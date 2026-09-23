{ : DUnitX tests for the DXF module (VCL.FNCCS4DXFModule.pas): group-level
  round trips through TDXFWrite / TDXFRead, and one end-to-end import
  through TDXF2DImport.

  These were part of CADSys4.Tests.Persistence until the drawing format
  moved to JSON; DXF is an interchange format of its own and is
  unaffected by that change.
}
unit CADSys4.Tests.DXF;

interface

uses
  DUnitX.TestFramework;

type

  { : TDXFWrite / TDXFRead group-level round trips (VCL.FNCCS4DXFModule.pas). }
  [TestFixture]
  TDXFGroupRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure StringGroups_SurviveAWriteReadCycle;
    [Test]
    procedure FloatGroups_SurviveToSixDecimalPlaces;
    [Test]
    procedure IntegerGroups_SurviveAWriteReadCycle;
    [Test]
    procedure ExtendedGroupCodes_RemapTo256AndAbove;
    [Test]
    procedure ReadAnEntry_ClearsTheTableBetweenEntities;
    [Test]
    procedure ReadAnEntry_AcceptsCode1256AtTheTableUpperBound;
    [Test]
    procedure ReadAnEntry_IgnoresGroupCodesAbove1256;
    [Test]
    procedure ConsumeGroup_ParsesFloats_WhenGlobalDecimalSeparatorIsComma;
    [Test]
    procedure ConsumeGroup_DoesNotWriteTheGlobalFormatSettings;
    [Test]
    procedure Reader_IdentifiesTheEntitiesSection;
    [Test]
    procedure NextSection_AdvancesFromHeaderToEntities;
    [Test]
    procedure Rewind_RepositionsAtTheFirstSection;
  end;

  { : One end-to-end DXF import through TDXF2DImport. }
  [TestFixture]
  TDXFImportRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ImportedLineEntity_LandsInTheCADWithItsCoordinates;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.IOUtils,
  Winapi.Windows,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCADSys4,
  VCL.FNCCS4Shapes,
  VCL.FNCCS4DXFModule,
  { Required: its initialization section fills the persistence class
    registry and the font list. }
  VCL.FNCCadSysRegister;

const
  { Exact geometry must survive a Double round trip bit for bit; a
    tolerance is used only to keep the intent readable. }
  TOL_EXACT = 1E-9;
  { Values that have passed through an accumulation, or through the
    DXF '%.6f' text form, which cannot promise more than six decimals. }
  TOL_DXF = 1E-6;

  { --------------------------------------------------------------- }
  { Local assertion helpers.                                          }
  {                                                                   }
  { These exist purely to pin down DUnitX overload resolution: every  }
  { argument is already of the exact parameter type, so there is no   }
  { implicit widening for the compiler to choose between.             }
  { --------------------------------------------------------------- }

procedure AssertReal(const AExpected, AActual, ATolerance: Double;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, ATolerance, AMessage);
end;

