{: TMS FNC backend for the CADSys drawing layer.

   <See Class=TCADFNCGraphics> draws through a TTMSFNCGraphics, so the
   same shape code renders on VCL, FMX and LCL.

   Framework selection is CADSys.inc's job; this unit only reads
   CADSYS_VCL, CADSYS_FMX and CADSYS_LCL. Where the differences fall is
   worth knowing: FMX is nearly always the odd one out, because it is
   the only flavour whose FNC colour is a TAlphaColor and whose graphics
   font is not a descendant of the framework TFont. So a test here
   usually reads <I=IFNDEF CADSYS_FMX> - meaning VCL and LCL together -
   rather than naming the two.

   Known differences from the GDI backend (see docs/port/port-log.md):
   <LI=There are no raster operations. A pen whose Mode is not cpmCopy
   (the library uses cpmXor for rubber-banding) draws in
   <See Property=TCADFNCGraphics@XorColor>. The viewport has to redraw
   the overlay rather than rely on XOR erasing it.>
   <LI=Hatched brushes are drawn solid.>
   <LI=Font heights are converted from LOGFONT pixels to FNC sizes, and
   raster faces such as 'Small Fonts' are replaced by
   <See Property=TCADFNCGraphics@FallbackFontName>.>
   <LI=Opaque text fills the whole text rectangle, not only the glyph
   cells.>
   <LI=The clip rectangle is only narrowed, never widened, because FNC
   has no public way to read or reset it outside Save/RestoreState.>
}
unit VCL.FNCCS4GraphicsFNC;

{$I VCL.FNCCADSys.inc}

{$RANGECHECKS OFF} // PCADPoints is a [0..0] array indexed past its bound

interface

uses
{$IFDEF CADSYS_LCL}
  Types, UITypes, Classes, SysUtils, Math,
{$ELSE}
  System.Types, System.UITypes, System.Classes, System.SysUtils, System.Math,
{$ENDIF}
  VCL.FNCCS4Graphics,
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics;
{$ENDIF}
{$IFDEF CADSYS_LCL}
  Graphics,
  LCLTMSFNCTypes, LCLTMSFNCGraphicsTypes, LCLTMSFNCGraphics;
{$ENDIF}
{$IFDEF CADSYS_VCL}
  Vcl.Graphics, Vcl.Imaging.pngimage,
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics;
{$ENDIF}

