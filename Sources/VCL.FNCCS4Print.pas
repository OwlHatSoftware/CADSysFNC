{ : The page model: what a drawing looks like on paper, with no idea
  what paper is.

  Nothing in here knows about a printer, a preview control, the VCL or
  FMX. It answers three questions - how big is the page, which part of
  the drawing lands on it, and how do millimetres become pixels on this
  device - and then draws through a <See Class=TDecorativeCanvas> like
  everything else in the library.

  That is deliberate and it is the whole design:

    the preview control and the printer call the same CADDrawPage.

  Any arrangement where the preview is drawn by different code will
  drift from what comes out of the printer, and the drift is only
  visible on paper, which is the worst place to find it.

  THE UNITS PROBLEM

  Everything else in the library measures in device pixels - pen
  widths, hatch spacing, the pick aperture. A pixel is about a quarter
  of a millimetre on screen and a twenty-fourth of one at 600 dpi, so a
  drawing printed with its screen figures comes out as hairlines and
  solid-black hatching. The page model therefore carries the device's
  pixels-per-millimetre, and CADDrawPage hands it to the drawing layer
  (TCADGraphics.PixelsPerMM) before it draws anything. Pens with a
  LineWeightMM and hatching then come out at a physical size; pens
  without one keep their pixel width, which is what every existing
  drawing has.

  A SETUP IS A VALUE

  TCADPageSetup is a record, like TCADViewSpec, and for the same
  reason: no identity, nothing to free, and it can sit inside a sheet
  later on without anyone owning it. It holds a TCADViewSpec, so the
  question "which part of the drawing, at what scale, with which
  layers" has one answer in this library rather than two. }
unit VCL.FNCCS4Print;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCADSys4, VCL.FNCCS4Views;

const
  { : Millimetres in an inch. Printers talk in dots per inch; everything
    here talks in millimetres. }
  CADMMPerInch = 25.4;

type
  { : Raised when a page setup cannot produce a page - a paper size of
    zero, a scale of zero, an empty drawing window. }
  ECADPageError = class(Exception);

  { : The standard paper sizes, portrait. pkCustom takes its size from
    the setup's CustomWidthMM and CustomHeightMM. }
  TCADPaperKind = (pkA5, pkA4, pkA3, pkA2, pkA1, pkA0, pkLetter, pkLegal,
    pkTabloid, pkCustom);

  { : Portrait or landscape.

    Spelled pgo rather than po because Vcl.Printers and FMX.Printer both
    declare a TPrinterOrientation with poPortrait and poLandscape in it,
    and any unit that prints has both in scope. Two enumerations with
    the same member names in one uses clause is an afternoon lost to a
    message that points at the wrong line. }
  TCADPageOrientation = (pgoPortrait, pgoLandscape);

  { : How the drawing is sized onto the paper.

    pfFitToPage works out the scale so the whole view fits one page.
    pfScale takes the scale as given and uses as many pages as that
    needs. }
  TCADPageFit = (pfFitToPage, pfScale);

  { : The unprinted border, in millimetres. }
  TCADPageMargins = record
    Left, Top, Right, Bottom: TRealType;
    { : The same margin on all four sides. }
    class function Uniform(const AMM: TRealType): TCADPageMargins; static;
    class function Sides(const ALeft, ATop, ARight, ABottom: TRealType)
      : TCADPageMargins; static;
    function Horizontal: TRealType;
    function Vertical: TRealType;
  end;

  { : What the surface being drawn on can do, in device pixels.

    X and Y are separate because a printer's are not always equal, and
    because keeping them separate costs nothing and getting it wrong
    costs a squashed drawing.

    OffsetXPx and OffsetYPx are where the paper's top-left corner sits
    in the canvas' coordinates. A printer canvas normally begins at the
    printable area rather than at the sheet, so for a printer they are
    negative - the sheet starts above and to the left of pixel zero. A
    preview that draws the whole sheet leaves them at zero. }
  TCADPageDevice = record
    PixelsPerMMX, PixelsPerMMY: TRealType;
    OffsetXPx, OffsetYPx: Integer;

    { : From a device's resolution in dots per inch. }
    class function FromDPI(const ADPIX, ADPIY: TRealType)
      : TCADPageDevice; static;
    { : From pixels per millimetre, the same both ways. }
    class function FromPixelsPerMM(const APixelsPerMM: TRealType)
      : TCADPageDevice; static;
    { : A device that renders APaperWidthMM x APaperHeightMM into a box
      AWidthPx x AHeightPx - what a preview control wants. The aspect is
      preserved and the result is centred, so a preview of a portrait
      sheet in a wide box has the sheet in the middle. }
    class function ToBox(const APaperWidthMM, APaperHeightMM: TRealType;
      const AWidthPx, AHeightPx: Integer): TCADPageDevice; static;

    function MMToPxX(const AMM: TRealType): Integer;
    function MMToPxY(const AMM: TRealType): Integer;
    { : The mean of the two axes - for anything with one figure to give,
      such as a line weight. }
    function PixelsPerMM: TRealType;
    { : The whole sheet as a device rectangle. }
    function PaperRect(const AWidthMM, AHeightMM: TRealType): TRect;
  end;

  { : A page setup: the paper, the scale, and the view it shows.

    A record on purpose - see the unit header. TCADPageSetup.Default
    gives A4 portrait, 10 mm margins, fitted to the page. }
  TCADPageSetup = record
    Paper: TCADPaperKind;
    { : Used only when Paper is pkCustom. Portrait, as the standard
      sizes are - Orientation is applied afterwards. }
    CustomWidthMM, CustomHeightMM: TRealType;
    Orientation: TCADPageOrientation;
    Margins: TCADPageMargins;
    Fit: TCADPageFit;
    { : Drawing units to one millimetre of paper, when Fit is pfScale.

      This is the scale as a draughtsman states it. A plan drawn in
      millimetres at 1:100 is 100 units per millimetre; the same plan
      drawn in metres at 1:100 is 0.1. }
    UnitsPerMM: TRealType;
    { : Which part of the drawing, and which layers.

      Only Window, AspectRatio, UseLayerOverride and HiddenLayers are
      read here; Name and DrawingFile are carried for whoever saves the
      setup. An empty Window means "the whole drawing", resolved
      against the component when the page is drawn - and that, not
      TCADViewSpec.Default's -100..100, is what Default leaves here. }
    View: TCADViewSpec;
    { : When False the view is stretched to fill the printable area.
      True is almost always what is wanted: a stretched CAD drawing is
      no longer to scale in either direction. }
    KeepAspect: Boolean;
    { : When True a drawing wider or taller than one page continues onto
      further pages. When False only the first page is produced. }
    Tiled: Boolean;

    class function Default: TCADPageSetup; static;

    { : The sheet, in millimetres, with Orientation applied. }
    procedure PaperSizeMM(out AWidth, AHeight: TRealType);
    { : The sheet less the margins. }
    procedure PrintableSizeMM(out AWidth, AHeight: TRealType);

    { : The window this setup actually prints: View.Window, or ACAD's
      whole extension when that is empty. }
    function EffectiveWindow(const ACAD: TFNCCADCmp2D): TRect2D;
    { : Drawing units per millimetre of paper, resolved - which for
      pfFitToPage means worked out from the window and the paper. }
    function EffectiveUnitsPerMM(const ACAD: TFNCCADCmp2D): TRealType;

    function PagesAcross(const ACAD: TFNCCADCmp2D): Integer;
    function PagesDown(const ACAD: TFNCCADCmp2D): Integer;
    function PageCount(const ACAD: TFNCCADCmp2D): Integer;

    { : The part of the drawing that lands on page AIndex, counted from
      zero, left to right and then top to bottom.

      For a fitted page that keeps its aspect this is the view grown to
      the paper's proportions about its own centre, so the drawing ends
      up in the middle of the sheet rather than in a corner. }
    function PageWindow(const ACAD: TFNCCADCmp2D;
      const AIndex: Integer): TRect2D;
  end;

{ : The sheet in millimetres, portrait, for a standard size. }
procedure CADPaperSizeMM(const AKind: TCADPaperKind;
  out AWidth, AHeight: TRealType);
{ : 'A4', 'Letter', 'Custom' - for a combo box. }
function CADPaperKindName(const AKind: TCADPaperKind): String;

{ : Draws one page of ACAD onto ACanvas.

  **This is the only routine that renders a page.** The preview control
  calls it and so does the printer; if a second one ever appears, the
  two pictures will differ and only paper will show it.

  ADevice says what the canvas is, ASetup says what to draw, AIndex
  says which page. The canvas is the caller's and is not freed.

  The drawing layer is told the device's pixels-per-millimetre for the
  duration, so line weights and hatching come out at a physical size,
  and it is put back afterwards - the canvas may well be the screen's. }
procedure CADDrawPage(const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup;
  const ADevice: TCADPageDevice; const AIndex: Integer;
  const ACanvas: TDecorativeCanvas; const ADrawMode: Cardinal = 0);

{ : The printable area of a page, in device pixels. Exposed because a
  preview wants to outline it and a printer wants to clip to it. }
function CADPrintableRectPx(const ASetup: TCADPageSetup;
  const ADevice: TCADPageDevice): TRect;

implementation

const
  { : The A series, portrait, in millimetres. }
  PaperMM: array [pkA5 .. pkTabloid] of array [0 .. 1] of TRealType =
    ((148, 210), (210, 297), (297, 420), (420, 594), (594, 841), (841, 1189),
    (215.9, 279.4), (215.9, 355.6), (279.4, 431.8));

  PaperNames: array [TCADPaperKind] of String = ('A5', 'A4', 'A3', 'A2', 'A1',
    'A0', 'Letter', 'Legal', 'Tabloid', 'Custom');

{ ==================================================================
  TCADPageMargins
  ================================================================== }

class function TCADPageMargins.Uniform(const AMM: TRealType): TCADPageMargins;
begin
  Result.Left := AMM;
  Result.Top := AMM;
  Result.Right := AMM;
  Result.Bottom := AMM;
end;

class function TCADPageMargins.Sides(const ALeft, ATop, ARight,
  ABottom: TRealType): TCADPageMargins;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
end;

function TCADPageMargins.Horizontal: TRealType;
begin
  Result := Left + Right;
end;

function TCADPageMargins.Vertical: TRealType;
begin
  Result := Top + Bottom;
end;

{ ==================================================================
  TCADPageDevice
  ================================================================== }

class function TCADPageDevice.FromDPI(const ADPIX, ADPIY: TRealType)
  : TCADPageDevice;
begin
  Result.PixelsPerMMX := ADPIX / CADMMPerInch;
  Result.PixelsPerMMY := ADPIY / CADMMPerInch;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
end;

class function TCADPageDevice.FromPixelsPerMM(const APixelsPerMM: TRealType)
  : TCADPageDevice;
begin
  Result.PixelsPerMMX := APixelsPerMM;
  Result.PixelsPerMMY := APixelsPerMM;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
end;

class function TCADPageDevice.ToBox(const APaperWidthMM,
  APaperHeightMM: TRealType; const AWidthPx, AHeightPx: Integer)
  : TCADPageDevice;
var
  TmpScale: TRealType;
begin
  { One scale for both axes: a preview of a sheet has to look like the
    sheet, and a box that is the wrong shape is the box's problem. }
  Result.PixelsPerMMX := 0;
  Result.PixelsPerMMY := 0;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
  if (APaperWidthMM <= 0) or (APaperHeightMM <= 0) or (AWidthPx <= 0) or
    (AHeightPx <= 0) then
    Exit;
  TmpScale := MinValue([AWidthPx / APaperWidthMM, AHeightPx / APaperHeightMM]);
  Result.PixelsPerMMX := TmpScale;
  Result.PixelsPerMMY := TmpScale;
  Result.OffsetXPx := Round((AWidthPx - APaperWidthMM * TmpScale) / 2);
  Result.OffsetYPx := Round((AHeightPx - APaperHeightMM * TmpScale) / 2);
end;

function TCADPageDevice.MMToPxX(const AMM: TRealType): Integer;
begin
  Result := Round(AMM * PixelsPerMMX);
end;

function TCADPageDevice.MMToPxY(const AMM: TRealType): Integer;
begin
  Result := Round(AMM * PixelsPerMMY);
end;

function TCADPageDevice.PixelsPerMM: TRealType;
begin
  Result := (PixelsPerMMX + PixelsPerMMY) / 2;
end;

function TCADPageDevice.PaperRect(const AWidthMM, AHeightMM: TRealType): TRect;
begin
  Result.Left := OffsetXPx;
  Result.Top := OffsetYPx;
  Result.Right := OffsetXPx + MMToPxX(AWidthMM);
  Result.Bottom := OffsetYPx + MMToPxY(AHeightMM);
end;

{ ==================================================================
  TCADPageSetup
  ================================================================== }

class function TCADPageSetup.Default: TCADPageSetup;
begin
  Result.Paper := pkA4;
  Result.CustomWidthMM := 210;
  Result.CustomHeightMM := 297;
  Result.Orientation := pgoPortrait;
  Result.Margins := TCADPageMargins.Uniform(10);
  Result.Fit := pfFitToPage;
  Result.UnitsPerMM := 1;
  Result.View := TCADViewSpec.Default;
  { TCADViewSpec.Default hands back a -100..100 window. That is a
    sensible place for a *viewport* to open - it gives the user
    somewhere to draw - and it is the wrong thing for a page, where a
    setup nobody has pointed anywhere should print the drawing rather
    than an arbitrary square of empty paper around the origin.

    Emptied here rather than changed there: the two defaults answer
    different questions and only one of them is this unit's business.
    An empty window is what EffectiveWindow reads as "all of it". }
  Result.View.Window.Left := 0;
  Result.View.Window.Bottom := 0;
  Result.View.Window.Right := 0;
  Result.View.Window.Top := 0;
  Result.KeepAspect := True;
  Result.Tiled := False;
end;

procedure TCADPageSetup.PaperSizeMM(out AWidth, AHeight: TRealType);
var
  TmpSwap: TRealType;
begin
  if Paper = pkCustom then
  begin
    AWidth := CustomWidthMM;
    AHeight := CustomHeightMM;
  end
  else
  begin
    AWidth := PaperMM[Paper][0];
    AHeight := PaperMM[Paper][1];
  end;
  if Orientation = pgoLandscape then
  begin
    TmpSwap := AWidth;
    AWidth := AHeight;
    AHeight := TmpSwap;
  end;
end;

procedure TCADPageSetup.PrintableSizeMM(out AWidth, AHeight: TRealType);
begin
  PaperSizeMM(AWidth, AHeight);
  AWidth := AWidth - Margins.Horizontal;
  AHeight := AHeight - Margins.Vertical;
  if (AWidth <= 0) or (AHeight <= 0) then
    Raise ECADPageError.Create
      ('The margins leave no printable area on this paper size');
end;

function TCADPageSetup.EffectiveWindow(const ACAD: TFNCCADCmp2D): TRect2D;
begin
  Result := View.Window;
  if (Result.Right - Result.Left <= 0) or (Result.Top - Result.Bottom <= 0) then
  begin
    if ACAD = nil then
      Raise ECADPageError.Create
        ('The setup has no window and there is no drawing to take one from');
    Result := ACAD.DrawingExtension;
  end;
  if (Result.Right - Result.Left <= 0) or (Result.Top - Result.Bottom <= 0) then
    Raise ECADPageError.Create('The drawing is empty - there is nothing to fit');
end;

function TCADPageSetup.EffectiveUnitsPerMM(const ACAD: TFNCCADCmp2D)
  : TRealType;
var
  TmpW, TmpH, TmpPW, TmpPH: TRealType;
  TmpWin: TRect2D;
begin
  if Fit = pfScale then
  begin
    if UnitsPerMM <= 0 then
      Raise ECADPageError.Create('A page scale of zero units per millimetre');
    Result := UnitsPerMM;
    Exit;
  end;
  PrintableSizeMM(TmpPW, TmpPH);
  TmpWin := EffectiveWindow(ACAD);
  TmpW := TmpWin.Right - TmpWin.Left;
  TmpH := TmpWin.Top - TmpWin.Bottom;
  { Fitting means the larger of the two ratios: the axis that runs out
    of paper first is the one that sets the scale. }
  if KeepAspect then
    Result := MaxValue([TmpW / TmpPW, TmpH / TmpPH])
  else
    Result := TmpW / TmpPW;
end;

function TCADPageSetup.PagesAcross(const ACAD: TFNCCADCmp2D): Integer;
var
  TmpPW, TmpPH, TmpUPM: TRealType;
  TmpWin: TRect2D;
begin
  Result := 1;
  if (Fit = pfFitToPage) or not Tiled then
    Exit;
  PrintableSizeMM(TmpPW, TmpPH);
  TmpUPM := EffectiveUnitsPerMM(ACAD);
  TmpWin := EffectiveWindow(ACAD);
  Result := Ceil((TmpWin.Right - TmpWin.Left) / (TmpPW * TmpUPM) - 1E-9);
  if Result < 1 then
    Result := 1;
end;

function TCADPageSetup.PagesDown(const ACAD: TFNCCADCmp2D): Integer;
var
  TmpPW, TmpPH, TmpUPM: TRealType;
  TmpWin: TRect2D;
begin
  Result := 1;
  if (Fit = pfFitToPage) or not Tiled then
    Exit;
  PrintableSizeMM(TmpPW, TmpPH);
  TmpUPM := EffectiveUnitsPerMM(ACAD);
  TmpWin := EffectiveWindow(ACAD);
  Result := Ceil((TmpWin.Top - TmpWin.Bottom) / (TmpPH * TmpUPM) - 1E-9);
  if Result < 1 then
    Result := 1;
end;

function TCADPageSetup.PageCount(const ACAD: TFNCCADCmp2D): Integer;
begin
  Result := PagesAcross(ACAD) * PagesDown(ACAD);
end;

function TCADPageSetup.PageWindow(const ACAD: TFNCCADCmp2D;
  const AIndex: Integer): TRect2D;
var
  TmpPW, TmpPH, TmpUPM, TmpPageW, TmpPageH, TmpCX, TmpCY: TRealType;
  TmpWin: TRect2D;
  TmpAcross, TmpCol, TmpRow: Integer;
begin
  TmpWin := EffectiveWindow(ACAD);
  PrintableSizeMM(TmpPW, TmpPH);
  TmpUPM := EffectiveUnitsPerMM(ACAD);
  TmpPageW := TmpPW * TmpUPM;
  TmpPageH := TmpPH * TmpUPM;

  if (Fit = pfFitToPage) and not KeepAspect then
  begin
    { Stretched: the window is the page, distortion and all. }
    Result := TmpWin;
    Exit;
  end;

  if Fit = pfFitToPage then
  begin
    { One page, the window grown to the paper's proportions about its
      own centre, so the drawing sits in the middle of the sheet. }
    TmpCX := (TmpWin.Left + TmpWin.Right) / 2;
    TmpCY := (TmpWin.Bottom + TmpWin.Top) / 2;
    Result := Rect2D(TmpCX - TmpPageW / 2, TmpCY - TmpPageH / 2,
      TmpCX + TmpPageW / 2, TmpCY + TmpPageH / 2);
    Exit;
  end;

  { pfScale: pages laid over the window from its top-left corner,
    left to right and then downwards, which is how a drawing is read
    and how the sheets are meant to be laid out on a table. }
  TmpAcross := PagesAcross(ACAD);
  if AIndex < 0 then
    Raise ECADPageError.CreateFmt('Page index %d', [AIndex]);
  TmpCol := AIndex mod TmpAcross;
  TmpRow := AIndex div TmpAcross;
  Result := Rect2D(TmpWin.Left + TmpCol * TmpPageW,
    TmpWin.Top - (TmpRow + 1) * TmpPageH, TmpWin.Left + (TmpCol + 1) * TmpPageW,
    TmpWin.Top - TmpRow * TmpPageH);
end;

{ ==================================================================
  Paper
  ================================================================== }

procedure CADPaperSizeMM(const AKind: TCADPaperKind;
  out AWidth, AHeight: TRealType);
begin
  if AKind = pkCustom then
  begin
    AWidth := 0;
    AHeight := 0;
    Exit;
  end;
  AWidth := PaperMM[AKind][0];
  AHeight := PaperMM[AKind][1];
end;

function CADPaperKindName(const AKind: TCADPaperKind): String;
begin
  Result := PaperNames[AKind];
end;

{ ==================================================================
  Drawing
  ================================================================== }

function CADPrintableRectPx(const ASetup: TCADPageSetup;
  const ADevice: TCADPageDevice): TRect;
var
  TmpSetup: TCADPageSetup;
  TmpPaperW, TmpPaperH: TRealType;
begin
  TmpSetup := ASetup;
  TmpSetup.PaperSizeMM(TmpPaperW, TmpPaperH);
  Result.Left := ADevice.OffsetXPx + ADevice.MMToPxX(TmpSetup.Margins.Left);
  Result.Top := ADevice.OffsetYPx + ADevice.MMToPxY(TmpSetup.Margins.Top);
  Result.Right := ADevice.OffsetXPx +
    ADevice.MMToPxX(TmpPaperW - TmpSetup.Margins.Right);
  Result.Bottom := ADevice.OffsetYPx +
    ADevice.MMToPxY(TmpPaperH - TmpSetup.Margins.Bottom);
end;

procedure CADDrawPage(const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup;
  const ADevice: TCADPageDevice; const AIndex: Integer;
  const ACanvas: TDecorativeCanvas; const ADrawMode: Cardinal);
var
  TmpSetup: TCADPageSetup;
  TmpWindow, TmpClip: TRect2D;
  TmpDest: TRect;
  TmpTransf: TTransf2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
  TmpSavedPPMM: TRealType;
begin
  if (ACAD = nil) or (ACanvas = nil) or (ACanvas.Graphics = nil) then
    Exit;
  { A record parameter is const, and the query methods are not - hence
    the copy. It is four dozen bytes and it happens once per page. }
  TmpSetup := ASetup;
  TmpWindow := TmpSetup.PageWindow(ACAD, AIndex);
  TmpDest := CADPrintableRectPx(TmpSetup, ADevice);
  if (TmpDest.Right <= TmpDest.Left) or (TmpDest.Bottom <= TmpDest.Top) then
    Exit;

  { The window and the destination are both physically proportional -
    the page window was built to the paper's shape - so the transform
    is asked for a plain stretch with no aspect of its own. That is
    also what makes a device with unequal pixels come out right:
    stretching equal millimetres onto unequal pixels is the correction. }
  TmpTransf := GetVisualTransform2D(TmpWindow, TmpDest, 0);
  TmpClip := RectToRect2D(TmpDest);

  TmpSavedPPMM := ACanvas.Graphics.PixelsPerMM;
  ACanvas.Graphics.PixelsPerMM := ADevice.PixelsPerMM;
  { The clip is what makes a sheet a sheet. Without it, a drawing laid
    out across several pages draws all of itself on every one of them -
    over the margins, off the paper, and across whatever else is on the
    surface, which on a preview control is the rest of the window.

    The window handed to the transform is not a clip and cannot be one.
    Shapes use it to decide whether to bother drawing at all, and a line
    that crosses the page boundary is worth drawing precisely because
    part of it belongs here. Only the device can cut it at the edge. }
  ACanvas.Graphics.PushClip(TmpDest);
  try
    TmpIter := ACAD.ObjectsIterator;
    try
      TmpObj := TObject2D(TmpIter.First);
      while TmpObj <> nil do
      begin
        if TmpObj.IsVisible(TmpWindow, ADrawMode) and
          (not TmpSetup.View.UseLayerOverride or
          not(TmpObj.Layer in TmpSetup.View.HiddenLayers)) then
        begin
          ACAD.Layers.SetCanvas(ACanvas, TmpObj.Layer);
          TmpObj.Draw(TmpTransf, ACanvas, TmpClip, ADrawMode);
        end;
        TmpObj := TObject2D(TmpIter.Next);
      end;
    finally
      TmpIter.Free;
    end;
  finally
    ACanvas.Graphics.PopClip;
    { The canvas may be the screen's, and leaving a printer's
      millimetre scale on it would make every subsequent line six
      times too thick. }
    ACanvas.Graphics.PixelsPerMM := TmpSavedPPMM;
  end;
end;

end.
