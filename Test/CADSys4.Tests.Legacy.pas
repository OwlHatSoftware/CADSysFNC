{ : DUnitX tests for the legacy .CS2 reader (FNCCS4Legacy).

  The streams are built here rather than loaded from files, for the
  same reason the DXF tests build theirs: a test that needs a fixture
  on disk is a test that fails for the wrong reason. Building them also
  makes the two awkward branches - six byte versus twelve byte headers,
  and Single versus Double reals - directly testable, which reading one
  real file never would be.

  The layouts written here come from the original CADSys42 sources and
  were checked against real drawings, including a 1.2 MB one that
  parses to the last byte.
}
unit CADSys4.Tests.Legacy;

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  FNCCS4BaseTypes, FNCCS4Graphics, FNCCADSys4, FNCCS4Shapes, FNCCS4Legacy,
  FNCCadSysRegister;

type
  { : Writes legacy drawings, so the reader has something to read. }
  TLegacyWriter = class
  private
    fStream: TMemoryStream;
    fWide: Boolean;
    fDouble: Boolean;
  public
    constructor Create(const AVersion: string; const AWide, ADouble: Boolean);
    destructor Destroy; override;

    procedure WriteByte(const AValue: Byte);
    procedure WriteWord(const AValue: Word);
    procedure WriteInt(const AValue: LongInt);
    procedure WriteReal(const AValue: TRealType);
    procedure WritePoint(const AX, AY: TRealType);
    procedure WriteIdentity;
    procedure WriteObjectHeader(const AID: LongInt; const ALayer: Byte);
    { : One layer slot, with the fields a CAD422-or-later file has. }
    procedure WriteLayer(const AIndex: Word; const AName: string);
    procedure EndLayers;
    procedure WriteNoBlocks;
    procedure BeginObjects(const ACount: LongInt);
    { : A two-point primitive: header, point count, points, growing. }
    procedure WriteLine(const AID: LongInt; const ALayer: Byte;
      const AX1, AY1, AX2, AY2: TRealType);

    property Stream: TMemoryStream read fStream;
  end;

  [TestFixture]
  TLegacyReaderTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FPercents: array of Integer;
    procedure CollectProgress(Sender: TObject; ReadPercent: Byte);
    function ReadBack(const AWriter: TLegacyWriter): TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AnsiHeader_SingleReals_ReadsTheLine;
    [Test]
    procedure WideHeader_DoubleReals_ReadsTheLine;
    [Test]
    procedure TheHeaderDecidesTheWidthOfEveryReal;
    [Test]
    procedure LayerNameAndColourComeAcross;
    [Test]
    procedure AnUnregisteredClassIsRefusedClearly;
    [Test]
    procedure SomethingThatIsNotADrawingIsRefused;
    [Test]
    procedure IsLegacyStream_RecognisesBothHeaderWidths;
    [Test]
    procedure TheComponentMethodReadsItToo;
    [Test]
    procedure ProgressRisesOnceToAHundred;
  end;

implementation

{ TLegacyWriter }

constructor TLegacyWriter.Create(const AVersion: string;
  const AWide, ADouble: Boolean);
var
  Cont: Integer;
begin
  inherited Create;
  fStream := TMemoryStream.Create;
  fWide := AWide;
  fDouble := ADouble;
  { TCADVersion was 'array [1..6] of Char', so the header is six bytes
    or twelve depending on what Char meant when the file was written -
    and nothing in the file says which. }
  for Cont := 1 to 6 do
  begin
    WriteByte(Byte(AVersion[Cont]));
    if fWide then
      WriteByte(0);
  end;
end;

destructor TLegacyWriter.Destroy;
begin
  fStream.Free;
  inherited;
end;

procedure TLegacyWriter.WriteByte(const AValue: Byte);
begin
  fStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TLegacyWriter.WriteWord(const AValue: Word);
begin
  fStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TLegacyWriter.WriteInt(const AValue: LongInt);
begin
  fStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TLegacyWriter.WriteReal(const AValue: TRealType);
var
  TmpSingle: Single;
  TmpDouble: Double;
