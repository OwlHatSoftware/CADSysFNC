{ : DUnitX tests for sheets - paper space (unit VCL.FNCCADSys4).

  Scope: TCADSheet and TCADSheetViewport as a model - the paper they
  sit on, the arithmetic that turns a viewport rectangle into a window
  of the drawing, and the round trip through the drawing's own JSON.

  CADDrawSheet is here too, against the recording canvas from
  CADSys4.Tests.Graphics - the only thing in this suite that can watch
  drawing happen. What it can watch is which calls were made in which
  order, not what the picture looks like; the demos are for that.
}
unit CADSys4.Tests.Sheets;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.JSON,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCS4JSON,
  VCL.FNCCS4Paper,
  VCL.FNCCS4Views,
  VCL.FNCCADSys4,
  VCL.FNCCS4Shapes,
  VCL.FNCCS4Graphics,
  VCL.FNCCS4Print,
  VCL.FNCCadSysRegister,
  CADSys4.Tests.Graphics;

type
  [TestFixture]
  TCADSheetModelTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ANewSheetIsA3Landscape;
    [Test]
    procedure TheMarginsComeOffTheSheetTheRightWayUp;
    [Test]
    procedure ACustomSheetTakesItsOwnSize;
    [Test]
    procedure AFittedViewportTakesTheLargerOfTheTwoRatios;
    [Test]
    procedure AFittedViewportCentresWhatItFrames;
    [Test]
    procedure AScaledViewportIgnoresTheWindowSize;
    [Test]
    procedure AViewportThatFramesNothingUsesTheDrawing;
    [Test]
    procedure AViewportWithNoAreaIsRefused;
    [Test]
    procedure AnEmptyDrawingIsRefusedRatherThanGuessed;
  end;

  [TestFixture]
  TCADSheetPersistenceTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    function Reload: TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ADrawingWithoutSheetsWritesNoSheetsMember;
    [Test]
    procedure APaperSetupSurvivesTheRoundTrip;
    [Test]
    procedure AViewportKeepsItsRectangleScaleAndView;
    [Test]
    procedure AnnotationTravelsWithTheSheet;
    [Test]
    procedure LoadingADrawingReplacesTheSheetsItHad;
    [Test]
    procedure PaperIsWrittenAsANameNotANumber;
    [Test]
    procedure AssignCopiesEverySheetField;
  end;

  [TestFixture]
  TCADSheetDrawingTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    { : A3 landscape at 25.4 dpi - one device pixel to the millimetre,
      so every number in these tests is a millimetre and can be read
      off the sheet with a ruler. }
    function Device: TCADPageDevice;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AViewportRectangleFlipsIntoDeviceRows;
    [Test]
    procedure TheViewportClipSitsInsideTheSheetClip;
    [Test]
    procedure TheModelIsDrawnThroughTheViewportAndTheAnnotationOverIt;
    [Test]
    procedure ABorderlessViewportDrawsNoOutline;
    [Test]
    procedure TheCanvasScaleIsPutBack;
  end;

  [TestFixture]
  TCADSheetHitTestTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    function Device: TCADPageDevice;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure APointOnThePaperIsMillimetres;
    [Test]
    procedure MillimetresAndPixelsAreEachOthersInverse;
    [Test]
    procedure AViewportIsFoundByItsRectangle;
    [Test]
    procedure TheViewportOnTopIsTheOneThatAnswers;
    [Test]
    procedure TheCentreOfAViewportIsTheCentreOfWhatItShows;
    [Test]
    procedure APointSurvivesTheRoundTripThroughTheModel;
    [Test]
    procedure APointOutsideAViewportStillTransforms;

  end;

implementation

{ ==================================================================
  TCADSheetModelTests
  ================================================================== }

procedure TCADSheetModelTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADSheetModelTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetModelTests.ANewSheetIsA3Landscape;
var
  TmpSheet: TCADSheet;
  TmpW, TmpH: TRealType;
