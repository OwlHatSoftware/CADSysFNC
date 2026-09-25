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
  { fpjson for TJSONObject itself: VCL.FNCCS4JSON hides the difference
    between the two JSON APIs, but not the name of the class. }
  Classes, SysUtils, Types, Math, fpjson,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math, System.JSON,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4JSON, VCL.FNCCADSys4,
  VCL.FNCCS4Views, VCL.FNCCS4Paper;

{ The paper itself - sizes, margins, and what a device makes of a
  millimetre - lives in VCL.FNCCS4Paper, below both this unit and
  VCL.FNCCADSys4, because a sheet belongs to the drawing and the
  drawing cannot use this unit. The names are repeated here so that a
  unit which prints still needs only VCL.FNCCS4Print in its uses
  clause. They are aliases, not copies: the same types, with one
  declaration between them. }

const
  CADMMPerInch = VCL.FNCCS4Paper.CADMMPerInch;

type
  ECADPageError = VCL.FNCCS4Paper.ECADPageError;
  TCADPaperKind = VCL.FNCCS4Paper.TCADPaperKind;
  TCADPageOrientation = VCL.FNCCS4Paper.TCADPageOrientation;
  TCADPageMargins = VCL.FNCCS4Paper.TCADPageMargins;
  TCADPageDevice = VCL.FNCCS4Paper.TCADPageDevice;

const
  pkA5 = VCL.FNCCS4Paper.pkA5;
  pkA4 = VCL.FNCCS4Paper.pkA4;
  pkA3 = VCL.FNCCS4Paper.pkA3;
  pkA2 = VCL.FNCCS4Paper.pkA2;
  pkA1 = VCL.FNCCS4Paper.pkA1;
  pkA0 = VCL.FNCCS4Paper.pkA0;
  pkLetter = VCL.FNCCS4Paper.pkLetter;
  pkLegal = VCL.FNCCS4Paper.pkLegal;
  pkTabloid = VCL.FNCCS4Paper.pkTabloid;
  pkCustom = VCL.FNCCS4Paper.pkCustom;
  pgoPortrait = VCL.FNCCS4Paper.pgoPortrait;
  pgoLandscape = VCL.FNCCS4Paper.pgoLandscape;

type
  { : How the drawing is sized onto the paper.

    pfFitToPage works out the scale so the whole view fits one page.
    pfScale takes the scale as given and uses as many pages as that
    needs. }
  TCADPageFit = (pfFitToPage, pfScale);

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

    { : The setup as a JSON document, kind "pagesetup". The caller owns
      what comes back.

      The view goes in whole, as the document TCADViewSpec.SaveToJSON
      produces, rather than as a handful of borrowed fields. A setup
      that carried its own copy of the window and the layer set would
      be a second place for those to be wrong. }
    function SaveToJSON: TJSONObject;
    { : Reads a document written by SaveToJSON. Anything the document
      does not mention keeps the value it already had, so a partial or
      older file loses nothing that was already set. }
    procedure LoadFromJSON(const AJSON: TJSONObject);
    { : Writes the setup, making the view's DrawingFile relative to
      **this** file rather than to the view's own. A setup saved beside
      a drawing and moved with it still finds it. }
    procedure SaveToFile(const AFileName: String);
    { : Reads it back, making the drawing path absolute again. }
    procedure LoadFromFile(const AFileName: String);
  end;

const
  { : The <I=kind> a page setup document carries, beside "drawing",
    "library", "font" and "view". }
  CADPageSetupKind = 'pagesetup';
  { : The conventional extension. Nothing enforces it. }
  CADPageSetupExtension = '.cadpage';

  { : Written as names rather than as ordinals, like every other
    enumeration in this library's files.

    An ordinal is one insertion away from meaning something else: put
    pkA7 between pkA5 and pkA4 and every saved setup silently changes
    paper. JGetEnum still accepts a number, so a file written by hand
    is readable either way. The paper and orientation names are in
    VCL.FNCCS4Paper, where the paper is. }
  CADPageFitNames: array [0 .. 1] of String = ('fitToPage', 'scale');

{ : The sheet in millimetres, portrait, for a standard size. Repeated
  from VCL.FNCCS4Paper, like the type names above, so that a unit which
  prints needs only this one in its uses clause. }
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

{ : Draws ASheet - paper space - onto ACanvas.

  The companion of CADDrawPage, and the only routine that renders a
  sheet, for the same reason: the preview, the printer and the PDF
  writer must not each have their own idea of what a sheet looks like.

  A sheet is drawn at 1:1. Its own objects are in millimetres of
  paper, so the sheet's millimetres onto ADevice's pixels is the whole
  of the transform, and there is no scale left to decide - the
  scaling decisions live in the viewports, each of which frames the
  model at its own scale.

  The order is viewports first, each clipped to its own rectangle, and
  then the sheet's own objects over the top. A title block is in front
  of the drawing, not behind it.

  The device's pixels-per-millimetre goes to the drawing layer for the
  duration and is put back afterwards, exactly as CADDrawPage does
  it. }
