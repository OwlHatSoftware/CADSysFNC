{ : DUnitX tests for the TMS FNC drawing backend (VCL.FNCCS4GraphicsFNC).

  Everything is drawn into a TTMSFNCGraphics bitmap canvas with
  anti-aliasing off, and pixels are read back from its TBitmap. Only pixels
  well inside a shape or well away from it are checked, so the tests do not
  depend on how FNC rasterises edges.

  Needs TMS FNC Core (VCL flavour) on the library path.
}
unit CADSys4.Tests.GraphicsFNC;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.UITypes,
  Vcl.Graphics,
  DUnitX.TestFramework,
  VCL.TMSFNCGraphics, VCL.TMSFNCGraphicsTypes,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsFNC,
  VCL.FNCCADSys4, VCL.FNCCS4Shapes, VCL.FNCCadSysRegister,
  VCL.FNCCS4Paper, VCL.FNCCS4Image, Vcl.Imaging.pngimage, VCL.FNCCS4SVG,
  System.IOUtils, Xml.XMLIntf, Xml.XMLDoc, Xml.xmldom, Xml.omnixmldom;

type
  { : CS-04: a sheet, or a rectangle of the model, as a PNG. Here rather
    than in the main suite because it draws through FNC onto a bitmap,
    which is what this suite is for. }
  [TestFixture]
  TCADImageExportTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    function SheetPNG(const ATransparent: Boolean): TPngImage;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ASheetImageIsThePaperAtTheResolution;
    [Test]
    procedure ASheetImageShowsTheSheet;
    [Test]
    procedure ATransparentSheetIsClearWhereNothingIsDrawn;
    [Test]
    procedure AModelRectangleIsTheRectangleAtTheScale;
    [Test]
    procedure TooLargeAnImageIsRefused;
  end;

  { : CS-05: a sheet as SVG. Here rather than in the main suite because
    the text is measured through FNC. Most of it draws on a
    TCADSVGGraphics directly and reads the text back; what has to be
    well-formed is parsed. }
  [TestFixture]
  TCADSVGExportTests = class(TObject)
  private
    FSVG: TCADSVGGraphics;
    FOldVendor: string;
    function Parse(const AText: string): IXMLDocument;
    function FindElement(const ANode: IXMLNode; const AName: string): IXMLNode;
    function ArialSpec(const AHeight: Integer): TCADFontSpec;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ASheetIsAnSVGOfThePaperSize;
    [Test]
    procedure LineToRunsBecomeOnePolyline;
    [Test]
    procedure APenChangeEndsTheRun;
    [Test]
    procedure ARectangleCarriesItsFillAndStroke;
    [Test]
    procedure ADashedPenIsDashedAtPaperSize;
    [Test]
    procedure OneGradientServesEveryShapeThatUsesIt;
    [Test]
    procedure AClipIsAGroupWithAClipPath;
    [Test]
    procedure AClipLeftOpenIsClosedInTheDocument;
    [Test]
    procedure TextIsEscapedAndReadsBack;
    [Test]
    procedure WordWrapMakesOneLinePerTspan;
    [Test]
    procedure CalcRectAgreesWithTheFNCBackend;
    [Test]
    procedure AnImageIsEmbeddedAsADataURI;
    [Test]
    procedure SeveralSheetsNeedAPattern;
  end;

  [TestFixture]
  TCADFNCGraphicsTests = class(TObject)
  private
    FG: TTMSFNCGraphics;
    FCnv: TDecorativeCanvas;
    FFNC: TCADFNCGraphics;
    function Pixel(const X, Y: Integer): TColor;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Pen_StateIsKeptByTheBackend;
    [Test]
    procedure Pen_ColourReachesTheFNCStroke;
    [Test]
    procedure Pen_ClearStyle_DisablesTheStroke;
    [Test]
    procedure Pen_XorMode_DrawsInXorColor;
    [Test]
    procedure Pen_Alpha_BecomesStrokeOpacity;
    [Test]
    procedure Brush_Alpha_BecomesFillOpacity;
    [Test]
    procedure Brush_Gradient_BecomesAGradientFill;
    [Test]
    procedure Brush_Gradient_BlendsAcrossARectangle;
    [Test]
    procedure Brush_ZeroAlpha_DisablesTheFill;
    [Test]
    procedure Brush_ClearStyle_DisablesTheFill;
    [Test]
    procedure ClipRect_IsTheBounds;
    [Test]
    procedure DecorativeCanvas_HasNoVCLCanvas;
    [Test]
    procedure APolygonDrawsItsClosingEdge;
    [Test]
    procedure Polygon_FillsWithTheBrush;
    [Test]
    procedure Polyline_DoesNotFill;
    [Test]
    procedure Polyline_RestoresTheFill;
    [Test]
    procedure MoveToLineTo_DrawsALine;
    [Test]
    procedure FillRect_DoesNotChangeThePen;
    [Test]
    procedure DrawText_CalcRect_GrowsTheRectangle;
    [Test]
    procedure DrawText_PutsInkInTheRectangle;
    [Test]
    procedure Polygon2D_RendersThroughTheFNCBackend;
    [Test]
    procedure FontHeight_ConvertsToPositiveSize;
    [Test]
    procedure Color_SystemColourIsResolved;
  end;