begin
  TmpSheet := FCAD.Sheets.Add('Layout 1');
  Assert.AreEqual(1, FCAD.Sheets.Count, 'the drawing has one sheet');
  Assert.AreEqual(0, FCAD.Sheets.IndexOfName('layout 1'),
    'found by name, whatever the case');
  TmpSheet.SizeMM(TmpW, TmpH);
  { The table is portrait and the orientation swaps it - one routine
    does that for a sheet and for a page setup both. }
  Assert.AreEqual(420.0, TmpW, 1E-6, 'A3 landscape is 420 wide');
  Assert.AreEqual(297.0, TmpH, 1E-6, 'and 297 tall');
end;

procedure TCADSheetModelTests.TheMarginsComeOffTheSheetTheRightWayUp;
var
  TmpSheet: TCADSheet;
  TmpRect: TRect2D;
begin
  TmpSheet := FCAD.Sheets.Add;
  TmpSheet.Margins := TCADPageMargins.Sides(5, 6, 7, 8);
  Assert.AreEqual(0.0, TmpSheet.PaperRect2D.Left, 1E-6,
    'the paper starts at its own origin');
  TmpRect := TmpSheet.PrintableRect2D;
  { Y is upwards on a sheet, as it is in the model, so the TOP margin
    comes off the top of the paper - which is the high Y, not the low
    one. Getting this backwards is invisible with uniform margins,
    which is why these four differ. }
  Assert.AreEqual(5.0, TmpRect.Left, 1E-6, 'left margin');
  Assert.AreEqual(8.0, TmpRect.Bottom, 1E-6, 'bottom margin');
  Assert.AreEqual(413.0, TmpRect.Right, 1E-6, '420 less the right margin');
  Assert.AreEqual(291.0, TmpRect.Top, 1E-6, '297 less the top margin');
end;

procedure TCADSheetModelTests.ACustomSheetTakesItsOwnSize;
var
  TmpSheet: TCADSheet;
  TmpW, TmpH: TRealType;
begin
  TmpSheet := FCAD.Sheets.Add;
  TmpSheet.Paper := pkCustom;
  TmpSheet.CustomWidthMM := 500;
  TmpSheet.CustomHeightMM := 300;
  TmpSheet.Orientation := pgoPortrait;
  TmpSheet.SizeMM(TmpW, TmpH);
  Assert.AreEqual(500.0, TmpW, 1E-6, 'the custom width, unswapped');
  TmpSheet.Orientation := pgoLandscape;
  TmpSheet.SizeMM(TmpW, TmpH);
  Assert.AreEqual(300.0, TmpW, 1E-6,
    'and landscape swaps a custom size like any other');
  Assert.AreEqual(500.0, TmpH, 1E-6, 'the other way round');
end;

procedure TCADSheetModelTests.AFittedViewportTakesTheLargerOfTheTwoRatios;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpView := TmpVP.View;
  { 200 units across 100 mm is 2; 50 units down 50 mm is 1. All of it
    has to fit, so the answer is 2 - the smaller would run the drawing
    off the sides of the viewport. }
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  Assert.AreEqual(2.0, TmpVP.EffectiveUnitsPerMM(FCAD), 1E-9,
    'the ratio that makes everything fit');
end;

procedure TCADSheetModelTests.AFittedViewportCentresWhatItFrames;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpWin: TRect2D;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  TmpWin := TmpVP.ModelWindow(FCAD);
  { At 2 units to the millimetre the viewport holds 200 x 100 units.
    The window it was given is 200 x 50, centred on (100, 25), so the
    50 spare units are split evenly above and below rather than all
    falling on one side. }
  Assert.AreEqual(200.0, TmpWin.Right - TmpWin.Left, 1E-9,
    'as wide as the viewport can hold');
  Assert.AreEqual(100.0, TmpWin.Top - TmpWin.Bottom, 1E-9, 'and as tall');
  Assert.AreEqual(100.0, (TmpWin.Left + TmpWin.Right) / 2, 1E-9,
    'centred on the window it was given');
  Assert.AreEqual(25.0, (TmpWin.Bottom + TmpWin.Top) / 2, 1E-9,
    'in both directions');
  { And the shape of the window is the shape of the rectangle, which is
    what lets the transform be a plain stretch. }
  Assert.AreEqual((TmpWin.Right - TmpWin.Left) / (TmpWin.Top - TmpWin.Bottom),
    TmpVP.WidthMM / TmpVP.HeightMM, 1E-9, 'same proportions as the paper');
