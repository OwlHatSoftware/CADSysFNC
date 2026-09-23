{ : DUnitX tests for the drawing layer (VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsVCL) and for
  TDecorativeCanvas on top of it.

  Two kinds of test live here:

  - VCL backend tests draw into an off-screen TBitmap and read pixels back.
    They pin the promise that the GDI backend behaves exactly like the
    TCanvas code it replaced, and that pen/brush state is shared with the
    wrapped TCanvas.

  - Recording backend tests use TRecordingGraphics, a backend that draws
    nothing and only logs calls. Shapes are drawn through it to prove they
    no longer need a TCanvas, which is the precondition for the FNC port.
}
unit CADSys4.Tests.Graphics;

interface

uses
  System.SysUtils, System.Types, System.Classes,
  Vcl.Graphics,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsVCL,
  VCL.FNCCADSys4, VCL.FNCCS4Shapes, VCL.FNCCadSysRegister;

type
  { A backend that records what it is asked to draw. }
  TRecordingPen = class(TCADPen)
  private
    fColor: TCADColor;
    fWidth: Integer;
    fStyle: TCADPenStyle;
    fMode: TCADPenMode;
  protected
    function GetColor: TCADColor; override;
    procedure SetColor(const Value: TCADColor); override;
    function GetWidth: Integer; override;
    procedure SetWidth(const Value: Integer); override;
    function GetStyle: TCADPenStyle; override;
    procedure SetStyle(const Value: TCADPenStyle); override;
    function GetMode: TCADPenMode; override;
    procedure SetMode(const Value: TCADPenMode); override;
  end;

  TRecordingBrush = class(TCADBrush)
  private
    fColor: TCADColor;
    fStyle: TCADBrushStyle;
  protected
    function GetColor: TCADColor; override;
    procedure SetColor(const Value: TCADColor); override;
    function GetStyle: TCADBrushStyle; override;
    procedure SetStyle(const Value: TCADBrushStyle); override;
  end;

  TRecordingGraphics = class(TCADGraphics)
  private
    fLog: TStringList;
    fClip: TRect;
    fFontColor: TCADColor;
    fTransparent: Boolean;
    fPointsDrawn: Integer;
  protected
    function CreatePen: TCADPen; override;
    function CreateBrush: TCADBrush; override;
    function GetFontColor: TCADColor; override;
    procedure SetFontColor(const Value: TCADColor); override;
    function GetTransparent: Boolean; override;
    procedure SetTransparent(const Value: Boolean); override;
    function GetClipRect: TRect; override;
  public
    constructor Create(const AClip: TRect);
    destructor Destroy; override;
    procedure MoveTo(const X, Y: Integer); override;
    procedure LineTo(const X, Y: Integer); override;
    procedure Polyline(const Pts: Pointer; const Count: Integer); overload; override;
    procedure DoPolygon(const Pts: Pointer; const Count: Integer); override;
    procedure DoRectangle(const X1, Y1, X2, Y2: Integer); override;
    procedure DoEllipse(const X1, Y1, X2, Y2: Integer); override;
    procedure DoFillRect(const R: TRect); override;
    procedure SelectFont(const Font: TCADFontSpec); override;
    procedure ResetFont; override;
    function DrawText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer; override;
    procedure DrawImage(const Dest: TRect; const Image: TCADImage;
      const CopyMode: LongInt); override;
    function CountOf(const Prefix: string): Integer;
    property Log: TStringList read fLog;
    property PointsDrawn: Integer read fPointsDrawn;
  end;

  [TestFixture]
  TCADGraphicsCoreTests = class(TObject)
  public
    [Test]
    procedure TColorConversion_SwapsRedAndBlue;
    [Test]
    procedure TColorConversion_SystemColourIsResolved;
    [Test]
    procedure Alpha_IsReadAndReplaced;
    [Test]
    procedure Blend_MixesTowardsTheBackground;
    [Test]
    procedure FontSpec_SameComparesEveryField;
    [Test]
    procedure SaveRestoreState_RoundTrips;
    [Test]
    procedure PenAssign_CopiesAllFields;
  end;

  [TestFixture]
  TCADVCLGraphicsTests = class(TObject)
  private
    FBmp: TBitmap;
    FCnv: TDecorativeCanvas;
    procedure ClearWhite;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PenColour_IsSharedWithTheCanvas;
    [Test]
    procedure TranslucentPen_IsFlattenedOntoTheBackground;
    [Test]
    procedure FullyTransparentPen_DrawsNothing;
    [Test]
    procedure PenMode_SetOnTheCanvas_IsSeenThroughTheLayer;
    [Test]
    procedure BrushStyle_MapsBothWays;
    [Test]
    procedure CanvasProperty_ReturnsTheWrappedCanvas;
    [Test]
    procedure ClipRect_MatchesTheCanvas;
    [Test]
    procedure Polygon_FillsWithTheBrush;
    [Test]
    procedure Polyline_DoesNotFill;
    [Test]
    procedure DecorativeMoveToLineTo_DrawsALine;
    [Test]
    procedure Transparent_RoundTrips;
    [Test]
    procedure DrawText_CalcRect_GrowsTheRectangle;
    [Test]
    procedure SelectFont_TwiceWithTheSameSpec_DoesNotFail;
  end;

  [TestFixture]
  TShapesThroughRecordingBackendTests = class(TObject)
  private
    FRec: TRecordingGraphics;
    FCnv: TDecorativeCanvas;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DecorativeCanvas_WithNonVCLBackend_HasNoCanvas;
    [Test]
    procedure Line2D_DrawsOneSegment;
    [Test]
    procedure Polygon2D_DrawsAPolygon;
    [Test]
    procedure Line2D_OutsideTheClip_DrawsNothing;
    [Test]
    procedure Text2D_SelectsAndReleasesItsFont;
    [Test]
    procedure Line2D_DrawControlPoints_UsesOnlyTheLayer;
  end;

  { : TCADImage is the platform-neutral picture TBitmap2D holds. These
    tests use the VCL bridge to make one, because that is how a caller
    with a TBitmap gets there. }
  { : The hatch generator, which is pure geometry - polygon in, line
    segments out - and so can be tested without a canvas anywhere near
    it. That is most of the reason it was written that way. }
  [TestFixture]
  THatchGeometryTests = class(TObject)
  private
    function Square(const ASize: Integer): TArray<TPoint>;
  public
    [Test]
    procedure SolidBrush_ProducesNoLines;
    [Test]
    procedure TooFewPoints_ProduceNoLines;
    [Test]
    procedure Horizontal_Square_LinesAreSpacedAndSpanTheWidth;
    [Test]
    procedure Vertical_Square_LinesRunTopToBottom;
    [Test]
    procedure Cross_IsHorizontalPlusVertical;
    [Test]
    procedure DiagCross_IsBothDiagonals;
    [Test]
    procedure Diagonal_LinesAreAtFortyFiveDegrees;
    [Test]
    procedure Concave_LineAcrossTheNotchBreaksInTwo;
    [Test]
    procedure LinesSitOnAGridAnchoredAtTheOrigin;
    [Test]
    procedure EverySegmentStaysInsideTheShape;
  end;

  [TestFixture]
  TCADImageTests = class
  private
    FImg: TCADImage;
    function MakeBitmap(const W, H: Integer): TBitmap;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Empty_HasNoBytesAndNoSize;
    [Test]
    procedure FromBitmap_ReadsTheSizeOutOfThePngHeader;
    [Test]
    procedure RoundTrip_ThroughTheVCLBridge_KeepsTheSize;
    [Test]
    procedure Assign_CopiesTheBytes;
    [Test]
    procedure Cache_IsHandedBackToItsOwnerOnly;
    [Test]
    procedure Cache_IsDroppedWhenTheBytesChange;
    [Test]
    procedure UnknownFormat_HasNoSizeButKeepsItsBytes;
  end;