type
  TCADFNCGraphics = class;

  TCADFNCPen = class(TCADPen)
  private
    fOwner: TCADFNCGraphics;
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
  public
    constructor Create(const AOwner: TCADFNCGraphics);
  end;

  TCADFNCBrush = class(TCADBrush)
  private
    fOwner: TCADFNCGraphics;
    fColor: TCADColor;
    fStyle: TCADBrushStyle;
  protected
    function GetColor: TCADColor; override;
    procedure SetColor(const Value: TCADColor); override;
    function GetStyle: TCADBrushStyle; override;
    procedure SetStyle(const Value: TCADBrushStyle); override;
  public
    constructor Create(const AOwner: TCADFNCGraphics);
  end;

  TCADFNCGraphics = class(TCADGraphics)
  private
    fGraphics: TTMSFNCGraphics;
    fOwnsGraphics: Boolean;
    { Non-nil while a clip of ours is in force. FNC's RestoreState frees
      the state object, so this is a one-shot handle, not a cache. }
    fClipState: TTMSFNCGraphicsSaveState;
    fClip: TRect;
    fCurPt: TPoint;
    fFontColor: TCADColor;
    fTransparent: Boolean;
    fFont: TCADFontSpec;
    fFontSelected: Boolean;
    fPoly: TTMSFNCGraphicsPathPolygon;
    fXorColor: TCADColor;
    fFallbackFontName: string;
    fReady: Boolean;
    procedure ApplyPen;
    procedure ApplyBrush;
    procedure ApplyFont;
    function DecodeImage(const Image: TCADImage): TTMSFNCBitmapHelperClass;
    function PixelOffset: Single;
    procedure LoadPoly(const Pts: Pointer; const Count: Integer);
    procedure SetXorColor(const Value: TCADColor);
  protected
    function CreatePen: TCADPen; override;
    function CreateBrush: TCADBrush; override;
    function GetFontColor: TCADColor; override;
    procedure SetFontColor(const Value: TCADColor); override;
    function GetTransparent: Boolean; override;
    procedure SetTransparent(const Value: Boolean); override;
    function GetClipRect: TRect; override;
  public
    {: Wraps AGraphics. ABounds is the drawable area in pixels; it is the
       initial clip rectangle and is what shapes use to clip geometry. }
    constructor Create(const AGraphics: TTMSFNCGraphics; const ABounds: TRect;
      const AOwnsGraphics: Boolean = False);
    destructor Destroy; override;

    {: Points this wrapper at a different FNC graphics - the one a
       control's Draw method hands over - or at nothing, by passing nil,
       between paints.

       An FNC control may only draw inside Draw, but the library draws its
       transient overlay whenever the mouse moves. While no graphics is
       attached every drawing call here is a no-op, so that code can keep
       calling and the paint that follows produces the picture. }
    procedure Attach(const AGraphics: TTMSFNCGraphics; const ABounds: TRect);
    { : Applies the clip rectangle that Attach recorded.

      Separate from Attach on purpose. A clip is a canvas operation -
      FMX turns it into TCanvas.IntersectClipRect - and FMX raises
      ECanvas for any canvas operation outside BeginScene/EndScene.
      Attach happens in places where there is legitimately no scene
      yet: building the back buffer's drawing stack when the viewport
      is constructed, for one. So Attach only remembers the rectangle,
      and whoever is inside a scene applies it.

      A clip must be given back. On FMX a clip set with
      IntersectClipRect narrows the canvas for the rest of the scene,
      and the canvas belongs to the framework, not to us - leaving one
      behind means everything painted after this control is clipped
      away, which looks like siblings mysteriously vanishing rather
      than like a clipping bug. So this saves the canvas state and
      ReleaseClip puts it back.

      Calling it twice does nothing the second time; calling it with
      nothing attached does nothing at all. }
    procedure ApplyClip;
    { : Gives back the clip ApplyClip set, restoring the canvas state.
      Attach calls it for you when the graphics is swapped or
      detached. }
    procedure ReleaseClip;
    {: False while no FNC graphics is attached, when nothing is drawn. }
    function IsReady: Boolean;
    {: Narrows the clip rectangle to R. }
    procedure SetClipRect(const R: TRect);

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

    property FNCGraphics: TTMSFNCGraphics read fGraphics;
    {: Colour used for pens whose Mode is not cpmCopy. Default gray. }
    property XorColor: TCADColor read fXorColor write SetXorColor;
    {: Face used when the requested face is empty or a Windows raster
       font. Default 'Tahoma'. }
    property FallbackFontName: string read fFallbackFontName
      write fFallbackFontName;
  end;

{: Converts a drawing-layer colour to the colour type of the FNC flavour
   in use (TColor on VCL, TAlphaColor on FMX). The alpha channel does not
   travel with it on VCL; pass it separately as an opacity. }
function CADToFNCColor(const Color: TCADColor): TTMSFNCGraphicsColor;
{: The inverse, for the few places that read a colour off an FNC control
   rather than writing one: a control's Color property is a
   TTMSFNCGraphicsColor, and only this unit knows which of TColor and
   TAlphaColor that is today. }
function FNCToCADColor(const Color: TTMSFNCGraphicsColor): TCADColor;
{: The alpha channel of Color as an FNC opacity, 0..1. }
function CADToFNCOpacity(const Color: TCADColor): Single;
{: Converts a LOGFONT-style pixel height to an FNC font size. }
function CADFontHeightToFNCSize(const Height: Integer): Single;

implementation

function CADToFNCColor(const Color: TCADColor): TTMSFNCGraphicsColor;
begin
{$IFDEF CADSYS_FMX}
  { TAlphaColor is $AARRGGBB, the same layout. }
  Result := TTMSFNCGraphicsColor(CADColorToARGB(Color));
{$ELSE}
  { The VCL and LCL flavours use TColor, which has no alpha -
    Stroke.Opacity and Fill.Opacity carry it instead. }
  Result := CADColorToTColor(Color);
{$ENDIF}
end;

