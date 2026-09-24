{: Platform-neutral drawing layer for CADSys 4.

   Every shape, grid and handle in the library draws through a
   <See Class=TDecorativeCanvas>, and a TDecorativeCanvas draws through a
   <See Class=TCADGraphics>. TCADGraphics is abstract: a backend unit
   binds it to a real surface.

   <LI=<I=VCL.FNCCS4GraphicsVCL> - a VCL TCanvas (GDI). Behaves exactly as the
   library did before this layer existed.>
   <LI=<I=VCL.FNCCS4GraphicsFNC> - a TMS FNC TTMSFNCGraphics, which runs on
   VCL, FMX and LCL.>

   This unit must not use any VCL, FMX, LCL or Windows unit.

   The pen, brush and text-format vocabulary deliberately mirrors the VCL
   (same member names, same ordinal order, same DT_ bit values), so code
   written against TCanvas ports by dropping the ".Canvas" and adding a
   "c" prefix to the enum values.
}
unit VCL.FNCCS4Graphics;

{$I VCL.FNCCADSys.inc}

{ : Range checking off - see VCL.FNCCADSys4 for the reasoning. This unit
  indexes a 'array [0..0] of TPoint' through PCADPoints, which is the
  same variable-length-array idiom and equally cannot be range checked. }
{$RANGECHECKS OFF}

interface

uses
{$IFDEF CADSYS_LCL}
  Types, UITypes, Classes, SysUtils, Math;
{$ELSE}
  System.Types, System.UITypes, System.Classes, System.SysUtils, System.Math;
{$ENDIF}

type
  {: Colour as $AARRGGBB: alpha in the high byte, then red, green and
     blue. $FF alpha is opaque, $00 fully transparent.

     This is not a VCL TColor. Use <See Function=TColorToCADColor> and
     <See Function=CADColorToTColor> to convert, and never assign a
     clXxx constant to it directly - the byte order differs. }
  TCADColor = type Cardinal;

  {: Same ordinal order as Vcl.Graphics.TPenStyle. }
  TCADPenStyle = (cpsSolid, cpsDash, cpsDot, cpsDashDot, cpsDashDotDot,
    cpsClear, cpsInsideFrame, cpsUserStyle, cpsAlternate);

  {: Same ordinal order as Vcl.Graphics.TPenMode. Only cpmCopy and cpmXor
     matter to the library; backends without raster operations treat
     every mode other than cpmCopy as "transient overlay drawing". }
  TCADPenMode = (cpmBlack, cpmWhite, cpmNop, cpmNot, cpmCopy, cpmNotCopy,
    cpmMergePenNot, cpmMaskPenNot, cpmMergeNotPen, cpmMaskNotPen, cpmMerge,
    cpmNotMerge, cpmMask, cpmNotMask, cpmXor, cpmNotXor);

  {: Same ordinal order as Vcl.Graphics.TBrushStyle. }
  TCADBrushStyle = (cbsSolid, cbsClear, cbsHorizontal, cbsVertical,
    cbsFDiagonal, cbsBDiagonal, cbsCross, cbsDiagCross);

const
  { Text format flags for TCADGraphics.DrawText. The values equal the
    Windows DT_ constants, so flags that were stored as DT_ values (for
    example TText2D.ClippingFlags) can be passed straight through. }
  CAD_DT_TOP        = $0000;
  CAD_DT_LEFT       = $0000;
  CAD_DT_CENTER     = $0001;
  CAD_DT_RIGHT      = $0002;
  CAD_DT_VCENTER    = $0004;
  CAD_DT_BOTTOM     = $0008;
  CAD_DT_WORDBREAK  = $0010;
  CAD_DT_SINGLELINE = $0020;
  CAD_DT_EXPANDTABS = $0040;
  CAD_DT_NOCLIP     = $0100;
  CAD_DT_CALCRECT   = $0400;
  CAD_DT_NOPREFIX   = $0800;

  { Raster operation for TCADGraphics.DrawImage. The value equals the
    Windows SRCCOPY, which is what a VCL TCanvas.CopyMode holds.
    Backends that cannot do raster operations ignore it. }
  CAD_SRCCOPY = LongInt($00CC0020);

  { Colour constants, so shape code does not need Vcl.Graphics. All are
    opaque; $AARRGGBB. }
  cadclNone    = TCADColor($00000000);
  cadclBlack   = TCADColor($FF000000);
  cadclMaroon  = TCADColor($FF800000);
  cadclGreen   = TCADColor($FF008000);
  cadclOlive   = TCADColor($FF808000);
  cadclNavy    = TCADColor($FF000080);
  cadclPurple  = TCADColor($FF800080);
  cadclTeal    = TCADColor($FF008080);
  cadclGray    = TCADColor($FF808080);
  cadclSilver  = TCADColor($FFC0C0C0);
  cadclRed     = TCADColor($FFFF0000);
  cadclLime    = TCADColor($FF00FF00);
  cadclYellow  = TCADColor($FFFFFF00);
  cadclBlue    = TCADColor($FF0000FF);
  cadclFuchsia = TCADColor($FFFF00FF);
  cadclAqua    = TCADColor($FF00FFFF);
  cadclWhite   = TCADColor($FFFFFFFF);

  { : Plain TColor constants, for the library's published colour
    properties.

    The unscoped clBlack..clWhite everyone writes are declared in
    Vcl.Graphics. System.UITypes has the values only as members of
    TColors, and FMX has no clXxx at all - so a published property's
    'default' clause, which needs a plain constant, has nothing portable
    to name. Hence this set: same values, no framework, usable in a
    default clause on all three targets.

    Note the spelling. These are TColor - the framework's colour type,
    $00BBGGRR, no alpha - and are not interchangeable with the cadcl*
    constants above, which are TCADColor, $AARRGGBB. The two prefixes
    differ by more than case on purpose: Pascal would not tell CADclRed
    and cadclRed apart. }
  cadtcBlack  = System.UITypes.TColor($000000);
  cadtcRed    = System.UITypes.TColor($0000FF);
  cadtcGreen  = System.UITypes.TColor($008000);
  cadtcBlue   = System.UITypes.TColor($FF0000);
  cadtcGray   = System.UITypes.TColor($808080);
  cadtcSilver = System.UITypes.TColor($C0C0C0);
  cadtcWhite  = System.UITypes.TColor($FFFFFF);