implementation

{ TRecordingPen }

function TRecordingPen.GetColor: TCADColor; begin Result := fColor; end;
procedure TRecordingPen.SetColor(const Value: TCADColor); begin fColor := Value; end;
function TRecordingPen.GetWidth: Integer; begin Result := fWidth; end;
procedure TRecordingPen.SetWidth(const Value: Integer); begin fWidth := Value; end;
function TRecordingPen.GetStyle: TCADPenStyle; begin Result := fStyle; end;
procedure TRecordingPen.SetStyle(const Value: TCADPenStyle); begin fStyle := Value; end;
function TRecordingPen.GetMode: TCADPenMode; begin Result := fMode; end;
procedure TRecordingPen.SetMode(const Value: TCADPenMode); begin fMode := Value; end;

{ TRecordingBrush }

function TRecordingBrush.GetColor: TCADColor; begin Result := fColor; end;
procedure TRecordingBrush.SetColor(const Value: TCADColor); begin fColor := Value; end;
function TRecordingBrush.GetStyle: TCADBrushStyle; begin Result := fStyle; end;
procedure TRecordingBrush.SetStyle(const Value: TCADBrushStyle); begin fStyle := Value; end;

{ TRecordingGraphics }

constructor TRecordingGraphics.Create(const AClip: TRect);
begin
  fLog := TStringList.Create;
  fClip := AClip;
  inherited Create;
  Pen.Mode := cpmCopy;
  Pen.Width := 1;
end;

destructor TRecordingGraphics.Destroy;
begin
  inherited Destroy;
  fLog.Free;
end;

function TRecordingGraphics.CreatePen: TCADPen; begin Result := TRecordingPen.Create; end;
function TRecordingGraphics.CreateBrush: TCADBrush; begin Result := TRecordingBrush.Create; end;
function TRecordingGraphics.GetFontColor: TCADColor; begin Result := fFontColor; end;
procedure TRecordingGraphics.SetFontColor(const Value: TCADColor); begin fFontColor := Value; end;
function TRecordingGraphics.GetTransparent: Boolean; begin Result := fTransparent; end;
procedure TRecordingGraphics.SetTransparent(const Value: Boolean); begin fTransparent := Value; end;
function TRecordingGraphics.GetClipRect: TRect; begin Result := fClip; end;

procedure TRecordingGraphics.MoveTo(const X, Y: Integer);
begin
  fLog.Add(Format('MoveTo %d,%d', [X, Y]));
end;

procedure TRecordingGraphics.LineTo(const X, Y: Integer);
begin
  fLog.Add(Format('LineTo %d,%d', [X, Y]));
  Inc(fPointsDrawn);
end;

