{ : DUnitX tests for loading and saving a drawing through a streaming JSON
  writer and reader, and for mapping classes while a drawing loads.

  The yardstick is the tree path. SaveToJSON and LoadFromJSON have been
  in use since the format was written; the streaming path is right when
  it produces the same document and the same drawing, and these tests
  compare the two rather than restating what either should contain.
  "The same" is checked after parsing both texts again, so that member
  order, numbers and strings must agree while white space and escaping
  are free to differ.
}
unit CADSys4.Tests.Streaming;

interface

uses
  DUnitX.TestFramework,
  VCL.FNCCADSys4;

type
  [TestFixture]
  TJSONStreamingTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FProgress: TArray<Integer>;
    procedure OnProgress(Sender: TObject; ReadPercent: Byte);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TheWriterWritesWhatTheTreeWrites;
    [Test]
    procedure TheReaderLoadsWhatTheTreeLoads;
    [Test]
    procedure WriterToReaderGivesTheSameDrawing;
    [Test]
    procedure AnEmptyDrawingRoundTrips;
    [Test]
    procedure ALargeDrawingRoundTrips;
    [Test]
    procedure TheObjectCountLeavesOutWhatIsNotSaved;
    [Test]
    procedure ProgressReachesAHundred;
    [Test]
    procedure WithoutAnObjectCountProgressStillFinishes;
    [Test]
    procedure TheReaderStopsAtTheEndOfTheDrawing;
    [Test]
    procedure TheWriterWritesOneValueInsideAnotherDocument;
    [Test]
    procedure UnknownMembersAreSkipped;
    [Test]
    procedure AHeaderAfterTheContentIsRejected;
    [Test]
    procedure BlocksAfterObjectsAreRejected;
    [Test]
    procedure AWrongKindIsRejected;
    [Test]
    procedure TextThatLooksLikeADateStaysText;
    [Test]
    procedure MergingAppends;
  end;

  [TestFixture]
  TObjectClassMapTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FCalls: Integer;
    procedure MapLines(Sender: TObject; const ATypeName: String;
      var AClass: TGraphicObjectClass);
    procedure MapUnknown(Sender: TObject; const ATypeName: String;
      var AClass: TGraphicObjectClass);
    procedure MapAndFail(Sender: TObject; const ATypeName: String;
      var AClass: TGraphicObjectClass);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ModelLinesAreCreatedAsTheMappedClass;
    [Test]
    procedure LinesInBlocksContainersAndSheetsAreMappedToo;
    [Test]
    procedure TheReaderMapsTheSameWay;
    [Test]
    procedure AnUnregisteredTypeCanBeGivenAClass;
    [Test]
    procedure TheMapEndsWithTheLoad;
    [Test]
    procedure TheMapEndsEvenWhenTheLoadFails;
    [Test]
    procedure NoHandlerMeansNoMapping;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.JSON,
  System.JSON.Types,
  System.JSON.Readers,
  System.JSON.Writers,
  { TValue, which the reader hands its values back in. }
  System.Rtti,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCS4Graphics,
  VCL.FNCCS4JSON,
  VCL.FNCCS4Views,
  VCL.FNCCS4Shapes,
  { Its initialization section fills the class registry. }
  VCL.FNCCadSysRegister;

type
  { What an application's own line looks like to the library: a TLine2D
    descendant with nothing of its own. Not registered, on purpose - the
    map is what creates it. }
  TMappedLine2D = class(TLine2D)
  end;

{ ------------------------------------------------------------------ }

{ The text parsed and written again, compact: member order, numbers and
  strings survive, white space and escaping do not. }
function Canonical(const AText: string): string;
var
  TmpValue: TJSONValue;
begin
  TmpValue := TJSONObject.ParseJSONValue(AText);
  Assert.IsNotNull(TmpValue, 'the text parses');
  try
    Result := TmpValue.ToJSON;
  finally
    TmpValue.Free;
  end;
end;

{ Whether AProc raises AClass. Spelled out rather than through
  Assert.WillRaise, which would not take these anonymous methods. }
function Raises(const AProc: TProc; const AClass: ExceptClass): Boolean;
begin
  Result := False;
  try
    AProc;
  except
    on E: Exception do
    begin
      if not(E is AClass) then
        Raise;
      Result := True;
    end;
  end;
end;

function StreamedText(const ACAD: TFNCCADCmp): string;
var
  TmpText: TStringWriter;
  TmpWriter: TJsonTextWriter;
