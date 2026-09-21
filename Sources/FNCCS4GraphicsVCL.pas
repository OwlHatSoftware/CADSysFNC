{: VCL (GDI) backend for the CADSys drawing layer.

   <See Class=TCADVCLGraphics> wraps a VCL TCanvas. Pen and brush values
   are read from and written to the canvas itself, so code that still
   touches the TCanvas directly and code that goes through
   <See Class=TCADGraphics> always see the same state.

   The drawing calls are the same GDI calls the library made before the
   drawing layer existed, so output is pixel-identical for opaque
   colours.

   GDI has no alpha for pens and brushes. A translucent colour is
   therefore flattened onto <See Property=TCADGraphics@BlendBackground>
   before it reaches the canvas, which looks right against a uniform
   background but does not blend with whatever was drawn underneath. A
   colour with alpha 0 is not drawn at all. The FNC backend blends for
   real.
}
unit FNCCS4GraphicsVCL;

{$I CADSys.inc}

{ : Range checking off - see FNCCADSys4 for the reasoning. This unit
  indexes a 'array [0..0] of TPoint' through PCADPoints, which is the
  same variable-length-array idiom and equally cannot be range checked. }
{$RANGECHECKS OFF}

{$IFNDEF CADSYS_VCL}
{$MESSAGE Fatal 'FNCCS4GraphicsVCL is VCL-only (the GDI backend). Remove it from the FMX or LCL package rather than compiling it there.'}
{$ENDIF}

interface

uses
  WinAPI.Windows, System.Types, System.UITypes, System.Classes,
  System.SysUtils, Vcl.Graphics, Vcl.Imaging.pngimage, FNCCS4Graphics;

type
  TCADVCLGraphics = class;

  TCADVCLPen = class(TCADPen)
  private
    fOwner: TCADVCLGraphics;
    fCanvas: TCanvas;
    fColor: TCADColor;
    fStyle: TCADPenStyle;
    procedure ApplyColor;
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
    constructor Create(const AOwner: TCADVCLGraphics; const ACanvas: TCanvas);
    {: Re-flattens the colour, after the blend background changed. }
    procedure Refresh;
  end;

  TCADVCLBrush = class(TCADBrush)
  private
    fOwner: TCADVCLGraphics;
    fCanvas: TCanvas;
    fColor: TCADColor;
    fStyle: TCADBrushStyle;
    procedure ApplyColor;
  protected
    function GetColor: TCADColor; override;
    procedure SetColor(const Value: TCADColor); override;
    function GetStyle: TCADBrushStyle; override;
    procedure SetStyle(const Value: TCADBrushStyle); override;
  public
    constructor Create(const AOwner: TCADVCLGraphics; const ACanvas: TCanvas);
    procedure Refresh;
  end;

  TCADVCLGraphics = class(TCADGraphics)
  private
    fCanvas: TCanvas;
    fFontHandle: HFONT;
    fFontSpec: TCADFontSpec;
    fFontSelected: Boolean;
    procedure FreeFontHandle;
  protected
    function CreatePen: TCADPen; override;
    function CreateBrush: TCADBrush; override;
    function GetFontColor: TCADColor; override;
    procedure SetFontColor(const Value: TCADColor); override;
    function GetTransparent: Boolean; override;
    procedure SetTransparent(const Value: Boolean); override;
    function GetClipRect: TRect; override;
    procedure SetBlendBackground(const Value: TCADColor); override;
  public
    constructor Create(const ACanvas: TCanvas);
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
    procedure Lock; override;
    procedure Unlock; override;

    property Canvas: TCanvas read fCanvas;
  end;