procedure TRecordingGraphics.Polyline(const Pts: Pointer; const Count: Integer);
begin
  fLog.Add(Format('Polyline %d', [Count]));
  Inc(fPointsDrawn, Count);
end;

procedure TRecordingGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
begin
  fLog.Add(Format('Polygon %d', [Count]));
  Inc(fPointsDrawn, Count);
end;

procedure TRecordingGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
begin
  fLog.Add('Rectangle');
end;

procedure TRecordingGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
begin
  fLog.Add('Ellipse');
end;

procedure TRecordingGraphics.DoFillRect(const R: TRect);
begin
  fLog.Add('FillRect');
end;

procedure TRecordingGraphics.SelectFont(const Font: TCADFontSpec);
begin
  fLog.Add('SelectFont');
end;

procedure TRecordingGraphics.ResetFont;
begin
  fLog.Add('ResetFont');
end;

function TRecordingGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
begin
  if (Flags and CAD_DT_CALCRECT) <> 0 then
  begin
    fLog.Add('CalcText');
    R.Right := R.Left + 8 * Length(Text);
    R.Bottom := R.Top + 12;
  end
  else
    fLog.Add('DrawText ' + Text);
  Result := R.Bottom - R.Top;
end;

procedure TRecordingGraphics.DrawImage(const Dest: TRect;
  const Image: TCADImage; const CopyMode: LongInt);
begin
  fLog.Add('DrawImage');
end;

function TRecordingGraphics.CountOf(const Prefix: string): Integer;
var
  S: string;
begin
  Result := 0;
  for S in fLog do
    if S.StartsWith(Prefix) then
      Inc(Result);
end;

{ TCADGraphicsCoreTests }

procedure TCADGraphicsCoreTests.TColorConversion_SwapsRedAndBlue;
begin
  { TColor is $00BBGGRR, TCADColor is $AARRGGBB. }
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed),
    Cardinal(TColorToCADColor(clRed)));
  Assert.AreEqual<Cardinal>(Cardinal(cadclBlue),
    Cardinal(TColorToCADColor(clBlue)));
  Assert.AreEqual<Cardinal>(Cardinal($FF123456),
    Cardinal(TColorToCADColor(TColor($563412))));
  Assert.AreEqual(TColor($563412), CADColorToTColor(TCADColor($FF123456)));
end;

procedure TCADGraphicsCoreTests.TColorConversion_SystemColourIsResolved;
var
  TmpSaved: TCADColorResolver;
begin
  { A system colour has its high byte set, so its low three bytes are an
    index into the theme rather than a BGR triple. The drawing layer cannot
    know what clBtnFace means - only the framework does - so a backend
    installs CADResolveSystemColor and VCL.FNCCS4GraphicsVCL points it at
    Vcl.Graphics.ColorToRGB. With that hook in place the conversion has to
    give the same answer as resolving by hand. }
  Assert.IsTrue(Assigned(CADResolveSystemColor),
    'linking VCL.FNCCS4GraphicsVCL installs the resolver');
  Assert.AreEqual<Cardinal>(Cardinal(TColorToCADColor(ColorToRGB(clBtnFace))),
    Cardinal(TColorToCADColor(clBtnFace)), 'resolved, not taken literally');
  Assert.AreNotEqual<Cardinal>(Cardinal(cadclBlack),
    Cardinal(TColorToCADColor(clBtnFace)),
    'the old behaviour - every system colour collapsing to black - is gone');
  Assert.IsTrue(CADColorIsOpaque(TColorToCADColor(clBtnFace)),
    'a resolved system colour is still fully opaque');

  { Without a resolver there is nothing sensible to return, so the layer
    falls back to opaque black rather than reading the index as a colour. }
  TmpSaved := CADResolveSystemColor;
  try
    CADResolveSystemColor := nil;
    Assert.AreEqual<Cardinal>(Cardinal(cadclBlack),
      Cardinal(TColorToCADColor(clBtnFace)), 'fallback with no backend');
  finally
    CADResolveSystemColor := TmpSaved;
  end;
end;

procedure TCADGraphicsCoreTests.Alpha_IsReadAndReplaced;
var
  TmpColor: TCADColor;
begin
  Assert.AreEqual<Byte>($FF, CADColorAlpha(cadclRed), 'constants are opaque');
  Assert.IsTrue(CADColorIsOpaque(cadclRed), 'IsOpaque');
  TmpColor := CADColorSetAlpha(cadclRed, 128);
  Assert.AreEqual<Byte>(128, CADColorAlpha(TmpColor), 'alpha replaced');
  Assert.IsFalse(CADColorIsOpaque(TmpColor), 'no longer opaque');
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed) and $00FFFFFF,
    Cardinal(TmpColor) and $00FFFFFF, 'the colour itself is untouched');
  Assert.AreEqual<Cardinal>(Cardinal(CADColor($80, $12, $34, $56)),
    Cardinal(TCADColor($80123456)), 'CADColor composes the channels');
end;

procedure TCADGraphicsCoreTests.Blend_MixesTowardsTheBackground;
var
  TmpHalf: TCADColor;