end;

procedure TCADSheetModelTests.AScaledViewportIgnoresTheWindowSize;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpWin: TRect2D;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpVP.UnitsPerMM := 10;
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  TmpWin := TmpVP.ModelWindow(FCAD);
  { 1:10 of a millimetre-drawn plan. The window it was given decides
    where it looks, not how big the picture is. }
  Assert.AreEqual(1000.0, TmpWin.Right - TmpWin.Left, 1E-9,
    '100 mm at ten units each');
  Assert.AreEqual(500.0, TmpWin.Top - TmpWin.Bottom, 1E-9, 'and 50 mm');
  Assert.AreEqual(100.0, (TmpWin.Left + TmpWin.Right) / 2, 1E-9,
    'still looking where it was pointed');
end;

procedure TCADSheetModelTests.AViewportThatFramesNothingUsesTheDrawing;
var
  TmpVP: TCADSheetViewport;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  { A new viewport frames nothing - deliberately, because
    TCADViewSpec.Default's -100..100 is a viewport's opening view and
    has no business on paper. An empty window means "the drawing". }
  Assert.AreEqual(3.0, TmpVP.EffectiveUnitsPerMM(FCAD), 1E-9,
    '300 units across 100 mm');
end;

procedure TCADSheetModelTests.AViewportWithNoAreaIsRefused;
var
  TmpVP: TCADSheetViewport;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  TmpVP := FCAD.Sheets.Add.AddViewport;
  { A rectangle nobody ever positioned. Dividing by it would give
    infinity and draw nothing, silently. }
  Assert.WillRaise(
    procedure
    begin
      TmpVP.ModelWindow(FCAD);
    end, ECADPageError, 'a viewport with no area cannot show anything');
end;

procedure TCADSheetModelTests.AnEmptyDrawingIsRefusedRatherThanGuessed;
var
  TmpVP: TCADSheetViewport;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  Assert.WillRaise(
    procedure
    begin
      TmpVP.ModelWindow(FCAD);
    end, ECADPageError, 'nothing to frame, and no made-up window either');
end;

{ ==================================================================
  TCADSheetPersistenceTests
  ================================================================== }

procedure TCADSheetPersistenceTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADSheetPersistenceTests.TearDown;
begin
  FCAD.Free;
end;

function TCADSheetPersistenceTests.Reload: TFNCCADCmp2D;
begin
  { Through the text, not through the object tree: a round trip that
    never becomes characters proves less than it looks. }
  Result := TFNCCADCmp2D.Create(nil);
  try
    Result.LoadFromJSONString(FCAD.SaveToJSONString);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TCADSheetPersistenceTests.ADrawingWithoutSheetsWritesNoSheetsMember;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  { A drawing with no paper space writes the file it wrote before
    sheets existed. Old readers keep working and old files keep
    comparing equal. }
  Assert.IsFalse(FCAD.SaveToJSONString.Contains('"sheets"'),
    'no empty array for a drawing that has none');
end;

procedure TCADSheetPersistenceTests.APaperSetupSurvivesTheRoundTrip;
var
  TmpSheet: TCADSheet;
  TmpBack: TFNCCADCmp2D;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  TmpSheet.Paper := pkA1;
  TmpSheet.Orientation := pgoPortrait;
  TmpSheet.Margins := TCADPageMargins.Sides(5, 6, 7, 8);
  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.Sheets.Count, 'one sheet came back');
    Assert.AreEqual('Plan', TmpBack.Sheets[0].Name, 'by name');
    Assert.AreEqual(Ord(pkA1), Ord(TmpBack.Sheets[0].Paper), 'paper');
    Assert.AreEqual(Ord(pgoPortrait), Ord(TmpBack.Sheets[0].Orientation),
      'orientation');
    Assert.AreEqual(6.0, TmpBack.Sheets[0].Margins.Top, 1E-9,
      'and each margin on its own side');
    Assert.AreEqual(8.0, TmpBack.Sheets[0].Margins.Bottom, 1E-9, 'bottom');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.AViewportKeepsItsRectangleScaleAndView;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpBack: TFNCCADCmp2D;