const
  CADToVCLPenStyle: array[TCADPenStyle] of TPenStyle = (psSolid, psDash,
    psDot, psDashDot, psDashDotDot, psClear, psInsideFrame, psUserStyle,
    psAlternate);
  VCLToCADPenStyle: array[TPenStyle] of TCADPenStyle = (cpsSolid, cpsDash,
    cpsDot, cpsDashDot, cpsDashDotDot, cpsClear, cpsInsideFrame, cpsUserStyle,
    cpsAlternate);
  CADToVCLPenMode: array[TCADPenMode] of TPenMode = (pmBlack, pmWhite, pmNop,
    pmNot, pmCopy, pmNotCopy, pmMergePenNot, pmMaskPenNot, pmMergeNotPen,
    pmMaskNotPen, pmMerge, pmNotMerge, pmMask, pmNotMask, pmXor, pmNotXor);
  VCLToCADPenMode: array[TPenMode] of TCADPenMode = (cpmBlack, cpmWhite,
    cpmNop, cpmNot, cpmCopy, cpmNotCopy, cpmMergePenNot, cpmMaskPenNot,
    cpmMergeNotPen, cpmMaskNotPen, cpmMerge, cpmNotMerge, cpmMask, cpmNotMask,
    cpmXor, cpmNotXor);
  CADToVCLBrushStyle: array[TCADBrushStyle] of TBrushStyle = (bsSolid,
    bsClear, bsHorizontal, bsVertical, bsFDiagonal, bsBDiagonal, bsCross,
    bsDiagCross);
  VCLToCADBrushStyle: array[TBrushStyle] of TCADBrushStyle = (cbsSolid,
    cbsClear, cbsHorizontal, cbsVertical, cbsFDiagonal, cbsBDiagonal,
    cbsCross, cbsDiagCross);

{: Copies a VCL pen (still used by TLayer and the viewports) into a
   drawing-layer pen. }
procedure AssignVCLPen(const Dest: TCADPen; const Source: TPen);
{: Copies a VCL brush into a drawing-layer brush. }
procedure AssignVCLBrush(const Dest: TCADBrush; const Source: TBrush);
{: Returns the TCanvas behind G, or nil when G is not a VCL backend. }
function VCLCanvasOf(const G: TCADGraphics): TCanvas;
{: Builds a drawing-layer image from a VCL bitmap, encoding it as a PNG.
   For callers that have a TBitmap in hand - loading a file, the
   clipboard, a TImage. }
function CADImageFromBitmap(const Bmp: TGraphic): TCADImage;
{: Decodes an image into a VCL bitmap. Returns False and leaves Bmp
   alone when the image is empty or not a format the VCL can read. }
function CADImageToBitmap(const Image: TCADImage;
  const Bmp: TBitmap): Boolean;

implementation

procedure AssignVCLPen(const Dest: TCADPen; const Source: TPen);
begin
  if (Dest = nil) or (Source = nil) then
    Exit;
  Dest.Color := TColorToCADColor(ColorToRGB(Source.Color));
  Dest.Width := Source.Width;
  Dest.Style := VCLToCADPenStyle[Source.Style];
  Dest.Mode := VCLToCADPenMode[Source.Mode];
end;

procedure AssignVCLBrush(const Dest: TCADBrush; const Source: TBrush);
begin
  if (Dest = nil) or (Source = nil) then
    Exit;
  Dest.Color := TColorToCADColor(ColorToRGB(Source.Color));
  Dest.Style := VCLToCADBrushStyle[Source.Style];
end;

function VCLResolveSystemColor(const Color: System.UITypes.TColor)
  : System.UITypes.TColor;
{ Vcl.Graphics.ColorToRGB is 'function(Color: TColor): Longint' - no const,
  and a Longint result - and Delphi wants procedural types to match
  exactly, so it cannot be assigned to TCADColorResolver directly. }
begin
  Result := Vcl.Graphics.ColorToRGB(Color);
end;

function CADImageFromBitmap(const Bmp: TGraphic): TCADImage;
var
  TmpPng: TPngImage;
  TmpBmp: TBitmap;
  TmpStream: TMemoryStream;
begin
  Result := TCADImage.Create;
  if (Bmp = nil) or (Bmp.Width = 0) or (Bmp.Height = 0) then
    Exit;
  TmpPng := TPngImage.Create;
  try
    if Bmp is TBitmap then
      TmpPng.Assign(TBitmap(Bmp))
    else
    begin
      { A TPngImage only assigns from a bitmap, so anything else - an icon,
        a JPEG, a metafile - is rendered into one first. }
      TmpBmp := TBitmap.Create;
      try
        TmpBmp.SetSize(Bmp.Width, Bmp.Height);
        TmpBmp.Canvas.Draw(0, 0, Bmp);
        TmpPng.Assign(TmpBmp);
      finally
        TmpBmp.Free;
      end;
    end;
    TmpStream := TMemoryStream.Create;
    try
      TmpPng.SaveToStream(TmpStream);
      TmpStream.Position := 0;
      Result.LoadFromStream(TmpStream);
    finally
      TmpStream.Free;
    end;
  finally
    TmpPng.Free;
  end;