begin
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed),
    Cardinal(CADBlendColor(cadclRed, cadclWhite)), 'opaque passes through');
  Assert.AreEqual<Cardinal>(Cardinal(cadclWhite),
    Cardinal(CADBlendColor(CADColorSetAlpha(cadclRed, 0), cadclWhite)),
    'fully transparent gives the background');
  TmpHalf := CADBlendColor(CADColorSetAlpha(cadclBlack, 128), cadclWhite);
  Assert.IsTrue(CADColorIsOpaque(TmpHalf), 'the result is opaque');
  Assert.IsTrue((CADColorAlpha(TmpHalf) = $FF) and
    (Cardinal(TmpHalf) and $FF > $70) and (Cardinal(TmpHalf) and $FF < $90),
    'half of black on white lands mid grey');
end;

procedure TCADGraphicsCoreTests.FontSpec_SameComparesEveryField;
var
  A, B: TCADFontSpec;
begin
  A := TCADFontSpec.Default;
  B := A;
  Assert.IsTrue(TCADFontSpec.Same(A, B));
  B.Escapement := 900;
  Assert.IsFalse(TCADFontSpec.Same(A, B), 'escapement');
  B := A;
  B.FaceName := 'Arial';
  Assert.IsFalse(TCADFontSpec.Same(A, B), 'face name');
  B := A;
  B.Italic := True;
  Assert.IsFalse(TCADFontSpec.Same(A, B), 'italic');
end;

procedure TCADGraphicsCoreTests.SaveRestoreState_RoundTrips;
var
  G: TRecordingGraphics;
  St: TCADGraphicsState;
begin
  G := TRecordingGraphics.Create(Rect(0, 0, 10, 10));
  try
    G.Pen.Color := cadclRed;
    G.Pen.Width := 3;
    G.Pen.Style := cpsDash;
    G.Pen.Mode := cpmXor;
    G.Brush.Color := cadclLime;
    G.Brush.Style := cbsClear;
    St := G.SaveState;
    G.Pen.Color := cadclBlue;
    G.Pen.Width := 1;
    G.Pen.Style := cpsSolid;
    G.Pen.Mode := cpmCopy;
    G.Brush.Color := cadclWhite;
    G.Brush.Style := cbsSolid;
    G.RestoreState(St);
    Assert.AreEqual<Cardinal>(Cardinal(cadclRed), Cardinal(G.Pen.Color));
    Assert.AreEqual(3, G.Pen.Width);
    Assert.IsTrue(G.Pen.Style = cpsDash, 'pen style');
    Assert.IsTrue(G.Pen.Mode = cpmXor, 'pen mode');
    Assert.AreEqual<Cardinal>(Cardinal(cadclLime), Cardinal(G.Brush.Color));
    Assert.IsTrue(G.Brush.Style = cbsClear, 'brush style');
  finally
    G.Free;
  end;
end;

procedure TCADGraphicsCoreTests.PenAssign_CopiesAllFields;
var
  A, B: TRecordingGraphics;
begin
  A := TRecordingGraphics.Create(Rect(0, 0, 1, 1));
  B := TRecordingGraphics.Create(Rect(0, 0, 1, 1));
  try
    A.Pen.Color := cadclTeal;
    A.Pen.Width := 4;
    A.Pen.Style := cpsDot;
    A.Pen.Mode := cpmNotXor;
    B.Pen.Assign(A.Pen);
    Assert.AreEqual<Cardinal>(Cardinal(cadclTeal), Cardinal(B.Pen.Color));
    Assert.AreEqual(4, B.Pen.Width);
    Assert.IsTrue(B.Pen.Style = cpsDot);
    Assert.IsTrue(B.Pen.Mode = cpmNotXor);
  finally
    A.Free;
    B.Free;
  end;
end;

{ TCADVCLGraphicsTests }

procedure TCADVCLGraphicsTests.Setup;
begin
  FBmp := TBitmap.Create;
  FBmp.PixelFormat := pf24bit;
  FBmp.SetSize(40, 40);
  FCnv := TDecorativeCanvas.Create(FBmp.Canvas);
  ClearWhite;
end;

procedure TCADVCLGraphicsTests.TearDown;
begin
  FCnv.Free;
  FBmp.Free;
end;

procedure TCADVCLGraphicsTests.ClearWhite;
begin
  FBmp.Canvas.Brush.Style := bsSolid;
  FBmp.Canvas.Brush.Color := clWhite;
  FBmp.Canvas.FillRect(Rect(0, 0, 40, 40));
end;

procedure TCADVCLGraphicsTests.PenColour_IsSharedWithTheCanvas;
begin
  { An opaque colour reaches GDI unchanged. The layer keeps the ARGB
    value, which the canvas cannot hold. }
  FCnv.Pen.Color := cadclRed;
  Assert.AreEqual(TColor(clRed), FBmp.Canvas.Pen.Color, 'canvas pen');
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed), Cardinal(FCnv.Pen.Color),
    'the layer keeps the colour it was given');
end;

procedure TCADVCLGraphicsTests.TranslucentPen_IsFlattenedOntoTheBackground;
begin
  FCnv.Graphics.BlendBackground := cadclWhite;
  FCnv.Pen.Color := CADColorSetAlpha(cadclBlack, 128);
  Assert.AreNotEqual(Integer(clBlack), Integer(FBmp.Canvas.Pen.Color),
    'GDI gets a blended colour, not the raw one');
  Assert.AreEqual<Cardinal>(Cardinal(CADColorSetAlpha(cadclBlack, 128)),
    Cardinal(FCnv.Pen.Color), 'the alpha itself survives in the layer');
  { Changing the background re-flattens what is already set. }
  FCnv.Graphics.BlendBackground := cadclBlack;
  Assert.AreEqual(TColor(clBlack), FBmp.Canvas.Pen.Color,
    'black on black is black');