procedure CADDrawSheet(const ACAD: TFNCCADCmp2D; const ASheet: TCADSheet;
  const ADevice: TCADPageDevice; const ACanvas: TDecorativeCanvas;
  const ADrawMode: Cardinal = 0);

{ : The whole sheet as a device rectangle. A preview outlines it; a
  printer clips to it. }
function CADSheetRectPx(const ASheet: TCADSheet;
  const ADevice: TCADPageDevice): TRect;

{ : One viewport's rectangle, in the same device pixels. Public
  because an application that lets somebody click a viewport needs the
  same arithmetic and must not invent its own. }
function CADSheetViewportRectPx(const ASheet: TCADSheet;
  const AViewport: TCADSheetViewport; const ADevice: TCADPageDevice): TRect;

{ : The sheet less its margins, in device pixels - what
  CADPrintableRectPx is for a page. A preview draws its guides with
  it. }
function CADSheetPrintableRectPx(const ASheet: TCADSheet;
  const ADevice: TCADPageDevice): TRect;

implementation

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
begin
  { One routine turns a paper kind and an orientation into two numbers,
    and it is not this one. A sheet asks the same question. }
  CADSheetSizeMM(Paper, Orientation, CustomWidthMM, CustomHeightMM,
    AWidth, AHeight);
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
  TCADPageSetup: persistence
  ================================================================== }

function TCADPageSetup.SaveToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    JSetStr(Result, 'format', CADSysJSONFormat);
    JSetStr(Result, 'version', CADSysJSONVersion);
    JSetStr(Result, 'kind', CADPageSetupKind);

    JSetEnum(Result, 'paper', Ord(Paper), CADPaperKindNames);
    { Only when they mean anything. A custom size written beside
      'A4' invites somebody to change one of them and wonder why
      nothing happened. }
    if Paper = pkCustom then
    begin
      JSetReal(Result, 'widthMM', CustomWidthMM);
      JSetReal(Result, 'heightMM', CustomHeightMM);
    end;
    JSetEnum(Result, 'orientation', Ord(Orientation),
      CADPageOrientationNames);

    JSetReal(Result, 'marginLeftMM', Margins.Left);
    JSetReal(Result, 'marginTopMM', Margins.Top);
    JSetReal(Result, 'marginRightMM', Margins.Right);
    JSetReal(Result, 'marginBottomMM', Margins.Bottom);

    JSetEnum(Result, 'fit', Ord(Fit), CADPageFitNames);
    JSetReal(Result, 'unitsPerMM', UnitsPerMM);
    JSetBool(Result, 'keepAspect', KeepAspect);
    JSetBool(Result, 'tiled', Tiled);

    JSetValue(Result, 'view', View.SaveToJSON);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TCADPageSetup.LoadFromJSON(const AJSON: TJSONObject);
var
  TmpView: TJSONObject;
begin
  if AJSON = nil then
    Raise ECADPageError.Create('TCADPageSetup: no document');
  if not SameText(JGetStr(AJSON, 'format'), CADSysJSONFormat) then
    Raise ECADPageError.Create
      ('TCADPageSetup: the document is not a CADSys document');
  if not SameText(JGetStr(AJSON, 'kind'), CADPageSetupKind) then
    Raise ECADPageError.Create
      ('TCADPageSetup: the document is not a page setup');

  { Every read takes the current value as its default, so a document
    that does not mention a field leaves it alone. That is what lets an
    older file load into a newer setup without losing the fields it
    never heard of. }
  Paper := TCADPaperKind(JGetEnum(AJSON, 'paper', Ord(Paper),
    CADPaperKindNames));
  CustomWidthMM := JGetReal(AJSON, 'widthMM', CustomWidthMM);
  CustomHeightMM := JGetReal(AJSON, 'heightMM', CustomHeightMM);
  Orientation := TCADPageOrientation(JGetEnum(AJSON, 'orientation',
    Ord(Orientation), CADPageOrientationNames));

  Margins.Left := JGetReal(AJSON, 'marginLeftMM', Margins.Left);
  Margins.Top := JGetReal(AJSON, 'marginTopMM', Margins.Top);
  Margins.Right := JGetReal(AJSON, 'marginRightMM', Margins.Right);
  Margins.Bottom := JGetReal(AJSON, 'marginBottomMM', Margins.Bottom);

  Fit := TCADPageFit(JGetEnum(AJSON, 'fit', Ord(Fit), CADPageFitNames));
  UnitsPerMM := JGetReal(AJSON, 'unitsPerMM', UnitsPerMM);
  KeepAspect := JGetBool(AJSON, 'keepAspect', KeepAspect);
  Tiled := JGetBool(AJSON, 'tiled', Tiled);

  TmpView := JGetObject(AJSON, 'view');
  if TmpView <> nil then
    View.LoadFromJSON(TmpView);