end;

function CADImageToBitmap(const Image: TCADImage;
  const Bmp: TBitmap): Boolean;
var
  TmpStream: TMemoryStream;
  TmpPng: TPngImage;
begin
  Result := False;
  if (Image = nil) or (Bmp = nil) or Image.IsEmpty then
    Exit;
  TmpStream := TMemoryStream.Create;
  try
    Image.SaveToStream(TmpStream);
    TmpStream.Position := 0;
    if (Length(Image.Data) >= 2) and (Image.Data[0] = Ord('B')) and
      (Image.Data[1] = Ord('M')) then
    begin
      Bmp.LoadFromStream(TmpStream);
      Exit(True);
    end;
    TmpPng := TPngImage.Create;
    try
      TmpPng.LoadFromStream(TmpStream);
      Bmp.Assign(TmpPng);
      Result := True;
    finally
      TmpPng.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

function VCLCanvasOf(const G: TCADGraphics): TCanvas;
begin
  if G is TCADVCLGraphics then
    Result := TCADVCLGraphics(G).Canvas
  else
    Result := nil;
end;

{ TCADVCLPen }

constructor TCADVCLPen.Create(const AOwner: TCADVCLGraphics;
  const ACanvas: TCanvas);
begin
  inherited Create;
  fOwner := AOwner;
  fCanvas := ACanvas;
  fColor := TColorToCADColor(ColorToRGB(fCanvas.Pen.Color));
  fStyle := VCLToCADPenStyle[fCanvas.Pen.Style];
end;

procedure TCADVCLPen.ApplyColor;
begin
  { GDI cannot blend, so the colour is flattened onto the background and
    a fully transparent pen simply stops drawing. }
  if CADColorAlpha(fColor) = 0 then
    fCanvas.Pen.Style := psClear
  else
  begin
    { Same ordering as the brush, for the same reason. }
    fCanvas.Pen.Color := CADColorToTColor(CADBlendColor(fColor,
      fOwner.BlendBackground));
    fCanvas.Pen.Style := CADToVCLPenStyle[fStyle];
  end;
end;

procedure TCADVCLPen.Refresh;
begin
  ApplyColor;
end;

function TCADVCLPen.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADVCLPen.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  ApplyColor;
end;

function TCADVCLPen.GetWidth: Integer;
begin
  Result := fCanvas.Pen.Width;
end;

procedure TCADVCLPen.SetWidth(const Value: Integer);
begin
  fCanvas.Pen.Width := Value;
end;

function TCADVCLPen.GetStyle: TCADPenStyle;
begin
  Result := fStyle;
end;

procedure TCADVCLPen.SetStyle(const Value: TCADPenStyle);
begin
  fStyle := Value;
  { A transparent colour keeps the canvas pen clear whatever style is
    asked for; ApplyColor decides. }
  ApplyColor;
end;

function TCADVCLPen.GetMode: TCADPenMode;
begin
  Result := VCLToCADPenMode[fCanvas.Pen.Mode];
end;

procedure TCADVCLPen.SetMode(const Value: TCADPenMode);
begin
  fCanvas.Pen.Mode := CADToVCLPenMode[Value];
end;

{ TCADVCLBrush }

constructor TCADVCLBrush.Create(const AOwner: TCADVCLGraphics;
  const ACanvas: TCanvas);
begin
  inherited Create;
  fOwner := AOwner;
  fCanvas := ACanvas;
  fColor := TColorToCADColor(ColorToRGB(fCanvas.Brush.Color));
  fStyle := VCLToCADBrushStyle[fCanvas.Brush.Style];
end;