end;

procedure TCADVCLGraphicsTests.FullyTransparentPen_DrawsNothing;
begin
  ClearWhite;
  FCnv.Pen.Color := CADColorSetAlpha(cadclRed, 0);
  FCnv.MoveTo(2, 20);
  FCnv.LineTo(38, 20);
  Assert.AreEqual(TColor(clWhite), FBmp.Canvas.Pixels[20, 20],
    'an alpha of zero draws nothing');
end;

procedure TCADVCLGraphicsTests.PenMode_SetOnTheCanvas_IsSeenThroughTheLayer;
begin
  FBmp.Canvas.Pen.Mode := pmXor;
  Assert.IsTrue(FCnv.Pen.Mode = cpmXor);
  FCnv.Pen.Mode := cpmCopy;
  Assert.IsTrue(FBmp.Canvas.Pen.Mode = pmCopy);
end;

procedure TCADVCLGraphicsTests.BrushStyle_MapsBothWays;
var
  S: TCADBrushStyle;
begin
  for S := Low(TCADBrushStyle) to High(TCADBrushStyle) do
  begin
    FCnv.Brush.Style := S;
    Assert.IsTrue(FCnv.Brush.Style = S, 'brush style ' + IntToStr(Ord(S)));
    Assert.AreEqual(Ord(S), Ord(FBmp.Canvas.Brush.Style),
      'ordinal ' + IntToStr(Ord(S)));
  end;
end;

procedure TCADVCLGraphicsTests.CanvasProperty_ReturnsTheWrappedCanvas;
begin
  Assert.AreSame(FBmp.Canvas, FCnv.Canvas);
  Assert.IsTrue(FCnv.Graphics is TCADVCLGraphics);
end;

procedure TCADVCLGraphicsTests.ClipRect_MatchesTheCanvas;
var
  A, B: TRect;
begin
  A := FCnv.ClipRect;
  B := FBmp.Canvas.ClipRect;
  Assert.AreEqual(B.Left, A.Left);
  Assert.AreEqual(B.Top, A.Top);
  Assert.AreEqual(B.Right, A.Right);
  Assert.AreEqual(B.Bottom, A.Bottom);
end;

procedure TCADVCLGraphicsTests.Polygon_FillsWithTheBrush;
const
  Pts: array[0..3] of TPoint = ((X: 5; Y: 5), (X: 30; Y: 5), (X: 30; Y: 30),
    (X: 5; Y: 30));
begin
  FCnv.Pen.Color := cadclLime;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polygon(@Pts[0], 4);
  Assert.AreEqual(TColor(clLime), FBmp.Canvas.Pixels[17, 17]);
end;

procedure TCADVCLGraphicsTests.Polyline_DoesNotFill;
const
  Pts: array[0..4] of TPoint = ((X: 5; Y: 5), (X: 30; Y: 5), (X: 30; Y: 30),
    (X: 5; Y: 30), (X: 5; Y: 5));
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polyline(@Pts[0], 5);
  Assert.AreEqual(TColor(clWhite), FBmp.Canvas.Pixels[17, 17], 'inside');
  Assert.AreEqual(TColor(clRed), FBmp.Canvas.Pixels[17, 5], 'edge');
end;

procedure TCADVCLGraphicsTests.DecorativeMoveToLineTo_DrawsALine;
begin
  FCnv.Pen.Color := cadclBlue;
  FCnv.Pen.Width := 1;
  FCnv.MoveTo(2, 20);
  FCnv.LineTo(38, 20);
  Assert.AreEqual(TColor(clBlue), FBmp.Canvas.Pixels[20, 20]);
  Assert.AreEqual(TColor(clWhite), FBmp.Canvas.Pixels[20, 22]);
end;

procedure TCADVCLGraphicsTests.Transparent_RoundTrips;
begin
  FCnv.Graphics.Transparent := True;
  Assert.IsTrue(FCnv.Graphics.Transparent);
  FCnv.Graphics.Transparent := False;
  Assert.IsFalse(FCnv.Graphics.Transparent);
end;

procedure TCADVCLGraphicsTests.DrawText_CalcRect_GrowsTheRectangle;
var
  R: TRect;
begin
  R := Rect(0, 0, 0, 0);
  FCnv.Graphics.SelectFont(TCADFontSpec.Default);
  try
    FCnv.Graphics.DrawText('CADSys', R, CAD_DT_CALCRECT);
  finally
    FCnv.Graphics.ResetFont;
  end;
  Assert.IsTrue(R.Right > 0, 'width');
  Assert.IsTrue(R.Bottom > 0, 'height');
end;

procedure TCADVCLGraphicsTests.SelectFont_TwiceWithTheSameSpec_DoesNotFail;
var
  F: TCADFontSpec;
  R: TRect;
begin
  F := TCADFontSpec.Default;
  FCnv.Graphics.SelectFont(F);
  FCnv.Graphics.SelectFont(F);
  F.Height := -20;
  FCnv.Graphics.SelectFont(F);
  R := Rect(0, 0, 40, 40);
  FCnv.Graphics.DrawText('x', R, 0);
  FCnv.Graphics.ResetFont;
  FCnv.Graphics.ResetFont;
  Assert.Pass;