procedure AssertInt(const AExpected, AActual: Integer;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

procedure AssertStr(const AExpected, AActual: string;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

{ --------------------------------------------------------------- }
{ Shared fixture helpers.                                           }
{ --------------------------------------------------------------- }

{ : Write a DXF file line by line. ASCII has no byte-order mark, which
  matters because TDXFRead opens the file as a classic TextFile and the
  first ReadLn parses a Word. }
procedure WriteRawDXF(const AFileName: string;
  const ALines: array of string);
var
  TmpList: TStringList;
  Cont: Integer;
begin
  TmpList := TStringList.Create;
  try
    for Cont := Low(ALines) to High(ALines) do
      TmpList.Add(ALines[Cont]);
    TmpList.SaveToFile(AFileName, TEncoding.ASCII);
  finally
    TmpList.Free;
  end;
end;

{ : TDXFRead.ConsumeGroup reads both lines of a group and only then
  tests EOF, discarding the very last group in the file. Every fixture
  therefore appends two throwaway string groups so that the groups the
  test cares about are always parsed. Both are string-valued:
  NextSection compares GroupValue against 'SECTION', and comparing a
  float Variant with a string raises. }
procedure WriteDXFTail(const AWriter: TDXFWrite);
begin
  AWriter.WriteGroup(0, 'EOF');
  AWriter.WriteGroup(0, 'EOF');
end;

procedure TDXFGroupRoundTripTests.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TDXFGroupRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDXFGroupRoundTripTests.StringGroups_SurviveAWriteReadCycle;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[8] := 'WALLS';
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Group 0 (entity type)');
    AssertStr('WALLS', VarToStr(TmpIn[8]), 'Group 8 (layer name)');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.FloatGroups_SurviveToSixDecimalPlaces;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[10] := 12.345678;
    TmpOut[20] := -98.765432;
    TmpOut[40] := 0.5;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    { TDXFWrite formats floats with '%.6f', so six decimals is the
      best the text form can promise. }
    AssertReal(12.345678, Double(TmpIn[10]), TOL_DXF, 'Group 10');
    AssertReal(-98.765432, Double(TmpIn[20]), TOL_DXF, 'Group 20');
    AssertReal(0.5, Double(TmpIn[40]), TOL_DXF, 'Group 40');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.IntegerGroups_SurviveAWriteReadCycle;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[62] := 7;
    TmpOut[70] := -3;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertInt(7, Integer(TmpIn[62]), 'Group 62 (colour)');
    AssertInt(-3, Integer(TmpIn[70]), 'Group 70');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ExtendedGroupCodes_RemapTo256AndAbove;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  { TGroupTable is only 513 slots wide, so the extended DXF codes are
    folded down by 744: 1000 -> 256, 1010 -> 266, 1060 -> 316. Both
    TDXFWrite.WriteAnEntry and TDXFRead.ReadAnEntry must agree on that
    offset or extended data silently lands in the wrong slot. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[256] := 'XDATA';
    TmpOut[266] := 3.25;
    TmpOut[316] := 4242;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('XDATA', VarToStr(TmpIn[256]),
      'Code 1000 came back at slot 256');
    AssertReal(3.25, Double(TmpIn[266]), TOL_DXF,
      'Code 1010 came back at slot 266');
    AssertInt(4242, Integer(TmpIn[316]),
      'Code 1060 came back at slot 316');
    AssertStr('LINE', VarToStr(TmpIn[0]),
      'The ordinary groups were not disturbed');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ReadAnEntry_ClearsTheTableBetweenEntities;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpFirst, TmpSecond, TmpIn: TGroupTable;
begin
  { CS4-FIX: ReadAnEntry now VarClears every slot before filling the
    table. Before the fix a group the second entity omitted kept the
    FIRST entity's value, so every 'VarType(...) <> varEmpty' guard in
    the importer read stale data instead of detecting an absent group. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpFirst[0] := 'LINE';
    TmpFirst[8] := 'WALLS';
    TmpFirst[10] := 1.0;
    TmpFirst[20] := 2.0;
    TmpFirst[62] := 7;

    TmpSecond[0] := 'POINT';
    TmpSecond[10] := 9.0;

    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpFirst);
    TmpWrite.WriteAnEntry({%H-}TmpSecond);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'First entity type');
    AssertInt(7, Integer(TmpIn[62]), 'First entity colour');

    TmpRead.ReadAnEntry(0, TmpIn);
    AssertStr('POINT', VarToStr(TmpIn[0]), 'Second entity type');
    AssertReal(9.0, Double(TmpIn[10]), TOL_DXF, 'Second entity group 10');
    Assert.IsTrue(VarType(TmpIn[20]) = varEmpty,
      'Group 20 was omitted by the second entity and reads Unassigned');
    Assert.IsTrue(VarType(TmpIn[62]) = varEmpty,
      'Group 62 was omitted by the second entity and reads Unassigned');
    Assert.IsTrue(VarType(TmpIn[8]) = varEmpty,
      'Group 8 was omitted by the second entity and reads Unassigned');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ReadAnEntry_AcceptsCode1256AtTheTableUpperBound;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
begin
  { 1256 - 744 = 512 = High(TGroupTable), the last legal slot. It is
    written by hand because TDXFWrite.WriteGroup has no formatting rule
    for 1256 and would emit an empty value line. Codes outside the
    numeric ranges fall through to the untrimmed raw-text branch of
    ConsumeGroup, so the value is written with no leading spaces. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '1256', 'EDGE', '10', '1.000000', '0', 'ENDSEC', '0', 'EOF', '0',
    'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('EDGE', VarToStr(TmpIn[512]),
      'Code 1256 lands at the last table slot');
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Entity type');
    AssertReal(1.0, Double(TmpIn[10]), TOL_DXF, 'Group 10');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ReadAnEntry_IgnoresGroupCodesAbove1256;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
begin
  { CS4-FIX: the upper bound on the extended-code branch was missing,
    so a code above 1256 wrote a Variant past the end of TGroupTable -
    and every caller in VCL.FNCCS4DXFModule declares that table as a stack
    local. 1300 must now be dropped entirely: neither stored nor
    allowed to disturb the surrounding groups. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '1.000000', '1300', 'OUTOFRANGE', '20', '2.000000', '0',
    'ENDSEC', '0', 'EOF', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Entity type');
    AssertReal(1.0, Double(TmpIn[10]), TOL_DXF,
      'The group before the bad code');
    AssertReal(2.0, Double(TmpIn[20]), TOL_DXF,
      'The group after the bad code');
    Assert.IsTrue(VarType(TmpIn[512]) = varEmpty,
      'The out-of-range code did not land at the top of the table');
    Assert.IsTrue(VarType(TmpIn[256]) = varEmpty,
      'The out-of-range code did not land in the extended block');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ConsumeGroup_ParsesFloats_WhenGlobalDecimalSeparatorIsComma;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
  TmpSaved: Char;
begin
  { X2: TDXFRead.ConsumeGroup used to save, overwrite and restore
    FormatSettings.DecimalSeparator - a process global - around every
    parsed group. It now carries its own TFormatSettings pinned to '.',
    so a '.'-decimal DXF must parse correctly even while the global
    separator says ','. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '12.500000', '20', '-0.250000', '0', 'ENDSEC', '0', 'EOF',
    '0', 'EOF']);

  TmpSaved := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    TmpRead := TDXFRead.Create(FTempFile);
    try
      TmpRead.ReadAnEntry(0, {%H-}TmpIn);
      AssertReal(12.5, Double(TmpIn[10]), TOL_DXF,
        'X2: group 10 parsed with a comma decimal separator in force');
      AssertReal(-0.25, Double(TmpIn[20]), TOL_DXF,
        'X2: group 20 parsed with a comma decimal separator in force');
    finally
      TmpRead.Free;
    end;
  finally
    FormatSettings.DecimalSeparator := TmpSaved;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ConsumeGroup_DoesNotWriteTheGlobalFormatSettings;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
  TmpSaved: Char;
  TmpAfter: Char;
begin
  { The other half of X2: parsing must leave the process-wide
    FormatSettings exactly as it found them. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '3.750000', '0', 'ENDSEC', '0', 'EOF', '0', 'EOF']);

  TmpSaved := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    TmpRead := TDXFRead.Create(FTempFile);
    try
      TmpRead.ReadAnEntry(0, {%H-}TmpIn);
      AssertReal(3.75, Double(TmpIn[10]), TOL_DXF, 'Group 10');
    finally
      TmpRead.Free;
    end;
    TmpAfter := FormatSettings.DecimalSeparator;
    Assert.IsTrue(TmpAfter = ',',
      'X2: the DXF parser left the global decimal separator untouched');
  finally
    FormatSettings.DecimalSeparator := TmpSaved;
  end;
end;

procedure TDXFGroupRoundTripTests.Reader_IdentifiesTheEntitiesSection;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpWrite.BeginSection(scEntities);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    { TDXFRead.Create already consumes the first group and positions on
      the first section. }
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'BeginSection(scEntities) is read back as scEntities');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.NextSection_AdvancesFromHeaderToEntities;
var
  TmpRead: TDXFRead;