implementation

const
  W = 60;
  H = 60;

procedure TCADFNCGraphicsTests.Setup;
begin
  FG := TTMSFNCGraphics.CreateBitmapCanvas(W, H);
  FG.BeginScene;
  FG.Context.SetAntiAliasing(False);
  FG.Fill.Kind := gfkSolid;
  FG.Fill.Color := gcWhite;
  FG.Stroke.Kind := gskNone;
  FG.DrawRectangle(RectF(0, 0, W, H));
  FFNC := TCADFNCGraphics.Create(FG, Rect(0, 0, W, H), False);
  FCnv := TDecorativeCanvas.Create(FFNC, True);
end;

procedure TCADFNCGraphicsTests.TearDown;
begin
  FCnv.Free; // frees FFNC, which does not own FG
  FFNC := nil;
  FG.Free;
end;

function TCADFNCGraphicsTests.Pixel(const X, Y: Integer): TColor;
begin
  { Flush the scene, read, and reopen it for further drawing. }
  FG.EndScene;
  try
    Result := ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]);
  finally
    FG.BeginScene;
  end;
end;

procedure TCADFNCGraphicsTests.Pen_StateIsKeptByTheBackend;
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Width := 3;
  FCnv.Pen.Style := cpsDash;
  FCnv.Pen.Mode := cpmXor;
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed), Cardinal(FCnv.Pen.Color));
  Assert.AreEqual(3, FCnv.Pen.Width);
  Assert.IsTrue(FCnv.Pen.Style = cpsDash);
  Assert.IsTrue(FCnv.Pen.Mode = cpmXor);
end;

procedure TCADFNCGraphicsTests.Pen_ColourReachesTheFNCStroke;
begin
  FCnv.Pen.Color := cadclBlue;
  FCnv.Pen.Width := 2;
  Assert.AreEqual(TColor(clBlue), TColor(FG.Stroke.Color));
  Assert.IsTrue(Abs(FG.Stroke.Width - 2) < 0.01, 'width');
  Assert.IsTrue(FG.Stroke.Kind = gskSolid, 'kind');
end;

procedure TCADFNCGraphicsTests.Pen_ClearStyle_DisablesTheStroke;
begin
  FCnv.Pen.Style := cpsClear;
  Assert.IsTrue(FG.Stroke.Kind = gskNone);
  FCnv.Pen.Style := cpsDot;
  Assert.IsTrue(FG.Stroke.Kind = gskDot);
end;

procedure TCADFNCGraphicsTests.Pen_XorMode_DrawsInXorColor;
begin
  FFNC.XorColor := cadclFuchsia;
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Mode := cpmXor;
  Assert.AreEqual(TColor(clFuchsia), TColor(FG.Stroke.Color));
  FCnv.Pen.Mode := cpmCopy;
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color));
end;

procedure TCADFNCGraphicsTests.Pen_Alpha_BecomesStrokeOpacity;
begin
  { FNC on VCL has no alpha in the colour, so it travels as opacity. }
  FCnv.Pen.Color := CADColorSetAlpha(cadclRed, 128);
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color), 'colour');
  Assert.IsTrue(Abs(FG.Stroke.Opacity - 128 / 255) < 0.01,
    'opacity ' + FloatToStr(FG.Stroke.Opacity));
  FCnv.Pen.Color := cadclRed;
  Assert.IsTrue(Abs(FG.Stroke.Opacity - 1) < 0.01, 'opaque again');
end;

procedure TCADFNCGraphicsTests.Brush_Alpha_BecomesFillOpacity;
begin
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := CADColorSetAlpha(cadclLime, 64);
  Assert.IsTrue(FG.Fill.Kind = gfkSolid, 'kind');
  Assert.AreEqual(TColor(clLime), TColor(FG.Fill.Color), 'colour');
  Assert.IsTrue(Abs(FG.Fill.Opacity - 64 / 255) < 0.01,
    'opacity ' + FloatToStr(FG.Fill.Opacity));
end;

procedure TCADFNCGraphicsTests.Brush_ZeroAlpha_DisablesTheFill;
const
  Pts: array[0..3] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50));
begin
  FCnv.Pen.Style := cpsClear;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := CADColorSetAlpha(cadclLime, 0);
  Assert.IsTrue(FG.Fill.Kind = gfkNone, 'nothing to fill with');
  FCnv.Polygon(@Pts[0], 4);
  Assert.AreEqual(TColor(clWhite), Pixel(30, 30), 'so nothing is drawn');
end;

{ The red and blue of a colour as it is on the screen - ColorToRGB
  resolves a system colour - without WinAPI.Windows for GetRValue. }
function RedOf(const AColor: TColor): Byte;
begin
  Result := ColorToRGB(AColor) and $FF;
end;

function BlueOf(const AColor: TColor): Byte;
begin
  Result := (ColorToRGB(AColor) shr 16) and $FF;
end;

