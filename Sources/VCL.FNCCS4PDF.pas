{ : PDF output, on all three frameworks, by doing almost nothing.

  TMS FNC Core ships a PDF library, and - this is the part that
  matters - <I=TTMSFNCGraphicsPDFEngine> descends from
  <I=TTMSFNCGraphics>. So the library's existing FNC backend attaches to
  a PDF exactly as it attaches to a control, and
  <See Procedure=CADDrawPage> draws a page onto it without knowing the
  difference.

    TCADFNCGraphics -> TTMSFNCGraphicsPDFEngine -> TTMSFNCPDFLib -> file

  There is no PDF-specific drawing code in this unit and there should
  never be any. Everything it does is arrange the pipe and turn the
  pages. That also means a PDF, a preview and a printed sheet come from
  one renderer rather than three, which is the property the page model
  was built for.

  It is not a new dependency either: the library already requires FNC
  Core. Hand-rolling a PDF writer was considered and would have been
  about eight hundred lines to arrive somewhere worse.

  WHY THE DRAWING IS LAID OUT AT 600 DPI AND THEN SCALED

  PDF measures in points, 72 to the inch, and the drawing layer works
  in integer device coordinates. Laid out directly in points, every
  endpoint would land on a 1/72 inch grid - a third of a millimetre -
  coarse enough to see on a CAD drawing and absurd on a plotter. So the
  page is laid out at <See Variable=CADPDFResolution> dots per inch and
  scaled to points on the way out. The output is vector either way;
  this only decides how finely the numbers going into it are rounded.

  AND WHY THAT TAKES TWO STEPS RATHER THAN ONE

  A transform alone is not enough, and the first attempt at this
  produced twenty-six blank pages.

  FNC's PDF graphics library turns the top-left origin the rest of FNC
  uses into PDF's bottom-left one **in Pascal**, per drawing call, as
  <I=FPageHeight - Y>. Its FPageHeight is in points. Hand it a Y in
  600 dpi dots and the subtraction mixes two units: a page 842 points
  tall against a Y up to 7016, giving coordinates thousands of points
  below the paper. No transform can repair that afterwards, because the
  damage is done before the transform is reached - the content stream
  came out reading <I=0.5 -3960.61 m>, which is exactly what it looked
  like on the page.

  So the page height the graphics library subtracts from is set in the
  same dots the drawing is laid out in, through
  ITMSFNCCustomPDFInitializationLib, and the transform then scales the
  result:

    s * (Hdots - Ydots) = Hpoints - s * Ydots     where s = 72/dpi

  which is the right answer with both halves in step. If that interface
  is ever not supported, the code falls back to laying out at 72 dpi,
  where no conversion is needed and the only cost is the rounding. }
unit VCL.FNCCS4PDF;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math,
{$ENDIF}
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics,
  FMX.TMSFNCPDFLib, FMX.TMSFNCPDFGraphicsLib, FMX.TMSFNCGraphicsPDFEngine,
{$ENDIF}
{$IFDEF CADSYS_LCL}
  LCLTMSFNCTypes, LCLTMSFNCGraphicsTypes, LCLTMSFNCGraphics,
  LCLTMSFNCPDFLib, LCLTMSFNCPDFGraphicsLib, LCLTMSFNCGraphicsPDFEngine,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics,
  VCL.TMSFNCPDFLib, VCL.TMSFNCPDFGraphicsLib, VCL.TMSFNCGraphicsPDFEngine,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsFNC,
  VCL.FNCCADSys4, VCL.FNCCS4Views, VCL.FNCCS4Print;

