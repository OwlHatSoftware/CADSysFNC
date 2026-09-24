{ : DUnitX tests for the page model (VCL.FNCCS4Print) and for the two
  things that had to become physical before printing could mean
  anything: a pen's line weight and the hatch spacing.

  The page model is a value and a handful of functions over it, which
  is exactly what a console runner can hold to account - no printer, no
  window, no canvas. The one test that does draw uses the recording
  backend from CADSys4.Tests.Graphics, so "did the page transform put
  the drawing where it said it would" is answered in device coordinates
  rather than by looking at a preview.

  The arithmetic in here is deliberately done with round numbers -
  A4 at 25.4 dpi is one pixel to the millimetre - so an assertion that
  fails says which number is wrong instead of by how much. }
unit CADSys4.Tests.Print;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCADSys4, VCL.FNCCS4Shapes,
  VCL.FNCCS4Views, VCL.FNCCS4Print, VCL.FNCCadSysRegister,
  CADSys4.Tests.Graphics;

type
  [TestFixture]
  TCADPageModelTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    { : A4 portrait, 10 mm margins - so the printable area is 190 x 277
      and every expected number below is a whole one. }
    function A4: TCADPageSetup;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure PaperSizes_AreTheStandardMillimetres;
    [Test]
    procedure Landscape_SwapsTheSheet;
    [Test]
    procedure PrintableSize_IsTheSheetLessTheMargins;
    [Test]
    procedure MarginsLargerThanTheSheet_AreRefused;
    [Test]
    procedure FitToPage_TakesTheAxisThatRunsOutOfPaperFirst;
    [Test]
    procedure FitToPage_CentresTheDrawingOnTheSheet;
    [Test]
    procedure FitToPage_IsAlwaysOnePage;
    [Test]
    procedure AScaledDrawingTooWideForOneSheet_IsTiled;
    [Test]
    procedure UntiledIsOnePageHoweverBigTheDrawing;
    [Test]
    procedure TiledPagesStartAtTheTopLeftAndRunRightThenDown;
    [Test]
    procedure AnEmptySetupTakesItsWindowFromTheDrawing;
    [Test]
    procedure PrintableRectInPixels_FollowsTheResolution;
    [Test]
    procedure APreviewBoxCentresTheSheetAndKeepsItsShape;
    [Test]
    procedure DrawPage_PutsTheDrawingInsideTheMargins;
    [Test]
    procedure DrawPage_ClipsToThePrintableArea;
    [Test]
    procedure DrawPage_LeavesTheCanvasScaleAsItFoundIt;
    [Test]
    procedure HiddenLayers_AreNotPrinted;
  end;

  { : The millimetre figures, which are what makes a print look like a
    drawing rather than like a fax. }
  [TestFixture]
  TPhysicalSizeTests = class(TObject)
  public
    [Test]
    procedure AWeightedPenTakesItsWidthFromTheDevice;
    [Test]
    procedure AWeightedPenOnAScreenChangesNothing;
    [Test]
    procedure AWeightThatWouldRoundToNothingStillDrawsOnePixel;
    [Test]
    procedure AssignGivesTheMillimetresTheLastWord;
    [Test]
    procedure AStoredPenKeepsItsWeightAndTouchesNoWidth;
    [Test]
    procedure HatchSpacingCanBeGivenPerCall;
    [Test]
    procedure SaveAndRestoreCarryTheWeight;
    [Test]
    procedure AClipDoesNotStack;
  end;

implementation

{ ==================================================================
  TCADPageModelTests
  ================================================================== }

procedure TCADPageModelTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADPageModelTests.TearDown;
begin
  FCAD.Free;
  FCAD := nil;
end;

function TCADPageModelTests.A4: TCADPageSetup;
begin
  Result := TCADPageSetup.Default;
  Result.Paper := pkA4;
  Result.Orientation := pgoPortrait;
  Result.Margins := TCADPageMargins.Uniform(10);
end;

procedure TCADPageModelTests.PaperSizes_AreTheStandardMillimetres;
var
  TmpW, TmpH: TRealType;
begin
  CADPaperSizeMM(pkA4, TmpW, TmpH);
  Assert.AreEqual(210.0, TmpW, 0.001, 'A4 width');
  Assert.AreEqual(297.0, TmpH, 0.001, 'A4 height');
  CADPaperSizeMM(pkA3, TmpW, TmpH);
  Assert.AreEqual(297.0, TmpW, 0.001, 'A3 is A4 turned and doubled');
  Assert.AreEqual(420.0, TmpH, 0.001, 'A3 height');
  Assert.AreEqual('A3', CADPaperKindName(pkA3), 'and it has a name');