procedure TCADFNCGraphicsTests.Brush_Gradient_BecomesAGradientFill;
begin
  FCnv.Brush.Color := cadclRed;
  FCnv.Brush.Color2 := cadclBlue;
  FCnv.Brush.GradientVertical := True;
  FCnv.Brush.Style := cbsGradient;
  Assert.IsTrue(FG.Fill.Kind = gfkGradient, 'kind');
  Assert.AreEqual(TColor(clRed), TColor(FG.Fill.Color), 'from');
  Assert.AreEqual(TColor(clBlue), TColor(FG.Fill.ColorTo), 'to');
  Assert.IsTrue(FG.Fill.Orientation = gfoVertical, 'top to bottom');
  FCnv.Brush.GradientVertical := False;
  Assert.IsTrue(FG.Fill.Orientation = gfoHorizontal,
    'and a change reaches the fill at once');
end;

procedure TCADFNCGraphicsTests.Brush_Gradient_BlendsAcrossARectangle;
begin
  FCnv.Pen.Style := cpsClear;
  FCnv.Brush.Color := cadclRed;
  FCnv.Brush.Color2 := cadclBlue;
  FCnv.Brush.GradientVertical := False;
  FCnv.Brush.Style := cbsGradient;
  FCnv.Graphics.Rectangle(0, 0, W, H);
  Assert.IsTrue(RedOf((Pixel(2, H div 2))) > 180, 'red at the left');
  Assert.IsTrue(BlueOf((Pixel(W - 3, H div 2))) > 180,
    'blue at the right');
end;

procedure TCADFNCGraphicsTests.Brush_ClearStyle_DisablesTheFill;
begin
  FCnv.Brush.Style := cbsClear;
  Assert.IsTrue(FG.Fill.Kind = gfkNone);
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  Assert.IsTrue(FG.Fill.Kind = gfkSolid);
  Assert.AreEqual(TColor(clLime), TColor(FG.Fill.Color));
end;

procedure TCADFNCGraphicsTests.ClipRect_IsTheBounds;
var
  R: TRect;
begin
  R := FCnv.ClipRect;
  Assert.AreEqual(0, R.Left);
  Assert.AreEqual(0, R.Top);
  Assert.AreEqual(W, R.Right);
  Assert.AreEqual(H, R.Bottom);
end;

procedure TCADFNCGraphicsTests.APolygonDrawsItsClosingEdge;
var
  TmpPts: array [0 .. 3] of TPoint;

  function AnyInk(const AX, AY: Integer): Boolean;
  var
    D: Integer;
  begin
    { A one pixel line sits on a half-pixel boundary - see PixelOffset -
      so the row it lands on is not worth being dogmatic about. }
    Result := False;
    for D := -1 to 1 do
      Result := Result or (Pixel(AX, AY + D) <> clWhite);
  end;

begin
  { The closing edge of a polygon is the one nobody draws.

    Three of the four edges are between points the caller gave; the
    fourth is implied, and whether it appears depends entirely on what
    the backend does with a path it was not told to close. On screen
    FNC closes it. Its PDF engine ends the path with the operator B,
    which fills as though the path were closed and strokes as though it
    were not - so every polygon in a PDF was missing one edge, and
    nothing else showed it.

    The outline only, so the fill cannot be mistaken for the edge. }
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Width := 1;
  FCnv.Pen.Style := cpsSolid;
  FCnv.Brush.Style := cbsClear;

  TmpPts[0] := Point(10, 50);
  TmpPts[1] := Point(10, 10);
  TmpPts[2] := Point(50, 10);
  TmpPts[3] := Point(50, 50);
  FCnv.Graphics.Polygon(TmpPts);

  Assert.IsTrue(AnyInk(30, 10),
    'the top edge, which is between two given points, was drawn');
  Assert.IsTrue(AnyInk(30, 50),
    'and so was the bottom one, which is the closing edge nobody asked ' +
    'for by name');
  Assert.AreEqual(clWhite, Pixel(30, 30),
    'with a clear brush the inside is still paper, so what was measured ' +
    'above is the outline and not the fill');
end;

procedure TCADFNCGraphicsTests.DecorativeCanvas_HasNoVCLCanvas;
begin
  Assert.IsNull(FCnv.Canvas);
end;

procedure TCADFNCGraphicsTests.Polygon_FillsWithTheBrush;
const
  Pts: array[0..3] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50));
begin
  FCnv.Pen.Color := cadclLime;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polygon(@Pts[0], 4);
  Assert.AreEqual(TColor(clLime), Pixel(30, 30), 'inside');
  Assert.AreEqual(TColor(clWhite), Pixel(3, 3), 'outside');
end;

procedure TCADFNCGraphicsTests.Polyline_DoesNotFill;
const
  Pts: array[0..4] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50), (X: 10; Y: 10));
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polyline(@Pts[0], 5);
  Assert.AreEqual(TColor(clWhite), Pixel(30, 30), 'inside');
  Assert.AreEqual(TColor(clRed), Pixel(30, 10), 'edge');
end;

procedure TCADFNCGraphicsTests.Polyline_RestoresTheFill;
const
  Pts: array[0..1] of TPoint = ((X: 1; Y: 1), (X: 5; Y: 5));
begin
  FCnv.Brush.Style := cbsSolid;
  FCnv.Polyline(@Pts[0], 2);
  Assert.IsTrue(FG.Fill.Kind = gfkSolid);
end;