function FNCToCADColor(const Color: TTMSFNCGraphicsColor): TCADColor;
begin
{$IFDEF CADSYS_FMX}
  { TAlphaColor is $AARRGGBB, the same layout, alpha included. }
  Result := TCADColor(Color);
{$ELSE}
  { A TColor: opaque by definition, and with red and blue the other way
    round. TColorToCADColor handles both, and a system colour too if one
    ever reaches here. }
  Result := TColorToCADColor(Color);
{$ENDIF}
end;

function CADToFNCOpacity(const Color: TCADColor): Single;
begin
  Result := CADColorAlpha(Color) / 255;
end;

function CADFontHeightToFNCSize(const Height: Integer): Single;
begin
  { A negative LOGFONT height is the character height, a positive one the
    cell height, which includes roughly 20% internal leading. }
  if Height < 0 then
    Result := -Height
  else
    Result := Height / 1.2;
{$IFNDEF CADSYS_FMX}
  { VCL and LCL FNC fonts are sized in points at 96 DPI. }
  Result := Result * 72 / 96;
{$ENDIF}
  if Result < 1 then
    Result := 1;
end;

const
  PenStyleToFNC: array[TCADPenStyle] of TTMSFNCGraphicsStrokeKind = (
    gskSolid, gskDash, gskDot, gskDashDot, gskDashDotDot, gskNone,
    gskSolid, gskSolid, gskDot);

{ TCADFNCPen }

constructor TCADFNCPen.Create(const AOwner: TCADFNCGraphics);
begin
  inherited Create;
  fOwner := AOwner;
  fColor := cadclBlack;
  fWidth := 1;
  fStyle := cpsSolid;
  fMode := cpmCopy;
end;

function TCADFNCPen.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADFNCPen.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  fOwner.ApplyPen;
end;

function TCADFNCPen.GetWidth: Integer;
begin
  Result := fWidth;
end;

procedure TCADFNCPen.SetWidth(const Value: Integer);
begin
  fWidth := Value;
  fOwner.ApplyPen;
end;

function TCADFNCPen.GetStyle: TCADPenStyle;
begin
  Result := fStyle;
end;

procedure TCADFNCPen.SetStyle(const Value: TCADPenStyle);
begin
  fStyle := Value;
  fOwner.ApplyPen;
end;

function TCADFNCPen.GetMode: TCADPenMode;
begin
  Result := fMode;
end;

procedure TCADFNCPen.SetMode(const Value: TCADPenMode);
begin
  fMode := Value;
  fOwner.ApplyPen;
end;

{ TCADFNCBrush }

constructor TCADFNCBrush.Create(const AOwner: TCADFNCGraphics);
begin
  inherited Create;
  fOwner := AOwner;
  fColor := cadclWhite;
  fStyle := cbsSolid;
end;

function TCADFNCBrush.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADFNCBrush.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  fOwner.ApplyBrush;
end;

function TCADFNCBrush.GetStyle: TCADBrushStyle;
begin
  Result := fStyle;
end;

procedure TCADFNCBrush.SetStyle(const Value: TCADBrushStyle);
begin
  fStyle := Value;
  fOwner.ApplyBrush;
end;

{ TCADFNCGraphics }

constructor TCADFNCGraphics.Create(const AGraphics: TTMSFNCGraphics;
  const ABounds: TRect; const AOwnsGraphics: Boolean);
begin
  { Fields used by ApplyPen/ApplyBrush must exist before inherited Create
    builds the pen and brush. fReady keeps the Apply* calls quiet until
    both exist. }
  fGraphics := AGraphics;
  fOwnsGraphics := AOwnsGraphics;
  fXorColor := cadclGray;
  fFontColor := cadclBlack;
  fTransparent := True;
  fFallbackFontName := 'Tahoma';
  fFont := TCADFontSpec.Default;
  fReady := False;
  inherited Create;
  { AGraphics may be nil: a control that paints only inside its Draw has
    nothing to attach between paints. Attach sets fReady and, with a
    surface, applies the clip, the pen and the brush. }
  fGraphics := nil;
  Attach(AGraphics, ABounds);
  fOwnsGraphics := AOwnsGraphics;