end;

{ TShapesThroughRecordingBackendTests }

procedure TShapesThroughRecordingBackendTests.Setup;
begin
  FRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  FCnv := TDecorativeCanvas.Create(FRec, True);
end;

procedure TShapesThroughRecordingBackendTests.TearDown;
begin
  FCnv.Free; // owns FRec
  FRec := nil;
end;

procedure TShapesThroughRecordingBackendTests.DecorativeCanvas_WithNonVCLBackend_HasNoCanvas;
begin
  Assert.IsNull(FCnv.Canvas);
  Assert.AreSame(FRec, FCnv.Graphics);
end;

procedure TShapesThroughRecordingBackendTests.Line2D_DrawsOneSegment;
var
  L: TLine2D;
begin
  L := TLine2D.Create(1, Point2D(10, 10), Point2D(50, 50));
  try
    L.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, 100, 100), DRAWMODE_NORMAL);
  finally
    L.Free;
  end;
  { DrawLine2D emits MoveTo + LineTo. }
  Assert.AreEqual(1, FRec.CountOf('MoveTo 10,10'), FRec.Log.Text);
  Assert.AreEqual(1, FRec.CountOf('LineTo 50,50'), FRec.Log.Text);
  Assert.AreEqual(0, FRec.CountOf('Polygon'), FRec.Log.Text);
end;

procedure TShapesThroughRecordingBackendTests.Polygon2D_DrawsAPolygon;
var
  P: TPolygon2D;
begin
  P := TPolygon2D.Create(2, [Point2D(10, 10), Point2D(60, 10),
    Point2D(60, 60), Point2D(10, 60)]);
  try
    P.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, 100, 100), DRAWMODE_NORMAL);
  finally
    P.Free;
  end;
  Assert.IsTrue(FRec.CountOf('Polygon') >= 1, FRec.Log.Text);
end;

procedure TShapesThroughRecordingBackendTests.Line2D_OutsideTheClip_DrawsNothing;
var
  L: TLine2D;
begin
  L := TLine2D.Create(3, Point2D(500, 500), Point2D(600, 600));
  try
    L.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, 100, 100), DRAWMODE_NORMAL);
  finally
    L.Free;
  end;
  Assert.AreEqual(0, FRec.PointsDrawn, FRec.Log.Text);
end;

procedure TShapesThroughRecordingBackendTests.Text2D_SelectsAndReleasesItsFont;
var
  T: TText2D;
begin
  T := TText2D.Create(4, Rect2D(10, 10, 60, 30), 12, 'Hello');
  try
    T.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, 100, 100), DRAWMODE_NORMAL);
  finally
    T.Free;
  end;
  Assert.AreEqual(1, FRec.CountOf('SelectFont'), FRec.Log.Text);
  Assert.AreEqual(1, FRec.CountOf('ResetFont'), FRec.Log.Text);
  Assert.AreEqual(1, FRec.CountOf('DrawText Hello'), FRec.Log.Text);
end;

procedure TShapesThroughRecordingBackendTests.Line2D_DrawControlPoints_UsesOnlyTheLayer;
var
  L: TLine2D;
begin
  L := TLine2D.Create(5, Point2D(10, 10), Point2D(50, 50));
  try
    L.DrawControlPoints(IdentityTransf2D, FCnv, Rect2D(0, 0, 100, 100), 5);
  finally
    L.Free;
  end;
  { Control points are the silver placeholder squares. }
  Assert.IsTrue(FRec.CountOf('Rectangle') + FRec.CountOf('Ellipse') >= 2,
    FRec.Log.Text);
  Assert.AreEqual<Cardinal>(Cardinal(cadclSilver), Cardinal(FRec.Brush.Color));
end;

{ ================================================================== }
{ TCADImageTests }
{ ================================================================== }

function TCADImageTests.MakeBitmap(const W, H: Integer): TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(W, H);
  Result.Canvas.Brush.Color := clRed;
  Result.Canvas.FillRect(Rect(0, 0, W, H));
end;

procedure TCADImageTests.Setup;
begin
  FImg := TCADImage.Create;
end;

procedure TCADImageTests.TearDown;
begin
  FImg.Free;
end;

procedure TCADImageTests.Empty_HasNoBytesAndNoSize;
begin
  Assert.IsTrue(FImg.IsEmpty, 'IsEmpty');
  Assert.AreEqual(0, FImg.Width, 'Width');
  Assert.AreEqual(0, FImg.Height, 'Height');
end;

procedure TCADImageTests.FromBitmap_ReadsTheSizeOutOfThePngHeader;
var
  Bmp: TBitmap;
  Tmp: TCADImage;
begin
  Bmp := MakeBitmap(37, 11);
  try
    Tmp := CADImageFromBitmap(Bmp);
    try
      Assert.IsFalse(Tmp.IsEmpty, 'the bitmap was encoded');
      { Nothing decoded it - the size comes from the PNG IHDR. }
      Assert.AreEqual(37, Tmp.Width, 'Width');
      Assert.AreEqual(11, Tmp.Height, 'Height');
    finally
      Tmp.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

procedure TCADImageTests.RoundTrip_ThroughTheVCLBridge_KeepsTheSize;
var
  Bmp, Back: TBitmap;
  Tmp: TCADImage;