procedure TCADFNCGraphicsTests.MoveToLineTo_DrawsALine;
begin
  FCnv.Pen.Color := cadclBlue;
  FCnv.Pen.Width := 1;
  FCnv.MoveTo(5, 30);
  FCnv.LineTo(55, 30);
  Assert.AreEqual(TColor(clBlue), Pixel(30, 30), 'on the line');
  Assert.AreEqual(TColor(clWhite), Pixel(30, 34), 'below the line');
end;

procedure TCADFNCGraphicsTests.FillRect_DoesNotChangeThePen;
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Brush.Color := cadclYellow;
  FFNC.FillRect(Rect(20, 20, 40, 40));
  Assert.IsTrue(FG.Stroke.Kind = gskSolid);
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color));
  Assert.AreEqual(TColor(clYellow), Pixel(30, 30));
end;

procedure TCADFNCGraphicsTests.DrawText_CalcRect_GrowsTheRectangle;
var
  R: TRect;
  F: TCADFontSpec;
begin
  F := TCADFontSpec.Default;
  F.Height := -14;
  FFNC.SelectFont(F);
  R := Rect(5, 5, 5, 5);
  FFNC.DrawText('CADSys', R, CAD_DT_CALCRECT);
  FFNC.ResetFont;
  Assert.IsTrue(R.Right > 5 + 10, 'width ' + IntToStr(R.Width));
  Assert.IsTrue(R.Bottom > 5 + 5, 'height ' + IntToStr(R.Height));
  Assert.AreEqual(5, R.Left);
  Assert.AreEqual(5, R.Top);
end;

procedure TCADFNCGraphicsTests.DrawText_PutsInkInTheRectangle;
var
  R: TRect;
  F: TCADFontSpec;
  X, Y, Ink: Integer;
begin
  F := TCADFontSpec.Default;
  F.Height := -20;
  F.Weight := 700;
  FFNC.FontColor := cadclBlack;
  FFNC.Transparent := True;
  FFNC.SelectFont(F);
  R := Rect(2, 2, 58, 30);
  FFNC.DrawText('MMM', R, CAD_DT_LEFT or CAD_DT_TOP or CAD_DT_SINGLELINE);
  FFNC.ResetFont;
  FG.EndScene;
  try
    Ink := 0;
    for Y := 2 to 29 do
      for X := 2 to 57 do
        if ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]) <> clWhite then
          Inc(Ink);
    Assert.IsTrue(Ink > 20, 'ink pixels: ' + IntToStr(Ink));
    Ink := 0;
    for Y := 40 to 59 do
      for X := 0 to 59 do
        if ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]) <> clWhite then
          Inc(Ink);
    Assert.AreEqual(0, Ink, 'nothing drawn below the text rectangle');
  finally
    FG.BeginScene;
  end;
end;

procedure TCADFNCGraphicsTests.Polygon2D_RendersThroughTheFNCBackend;
var
  P: TPolygon2D;
begin
  P := TPolygon2D.Create(1, [Point2D(10, 10), Point2D(50, 10),
    Point2D(50, 50), Point2D(10, 50)]);
  try
    FCnv.Pen.Color := cadclNavy;
    FCnv.Brush.Style := cbsSolid;
    FCnv.Brush.Color := cadclAqua;
    P.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, W, H), DRAWMODE_NORMAL);
  finally
    P.Free;
  end;
  Assert.AreEqual(TColor(clAqua), Pixel(30, 30));
end;

procedure TCADFNCGraphicsTests.FontHeight_ConvertsToPositiveSize;
begin
  { -16 px character height = 12 pt at 96 DPI. }
  Assert.IsTrue(Abs(CADFontHeightToFNCSize(-16) - 12) < 0.01);
  Assert.IsTrue(CADFontHeightToFNCSize(20) > 0);
  Assert.IsTrue(CADFontHeightToFNCSize(0) >= 1);
end;

procedure TCADFNCGraphicsTests.Color_SystemColourIsResolved;
begin
  { A system colour is resolved on the way into the drawing layer, so
    what reaches FNC is a plain RGB value. }
  Assert.AreEqual(ColorToRGB(clBtnFace),
    TColor(CADToFNCColor(TColorToCADColor(ColorToRGB(clBtnFace)))));
  Assert.AreEqual(TColor(clRed), TColor(CADToFNCColor(cadclRed)));
  Assert.IsTrue(Abs(CADToFNCOpacity(cadclRed) - 1) < 0.001, 'opaque');
  Assert.IsTrue(Abs(CADToFNCOpacity(CADColorSetAlpha(cadclRed, 0))) < 0.001,
    'transparent');
end;

{ ==================================================================
  TCADImageExportTests
  ================================================================== }

procedure TCADImageExportTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
  { A3 landscape, 420 x 297 mm, and at 25.4 dpi one pixel to the
    millimetre - every number below is a millimetre. }
  FSheet := FCAD.Sheets.Add('Plate');
  FSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10), Point2D(410, 287)));
end;

procedure TCADImageExportTests.TearDown;
begin
  FCAD.Free;
end;

function TCADImageExportTests.SheetPNG(const ATransparent: Boolean)
  : TPngImage;
var
  TmpStream: TMemoryStream;