end;

procedure TCADPageSetup.SaveToFile(const AFileName: String);
var
  TmpDoc: TJSONObject;
  TmpKeep: String;
begin
  { The same relative-on-the-way-out rule TCADViewSpec.SaveToFile
    follows, but measured from **this** file. A setup holds a view, and
    a view holds a path; if the path were left relative to the view's
    own file it would be relative to a file that may not exist. }
  TmpKeep := View.DrawingFile;
  try
    if View.DrawingFile <> '' then
      View.DrawingFile := ExtractRelativePath
        (ExtractFilePath(ExpandFileName(AFileName)), View.DrawingFile);
    TmpDoc := SaveToJSON;
    try
      JSONToFile(TmpDoc, AFileName, True);
    finally
      TmpDoc.Free;
    end;
  finally
    View.DrawingFile := TmpKeep;
  end;
end;

procedure TCADPageSetup.LoadFromFile(const AFileName: String);
var
  TmpDoc: TJSONObject;
begin
  TmpDoc := JSONFromFile(AFileName);
  try
    LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;
  { Absolute in memory: a caller holding a setup has no reason to also
    have to remember where the setup came from. }
  if View.DrawingFile <> '' then
    View.DrawingFile := ExpandFileName(ExtractFilePath(ExpandFileName
      (AFileName)) + View.DrawingFile);
end;

{ ==================================================================
  Paper, forwarded
  ================================================================== }

procedure CADPaperSizeMM(const AKind: TCADPaperKind;
  out AWidth, AHeight: TRealType);
begin
  { Qualified, or this calls itself. }
  VCL.FNCCS4Paper.CADPaperSizeMM(AKind, AWidth, AHeight);
end;

function CADPaperKindName(const AKind: TCADPaperKind): String;
begin
  Result := VCL.FNCCS4Paper.CADPaperKindName(AKind);
end;

{ ==================================================================
  Drawing
  ================================================================== }

{ : The sheet's millimetres onto the device's pixels. Needed by three
  routines below and worth having in one. }
function SheetTransform(const ASheet: TCADSheet;
  const ADevice: TCADPageDevice; out ADest: TRect): TTransf2D;
var
  TmpPaperW, TmpPaperH: TRealType;
  TmpWin: TRect2D;
begin
  ASheet.SizeMM(TmpPaperW, TmpPaperH);
  ADest := ADevice.PaperRect(TmpPaperW, TmpPaperH);
  TmpWin := ASheet.PaperRect2D;
  { Aspect 0 - a plain stretch. The sheet's rectangle and the device's
    are the same shape already, because both came from the same two
    millimetre figures, and a device with unequal pixels wants the
    stretch rather than a correction on top of it. }
  Result := GetVisualTransform2D(TmpWin, ADest, 0);
end;

function CADSheetRectPx(const ASheet: TCADSheet;
  const ADevice: TCADPageDevice): TRect;
var
  TmpPaperW, TmpPaperH: TRealType;
begin
  Result := Rect(0, 0, 0, 0);
  if ASheet = nil then
    Exit;
  ASheet.SizeMM(TmpPaperW, TmpPaperH);
  Result := ADevice.PaperRect(TmpPaperW, TmpPaperH);
end;

{ : A rectangle of a sheet's millimetres as device pixels.

  Millimetres straight onto the device, exactly as
  CADPrintableRectPx turns margins into pixels - and deliberately NOT
  through the sheet's visual transform.

  That transform carries a half-pixel offset, the pixel-centre
  convention every drawing in this library is laid out with. It is
  right for drawing and wrong for a rectangle that has to line up with
  another rectangle computed a different way: the sheet's own clip
  comes from TCADPageDevice.PaperRect, and a viewport arrived at
  through the transform came out a pixel short of it. Two conventions
  for two rectangles that must meet is a seam waiting to appear at
  some resolution nobody tested.

  The Y flip is the other half: the sheet's Y runs upwards and the
  device's runs down, so the TOP edge - the larger Y - is the smaller
  device row. Taking Left/Bottom for the top-left corner gives an
  inside-out rectangle, which clips away to nothing and draws a blank
  sheet without a word. }
function SheetRectPx(const ASheet: TCADSheet; const ADevice: TCADPageDevice;
  const ARectMM: TRect2D): TRect;
var
  TmpPaperW, TmpPaperH: TRealType;