begin
  TmpText := TStringWriter.Create;
  try
    TmpWriter := TJsonTextWriter.Create(TmpText);
    try
      ACAD.SaveToJSONWriter(TmpWriter);
      TmpWriter.Flush;
    finally
      TmpWriter.Free;
    end;
    Result := TmpText.ToString;
  finally
    TmpText.Free;
  end;
end;

{ AText loaded through the tree and saved again - what the streaming
  reader has to match. Not the text itself: the tree path does not give
  back everything it was given either (a source block comes back on the
  layer that is current when it is added, not the one it was saved on),
  and the reader's promise is to load what the tree loads. }
function TreeReloaded(const AText: string): string;
var
  TmpCAD: TFNCCADCmp2D;
begin
  TmpCAD := TFNCCADCmp2D.Create(nil);
  try
    TmpCAD.LoadFromJSONString(AText);
    Result := TmpCAD.SaveToJSONString(False);
  finally
    TmpCAD.Free;
  end;
end;

procedure LoadStreamed(const ACAD: TFNCCADCmp; const AText: string;
  const AMerge: Boolean = False);
var
  TmpText: TStringReader;
  TmpReader: TJsonTextReader;
begin
  TmpText := TStringReader.Create(AText);
  try
    TmpReader := TJsonTextReader.Create(TmpText);
    try
      if AMerge then
        ACAD.MergeFromJSONReader(TmpReader)
      else
        ACAD.LoadFromJSONReader(TmpReader);
    finally
      TmpReader.Free;
    end;
  finally
    TmpText.Free;
  end;
end;

{ One of everything the format has a place for: modified layers, every
  2D shape family the registry knows without a font or an image, a
  source block with an instance, a container, a sheet with its own
  objects and two viewports - one with a view of its own and one linked
  to a named view. Coordinates that are not round, so that a number
  that loses a digit on the way shows. }
procedure BuildRichDrawing(const ACAD: TFNCCADCmp2D);
var
  TmpSource: TSourceBlock2D;
  TmpSheet: TCADSheet;
  TmpPort: TCADSheetViewport;
  TmpView: TCADNamedView;
begin
  ACAD.Layers[3].Name := 'Walls';
  ACAD.Layers[3].Pen.Color := TCADColor($FFFF0000);
  ACAD.Layers[4].Name := 'Doors';
  ACAD.CurrentLayer := 3;
  ACAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1 / 3, Pi)));
  ACAD.AddObject(-1, TPolyline2D.Create(-1, [Point2D(0, 0), Point2D(10, 0),
    Point2D(10, 1E-7)]));
  ACAD.AddObject(-1, TPolygon2D.Create(-1, [Point2D(0, 0), Point2D(5, 0),
    Point2D(2.5, 4.330127)]));
  ACAD.AddObject(-1, TFrame2D.Create(-1, Point2D(-1, -1), Point2D(1e6, 2e6)));
  ACAD.CurrentLayer := 4;
  ACAD.AddObject(-1, TRectangle2D.Create(-1, Point2D(1, 1), Point2D(2, 3)));
  ACAD.AddObject(-1, TArc2D.Create(-1, Point2D(0, 0), Point2D(4, 4), 0,
    Pi / 2));
  ACAD.AddObject(-1, TEllipse2D.Create(-1, Point2D(5, 5), Point2D(9, 7)));
  ACAD.AddObject(-1, TFilledEllipse2D.Create(-1, Point2D(5, 5),
    Point2D(6, 6)));
  ACAD.AddObject(-1, TBSpline2D.Create(-1, [Point2D(0, 0), Point2D(1, 2),
    Point2D(3, 3), Point2D(4, 0), Point2D(6, 1)]));
  ACAD.AddObject(-1, TText2D.Create(-1, Rect2D(0, 0, 10, 3), 2.5,
    AnsiString('Plan 1:50')));

  TmpSource := TSourceBlock2D.Create(-1, StringToBlockName('DOOR'),
    [TLine2D.Create(0, Point2D(0, 0), Point2D(0, 2)),
    TLine2D.Create(1, Point2D(0, 2), Point2D(1, 2))]);
  ACAD.AddSourceBlock(TmpSource);
  ACAD.AddObject(-1, TBlock2D.Create(-1, TmpSource));
  ACAD.AddObject(-1, TContainer2D.Create(-1,
    [TLine2D.Create(0, Point2D(7, 7), Point2D(8, 8)),
    TFrame2D.Create(1, Point2D(7, 7), Point2D(9, 9))]));

  TmpSheet := ACAD.Sheets.Add('Sheet 1');
  TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10),
    Point2D(410, 287)));
  TmpSheet.AddObject(TLine2D.Create(-1, Point2D(10, 30), Point2D(410, 30)));
  TmpPort := TmpSheet.AddViewport;
  TmpPort.Name := 'Main';
  TmpPort.RectMM := Rect2D(15, 40, 300, 280);
  TmpView := ACAD.Views.Add('Detail',
    CADViewFromArea(Rect2D(0, 0, 5, 5)));
  TmpPort := TmpSheet.AddViewport;
  TmpPort.Name := 'Detail';
  TmpPort.RectMM := Rect2D(310, 180, 400, 280);
  TmpPort.UnitsPerMM := 0.25;
  TmpPort.LinkTo(TmpView);
