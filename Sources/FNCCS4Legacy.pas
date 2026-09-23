{ : Reads the legacy CADSys 4 binary drawing format - the .CS2 files
  written by the library before step 2b replaced binary streams with
  JSON.

  This is a reader and nothing else. It parses the old bytes and builds
  present-day objects; saving them back out as JSON is then
  TFNCCADCmp2D.SaveToFile's business, and that is the whole migration:

    CADLoadLegacyFile('old.cs2', CAD);
    CAD.SaveToFile('new.json');

  It has to live here rather than in a tool built against the old
  library, because the old library cannot write the new JSON and the
  two cannot coexist in one program - same unit names, same class
  names.

  WHAT THE FORMAT DOES NOT TELL YOU

  Two things are not in the file and cannot be inferred from it:

  - The width of a Char. TCADVersion was 'array [1..6] of Char', so the
    header is six bytes in a Delphi 7 era build and twelve in a Unicode
    one, and the same goes for block names and text. The reader sniffs
    it from the header - see ReadHeader - and applies the answer to
    every Char-typed field after it.

  - What a class index means. The index is positional, registered by
    the application at startup. Indices 0..14 are the library's own and
    are built in here; an application that registered shapes of its own
    at other indices must add them through RegisterLegacyClass before
    reading, or the reader will refuse the file rather than guess.

  Everything in here was derived from the original sources in the
  CADSys42 repository and checked against real files. Where the old
  code branched on version, so does this.
}
unit FNCCS4Legacy;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, UITypes,
{$ELSE}
  System.Classes, System.SysUtils, System.UITypes,
{$ENDIF}
  FNCCS4BaseTypes, FNCCS4Graphics, FNCCADSys4, FNCCS4Shapes;

type
  { : Raised when the stream is not a CADSys drawing, or stops making
    sense part way through. }
  ECADLegacyFormat = class(Exception);

  { : Builds one object of a legacy class index.

    Reader is the reader positioned just after the class index; the
    function reads the object's own fields and returns it. Register one
    with <See Procedure=RegisterLegacyClass> for an application's own
    shapes. }
  TCADLegacyReader = class;
  TCADLegacyBuilder = function(const AReader: TCADLegacyReader;
    const AID: LongInt): TObject2D;

  { : The state of one read: the stream, and what the header said about
    how to interpret it. }
  TCADLegacyReader = class
  private
    fStream: TStream;
    fVersion: string;
    fWideChars: Boolean;
    fDoubleReals: Boolean;
    fCAD: TFNCCADCmp2D;
    fTotal, fDone, fLastPerc: Integer;

    { : Reports through the component's own OnLoadProgress, so that a
      caller cannot tell a legacy import from a JSON one - a progress
      bar wired up for one works for the other without knowing. Fired
      only when the whole number changes, which keeps a drawing of
      several thousand objects to a hundred events. }
    procedure ReportProgress;

    procedure ReadHeader;
    procedure ReadLayers;
    procedure ReadSourceBlocks;
    procedure ReadObjects;
    function ReadObject: TObject2D;
    procedure ReadGraphicObjectHeader(const AObj: TObject2D;
      out AID: LongInt);
  public
    constructor Create(const AStream: TStream; const ACAD: TFNCCADCmp2D);

    { : Reads the whole drawing into the component given to Create. }
    procedure Execute;

    { : The stream primitives, public because a builder registered by an
      application needs them. }
    function ReadByte: Byte;
    function ReadBool: Boolean;
    function ReadWord: Word;
    function ReadInt: LongInt;
    { : One TRealType: four bytes before CAD423, eight from it. }
    function ReadReal: TRealType;
    { : X, Y and W - the old format stored homogeneous points. }
    function ReadPoint: TPoint2D;
    { : Nine reals, row major, as the old TTransf2D was laid out. }
    function ReadTransform: TTransf2D;
    { : ACount characters of whatever width this file uses, cut at the
      first NUL. }
    function ReadFixedString(const ACount: Integer): string;
    { : A four byte character count, then that many characters. }
    function ReadCountedString: string;
    { : A Delphi ShortString in a fixed 32 byte slot. Always single
      byte characters, even in a Unicode build, and the bytes past the
      length are whatever was in memory - so they are discarded. }
    function ReadShortString32: string;
    procedure ReadBytes(var ABuffer; const ACount: Integer);
    procedure Skip(const ACount: Integer);

    { : The version string, six characters, for a builder that needs to
      branch on it. Compare with >= as the old code does. }
    property Version: string read fVersion;
    property WideChars: Boolean read fWideChars;
    property DoubleReals: Boolean read fDoubleReals;
    property Stream: TStream read fStream;
  end;

{ : Registers a builder for a class index an application added to the
  old library's registry. Indices 0..14 are the library's own. }
procedure RegisterLegacyClass(const AIndex: Word;
  const ABuilder: TCADLegacyBuilder);