begin
  TmpStream := TMemoryStream.Create;
  try
    CADSaveSheetToPNGStream(FCAD, FSheet, TmpStream, 25, ATransparent);
    Assert.IsTrue(TmpStream.Size > 0, 'something was written');
    TmpStream.Position := 0;
    Result := TPngImage.Create;
    try
      Result.LoadFromStream(TmpStream);
    except
      Result.Free;
      Raise;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TCADImageExportTests.ASheetImageIsThePaperAtTheResolution;
var
  TmpPNG: TPngImage;
  TmpSize: TPoint;
begin
  TmpSize := CADSheetImageSize(FSheet, 300);
  Assert.AreEqual(4961, TmpSize.X, 'A3 across at 300 dpi');
  Assert.AreEqual(3508, TmpSize.Y, 'and down');
  TmpPNG := SheetPNG(False);
  try
    Assert.AreEqual(CADSheetImageSize(FSheet, 25).X, TmpPNG.Width, 'width');
    Assert.AreEqual(CADSheetImageSize(FSheet, 25).Y, TmpPNG.Height, 'height');
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.ASheetImageShowsTheSheet;
var
  TmpPNG: TPngImage;
  TmpInk, X, Y: Integer;
begin
  TmpPNG := SheetPNG(False);
  try
    Assert.AreEqual(TColor(clWhite), ColorToRGB(TmpPNG.Pixels[TmpPNG.Width div 2,
      TmpPNG.Height div 2]), 'white paper in the middle');
    { The frame's left edge, 10 mm in: some ink in the column around it. }
    TmpInk := 0;
    for Y := TmpPNG.Height div 4 to TmpPNG.Height div 2 do
      for X := 7 to 12 do
        if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
          Inc(TmpInk);
    Assert.IsTrue(TmpInk > 10, 'the frame is drawn: ' + IntToStr(TmpInk));
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.ATransparentSheetIsClearWhereNothingIsDrawn;
var
  TmpPNG: TPngImage;
  TmpOpaque, X, Y: Integer;
begin
  TmpPNG := SheetPNG(True);
  try
    Assert.AreEqual(0, Integer(TmpPNG.AlphaScanline[TmpPNG.Height div 2]
      ^[TmpPNG.Width div 2]), 'clear where the paper is empty');
    TmpOpaque := 0;
    for Y := TmpPNG.Height div 4 to TmpPNG.Height div 2 do
      for X := 7 to 12 do
        if TmpPNG.AlphaScanline[Y]^[X] > 128 then
          Inc(TmpOpaque);
    Assert.IsTrue(TmpOpaque > 10, 'and solid where the frame is: ' +
      IntToStr(TmpOpaque));
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.AModelRectangleIsTheRectangleAtTheScale;
var
  TmpStream: TMemoryStream;
  TmpPNG: TPngImage;
  TmpSize: TPoint;
  TmpInk, X, Y: Integer;
begin
  { 200 x 100 units at 2 units to the millimetre is 100 x 50 mm. }
  TmpSize := CADModelRectImageSize(Rect2D(0, 0, 200, 100), 2, 254);
  Assert.AreEqual(1000, TmpSize.X, '100 mm at 254 dpi');
  Assert.AreEqual(500, TmpSize.Y);
  TmpStream := TMemoryStream.Create;
  TmpPNG := TPngImage.Create;
  try
    CADSaveModelRectToPNGStream(FCAD, Rect2D(0, 0, 100, 50), 1, TmpStream, 254);
    TmpStream.Position := 0;
    TmpPNG.LoadFromStream(TmpStream);
    Assert.AreEqual(1000, TmpPNG.Width, 'width');
    Assert.AreEqual(500, TmpPNG.Height, 'height');
    { The line runs corner to corner, so it passes through the middle -
      within a pixel or two, a one-pixel line being anti-aliased across
      the pixel-centre half-pixel. }
    TmpInk := 0;
    for Y := 245 to 255 do
      for X := 495 to 505 do
        if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
          Inc(TmpInk);
    if TmpInk = 0 then
    begin
      { Where the ink is, if not where it was expected: the number that
        says whether this is a placement or nothing drawn at all. }
      for Y := 0 to TmpPNG.Height - 1 do
        for X := 0 to TmpPNG.Width - 1 do
          if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
            Assert.Fail(Format('no ink at the middle; first ink at %d,%d',
              [X, Y]));
      Assert.Fail('no ink in the image at all');
    end;
    Assert.AreEqual(TColor(clWhite), ColorToRGB(TmpPNG.Pixels[900, 100]),
      'and paper away from it');
  finally
    TmpPNG.Free;
    TmpStream.Free;
  end;
end;

procedure TCADImageExportTests.TooLargeAnImageIsRefused;
var
  TmpOld: Int64;
  TmpRaised: Boolean;
  TmpStream: TMemoryStream;
begin
  TmpOld := CADImageMaxPixels;
  CADImageMaxPixels := 1000;
  TmpStream := TMemoryStream.Create;
  try
    TmpRaised := False;
    try
      CADSaveSheetToPNGStream(FCAD, FSheet, TmpStream, 300);
    except
      on ECADPageError do
        TmpRaised := True;
    end;
    Assert.IsTrue(TmpRaised, 'refused, with a reason');
    Assert.AreEqual(Int64(0), TmpStream.Size, 'and nothing written');
  finally
    TmpStream.Free;
    CADImageMaxPixels := TmpOld;
  end;
end;

{ ==================================================================
  TCADSVGExportTests
  ================================================================== }

function CountOf(const ASub, AText: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos(ASub, AText);
  while P > 0 do
  begin
    Inc(Result);
    P := Pos(ASub, AText, P + Length(ASub));
  end;
end;

procedure TCADSVGExportTests.Setup;
begin
  { 1000 x 500 dots at 600 dpi. }
  FSVG := TCADSVGGraphics.Create(1000, 500, 600 / 25.4);
  { Parse switches the DOM vendor; put back whatever was there. }
  FOldVendor := DefaultDOMVendor;
end;

procedure TCADSVGExportTests.TearDown;
begin
  DefaultDOMVendor := FOldVendor;
  FSVG.Free;
end;

function TCADSVGExportTests.Parse(const AText: string): IXMLDocument;
var
  TmpStream: TBytesStream;
begin
  { OmniXML rather than MSXML: no COM to initialise in a console
    runner. }
  DefaultDOMVendor := sOmniXmlVendor;
  TmpStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(AText));
  try
    Result := TXMLDocument.Create(nil);
    Result.LoadFromStream(TmpStream);
    Result.Active := True;
  finally
    TmpStream.Free;
  end;
end;

function TCADSVGExportTests.FindElement(const ANode: IXMLNode;
  const AName: string): IXMLNode;
var
  I: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if ANode.NodeName = AName then
    Exit(ANode);
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Result := FindElement(ANode.ChildNodes[I], AName);
    if Result <> nil then
      Exit;
  end;
end;

function TCADSVGExportTests.ArialSpec(const AHeight: Integer): TCADFontSpec;
begin
  Result := TCADFontSpec.Default;
  Result.FaceName := 'Arial';
  Result.Height := AHeight;
end;

procedure TCADSVGExportTests.ASheetIsAnSVGOfThePaperSize;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpStream: TBytesStream;
  TmpText: string;
  TmpDoc: IXMLDocument;
  TmpDevice: TCADPageDevice;
begin
  TmpCAD := TFNCCADCmp2D.Create(nil);
  TmpStream := TBytesStream.Create;
  try
    TmpCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
    TmpSheet := TmpCAD.Sheets.Add('Plate');
    TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10),
      Point2D(410, 287)));
    CADSaveSheetToSVGStream(TmpCAD, TmpSheet, TmpStream);
    Assert.IsTrue(TmpStream.Size > 0, 'something was written');
    TmpText := TEncoding.UTF8.GetString(TmpStream.Bytes, 0, TmpStream.Size);
    TmpDoc := Parse(TmpText);
    Assert.AreEqual('svg', TmpDoc.DocumentElement.NodeName, 'an SVG');
    Assert.AreEqual('420mm', string(TmpDoc.DocumentElement.Attributes['width']),
      'A3 landscape across');
    Assert.AreEqual('297mm', string(TmpDoc.DocumentElement.Attributes['height']),
      'and down');
    TmpDevice := TCADPageDevice.FromDPI(600, 600);
    Assert.AreEqual(Format('0 0 %d %d', [TmpDevice.MMToPxX(420),
      TmpDevice.MMToPxY(297)]),
      string(TmpDoc.DocumentElement.Attributes['viewBox']),
      'laid out in 600 dpi dots');
    Assert.IsTrue(CountOf('<polyline', TmpText) + CountOf('<polygon', TmpText)
      + CountOf('<rect', TmpText) > 0, 'the frame is drawn');
  finally
    TmpStream.Free;
    TmpCAD.Free;
  end;
