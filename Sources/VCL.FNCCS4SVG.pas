{ : SVG files of a sheet - CS-05 of docs\masterplanner-changes.md.

  <See Class=TCADSVGGraphics> is a drawing backend like the GDI and FNC
  ones, except that what it draws on is a string: every call becomes an
  SVG element. The sheet is drawn by <See Procedure=CADDrawSheet>, the
  routine the preview, the printer, the PDF and the PNG use, so an SVG
  shows what they show.

  COORDINATES

  The drawing layer works in integer device pixels. As for the PDF, the
  sheet is laid out at <See Variable=CADSVGResolution> dots per inch
  (600 unless changed), so an endpoint is rounded to a twenty-fourth of
  a millimetre rather than to a screen pixel. Those dots are the SVG's
  user units: the viewBox is the sheet in dots, and width and height
  say the same size in millimetres, so the file opens at the size of
  the paper.

  WHAT BECOMES WHAT

  <LI=MoveTo/LineTo - one polyline per unbroken run of LineTos, rather
  than an element per segment. A pen change ends the run.>
  <LI=Polyline, Polygon, Rectangle, Ellipse, FillRect - polyline,
  polygon, rect, ellipse, each with its fill and stroke. Hatches never
  arrive: the base class draws them as lines.>
  <LI=The pen - stroke, stroke-width, stroke-opacity and, for the dashed
  styles, a stroke-dasharray in the proportions GDI uses, scaled so a
  dash on paper is as long as one on the screen.>
  <LI=The brush - fill and fill-opacity; a gradient a linearGradient in
  defs, one per distinct pair of colours and direction.>
  <LI=Text - a text element, one tspan per line. SVG has no word wrap,
  so the lines are laid out here: words are measured through an FNC
  graphics with the same font, which is also how CAD_DT_CALCRECT is
  answered. The baseline is put at four fifths of the line height. A
  viewer with other font metrics will make the words a little wider or
  narrower than they were measured; the line breaks stay where they
  were put. Rotation (Escapement) turns about the middle of the text
  rectangle, as FNC does.>
  <LI=Images - an image element carrying the picture's own bytes (PNG,
  BMP or JPEG) as a data URI.>
  <LI=PushClip/PopClip - a clipPath in defs and a group that uses it.>

  The paper itself is not painted, as in the PDF: an SVG put on a page
  shows the page through it.

  The unit uses no framework. The FNC text measurer is the only thing
  that does, and on the LCL, where it is not wired up, text is measured
  from the font size alone. }
unit VCL.FNCCS4SVG;

{$I VCL.FNCCADSys.inc}

{ : Range checking off - PCADPoints is the 'array [0..0] of TPoint'
  idiom, which cannot be range checked. }
{$RANGECHECKS OFF}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4Paper,
  VCL.FNCCADSys4;

var
  { : Dots per inch the sheet is laid out at - see COORDINATES above.
    Never less than 72. }
  CADSVGResolution: Integer = 600;

type
  { : A <See Class=TCADGraphics> that writes SVG. Draw on it, then take
    <See Method=SVGText> or <See Method=SaveToStream>. }
  TCADSVGGraphics = class(TCADGraphics)
  private
    fWidthPx: Integer;
    fHeightPx: Integer;
    fWidthMM: Double;
    fHeightMM: Double;
    fBody: TStringBuilder;
    fDefs: TStringBuilder;
    { : Gradients and clip paths already in defs, by what they draw, so
      a thousand bars in the same two colours share one gradient. }
    fDefIds: TStringList;
    fNextId: Integer;
    fGroupDepth: Integer;
    fFontColor: TCADColor;
    fTransparent: Boolean;
    fFont: TCADFontSpec;
    fFontSelected: Boolean;
    fCurPt: TPoint;
    { : The polyline LineTo is building, and the stroke it started
      with. }
    fRun: array of TPoint;
    fRunCount: Integer;
    fRunStroke: string;
    fMeasurer: TObject;
    fFmt: TFormatSettings;
    procedure PenChanged(Sender: TObject);
    procedure FlushRun;
    function Num(const AValue: Double): string;
    function ColorText(const AColor: TCADColor): string;
    function StrokeAttrs: string;
    function FillAttrs: string;
    function DefId(const AKey, APrefix: string; out AId: string): Boolean;
    procedure AppendPoints(const APts: Pointer; const ACount: Integer);
    function TextLines(const AText: string; const AWidth: Integer;
      const AWrap, ASingle: Boolean): TStringDynArray;
    function CurrentFont: TCADFontSpec;
  protected
    function CreatePen: TCADPen; override;
    function CreateBrush: TCADBrush; override;
    function GetFontColor: TCADColor; override;
    procedure SetFontColor(const Value: TCADColor); override;
    function GetTransparent: Boolean; override;
    procedure SetTransparent(const Value: Boolean); override;
    function GetClipRect: TRect; override;
    procedure DoPushClip(const R: TRect); override;
    procedure DoPopClip; override;
    procedure DoPolygon(const Pts: Pointer; const Count: Integer); override;
    procedure DoRectangle(const X1, Y1, X2, Y2: Integer); override;
    procedure DoEllipse(const X1, Y1, X2, Y2: Integer); override;
    procedure DoFillRect(const R: TRect); override;
    { : The size of AText on one line in AFont, in device pixels. The
      layout of word-wrapped text and CAD_DT_CALCRECT both come from
      here. }
    function MeasureText(const AText: string;
      const AFont: TCADFontSpec): TPoint; virtual;
  public
    { : A surface AWidthPx by AHeightPx device pixels, APixelsPerMM to
      the millimetre - which sets <See Property=PixelsPerMM> and the
      size the file says it is. 0 for "not known" writes the size in
      pixels. }
    constructor Create(const AWidthPx, AHeightPx: Integer;
      const APixelsPerMM: Double);
    destructor Destroy; override;

    procedure MoveTo(const X, Y: Integer); override;
    procedure LineTo(const X, Y: Integer); override;
    procedure Polyline(const Pts: Pointer; const Count: Integer); overload;
      override;
    procedure SelectFont(const Font: TCADFontSpec); override;
    procedure ResetFont; override;
    function DrawText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer; override;
    procedure DrawImage(const Dest: TRect; const Image: TCADImage;
      const CopyMode: LongInt); override;

    { : The complete document, as drawn so far. Clips still pushed are
      closed in it, not here: drawing can go on afterwards. }
    function SVGText: String;
    { : SVGText as UTF-8, without a byte order mark. }
    procedure SaveToStream(const AStream: TStream);

    property WidthPx: Integer read fWidthPx;
    property HeightPx: Integer read fHeightPx;
    { : The size the file says it is, in millimetres. WidthPx over
      PixelsPerMM until set; the sheet export sets the paper's own
      figures, so an A3 sheet says 420mm rather than the 419.99 its
      whole dots come to. 0 writes the size in pixels. }
    property WidthMM: Double read fWidthMM write fWidthMM;
    property HeightMM: Double read fHeightMM write fHeightMM;
  end;