end;

destructor TCADFNCGraphics.Destroy;
begin
  ReleaseClip;
  if fOwnsGraphics then
    fGraphics.Free;
  inherited Destroy;
end;

function TCADFNCGraphics.CreatePen: TCADPen;
begin
  Result := TCADFNCPen.Create(Self);
end;

function TCADFNCGraphics.CreateBrush: TCADBrush;
begin
  Result := TCADFNCBrush.Create(Self);
end;

procedure TCADFNCGraphics.ApplyPen;
var
  P: TCADFNCPen;
  Col: TCADColor;
begin
  if not fReady then
    Exit;
  P := TCADFNCPen(Pen);
  if (P.fMode = cpmNop) or (P.fStyle = cpsClear) or
    (CADColorAlpha(P.fColor) = 0) then
  begin
    fGraphics.Stroke.Kind := gskNone;
    Exit;
  end;
  fGraphics.Stroke.Kind := PenStyleToFNC[P.fStyle];
  if P.fMode = cpmCopy then
    Col := P.fColor
  else
    Col := fXorColor;
  fGraphics.Stroke.Color := CADToFNCColor(Col);
  fGraphics.Stroke.Opacity := CADToFNCOpacity(Col);
  fGraphics.Stroke.Width := Max(1, P.fWidth);
end;

procedure TCADFNCGraphics.ApplyBrush;
var
  B: TCADFNCBrush;
begin
  if not fReady then
    Exit;
  B := TCADFNCBrush(Brush);
  if (B.fStyle = cbsClear) or (CADColorAlpha(B.fColor) = 0) then
    fGraphics.Fill.Kind := gfkNone
  else
  begin
    fGraphics.Fill.Kind := gfkSolid;
    fGraphics.Fill.Color := CADToFNCColor(B.fColor);
    fGraphics.Fill.Opacity := CADToFNCOpacity(B.fColor);
  end;
end;

procedure TCADFNCGraphics.ApplyFont;
var
  Styles: TFontStyles;
begin
  if not fReady then
    Exit;
  if (fFont.FaceName = '') or SameText(fFont.FaceName, 'Small Fonts') or
    SameText(fFont.FaceName, 'Small Font') then
    fGraphics.Font.Name := fFallbackFontName
  else
    fGraphics.Font.Name := fFont.FaceName;
{$IFDEF CADSYS_FMX}
  fGraphics.Font.Size := CADFontHeightToFNCSize(fFont.Height);
{$ELSE}
  { The VCL and LCL flavours of TTMSFNCGraphicsFont descend from TFont,
    whose Height is in pixels with the LOGFONT sign convention - the same
    value the font spec carries, so no conversion is needed or wanted. }
  fGraphics.Font.Height := fFont.Height;
{$ENDIF}
  Styles := [];
  if fFont.Weight >= 600 then
    Include(Styles, TFontStyle.fsBold);
  if fFont.Italic then
    Include(Styles, TFontStyle.fsItalic);
  if fFont.Underline then
    Include(Styles, TFontStyle.fsUnderline);
  if fFont.StrikeOut then
    Include(Styles, TFontStyle.fsStrikeOut);
  fGraphics.Font.Style := Styles;
  fGraphics.Font.Color := CADToFNCColor(fFontColor);
end;

procedure TCADFNCGraphics.SetXorColor(const Value: TCADColor);
begin
  fXorColor := Value;
  ApplyPen;
end;

function TCADFNCGraphics.GetFontColor: TCADColor;
begin
  Result := fFontColor;
end;

procedure TCADFNCGraphics.SetFontColor(const Value: TCADColor);
begin
  fFontColor := Value;
  if fReady then
    fGraphics.Font.Color := CADToFNCColor(Value);
end;