type
  { : Resolves a framework system colour to a plain RGB value. Named so
    that callers wanting to save and restore the hook have a type to
    declare a local of. }
  TCADColorResolver = function(const Color: System.UITypes.TColor)
    : System.UITypes.TColor;

var
  { : The installed system colour resolver, or nil.

    The drawing layer cannot know what clBtnFace means - that is a VCL
    idea, and this unit uses no framework at all - so a backend installs
    the resolver. VCL.FNCCS4GraphicsVCL points it at Vcl.Graphics.ColorToRGB
    in its initialization section. With none installed a system colour
    falls back to opaque black.
  }
  CADResolveSystemColor: TCADColorResolver = nil;

type
  TCADGraphics = class;

  {: Pen of a <See Class=TCADGraphics>. The backend decides where the
     values live: the VCL backend reads and writes the TCanvas pen
     directly, so the two can never disagree. }
  TCADPen = class(TObject)
  private
    fLineWeightMM: Double;
    fOwnerGraphics: TCADGraphics;
  protected
    { : Millimetres rather than TRealType, because this unit cannot use
      VCL.FNCCS4BaseTypes - that unit uses this one. They are the same
      type; TRealType is Double. }
    procedure SetLineWeightMM(const Value: Double); virtual;
    function GetColor: TCADColor; virtual; abstract;
    procedure SetColor(const Value: TCADColor); virtual; abstract;
    function GetWidth: Integer; virtual; abstract;
    procedure SetWidth(const Value: Integer); virtual; abstract;
    function GetStyle: TCADPenStyle; virtual; abstract;
    procedure SetStyle(const Value: TCADPenStyle); virtual; abstract;
    function GetMode: TCADPenMode; virtual; abstract;
    procedure SetMode(const Value: TCADPenMode); virtual; abstract;
  public
    procedure Assign(const Source: TCADPen);
    property Color: TCADColor read GetColor write SetColor;
    property Width: Integer read GetWidth write SetWidth;
    property Style: TCADPenStyle read GetStyle write SetStyle;
    property Mode: TCADPenMode read GetMode write SetMode;
    { : The line's physical width in millimetres, or 0 for "use Width".

      Zero by default, which is every drawing that existed before this
      property did, and it means the pen behaves exactly as it always
      has: Width pixels, whatever a pixel happens to be on this device.

      Set it to a real weight - 0.18, 0.25, 0.35, as a draughtsman's pen
      set is numbered - and the pen asks its graphics how many pixels
      that is, the moment it is told. On a surface that does not know
      its own physical scale (PixelsPerMM = 0, which is every screen
      unless something sets it) nothing happens and Width still rules;
      on a printer's it comes out the width it says.

      The order in Assign is Width first and this second, so a pen that
      carries both gives the millimetres the last word. }
    property LineWeightMM: Double read fLineWeightMM write SetLineWeightMM;
    { : The graphics this pen belongs to, or nil for a stored pen such
      as a layer's. }
    property OwnerGraphics: TCADGraphics read fOwnerGraphics;
  end;

  {: Brush of a <See Class=TCADGraphics>. }
  TCADBrush = class(TObject)
  protected
    function GetColor: TCADColor; virtual; abstract;
    procedure SetColor(const Value: TCADColor); virtual; abstract;
    function GetStyle: TCADBrushStyle; virtual; abstract;
    procedure SetStyle(const Value: TCADBrushStyle); virtual; abstract;
  public
    procedure Assign(const Source: TCADBrush);
    property Color: TCADColor read GetColor write SetColor;
    property Style: TCADBrushStyle read GetStyle write SetStyle;
  end;

  {: A pen that only stores its values, for code that owns a pen without
     a surface - a layer, a defaults record, a saved style. Assigning it
     to a graphics pen applies it. }
  TCADSimplePen = class(TCADPen)
  private
    fColor: TCADColor;
    fWidth: Integer;
    fStyle: TCADPenStyle;
    fMode: TCADPenMode;
    fOnChange: TNotifyEvent;
    procedure Changed;
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
    constructor Create;
    {: Called whenever a value changes. }
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
  end;

  {: A brush that only stores its values. See <See Class=TCADSimplePen>. }
  TCADSimpleBrush = class(TCADBrush)
  private
    fColor: TCADColor;
    fStyle: TCADBrushStyle;
    fOnChange: TNotifyEvent;
    procedure Changed;
  protected
    function GetColor: TCADColor; override;
    procedure SetColor(const Value: TCADColor); override;
    function GetStyle: TCADBrushStyle; override;
    procedure SetStyle(const Value: TCADBrushStyle); override;
  public
    constructor Create;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
  end;

  {: A snapshot of pen and brush, for save/restore around a draw. }
  TCADGraphicsState = record
    PenColor: TCADColor;
    PenWidth: Integer;
    PenStyle: TCADPenStyle;
    PenMode: TCADPenMode;
    PenLineWeightMM: Double;
    BrushColor: TCADColor;
    BrushStyle: TCADBrushStyle;
  end;

  {: Platform-neutral description of a font. The fields follow the
     Windows LOGFONT structure because that is what CADSys has always
     stored; backends use what they can. Height is in pixels, a
     negative value meaning character height (LOGFONT convention).
     Escapement is in tenths of a degree, counter-clockwise. }
  TCADFontSpec = record
    FaceName: string;
    Height: Integer;
    Width: Integer;
    Escapement: Integer;
    Orientation: Integer;
    Weight: Integer;
    Italic: Boolean;
    Underline: Boolean;
    StrikeOut: Boolean;
    CharSet: Byte;
    OutPrecision: Byte;
    ClipPrecision: Byte;
    Quality: Byte;
    PitchAndFamily: Byte;
    class function Default: TCADFontSpec; static;
    class function Same(const A, B: TCADFontSpec): Boolean; static;
  end;

  {: A picture in a platform-neutral form: the bytes of an encoded image
     plus the pixel size read out of them (PNG and BMP headers are
     understood). A backend decodes the bytes once and parks the result
     in the cache slot, so a repaint does not decode again.

     This is what <See Class=TBitmap2D> holds and what the JSON format
     stores, base64 encoded - no VCL TBitmap anywhere in between. }
  TCADImage = class(TObject)
  private
    fData: TBytes;
    fWidth: Integer;
    fHeight: Integer;
    fGeneration: Cardinal;
    fCache: TObject;
    fCacheOwner: TObject;
    fCacheGeneration: Cardinal;
    procedure DropCache;
    procedure ReadSize;
  public
    constructor Create;
    destructor Destroy; override;
    {: Copies the bytes and the size of another image. }
    procedure Assign(const Source: TCADImage);
    {: Forgets the picture. }
    procedure Clear;
    {: Copies AData in. The pixel size is read from the image header. }
    procedure SetData(const AData: TBytes); overload;
    {: The same, when the caller already knows the size. }
    procedure SetData(const AData: TBytes;
      const AWidth, AHeight: Integer); overload;
    {: Reads the rest of Stream as the encoded image. }
    procedure LoadFromStream(const Stream: TStream);
    {: Writes the encoded image to Stream. }
    procedure SaveToStream(const Stream: TStream);
    function IsEmpty: Boolean;
    {: The decoded object a backend left here, or nil when it has to
       decode again - because nothing is cached, the bytes changed, or a
       different backend owns the slot. AOwner is the backend. }
    function CacheFor(const AOwner: TObject): TObject;
    {: Parks ACache here and takes ownership of it. }
    procedure SetCache(const AOwner: TObject; const ACache: TObject);
    {: The encoded bytes. }
    property Data: TBytes read fData;
    property Width: Integer read fWidth;
    property Height: Integer read fHeight;
    {: Bumped whenever the bytes change, so a cache can tell. }
    property Generation: Cardinal read fGeneration;
  end;

  PCADPoints = ^TCADPoints;
  TCADPoints = array[0..0] of TPoint;

  { : One hatch line, in device coordinates. }
  TCADHatchSegment = record
    P1, P2: TPoint;
  end;

  TCADHatchSegments = array of TCADHatchSegment;

  {: Abstract drawing surface. Coordinates are device pixels with the
     origin at the top-left corner, as on a VCL canvas. }
  TCADGraphics = class(TObject)
  private
    fPen: TCADPen;
    fBrush: TCADBrush;
    fBlendBackground: TCADColor;
    fPixelsPerMM: Double;
  protected
    function CreatePen: TCADPen; virtual; abstract;
    function CreateBrush: TCADBrush; virtual; abstract;
    function GetFontColor: TCADColor; virtual; abstract;
    procedure SetFontColor(const Value: TCADColor); virtual; abstract;
    function GetTransparent: Boolean; virtual; abstract;
    procedure SetTransparent(const Value: Boolean); virtual; abstract;
    function GetClipRect: TRect; virtual; abstract;
    procedure SetBlendBackground(const Value: TCADColor); virtual;

    { : The filled primitives as the backend draws them, with whatever
      the backend makes of the current brush.

      The public Polygon, Rectangle, Ellipse and FillRect are wrappers
      that peel off the hatch styles first - see
      <See Method=TCADGraphics@HatchPolygon>. A backend implements
      these and never sees a hatch style. }
    procedure DoPolygon(const Pts: Pointer; const Count: Integer);
      virtual; abstract;
    procedure DoRectangle(const X1, Y1, X2, Y2: Integer); virtual; abstract;
    procedure DoEllipse(const X1, Y1, X2, Y2: Integer); virtual; abstract;
    procedure DoFillRect(const R: TRect); virtual; abstract;

    { : True when the current brush asks for hatch lines. }
    function Hatching: Boolean;
    { : Outlines the polygon with the pen and draws the hatch lines in
      the brush colour.

      No backend hatches for us, and no two would agree if they did:
      GDI has eight hatch brushes, TTMSFNCGraphics has none at all, and
      an FMX bitmap brush would tile at whatever the device scale
      happened to be. Drawing the lines ourselves is the only way the
      same drawing comes out the same on all three.

      The gaps are left alone rather than painted with a background
      colour, which is where this departs from an opaque GDI hatch: the
      drawing layer has no background colour to paint them with. }
    procedure HatchPolygon(const Pts: Pointer; const Count: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    function SaveState: TCADGraphicsState;
    procedure RestoreState(const State: TCADGraphicsState);

    procedure MoveTo(const X, Y: Integer); virtual; abstract;
    procedure LineTo(const X, Y: Integer); virtual; abstract;
    {: Pts points to Count TPoint values. }
    procedure Polyline(const Pts: Pointer; const Count: Integer); overload; virtual; abstract;
    procedure Polyline(const Pts: array of TPoint); overload;
    {: Closed, filled with the brush and outlined with the pen. }
    procedure Polygon(const Pts: Pointer; const Count: Integer); overload;
    procedure Polygon(const Pts: array of TPoint); overload;
    {: Outlined with the pen, filled with the brush. X2/Y2 are exclusive,
       as in GDI. }
    procedure Rectangle(const X1, Y1, X2, Y2: Integer);
    procedure Ellipse(const X1, Y1, X2, Y2: Integer);
    {: Filled with the brush, no outline. }
    procedure FillRect(const R: TRect);

    {: Makes Font the font used by DrawText until <See Method=ResetFont>. }
    procedure SelectFont(const Font: TCADFontSpec); virtual; abstract;
    procedure ResetFont; virtual; abstract;
    {: Draws Text in R using CAD_DT_ flags. With CAD_DT_CALCRECT nothing is
       drawn and R is resized to fit the text. Returns the text height. }
    function DrawText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer; virtual; abstract;

    {: Stretches a backend-specific image object (a TGraphic for the VCL
       backend) into Dest. CopyMode is a raster operation code; backends
       that do not support it draw a plain copy. }
    procedure DrawImage(const Dest: TRect; const Image: TCADImage;
      const CopyMode: LongInt); virtual; abstract;

    procedure Lock; virtual;
    procedure Unlock; virtual;

    property Pen: TCADPen read fPen;
    property Brush: TCADBrush read fBrush;
    {: The colour a backend that cannot blend flattens translucent
       colours against - normally the background of the surface being
       drawn on. Default opaque white. }
    property BlendBackground: TCADColor read fBlendBackground
      write SetBlendBackground;
    property FontColor: TCADColor read GetFontColor write SetFontColor;
    {: When True, text is drawn without filling its background. }
    property Transparent: Boolean read GetTransparent write SetTransparent;
    property ClipRect: TRect read GetClipRect;
    {: How many device pixels make a millimetre on this surface, or 0
       for "not known".

       Zero is the default and means the whole library behaves as it did
       before: pen widths and hatch spacing are pixel figures and a
       pixel is whatever the device says. That is right for a screen,
       where nobody measures the picture with a ruler.

       It is wrong for paper. At 600 dpi a pixel is a twenty-fourth of a
       millimetre, so a one-pixel line is invisible and eight-pixel
       hatching is a solid black fill. Whoever draws on a physical
       device sets this - VCL.FNCCS4Print.CADDrawPage does, for the
       duration of one page - and then LineWeightMM and the millimetre
       hatch figures start to mean something.

       It is not a scale factor for coordinates. The geometry is
       already correct; this is only for the things that have a
       physical size of their own. }
    property PixelsPerMM: Double read fPixelsPerMM write fPixelsPerMM;
  end;

{: Builds a colour from its components. }
function CADColor(const A, R, G, B: Byte): TCADColor;
{: The alpha channel of Color: $FF opaque, $00 fully transparent. }
function CADColorAlpha(const Color: TCADColor): Byte;
{: Color with its alpha channel replaced. }
function CADColorSetAlpha(const Color: TCADColor; const Alpha: Byte): TCADColor;
{: True when the colour is fully opaque, which is the fast path in every
   backend. }
function CADColorIsOpaque(const Color: TCADColor): Boolean;
{: Converts a VCL-style $00BBGGRR value to an opaque colour.

   A framework system colour - clBtnFace and its kind, which are negative -
   is resolved through <See Var=CADResolveSystemColor> first. The VCL
   backend installs Vcl.Graphics.ColorToRGB there when it is linked in;
   with nothing installed a system colour comes out black, as it did
   before the hook existed. }
function TColorToCADColor(const Color: System.UITypes.TColor): TCADColor;
{: Converts back to a VCL-style $00BBGGRR value, dropping the alpha. }
function CADColorToTColor(const Color: TCADColor): System.UITypes.TColor;
{: Flattens Fore onto the opaque colour Back using Fore's alpha, for
   backends that cannot blend. }
function CADBlendColor(const Fore, Back: TCADColor): TCADColor;
{: The colour as $AARRGGBB, which is what FMX and FNC call an alpha
   colour. Kept as a name for backends to use. }
function CADColorToARGB(const Color: TCADColor): Cardinal;

{ : The brush styles that are drawn as hatch lines rather than as a fill. }
const
  CADHatchStyles = [cbsHorizontal, cbsVertical, cbsFDiagonal, cbsBDiagonal,
    cbsCross, cbsDiagCross];

var
  { : Device pixels between hatch lines.

    Eight, because that is what GDI's hatch brushes use - a drawing
    should not change density when it moves between backends. A
    variable rather than a constant so a high-DPI application can open
    it up. }
  CADHatchSpacing: Integer = 8;

  { : Refuse to hatch a shape that would need more lines than this.

    A guard, not a policy: with a small spacing and a large shape the
    line count is unbounded, and a CAD drawing can legitimately be
    zoomed until one polygon covers a wall. Above the limit the shape
    is left unfilled rather than freezing the repaint. }
  CADHatchMaxLines: Integer = 4096;

  { : Millimetres between hatch lines on a surface that knows its
    physical scale - see <See Property=TCADGraphics@PixelsPerMM>.

    Two, because that is roughly what the eight-pixel screen figure
    comes to at 96 dpi, so a drawing printed and a drawing on screen
    look like the same drawing. Ignored where PixelsPerMM is 0. }
  CADHatchSpacingMM: Double = 2.0;

  { : The weight of a hatch line itself, in millimetres, on a surface
    that knows its physical scale. A thin pen: hatching is texture, and
    it should not read as heavily as the outline it fills. }
  CADHatchLineWeightMM: Double = 0.18;

{ : The hatch lines for a polygon, in device coordinates.

  Pure geometry: no canvas, no backend, no state. That is the point -
  it means hatching is a property of the library rather than of
  whichever canvas the drawing landed on, and it means the awkward
  cases (concave, self-intersecting, a shape clipped to a sliver) can
  be tested without a screen.

  The lines are laid on a grid anchored at the origin rather than at
  the shape, so two shapes that touch have hatching that lines up -
  which is what makes a hatched CAD drawing look deliberate rather
  than assembled. }
function CADHatchLines(const APoly: array of TPoint;
  const AStyle: TCADBrushStyle; const ASpacing: Integer = 0)
  : TCADHatchSegments;

implementation

{ The four directions a hatch line can run, as the angle the line
  itself makes, measured with Y pointing down the screen. GDI's names
  are worth keeping straight: HS_FDIAGONAL runs downward left to
  right ("\"), HS_BDIAGONAL upward ("/"). }
const
  HatchAngleHorz = 0.0;
  HatchAngleVert = Pi / 2;
  HatchAngleFDiag = Pi / 4;
  HatchAngleBDiag = -Pi / 4;

function CADHatchLines(const APoly: array of TPoint;
  const AStyle: TCADBrushStyle; const ASpacing: Integer): TCADHatchSegments;
var
  Count: Integer;
  Spacing: Integer;

  { One family of parallel lines at AAngle.

    The whole trick is to rotate the polygon by -AAngle, which turns
    the hatch lines into horizontal scanlines, do the easy thing, and
    rotate the resulting segments back. One routine then serves all
    four directions, and the two diagonals are not special cases with
    their own arithmetic to get wrong. }
  procedure OneDirection(const AAngle: Double);
  var
    SinA, CosA: Double;
    RotX, RotY, Xs: array of Double;
    N, Cont, Next, Line, First, Last, Hit, I, J: Integer;
    MinY, MaxY, Y, Tmp: Double;

    function Back(const AX, AY: Double): TPoint;
    begin
      Result.X := Round(AX * CosA - AY * SinA);
      Result.Y := Round(AX * SinA + AY * CosA);
    end;

  begin
    N := Length(APoly);
    if N < 3 then
      Exit;
    SinA := Sin(AAngle);
    CosA := Cos(AAngle);
    SetLength(RotX, N);
    SetLength(RotY, N);
    SetLength(Xs, N);
    for Cont := 0 to N - 1 do
    begin
      RotX[Cont] := APoly[Cont].X * CosA + APoly[Cont].Y * SinA;
      RotY[Cont] := -APoly[Cont].X * SinA + APoly[Cont].Y * CosA;
    end;

    MinY := RotY[0];
    MaxY := RotY[0];
    for Cont := 1 to N - 1 do
    begin
      if RotY[Cont] < MinY then
        MinY := RotY[Cont];
      if RotY[Cont] > MaxY then
        MaxY := RotY[Cont];
    end;

    First := Ceil(MinY / Spacing);
    Last := Floor(MaxY / Spacing);
    if Last - First > CADHatchMaxLines then
      Exit;

    for Line := First to Last do
    begin
      Y := Line * Spacing;
      Hit := 0;
      { Half-open on purpose: an edge counts at its top end and not at
        its bottom, so a vertex shared by two edges is crossed once and
        the parity below stays right. }
      for Cont := 0 to N - 1 do
      begin
        Next := (Cont + 1) mod N;
        if ((RotY[Cont] <= Y) and (RotY[Next] > Y)) or
          ((RotY[Next] <= Y) and (RotY[Cont] > Y)) then
        begin
          Xs[Hit] := RotX[Cont] + (Y - RotY[Cont]) *
            (RotX[Next] - RotX[Cont]) / (RotY[Next] - RotY[Cont]);
          Inc(Hit);
        end;
      end;
      if Hit < 2 then
        Continue;

      { Insertion sort: Hit is the number of times this line crosses
        the outline, which is 2 for anything convex and rarely more
        than a handful otherwise. }
      for I := 1 to Hit - 1 do
      begin
        Tmp := Xs[I];
        J := I - 1;
        while (J >= 0) and (Xs[J] > Tmp) do
        begin
          Xs[J + 1] := Xs[J];
          Dec(J);
        end;
        Xs[J + 1] := Tmp;
      end;

      { Even-odd: inside runs from the first crossing to the second,
        the third to the fourth, and so on. This is what makes a
        concave or self-intersecting shape come out right for free. }
      I := 0;
      while I + 1 < Hit do
      begin
        if Xs[I + 1] - Xs[I] >= 0.5 then
        begin
          if Count = Length(Result) then
            SetLength(Result, Count + 64);
          Result[Count].P1 := Back(Xs[I], Y);
          Result[Count].P2 := Back(Xs[I + 1], Y);
          Inc(Count);
        end;
        Inc(I, 2);
      end;
    end;
  end;

begin
  { A caller with a physical surface passes the spacing it wants;
    everyone else gets the pixel figure. Clamped here rather than
    by writing back to the global, which two threads could race on. }
  if ASpacing > 0 then
    Spacing := ASpacing
  else
    Spacing := CADHatchSpacing;
  if Spacing < 1 then
    Spacing := 1;
  Result := nil;
  Count := 0;
  case AStyle of
    cbsHorizontal:
      OneDirection(HatchAngleHorz);
    cbsVertical:
      OneDirection(HatchAngleVert);
    cbsFDiagonal:
      OneDirection(HatchAngleFDiag);
    cbsBDiagonal:
      OneDirection(HatchAngleBDiag);
    cbsCross:
      begin
        OneDirection(HatchAngleHorz);
        OneDirection(HatchAngleVert);
      end;
    cbsDiagCross:
      begin
        OneDirection(HatchAngleFDiag);
        OneDirection(HatchAngleBDiag);
      end;
  end;
  SetLength(Result, Count);
end;

function CADColor(const A, R, G, B: Byte): TCADColor;
begin
  Result := TCADColor((Cardinal(A) shl 24) or (Cardinal(R) shl 16) or
    (Cardinal(G) shl 8) or Cardinal(B));
end;

function CADColorAlpha(const Color: TCADColor): Byte;
begin
  Result := Byte(Cardinal(Color) shr 24);
end;

function CADColorSetAlpha(const Color: TCADColor; const Alpha: Byte): TCADColor;
begin
  Result := TCADColor((Cardinal(Color) and $00FFFFFF) or
    (Cardinal(Alpha) shl 24));
end;

function CADColorIsOpaque(const Color: TCADColor): Boolean;
begin
  Result := CADColorAlpha(Color) = $FF;
end;

function TColorToCADColor(const Color: System.UITypes.TColor): TCADColor;
var
  C: Cardinal;
  TmpColor: System.UITypes.TColor;
begin
  TmpColor := Color;
  if (TmpColor < 0) and Assigned(CADResolveSystemColor) then
    TmpColor := CADResolveSystemColor(TmpColor);
  if TmpColor < 0 then
    C := 0
  else
    C := Cardinal(TmpColor);
  { TColor is $00BBGGRR, this is $AARRGGBB. }
  Result := TCADColor($FF000000 or ((C and $000000FF) shl 16) or
    (C and $0000FF00) or ((C and $00FF0000) shr 16));
end;

function CADColorToTColor(const Color: TCADColor): System.UITypes.TColor;
var
  C: Cardinal;
begin
  C := Cardinal(Color);
  Result := System.UITypes.TColor(((C and $00FF0000) shr 16) or
    (C and $0000FF00) or ((C and $000000FF) shl 16));
end;

function CADBlendColor(const Fore, Back: TCADColor): TCADColor;
var
  A, InvA: Integer;
  FC, BC: Cardinal;
begin
  A := CADColorAlpha(Fore);
  if A = $FF then
    Exit(Fore);
  if A = 0 then
    Exit(CADColorSetAlpha(Back, $FF));
  InvA := $FF - A;
  { Everything is masked to a byte first, so the arithmetic is small - the
    Integer casts are only there to keep the Cardinal channels from
    widening the expression and drawing W1024. }
  FC := Cardinal(Fore);
  BC := Cardinal(Back);
  Result := CADColor($FF,
    (Integer((FC shr 16) and $FF) * A +
     Integer((BC shr 16) and $FF) * InvA) div $FF,
    (Integer((FC shr 8) and $FF) * A +
     Integer((BC shr 8) and $FF) * InvA) div $FF,
    (Integer(FC and $FF) * A + Integer(BC and $FF) * InvA) div $FF);
end;

function CADColorToARGB(const Color: TCADColor): Cardinal;
begin
  Result := Cardinal(Color);
end;

{ TCADPen }

procedure TCADPen.Assign(const Source: TCADPen);
begin
  if (Source = nil) or (Source = Self) then
    Exit;
  Color := Source.Color;
  Width := Source.Width;
  Style := Source.Style;
  Mode := Source.Mode;
  { Last, so that a pen carrying both a pixel width and a millimetre
    weight lands on the millimetres wherever the device knows what one
    is. On a screen this line does nothing at all. }
  LineWeightMM := Source.LineWeightMM;
end;

procedure TCADPen.SetLineWeightMM(const Value: Double);
var
  TmpWidth: Integer;
begin
  fLineWeightMM := Value;
  if (Value <= 0) or (fOwnerGraphics = nil) or
    (fOwnerGraphics.PixelsPerMM <= 0) then
    Exit;
  { Never thinner than one pixel: a weight that rounds to nothing would
    disappear rather than come out fine, and a line nobody can see is
    not a thin line, it is a missing one. }
  TmpWidth := Round(Value * fOwnerGraphics.PixelsPerMM);
  if TmpWidth < 1 then
    TmpWidth := 1;
  Width := TmpWidth;
end;

{ TCADBrush }

procedure TCADBrush.Assign(const Source: TCADBrush);
begin
  if (Source = nil) or (Source = Self) then
    Exit;
  Color := Source.Color;
  Style := Source.Style;
end;

{ TCADFontSpec }

class function TCADFontSpec.Default: TCADFontSpec;
begin
  Result.FaceName := 'Small Fonts';
  Result.Height := -11;
  Result.Width := 0;
  Result.Escapement := 0;
  Result.Orientation := 0;
  Result.Weight := 400;
  Result.Italic := False;
  Result.Underline := False;
  Result.StrikeOut := False;
  Result.CharSet := 1; // DEFAULT_CHARSET
  Result.OutPrecision := 0;
  Result.ClipPrecision := 0;
  Result.Quality := 0;
  Result.PitchAndFamily := 0;
end;

class function TCADFontSpec.Same(const A, B: TCADFontSpec): Boolean;
begin
  Result := (A.Height = B.Height) and (A.Width = B.Width) and
    (A.Escapement = B.Escapement) and (A.Orientation = B.Orientation) and
    (A.Weight = B.Weight) and (A.Italic = B.Italic) and
    (A.Underline = B.Underline) and (A.StrikeOut = B.StrikeOut) and
    (A.CharSet = B.CharSet) and (A.OutPrecision = B.OutPrecision) and
    (A.ClipPrecision = B.ClipPrecision) and (A.Quality = B.Quality) and
    (A.PitchAndFamily = B.PitchAndFamily) and (A.FaceName = B.FaceName);
end;

{ TCADImage }

constructor TCADImage.Create;
begin
  inherited Create;
  fGeneration := 1;
end;

destructor TCADImage.Destroy;
begin
  DropCache;
  inherited Destroy;
end;

procedure TCADImage.DropCache;
begin
  if fCache <> nil then
  begin
    fCache.Free;
    fCache := nil;
  end;
  fCacheOwner := nil;
  fCacheGeneration := 0;
end;

procedure TCADImage.ReadSize;

  function BE32(const Idx: Integer): Integer;
  begin
    Result := (Integer(fData[Idx]) shl 24) or (Integer(fData[Idx + 1]) shl 16)
      or (Integer(fData[Idx + 2]) shl 8) or Integer(fData[Idx + 3]);
  end;

  function LE32(const Idx: Integer): Integer;
  begin
    Result := Integer(fData[Idx]) or (Integer(fData[Idx + 1]) shl 8) or
      (Integer(fData[Idx + 2]) shl 16) or (Integer(fData[Idx + 3]) shl 24);
  end;

begin
  fWidth := 0;
  fHeight := 0;
  { PNG: the signature, then IHDR with the size as two big-endian longs. }
  if (Length(fData) >= 24) and (fData[0] = $89) and (fData[1] = Ord('P')) and
    (fData[2] = Ord('N')) and (fData[3] = Ord('G')) then
  begin
    fWidth := BE32(16);
    fHeight := BE32(20);
    Exit;
  end;
  { BMP: 'BM', then the info header. A negative height means top-down. }
  if (Length(fData) >= 26) and (fData[0] = Ord('B')) and
    (fData[1] = Ord('M')) then
  begin
    fWidth := LE32(18);
    fHeight := Abs(LE32(22));
  end;
end;

procedure TCADImage.Assign(const Source: TCADImage);
begin
  if (Source = nil) or (Source = Self) then
    Exit;
  SetData(Source.fData, Source.fWidth, Source.fHeight);
end;

procedure TCADImage.Clear;
begin
  SetLength(fData, 0);
  fWidth := 0;
  fHeight := 0;
  Inc(fGeneration);
  DropCache;
end;

procedure TCADImage.SetData(const AData: TBytes);
begin
  SetData(AData, -1, -1);
end;

procedure TCADImage.SetData(const AData: TBytes;
  const AWidth, AHeight: Integer);
begin
  SetLength(fData, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], fData[0], Length(AData));
  if (AWidth >= 0) and (AHeight >= 0) then
  begin
    fWidth := AWidth;
    fHeight := AHeight;
  end
  else
    ReadSize;
  Inc(fGeneration);
  DropCache;
end;

procedure TCADImage.LoadFromStream(const Stream: TStream);
var
  TmpBytes: TBytes;
  TmpCount: Integer;
begin
  TmpCount := Stream.Size - Stream.Position;
  SetLength(TmpBytes, TmpCount);
  if TmpCount > 0 then
    Stream.ReadBuffer(TmpBytes[0], TmpCount);
  SetData(TmpBytes);
end;

procedure TCADImage.SaveToStream(const Stream: TStream);
begin
  if Length(fData) > 0 then
    Stream.WriteBuffer(fData[0], Length(fData));
end;

function TCADImage.IsEmpty: Boolean;
begin
  Result := Length(fData) = 0;
end;

function TCADImage.CacheFor(const AOwner: TObject): TObject;
begin
  if (fCache <> nil) and (fCacheOwner = AOwner) and
    (fCacheGeneration = fGeneration) then
    Result := fCache
  else
    Result := nil;
end;

procedure TCADImage.SetCache(const AOwner: TObject; const ACache: TObject);
begin
  DropCache;
  fCache := ACache;
  fCacheOwner := AOwner;
  fCacheGeneration := fGeneration;
end;

{ TCADSimplePen }

constructor TCADSimplePen.Create;
begin
  inherited Create;
  fColor := cadclBlack;
  fWidth := 1;
  fStyle := cpsSolid;
  fMode := cpmCopy;
end;

procedure TCADSimplePen.Changed;
begin
  if Assigned(fOnChange) then
    fOnChange(Self);
end;

function TCADSimplePen.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADSimplePen.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  Changed;
end;

function TCADSimplePen.GetWidth: Integer;
begin
  Result := fWidth;
end;

procedure TCADSimplePen.SetWidth(const Value: Integer);
begin
  fWidth := Value;
  Changed;
end;

function TCADSimplePen.GetStyle: TCADPenStyle;
begin
  Result := fStyle;
end;

procedure TCADSimplePen.SetStyle(const Value: TCADPenStyle);
begin
  fStyle := Value;
  Changed;
end;

function TCADSimplePen.GetMode: TCADPenMode;
begin
  Result := fMode;
end;

procedure TCADSimplePen.SetMode(const Value: TCADPenMode);
begin
  fMode := Value;
  Changed;
end;

{ TCADSimpleBrush }

constructor TCADSimpleBrush.Create;
begin
  inherited Create;
  fColor := cadclWhite;
  fStyle := cbsSolid;
end;

procedure TCADSimpleBrush.Changed;
begin
  if Assigned(fOnChange) then
    fOnChange(Self);
end;

function TCADSimpleBrush.GetColor: TCADColor;
begin
  Result := fColor;
end;

procedure TCADSimpleBrush.SetColor(const Value: TCADColor);
begin
  fColor := Value;
  Changed;
end;

function TCADSimpleBrush.GetStyle: TCADBrushStyle;
begin
  Result := fStyle;
end;

procedure TCADSimpleBrush.SetStyle(const Value: TCADBrushStyle);
begin
  fStyle := Value;
  Changed;
end;

{ TCADGraphics }

constructor TCADGraphics.Create;
begin
  inherited Create;
  fBlendBackground := cadclWhite;
  fPixelsPerMM := 0;
  fPen := CreatePen;
  fBrush := CreateBrush;
  { So a pen can convert its own millimetres. Only the graphics' own
    pen gets this; a layer's stored pen has no surface and no business
    guessing at one. }
  if fPen <> nil then
    fPen.fOwnerGraphics := Self;
end;

destructor TCADGraphics.Destroy;
begin
  fPen.Free;
  fBrush.Free;
  inherited Destroy;
end;

function TCADGraphics.SaveState: TCADGraphicsState;
begin
  Result.PenColor := fPen.Color;
  Result.PenWidth := fPen.Width;
  Result.PenStyle := fPen.Style;
  Result.PenMode := fPen.Mode;
  Result.PenLineWeightMM := fPen.LineWeightMM;
  Result.BrushColor := fBrush.Color;
  Result.BrushStyle := fBrush.Style;
end;

procedure TCADGraphics.RestoreState(const State: TCADGraphicsState);
begin
  fPen.Color := State.PenColor;
  fPen.Width := State.PenWidth;
  fPen.Style := State.PenStyle;
  fPen.Mode := State.PenMode;
  { The weight first, then the width, so the width that was actually in
    force is what comes back - restoring a weight afterwards would
    recompute it and could land a pixel away. }
  fPen.fLineWeightMM := State.PenLineWeightMM;
  fPen.Width := State.PenWidth;
  fBrush.Color := State.BrushColor;
  fBrush.Style := State.BrushStyle;
end;

procedure TCADGraphics.Polyline(const Pts: array of TPoint);
begin
  if Length(Pts) > 0 then
    Polyline(@Pts[0], Length(Pts));
end;

function TCADGraphics.Hatching: Boolean;
begin
  Result := (Brush <> nil) and (Brush.Style in CADHatchStyles) and
    (CADColorAlpha(Brush.Color) > 0);
end;

procedure TCADGraphics.HatchPolygon(const Pts: Pointer; const Count: Integer);
var
  Poly: array of TPoint;
  Segs: TCADHatchSegments;
  State: TCADGraphicsState;
  Cont: Integer;
begin
  SetLength(Poly, Count);
  for Cont := 0 to Count - 1 do
    Poly[Cont] := PCADPoints(Pts)^[Cont];

  { On a surface that knows its physical scale the spacing is a
    millimetre figure, so a hatch keeps its density on paper instead of
    closing up into a solid fill at the printer's resolution. }
  if fPixelsPerMM > 0 then
    Segs := CADHatchLines(Poly, Brush.Style,
      Round(CADHatchSpacingMM * fPixelsPerMM))
  else
    Segs := CADHatchLines(Poly, Brush.Style);

  State := SaveState;
  try
    { The outline first, with the caller's pen, and no fill under it. }
    Brush.Style := cbsClear;
    DoPolygon(Pts, Count);

    if Length(Segs) = 0 then
      Exit;
    { Then the lines, in the brush colour. One pixel and solid: a hatch
      is a fill, and a fill does not inherit the outline's dashes or
      its width. }
    Pen.Color := Brush.Color;
    Pen.Style := cpsSolid;
    Pen.LineWeightMM := 0;
    Pen.Width := 1;
    if fPixelsPerMM > 0 then
      Pen.LineWeightMM := CADHatchLineWeightMM;
    for Cont := 0 to High(Segs) do
    begin
      MoveTo(Segs[Cont].P1.X, Segs[Cont].P1.Y);
      LineTo(Segs[Cont].P2.X, Segs[Cont].P2.Y);
    end;
  finally
    RestoreState(State);
  end;
end;

procedure TCADGraphics.Polygon(const Pts: Pointer; const Count: Integer);
begin
  if (Pts = nil) or (Count <= 0) then
    Exit;
  if Hatching and (Count >= 3) then
    HatchPolygon(Pts, Count)
  else
    DoPolygon(Pts, Count);
end;

procedure TCADGraphics.Rectangle(const X1, Y1, X2, Y2: Integer);
var
  Poly: array [0 .. 3] of TPoint;
begin
  if not Hatching then
  begin
    DoRectangle(X1, Y1, X2, Y2);
    Exit;
  end;
  { X2 and Y2 are exclusive, as in GDI, so the hatched polygon stops one
    short of them - otherwise a hatched rectangle would be a pixel
    wider than a solid one. }
  Poly[0] := Point(X1, Y1);
  Poly[1] := Point(X2 - 1, Y1);
  Poly[2] := Point(X2 - 1, Y2 - 1);
  Poly[3] := Point(X1, Y2 - 1);
  HatchPolygon(@Poly[0], 4);
end;

procedure TCADGraphics.Ellipse(const X1, Y1, X2, Y2: Integer);
var
  Poly: array of TPoint;
  Cont, Steps: Integer;
  CX, CY, RX, RY, Step: Double;
begin
  if not Hatching then
  begin
    DoEllipse(X1, Y1, X2, Y2);
    Exit;
  end;
  { Flattened to a polygon, because the hatcher works on outlines and
    an ellipse is the only filled primitive that is not one already.
    The step count follows the size: enough that the facets are under
    a pixel or so, capped so a hugely zoomed ellipse does not take the
    repaint with it. }
  RX := Abs(X2 - X1) / 2;
  RY := Abs(Y2 - Y1) / 2;
  CX := (X1 + X2) / 2;
  CY := (Y1 + Y2) / 2;
  Steps := Round(Max(RX, RY));
  if Steps < 16 then
    Steps := 16;
  if Steps > 360 then
    Steps := 360;
  SetLength(Poly, Steps);
  Step := 2 * Pi / Steps;
  for Cont := 0 to Steps - 1 do
    Poly[Cont] := Point(Round(CX + RX * Cos(Cont * Step)),
      Round(CY + RY * Sin(Cont * Step)));
  HatchPolygon(@Poly[0], Steps);
end;

procedure TCADGraphics.FillRect(const R: TRect);
var
  State: TCADGraphicsState;
begin
  if not Hatching then
  begin
    DoFillRect(R);
    Exit;
  end;
  { FillRect draws no outline, so the pen is taken out of the way and
    Rectangle does the rest. }
  State := SaveState;
  try
    Pen.Style := cpsClear;
    Rectangle(R.Left, R.Top, R.Right, R.Bottom);
  finally
    RestoreState(State);
  end;
end;

procedure TCADGraphics.Polygon(const Pts: array of TPoint);
begin
  if Length(Pts) > 0 then
    Polygon(@Pts[0], Length(Pts));
end;

procedure TCADGraphics.SetBlendBackground(const Value: TCADColor);
begin
  fBlendBackground := Value;
end;

procedure TCADGraphics.Lock;
begin
end;

procedure TCADGraphics.Unlock;
begin
end;

end.