end;

procedure TCADPageModelTests.Landscape_SwapsTheSheet;
var
  TmpSetup: TCADPageSetup;
  TmpW, TmpH: TRealType;
begin
  TmpSetup := A4;
  TmpSetup.Orientation := pgoLandscape;
  TmpSetup.PaperSizeMM(TmpW, TmpH);
  Assert.AreEqual(297.0, TmpW, 0.001, 'landscape width');
  Assert.AreEqual(210.0, TmpH, 0.001, 'landscape height');
end;

procedure TCADPageModelTests.PrintableSize_IsTheSheetLessTheMargins;
var
  TmpSetup: TCADPageSetup;
  TmpW, TmpH: TRealType;
begin
  TmpSetup := A4;
  TmpSetup.PrintableSizeMM(TmpW, TmpH);
  Assert.AreEqual(190.0, TmpW, 0.001, '210 less two 10s');
  Assert.AreEqual(277.0, TmpH, 0.001, '297 less two 10s');
end;

procedure TCADPageModelTests.MarginsLargerThanTheSheet_AreRefused;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Margins := TCADPageMargins.Uniform(200);
  Assert.WillRaise(
    procedure
    var
      TmpW, TmpH: TRealType;
      TmpLocal: TCADPageSetup;
    begin
      TmpLocal := TmpSetup;
      TmpLocal.PrintableSizeMM(TmpW, TmpH);
    end, ECADPageError, 'a sheet that is all margin has no page on it');
end;

procedure TCADPageModelTests.FitToPage_TakesTheAxisThatRunsOutOfPaperFirst;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.KeepAspect := True;

  { 380 wide on 190 mm of paper is 2 units per millimetre; 277 tall on
    277 mm is 1. The wider one wins, or the drawing runs off the side. }
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);
  Assert.AreEqual(2.0, TmpSetup.EffectiveUnitsPerMM(FCAD), 0.0001,
    'width decides');

  TmpSetup.View.Window := Rect2D(0, 0, 190, 554);
  Assert.AreEqual(2.0, TmpSetup.EffectiveUnitsPerMM(FCAD), 0.0001,
    'and height decides when height is the tighter one');
end;

procedure TCADPageModelTests.FitToPage_CentresTheDrawingOnTheSheet;
var
  TmpSetup: TCADPageSetup;
  TmpWin: TRect2D;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.KeepAspect := True;
  { A square drawing on a tall sheet: the page window has to grow
    downwards and upwards equally, or the drawing prints against one
    edge with all the white space at the other. }
  TmpSetup.View.Window := Rect2D(0, 0, 100, 100);
  TmpWin := TmpSetup.PageWindow(FCAD, 0);

  Assert.AreEqual(0.0, TmpWin.Left, 0.001, 'nothing added on the left');
  Assert.AreEqual(100.0, TmpWin.Right, 0.001, 'nor on the right');
  Assert.AreEqual(50.0, (TmpWin.Bottom + TmpWin.Top) / 2, 0.001,
    'the drawing stays in the middle');
  Assert.AreEqual(277.0 / 190.0, (TmpWin.Top - TmpWin.Bottom) /
    (TmpWin.Right - TmpWin.Left), 0.0001,
    'and the window comes out the paper''s shape');
end;

procedure TCADPageModelTests.FitToPage_IsAlwaysOnePage;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.Tiled := True;
  TmpSetup.View.Window := Rect2D(0, 0, 10000, 10000);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'fitting to the page is what one page means');
end;

procedure TCADPageModelTests.AScaledDrawingTooWideForOneSheet_IsTiled;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := True;
  { 380 units across 190 mm of printable width, at 1:1, is two sheets. }
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);
  Assert.AreEqual(2, TmpSetup.PagesAcross(FCAD), 'two across');
  Assert.AreEqual(1, TmpSetup.PagesDown(FCAD), 'one down');
  Assert.AreEqual(2, TmpSetup.PageCount(FCAD), 'two pages');

  { And exactly one sheet wide is exactly one sheet, not two. }
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'a drawing that just fits does not spill onto a second sheet');
end;

procedure TCADPageModelTests.UntiledIsOnePageHoweverBigTheDrawing;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := False;
  TmpSetup.View.Window := Rect2D(0, 0, 3800, 2770);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'not tiled means one sheet and the rest off the edge');