function TCADFNCGraphics.GetTransparent: Boolean;
begin
  Result := fTransparent;
end;

procedure TCADFNCGraphics.SetTransparent(const Value: Boolean);
begin
  fTransparent := Value;
end;

function TCADFNCGraphics.GetClipRect: TRect;
begin
  Result := fClip;
end;

procedure TCADFNCGraphics.Attach(const AGraphics: TTMSFNCGraphics;
  const ABounds: TRect);
begin
  { Any clip we are still holding belongs to the graphics we are about
    to let go of, so it has to go back first. }
  ReleaseClip;
  if fOwnsGraphics and (fGraphics <> nil) and (fGraphics <> AGraphics) then
    FreeAndNil(fGraphics);
  fGraphics := AGraphics;
  fOwnsGraphics := False;
  fClip := ABounds;
  fCurPt := Point(0, 0);
  fFontSelected := False;
  fReady := fGraphics <> nil;
  if fReady then
  begin
    { The clip is not applied here - see ApplyClip. Pen and brush are
      safe: they only assign to the graphics' own Stroke and Fill
      objects and never reach the canvas. }
    ApplyPen;
    ApplyBrush;
  end;
end;

procedure TCADFNCGraphics.ApplyClip;
begin
  if not fReady then
    Exit;
  if fClipState <> nil then
    Exit;
  { Canvas state only: the full SaveState also copies Fill, Stroke and
    Font, and restoring those would throw away the pen and brush the
    caller has just set. }
  fClipState := fGraphics.SaveState(True);
  fGraphics.ClipRect(RectF(fClip.Left, fClip.Top, fClip.Right, fClip.Bottom));
end;

procedure TCADFNCGraphics.ReleaseClip;
begin
  if fClipState = nil then
    Exit;
  if fGraphics <> nil then
    { RestoreState frees the state object itself. }
    fGraphics.RestoreState(fClipState, True)
  else
    fClipState.Free;
  fClipState := nil;
end;

function TCADFNCGraphics.IsReady: Boolean;
begin
  Result := fReady;
end;

procedure TCADFNCGraphics.SetClipRect(const R: TRect);
begin
  if not fReady then
    Exit;
  fClip := R;
  fGraphics.ClipRect(RectF(R.Left, R.Top, R.Right, R.Bottom));
end;

function TCADFNCGraphics.PixelOffset: Single;
begin
  { GDI draws a 1-pixel pen through pixel centres; anti-aliased engines
    need the half-pixel shift to stay crisp. Even widths are already
    centred on the pixel boundary. }
  if Odd(Max(1, Pen.Width)) then
    Result := 0.5
  else
    Result := 0;
end;

procedure TCADFNCGraphics.LoadPoly(const Pts: Pointer; const Count: Integer);
var
  I: Integer;
  O: Single;
  Src: PCADPoints;
begin
  if not fReady then
    Exit;
  O := PixelOffset;
  Src := PCADPoints(Pts);
  if Length(fPoly) <> Count then
    SetLength(fPoly, Count);
  for I := 0 to Count - 1 do
    fPoly[I] := PointF(Src^[I].X + O, Src^[I].Y + O);
end;

procedure TCADFNCGraphics.MoveTo(const X, Y: Integer);
begin
  { State only - the pen position has to survive between paints. }
  fCurPt := Point(X, Y);
end;

procedure TCADFNCGraphics.LineTo(const X, Y: Integer);
var
  O: Single;
begin
  if not fReady then
    Exit;
  O := PixelOffset;
  fGraphics.DrawLine(PointF(fCurPt.X + O, fCurPt.Y + O),
    PointF(X + O, Y + O), gcpmNone, gcpmNone);
  fCurPt := Point(X, Y);
end;

procedure TCADFNCGraphics.Polyline(const Pts: Pointer; const Count: Integer);
var
  OldKind: TTMSFNCGraphicsFillKind;