end;

procedure TCADSVGExportTests.LineToRunsBecomeOnePolyline;
var
  TmpText: string;
begin
  FSVG.MoveTo(10, 10);
  FSVG.LineTo(100, 10);
  FSVG.LineTo(100, 100);
  { A MoveTo to where the run ends does not break it. }
  FSVG.MoveTo(100, 100);
  FSVG.LineTo(10, 100);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<polyline', TmpText), TmpText);
  Assert.IsTrue(Pos('points="10,10 100,10 100,100 10,100"', TmpText) > 0,
    TmpText);
  Assert.IsTrue(Pos('fill="none"', TmpText) > 0, 'a line is not filled');
end;

procedure TCADSVGExportTests.APenChangeEndsTheRun;
var
  TmpText: string;
begin
  FSVG.MoveTo(0, 0);
  FSVG.LineTo(10, 0);
  FSVG.Pen.Color := cadclRed;
  FSVG.LineTo(10, 10);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('<polyline', TmpText), TmpText);
  Assert.IsTrue(Pos('points="0,0 10,0" fill="none" stroke="#000000"',
    TmpText) > 0, TmpText);
  Assert.IsTrue(Pos('points="10,0 10,10" fill="none" stroke="#FF0000"',
    TmpText) > 0, TmpText);
end;

procedure TCADSVGExportTests.ARectangleCarriesItsFillAndStroke;
var
  TmpText: string;