end;

procedure TCADPageModelTests.TiledPagesStartAtTheTopLeftAndRunRightThenDown;
var
  TmpSetup: TCADPageSetup;
  TmpFirst, TmpSecond: TRect2D;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := True;
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);

  TmpFirst := TmpSetup.PageWindow(FCAD, 0);
  TmpSecond := TmpSetup.PageWindow(FCAD, 1);

  { Page one is the top-left corner of the drawing - which is the sheet
    a reader picks up first and the one they lay the others against. }
  Assert.AreEqual(0.0, TmpFirst.Left, 0.001, 'page 1 starts at the left');
  Assert.AreEqual(277.0, TmpFirst.Top, 0.001, 'and at the top');
  Assert.AreEqual(190.0, TmpFirst.Right, 0.001, 'one printable width across');
  Assert.AreEqual(190.0, TmpSecond.Left, 0.001,
    'page 2 carries on where page 1 stopped');
  Assert.AreEqual(380.0, TmpSecond.Right, 0.001, 'to the end of the drawing');
end;

procedure TCADPageModelTests.AnEmptySetupTakesItsWindowFromTheDrawing;
var
  TmpSetup: TCADPageSetup;
  TmpWin: TRect2D;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(60, 40)));
  TmpSetup := A4;
  { View.Window is left as Default leaves it.

    This is the test that caught TCADPageSetup.Default handing back
    TCADViewSpec.Default's window, which is -100..100 - a good place
    for a viewport to open and a silly thing to print. A setup nobody
    has pointed anywhere prints the drawing. }
  TmpWin := TmpSetup.EffectiveWindow(FCAD);
  Assert.AreEqual(0.0, TmpWin.Left, 0.001, 'the drawing''s own extension');
  Assert.AreEqual(60.0, TmpWin.Right, 0.001, 'right');
  Assert.AreEqual(40.0, TmpWin.Top, 0.001, 'top');
end;

procedure TCADPageModelTests.PrintableRectInPixels_FollowsTheResolution;
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpRect: TRect;
begin
  TmpSetup := A4;
  { 25.4 dots per inch is one dot per millimetre, so every number below
    is the millimetre figure and a wrong one is obvious. }
  TmpDevice := TCADPageDevice.FromDPI(25.4, 25.4);
  TmpRect := CADPrintableRectPx(TmpSetup, TmpDevice);
  Assert.AreEqual(10, TmpRect.Left, 'the left margin');
  Assert.AreEqual(10, TmpRect.Top, 'the top margin');
  Assert.AreEqual(200, TmpRect.Right, '210 less the right margin');
  Assert.AreEqual(287, TmpRect.Bottom, '297 less the bottom margin');

  { A printer's canvas starts at the printable area, so the sheet
    begins off the top-left of it - which is what the offsets are for. }
  TmpDevice.OffsetXPx := -12;
  TmpDevice.OffsetYPx := -12;
  TmpRect := CADPrintableRectPx(TmpSetup, TmpDevice);
  Assert.AreEqual(-2, TmpRect.Left,
    'a 10 mm margin on a sheet that starts 12 mm off the canvas');
end;

procedure TCADPageModelTests.APreviewBoxCentresTheSheetAndKeepsItsShape;
var
  TmpDevice: TCADPageDevice;
begin
  { A portrait sheet in a square box: height is the tight one, so the
    sheet fills it top to bottom and is centred left to right. }
  TmpDevice := TCADPageDevice.ToBox(210, 297, 400, 400);
  Assert.AreEqual(TmpDevice.PixelsPerMMX, TmpDevice.PixelsPerMMY, 0.000001,
    'one scale for both axes, or the sheet is not a sheet');
  Assert.AreEqual(400.0 / 297.0, TmpDevice.PixelsPerMMY, 0.0001,
    'the height fills the box');
  Assert.AreEqual(0, TmpDevice.OffsetYPx, 'nothing to spare vertically');
  Assert.IsTrue(TmpDevice.OffsetXPx > 0, 'and the sheet is centred across');
end;