begin
  if not fReady then
    Exit;
  if (Pts = nil) or (Count <= 1) then
    Exit;
  LoadPoly(Pts, Count);
  { TTMSFNCGraphics.DrawPolyline also fills when a fill is set; a GDI
    polyline never does. }
  OldKind := fGraphics.Fill.Kind;
  fGraphics.Fill.Kind := gfkNone;
  try
    fGraphics.DrawPolyline(fPoly);
  finally
    fGraphics.Fill.Kind := OldKind;
  end;
  fCurPt := PCADPoints(Pts)^[Count - 1];
end;

procedure TCADFNCGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
begin
  if not fReady then
    Exit;
  if (Pts = nil) or (Count <= 0) then
    Exit;
  LoadPoly(Pts, Count);
  fGraphics.DrawPolygon(fPoly);
end;

procedure TCADFNCGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
var
  O: Single;
begin
  if not fReady then
    Exit;
  { GDI excludes the right and bottom edge. }
  O := PixelOffset;
  fGraphics.DrawRectangle(RectF(X1 + O, Y1 + O, X2 - 1 + O, Y2 - 1 + O),
    gcrmNone);
end;

procedure TCADFNCGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
var
  O: Single;
begin
  if not fReady then
    Exit;
  O := PixelOffset;
  fGraphics.DrawEllipse(RectF(X1 + O, Y1 + O, X2 - 1 + O, Y2 - 1 + O),
    gcrmNone);
end;

procedure TCADFNCGraphics.DoFillRect(const R: TRect);
begin
  if not fReady then
    Exit;
  fGraphics.Stroke.Kind := gskNone;
  try
    fGraphics.DrawRectangle(RectF(R.Left, R.Top, R.Right, R.Bottom), gcrmNone);
  finally
    ApplyPen;
  end;
end;

procedure TCADFNCGraphics.SelectFont(const Font: TCADFontSpec);
begin
  { The description is remembered even with nothing attached; ApplyFont is
    what needs a surface, and it guards itself. }
  fFont := Font;
  fFontSelected := True;
  ApplyFont;
end;

procedure TCADFNCGraphics.ResetFont;
begin
  fFontSelected := False;
end;

function TCADFNCGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
const
  BIG = 100000;
var
  HAlign, VAlign: TTMSFNCGraphicsTextAlign;
  WordWrap: Boolean;
  Angle: Single;
  RF: TRectF;
begin
  Result := 0;
  if not fReady then
    Exit;
  WordWrap := ((Flags and CAD_DT_WORDBREAK) <> 0) and
    ((Flags and CAD_DT_SINGLELINE) = 0);

  if (Flags and CAD_DT_CALCRECT) <> 0 then
  begin
    if WordWrap then
      RF := RectF(R.Left, R.Top, R.Right, R.Top + BIG)
    else
      RF := RectF(R.Left, R.Top, R.Left + BIG, R.Top + BIG);
    RF := fGraphics.CalculateText(Text, RF, WordWrap, False);
    R.Right := R.Left + Ceil(RF.Width);
    R.Bottom := R.Top + Ceil(RF.Height);
    Result := R.Bottom - R.Top;
    Exit;
  end;

  if (Flags and CAD_DT_CENTER) <> 0 then
    HAlign := gtaCenter
  else if (Flags and CAD_DT_RIGHT) <> 0 then
    HAlign := gtaTrailing
  else
    HAlign := gtaLeading;
  if (Flags and CAD_DT_VCENTER) <> 0 then
    VAlign := gtaCenter
  else if (Flags and CAD_DT_BOTTOM) <> 0 then
    VAlign := gtaTrailing
  else
    VAlign := gtaLeading;

  { LOGFONT escapement is counter-clockwise in tenths of a degree; FNC
    rotates clockwise in degrees. }
  if fFontSelected then
    Angle := -fFont.Escapement / 10
  else
    Angle := 0;

  if not fTransparent then
    FillRect(R);

  fGraphics.Font.Color := CADToFNCColor(fFontColor);
  fGraphics.DrawText(RectF(R.Left, R.Top, R.Right, R.Bottom), Text, WordWrap,
    HAlign, VAlign, gttNone, Angle, -1, -1, False);
  Result := R.Bottom - R.Top;
end;

function TCADFNCGraphics.DecodeImage(const Image: TCADImage):
  TTMSFNCBitmapHelperClass;