end;

{ ==================================================================
  TJSONStreamingTests
  ================================================================== }

procedure TJSONStreamingTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FProgress := nil;
end;

procedure TJSONStreamingTests.TearDown;
begin
  FCAD.Free;
end;

procedure TJSONStreamingTests.OnProgress(Sender: TObject; ReadPercent: Byte);
begin
  FProgress := FProgress + [Integer(ReadPercent)];
end;

procedure TJSONStreamingTests.TheWriterWritesWhatTheTreeWrites;
begin
  BuildRichDrawing(FCAD);
  { The whole promise in one line: member for member, value for value. }
  Assert.AreEqual(Canonical(FCAD.SaveToJSONString(False)),
    Canonical(StreamedText(FCAD)));
end;

procedure TJSONStreamingTests.TheReaderLoadsWhatTheTreeLoads;
var
  TmpText: string;
  TmpBack: TFNCCADCmp2D;
begin
  BuildRichDrawing(FCAD);
  TmpText := FCAD.SaveToJSONString(False);
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    LoadStreamed(TmpBack, TmpText);
    { Saved again through the tree: if the reader dropped, renamed or
      rounded anything the tree path keeps, the two documents differ. }
    Assert.AreEqual(Canonical(TreeReloaded(TmpText)),
      Canonical(TmpBack.SaveToJSONString(False)));
    Assert.AreEqual(FCAD.ObjectsCount, TmpBack.ObjectsCount, 'objects');
    Assert.AreEqual(1, TmpBack.SourceBlocksCount, 'the source block');
    Assert.IsNotNull((TmpBack.GetObject(10) as TBlock2D).SourceBlock,
      'the instance found its source');
    Assert.AreEqual(1, TmpBack.Sheets.Count, 'the sheet');
    Assert.AreEqual(2, TmpBack.Sheets[0].ObjectsCount, 'its own objects');
    Assert.AreSame(TObject(TmpBack.Views[0]),
      TObject(TmpBack.Sheets[0].Viewports[1].LinkedView(TmpBack)),
      'and the link found its view');
  finally
    TmpBack.Free;
  end;
end;

procedure TJSONStreamingTests.WriterToReaderGivesTheSameDrawing;
var
  TmpBack: TFNCCADCmp2D;
begin
  BuildRichDrawing(FCAD);
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    LoadStreamed(TmpBack, StreamedText(FCAD));
    Assert.AreEqual(Canonical(TreeReloaded(FCAD.SaveToJSONString(False))),
      Canonical(TmpBack.SaveToJSONString(False)));
  finally
    TmpBack.Free;
  end;
end;

procedure TJSONStreamingTests.AnEmptyDrawingRoundTrips;
var
  TmpBack: TFNCCADCmp2D;
begin
  Assert.AreEqual(Canonical(FCAD.SaveToJSONString(False)),
    Canonical(StreamedText(FCAD)), 'written');
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
    LoadStreamed(TmpBack, StreamedText(FCAD));
    Assert.AreEqual(0, TmpBack.ObjectsCount,
      'and loading it replaced what was there');
  finally
    TmpBack.Free;
  end;
end;

procedure TJSONStreamingTests.ALargeDrawingRoundTrips;
const
  COUNT = 20000;
var
  Cont: Integer;
  TmpBack: TFNCCADCmp2D;
  TmpStart: TDateTime;
  TmpText: string;