begin
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'HEADER', '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES', '0', 'ENDSEC', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    Assert.IsTrue(TmpRead.CurrentSection = scHeader,
      'The reader starts on the HEADER section');
    TmpRead.NextSection;
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'NextSection advances to the ENTITIES section');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.Rewind_RepositionsAtTheFirstSection;
var
  TmpRead: TDXFRead;
begin
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'HEADER', '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES', '0', 'ENDSEC', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.NextSection;
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'Advanced to ENTITIES');
    TmpRead.Rewind;
    Assert.IsTrue(TmpRead.CurrentSection = scHeader,
      'Rewind puts the reader back on the first section');
  finally
    TmpRead.Free;
  end;
end;

{ =================================================================== }
{ TDXFImportRoundTripTests                                            }
{ =================================================================== }

procedure TDXFImportRoundTripTests.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TDXFImportRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDXFImportRoundTripTests.
  ImportedLineEntity_LandsInTheCADWithItsCoordinates;
var
  TmpWrite: TDXFWrite;
  TmpOut: TGroupTable;
  TmpImport: TDXF2DImport;
  TmpCad: TFNCCADCmp2D;
  TmpLine: TLine2D;
begin
  { End to end: TDXFWrite produces the file, TDXF2DImport consumes it
    and materialises a TLine2D in a TFNCCADCmp2D. Only LINE is covered -
    it is the one entity whose importer needs neither a vector font nor
    a source-block table. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[8] := '0';
    TmpOut[10] := 1.5;
    TmpOut[20] := 2.5;
    TmpOut[11] := 3.5;
    TmpOut[21] := 4.5;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    TmpImport := TDXF2DImport.Create(FTempFile, TmpCad);
    try
      TmpImport.Scale := 1.0;
      TmpImport.Verbose := False;
      TmpImport.ReadDXF;
      Assert.IsFalse(TmpImport.UnableToReadAllTheFile,
        'The whole DXF was consumed');
    finally
      { Frees the TDXFRead and so closes the file before TearDown
        deletes it. }
      TmpImport.Free;
    end;
    AssertInt(1, TmpCad.ObjectsCount, 'One entity was imported');
    TmpLine := TmpCad.GetObject(0) as TLine2D;
    AssertReal(1.5, TmpLine.Points[0].X, TOL_DXF, 'Start X');
    AssertReal(2.5, TmpLine.Points[0].Y, TOL_DXF, 'Start Y');
    AssertReal(3.5, TmpLine.Points[1].X, TOL_DXF, 'End X');
    AssertReal(4.5, TmpLine.Points[1].Y, TOL_DXF, 'End Y');
  finally
    TmpCad.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TDXFGroupRoundTripTests);
TDUnitX.RegisterTestFixture(TDXFImportRoundTripTests);

end.