begin
  if fDouble then
  begin
    TmpDouble := AValue;
    fStream.WriteBuffer(TmpDouble, SizeOf(TmpDouble));
  end
  else
  begin
    TmpSingle := AValue;
    fStream.WriteBuffer(TmpSingle, SizeOf(TmpSingle));
  end;
end;

procedure TLegacyWriter.WritePoint(const AX, AY: TRealType);
begin
  WriteReal(AX);
  WriteReal(AY);
  WriteReal(1.0);
end;

procedure TLegacyWriter.WriteIdentity;
var
  Row, Col: Integer;
begin
  for Row := 1 to 3 do
    for Col := 1 to 3 do
      if Row = Col then
        WriteReal(1.0)
      else
        WriteReal(0.0);
end;

procedure TLegacyWriter.WriteObjectHeader(const AID: LongInt;
  const ALayer: Byte);
begin
  WriteInt(AID);
  WriteByte(ALayer);
  { Visible and Enabled set, 'not to be saved' clear. }
  WriteByte(1 or 2);
  WriteIdentity;
end;

procedure TLegacyWriter.WriteLayer(const AIndex: Word; const AName: string);
var
  TmpBuf: array [0 .. 31] of Byte;
  Cont: Integer;
begin
  WriteWord(AIndex);
  WriteInt($000000FF);        { pen colour, red in TColor's BGR order }
  WriteByte(0);               { pen style, solid }
  WriteByte(4);               { pen mode, copy }
  WriteInt(3);                { pen width }
  WriteInt($0000FF00);        { brush colour, green }
  WriteByte(0);               { brush style, solid }
  WriteInt(0);                { decorative pattern, empty }
  WriteByte(1);               { active }
  WriteByte(1);               { visible }
  WriteByte(1);               { opaque }
  WriteByte(1);               { streamable }
  { A ShortString in a fixed 32 byte slot. The tail is left as rubbish
    on purpose - that is what real files hold, and the reader must cut
    at the length byte rather than trust a NUL. }
  FillChar(TmpBuf, SizeOf(TmpBuf), Ord('?'));
  TmpBuf[0] := Length(AName);
  for Cont := 1 to Length(AName) do
    TmpBuf[Cont] := Byte(AName[Cont]);
  fStream.WriteBuffer(TmpBuf, SizeOf(TmpBuf));
end;

procedure TLegacyWriter.EndLayers;
begin
  WriteWord(256);
end;

procedure TLegacyWriter.WriteNoBlocks;
begin
  WriteByte(2);
  WriteInt(0);
end;

procedure TLegacyWriter.BeginObjects(const ACount: LongInt);
begin
  WriteByte(3);
  WriteInt(ACount);
end;

procedure TLegacyWriter.WriteLine(const AID: LongInt; const ALayer: Byte;
  const AX1, AY1, AX2, AY2: TRealType);
begin
  WriteWord(3);               { the registration index of TLine2D }
  WriteObjectHeader(AID, ALayer);
  WriteWord(2);
  WritePoint(AX1, AY1);
  WritePoint(AX2, AY2);
  WriteByte(0);               { growing disabled }
end;

{ TLegacyReaderTests }

procedure TLegacyReaderTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TLegacyReaderTests.TearDown;
begin
  FCAD.Free;
end;

function TLegacyReaderTests.ReadBack(const AWriter: TLegacyWriter)
  : TFNCCADCmp2D;
begin
  AWriter.Stream.Position := 0;
  CADLoadLegacyStream(AWriter.Stream, FCAD);
  Result := FCAD;
end;

function CountObjects(const ACAD: TFNCCADCmp2D): Integer;
var
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  Result := 0;
  TmpIter := ACAD.ObjectsIterator;
  try
    TmpObj := TmpIter.First;
    while TmpObj <> nil do
    begin
      Inc(Result);
      TmpObj := TmpIter.Next;
    end;
  finally
    TmpIter.Free;
  end;
end;

function FirstLine(const ACAD: TFNCCADCmp2D): TLine2D;
var
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  Result := nil;
  TmpIter := ACAD.ObjectsIterator;
  try
    TmpObj := TmpIter.First;
    while (TmpObj <> nil) and (Result = nil) do
    begin
      if TmpObj is TLine2D then
        Result := TLine2D(TmpObj);
      TmpObj := TmpIter.Next;
    end;
  finally
    TmpIter.Free;
  end;
end;

procedure TLegacyReaderTests.AnsiHeader_SingleReals_ReadsTheLine;
var
  TmpWriter: TLegacyWriter;
  TmpLine: TLine2D;
begin
  { A Delphi 7 era file: six byte header, four byte reals. }
  TmpWriter := TLegacyWriter.Create('CAD422', False, False);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(1);
    TmpWriter.WriteLine(7, 0, 10, 20, 30, 40);
    ReadBack(TmpWriter);
  finally
    TmpWriter.Free;
  end;
  Assert.AreEqual(1, CountObjects(FCAD), 'one object came across');
  TmpLine := FirstLine(FCAD);
  Assert.IsNotNull(TmpLine, 'and it is a line');
  Assert.AreEqual(7, TmpLine.ID, 'the ID survived');
  Assert.AreEqual(10.0, TmpLine.Points[0].X, 0.001, 'first X');
  Assert.AreEqual(40.0, TmpLine.Points[1].Y, 0.001, 'second Y');
end;

procedure TLegacyReaderTests.WideHeader_DoubleReals_ReadsTheLine;
var
  TmpWriter: TLegacyWriter;
  TmpLine: TLine2D;
begin
  { A modern file: twelve byte header, eight byte reals. }
  TmpWriter := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(1);
    TmpWriter.WriteLine(9, 0, -5, -6, 7, 8);
    ReadBack(TmpWriter);
  finally
    TmpWriter.Free;
  end;
  TmpLine := FirstLine(FCAD);
  Assert.IsNotNull(TmpLine, 'the line came across');
  Assert.AreEqual(9, TmpLine.ID, 'the ID survived');
  Assert.AreEqual(-5.0, TmpLine.Points[0].X, 0.000001, 'first X');
  Assert.AreEqual(8.0, TmpLine.Points[1].Y, 0.000001, 'second Y');
end;

procedure TLegacyReaderTests.TheHeaderDecidesTheWidthOfEveryReal;
var
  TmpWriter: TLegacyWriter;
  TmpLine: TLine2D;
begin
  { The catch that makes this format awkward: CAD422 with a twelve byte
    header is a real combination - a modern build writing the old
    version string - and the reader has to take the character width
    from the header and the real width from the version, separately.
    Conflate the two and every coordinate is nonsense. }
  TmpWriter := TLegacyWriter.Create('CAD422', True, False);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(1);
    TmpWriter.WriteLine(1, 0, 100, 200, 300, 400);
    ReadBack(TmpWriter);
  finally
    TmpWriter.Free;
  end;
  TmpLine := FirstLine(FCAD);
  Assert.IsNotNull(TmpLine, 'a wide header with narrow reals still reads');
  Assert.AreEqual(100.0, TmpLine.Points[0].X, 0.01, 'first X');
  Assert.AreEqual(400.0, TmpLine.Points[1].Y, 0.01, 'second Y');
end;

procedure TLegacyReaderTests.LayerNameAndColourComeAcross;
var
  TmpWriter: TLegacyWriter;
begin
  TmpWriter := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.WriteLayer(3, 'Walls');
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(0);
    ReadBack(TmpWriter);
  finally
    TmpWriter.Free;
  end;
  Assert.AreEqual('Walls', String(FCAD.Layers[3].Name),
    'the name is cut at the length byte, not at a NUL');
  Assert.AreEqual(3, FCAD.Layers[3].Pen.Width, 'the pen width');
  Assert.IsTrue(FCAD.Layers[3].Opaque, 'and the opacity flag');
end;

procedure TLegacyReaderTests.AnUnregisteredClassIsRefusedClearly;
var
  TmpWriter: TLegacyWriter;
begin
  { Records carry no length, so a reader that meets a class it does not
    know cannot find the end of it and must stop. Refusing loudly beats
    carrying on and producing rubbish. }
  TmpWriter := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(1);
    TmpWriter.WriteWord(400);
    TmpWriter.WriteObjectHeader(1, 0);
    TmpWriter.Stream.Position := 0;
    Assert.WillRaise(
      procedure
      begin
        CADLoadLegacyStream(TmpWriter.Stream, FCAD);
      end, ECADLegacyFormat, 'an unknown class index stops the read');
  finally
    TmpWriter.Free;
  end;
end;

procedure TLegacyReaderTests.SomethingThatIsNotADrawingIsRefused;
var
  TmpStream: TMemoryStream;
  TmpBytes: array [0 .. 15] of Byte;
begin
  TmpStream := TMemoryStream.Create;
  try
    FillChar(TmpBytes, SizeOf(TmpBytes), Ord('x'));
    TmpStream.WriteBuffer(TmpBytes, SizeOf(TmpBytes));
    TmpStream.Position := 0;
    Assert.WillRaise(
      procedure
      begin
        CADLoadLegacyStream(TmpStream, FCAD);
      end, ECADLegacyFormat, 'it does not start with CAD');
  finally
    TmpStream.Free;
  end;
end;

procedure TLegacyReaderTests.IsLegacyStream_RecognisesBothHeaderWidths;
var
  TmpAnsi, TmpWide: TLegacyWriter;
begin
  TmpAnsi := TLegacyWriter.Create('CAD422', False, False);
  TmpWide := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpAnsi.Stream.Position := 0;
    TmpWide.Stream.Position := 0;
    Assert.IsTrue(IsLegacyStream(TmpAnsi.Stream), 'the six byte header');
    Assert.IsTrue(IsLegacyStream(TmpWide.Stream), 'and the twelve byte one');
    Assert.AreEqual(Int64(0), TmpWide.Stream.Position,
      'and the position is put back');
  finally
    TmpAnsi.Free;
    TmpWide.Free;
  end;
end;

procedure TLegacyReaderTests.CollectProgress(Sender: TObject;
  ReadPercent: Byte);
begin
  SetLength(FPercents, Length(FPercents) + 1);
  FPercents[High(FPercents)] := ReadPercent;
end;

procedure TLegacyReaderTests.ProgressRisesOnceToAHundred;
var
  TmpWriter: TLegacyWriter;
  Cont: Integer;
begin
  { What the old code did not do: report a percentage that moves. It
    sent 100 div Count on every object, which integer division pinned
    at 0 for anything over a hundred objects. }
  FPercents := nil;
  FCAD.OnLoadProgress := CollectProgress;
  TmpWriter := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(250);
    for Cont := 1 to 250 do
      TmpWriter.WriteLine(Cont, 0, Cont, Cont, Cont + 1, Cont + 1);
    ReadBack(TmpWriter);
  finally
    TmpWriter.Free;
    FCAD.OnLoadProgress := nil;
  end;

  Assert.AreEqual(250, CountObjects(FCAD), 'every object came across');
  Assert.IsTrue(Length(FPercents) > 1, 'progress was reported more than once');
  Assert.IsTrue(Length(FPercents) <= 100,
    'and at most once per whole per cent, not once per object');
  for Cont := 1 to High(FPercents) do
    Assert.IsTrue(FPercents[Cont] > FPercents[Cont - 1],
      'it only ever rises');
  Assert.AreEqual(100, FPercents[High(FPercents)], 'and it reaches the end');
end;

procedure TLegacyReaderTests.TheComponentMethodReadsItToo;
var
  TmpWriter: TLegacyWriter;
begin
  { CAD.LoadLegacyStream reaches the reader through a hook, because
    FNCCADSys4 cannot use the unit that uses it. This is the test that
    the hook is actually installed - without it the method raises
    instead, and nothing else here would notice. }
  TmpWriter := TLegacyWriter.Create('CAD423', True, True);
  try
    TmpWriter.WriteWord(1);
    TmpWriter.EndLayers;
    TmpWriter.WriteNoBlocks;
    TmpWriter.BeginObjects(1);
    TmpWriter.WriteLine(42, 0, 1, 2, 3, 4);
    TmpWriter.Stream.Position := 0;
    FCAD.LoadLegacyStream(TmpWriter.Stream);
  finally
    TmpWriter.Free;
  end;
  Assert.AreEqual(1, CountObjects(FCAD), 'the method read the drawing');
  Assert.AreEqual(42, FirstLine(FCAD).ID, 'and it is the right one');
end;

initialization

TDUnitX.RegisterTestFixture(TLegacyReaderTests);

end.