begin
  ASheet.SizeMM(TmpPaperW, TmpPaperH);
  Result.Left := ADevice.OffsetXPx + ADevice.MMToPxX(ARectMM.Left);
  Result.Right := ADevice.OffsetXPx + ADevice.MMToPxX(ARectMM.Right);
  Result.Top := ADevice.OffsetYPx + ADevice.MMToPxY(TmpPaperH - ARectMM.Top);
  Result.Bottom := ADevice.OffsetYPx +
    ADevice.MMToPxY(TmpPaperH - ARectMM.Bottom);
end;

function CADSheetViewportRectPx(const ASheet: TCADSheet;
  const AViewport: TCADSheetViewport; const ADevice: TCADPageDevice): TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (ASheet = nil) or (AViewport = nil) then
    Exit;
  Result := SheetRectPx(ASheet, ADevice, AViewport.RectMM);
end;

function CADSheetPrintableRectPx(const ASheet: TCADSheet;
  const ADevice: TCADPageDevice): TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if ASheet = nil then
    Exit;
  Result := SheetRectPx(ASheet, ADevice, ASheet.PrintableRect2D);
end;

{ : One viewport: its border, and the model seen through it. }
procedure DrawSheetViewport(const ACAD: TFNCCADCmp2D;
  const AViewport: TCADSheetViewport; const ADest: TRect;
  const ACanvas: TDecorativeCanvas; const ADrawMode: Cardinal);
var
  TmpWindow, TmpClip: TRect2D;
  TmpTransf: TTransf2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
begin
  if (ADest.Right <= ADest.Left) or (ADest.Bottom <= ADest.Top) then
    Exit;
  { The border is drawn in layer zero's pen, and as a polyline rather
    than a rectangle: a rectangle is filled with the brush, and a
    viewport painted over with layer zero's brush would hide the
    drawing it exists to show. }
  if AViewport.ShowBorder then
  begin
    ACAD.Layers.SetCanvas(ACanvas, 0);
    ACanvas.Graphics.Polyline([Point(ADest.Left, ADest.Top),
      Point(ADest.Right, ADest.Top), Point(ADest.Right, ADest.Bottom),
      Point(ADest.Left, ADest.Bottom), Point(ADest.Left, ADest.Top)]);
  end;

  TmpWindow := AViewport.ModelWindow(ACAD);
  TmpTransf := GetVisualTransform2D(TmpWindow, ADest, 0);
  TmpClip := RectToRect2D(ADest);

  { Nested inside the sheet's clip, which is what PushClip had to
    learn to do before any of this could work: a viewport is a hole in
    a sheet, and a drawing seen through it runs past the hole in every
    direction. }
  ACanvas.Graphics.PushClip(ADest);
  try
    TmpIter := ACAD.ObjectsIterator;
    try
      TmpObj := TObject2D(TmpIter.First);
      while TmpObj <> nil do
      begin
        if TmpObj.IsVisible(TmpWindow, ADrawMode) and
          (not AViewport.View.UseLayerOverride or
          not(TmpObj.Layer in AViewport.View.HiddenLayers)) then
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
  end;
end;

procedure CADDrawSheet(const ACAD: TFNCCADCmp2D; const ASheet: TCADSheet;
  const ADevice: TCADPageDevice; const ACanvas: TDecorativeCanvas;
  const ADrawMode: Cardinal);
var
  TmpTransf: TTransf2D;
  TmpDest: TRect;
  TmpClip: TRect2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
  TmpSavedPPMM: TRealType;
  Cont: Integer;
begin
  if (ACAD = nil) or (ASheet = nil) or (ACanvas = nil) or
    (ACanvas.Graphics = nil) then
    Exit;
  TmpTransf := SheetTransform(ASheet, ADevice, TmpDest);
  if (TmpDest.Right <= TmpDest.Left) or (TmpDest.Bottom <= TmpDest.Top) then
    Exit;
  TmpClip := RectToRect2D(TmpDest);

  TmpSavedPPMM := ACanvas.Graphics.PixelsPerMM;
  ACanvas.Graphics.PixelsPerMM := ADevice.PixelsPerMM;
  ACanvas.Graphics.PushClip(TmpDest);
  try
    for Cont := 0 to ASheet.ViewportCount - 1 do
      DrawSheetViewport(ACAD, ASheet.Viewports[Cont],
        CADSheetViewportRectPx(ASheet, ASheet.Viewports[Cont], ADevice),
        ACanvas, ADrawMode);

    { The sheet's own objects last, in the sheet's millimetres: a title
      block, a border, a revision table. Ordinary shapes, drawn the
      ordinary way, which is the point of holding them as TObject2D. }
    TmpIter := ASheet.ObjectsIterator;
    try
      TmpObj := TObject2D(TmpIter.First);
      while TmpObj <> nil do
      begin
        if TmpObj.IsVisible(ASheet.PaperRect2D, ADrawMode) then
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
    ACanvas.Graphics.PixelsPerMM := TmpSavedPPMM;
  end;
end;

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
