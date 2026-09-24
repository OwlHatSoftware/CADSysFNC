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
  VCL.FNCCADSys4, VCL.FNCCS4Shapes, VCL.FNCCadSysRegister;

type
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

initialization
  TDUnitX.RegisterTestFixture(TCADFNCGraphicsTests);

end.