begin
  Bmp := MakeBitmap(24, 8);
  Back := TBitmap.Create;
  try
    Tmp := CADImageFromBitmap(Bmp);
    try
      Assert.IsTrue(CADImageToBitmap(Tmp, Back), 'decoded');
      Assert.AreEqual(24, Back.Width, 'Width');
      Assert.AreEqual(8, Back.Height, 'Height');
      Assert.AreEqual(Integer(clRed), Integer(ColorToRGB(Back.Canvas.Pixels[3, 3])),
        'and the pixels survived');
    finally
      Tmp.Free;
    end;
  finally
    Back.Free;
    Bmp.Free;
  end;
end;

procedure TCADImageTests.Assign_CopiesTheBytes;
var
  Bmp: TBitmap;
  Src: TCADImage;
begin
  Bmp := MakeBitmap(16, 16);
  try
    Src := CADImageFromBitmap(Bmp);
    try
      FImg.Assign(Src);
      Assert.AreEqual(Length(Src.Data), Length(FImg.Data), 'byte count');
      Assert.AreEqual(16, FImg.Width, 'Width');
      Src.Clear;
      Assert.IsFalse(FImg.IsEmpty, 'the copy is independent');
    finally
      Src.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

procedure TCADImageTests.Cache_IsHandedBackToItsOwnerOnly;
var
  OwnerA, OwnerB: TObject;
  Cached: TStringList;
begin
  OwnerA := TObject.Create;
  OwnerB := TObject.Create;
  try
    Cached := TStringList.Create;
    FImg.SetCache(OwnerA, Cached);
    Assert.IsTrue(FImg.CacheFor(OwnerA) = Cached, 'its owner gets it back');
    Assert.IsTrue(FImg.CacheFor(OwnerB) = nil,
      'another backend has to decode for itself');
  finally
    OwnerB.Free;
    OwnerA.Free;
  end;
end;

procedure TCADImageTests.Cache_IsDroppedWhenTheBytesChange;
var
  Owner: TObject;
  Bytes: TBytes;
begin
  Owner := TObject.Create;
  try
    FImg.SetCache(Owner, TStringList.Create);
    Assert.IsTrue(FImg.CacheFor(Owner) <> nil, 'precondition');
    SetLength(Bytes, 4);
    FImg.SetData(Bytes);
    Assert.IsTrue(FImg.CacheFor(Owner) = nil,
      'a new picture invalidates the decoded copy');
  finally
    Owner.Free;
  end;
end;

{ THatchGeometryTests }

function THatchGeometryTests.Square(const ASize: Integer): TArray<TPoint>;
begin
  Result := [Point(0, 0), Point(ASize, 0), Point(ASize, ASize),
    Point(0, ASize)];
end;

procedure THatchGeometryTests.SolidBrush_ProducesNoLines;
begin
  Assert.AreEqual(0, Length(CADHatchLines(Square(100), cbsSolid)),
    'a solid brush is a fill, not a hatch');
  Assert.AreEqual(0, Length(CADHatchLines(Square(100), cbsClear)),
    'and a clear one is neither');
end;

procedure THatchGeometryTests.TooFewPoints_ProduceNoLines;
begin
  Assert.AreEqual(0, Length(CADHatchLines([Point(0, 0), Point(10, 10)],
    cbsHorizontal)), 'two points do not enclose anything');
end;

procedure THatchGeometryTests.Horizontal_Square_LinesAreSpacedAndSpanTheWidth;
var
  Segs: TCADHatchSegments;
  Cont: Integer;
begin
  CADHatchSpacing := 8;
  Segs := CADHatchLines(Square(100), cbsHorizontal);
  { y = 0, 8, .. 96. The bottom edge is not hatched: the scanline rule
    is half-open so that a vertex shared by two edges is counted once. }
  Assert.AreEqual(13, Length(Segs), 'one line every 8 pixels');
  for Cont := 0 to High(Segs) do
  begin
    Assert.AreEqual(Cont * 8, Segs[Cont].P1.Y, 'line ' + IntToStr(Cont));
    Assert.AreEqual(Segs[Cont].P1.Y, Segs[Cont].P2.Y, 'stays horizontal');
    Assert.AreEqual(0, Segs[Cont].P1.X, 'starts at the left edge');
    Assert.AreEqual(100, Segs[Cont].P2.X, 'ends at the right edge');
  end;
end;

procedure THatchGeometryTests.Vertical_Square_LinesRunTopToBottom;
var
  Segs: TCADHatchSegments;
  Cont: Integer;
begin
  CADHatchSpacing := 8;
  Segs := CADHatchLines(Square(100), cbsVertical);
  Assert.AreEqual(13, Length(Segs), 'the same count, turned through 90');
  for Cont := 0 to High(Segs) do
    Assert.AreEqual(Segs[Cont].P1.X, Segs[Cont].P2.X,
      'line ' + IntToStr(Cont) + ' stays vertical');
end;

procedure THatchGeometryTests.Cross_IsHorizontalPlusVertical;
begin
  CADHatchSpacing := 8;
  Assert.AreEqual(Length(CADHatchLines(Square(100), cbsHorizontal)) +
    Length(CADHatchLines(Square(100), cbsVertical)),
    Length(CADHatchLines(Square(100), cbsCross)),
    'a cross is the two families, not a third thing');