begin
  TmpVP := FCAD.Sheets.Add('Plan').AddViewport;
  TmpVP.Name := 'Detail';
  TmpVP.RectMM := Rect2D(20, 30, 220, 130);
  TmpVP.UnitsPerMM := 50;
  TmpVP.ShowBorder := False;
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(-10, -20, 90, 80);
  TmpView.UseLayerOverride := True;
  TmpView.HiddenLayers := [3, 7];
  TmpVP.View := TmpView;

  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.Sheets[0].ViewportCount, 'one viewport');
    TmpVP := TmpBack.Sheets[0].Viewports[0];
    Assert.AreEqual('Detail', TmpVP.Name, 'name');
    Assert.AreEqual(20.0, TmpVP.RectMM.Left, 1E-9, 'where it sits');
    Assert.AreEqual(130.0, TmpVP.RectMM.Top, 1E-9, 'and how big it is');
    Assert.AreEqual(50.0, TmpVP.UnitsPerMM, 1E-9, 'its scale');
    Assert.IsFalse(TmpVP.ShowBorder, 'and its border');
    { The view travels whole, as a page setup's does. }
    Assert.AreEqual(-10.0, TmpVP.View.Window.Left, 1E-9, 'the view window');
    Assert.IsTrue(TmpVP.View.UseLayerOverride, 'the layer override');
    Assert.IsTrue(7 in TmpVP.View.HiddenLayers, 'and which layers it hides');
    Assert.IsFalse(4 in TmpVP.View.HiddenLayers, 'and which it does not');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.AnnotationTravelsWithTheSheet;
var
  TmpSheet: TCADSheet;
  TmpBack: TFNCCADCmp2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  { A title block is ordinary shapes in the sheet's millimetres - which
    is the whole reason a sheet holds TObject2D rather than a format of
    its own. }
  TmpSheet.AddObject(TLine2D.Create(-1, Point2D(10, 10), Point2D(410, 10)));
  TmpSheet.AddObject(TLine2D.Create(-1, Point2D(410, 10), Point2D(410, 287)));
  Assert.AreEqual(2, TmpSheet.ObjectsCount, 'two lines on the sheet');
  { And they are the sheet's, not the drawing's. }
  Assert.AreEqual(0, FCAD.ObjectsCount, 'the model itself is still empty');

  TmpBack := Reload;
  try
    Assert.AreEqual(2, TmpBack.Sheets[0].ObjectsCount, 'both came back');
    TmpIter := TmpBack.Sheets[0].ObjectsIterator;
    try
      TmpObj := TmpIter.First;
      Assert.IsTrue(TmpObj is TLine2D, 'as the class they were');
      Assert.AreEqual(10.0, TLine2D(TmpObj).Points[0].X, 1E-9,
        'in the millimetres they were drawn in');
    finally
      TmpIter.Free;
    end;
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.LoadingADrawingReplacesTheSheetsItHad;
var
  TmpText: String;
begin
  FCAD.Sheets.Add('First');
  TmpText := FCAD.SaveToJSONString;
  FCAD.Sheets.Add('Second');
  Assert.AreEqual(2, FCAD.Sheets.Count, 'two before');
  { DeleteAllObjects does not touch paper space - a sheet is not one of
    the drawing's objects - so LoadFromJSON has to clear it itself.
    Without that, opening a drawing twice doubles its sheets. }
  FCAD.LoadFromJSONString(TmpText);
  Assert.AreEqual(1, FCAD.Sheets.Count, 'and one after');
  Assert.AreEqual('First', FCAD.Sheets[0].Name, 'the one in the file');
end;

procedure TCADSheetPersistenceTests.PaperIsWrittenAsANameNotANumber;
var
  TmpSheet: TCADSheet;
  TmpText: String;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  TmpSheet.Paper := pkA1;
  TmpText := FCAD.SaveToJSONString;
  { An ordinal is one insertion away from meaning something else: put
    an A7 between A5 and A4 and every saved sheet changes paper. }
  Assert.IsTrue(TmpText.Contains('"A1"'), 'the paper is named: ' + TmpText);
end;

procedure TCADSheetPersistenceTests.AssignCopiesEverySheetField;
var
  TmpSource, TmpCopy: TCADSheet;
begin
  TmpSource := FCAD.Sheets.Add('Plan');
  TmpSource.Paper := pkA2;
  TmpSource.Margins := TCADPageMargins.Uniform(15);
  TmpSource.AddObject(TLine2D.Create(-1, Point2D(1, 2), Point2D(3, 4)));
  TmpSource.AddViewport.RectMM := Rect2D(0, 0, 100, 50);

  TmpCopy := FCAD.Sheets.Add('Copy');
  TmpCopy.Assign(TmpSource);
  { Assign goes through the file format on purpose - it is the one
    place that already knows every field and every class of object
    that can be on a sheet. }
  Assert.AreEqual(Ord(pkA2), Ord(TmpCopy.Paper), 'the paper');
  Assert.AreEqual(15.0, TmpCopy.Margins.Left, 1E-9, 'the margins');
  Assert.AreEqual(1, TmpCopy.ViewportCount, 'the viewports');
  Assert.AreEqual(1, TmpCopy.ObjectsCount, 'and the annotation');
  Assert.AreEqual('Plan', TmpCopy.Name,
    'including the name - a copy of a sheet is a copy');
end;

{ ==================================================================
  TCADSheetDrawingTests
  ================================================================== }

function TCADSheetDrawingTests.Device: TCADPageDevice;
begin
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADSheetDrawingTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  { A model 300 units wide, and a viewport 100 mm wide to look at it
    through: three units to the millimetre, and nothing round about
    the numbers by accident. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetDrawingTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetDrawingTests.AViewportRectangleFlipsIntoDeviceRows;
var
  TmpRect: TRect;
begin
  TmpRect := CADSheetViewportRectPx(FSheet, FViewport, Device);
  { The sheet is 297 mm tall and its Y runs upwards; the device's runs
    down. So the viewport's top edge at 60 mm is device row 237, and
    its bottom edge at 10 mm is row 287. Taking the corners the other
    way round gives an inside-out rectangle, which clips away to
    nothing and draws a blank sheet without a word of complaint.

    Whole millimetres onto whole pixels, the same arithmetic the
    sheet's own rectangle uses. Through the sheet's visual transform
    this came out a pixel smaller, because that transform is laid out
    on pixel centres - right for drawing, wrong for two rectangles
    that have to meet. }
  Assert.AreEqual(10, TmpRect.Left, 'left');
  Assert.AreEqual(237, TmpRect.Top, '297 less the 60 mm top edge');
  Assert.AreEqual(110, TmpRect.Right, 'right');
  Assert.AreEqual(287, TmpRect.Bottom, '297 less the 10 mm bottom edge');
end;

procedure TCADSheetDrawingTests.TheViewportClipSitsInsideTheSheetClip;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: String;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    { Two levels, and this is the whole reason PushClip had to learn to
      nest. Before it did, the second push was dropped and a viewport
      was free to paint over the rest of the sheet. }
    Assert.IsTrue(TmpLog.Contains('PushClip 0,0,420,297'),
      'the sheet was clipped to the paper: ' + TmpLog);
    Assert.IsTrue(TmpLog.Contains('PushClip 10,237,110,287'),
      'and the viewport to its own rectangle: ' + TmpLog);
    Assert.AreEqual(2, TmpRec.CountOf('PushClip'), 'two clips went down');
    Assert.AreEqual(2, TmpRec.CountOf('PopClip'), 'and both came back');
    Assert.AreEqual(0, TmpRec.ClipDepth, 'nothing left in force');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.TheModelIsDrawnThroughTheViewportAndTheAnnotationOverIt;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpIdxViewport, TmpIdxAnnotation: Integer;
begin
  FSheet.AddObject(TLine2D.Create(-1, Point2D(10, 287), Point2D(410, 287)));
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { One polyline - the viewport's border. A TLine2D draws itself
      with MoveTo and LineTo, not as a polyline, so the two lines are
      counted by their MoveTo. }
    Assert.AreEqual(1, TmpRec.CountOf('Polyline'),
      'the viewport border, and only that: ' + TmpRec.Log.Text);
    Assert.AreEqual(2, TmpRec.CountOf('MoveTo'),
      'the model line and the sheet''s own line: ' + TmpRec.Log.Text);

    { The annotation was placed at 287 mm up a 297 mm sheet, so it
      lands on device row 10 - which is the Y flip proved by where it
      came out rather than by arithmetic repeated in the test. }
    TmpIdxAnnotation := TmpRec.Log.IndexOf('MoveTo 10,10');
    Assert.IsTrue(TmpIdxAnnotation >= 0,
      'the annotation was drawn in the sheet''s millimetres: '
      + TmpRec.Log.Text);
    TmpIdxViewport := TmpRec.Log.IndexOf('PopClip');
    { After the viewport gave its clip back, which is what puts a
      title block in front of the drawing rather than behind it. }
    Assert.IsTrue(TmpIdxAnnotation > TmpIdxViewport,
      'the annotation came after the viewport: ' + TmpRec.Log.Text);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.ABorderlessViewportDrawsNoOutline;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  FViewport.ShowBorder := False;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { Nothing left but the model line, which draws itself with MoveTo
      and LineTo. And a rectangle was never drawn: the border is a
      polyline on purpose, because a rectangle is filled with the
      brush and would hide what the viewport is for. }
    Assert.AreEqual(0, TmpRec.CountOf('Polyline'), 'no border');
    Assert.AreEqual(1, TmpRec.CountOf('MoveTo'), 'the model, still drawn');
    Assert.AreEqual(0, TmpRec.CountOf('Rectangle'),
      'and nothing that fills');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.TheCanvasScaleIsPutBack;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpRec.PixelsPerMM := 0;
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { The canvas may well be the screen's, and leaving a printer's
      millimetre scale on it makes every line drawn afterwards several
      times too thick. }
    Assert.AreEqual(0.0, TmpRec.PixelsPerMM, 1E-9,
      'the scale went back to what it was');
  finally
    TmpRec.Free;
  end;
end;

{ ==================================================================
  TCADSheetHitTestTests
  ================================================================== }

function TCADSheetHitTestTests.Device: TCADPageDevice;
begin
  { One device pixel to the millimetre, so every number below is a
    millimetre of A3 landscape paper. }
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADSheetHitTestTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  { 100 x 50 mm of paper over a 300 x 150 model: three units to the
    millimetre, so one device pixel here is three model units and the
    tolerances below are written in those. }
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetHitTestTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetHitTestTests.APointOnThePaperIsMillimetres;
var
  TmpPt: TPoint2D;
begin
  { Device row 287 on a 297 mm sheet is 10 mm up from the bottom edge,
    because the paper's Y runs upwards and the device's runs down.
    This is where a click on a title block has to land. }
  TmpPt := CADSheetPointToMM(FSheet, Device, Point(10, 287));
  Assert.AreEqual(10.0, TmpPt.X, 1E-9, 'ten millimetres in');
  Assert.AreEqual(10.0, TmpPt.Y, 1E-9, 'and ten up, not 287 down');

  TmpPt := CADSheetPointToMM(FSheet, Device, Point(410, 10));
  Assert.AreEqual(410.0, TmpPt.X, 1E-9, 'the far corner across');
  Assert.AreEqual(287.0, TmpPt.Y, 1E-9, 'and up');
end;

procedure TCADSheetHitTestTests.MillimetresAndPixelsAreEachOthersInverse;
var
  TmpPt: TPoint;
begin
  TmpPt := CADSheetMMToPoint(FSheet, Device, Point2D(15, 40));
  { The same arithmetic the viewport's own clip rectangle comes from -
    which is the point of writing it out rather than inverting the
    drawing transform, because that one is laid out on pixel centres
    and would disagree with the rectangle by half a pixel. }
  Assert.AreEqual(15, TmpPt.X, 'across');
  Assert.AreEqual(257, TmpPt.Y, '297 less 40');
  Assert.AreEqual(15.0, CADSheetPointToMM(FSheet, Device, TmpPt).X, 1E-9,
    'and back again');
  Assert.AreEqual(40.0, CADSheetPointToMM(FSheet, Device, TmpPt).Y, 1E-9,
    'both ways');
end;

procedure TCADSheetHitTestTests.AViewportIsFoundByItsRectangle;
begin
  { The viewport is 10..110 mm across and 10..60 up, so on the device
    it is rows 237..287. }
  Assert.AreEqual(0, CADSheetViewportIndexAt(FSheet, Device, Point(60, 262)),
    'the middle of it');
  Assert.AreEqual(-1, CADSheetViewportIndexAt(FSheet, Device, Point(60, 100)),
    'well above it - and the paper is not a viewport');
  Assert.AreEqual(-1, CADSheetViewportIndexAt(FSheet, Device, Point(200, 262)),
    'and to the right of it');
  Assert.IsNotNull(CADSheetViewportAt(FSheet, Device, Point(60, 262)),
    'the object form answers too');
  Assert.IsNull(CADSheetViewportAt(FSheet, Device, Point(400, 20)),
    'and nil where there is nothing');
end;

procedure TCADSheetHitTestTests.TheViewportOnTopIsTheOneThatAnswers;
var
  TmpSecond: TCADSheetViewport;
begin
  TmpSecond := FSheet.AddViewport;
  TmpSecond.RectMM := Rect2D(50, 30, 150, 80);
  { CADDrawSheet draws them in order, so the second one is painted over
    the first. A hit test that answered with the first would hand the
    user the viewport they cannot see. }
  Assert.AreEqual(1, CADSheetViewportIndexAt(FSheet, Device, Point(60, 250)),
    'where they overlap, the one on top');
  Assert.AreEqual(0, CADSheetViewportIndexAt(FSheet, Device, Point(20, 280)),
    'and the one underneath where it is alone');
end;

procedure TCADSheetHitTestTests.TheCentreOfAViewportIsTheCentreOfWhatItShows;
var
  TmpPt: TPoint2D;
begin
  { The model is 300 x 150 and the viewport frames all of it, so the
    middle of the rectangle is the middle of the drawing. Within a
    device pixel, which here is three model units - the transform is
    laid out on pixel centres and this test is not the place to
    re-derive that half pixel. }
  TmpPt := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(60, 262));
  Assert.AreEqual(150.0, TmpPt.X, 3.0, 'halfway across the drawing');
  Assert.AreEqual(75.0, TmpPt.Y, 3.0, 'and halfway up it');
end;

procedure TCADSheetHitTestTests.APointSurvivesTheRoundTripThroughTheModel;
var
  TmpBack: TPoint;
  TmpModel: TPoint2D;
begin
  { Device to model and back. A round trip is worth more than either
    direction checked against arithmetic repeated in the test: it
    cannot agree with a mistake unless the mistake cancels itself. }
  TmpModel := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(37, 251));
  TmpBack := CADSheetModelToPoint(FCAD, FSheet, FViewport, Device, TmpModel);
  Assert.AreEqual(37, TmpBack.X, 'the same pixel across');
  Assert.AreEqual(251, TmpBack.Y, 'and the same row');
end;

procedure TCADSheetHitTestTests.APointOutsideAViewportStillTransforms;
var
  TmpPt: TPoint2D;
begin
  { Deliberate: a drag that leaves the viewport is still a drag in that
    viewport's model, and the library has no business deciding that a
    point which is off the paper means nothing. Asking which viewport a
    point is in is a separate question with a separate routine. }
  TmpPt := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(160, 262));
  Assert.IsTrue(TmpPt.X > 300.0,
    'fifty millimetres past the right edge, at three units each');
end;

initialization

TDUnitX.RegisterTestFixture(TCADSheetHitTestTests);
TDUnitX.RegisterTestFixture(TCADSheetModelTests);
TDUnitX.RegisterTestFixture(TCADSheetPersistenceTests);
TDUnitX.RegisterTestFixture(TCADSheetDrawingTests);

end.