begin
  { Not a benchmark - a build machine is not one - but large enough that
    a per-object mistake in the bookkeeping would show, and the times
    go to the log for whoever reads it. }
  for Cont := 0 to COUNT - 1 do
    FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(Cont, Cont / 7),
      Point2D(Cont + 0.5, Cont / 3)));
  TmpStart := Now;
  TmpText := StreamedText(FCAD);
  WriteLn(
    Format('streamed save of %d lines: %d ms, %d characters',
    [COUNT, Round((Now - TmpStart) * MSecsPerDay), Length(TmpText)]));
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpStart := Now;
    LoadStreamed(TmpBack, TmpText);
    WriteLn(
      Format('streamed load of %d lines: %d ms',
      [COUNT, Round((Now - TmpStart) * MSecsPerDay)]));
    Assert.AreEqual(COUNT, TmpBack.ObjectsCount, 'every line');
    Assert.AreEqual(Canonical(FCAD.SaveToJSONString(False)),
      Canonical(TmpBack.SaveToJSONString(False)), 'and the same lines');
  finally
    TmpBack.Free;
  end;
end;

procedure TJSONStreamingTests.TheObjectCountLeavesOutWhatIsNotSaved;
var
  TmpDoc: TJSONObject;
begin
  FCAD.CurrentLayer := 0;
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(2, 2)));
  FCAD.CurrentLayer := 7;
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(3, 3)));
  FCAD.Layers[7].Streamable := False;
  TmpDoc := FCAD.SaveToJSON;
  try
    Assert.AreEqual(Int64(2), JGetInt(TmpDoc, 'objectCount', -1),
      'the count is of what is written, not of what is in the drawing');
    Assert.AreEqual(2, JGetArray(TmpDoc, 'objects').Count,
      'and agrees with it');
  finally
    TmpDoc.Free;
  end;
end;

procedure TJSONStreamingTests.ProgressReachesAHundred;
var
  Cont: Integer;
  TmpBack: TFNCCADCmp2D;
begin
  for Cont := 0 to 249 do
    FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(Cont, 0), Point2D(0, Cont)));
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.OnLoadProgress := OnProgress;
    LoadStreamed(TmpBack, StreamedText(FCAD));
    Assert.IsTrue(Length(FProgress) > 10, 'it moved in steps');
    Assert.AreEqual(100, FProgress[High(FProgress)], 'and finished');
    Assert.IsTrue(Length(FProgress) <= 100, 'once per percent at most');
  finally
    TmpBack.Free;
  end;
end;

procedure TJSONStreamingTests.WithoutAnObjectCountProgressStillFinishes;
var
  TmpDoc: TJSONObject;
  TmpBack: TFNCCADCmp2D;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  { A document from before the count existed. }
  TmpDoc := FCAD.SaveToJSON;
  try
    TmpDoc.RemovePair('objectCount').Free;
    TmpBack := TFNCCADCmp2D.Create(nil);
    try
      TmpBack.OnLoadProgress := OnProgress;
      LoadStreamed(TmpBack, TmpDoc.ToJSON);
      Assert.AreEqual(1, TmpBack.ObjectsCount, 'it loads');
      Assert.AreEqual(1, Length(FProgress), 'one report, at the end');
      Assert.AreEqual(100, FProgress[0], 'saying it has finished');
    finally
      TmpBack.Free;
    end;
  finally
    TmpDoc.Free;
  end;
end;

procedure TJSONStreamingTests.TheReaderStopsAtTheEndOfTheDrawing;
var
  TmpText: TStringReader;
  TmpReader: TJsonTextReader;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  { The drawing inside a document of somebody else's, with members on
    both sides of it - which is what a .vpx is. }
  TmpText := TStringReader.Create('{"before":[1,{"x":2}],"drawing":' +
    StreamedText(FCAD) + ',"after":"still here"}');
  try
    TmpReader := TJsonTextReader.Create(TmpText);
    try
      Assert.IsTrue(TmpReader.Read and (TmpReader.TokenType =
        TJsonToken.StartObject), 'outer object');
      Assert.IsTrue(TmpReader.Read, 'before');
      Assert.IsTrue(TmpReader.Read, 'its value');
      TmpReader.Skip;
      Assert.IsTrue(TmpReader.Read and (TmpReader.Value.AsString = 'drawing'),
        'the drawing member');
      Assert.IsTrue(TmpReader.Read and (TmpReader.TokenType =
        TJsonToken.StartObject), 'on the drawing');
      FCAD.LoadFromJSONReader(TmpReader);
      Assert.AreEqual(Ord(TJsonToken.EndObject), Ord(TmpReader.TokenType),
        'left on the drawing''s own end');
      Assert.AreEqual(1, FCAD.ObjectsCount, 'the drawing loaded');
      Assert.IsTrue(TmpReader.Read and (TmpReader.Value.AsString = 'after'),
        'and the next member is the caller''s');
      Assert.IsTrue(TmpReader.Read and
        (TmpReader.Value.AsString = 'still here'), 'with its value');
    finally
      TmpReader.Free;
    end;
  finally
    TmpText.Free;
  end;