procedure TCADVCLBrush.ApplyColor;
begin
  if CADColorAlpha(fColor) = 0 then
    fCanvas.Brush.Style := bsClear
  else
  begin
    { Colour first: Vcl.Graphics.TBrush forces bsSolid when the colour is
      set, so writing the style afterwards is what makes a hatched or
      clear brush survive. }
    fCanvas.Brush.Color := CADColorToTColor(CADBlendColor(fColor,
      fOwner.BlendBackground));
    fCanvas.Brush.Style := CADToVCLBrushStyle[fStyle];
  end;
end;

procedure TCADVCLBrush.Refresh;
begin
  ApplyColor;
end;

function TCADVCLBrush.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADVCLBrush.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  ApplyColor;
end;

function TCADVCLBrush.GetStyle: TCADBrushStyle;
begin
  Result := fStyle;
end;

procedure TCADVCLBrush.SetStyle(const Value: TCADBrushStyle);
begin
  fStyle := Value;
  ApplyColor;
end;

{ TCADVCLGraphics }

constructor TCADVCLGraphics.Create(const ACanvas: TCanvas);
begin
  { fCanvas must be set before inherited Create calls CreatePen. }
  fCanvas := ACanvas;
  fFontHandle := 0;
  fFontSelected := False;
  inherited Create;
end;

destructor TCADVCLGraphics.Destroy;
begin
  ResetFont;
  FreeFontHandle;
  inherited Destroy;
end;

function TCADVCLGraphics.CreatePen: TCADPen;
begin
  Result := TCADVCLPen.Create(Self, fCanvas);
end;

function TCADVCLGraphics.CreateBrush: TCADBrush;
begin
  Result := TCADVCLBrush.Create(Self, fCanvas);
end;

procedure TCADVCLGraphics.SetBlendBackground(const Value: TCADColor);
begin
  inherited SetBlendBackground(Value);
  { Whatever is already set has to be flattened against the new
    background. }
  if Pen <> nil then
    TCADVCLPen(Pen).Refresh;
  if Brush <> nil then
    TCADVCLBrush(Brush).Refresh;
end;

function TCADVCLGraphics.GetFontColor: TCADColor;
begin
  Result := TColorToCADColor(ColorToRGB(fCanvas.Font.Color));
end;

procedure TCADVCLGraphics.SetFontColor(const Value: TCADColor);
begin
  fCanvas.Font.Color := CADColorToTColor(CADBlendColor(Value,
    BlendBackground));
end;

function TCADVCLGraphics.GetTransparent: Boolean;
begin
  Result := WinAPI.Windows.GetBkMode(fCanvas.Handle) = WinAPI.Windows.TRANSPARENT;
end;

procedure TCADVCLGraphics.SetTransparent(const Value: Boolean);
begin
  if Value then
    WinAPI.Windows.SetBkMode(fCanvas.Handle, WinAPI.Windows.TRANSPARENT)
  else
    WinAPI.Windows.SetBkMode(fCanvas.Handle, WinAPI.Windows.OPAQUE);
end;

function TCADVCLGraphics.GetClipRect: TRect;
begin
  Result := fCanvas.ClipRect;
end;

procedure TCADVCLGraphics.MoveTo(const X, Y: Integer);
begin
  fCanvas.MoveTo(X, Y);
end;

procedure TCADVCLGraphics.LineTo(const X, Y: Integer);
begin
  fCanvas.LineTo(X, Y);
end;

procedure TCADVCLGraphics.Polyline(const Pts: Pointer; const Count: Integer);
begin
  if (Pts = nil) or (Count <= 1) then
    Exit;
  WinAPI.Windows.Polyline(fCanvas.Handle, PCADPoints(Pts)^, Count);
end;

procedure TCADVCLGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
begin
  if (Pts = nil) or (Count <= 0) then
    Exit;
  WinAPI.Windows.Polygon(fCanvas.Handle, PCADPoints(Pts)^, Count);
end;

procedure TCADVCLGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
begin
  WinAPI.Windows.Rectangle(fCanvas.Handle, X1, Y1, X2, Y2);
end;

procedure TCADVCLGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
begin
  WinAPI.Windows.Ellipse(fCanvas.Handle, X1, Y1, X2, Y2);
end;