procedure TCADPageModelTests.DrawPage_PutsTheDrawingInsideTheMargins;
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: string;
begin
  { One millimetre to the pixel, 1:1, so a line from (10,10) to
    (100,50) in the drawing has to land inside the printable rectangle
    (10,10)-(200,287) - and near its bottom, because paper counts
    downwards and drawings count up. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(10, 10), Point2D(100, 50)));
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);
  TmpDevice := TCADPageDevice.FromDPI(25.4, 25.4);

  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TmpDevice, 0, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    Assert.IsTrue(TmpRec.CountOf('LineTo') > 0, 'the line was drawn at all');
    { The Y flip is the part that is silently wrong if it is wrong: a
      drawing printed upside down still looks like a drawing. World Y 10
      is 10 mm off the bottom of a 277 mm page, so it belongs near
      device Y 277, not near 10. }
    Assert.IsTrue(TmpLog.Contains('276') or TmpLog.Contains('277'),
      'the bottom of the drawing is at the bottom of the page: ' + TmpLog);
    Assert.IsTrue(TmpLog.Contains('19,') or TmpLog.Contains('20,'),
      'and 10 mm in from a 10 mm margin is 20 mm across: ' + TmpLog);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.DrawPage_ClipsToThePrintableArea;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: string;
begin
  { Without this, a drawing spread over several sheets draws all of
    itself on every one of them - over the margins, off the paper, and
    on a preview control across the rest of the window. Found by looking
    at a tiled preview; nothing in the geometry was wrong.

    The transform's window cannot do the job: a shape uses it to decide
    whether to draw at all, and a line crossing the page boundary has to
    be drawn because part of it belongs here. Only the device can cut it
    at the edge, which is why TCADGraphics grew PushClip. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(-500, -500),
    Point2D(5000, 5000)));
  TmpSetup := A4;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(25.4, 25.4), 0,
        TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    Assert.IsTrue(TmpLog.Contains('PushClip 10,10,200,287'),
      'clipped to the printable rectangle, not the paper or the surface: '
      + TmpLog);
    Assert.AreEqual(1, TmpRec.CountOf('PopClip'),
      'and given back - a clip left behind takes the next thing drawn '
      + 'with it');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.DrawPage_LeavesTheCanvasScaleAsItFoundIt;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  { The canvas handed to CADDrawPage may well be a screen's, and a
    printer's millimetre scale left behind on it would make every line
    afterwards six times too thick. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(50, 50)));
  TmpSetup := A4;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpRec.PixelsPerMM := 0;
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(600, 600), 0,
        TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Assert.AreEqual(0.0, TmpRec.PixelsPerMM, 0.000001,
      'the page put the screen''s scale back');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.HiddenLayers_AreNotPrinted;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpObj: TLine2D;
  TmpWithout, TmpWith: Integer;

  function DrawAndCount: Integer;
  begin
    TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
    try
      TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
      try
        CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(25.4, 25.4), 0,
          TmpCanvas);
      finally
        TmpCanvas.Free;
      end;
      Result := TmpRec.CountOf('LineTo');
    finally
      TmpRec.Free;
    end;
  end;

begin
  FCAD.CurrentLayer := 5;
  TmpObj := TLine2D.Create(-1, Point2D(10, 10), Point2D(100, 50));
  FCAD.AddObject(-1, TmpObj);

  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);

  TmpWithout := DrawAndCount;
  Assert.IsTrue(TmpWithout > 0, 'the line prints when nothing hides it');

  { The same override a saved view carries - which is the point of the
    setup holding a TCADViewSpec rather than a window of its own. }
  TmpSetup.View.UseLayerOverride := True;
  TmpSetup.View.HiddenLayers := [5];
  TmpWith := DrawAndCount;
  Assert.AreEqual(0, TmpWith, 'and not when its layer is hidden');
end;

{ ==================================================================
  TPhysicalSizeTests
  ================================================================== }

procedure TPhysicalSizeTests.AWeightedPenTakesItsWidthFromTheDevice;
var
  TmpRec: TRecordingGraphics;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.LineWeightMM := 0.5;
    Assert.AreEqual(5, TmpRec.Pen.Width, 'half a millimetre at 10 px/mm');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AWeightedPenOnAScreenChangesNothing;
var
  TmpRec: TRecordingGraphics;