{ : ASheet as an SVG document in AStream: the size of its paper, laid
  out at <See Variable=CADSVGResolution>. }
procedure CADSaveSheetToSVGStream(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AStream: TStream);

{ : One file per sheet. AFileNamePattern is a Format pattern given the
  sheet's place in ASheets, counting from 1 - 'plate-%d.svg' makes
  plate-1.svg, plate-2.svg and so on. A pattern without a '%' is only
  accepted for a single sheet. }
procedure CADSaveSheetsToSVG(const ACAD: TFNCCADCmp2D;
  const ASheets: array of TCADSheet; const AFileNamePattern: String);

implementation

{$IFNDEF CADSYS_LCL}
uses
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics,
{$ENDIF}
  VCL.FNCCS4GraphicsFNC;
{$ENDIF}

const
  NoFill = ' fill="none"';
  NoStroke = ' stroke="none"';
  { : Where the baseline sits in a line, as a fraction of its height:
    near enough the ascent of every ordinary font. }
  BaselineRatio = 0.8;

{ ------------------------------------------------------------------
  Helpers
  ------------------------------------------------------------------ }

function XMLEscape(const S: string): string;
var
  SB: TStringBuilder;
  I: Integer;
  C: Char;
begin
  SB := TStringBuilder.Create(Length(S) + 16);
  try
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '&': SB.Append('&amp;');
        '<': SB.Append('&lt;');
        '>': SB.Append('&gt;');
        '"': SB.Append('&quot;');
      else
        { XML 1.0 has no way to write the other control characters at
          all; dropping them is the only thing that keeps the file
          readable. }
        if (Ord(C) >= 32) or (C = #9) then
          SB.Append(C);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function Base64Of(const AData: TBytes): string;
const
  Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, N, P: Integer;
  V: Cardinal;
begin
  N := Length(AData);
  SetLength(Result, ((N + 2) div 3) * 4);
  I := 0;
  P := 1;
  while I < N do
  begin
    V := Cardinal(AData[I]) shl 16;
    if I + 1 < N then
      V := V or (Cardinal(AData[I + 1]) shl 8);
    if I + 2 < N then
      V := V or Cardinal(AData[I + 2]);
    Result[P] := Alphabet[((V shr 18) and 63) + 1];
    Result[P + 1] := Alphabet[((V shr 12) and 63) + 1];
    if I + 1 < N then
      Result[P + 2] := Alphabet[((V shr 6) and 63) + 1]
    else
      Result[P + 2] := '=';
    if I + 2 < N then
      Result[P + 3] := Alphabet[(V and 63) + 1]
    else
      Result[P + 3] := '=';
    Inc(I, 3);
    Inc(P, 4);
  end;
end;

{ : The media type of an encoded picture, from its first bytes, or ''
  for one an SVG viewer could not show. }
function ImageMediaType(const AData: TBytes): string;
begin
  Result := '';
  if Length(AData) < 4 then
    Exit;
  if (AData[0] = $89) and (AData[1] = $50) and (AData[2] = $4E) and
    (AData[3] = $47) then
    Result := 'image/png'
  else if (AData[0] = $FF) and (AData[1] = $D8) then
    Result := 'image/jpeg'
  else if (AData[0] = Ord('B')) and (AData[1] = Ord('M')) then
    Result := 'image/bmp';
end;

{ : The em size of a font spec in device pixels: a negative LOGFONT
  height is the character height already, a positive one the cell
  height, which carries about a fifth more for internal leading. }
function FontEmPx(const AFont: TCADFontSpec): Double;
begin
  if AFont.Height < 0 then
    Result := -AFont.Height
  else if AFont.Height > 0 then
    Result := AFont.Height / 1.2
  else
    Result := 12;
end;

{ : The family to ask the viewer for. 'Small Fonts' is a Windows bitmap
  font no viewer has; FNC draws it as Tahoma, so the SVG does too. }
function FontFamily(const AFont: TCADFontSpec): string;
var
  TmpName: string;
begin
  TmpName := AFont.FaceName;
  if (TmpName = '') or SameText(TmpName, 'Small Fonts') or
    SameText(TmpName, 'Small Font') then
    TmpName := 'Tahoma';
  { Quoted for CSS, with nothing in the name that could end the
    quote. }
  TmpName := StringReplace(TmpName, '''', '', [rfReplaceAll]);
  Result := '''' + XMLEscape(TmpName) + ''', sans-serif';
end;

{ ------------------------------------------------------------------
  TSVGTextMeasurer - the hidden FNC graphics the text is measured on
  ------------------------------------------------------------------ }

type
  TSVGTextMeasurer = class(TObject)
  private
{$IFNDEF CADSYS_LCL}
    fFNC: TTMSFNCGraphics;
    fCAD: TCADFNCGraphics;
{$ENDIF}
    fFont: TCADFontSpec;
    fHasFont: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Measure(const AText: string; const AFont: TCADFontSpec): TPoint;
  end;

constructor TSVGTextMeasurer.Create;
begin
  inherited Create;
{$IFNDEF CADSYS_LCL}
  { Not high-DPI, as for the PNG export: a pixel here is a pixel of the
    layout, whatever the display is. }
  fFNC := TTMSFNCGraphics.CreateBitmapCanvas(16, 16, False, False);
  fFNC.BeginScene;
  fCAD := TCADFNCGraphics.Create(fFNC, Rect(0, 0, 16, 16), False);
{$ENDIF}
end;

destructor TSVGTextMeasurer.Destroy;
begin
{$IFNDEF CADSYS_LCL}
  fCAD.Free;
  if fFNC <> nil then
  begin
    fFNC.EndScene;
    fFNC.Free;
  end;
{$ENDIF}
  inherited Destroy;
end;

function TSVGTextMeasurer.Measure(const AText: string;
  const AFont: TCADFontSpec): TPoint;
{$IFNDEF CADSYS_LCL}
var
  R: TRect;
{$ENDIF}
begin
{$IFDEF CADSYS_LCL}
  { No FNC graphics to ask: an average character is a little over half
    an em wide, and a line a fifth more than an em tall. }
  Result := Point(Round(Length(AText) * 0.55 * FontEmPx(AFont)),
    Round(1.2 * FontEmPx(AFont)));
{$ELSE}
  if (not fHasFont) or not TCADFontSpec.Same(fFont, AFont) then
  begin
    fCAD.SelectFont(AFont);
    fFont := AFont;
    fHasFont := True;
  end;
  R := Rect(0, 0, 0, 0);
  fCAD.DrawText(AText, R, CAD_DT_CALCRECT or CAD_DT_SINGLELINE or
    CAD_DT_NOPREFIX);
  Result := Point(R.Right - R.Left, R.Bottom - R.Top);
{$ENDIF}
end;

{ ------------------------------------------------------------------
  TCADSVGGraphics
  ------------------------------------------------------------------ }

constructor TCADSVGGraphics.Create(const AWidthPx, AHeightPx: Integer;
  const APixelsPerMM: Double);
begin
  inherited Create;
  fWidthPx := Max(1, AWidthPx);
  fHeightPx := Max(1, AHeightPx);
  if APixelsPerMM > 0 then
    PixelsPerMM := APixelsPerMM
  else
    PixelsPerMM := 0;
  if PixelsPerMM > 0 then
  begin
    fWidthMM := fWidthPx / PixelsPerMM;
    fHeightMM := fHeightPx / PixelsPerMM;
  end;
  fBody := TStringBuilder.Create;
  fDefs := TStringBuilder.Create;
  fDefIds := TStringList.Create;
  fDefIds.Sorted := True;
  fDefIds.CaseSensitive := True;
  fFontColor := cadclBlack;
  { As the FNC backend: text does not paint its rectangle unless told
    to. }
  fTransparent := True;
  fFont := TCADFontSpec.Default;
  fFmt := FormatSettings;
  fFmt.DecimalSeparator := '.';
  fFmt.ThousandSeparator := ',';
  { The pen was made by the inherited constructor, before any of this
    existed; only now can it be told whom to call. }
  (Pen as TCADSimplePen).OnChange := PenChanged;
end;

destructor TCADSVGGraphics.Destroy;
begin
  if Pen is TCADSimplePen then
    TCADSimplePen(Pen).OnChange := nil;
  fMeasurer.Free;
  fDefIds.Free;
  fDefs.Free;
  fBody.Free;
  inherited Destroy;
end;

function TCADSVGGraphics.CreatePen: TCADPen;
begin
  Result := TCADSimplePen.Create;
end;

function TCADSVGGraphics.CreateBrush: TCADBrush;
begin
  Result := TCADSimpleBrush.Create;
end;

function TCADSVGGraphics.GetFontColor: TCADColor;
begin
  Result := fFontColor;
end;

procedure TCADSVGGraphics.SetFontColor(const Value: TCADColor);
begin
  fFontColor := Value;
end;

function TCADSVGGraphics.GetTransparent: Boolean;
begin
  Result := fTransparent;
end;

procedure TCADSVGGraphics.SetTransparent(const Value: Boolean);
begin
  fTransparent := Value;
end;

function TCADSVGGraphics.GetClipRect: TRect;
begin
  Result := Rect(0, 0, fWidthPx, fHeightPx);
end;

procedure TCADSVGGraphics.PenChanged(Sender: TObject);
begin
  { The run carries the stroke it was started with; what is drawn after
    the change starts a run of its own. }
  FlushRun;
end;

function TCADSVGGraphics.Num(const AValue: Double): string;
begin
  Result := FormatFloat('0.###', AValue, fFmt);
end;

function TCADSVGGraphics.ColorText(const AColor: TCADColor): string;
begin
  Result := '#' + IntToHex(Integer(AColor and $FFFFFF), 6);
end;

function TCADSVGGraphics.DefId(const AKey, APrefix: string;
  out AId: string): Boolean;
var
  Idx: Integer;
begin
  Result := fDefIds.Find(AKey, Idx);
  if Result then
    AId := APrefix + IntToStr(NativeInt(fDefIds.Objects[Idx]))
  else
  begin
    Inc(fNextId);
    AId := APrefix + IntToStr(fNextId);
    fDefIds.AddObject(AKey, TObject(NativeInt(fNextId)));
  end;
end;

function TCADSVGGraphics.StrokeAttrs: string;
const
  { GDI's own dash patterns, in pen widths of a one-pixel pen. }
  DashPattern: array [0 .. 1] of Integer = (18, 6);
  DotPattern: array [0 .. 1] of Integer = (3, 3);
  DashDotPattern: array [0 .. 3] of Integer = (9, 6, 3, 6);
  DashDotDotPattern: array [0 .. 5] of Integer = (9, 3, 3, 3, 3, 3);
  AlternatePattern: array [0 .. 1] of Integer = (1, 1);

  function Dashes(const APattern: array of Integer; const AUnit: Double)
    : string;
  var
    I: Integer;
  begin
    Result := ' stroke-dasharray="';
    for I := 0 to High(APattern) do
    begin
      if I > 0 then
        Result := Result + ',';
      Result := Result + Num(APattern[I] * AUnit);
    end;
    Result := Result + '"';
  end;

var
  TmpColor: TCADColor;
  TmpWidth: Integer;
  TmpUnit: Double;
begin
  if (Pen.Mode = cpmNop) or (Pen.Style = cpsClear) or
    (CADColorAlpha(Pen.Color) = 0) then
    Exit(NoStroke);
  case Pen.Mode of
    cpmBlack:
      TmpColor := cadclBlack;
    cpmWhite:
      TmpColor := cadclWhite;
  else
    { The raster modes - XOR above all - are for rubber bands on a
      screen. A file has nothing under it to combine with; the honest
      picture of the line is the line. }
    TmpColor := Pen.Color;
  end;
  TmpWidth := Max(1, Pen.Width);
  Result := ' stroke="' + ColorText(TmpColor) + '" stroke-width="' +
    IntToStr(TmpWidth) + '"';
  if CADColorAlpha(TmpColor) < 255 then
    Result := Result + ' stroke-opacity="' +
      Num(CADColorAlpha(TmpColor) / 255) + '"';
  { A GDI pattern is counted in screen pixels. On paper that is a
    quarter of a millimetre a pixel, so a dash is as long in the file as
    it looks on the screen - not a twenty-fourth of that, which would
    print as a solid line. }
  TmpUnit := TmpWidth;
  if PixelsPerMM > 0 then
    TmpUnit := Max(TmpUnit, PixelsPerMM * 25.4 / 96);
  case Pen.Style of
    cpsDash:
      Result := Result + Dashes(DashPattern, TmpUnit);
    cpsDot:
      Result := Result + Dashes(DotPattern, TmpUnit);
    cpsDashDot:
      Result := Result + Dashes(DashDotPattern, TmpUnit);
    cpsDashDotDot:
      Result := Result + Dashes(DashDotDotPattern, TmpUnit);
    cpsAlternate:
      Result := Result + Dashes(AlternatePattern, TmpUnit);
  end;
end;

function TCADSVGGraphics.FillAttrs: string;
var
  TmpId, TmpKey, TmpOpacity: string;
  TmpAlpha: Byte;
begin
  TmpAlpha := CADColorAlpha(Brush.Color);
  if (Brush.Style = cbsClear) or (TmpAlpha = 0) then
    Exit(NoFill);
  if TmpAlpha < 255 then
    TmpOpacity := Num(TmpAlpha / 255)
  else
    TmpOpacity := '';
  if Brush.Style = cbsGradient then
  begin
    TmpKey := 'g:' + IntToHex(Int64(Brush.Color), 8) + ':' +
      IntToHex(Int64(Brush.Color2), 8) + ':' +
      BoolToStr(Brush.GradientVertical, True);
    if not DefId(TmpKey, 'grad', TmpId) then
    begin
      { objectBoundingBox, the default: the blend runs across whatever
        shape uses it, as it does in FNC and in GDI. }
      fDefs.Append('<linearGradient id="').Append(TmpId)
        .Append('" x1="0" y1="0"');
      if Brush.GradientVertical then
        fDefs.Append(' x2="0" y2="1">')
      else
        fDefs.Append(' x2="1" y2="0">');
      fDefs.Append('<stop offset="0" stop-color="')
        .Append(ColorText(Brush.Color)).Append('"');
      if TmpOpacity <> '' then
        fDefs.Append(' stop-opacity="').Append(TmpOpacity).Append('"');
      fDefs.Append('/><stop offset="1" stop-color="')
        .Append(ColorText(Brush.Color2)).Append('"');
      { Alpha comes from Color for both ends - see TCADBrush.Color2. }
      if TmpOpacity <> '' then
        fDefs.Append(' stop-opacity="').Append(TmpOpacity).Append('"');
      fDefs.Append('/></linearGradient>'#10);
    end;
    Exit(' fill="url(#' + TmpId + ')"');
  end;
  { Everything else is solid: the hatch styles were drawn as lines by
    the base class before they got here. }
  Result := ' fill="' + ColorText(Brush.Color) + '"';
  if TmpOpacity <> '' then
    Result := Result + ' fill-opacity="' + TmpOpacity + '"';
end;

procedure TCADSVGGraphics.AppendPoints(const APts: Pointer;
  const ACount: Integer);
var
  I: Integer;
  P: PCADPoints;
begin
  P := PCADPoints(APts);
  for I := 0 to ACount - 1 do
  begin
    if I > 0 then
      fBody.Append(' ');
    fBody.Append(IntToStr(P^[I].X)).Append(',').Append(IntToStr(P^[I].Y));
  end;
end;

procedure TCADSVGGraphics.FlushRun;
begin
  if (fRunCount >= 2) and (fRunStroke <> NoStroke) then
  begin
    fBody.Append('<polyline points="');
    AppendPoints(@fRun[0], fRunCount);
    fBody.Append('"').Append(NoFill).Append(fRunStroke).Append('/>'#10);
  end;
  fRunCount := 0;
end;

procedure TCADSVGGraphics.MoveTo(const X, Y: Integer);
begin
  { A MoveTo to where the run already ends changes nothing - the
    library draws a lot of polylines as MoveTo/LineTo pairs. }
  if (fRunCount > 0) and (fRun[fRunCount - 1].X = X) and
    (fRun[fRunCount - 1].Y = Y) then
    Exit;
  FlushRun;
  fCurPt := Point(X, Y);
end;

procedure TCADSVGGraphics.LineTo(const X, Y: Integer);
begin
  if fRunCount = 0 then
  begin
    fRunStroke := StrokeAttrs;
    if Length(fRun) < 16 then
      SetLength(fRun, 16);
    fRun[0] := fCurPt;
    fRunCount := 1;
  end;
  if fRunCount = Length(fRun) then
    SetLength(fRun, fRunCount * 2);
  fRun[fRunCount] := Point(X, Y);
  Inc(fRunCount);
  fCurPt := Point(X, Y);
end;

procedure TCADSVGGraphics.Polyline(const Pts: Pointer; const Count: Integer);
var
  TmpStroke: string;
begin
  FlushRun;
  if (Pts = nil) or (Count <= 0) then
    Exit;
  fCurPt := PCADPoints(Pts)^[Count - 1];
  if Count < 2 then
    Exit;
  TmpStroke := StrokeAttrs;
  if TmpStroke = NoStroke then
    Exit;
  fBody.Append('<polyline points="');
  AppendPoints(Pts, Count);
  fBody.Append('"').Append(NoFill).Append(TmpStroke).Append('/>'#10);
end;

procedure TCADSVGGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
var
  TmpFill, TmpStroke: string;
begin
  FlushRun;
  if (Pts = nil) or (Count < 2) then
    Exit;
  TmpFill := FillAttrs;
  TmpStroke := StrokeAttrs;
  if (TmpFill = NoFill) and (TmpStroke = NoStroke) then
    Exit;
  fBody.Append('<polygon points="');
  AppendPoints(Pts, Count);
  fBody.Append('"').Append(TmpFill).Append(TmpStroke).Append('/>'#10);
end;

procedure TCADSVGGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
var
  TmpFill, TmpStroke: string;
begin
  FlushRun;
  if (X1 = X2) and (Y1 = Y2) then
    Exit;
  TmpFill := FillAttrs;
  TmpStroke := StrokeAttrs;
  if (TmpFill = NoFill) and (TmpStroke = NoStroke) then
    Exit;
  { X2 and Y2 are exclusive, as in GDI: the rectangle covers X2 - X1
    pixels, and in vector terms that is its width. }
  fBody.Append('<rect x="').Append(IntToStr(Min(X1, X2)))
    .Append('" y="').Append(IntToStr(Min(Y1, Y2)))
    .Append('" width="').Append(IntToStr(Abs(X2 - X1)))
    .Append('" height="').Append(IntToStr(Abs(Y2 - Y1))).Append('"')
    .Append(TmpFill).Append(TmpStroke).Append('/>'#10);
end;

procedure TCADSVGGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
var
  TmpFill, TmpStroke: string;
begin
  FlushRun;
  if (X1 = X2) and (Y1 = Y2) then
    Exit;
  TmpFill := FillAttrs;
  TmpStroke := StrokeAttrs;
  if (TmpFill = NoFill) and (TmpStroke = NoStroke) then
    Exit;
  fBody.Append('<ellipse cx="').Append(Num((X1 + X2) / 2))
    .Append('" cy="').Append(Num((Y1 + Y2) / 2))
    .Append('" rx="').Append(Num(Abs(X2 - X1) / 2))
    .Append('" ry="').Append(Num(Abs(Y2 - Y1) / 2)).Append('"')
    .Append(TmpFill).Append(TmpStroke).Append('/>'#10);
end;

procedure TCADSVGGraphics.DoFillRect(const R: TRect);
var
  TmpFill: string;
begin
  FlushRun;
  if (R.Right = R.Left) or (R.Bottom = R.Top) then
    Exit;
  TmpFill := FillAttrs;
  if TmpFill = NoFill then
    Exit;
  fBody.Append('<rect x="').Append(IntToStr(Min(R.Left, R.Right)))
    .Append('" y="').Append(IntToStr(Min(R.Top, R.Bottom)))
    .Append('" width="').Append(IntToStr(Abs(R.Right - R.Left)))
    .Append('" height="').Append(IntToStr(Abs(R.Bottom - R.Top)))
    .Append('"').Append(TmpFill).Append(NoStroke).Append('/>'#10);
end;

procedure TCADSVGGraphics.DoPushClip(const R: TRect);
var
  TmpId: string;
begin
  FlushRun;
  { R is already intersected with everything outside it - see
    TCADGraphics.PushClip - so one rectangle per group is the whole
    story, and the same rectangle again is the same clip path. }
  if not DefId(Format('c:%d,%d,%d,%d', [R.Left, R.Top, R.Right, R.Bottom]),
    'clip', TmpId) then
    fDefs.Append('<clipPath id="').Append(TmpId).Append('"><rect x="')
      .Append(IntToStr(R.Left)).Append('" y="').Append(IntToStr(R.Top))
      .Append('" width="').Append(IntToStr(Max(0, R.Right - R.Left)))
      .Append('" height="').Append(IntToStr(Max(0, R.Bottom - R.Top)))
      .Append('"/></clipPath>'#10);
  fBody.Append('<g clip-path="url(#').Append(TmpId).Append(')">'#10);
  Inc(fGroupDepth);
end;

procedure TCADSVGGraphics.DoPopClip;
begin
  FlushRun;
  if fGroupDepth = 0 then
    Exit;
  fBody.Append('</g>'#10);
  Dec(fGroupDepth);
end;

procedure TCADSVGGraphics.SelectFont(const Font: TCADFontSpec);
begin
  FlushRun;
  fFont := Font;
  fFontSelected := True;
end;

procedure TCADSVGGraphics.ResetFont;
begin
  fFontSelected := False;
end;

function TCADSVGGraphics.CurrentFont: TCADFontSpec;
begin
  if fFontSelected then
    Result := fFont
  else
    Result := TCADFontSpec.Default;
end;

function TCADSVGGraphics.MeasureText(const AText: string;
  const AFont: TCADFontSpec): TPoint;
begin
  if fMeasurer = nil then
    fMeasurer := TSVGTextMeasurer.Create;
  Result := TSVGTextMeasurer(fMeasurer).Measure(AText, AFont);
end;

function TCADSVGGraphics.TextLines(const AText: string;
  const AWidth: Integer; const AWrap, ASingle: Boolean): TStringDynArray;
var
  TmpFont: TCADFontSpec;
  TmpCount: Integer;
  TmpOut: TStringDynArray;

  procedure Add(const ALine: string);
  begin
    if TmpCount = Length(TmpOut) then
      SetLength(TmpOut, TmpCount * 2 + 4);
    TmpOut[TmpCount] := ALine;
    Inc(TmpCount);
  end;

  procedure AddWrapped(const APara: string);
  var
    TmpLine, TmpWord, TmpCand: string;
    I, TmpStart: Integer;
  begin
    TmpLine := '';
    TmpStart := 1;
    { Greedy, as GDI's DT_WORDBREAK is: as many words as fit, and a
      word wider than the rectangle on a line of its own rather than
      broken. }
    for I := 1 to Length(APara) + 1 do
      if (I > Length(APara)) or (APara[I] = ' ') then
      begin
        TmpWord := Copy(APara, TmpStart, I - TmpStart);
        TmpStart := I + 1;
        if TmpLine = '' then
          TmpCand := TmpWord
        else
          TmpCand := TmpLine + ' ' + TmpWord;
        if (TmpLine <> '') and (MeasureText(TmpCand, TmpFont).X > AWidth) then
        begin
          Add(TmpLine);
          TmpLine := TmpWord;
        end
        else
          TmpLine := TmpCand;
      end;
    Add(TmpLine);
  end;

var
  TmpText: string;
  I, TmpStart: Integer;
  TmpPara: string;
begin
  SetLength(TmpOut, 0);
  TmpCount := 0;
  TmpFont := CurrentFont;
  TmpText := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  TmpText := StringReplace(TmpText, #13, #10, [rfReplaceAll]);
  if ASingle then
    TmpText := StringReplace(TmpText, #10, ' ', [rfReplaceAll]);
  TmpStart := 1;
  for I := 1 to Length(TmpText) + 1 do
    if (I > Length(TmpText)) or (TmpText[I] = #10) then
    begin
      TmpPara := Copy(TmpText, TmpStart, I - TmpStart);
      TmpStart := I + 1;
      if AWrap and (AWidth > 0) then
        AddWrapped(TmpPara)
      else
        Add(TmpPara);
    end;
  SetLength(TmpOut, TmpCount);
  Result := TmpOut;
end;

function TCADSVGGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
var
  TmpFont: TCADFontSpec;
  TmpLines: TStringDynArray;
  TmpWrap, TmpSingle: Boolean;
  TmpLineH, TmpWidest, I, TmpW: Integer;
  TmpTop, TmpX, TmpEm, TmpAngle: Double;
  TmpAnchor, TmpDecoration: string;
begin
  FlushRun;
  TmpFont := CurrentFont;
  TmpSingle := (Flags and CAD_DT_SINGLELINE) <> 0;
  TmpWrap := ((Flags and CAD_DT_WORDBREAK) <> 0) and not TmpSingle;
  TmpLines := TextLines(Text, R.Right - R.Left, TmpWrap, TmpSingle);
  TmpLineH := MeasureText('Wg', TmpFont).Y;
  TmpEm := FontEmPx(TmpFont);
  if TmpLineH <= 0 then
    TmpLineH := Max(1, Round(TmpEm * 1.2));

  if (Flags and CAD_DT_CALCRECT) <> 0 then
  begin
    TmpWidest := 0;
    for I := 0 to High(TmpLines) do
    begin
      TmpW := MeasureText(TmpLines[I], TmpFont).X;
      if TmpW > TmpWidest then
        TmpWidest := TmpW;
    end;
    R.Right := R.Left + TmpWidest;
    R.Bottom := R.Top + TmpLineH * Length(TmpLines);
    Result := R.Bottom - R.Top;
    Exit;
  end;

  Result := R.Bottom - R.Top;
  if not fTransparent then
    FillRect(R);
  if (Length(TmpLines) = 0) or ((Length(TmpLines) = 1) and
    (TmpLines[0] = '')) then
    Exit;

  if (Flags and CAD_DT_CENTER) <> 0 then
  begin
    TmpX := (R.Left + R.Right) / 2;
    TmpAnchor := ' text-anchor="middle"';
  end
  else if (Flags and CAD_DT_RIGHT) <> 0 then
  begin
    TmpX := R.Right;
    TmpAnchor := ' text-anchor="end"';
  end
  else
  begin
    TmpX := R.Left;
    TmpAnchor := '';
  end;
  if (Flags and CAD_DT_VCENTER) <> 0 then
    TmpTop := (R.Top + R.Bottom - TmpLineH * Length(TmpLines)) / 2
  else if (Flags and CAD_DT_BOTTOM) <> 0 then
    TmpTop := R.Bottom - TmpLineH * Length(TmpLines)
  else
    TmpTop := R.Top;

  fBody.Append('<text font-family="').Append(FontFamily(TmpFont))
    .Append('" font-size="').Append(Num(TmpEm)).Append('"');
  if TmpFont.Weight >= 600 then
    fBody.Append(' font-weight="bold"');
  if TmpFont.Italic then
    fBody.Append(' font-style="italic"');
  TmpDecoration := '';
  if TmpFont.Underline then
    TmpDecoration := 'underline';
  if TmpFont.StrikeOut then
    TmpDecoration := Trim(TmpDecoration + ' line-through');
  if TmpDecoration <> '' then
    fBody.Append(' text-decoration="').Append(TmpDecoration).Append('"');
  fBody.Append(' fill="').Append(ColorText(fFontColor)).Append('"');
  if CADColorAlpha(fFontColor) < 255 then
    fBody.Append(' fill-opacity="')
      .Append(Num(CADColorAlpha(fFontColor) / 255)).Append('"');
  fBody.Append(TmpAnchor);
  { Escapement is counter-clockwise in tenths of a degree; SVG's
    rotate, with Y down, turns clockwise. }
  TmpAngle := TmpFont.Escapement / 10;
  if TmpAngle <> 0 then
    fBody.Append(' transform="rotate(').Append(Num(-TmpAngle)).Append(' ')
      .Append(Num((R.Left + R.Right) / 2)).Append(' ')
      .Append(Num((R.Top + R.Bottom) / 2)).Append(')"');
  fBody.Append(' xml:space="preserve">');
  if Length(TmpLines) = 1 then
    fBody.Append('<tspan x="').Append(Num(TmpX)).Append('" y="')
      .Append(Num(TmpTop + TmpLineH * BaselineRatio)).Append('">')
      .Append(XMLEscape(TmpLines[0])).Append('</tspan>')
  else
    for I := 0 to High(TmpLines) do
      fBody.Append('<tspan x="').Append(Num(TmpX)).Append('" y="')
        .Append(Num(TmpTop + TmpLineH * (I + BaselineRatio))).Append('">')
        .Append(XMLEscape(TmpLines[I])).Append('</tspan>');
  fBody.Append('</text>'#10);
end;

procedure TCADSVGGraphics.DrawImage(const Dest: TRect;
  const Image: TCADImage; const CopyMode: LongInt);
var
  TmpType: string;
begin
  FlushRun;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  if (Dest.Right = Dest.Left) or (Dest.Bottom = Dest.Top) then
    Exit;
  TmpType := ImageMediaType(Image.Data);
  if TmpType = '' then
    Exit;
  { CopyMode is a raster operation on pixels underneath; a file has
    none, so every mode is a plain copy - as on FNC. }
  fBody.Append('<image x="').Append(IntToStr(Min(Dest.Left, Dest.Right)))
    .Append('" y="').Append(IntToStr(Min(Dest.Top, Dest.Bottom)))
    .Append('" width="').Append(IntToStr(Abs(Dest.Right - Dest.Left)))
    .Append('" height="').Append(IntToStr(Abs(Dest.Bottom - Dest.Top)))
    .Append('" preserveAspectRatio="none" xlink:href="data:')
    .Append(TmpType).Append(';base64,').Append(Base64Of(Image.Data))
    .Append('"/>'#10);
end;

function TCADSVGGraphics.SVGText: String;
var
  SB: TStringBuilder;
  I: Integer;
begin
  FlushRun;
  SB := TStringBuilder.Create(fBody.Length + fDefs.Length + 512);
  try
    SB.Append('<?xml version="1.0" encoding="UTF-8" standalone="no"?>'#10);
    SB.Append('<svg xmlns="http://www.w3.org/2000/svg" ' +
      'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1"');
    if (fWidthMM > 0) and (fHeightMM > 0) then
      SB.Append(' width="').Append(Num(fWidthMM)).Append('mm" height="')
        .Append(Num(fHeightMM)).Append('mm"')
    else
      SB.Append(' width="').Append(IntToStr(fWidthPx)).Append('" height="')
        .Append(IntToStr(fHeightPx)).Append('"');
    { Even-odd, as GDI fills a polygon by default (ALTERNATE). }
    SB.Append(' viewBox="0 0 ').Append(IntToStr(fWidthPx)).Append(' ')
      .Append(IntToStr(fHeightPx)).Append('" fill-rule="evenodd">'#10);
    if fDefs.Length > 0 then
      SB.Append('<defs>'#10).Append(fDefs.ToString).Append('</defs>'#10);
    SB.Append(fBody.ToString);
    for I := 1 to fGroupDepth do
      SB.Append('</g>'#10);
    SB.Append('</svg>'#10);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TCADSVGGraphics.SaveToStream(const AStream: TStream);
var
  TmpBytes: TBytes;
begin
  TmpBytes := TEncoding.UTF8.GetBytes(SVGText);
  if Length(TmpBytes) > 0 then
    AStream.WriteBuffer(TmpBytes[0], Length(TmpBytes));
end;

{ ------------------------------------------------------------------
  Entry points
  ------------------------------------------------------------------ }

procedure CADSaveSheetToSVGStream(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AStream: TStream);
var
  TmpW, TmpH: TRealType;
  TmpDevice: TCADPageDevice;
  TmpSVG: TCADSVGGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  if (ACAD = nil) or (ASheet = nil) or (AStream = nil) then
    Exit;
  ASheet.SizeMM(TmpW, TmpH);
  if (TmpW <= 0) or (TmpH <= 0) then
    Raise ECADPageError.Create('The sheet has no paper size');
  TmpDevice := TCADPageDevice.FromDPI(Max(72, CADSVGResolution),
    Max(72, CADSVGResolution));
  TmpSVG := TCADSVGGraphics.Create(TmpDevice.MMToPxX(TmpW),
    TmpDevice.MMToPxY(TmpH), TmpDevice.PixelsPerMM);
  try
    TmpSVG.WidthMM := TmpW;
    TmpSVG.HeightMM := TmpH;
    TmpCanvas := TDecorativeCanvas.Create(TmpSVG, False);
    try
      CADDrawSheet(ACAD, ASheet, TmpDevice, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpSVG.SaveToStream(AStream);
  finally
    TmpSVG.Free;
  end;
end;

procedure CADSaveSheetsToSVG(const ACAD: TFNCCADCmp2D;
  const ASheets: array of TCADSheet; const AFileNamePattern: String);
var
  I: Integer;
  TmpName: String;
  TmpStream: TFileStream;
begin
  if (Length(ASheets) > 1) and (Pos('%', AFileNamePattern) = 0) then
    Raise ECADPageError.Create('Several sheets need a file name pattern ' +
      'with a %d in it, such as ''plate-%d.svg''');
  for I := 0 to High(ASheets) do
  begin
    if ASheets[I] = nil then
      Continue;
    if Pos('%', AFileNamePattern) > 0 then
      TmpName := Format(AFileNamePattern, [I + 1])
    else
      TmpName := AFileNamePattern;
    TmpStream := TFileStream.Create(TmpName, fmCreate);
    try
      CADSaveSheetToSVGStream(ACAD, ASheets[I], TmpStream);
    finally
      TmpStream.Free;
    end;
  end;
end;

end.