end;

procedure TJSONStreamingTests.TheWriterWritesOneValueInsideAnotherDocument;
var
  TmpText: TStringWriter;
  TmpWriter: TJsonTextWriter;
  TmpDoc: TJSONObject;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpText := TStringWriter.Create;
  try
    TmpWriter := TJsonTextWriter.Create(TmpText);
    try
      TmpWriter.WriteStartObject;
      TmpWriter.WritePropertyName('mine');
      TmpWriter.WriteValue(42);
      TmpWriter.WritePropertyName('drawing');
      FCAD.SaveToJSONWriter(TmpWriter);
      TmpWriter.WritePropertyName('more');
      TmpWriter.WriteValue('yes');
      TmpWriter.WriteEndObject;
      TmpWriter.Flush;
    finally
      TmpWriter.Free;
    end;
    TmpDoc := TextToJSONObject(TmpText.ToString);
    try
      Assert.AreEqual(Int64(42), JGetInt(TmpDoc, 'mine'), 'before');
      Assert.AreEqual('yes', JGetStr(TmpDoc, 'more'), 'after');
      Assert.AreEqual(Canonical(FCAD.SaveToJSONString(False)),
        JGetObject(TmpDoc, 'drawing').ToJSON, 'and the drawing between');
    finally
      TmpDoc.Free;
    end;
  finally
    TmpText.Free;
  end;
end;

procedure TJSONStreamingTests.UnknownMembersAreSkipped;
begin
  LoadStreamed(FCAD, '{"x":{"a":[1,2,{"b":null}]},' +
    '"format":"cadsys-json","version":"' + CADSysJSONVersion + '",' +
    '"kind":"drawing","mine":[{"b":1}],"alsoMine":true,' +
    '"objects":[{"type":"TLine2D","id":0,"layer":0,' +
    '"points":[[0,0],[1,1]]}],"last":"word"}');
  Assert.AreEqual(1, FCAD.ObjectsCount, 'ours loaded, theirs ignored');
end;

procedure TJSONStreamingTests.AHeaderAfterTheContentIsRejected;
begin
  Assert.IsTrue(Raises(
    procedure
    begin
      LoadStreamed(FCAD, '{"objects":[],"format":"cadsys-json",' +
        '"version":"' + CADSysJSONVersion + '","kind":"drawing"}');
    end, ECADFileNotValid),
    'a stream cannot go back and check what it has already loaded');
end;

procedure TJSONStreamingTests.BlocksAfterObjectsAreRejected;
begin
  Assert.IsTrue(Raises(
    procedure
    begin
      LoadStreamed(FCAD, '{"format":"cadsys-json","version":"' +
        CADSysJSONVersion + '","kind":"drawing","objects":[],"blocks":[]}');
    end, ECADFileNotValid), 'the instances would have had nothing to find');
end;

procedure TJSONStreamingTests.AWrongKindIsRejected;
begin
  Assert.IsTrue(Raises(
    procedure
    begin
      LoadStreamed(FCAD, '{"format":"cadsys-json","version":"' +
        CADSysJSONVersion + '","kind":"library","blocks":[]}');
    end, ECADFileNotValid), 'the same check as the tree path');
end;

procedure TJSONStreamingTests.TextThatLooksLikeADateStaysText;
var
  TmpText: TStringReader;
  TmpReader: TJsonTextReader;