const
  { : PDF's unit is the point, 72 to the inch. }
  CADPDFPointsPerMM = 72 / 25.4;

var
  { : Dots per inch the page is laid out at before the PDF transform
    scales it to points. See the unit header.

    Six hundred, which puts the rounding at four hundredths of a
    millimetre - below what a plotter can draw and well below what
    anyone can see. Raising it costs nothing in file size, because the
    numbers are scaled down again before they are written.

    Set it to 72 to take the transform out of the picture entirely and
    lay the page out directly in points. That is the fallback the code
    takes on its own if FNC's initialization interface is ever missing,
    and it is the first thing to try if a PDF comes out wrong. }
  CADPDFResolution: Integer = 600;

type
  { : The FNC backend with a clip that actually clips.

    TTMSFNCGraphicsPDFEngine.ClipRect does this:

      DrawPathAddRectangle(ARect);   -> 're'
      DrawPathBeginClip;             -> 'n'
      DrawPathBegin;                 -> 'n'

    and 'n' means "end the path and paint nothing". The operator that
    turns a path into a clip is 'W', which FNC writes in
    DrawPathEndClip - and the engine never calls it. So the rectangle
    is built, discarded, and nothing is clipped.

    The symptom is not subtle once you know: every sheet of a tiled
    drawing carries the whole drawing, running over the margins and off
    the paper. It was found by printing the same drawing through the
    printer and through here and diffing the two PDFs' coordinates -
    every difference came out as exactly one margin, 28.3 points, which
    is what an unclipped page looks like next to a clipped one.

    Driving the PDF library directly is enough, because it has all the
    pieces: q, then the rectangle, then W n, and Q to give it back.

    If a future FNC Core calls DrawPathEndClip from ClipRect, this
    override becomes harmless duplication rather than a wrong answer -
    the clip would simply be set twice to the same rectangle. It is
    still worth deleting then. }
  TCADPDFGraphics = class(TCADFNCGraphics)
  private
    fLib: ITMSFNCCustomPDFGraphicsLib;
  protected
    procedure DoPushClip(const R: TRect); override;
    procedure DoPopClip; override;
  public
    constructor CreateForPDF(const ALib: ITMSFNCCustomPDFGraphicsLib);
  end;

{ : The page device a PDF is drawn with. Public because a caller that
  wants to check what the numbers will be should not have to guess. }
function CADPDFPageDevice: TCADPageDevice;

{ : Writes ASetup's pages of ACAD to AFileName as a PDF.

  ALastPage of -1 means "to the end". The paper size goes in as a
  custom size in points rather than one of FNC's presets, so the page
  model stays the only place that knows how big A3 is - two tables of
  paper sizes would eventually disagree, and the one that was wrong
  would be the one nobody printed from.

  Orientation is already applied by the page model, which is why the
  document is always portrait: the sheet has been swapped, so saying
  landscape as well would swap it back. }
procedure CADSavePagesToPDF(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const AFileName: String;
  const AFirstPage: Integer = 0; const ALastPage: Integer = -1);

{ : Writes sheets - paper space - to AFileName, one sheet to a page.

  ALastSheet of -1 means "to the end".

  Unlike the printer, this handles sheets that disagree about paper
  size or orientation: the page size is set per page, so an A3
  landscape sheet and an A4 portrait one can sit in the same document.
  That is the same custom-size-in-points arrangement CADSavePagesToPDF
  uses, applied once per sheet rather than once per document. }
procedure CADSaveSheetsToPDF(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const AFileName: String;
  const AFirstSheet: Integer = 0; const ALastSheet: Integer = -1);

implementation

constructor TCADPDFGraphics.CreateForPDF
  (const ALib: ITMSFNCCustomPDFGraphicsLib);
begin
  { Detached, like the preview's: until something is attached every
    drawing call is a no-op. }
  inherited Create(nil, Rect(0, 0, 0, 0));
  fLib := ALib;
end;

procedure TCADPDFGraphics.DoPushClip(const R: TRect);
begin
  if fLib = nil then
  begin
    inherited DoPushClip(R);
    Exit;
  end;
  { The rectangle goes in in device dots and the library flips it
    against the page height it was given - the same page height the
    drawing is laid out in, which is what makes the two agree. }
  fLib.DrawSaveState;
  fLib.DrawPathBeginClip;
  fLib.DrawPathAddRectangle(RectF(R.Left, R.Top, R.Right, R.Bottom));
  fLib.DrawPathEndClip;
end;

procedure TCADPDFGraphics.DoPopClip;
begin
  if fLib = nil then
  begin
    inherited DoPopClip;
    Exit;
  end;
  fLib.DrawRestoreState;
end;

function CADPDFPageDevice: TCADPageDevice;
begin
  if CADPDFResolution < 72 then
    CADPDFResolution := 72;
  Result := TCADPageDevice.FromDPI(CADPDFResolution, CADPDFResolution);
end;

{ : The transform that turns device dots into points.

  Built field by field rather than from a helper, because
  TTMSFNCGraphicsMatrix is declared twice in FNC's types unit behind
  conditionals and only the field names are certain to be there. }
function PDFScaleMatrix(const AScale: Single): TTMSFNCGraphicsMatrix;
begin
  Result.m11 := AScale;
  Result.m12 := 0;
  Result.m13 := 0;
  Result.m21 := 0;
  Result.m22 := AScale;
  Result.m23 := 0;
  Result.m31 := 0;
  Result.m32 := 0;
  Result.m33 := 1;
end;

procedure CADSavePagesToPDF(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const AFileName: String;
  const AFirstPage, ALastPage: Integer);
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpPDF: TTMSFNCPDFLib;
  TmpEngine: TTMSFNCGraphicsPDFEngine;
  TmpGraphics: TCADPDFGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpInit: ITMSFNCCustomPDFInitializationLib;
  TmpPaperW, TmpPaperH: TRealType;
  TmpBounds: TRect;
  TmpResolution: Integer;
  TmpCount, TmpFirst, TmpLast, Cont: Integer;
begin
  if (ACAD = nil) or (AFileName = '') then
    Exit;
  { A copy: the query methods are not const, and a const record
    parameter cannot be asked anything. }
  TmpSetup := ASetup;
  TmpSetup.PaperSizeMM(TmpPaperW, TmpPaperH);
  TmpCount := TmpSetup.PageCount(ACAD);

  TmpFirst := AFirstPage;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastPage;
  if (TmpLast < 0) or (TmpLast > TmpCount - 1) then
    TmpLast := TmpCount - 1;
  if TmpLast < TmpFirst then
    Exit;

  TmpPDF := TTMSFNCPDFLib.Create(nil);
  try
    TmpPDF.PageSize := psCustom;
    TmpPDF.PageWidth := TmpPaperW * CADPDFPointsPerMM;
    TmpPDF.PageHeight := TmpPaperH * CADPDFPointsPerMM;
    TmpPDF.PageOrientation := poPortrait;
    { FNC puts the words 'Header' and 'Footer' on a page by default.
      A drawing is not a report. }
    TmpPDF.Header := '';
    TmpPDF.Footer := '';
    TmpPDF.PageNumber := pnNone;

    { Laying out finer than a point needs the graphics library's own
      page height set in the same dots - see the unit header. Without
      that interface, 72 dpi is the honest answer rather than a wrong
      one. }
    TmpResolution := CADPDFResolution;
    if not Supports(TmpPDF.Graphics, ITMSFNCCustomPDFInitializationLib,
      TmpInit) then
      TmpResolution := 72;
    TmpDevice := TCADPageDevice.FromDPI(TmpResolution, TmpResolution);
    TmpBounds := Rect(0, 0, TmpDevice.MMToPxX(TmpPaperW),
      TmpDevice.MMToPxY(TmpPaperH));

    TmpEngine := TTMSFNCGraphicsPDFEngine.Create(TmpPDF);
    try
      TmpGraphics := TCADPDFGraphics.CreateForPDF(TmpPDF.Graphics);
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          TmpPDF.BeginDocument(AFileName);
          try
            for Cont := TmpFirst to TmpLast do
            begin
              { Every page, the first one included.

                BeginDocument writes the file header and the document
                metadata and nothing else - it does not open a page,
                whatever the name suggests and whatever Vcl.Printers'
                BeginDoc does. Asking for a new page only from the
                second one onwards drew the first page's tile with no
                page open, threw it away, and shifted every other tile
                back by one. The output was three plausible pages that
                happened to be pages two, three and four. }
              TmpPDF.NewPage;
              TmpGraphics.Attach(TmpEngine, TmpBounds);
              if TmpResolution <> 72 then
              begin
                { Per page, and after NewPage rather than before it:
                  NewPage draws the header and footer itself, and those
                  want the page height in points. By the time the
                  drawing starts they are already written. }
                TmpInit.SetPageWidth(TmpBounds.Right);
                TmpInit.SetPageHeight(TmpBounds.Bottom);
                { After Attach, which does not touch the transform, and
                  before anything is drawn. A clip pushed by CADDrawPage
                  brackets itself with q and Q, which leave a transform
                  set outside them alone. }
                TmpEngine.SetMatrix
                  (PDFScaleMatrix(72 / TmpResolution));
              end;
              CADDrawPage(ACAD, TmpSetup, TmpDevice, Cont, TmpCanvas);
              TmpGraphics.Attach(nil, Rect(0, 0, 0, 0));
            end;
          finally
            { A half-written PDF is still a file on disk with a
              plausible name, so the document is closed on the way out
              of a failure as well as a success. }
            TmpPDF.EndDocument;
          end;
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      TmpEngine.Free;
    end;
  finally
    TmpPDF.Free;
  end;
end;

procedure CADSaveSheetsToPDF(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const AFileName: String;
  const AFirstSheet, ALastSheet: Integer);
var
  TmpDevice: TCADPageDevice;
  TmpPDF: TTMSFNCPDFLib;
  TmpEngine: TTMSFNCGraphicsPDFEngine;
  TmpGraphics: TCADPDFGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpInit: ITMSFNCCustomPDFInitializationLib;
  TmpSheet: TCADSheet;
  TmpPaperW, TmpPaperH: TRealType;
  TmpBounds: TRect;
  TmpResolution: Integer;
  TmpFirst, TmpLast, Cont: Integer;
begin
  if (ACAD = nil) or (ASheets = nil) or (AFileName = '') then
    Exit;
  TmpFirst := AFirstSheet;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastSheet;
  if (TmpLast < 0) or (TmpLast > ASheets.Count - 1) then
    TmpLast := ASheets.Count - 1;
  if TmpLast < TmpFirst then
    Exit;

  TmpPDF := TTMSFNCPDFLib.Create(nil);
  try
    TmpPDF.PageSize := psCustom;
    { Always portrait, as the page version is: a landscape sheet has
      already had its two numbers swapped by the time it gets here, and
      saying landscape as well would swap them back. }
    TmpPDF.PageOrientation := poPortrait;
    TmpPDF.Header := '';
    TmpPDF.Footer := '';
    TmpPDF.PageNumber := pnNone;

    TmpResolution := CADPDFResolution;
    if not Supports(TmpPDF.Graphics, ITMSFNCCustomPDFInitializationLib,
      TmpInit) then
      TmpResolution := 72;
    TmpDevice := TCADPageDevice.FromDPI(TmpResolution, TmpResolution);

    TmpEngine := TTMSFNCGraphicsPDFEngine.Create(TmpPDF);
    try
      TmpGraphics := TCADPDFGraphics.CreateForPDF(TmpPDF.Graphics);
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          TmpPDF.BeginDocument(AFileName);
          try
            for Cont := TmpFirst to TmpLast do
            begin
              TmpSheet := ASheets[Cont];
              TmpSheet.SizeMM(TmpPaperW, TmpPaperH);
              if (TmpPaperW <= 0) or (TmpPaperH <= 0) then
                Continue;
              { Before NewPage: the page takes its size when it is
                opened. This is the part the printer cannot do - there
                the orientation belongs to the document. }
              TmpPDF.PageWidth := TmpPaperW * CADPDFPointsPerMM;
              TmpPDF.PageHeight := TmpPaperH * CADPDFPointsPerMM;
              TmpBounds := Rect(0, 0, TmpDevice.MMToPxX(TmpPaperW),
                TmpDevice.MMToPxY(TmpPaperH));
              { Every page, the first one included - BeginDocument does
                not open one. }
              TmpPDF.NewPage;
              TmpGraphics.Attach(TmpEngine, TmpBounds);
              if TmpResolution <> 72 then
              begin
                TmpInit.SetPageWidth(TmpBounds.Right);
                TmpInit.SetPageHeight(TmpBounds.Bottom);
                TmpEngine.SetMatrix(PDFScaleMatrix(72 / TmpResolution));
              end;
              CADDrawSheet(ACAD, TmpSheet, TmpDevice, TmpCanvas);
              TmpGraphics.Attach(nil, Rect(0, 0, 0, 0));
            end;
          finally
            TmpPDF.EndDocument;
          end;
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      TmpEngine.Free;
    end;
  finally
    TmpPDF.Free;
  end;
end;

end.