{ : Reads a legacy drawing into ACAD, replacing what is there. }
procedure CADLoadLegacyStream(const AStream: TStream;
  const ACAD: TFNCCADCmp2D);
procedure CADLoadLegacyFile(const AFileName: string;
  const ACAD: TFNCCADCmp2D);

{ : True if the stream looks like a legacy drawing - the first bytes
  spell CAD, in either character width. Leaves the position alone. }
function IsLegacyStream(const AStream: TStream): Boolean;

type
  { : Called as the reader works through a drawing.

    AWhat names the step, AIndex is a class index or a count depending
    on the step, and APosition is where the stream had got to. Reading
    a large drawing is otherwise silent for a long time, and when
    something goes wrong the position of the last object read is the
    only thing that says where to look. }
  TCADLegacyProgressEvent = procedure(const AWhat: string;
    const AIndex: Integer; const APosition: Int64);

var
  CADLegacyProgress: TCADLegacyProgressEvent = nil;

implementation

const
  { The markers that separate the file's three sections. }
  LegacyLayersMarker = 1;
  LegacyBlocksMarker = 2;
  LegacyObjectsMarker = 3;
  { Written in place of a class index when the writer skipped objects,
    so the count at the head of the section is an upper bound. }
  LegacyEndOfObjects = 65535;
  LegacyEndOfLayers = 256;

  { The library's own class indices, from CADSysRegister.pas. }
  LegacyContainer2D = 0;
  LegacySourceBlock2D = 1;
  LegacyBlock2D = 2;
  LegacyLine2D = 3;
  LegacyPolyline2D = 4;
  LegacyPolygon2D = 5;
  LegacyRectangle2D = 6;
  LegacyArc2D = 7;
  LegacyEllipse2D = 8;
  LegacyFilledEllipse2D = 9;
  LegacyText2D = 10;
  LegacyFrame2D = 11;
  LegacyBitmap2D = 12;
  LegacyBSpline2D = 13;
  LegacyJustifiedVectText2D = 14;

  MaxLegacyClass = 511;

var
  LegacyBuilders: array [0 .. MaxLegacyClass] of TCADLegacyBuilder;

procedure RegisterLegacyClass(const AIndex: Word;
  const ABuilder: TCADLegacyBuilder);
begin
  if AIndex > MaxLegacyClass then
    Raise ECADLegacyFormat.CreateFmt
      ('RegisterLegacyClass: index %d is out of range', [AIndex]);
  LegacyBuilders[AIndex] := ABuilder;
end;

function IsLegacyStream(const AStream: TStream): Boolean;
var
  TmpPos: Int64;
  TmpBuf: array [0 .. 5] of Byte;
begin
  Result := False;
  TmpPos := AStream.Position;
  try
    if AStream.Size - TmpPos < 6 then
      Exit;
    AStream.ReadBuffer(TmpBuf, 6);
    Result := (TmpBuf[0] = Ord('C')) and
      ((TmpBuf[1] = Ord('A')) or ((TmpBuf[1] = 0) and (TmpBuf[2] = Ord('A'))));
  finally
    AStream.Position := TmpPos;
  end;
end;

{ ==================================================================
  TCADLegacyReader - the stream primitives
  ================================================================== }

constructor TCADLegacyReader.Create(const AStream: TStream;
  const ACAD: TFNCCADCmp2D);
begin
  inherited Create;
  fStream := AStream;
  fCAD := ACAD;
  { Zero, not minus one: the first object of a large drawing rounds to
    0 per cent, and reporting that is a wasted event saying nothing.
    Starting here means the first thing a caller hears is 1 per cent,
    and a drawing small enough to jump straight to 100 still gets it. }
  fLastPerc := 0;
end;

procedure TCADLegacyReader.ReadBytes(var ABuffer; const ACount: Integer);
begin
  if fStream.Read(ABuffer, ACount) <> ACount then
    Raise ECADLegacyFormat.CreateFmt
      ('The drawing ends in the middle of a record (wanted %d bytes at %d)',
      [ACount, fStream.Position]);
end;

procedure TCADLegacyReader.Skip(const ACount: Integer);
begin
  fStream.Position := fStream.Position + ACount;
end;

function TCADLegacyReader.ReadByte: Byte;
begin
  ReadBytes(Result, SizeOf(Result));
end;

function TCADLegacyReader.ReadBool: Boolean;
begin
  Result := ReadByte <> 0;
end;

function TCADLegacyReader.ReadWord: Word;
begin
  ReadBytes(Result, SizeOf(Result));
end;

function TCADLegacyReader.ReadInt: LongInt;
begin
  ReadBytes(Result, SizeOf(Result));
end;

function TCADLegacyReader.ReadReal: TRealType;
var
  TmpSingle: Single;
  TmpDouble: Double;
begin
  { The one branch that runs through everything. TRealType was Single
    until CAD423 and Double from it, so every point, transform and
    dimension changes width at that boundary. }
  if fDoubleReals then
  begin
    ReadBytes(TmpDouble, SizeOf(TmpDouble));
    Result := TmpDouble;
  end
  else
  begin
    ReadBytes(TmpSingle, SizeOf(TmpSingle));
    Result := TmpSingle;
  end;
end;

function TCADLegacyReader.ReadPoint: TPoint2D;
begin
  Result.X := ReadReal;
  Result.Y := ReadReal;
  Result.W := ReadReal;
end;

function TCADLegacyReader.ReadTransform: TTransf2D;
var
  Row, Col: Integer;
begin
  for Row := 1 to 3 do
    for Col := 1 to 3 do
      Result[Row, Col] := ReadReal;
end;

function TCADLegacyReader.ReadFixedString(const ACount: Integer): string;
var
  Cont: Integer;
  TmpCh: Word;
begin
  Result := '';
  for Cont := 1 to ACount do
  begin
    TmpCh := 0;
    if fWideChars then
      ReadBytes(TmpCh, 2)
    else
      ReadBytes(TmpCh, 1);
    if TmpCh <> 0 then
      Result := Result + Char(TmpCh);
  end;
end;

function TCADLegacyReader.ReadCountedString: string;
var
  TmpLen: LongInt;
begin
  TmpLen := ReadInt;
  if (TmpLen < 0) or (TmpLen > fStream.Size - fStream.Position) then
    Raise ECADLegacyFormat.CreateFmt
      ('A string claims to be %d characters long at %d', [TmpLen,
      fStream.Position]);
  Result := ReadFixedString(TmpLen);
end;

function TCADLegacyReader.ReadShortString32: string;
var
  TmpBuf: array [0 .. 31] of Byte;
  TmpLen, Cont: Integer;
begin
  { A Delphi ShortString in a fixed slot: length byte, then the
    characters, then whatever happened to be in the buffer. The tail is
    uninitialised memory in real files - not NULs - so it is cut at the
    length and never looked at. }
  ReadBytes(TmpBuf, SizeOf(TmpBuf));
  TmpLen := TmpBuf[0];
  if TmpLen > 31 then
    TmpLen := 31;
  Result := '';
  for Cont := 1 to TmpLen do
    Result := Result + Char(TmpBuf[Cont]);
end;

{ ==================================================================
  The header
  ================================================================== }

procedure TCADLegacyReader.ReportProgress;
var
  TmpPerc: Integer;
begin
  if (fTotal <= 0) or not Assigned(fCAD.OnLoadProgress) then
    Exit;
  TmpPerc := Round(fDone / fTotal * 100);
  if TmpPerc = fLastPerc then
    Exit;
  fLastPerc := TmpPerc;
  fCAD.OnLoadProgress(fCAD, TmpPerc);
end;

procedure TCADLegacyReader.ReadHeader;
var
  TmpBuf: array [0 .. 11] of Byte;
  TmpStart: Int64;
  Cont: Integer;
begin
  { TCADVersion was 'array [1..6] of Char', and nothing in the file says
    how wide a Char was when it was written: six bytes from a Delphi 7
    era build, twelve from a Unicode one. Both exist in the wild.

    Sniffing is safe because the first three characters are always
    'CAD': in the wide form every second byte is zero. Once decided,
    the answer applies to every Char-typed field in the file. }
  TmpStart := fStream.Position;
  if fStream.Size - TmpStart < 6 then
    Raise ECADLegacyFormat.Create('The file is too short to be a drawing');

  FillChar(TmpBuf, SizeOf(TmpBuf), 0);
  if fStream.Size - TmpStart >= 12 then
    fStream.Read(TmpBuf, 12)
  else
    fStream.Read(TmpBuf, 6);

  if (TmpBuf[0] = Ord('C')) and (TmpBuf[1] = 0) and (TmpBuf[2] = Ord('A')) then
  begin
    fWideChars := True;
    fVersion := '';
    for Cont := 0 to 5 do
      fVersion := fVersion + Char(TmpBuf[Cont * 2]);
    fStream.Position := TmpStart + 12;
  end
  else if (TmpBuf[0] = Ord('C')) and (TmpBuf[1] = Ord('A')) and
    (TmpBuf[2] = Ord('D')) then
  begin
    fWideChars := False;
    fVersion := '';
    for Cont := 0 to 5 do
      fVersion := fVersion + Char(TmpBuf[Cont]);
    fStream.Position := TmpStart + 6;
  end
  else
    Raise ECADLegacyFormat.Create
      ('This is not a CADSys drawing - it does not start with CAD');

  { The old loader accepted anything beginning CAD and passed the string
    down to every constructor, so the same latitude is kept here. }
  fDoubleReals := fVersion >= 'CAD423';
  if Assigned(CADLegacyProgress) then
    CADLegacyProgress('version ' + fVersion + ', wide chars ' +
      BoolToStr(fWideChars, True) + ', double reals ' +
      BoolToStr(fDoubleReals, True), 0, fStream.Position);
end;

{ ==================================================================
  Layers
  ================================================================== }

procedure TCADLegacyReader.ReadLayers;
var
  TmpIdx: Word;
  TmpLayer: TLayer;
  TmpPenColor, TmpBrushColor: TColor;
  TmpPenStyle, TmpPenMode, TmpBrushStyle: Byte;
  TmpPenWidth, TmpPatternLen: LongInt;
  TmpName: string;
begin
  if ReadWord <> LegacyLayersMarker then
    Raise ECADLegacyFormat.Create('No layers section in the drawing');

  while fStream.Position < fStream.Size do
  begin
    TmpIdx := ReadWord;
    if TmpIdx = LegacyEndOfLayers then
      Break;
    if TmpIdx > 255 then
      Raise ECADLegacyFormat.CreateFmt('Layer index %d is out of range',
        [TmpIdx]);
    TmpLayer := fCAD.Layers[Byte(TmpIdx)];

    { The pen and the brush were VCL objects, written field by field.
      Colour is a TColor with the same $00BBGGRR layout the library
      still uses, and the styles line up one for one with cps* and
      cbs* because both were modelled on GDI's. }
    ReadBytes(TmpPenColor, SizeOf(TmpPenColor));
    TmpPenStyle := ReadByte;
    TmpPenMode := ReadByte;
    ReadBytes(TmpPenWidth, SizeOf(TmpPenWidth));
    ReadBytes(TmpBrushColor, SizeOf(TmpBrushColor));
    TmpBrushStyle := ReadByte;

    { Before CAD422 a second brush colour was written and ignored on
      the way back in. It is still written out by old files, so it
      still has to be stepped over. }
    if fVersion < 'CAD422' then
      Skip(SizeOf(TColor));

    { The decorative pen's bit pattern. A Win32 LineDDA stipple with no
      modern equivalent, so the bits are stepped over rather than
      pretended at - the library's TDecorativePen is a different
      animal. }
    if fVersion >= 'CAD41' then
    begin
      TmpPatternLen := ReadInt;
      if (TmpPatternLen < 0) or
        (TmpPatternLen > fStream.Size - fStream.Position) then
        Raise ECADLegacyFormat.CreateFmt
          ('A layer pattern claims to be %d long', [TmpPatternLen]);
      Skip(TmpPatternLen);
    end;

    TmpLayer.Active := ReadBool;
    if fVersion >= 'CAD4' then
      TmpLayer.Visible := ReadBool
    else
      TmpLayer.Visible := True;
    TmpLayer.Opaque := ReadBool;

    if (fVersion = 'CAD3  ') then
      TmpLayer.Streamable := ReadBool
    else if fVersion >= 'CAD33' then
    begin
      TmpLayer.Streamable := ReadBool;
      TmpName := ReadShortString32;
      if TmpName <> '' then
        TmpLayer.Name := TLayerName(AnsiString(TmpName));
    end;

    TmpLayer.Pen.Color := TColorToCADColor(TmpPenColor);
    TmpLayer.Pen.Width := TmpPenWidth;
    if TmpPenStyle <= Ord(High(TCADPenStyle)) then
      TmpLayer.Pen.Style := TCADPenStyle(TmpPenStyle);
    if TmpPenMode <= Ord(High(TCADPenMode)) then
      TmpLayer.Pen.Mode := TCADPenMode(TmpPenMode);
    TmpLayer.Brush.Color := TColorToCADColor(TmpBrushColor);
    if TmpBrushStyle <= Ord(High(TCADBrushStyle)) then
      TmpLayer.Brush.Style := TCADBrushStyle(TmpBrushStyle);
  end;
end;

{ ==================================================================
  Objects
  ================================================================== }

procedure TCADLegacyReader.ReadGraphicObjectHeader(const AObj: TObject2D;
  out AID: LongInt);
var
  TmpMask: Byte;
begin
  AID := ReadInt;
  AObj.Layer := ReadByte;
  TmpMask := ReadByte;
  AObj.Visible := (TmpMask and 1) <> 0;
  AObj.Enabled := (TmpMask and 2) <> 0;
  { Bit 4 is inverted - it meant 'not to be saved'. }
  AObj.ToBeSaved := (TmpMask and 4) = 0;
end;

function TCADLegacyReader.ReadObject: TObject2D;
var
  TmpIdx: Word;
  TmpBuilder: TCADLegacyBuilder;
  TmpID: LongInt;
begin
  TmpIdx := ReadWord;
  if TmpIdx > MaxLegacyClass then
    Raise ECADLegacyFormat.CreateFmt('Class index %d is out of range at %d',
      [TmpIdx, fStream.Position]);
  if Assigned(CADLegacyProgress) then
    CADLegacyProgress('object', TmpIdx, fStream.Position);
  TmpBuilder := LegacyBuilders[TmpIdx];
  if not Assigned(TmpBuilder) then
    Raise ECADLegacyFormat.CreateFmt
      ('Class index %d is not registered. If the drawing was written by an ' +
      'application with shapes of its own, register a builder for that ' +
      'index with RegisterLegacyClass before reading.', [TmpIdx]);
  { The header is read here rather than in each builder, because it is
    the same three fields for every class and the ID is needed before
    the object can be constructed. }
  TmpID := 0;
  Result := TmpBuilder(Self, TmpID);
end;

procedure TCADLegacyReader.ReadSourceBlocks;
var
  TmpCount, Cont: LongInt;
  TmpObj: TObject2D;
begin
  if ReadByte <> LegacyBlocksMarker then
    Raise ECADLegacyFormat.Create('No blocks section in the drawing');
  TmpCount := ReadInt;
  if (TmpCount < 0) or (TmpCount > fStream.Size) then
    Raise ECADLegacyFormat.CreateFmt('The drawing claims %d source blocks',
      [TmpCount]);
  if Assigned(CADLegacyProgress) then
    CADLegacyProgress('source blocks', TmpCount, fStream.Position);
  { The blocks and the objects are counted together: a reader that
    reaches 100 per cent and then starts again is worse than none. }
  Inc(fTotal, TmpCount);
  for Cont := 1 to TmpCount do
  begin
    TmpObj := ReadObject;
    Inc(fDone);
    ReportProgress;
    if TmpObj is TSourceBlock2D then
      fCAD.AddSourceBlock(TSourceBlock2D(TmpObj))
    else
    begin
      TmpObj.Free;
      Raise ECADLegacyFormat.Create
        ('The blocks section holds something that is not a source block');
    end;
  end;
end;

procedure TCADLegacyReader.ReadObjects;
var
  TmpCount: LongInt;
  TmpIdx: Word;
  TmpPos: Int64;
  TmpObj: TObject2D;
  TmpBlocks: TExclusiveGraphicObjIterator;
begin
  { One iterator for the whole run, as LoadObjectsFromJSON does. Making
    one per object worked, but it is 7554 of them for a real drawing. }
  if ReadByte <> LegacyObjectsMarker then
    Raise ECADLegacyFormat.Create('No objects section in the drawing');
  TmpCount := ReadInt;
  if (TmpCount < 0) or (TmpCount > fStream.Size) then
    Raise ECADLegacyFormat.CreateFmt('The drawing claims %d objects',
      [TmpCount]);
  if Assigned(CADLegacyProgress) then
    CADLegacyProgress('objects', TmpCount, fStream.Position);
  Inc(fTotal, TmpCount);
  TmpBlocks := fCAD.SourceBlocksExclusiveIterator;
  try
  while TmpCount > 0 do
  begin
    { The count at the head of the section is what was in memory, not
      what was written: objects on unstreamable layers were skipped and
      a sentinel appended. So the count is an upper bound and the
      sentinel is the real end. }
    TmpPos := fStream.Position;
    TmpIdx := ReadWord;
    fStream.Position := TmpPos;
    if TmpIdx = LegacyEndOfObjects then
      Break;
    Dec(TmpCount);
    TmpObj := ReadObject;
    { A block names its source rather than pointing at it, so the link
      is made here - the same way LoadObjectsFromJSON does it, and for
      the same reason: the source blocks are all in by now. }
    try
      if TmpObj is TContainer2D then
        TContainer2D(TmpObj).UpdateSourceReferences(TmpBlocks)
      else if TmpObj is TBlock2D then
        TBlock2D(TmpObj).UpdateReference(TmpBlocks);
    except
      on ECADListObjNotFound do
      begin
        CADSysWarn('Source block not found. The block will not be loaded');
        TmpObj.Free;
        Continue;
      end;
    end;
    { AddObject overwrites the object's layer with the component's
      current one, so the current one has to be the object's first.
      LoadObjectsFromJSON does the same; without it every imported
      object lands on whatever layer happened to be selected. }
    fCAD.CurrentLayer := TmpObj.Layer;
    fCAD.AddObject(TmpObj.ID, TmpObj);
    Inc(fDone);
    ReportProgress;
    if Assigned(CADLegacyProgress) then
      CADLegacyProgress('added', TmpObj.ID, fStream.Position);
  end;
  finally
    TmpBlocks.Free;
  end;
end;

procedure TCADLegacyReader.Execute;
begin
  ReadHeader;
  ReadLayers;
  ReadSourceBlocks;
  ReadObjects;
end;

{ ==================================================================
  The builders, one per legacy class index

  Each reads what its class added, in the order the old
  CreateFromStream read it. Where a class added nothing, it shares a
  builder with its siblings - on disk only the index tells them apart.
  ================================================================== }

type
  { Everything a TPrimitive2D wrote, gathered before the object exists:
    the new constructors want their points up front, and a two-cornered
    shape will not let points be added afterwards. }
  TLegacyPrimitive = record
    ID: LongInt;
    Layer: Byte;
    Visible, Enabled, ToBeSaved: Boolean;
    Transform: TTransf2D;
    Points: array of TPoint2D;
    Growing: Boolean;
  end;

procedure ReadObject2DHeader(const R: TCADLegacyReader;
  var APrim: TLegacyPrimitive);
var
  TmpMask: Byte;
begin
  APrim.ID := R.ReadInt;
  APrim.Layer := R.ReadByte;
  TmpMask := R.ReadByte;
  APrim.Visible := (TmpMask and 1) <> 0;
  APrim.Enabled := (TmpMask and 2) <> 0;
  { Inverted on purpose: the bit meant 'not to be saved'. }
  APrim.ToBeSaved := (TmpMask and 4) = 0;
  APrim.Transform := R.ReadTransform;
end;

function ReadPrimitive(const R: TCADLegacyReader): TLegacyPrimitive;
var
  TmpCount, Cont: Integer;
begin
  ReadObject2DHeader(R, Result);
  TmpCount := R.ReadWord;
  SetLength(Result.Points, TmpCount);
  for Cont := 0 to TmpCount - 1 do
    Result.Points[Cont] := R.ReadPoint;
  Result.Growing := R.ReadBool;
end;

procedure ApplyHeader(const AObj: TObject2D; const APrim: TLegacyPrimitive);
begin
  AObj.ID := APrim.ID;
  AObj.Layer := APrim.Layer;
  AObj.Visible := APrim.Visible;
  AObj.Enabled := APrim.Enabled;
  AObj.ToBeSaved := APrim.ToBeSaved;
  AObj.ModelTransform := APrim.Transform;
end;

{ Curves added a precision and a saving type on top of the points. }
procedure ReadCurveTail(const R: TCADLegacyReader; const ACurve: TCurve2D);
var
  TmpPrec: Word;
  TmpSaving: Byte;
begin
  TmpPrec := R.ReadWord;
  TmpSaving := R.ReadByte;
  if TmpPrec > 0 then
    ACurve.CurvePrecision := TmpPrec;
  if TmpSaving <= Ord(High(TPrimitiveSavingType)) then
    ACurve.SavingType := TPrimitiveSavingType(TmpSaving);
end;

function BuildLine2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
begin
  TmpPrim := ReadPrimitive(AReader);
  if Length(TmpPrim.Points) < 2 then
    Raise ECADLegacyFormat.Create('A line with fewer than two points');
  Result := TLine2D.Create(TmpPrim.ID, TmpPrim.Points[0], TmpPrim.Points[1]);
  ApplyHeader(Result, TmpPrim);
end;

function BuildPolyline2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
begin
  TmpPrim := ReadPrimitive(AReader);
  Result := TPolyline2D.Create(TmpPrim.ID, TmpPrim.Points);
  ApplyHeader(Result, TmpPrim);
end;

function BuildPolygon2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
begin
  TmpPrim := ReadPrimitive(AReader);
  Result := TPolygon2D.Create(TmpPrim.ID, TmpPrim.Points);
  ApplyHeader(Result, TmpPrim);
end;

{ Rectangle, frame, ellipse and filled ellipse are all two corners and
  a curve tail; only the index tells them apart. }
function BuildTwoCornerCurve(const AReader: TCADLegacyReader;
  const AID: LongInt; const AClass: TPrimitive2DClass): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
begin
  TmpPrim := ReadPrimitive(AReader);
  if Length(TmpPrim.Points) < 2 then
    Raise ECADLegacyFormat.Create('A two-cornered shape with fewer than ' +
      'two points');
  if AClass = TRectangle2D then
    Result := TRectangle2D.Create(TmpPrim.ID, TmpPrim.Points[0],
      TmpPrim.Points[1])
  else if AClass = TFrame2D then
    Result := TFrame2D.Create(TmpPrim.ID, TmpPrim.Points[0], TmpPrim.Points[1])
  else if AClass = TFilledEllipse2D then
    Result := TFilledEllipse2D.Create(TmpPrim.ID, TmpPrim.Points[0],
      TmpPrim.Points[1])
  else
    Result := TEllipse2D.Create(TmpPrim.ID, TmpPrim.Points[0],
      TmpPrim.Points[1]);
  ApplyHeader(Result, TmpPrim);
  ReadCurveTail(AReader, TCurve2D(Result));
end;

function BuildRectangle2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
begin
  Result := BuildTwoCornerCurve(AReader, AID, TRectangle2D);
end;

function BuildFrame2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
begin
  Result := BuildTwoCornerCurve(AReader, AID, TFrame2D);
end;

function BuildEllipse2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
begin
  Result := BuildTwoCornerCurve(AReader, AID, TEllipse2D);
end;

function BuildFilledEllipse2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
begin
  Result := BuildTwoCornerCurve(AReader, AID, TFilledEllipse2D);
end;

function BuildArc2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpArc: TArc2D;
  TmpDir: Byte;
  Cont: Integer;
begin
  TmpPrim := ReadPrimitive(AReader);
  if Length(TmpPrim.Points) < 4 then
    Raise ECADLegacyFormat.Create('An arc with fewer than four points');
  { The angles were never streamed: an arc keeps four control points,
    two for the bounding box and two that give the start and end
    angles, and GetArcParams derives the angles from them. So the
    points are put back and the angles follow. }
  TmpArc := TArc2D.Create(TmpPrim.ID, TmpPrim.Points[0], TmpPrim.Points[1],
    0, 0);
  Result := TmpArc;
  for Cont := 2 to 3 do
    TmpArc.Points[Cont] := TmpPrim.Points[Cont];
  ApplyHeader(Result, TmpPrim);
  ReadCurveTail(AReader, TmpArc);
  TmpDir := AReader.ReadByte;
  if TmpDir <= Ord(High(TArcDirection)) then
    TmpArc.Direction := TArcDirection(TmpDir);
end;

function BuildBSpline2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpSpline: TBSpline2D;
  TmpOrder: Byte;
begin
  TmpPrim := ReadPrimitive(AReader);
  TmpSpline := TBSpline2D.Create(TmpPrim.ID, TmpPrim.Points);
  Result := TmpSpline;
  ApplyHeader(Result, TmpPrim);
  ReadCurveTail(AReader, TmpSpline);
  TmpOrder := AReader.ReadByte;
  if TmpOrder > 0 then
    TmpSpline.Order := TmpOrder;
end;

{ Containers hold their children inline, each behind its own class
  index, so this recurses. }
function BuildContainer2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpCount, Cont: LongInt;
  TmpCont: TContainer2D;
begin
  ReadObject2DHeader(AReader, TmpPrim);
  TmpCont := TContainer2D.Create(TmpPrim.ID, []);
  Result := TmpCont;
  ApplyHeader(Result, TmpPrim);
  TmpCount := AReader.ReadInt;
  if (TmpCount < 0) or (TmpCount > AReader.Stream.Size) then
    Raise ECADLegacyFormat.CreateFmt('A container claims %d children',
      [TmpCount]);
  for Cont := 1 to TmpCount do
    TmpCont.Objects.Add(AReader.ReadObject);
end;

function BuildSourceBlock2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpCount, Cont: LongInt;
  TmpBlock: TSourceBlock2D;
  TmpName: string;
  TmpSaved, TmpLibrary: Boolean;
begin
  { A source block is a container plus three fields of its own. }
  ReadObject2DHeader(AReader, TmpPrim);
  TmpCount := AReader.ReadInt;
  if (TmpCount < 0) or (TmpCount > AReader.Stream.Size) then
    Raise ECADLegacyFormat.CreateFmt('A source block claims %d children',
      [TmpCount]);
  TmpBlock := TSourceBlock2D.Create(TmpPrim.ID, StringToBlockName(''), []);
  Result := TmpBlock;
  ApplyHeader(Result, TmpPrim);
  for Cont := 1 to TmpCount do
    TmpBlock.Objects.Add(AReader.ReadObject);

  { ToBeSaved a second time, overriding the bit in the header - the old
    class wrote it twice and the second one won. }
  TmpSaved := AReader.ReadBool;
  TmpLibrary := AReader.ReadBool;
  TmpName := AReader.ReadFixedString(13);
  TmpBlock.ToBeSaved := TmpSaved;
  TmpBlock.IsLibraryBlock := TmpLibrary;
  TmpBlock.Name := StringToBlockName(TmpName);
end;

function BuildBlock2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpBlock: TBlock2D;
  TmpName: string;
  TmpOrigin: TPoint2D;
begin
  { A block descends from TObject2D, not from the container, and names
    its source rather than pointing at it. The link is made by the
    caller once every source block is in. }
  ReadObject2DHeader(AReader, TmpPrim);
  TmpName := AReader.ReadFixedString(13);
  TmpOrigin := AReader.ReadPoint;
  TmpBlock := TBlock2D.CreateUnlinked(TmpPrim.ID,
    StringToBlockName(TmpName), TmpOrigin);
  Result := TmpBlock;
  ApplyHeader(Result, TmpPrim);
end;

function BuildJustifiedVectText2D(const AReader: TCADLegacyReader;
  const AID: LongInt): TObject2D;
var
  TmpPrim: TLegacyPrimitive;
  TmpText: TJustifiedVectText2D;
  TmpStr: string;
  TmpFontIdx: LongInt;
  TmpFont: TVectFont;
  TmpHJust, TmpVJust: Byte;
  TmpDrawBox: Boolean;
  TmpHeight, TmpInterLine, TmpCharSpace: TRealType;
begin
  TmpPrim := ReadPrimitive(AReader);
  if Length(TmpPrim.Points) < 2 then
    Raise ECADLegacyFormat.Create('Vector text with fewer than two points');
  TmpStr := AReader.ReadCountedString;
  TmpFontIdx := AReader.ReadInt;
  TmpHJust := AReader.ReadByte;
  TmpVJust := AReader.ReadByte;
  TmpDrawBox := AReader.ReadBool;
  TmpHeight := AReader.ReadReal;
  TmpInterLine := AReader.ReadReal;
  TmpCharSpace := AReader.ReadReal;

  { The font is a registration index, and it always was - the new JSON
    stores the very same number. So this is not a migration problem at
    all: whatever CADSysRegisterFont calls the application makes at
    startup resolve the index before and after, identically. If the
    index is unregistered the object still loads without a font, which
    is what the JSON loader does too. }
  TmpFont := nil;
  try
    TmpFont := CADSysFindFontByIndex(TmpFontIdx);
  except
    on ECADObjClassNotFound do
      CADSysWarn('Vector font ' + IntToStr(TmpFontIdx) +
        ' is not registered. The text will load without a font.');
  end;

  TmpText := TJustifiedVectText2D.Create(TmpPrim.ID, TmpFont,
    Rect2D(TmpPrim.Points[0].X, TmpPrim.Points[0].Y, TmpPrim.Points[1].X,
    TmpPrim.Points[1].Y), TmpHeight, AnsiString(TmpStr));
  Result := TmpText;
  ApplyHeader(Result, TmpPrim);
  if TmpHJust <= Ord(High(THJustification)) then
    TmpText.HorizontalJust := THJustification(TmpHJust);
  if TmpVJust <= Ord(High(TVJustification)) then
    TmpText.VerticalJust := TVJustification(TmpVJust);
  TmpText.DrawBox := TmpDrawBox;
  TmpText.InterLine := TmpInterLine;
  TmpText.CharSpace := TmpCharSpace;
end;

{ ==================================================================
  Entry points
  ================================================================== }

procedure CADLoadLegacyStream(const AStream: TStream;
  const ACAD: TFNCCADCmp2D);
var
  TmpReader: TCADLegacyReader;
begin
  ACAD.DeleteAllObjects;
  ACAD.DeleteSavedSourceBlocks;
  TmpReader := TCADLegacyReader.Create(AStream, ACAD);
  try
    TmpReader.Execute;
  finally
    TmpReader.Free;
  end;
  ACAD.RepaintViewports;
end;

procedure CADLoadLegacyFile(const AFileName: string;
  const ACAD: TFNCCADCmp2D);
var
  TmpStream: TFileStream;
begin
  TmpStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    CADLoadLegacyStream(TmpStream, ACAD);
  finally
    TmpStream.Free;
  end;
end;

initialization

{ So that TFNCCADCmp2D.LoadLegacyStream works for anyone who has this
  unit in the program, without FNCCADSys4 having to know it exists. }
CADLegacyLoader := CADLoadLegacyStream;

RegisterLegacyClass(LegacyContainer2D, BuildContainer2D);
RegisterLegacyClass(LegacySourceBlock2D, BuildSourceBlock2D);
RegisterLegacyClass(LegacyBlock2D, BuildBlock2D);
RegisterLegacyClass(LegacyLine2D, BuildLine2D);
RegisterLegacyClass(LegacyPolyline2D, BuildPolyline2D);
RegisterLegacyClass(LegacyPolygon2D, BuildPolygon2D);
RegisterLegacyClass(LegacyRectangle2D, BuildRectangle2D);
RegisterLegacyClass(LegacyArc2D, BuildArc2D);
RegisterLegacyClass(LegacyEllipse2D, BuildEllipse2D);
RegisterLegacyClass(LegacyFilledEllipse2D, BuildFilledEllipse2D);
RegisterLegacyClass(LegacyFrame2D, BuildFrame2D);
RegisterLegacyClass(LegacyBSpline2D, BuildBSpline2D);
RegisterLegacyClass(LegacyJustifiedVectText2D, BuildJustifiedVectText2D);

{ Indices 10 and 12 - TText2D and TBitmap2D - are left unregistered on
  purpose, and a drawing holding one gets a clear "class index not
  registered" rather than a silently mangled object.

  Neither can be read without deciding something first. TText2D's text
  was declared AnsiString but written as count * SizeOf(Char), so files
  from a Unicode build hold twice the bytes the string has and the
  second half is heap rubbish - readable, but only by resynchronising
  on the LOGFONT that follows, and that wants a real file to test
  against. TBitmap2D embeds a bare Windows BMP with no length prefix,
  so the reader has to parse the BMP headers to find where the record
  ends. Both are worth doing when a drawing needs them.

  An unregistered class is fatal rather than skippable, and has to be:
  records carry no length, so a reader that does not know a class
  cannot find the end of it. }

end.