begin
  { PixelsPerMM is 0 on every surface that has not been told otherwise,
    which is every screen - and there the pixel width still rules.
    This is what makes the whole feature additive. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.Pen.Width := 3;
    TmpRec.Pen.LineWeightMM := 0.5;
    Assert.AreEqual(3, TmpRec.Pen.Width, 'the width the caller set');
    Assert.AreEqual(0.5, TmpRec.Pen.LineWeightMM, 0.0001,
      'and the weight is remembered for a device that can use it');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AWeightThatWouldRoundToNothingStillDrawsOnePixel;
var
  TmpRec: TRecordingGraphics;
begin
  { A line nobody can see is not a thin line, it is a missing one. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 1;
    TmpRec.Pen.LineWeightMM := 0.05;
    Assert.AreEqual(1, TmpRec.Pen.Width, 'never thinner than a pixel');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AssignGivesTheMillimetresTheLastWord;
var
  TmpRec: TRecordingGraphics;
  TmpStored: TCADSimplePen;
begin
  { A layer carries both: a pixel width for the screen and a weight for
    paper. On paper the weight has to win, and Assign copies the width
    first for exactly that reason. }
  TmpStored := TCADSimplePen.Create;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpStored.Width := 1;
    TmpStored.LineWeightMM := 0.7;
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.Assign(TmpStored);
    Assert.AreEqual(7, TmpRec.Pen.Width, '0.7 mm at 10 px/mm, not 1 pixel');
  finally
    TmpRec.Free;
    TmpStored.Free;
  end;
end;

procedure TPhysicalSizeTests.AStoredPenKeepsItsWeightAndTouchesNoWidth;
var
  TmpStored: TCADSimplePen;
begin
  { A layer's pen has no surface and no business guessing at one. }
  TmpStored := TCADSimplePen.Create;
  try
    TmpStored.Width := 2;
    TmpStored.LineWeightMM := 0.35;
    Assert.AreEqual(2, TmpStored.Width, 'the width is untouched');
    Assert.AreEqual(0.35, TmpStored.LineWeightMM, 0.0001, 'the weight is kept');
    Assert.IsTrue(TmpStored.OwnerGraphics = nil,
      'and it belongs to no graphics');
  finally
    TmpStored.Free;
  end;
end;

procedure TPhysicalSizeTests.HatchSpacingCanBeGivenPerCall;
var
  TmpPoly: array [0 .. 3] of TPoint;
  TmpWide, TmpTight: TCADHatchSegments;
begin
  TmpPoly[0] := Point(0, 0);
  TmpPoly[1] := Point(200, 0);
  TmpPoly[2] := Point(200, 200);
  TmpPoly[3] := Point(0, 200);
  TmpWide := CADHatchLines(TmpPoly, cbsHorizontal, 40);
  TmpTight := CADHatchLines(TmpPoly, cbsHorizontal, 10);
  Assert.IsTrue(Length(TmpTight) > Length(TmpWide),
    'a smaller spacing is more lines');
  { Which is the whole point on paper: the spacing stops being eight
    pixels and starts being two millimetres. }
  Assert.AreEqual(Length(CADHatchLines(TmpPoly, cbsHorizontal)),
    Length(CADHatchLines(TmpPoly, cbsHorizontal, 0)),
    'and zero means the pixel default, as it always did');
end;

procedure TPhysicalSizeTests.AClipDoesNotStack;
var
  TmpRec: TRecordingGraphics;
begin
  { One level deep, and a second push is ignored rather than stacked.
    Nothing in the library nests clips, and a clip stack that silently
    loses a level is worse than one that refuses to grow: the drawing
    that comes out is wrong in a way nobody can see until it is on
    paper. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PushClip(Rect(10, 10, 90, 90));
    TmpRec.PushClip(Rect(20, 20, 80, 80));
    TmpRec.PopClip;
    TmpRec.PopClip;
    Assert.AreEqual(1, TmpRec.CountOf('PushClip'), 'one clip went down');
    Assert.AreEqual(1, TmpRec.CountOf('PopClip'), 'and one came back up');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.SaveAndRestoreCarryTheWeight;
var
  TmpRec: TRecordingGraphics;
  TmpState: TCADGraphicsState;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.LineWeightMM := 0.4;
    TmpState := TmpRec.SaveState;
    TmpRec.Pen.LineWeightMM := 2.0;
    Assert.AreEqual(20, TmpRec.Pen.Width, 'the new weight took effect');
    TmpRec.RestoreState(TmpState);
    Assert.AreEqual(4, TmpRec.Pen.Width, 'and the old one came back');
    Assert.AreEqual(0.4, TmpRec.Pen.LineWeightMM, 0.0001,
      'with the weight itself, not only the pixels');
  finally
    TmpRec.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TCADPageModelTests);
TDUnitX.RegisterTestFixture(TPhysicalSizeTests);

end.