end;

procedure THatchGeometryTests.DiagCross_IsBothDiagonals;
begin
  CADHatchSpacing := 8;
  Assert.AreEqual(Length(CADHatchLines(Square(100), cbsFDiagonal)) +
    Length(CADHatchLines(Square(100), cbsBDiagonal)),
    Length(CADHatchLines(Square(100), cbsDiagCross)),
    'and so is a diagonal cross');
end;

procedure THatchGeometryTests.Diagonal_LinesAreAtFortyFiveDegrees;
var
  Segs: TCADHatchSegments;
  Cont, DX, DY: Integer;
begin
  CADHatchSpacing := 8;
  Segs := CADHatchLines(Square(100), cbsFDiagonal);
  Assert.IsTrue(Length(Segs) > 0, 'there are lines to look at');
  for Cont := 0 to High(Segs) do
  begin
    DX := Segs[Cont].P2.X - Segs[Cont].P1.X;
    DY := Segs[Cont].P2.Y - Segs[Cont].P1.Y;
    { FDiagonal runs downward left to right, like GDI's HS_FDIAGONAL.
      One pixel of rounding either way is the price of integer ends. }
    Assert.IsTrue(Abs(Abs(DX) - Abs(DY)) <= 1,
      'line ' + IntToStr(Cont) + ' is at 45 degrees');
    Assert.IsTrue(DX * DY >= 0, 'and slopes down to the right');
  end;
end;

procedure THatchGeometryTests.Concave_LineAcrossTheNotchBreaksInTwo;
var
  Segs: TCADHatchSegments;
  Cont, OnTen: Integer;
begin
  { A squared-off U: 100 wide, with a notch cut down the middle from
    the top. A scanline through the notch must come out as two
    segments, one each side - which is the whole reason for pairing
    crossings even-odd rather than taking the first and the last. }
  CADHatchSpacing := 10;
  Segs := CADHatchLines([Point(0, 0), Point(40, 0), Point(40, 60),
    Point(60, 60), Point(60, 0), Point(100, 0), Point(100, 100),
    Point(0, 100)], cbsHorizontal);
  OnTen := 0;
  for Cont := 0 to High(Segs) do
    if Segs[Cont].P1.Y = 10 then
      Inc(OnTen);
  Assert.AreEqual(2, OnTen, 'the line at y=10 is broken by the notch');

  OnTen := 0;
  for Cont := 0 to High(Segs) do
    if Segs[Cont].P1.Y = 70 then
      Inc(OnTen);
  Assert.AreEqual(1, OnTen, 'and below the notch it is whole again');
end;

procedure THatchGeometryTests.LinesSitOnAGridAnchoredAtTheOrigin;
var
  Segs: TCADHatchSegments;
  Cont: Integer;
begin
  { Two shapes that touch must have hatching that lines up, so the
    grid is anchored at the origin and not at the shape. This one
    starts at y=13, and its first line still lands on a multiple of
    the spacing. }
  CADHatchSpacing := 10;
  Segs := CADHatchLines([Point(0, 13), Point(100, 13), Point(100, 87),
    Point(0, 87)], cbsHorizontal);
  Assert.IsTrue(Length(Segs) > 0, 'the shape is hatched at all');
  for Cont := 0 to High(Segs) do
    Assert.AreEqual(0, Segs[Cont].P1.Y mod 10,
      'line ' + IntToStr(Cont) + ' is on the grid');
  Assert.AreEqual(20, Segs[0].P1.Y, 'the first line inside the shape');
end;

procedure THatchGeometryTests.EverySegmentStaysInsideTheShape;
var
  Segs: TCADHatchSegments;
  Cont: Integer;
  Style: TCADBrushStyle;
begin
  CADHatchSpacing := 7;
  for Style := cbsHorizontal to cbsDiagCross do
  begin
    Segs := CADHatchLines(Square(100), Style);
    for Cont := 0 to High(Segs) do
    begin
      Assert.IsTrue((Segs[Cont].P1.X >= -1) and (Segs[Cont].P1.X <= 101) and
        (Segs[Cont].P1.Y >= -1) and (Segs[Cont].P1.Y <= 101) and
        (Segs[Cont].P2.X >= -1) and (Segs[Cont].P2.X <= 101) and
        (Segs[Cont].P2.Y >= -1) and (Segs[Cont].P2.Y <= 101),
        'segment ' + IntToStr(Cont) + ' of style ' +
        IntToStr(Ord(Style)) + ' escaped the square');
    end;
  end;
end;

procedure TCADImageTests.UnknownFormat_HasNoSizeButKeepsItsBytes;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, 3);
  Bytes[0] := 1; Bytes[1] := 2; Bytes[2] := 3;
  FImg.SetData(Bytes);
  Assert.IsFalse(FImg.IsEmpty, 'the bytes are kept');
  Assert.AreEqual(0, FImg.Width, 'but nothing claims to know the size');
end;

initialization
  TDUnitX.RegisterTestFixture(TCADGraphicsCoreTests);
  TDUnitX.RegisterTestFixture(TCADVCLGraphicsTests);
  TDUnitX.RegisterTestFixture(TCADImageTests);
  TDUnitX.RegisterTestFixture(TShapesThroughRecordingBackendTests);
  TDUnitX.RegisterTestFixture(THatchGeometryTests);

end.