procedure TCADVCLGraphics.DoFillRect(const R: TRect);
begin
  fCanvas.FillRect(R);
end;

procedure TCADVCLGraphics.FreeFontHandle;
begin
  if fFontHandle <> 0 then
  begin
    WinAPI.Windows.DeleteObject(fFontHandle);
    fFontHandle := 0;
  end;
end;

procedure TCADVCLGraphics.SelectFont(const Font: TCADFontSpec);
var
  LF: TLogFont;
  Len: Integer;
begin
  { Rebuild the HFONT only when the description changed: text shapes
    select their font on every draw, and CreateFontIndirect per frame was
    finding P4 of the optimization review. }
  if (fFontHandle = 0) or not TCADFontSpec.Same(Font, fFontSpec) then
  begin
    if fFontSelected then
      ResetFont;
    FreeFontHandle;
    FillChar(LF, SizeOf(LF), 0);
    LF.lfHeight := Font.Height;
    LF.lfWidth := Font.Width;
    LF.lfEscapement := Font.Escapement;
    LF.lfOrientation := Font.Orientation;
    LF.lfWeight := Font.Weight;
    LF.lfItalic := Byte(Font.Italic);
    LF.lfUnderline := Byte(Font.Underline);
    LF.lfStrikeOut := Byte(Font.StrikeOut);
    LF.lfCharSet := Font.CharSet;
    LF.lfOutPrecision := Font.OutPrecision;
    LF.lfClipPrecision := Font.ClipPrecision;
    LF.lfQuality := Font.Quality;
    LF.lfPitchAndFamily := Font.PitchAndFamily;
    Len := Length(Font.FaceName);
    if Len > LF_FACESIZE - 1 then
      Len := LF_FACESIZE - 1;
    if Len > 0 then
      Move(PChar(Font.FaceName)^, LF.lfFaceName[0], Len * SizeOf(Char));
    fFontHandle := WinAPI.Windows.CreateFontIndirect(LF);
    fFontSpec := Font;
  end;
  WinAPI.Windows.SelectObject(fCanvas.Handle, fFontHandle);
  fFontSelected := True;
end;

procedure TCADVCLGraphics.ResetFont;
begin
  if not fFontSelected then
    Exit;
  { Hand the DC back the canvas' own font, as TExtendedFont always did. }
  WinAPI.Windows.SelectObject(fCanvas.Handle, fCanvas.Font.Handle);
  fFontSelected := False;
end;

function TCADVCLGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
begin
  Result := WinAPI.Windows.DrawText(fCanvas.Handle, PChar(Text),
    Length(Text), R, Flags);
end;

procedure TCADVCLGraphics.DrawImage(const Dest: TRect;
  const Image: TCADImage; const CopyMode: LongInt);
var
  OldMode: TCopyMode;
  TmpBmp: TBitmap;
begin
  if (Image = nil) or Image.IsEmpty then
    Exit;
  { Decoding a PNG per repaint would be absurd, so the decoded bitmap
    lives in the image's cache slot until the bytes change. }
  TmpBmp := TBitmap(Image.CacheFor(Self));
  if TmpBmp = nil then
  begin
    TmpBmp := TBitmap.Create;
    if not CADImageToBitmap(Image, TmpBmp) then
    begin
      TmpBmp.Free;
      Exit;
    end;
    Image.SetCache(Self, TmpBmp);
  end;
  OldMode := fCanvas.CopyMode;
  try
    fCanvas.CopyMode := CopyMode;
    fCanvas.StretchDraw(Dest, TmpBmp);
  finally
    fCanvas.CopyMode := OldMode;
  end;
end;

procedure TCADVCLGraphics.Lock;
begin
  fCanvas.Lock;
end;

procedure TCADVCLGraphics.Unlock;
begin
  fCanvas.Unlock;
end;

initialization

{ Linking this unit in is what teaches the drawing layer about VCL system
  colours. Nothing else here has to be used for it to take effect.

  Through a wrapper rather than assigning Vcl.Graphics.ColorToRGB itself:
  that one is declared 'function(Color: TColor): Longint', and Delphi
  wants the procedural types to match exactly. }
CADResolveSystemColor := VCLResolveSystemColor;

end.