begin
  FCAD.Sheets.Add('2026-10-12T09:30:00');
  FCAD.AddObject(-1, TText2D.Create(-1, Rect2D(0, 0, 10, 3), 2.5,
    AnsiString('2026-10-12')));
  TmpText := TStringReader.Create(StreamedText(FCAD));
  try
    TmpReader := TJsonTextReader.Create(TmpText);
    try
      TmpReader.DateParseHandling := TJsonDateParseHandling.DateTime;
      FCAD.LoadFromJSONReader(TmpReader);
      Assert.AreEqual(Ord(TJsonDateParseHandling.DateTime),
        Ord(TmpReader.DateParseHandling), 'the reader''s setting is put back');
    finally
      TmpReader.Free;
    end;
  finally
    TmpText.Free;
  end;
  Assert.AreEqual('2026-10-12T09:30:00', FCAD.Sheets[0].Name,
    'a sheet name');
  Assert.AreEqual('2026-10-12', string((FCAD.GetObject(0) as TText2D).Text),
    'and a text');
end;

procedure TJSONStreamingTests.MergingAppends;
var
  TmpOther: TFNCCADCmp2D;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpOther := TFNCCADCmp2D.Create(nil);
  try
    TmpOther.AddObject(-1, TLine2D.Create(-1, Point2D(5, 5), Point2D(6, 6)));
    TmpOther.Sheets.Add('Other');
    LoadStreamed(FCAD, StreamedText(TmpOther), True);
  finally
    TmpOther.Free;
  end;
  Assert.AreEqual(2, FCAD.ObjectsCount, 'both drawings'' objects');
  Assert.AreEqual(1, FCAD.Sheets.Count, 'and the merged sheet');
end;

{ ==================================================================
  TObjectClassMapTests
  ================================================================== }

procedure TObjectClassMapTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCalls := 0;
end;

procedure TObjectClassMapTests.TearDown;
begin
  FCAD.Free;
end;

procedure TObjectClassMapTests.MapLines(Sender: TObject;
  const ATypeName: String; var AClass: TGraphicObjectClass);
begin
  Inc(FCalls);
  Assert.AreSame(TObject(FCAD), Sender, 'the drawing that is loading asks');
  if AClass = TLine2D then
    AClass := TMappedLine2D;
end;

procedure TObjectClassMapTests.MapUnknown(Sender: TObject;
  const ATypeName: String; var AClass: TGraphicObjectClass);
begin
  if ATypeName = 'TNoSuchLine' then
  begin
    Assert.IsTrue(AClass = nil, 'unregistered, so nothing to start from');
    AClass := TLine2D;
  end;
end;

procedure TObjectClassMapTests.MapAndFail(Sender: TObject;
  const ATypeName: String; var AClass: TGraphicObjectClass);
begin
  Raise EAbort.Create('the handler gave up');
end;