var
  TmpStream: TMemoryStream;
{$IFDEF CADSYS_VCL}
  TmpPng: TPngImage;
{$ENDIF}
{$IFDEF CADSYS_LCL}
  TmpIsBmp: Boolean;
{$ENDIF}
begin
  Result := nil;
  TmpStream := TMemoryStream.Create;
  try
    Image.SaveToStream(TmpStream);
    TmpStream.Position := 0;
{$IFDEF CADSYS_FMX}
    { FMX TBitmap reads PNG and BMP itself. }
    Result := TTMSFNCBitmapHelperClass.Create;
    try
      Result.LoadFromStream(TmpStream);
    except
      FreeAndNil(Result);
    end;
{$ENDIF}
{$IFDEF CADSYS_VCL}
    { VCL FNC draws a TPicture, which will not guess the format from a
      stream, so the PNG is decoded explicitly. }
    Result := TPicture.Create;
    try
      if (Length(Image.Data) >= 2) and (Image.Data[0] = Ord('B')) and
        (Image.Data[1] = Ord('M')) then
        Result.Bitmap.LoadFromStream(TmpStream)
      else
      begin
        TmpPng := TPngImage.Create;
        try
          TmpPng.LoadFromStream(TmpStream);
          Result.Assign(TmpPng);
        finally
          TmpPng.Free;
        end;
      end;
    except
      FreeAndNil(Result);
    end;
{$ENDIF}
{$IFDEF CADSYS_LCL}
    { LCL FNC draws a TPicture too, and it has the same problem: a bare
      LoadFromStream cannot tell PNG from BMP. LCL does offer a variant
      that takes the extension, which is all the hint it needs, and the
      graphic class for it is registered by the Graphics unit. }
    TmpIsBmp := (Length(Image.Data) >= 2) and (Image.Data[0] = Ord('B')) and
      (Image.Data[1] = Ord('M'));
    Result := TPicture.Create;
    try
      if TmpIsBmp then
        Result.LoadFromStreamWithFileExt(TmpStream, 'bmp')
      else
        Result.LoadFromStreamWithFileExt(TmpStream, 'png');
    except
      FreeAndNil(Result);
    end;
{$ENDIF}
  finally
    TmpStream.Free;
  end;
end;

procedure TCADFNCGraphics.DrawImage(const Dest: TRect; const Image: TCADImage;
  const {%H-}CopyMode: LongInt);
var
  DR: TRectF;
  TmpBmp: TTMSFNCBitmapHelperClass;
begin
  if not fReady then
    Exit;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  { FNC has no raster operations, so CopyMode is ignored. The decoded
    picture lives in the image's cache slot until the bytes change. }
  TmpBmp := TTMSFNCBitmapHelperClass(Image.CacheFor(Self));
  if TmpBmp = nil then
  begin
    TmpBmp := DecodeImage(Image);
    if TmpBmp = nil then
      Exit;
    Image.SetCache(Self, TmpBmp);
  end;
  DR := RectF(Dest.Left, Dest.Top, Dest.Right, Dest.Bottom);
  fGraphics.DrawBitmap(DR, TmpBmp, False, True, False, False);
end;

{$IFDEF CADSYS_LCL}
function LCLResolveSystemColor(const Color: System.UITypes.TColor)
  : System.UITypes.TColor;
begin
  Result := Graphics.ColorToRGB(Color);
end;

initialization

{ The same hook VCL.FNCCS4GraphicsVCL installs, for the target that has no
  VCL backend to install it. Without a resolver every clBtnFace and
  clWindow in a drawing converts to opaque black, because the drawing
  layer has no way to read a theme index.

  Only LCL: on the VCL this unit is linked alongside VCL.FNCCS4GraphicsVCL
  and must not race it for the hook, and FMX has no TColor system
  colours to resolve in the first place - its palette is TAlphaColor,
  and the clXxx values that do reach here come from System.UITypes and
  are plain positive RGB. }
CADResolveSystemColor := LCLResolveSystemColor;
{$ENDIF}

end.