begin
  FSVG.Brush.Style := cbsSolid;
  FSVG.Brush.Color := cadclRed;
  FSVG.Pen.Color := cadclBlue;
  FSVG.Pen.Width := 3;
  FSVG.Rectangle(10, 20, 30, 50);
  FSVG.Brush.Color := CADColorSetAlpha(cadclLime, 128);
  FSVG.FillRect(Rect(40, 40, 60, 60));
  TmpText := FSVG.SVGText;
  Assert.IsTrue(Pos('<rect x="10" y="20" width="20" height="30" ' +
    'fill="#FF0000" stroke="#0000FF" stroke-width="3"/>', TmpText) > 0,
    TmpText);
  Assert.IsTrue(Pos('<rect x="40" y="40" width="20" height="20" ' +
    'fill="#00FF00" fill-opacity="0.502" stroke="none"/>', TmpText) > 0,
    TmpText);
end;

procedure TCADSVGExportTests.ADashedPenIsDashedAtPaperSize;
var
  TmpText: string;
begin
  FSVG.Pen.Style := cpsDash;
  FSVG.Pen.Width := 1;
  FSVG.Polyline([Point(0, 0), Point(500, 0)]);
  TmpText := FSVG.SVGText;
  { GDI's 18 on, 6 off, in screen pixels - 600/96 dots each. }
  Assert.IsTrue(Pos('stroke-dasharray="112.5,37.5"', TmpText) > 0, TmpText);
end;

procedure TCADSVGExportTests.OneGradientServesEveryShapeThatUsesIt;
var
  TmpText: string;
begin
  FSVG.Brush.Style := cbsGradient;
  FSVG.Brush.Color := cadclRed;
  FSVG.Brush.Color2 := cadclBlue;
  FSVG.Rectangle(0, 0, 100, 20);
  FSVG.Rectangle(0, 30, 100, 50);
  FSVG.Ellipse(0, 60, 100, 80);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<linearGradient', TmpText), TmpText);
  Assert.AreEqual(3, CountOf('fill="url(#grad1)"', TmpText), TmpText);
  Assert.IsTrue(Pos('x2="1" y2="0"', TmpText) > 0, 'left to right');
  Assert.IsTrue(Pos('stop-color="#FF0000"', TmpText) > 0, 'from red');
  Assert.IsTrue(Pos('stop-color="#0000FF"', TmpText) > 0, 'to blue');

  FSVG.Brush.GradientVertical := True;
  FSVG.Rectangle(0, 90, 100, 110);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('<linearGradient', TmpText),
    'top to bottom is another gradient');
  Assert.IsTrue(Pos('x2="0" y2="1"', TmpText) > 0, TmpText);
  Parse(TmpText);
end;

procedure TCADSVGExportTests.AClipIsAGroupWithAClipPath;
var
  TmpText: string;
  TmpGroup, TmpRect, TmpEnd: Integer;
begin
  FSVG.PushClip(Rect(10, 10, 200, 100));
  FSVG.Rectangle(0, 0, 300, 300);
  FSVG.PopClip;
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<clipPath', TmpText), TmpText);
  Assert.IsTrue(Pos('<rect x="10" y="10" width="190" height="90"/>',
    TmpText) > 0, TmpText);
  TmpGroup := Pos('<g clip-path="url(#clip1)">', TmpText);
  TmpRect := Pos('<rect x="0"', TmpText);
  TmpEnd := Pos('</g>', TmpText);
  Assert.IsTrue((TmpGroup > 0) and (TmpGroup < TmpRect) and
    (TmpRect < TmpEnd), 'the rectangle is inside the clipped group');
  Assert.AreEqual(0, FSVG.ClipDepth, 'balanced');
  Parse(TmpText);
end;

procedure TCADSVGExportTests.AClipLeftOpenIsClosedInTheDocument;
var
  TmpText: string;
begin
  FSVG.PushClip(Rect(0, 0, 500, 400));
  FSVG.PushClip(Rect(10, 10, 200, 100));
  FSVG.Rectangle(0, 0, 300, 300);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('</g>', TmpText), TmpText);
  Parse(TmpText);
  FSVG.PopAllClips;
  Assert.AreEqual(2, CountOf('</g>', FSVG.SVGText), 'and not twice');
end;

procedure TCADSVGExportTests.TextIsEscapedAndReadsBack;
var
  TmpR: TRect;
  TmpDoc: IXMLDocument;
  TmpText: IXMLNode;
begin
  FSVG.SelectFont(ArialSpec(-40));
  FSVG.FontColor := cadclRed;
  TmpR := Rect(0, 0, 900, 100);
  FSVG.DrawText('a < b & "c"', TmpR, CAD_DT_SINGLELINE or CAD_DT_NOPREFIX);
  TmpDoc := Parse(FSVG.SVGText);
  TmpText := FindElement(TmpDoc.DocumentElement, 'text');
  Assert.IsTrue(TmpText <> nil, 'a text element');
  Assert.AreEqual('40', string(TmpText.Attributes['font-size']), 'em size');
  Assert.IsTrue(Pos('Arial', string(TmpText.Attributes['font-family'])) > 0,
    'family');
  Assert.AreEqual('#FF0000', string(TmpText.Attributes['fill']), 'colour');
  Assert.AreEqual('a < b & "c"', FindElement(TmpText, 'tspan').Text,
    'the words, unharmed');