procedure TObjectClassMapTests.ModelLinesAreCreatedAsTheMappedClass;
var
  TmpText: string;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  FCAD.AddObject(-1, TFrame2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpText := FCAD.SaveToJSONString(False);
  FCAD.OnMapObjectClass := MapLines;
  FCAD.LoadFromJSONString(TmpText);
  Assert.AreEqual(TMappedLine2D, FCAD.GetObject(0).ClassType, 'the line');
  Assert.AreEqual(TFrame2D, FCAD.GetObject(1).ClassType,
    'and the frame left alone');
  Assert.AreEqual(1.0, (FCAD.GetObject(0) as TLine2D).Points[1].X, 1E-9,
    'with what the line said');
end;

procedure TObjectClassMapTests.LinesInBlocksContainersAndSheetsAreMappedToo;
var
  TmpText: string;
  TmpSource: TSourceBlock2D;
begin
  BuildRichDrawing(FCAD);
  TmpText := FCAD.SaveToJSONString(False);
  FCAD.OnMapObjectClass := MapLines;
  FCAD.LoadFromJSONString(TmpText);
  Assert.AreEqual(TMappedLine2D, FCAD.GetObject(0).ClassType, 'model');
  TmpSource := TSourceBlock2D(FCAD.FindSourceBlock(StringToBlockName('DOOR')));
  Assert.IsNotNull(TmpSource, 'the source block came back');
  Assert.AreEqual(TMappedLine2D,
    TmpSource.Objects.Find(0).ClassType, 'inside the source block');
  Assert.AreEqual(TMappedLine2D,
    (FCAD.GetObject(11) as TContainer2D).Objects.Find(0).ClassType,
    'inside a container');
  Assert.AreEqual(TMappedLine2D, FCAD.Sheets[0].GetObject(1).ClassType,
    'and on a sheet');
end;

procedure TObjectClassMapTests.TheReaderMapsTheSameWay;
var
  TmpText: string;
  TmpText2: TStringReader;
  TmpReader: TJsonTextReader;
begin
  BuildRichDrawing(FCAD);
  TmpText := FCAD.SaveToJSONString(False);
  FCAD.OnMapObjectClass := MapLines;
  TmpText2 := TStringReader.Create(TmpText);
  try
    TmpReader := TJsonTextReader.Create(TmpText2);
    try
      FCAD.LoadFromJSONReader(TmpReader);
    finally
      TmpReader.Free;
    end;
  finally
    TmpText2.Free;
  end;
  Assert.AreEqual(TMappedLine2D, FCAD.GetObject(0).ClassType, 'model');
  Assert.AreEqual(TMappedLine2D,
    TSourceBlock2D(FCAD.FindSourceBlock(StringToBlockName('DOOR'))).Objects.
    Find(0).ClassType, 'block');
  Assert.AreEqual(TMappedLine2D, FCAD.Sheets[0].GetObject(1).ClassType,
    'sheet');
end;

procedure TObjectClassMapTests.AnUnregisteredTypeCanBeGivenAClass;
begin
  FCAD.OnMapObjectClass := MapUnknown;
  FCAD.LoadFromJSONString('{"format":"cadsys-json","version":"' +
    CADSysJSONVersion + '","kind":"drawing","objects":[{"type":' +
    '"TNoSuchLine","id":0,"layer":0,"points":[[0,0],[2,3]]}]}');
  Assert.AreEqual(1, FCAD.ObjectsCount,
    'loaded rather than skipped as an unknown class');
  Assert.AreEqual(TLine2D, FCAD.GetObject(0).ClassType, 'as the chosen class');
end;

procedure TObjectClassMapTests.TheMapEndsWithTheLoad;
var
  TmpJSON: TJSONObject;
  TmpObj: TGraphicObject;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpJSON := CADSysObjectToJSON(FCAD.GetObject(0));
  try
    FCAD.OnMapObjectClass := MapLines;
    FCAD.LoadFromJSONString(FCAD.SaveToJSONString(False));
    Assert.AreEqual(1, FCalls, 'mapped while loading');
    { Outside a load nobody has asked for a map. }
    TmpObj := CADSysObjectFromJSON(TmpJSON);
    try
      Assert.AreEqual(TLine2D, TmpObj.ClassType, 'not mapped afterwards');
      Assert.AreEqual(1, FCalls, 'and the handler was not asked');
    finally
      TmpObj.Free;
    end;
  finally
    TmpJSON.Free;
  end;
end;

procedure TObjectClassMapTests.TheMapEndsEvenWhenTheLoadFails;
var
  TmpText: string;
  TmpJSON: TJSONObject;
  TmpObj: TGraphicObject;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpText := FCAD.SaveToJSONString(False);
  TmpJSON := CADSysObjectToJSON(FCAD.GetObject(0));
  try
    FCAD.OnMapObjectClass := MapAndFail;
    Assert.IsTrue(Raises(
      procedure
      begin
        FCAD.LoadFromJSONString(TmpText);
      end, EAbort), 'the handler''s exception gets out');
    TmpObj := CADSysObjectFromJSON(TmpJSON);
    try
      Assert.AreEqual(TLine2D, TmpObj.ClassType,
        'and the map did not stay behind');
    finally
      TmpObj.Free;
    end;
  finally
    TmpJSON.Free;
  end;
end;

procedure TObjectClassMapTests.NoHandlerMeansNoMapping;
var
  TmpState: TCADObjectClassMapState;
  TmpOther: TFNCCADCmp2D;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpOther := TFNCCADCmp2D.Create(nil);
  try
    { A load inside somebody else's map - a drawing loaded from within
      another drawing's handler - does not inherit it. }
    TmpState := CADSysPushObjectClassMap(FCAD, MapLines);
    try
      TmpOther.LoadFromJSONString(FCAD.SaveToJSONString(False));
    finally
      CADSysPopObjectClassMap(TmpState);
    end;
    Assert.AreEqual(TLine2D, TmpOther.GetObject(0).ClassType,
      'the other drawing has no handler of its own');
    Assert.AreEqual(0, FCalls, 'so nobody was asked');
  finally
    TmpOther.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TJSONStreamingTests);
TDUnitX.RegisterTestFixture(TObjectClassMapTests);

end.