end;

procedure TCADSVGExportTests.WordWrapMakesOneLinePerTspan;
var
  TmpOne, TmpR: TRect;
  TmpText: string;
begin
  FSVG.SelectFont(ArialSpec(-40));
  TmpOne := Rect(0, 0, 0, 0);
  FSVG.DrawText('one two', TmpOne, CAD_DT_CALCRECT or CAD_DT_SINGLELINE);
  Assert.IsTrue(TmpOne.Right > 0, 'measured');
  { Room for 'one two' and not a word more. }
  TmpR := Rect(0, 0, TmpOne.Right + 5, 1000);
  FSVG.DrawText('one two one two one two', TmpR, CAD_DT_WORDBREAK);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(3, CountOf('<tspan', TmpText), TmpText);
  Assert.AreEqual(3, CountOf('>one two</tspan>', TmpText), TmpText);

  TmpR := Rect(0, 0, TmpOne.Right + 5, 1000);
  FSVG.DrawText('one two one two one two', TmpR, CAD_DT_WORDBREAK or
    CAD_DT_CALCRECT);
  Assert.AreEqual(3 * TmpOne.Bottom, TmpR.Bottom, 'three lines tall');
end;

procedure TCADSVGExportTests.CalcRectAgreesWithTheFNCBackend;
var
  TmpG: TTMSFNCGraphics;
  TmpFNC: TCADFNCGraphics;
  TmpA, TmpB: TRect;
begin
  TmpG := TTMSFNCGraphics.CreateBitmapCanvas(16, 16, False, False);
  try
    TmpG.BeginScene;
    try
      TmpFNC := TCADFNCGraphics.Create(TmpG, Rect(0, 0, 16, 16), False);
      try
        TmpFNC.SelectFont(ArialSpec(-30));
        TmpA := Rect(0, 0, 0, 0);
        TmpFNC.DrawText('Hello world', TmpA, CAD_DT_CALCRECT or
          CAD_DT_SINGLELINE);
      finally
        TmpFNC.Free;
      end;
    finally
      TmpG.EndScene;
    end;
  finally
    TmpG.Free;
  end;
  FSVG.SelectFont(ArialSpec(-30));
  TmpB := Rect(0, 0, 0, 0);
  FSVG.DrawText('Hello world', TmpB, CAD_DT_CALCRECT or CAD_DT_SINGLELINE);
  Assert.AreEqual(TmpA.Right, TmpB.Right, 'as wide');
  Assert.AreEqual(TmpA.Bottom, TmpB.Bottom, 'as tall');
end;

procedure TCADSVGExportTests.AnImageIsEmbeddedAsADataURI;
var
  TmpPNG: TPngImage;
  TmpStream: TBytesStream;
  TmpImage: TCADImage;
  TmpText: string;
begin
  TmpImage := TCADImage.Create;
  TmpStream := TBytesStream.Create;
  try
    TmpPNG := TPngImage.CreateBlank(COLOR_RGB, 8, 4, 4);
    try
      TmpPNG.SaveToStream(TmpStream);
    finally
      TmpPNG.Free;
    end;
    TmpImage.SetData(Copy(TmpStream.Bytes, 0, TmpStream.Size));
    FSVG.DrawImage(Rect(10, 10, 110, 60), TmpImage, 0);
    TmpText := FSVG.SVGText;
    Assert.IsTrue(Pos('<image x="10" y="10" width="100" height="50"',
      TmpText) > 0, TmpText);
    { The PNG signature, base64 encoded. }
    Assert.IsTrue(Pos('xlink:href="data:image/png;base64,iVBORw0KGgo',
      TmpText) > 0, 'the PNG itself');
    Parse(TmpText);
  finally
    TmpStream.Free;
    TmpImage.Free;
  end;
end;

procedure TCADSVGExportTests.SeveralSheetsNeedAPattern;
var
  TmpCAD: TFNCCADCmp2D;
  TmpA, TmpB: TCADSheet;
  TmpDir: string;
begin
  TmpDir := TPath.Combine(TPath.GetTempPath, 'CADSysSVGTest');
  TDirectory.CreateDirectory(TmpDir);
  TmpCAD := TFNCCADCmp2D.Create(nil);
  try
    TmpA := TmpCAD.Sheets.Add('A');
    TmpB := TmpCAD.Sheets.Add('B');
    Assert.WillRaise(
      procedure
      begin
        CADSaveSheetsToSVG(TmpCAD, [TmpA, TmpB],
          TPath.Combine(TmpDir, 'plate.svg'));
      end, ECADPageError, 'one name for two files');
    CADSaveSheetsToSVG(TmpCAD, [TmpA, TmpB],
      TPath.Combine(TmpDir, 'plate-%d.svg'));
    Assert.IsTrue(TFile.Exists(TPath.Combine(TmpDir, 'plate-1.svg')), 'first');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TmpDir, 'plate-2.svg')), 'second');
  finally
    TmpCAD.Free;
    TDirectory.Delete(TmpDir, True);
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TCADImageExportTests);
TDUnitX.RegisterTestFixture(TCADSVGExportTests);
TDUnitX.RegisterTestFixture(TCADFNCGraphicsTests);

end.
