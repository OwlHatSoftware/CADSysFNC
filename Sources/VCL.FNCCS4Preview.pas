{ : A print preview control, on all three frameworks.

  It draws a sheet of paper with the drawing on it, and it does so by
  calling <See Procedure=CADDrawPage> - the same routine the printer
  calls, with a different <See Class=TCADPageDevice>. That is the
  entire design and it is worth stating plainly:

    the preview is not a picture of what will print.
    It is the same code, at fewer pixels per millimetre.

  A preview drawn by its own code drifts from the printer, and the
  drift only shows on paper, where it costs a sheet to find and cannot
  be seen in a test.

  It needs no printer, which is what makes it work on FMX and what
  makes it possible to look at a page setup without a print driver
  installed.

  It shows a SHEET the same way. Set
  <See Property=TFNCPrintPreview@Sheet> and the control draws paper
  space through CADDrawSheet instead - same control, same paper, same
  margin guides, and the setup is left alone rather than being
  half-used. A sheet is one page, so the page buttons do nothing while
  one is showing. }
unit VCL.FNCCS4Preview;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, UITypes, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.UITypes, System.Math,
{$ENDIF}
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics,
  FMX.TMSFNCCustomControl,
{$ENDIF}
{$IFDEF CADSYS_LCL}
  LCLTMSFNCTypes, LCLTMSFNCGraphicsTypes, LCLTMSFNCGraphics,
  LCLTMSFNCCustomControl,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics,
  VCL.TMSFNCCustomControl,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsFNC,
  VCL.FNCCADSys4, VCL.FNCCS4Views, VCL.FNCCS4Print;

type
  { : Fired after the page or the setup changes, so a form can update
    its "page 2 of 7" label without polling. }
  TCADPreviewPageEvent = procedure(Sender: TObject; const APageIndex,
    APageCount: Integer) of object;

  { : Shows one page of a drawing as it will print.

    Give it a <See Property=TFNCPrintPreview@CADCmp> and a
    <See Property=TFNCPrintPreview@Setup> and it draws. Nothing here
    holds state that the page model does not - the control is a window
    onto a value, and changing the value and calling
    <See Method=TFNCPrintPreview@SetupChanged> is the whole API. }
  TFNCPrintPreview = class(TTMSFNCCustomControl)
  private
    fCAD: TFNCCADCmp2D;
    fSetup: TCADPageSetup;
    { : The sheet being shown, or nil for "show the page setup". Not
      owned - it belongs to the drawing's Sheets. }
    fSheet: TCADSheet;
    fPageIndex: Integer;
    fCanvas: TDecorativeCanvas;
    fGraphics: TCADFNCGraphics;
    fPaperColor: TColor;
    fShadowColor: TColor;
    fMarginColor: TColor;
    fShowMargins: Boolean;
    fPadding: Integer;
    fOnPageChanged: TCADPreviewPageEvent;
    procedure SetCADCmp(const Value: TFNCCADCmp2D);
    procedure SetSetup(const Value: TCADPageSetup);
    procedure SetSheet(const Value: TCADSheet);
    procedure SetPageIndex(const Value: Integer);
    procedure SetShowMargins(const Value: Boolean);
    procedure SetPaperColor(const Value: TColor);
    procedure SetPadding(const Value: Integer);
    procedure PageChanged;
    { : The sheet's size in millimetres, orientation applied. }
    procedure PaperMM(out AWidth, AHeight: TRealType);
  protected
    procedure Draw(AGraphics: TTMSFNCGraphics; ARect: TRectF); override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
    { : The sheet and its shadow. Separate so a descendant can leave the
      paper out - a preview embedded in a dark tool window, say. }
    procedure DrawSheet(const APaper: TRect); virtual;
    { : The dashed margin guides. Not printed, obviously; they are here
      because a margin that cannot be seen is a margin that gets set
      wrong. }
    procedure DrawMarginGuides(const ADevice: TCADPageDevice); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { : How many pages this setup produces. 1 unless the setup is
      tiled and the drawing is bigger than a page. }
    function PageCount: Integer;
    { : The device the preview is drawing with. The same value the
      printer's would have if the printer were this coarse - which is
      what makes the two pictures the same picture. }
    function PageDevice: TCADPageDevice;
    { : Where the sheet is, in this control's pixels. }
    function PaperRect: TRect;

    procedure FirstPage;
    procedure LastPage;
    procedure NextPage;
    procedure PreviousPage;

    { : Call after changing anything inside Setup in place.

      Setup is a record, so `Preview.Setup.Orientation := pgoLandscape`
      does not compile against a property - read it, change it, assign
      it back, and the setter does this for you. This is for code that
      keeps its own copy and wants the preview to catch up. }
    procedure SetupChanged;

    { : What to show. Assigning a whole setup repaints and clamps the
      page index. }
    property Setup: TCADPageSetup read fSetup write SetSetup;

    { : The sheet to show, or nil to go back to showing the page
      setup.

      Not published and not owned: a sheet belongs to the drawing, and
      this is a reference into TFNCCADCmp.Sheets. The control drops it
      when the drawing goes, but it cannot know when the drawing
      deletes one sheet - assign nil before deleting the sheet being
      looked at. }
    property Sheet: TCADSheet read fSheet write SetSheet;
  published
    { : The drawing. The control does not own it and survives it being
      freed. }
    property CADCmp: TFNCCADCmp2D read fCAD write SetCADCmp;
    { : Which page, from zero. Clamped to the page count. }
    property PageIndex: Integer read fPageIndex write SetPageIndex default 0;
    { : The sheet's colour. White, because that is what paper is, and
      because a preview that flatters the drawing is not a preview. }
    property PaperColor: TColor read fPaperColor write SetPaperColor;
    property ShowMargins: Boolean read fShowMargins write SetShowMargins
      default True;
    { : Space between the sheet and the edge of the control, in pixels. }
    property Padding: Integer read fPadding write SetPadding default 12;
    property OnPageChanged: TCADPreviewPageEvent read fOnPageChanged
      write fOnPageChanged;
  end;

implementation

constructor TFNCPrintPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fSetup := TCADPageSetup.Default;
  fPageIndex := 0;
  fPaperColor := cadtcWhite;
  fShadowColor := cadtcGray;
  fMarginColor := cadtcSilver;
  fShowMargins := True;
  fPadding := 12;
  { Built once and pointed at whatever Draw is given. The graphics is
    created detached - there is no FNC graphics outside a paint, and
    every call through it is a no-op until there is. }
  fGraphics := TCADFNCGraphics.Create(nil, Rect(0, 0, 0, 0));
  fCanvas := TDecorativeCanvas.Create(fGraphics, False);
  Width := 320;
  Height := 440;
end;

destructor TFNCPrintPreview.Destroy;
begin
  fCanvas.Free;
  fGraphics.Free;
  inherited Destroy;
end;

procedure TFNCPrintPreview.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = fCAD) then
  begin
    fCAD := nil;
    { The sheet belonged to that drawing. }
    fSheet := nil;
  end;
end;

procedure TFNCPrintPreview.SetCADCmp(const Value: TFNCCADCmp2D);
begin
  if fCAD = Value then
    Exit;
  if fCAD <> nil then
    fCAD.RemoveFreeNotification(Self);
  fCAD := Value;
  if fCAD <> nil then
    fCAD.FreeNotification(Self);
  { Whatever sheet was showing belonged to the drawing being replaced. }
  fSheet := nil;
  SetupChanged;
end;

procedure TFNCPrintPreview.SetSheet(const Value: TCADSheet);
begin
  if fSheet = Value then
    Exit;
  fSheet := Value;
  { A sheet is one page. Going either way resets the page index rather
    than leaving 'page 3 of 1' on a form's label. }
  fPageIndex := 0;
  SetupChanged;
end;

procedure TFNCPrintPreview.SetSetup(const Value: TCADPageSetup);
begin
  fSetup := Value;
  SetupChanged;
end;

procedure TFNCPrintPreview.SetShowMargins(const Value: Boolean);
begin
  if fShowMargins = Value then
    Exit;
  fShowMargins := Value;
  Invalidate;
end;

procedure TFNCPrintPreview.SetPaperColor(const Value: TColor);
begin
  if fPaperColor = Value then
    Exit;
  fPaperColor := Value;
  Invalidate;
end;

procedure TFNCPrintPreview.SetPadding(const Value: Integer);
begin
  if (fPadding = Value) or (Value < 0) then
    Exit;
  fPadding := Value;
  Invalidate;
end;

procedure TFNCPrintPreview.SetPageIndex(const Value: Integer);
var
  TmpValue, TmpCount: Integer;
begin
  TmpCount := PageCount;
  TmpValue := Value;
  if TmpValue < 0 then
    TmpValue := 0;
  if TmpValue > TmpCount - 1 then
    TmpValue := TmpCount - 1;
  if fPageIndex = TmpValue then
    Exit;
  fPageIndex := TmpValue;
  PageChanged;
end;

procedure TFNCPrintPreview.SetupChanged;
begin
  { A new setup can make the drawing fit on fewer pages than the one
    being looked at. }
  if fPageIndex > PageCount - 1 then
    fPageIndex := PageCount - 1;
  if fPageIndex < 0 then
    fPageIndex := 0;
  PageChanged;
end;

procedure TFNCPrintPreview.PageChanged;
begin
  Invalidate;
  if Assigned(fOnPageChanged) then
    fOnPageChanged(Self, fPageIndex, PageCount);
end;

procedure TFNCPrintPreview.FirstPage;
begin
  PageIndex := 0;
end;

procedure TFNCPrintPreview.LastPage;
begin
  PageIndex := PageCount - 1;
end;

procedure TFNCPrintPreview.NextPage;
begin
  PageIndex := fPageIndex + 1;
end;

procedure TFNCPrintPreview.PreviousPage;
begin
  PageIndex := fPageIndex - 1;
end;

function TFNCPrintPreview.PageCount: Integer;
begin
  Result := 1;
  { A sheet is one sheet. Tiling is a page-setup idea - a drawing too
    big for the paper is what a viewport's scale is for. }
  if (fCAD = nil) or (fSheet <> nil) then
    Exit;
  try
    Result := fSetup.PageCount(fCAD);
  except
    { An empty drawing, a paper size with no room in it: the preview
      shows one blank sheet and the exception belongs to whoever asked
      to print, not to a repaint. }
    on ECADPageError do
      Result := 1;
  end;
  if Result < 1 then
    Result := 1;
end;

procedure TFNCPrintPreview.PaperMM(out AWidth, AHeight: TRealType);
begin
  if fSheet <> nil then
    fSheet.SizeMM(AWidth, AHeight)
  else
    fSetup.PaperSizeMM(AWidth, AHeight);
end;

function TFNCPrintPreview.PageDevice: TCADPageDevice;
var
  TmpW, TmpH: TRealType;
  TmpBoxW, TmpBoxH: Integer;
begin
  PaperMM(TmpW, TmpH);
  { Round returns an Int64, and Width is a Single on FMX and an Integer
    elsewhere. Narrowed here, once, rather than inside the call where
    the overload would have to be guessed at. }
  TmpBoxW := Integer(Round(Width)) - 2 * fPadding;
  TmpBoxH := Integer(Round(Height)) - 2 * fPadding;
  Result := TCADPageDevice.ToBox(TmpW, TmpH, TmpBoxW, TmpBoxH);
  { ToBox centres the sheet in the box; the box itself sits inside the
    padding. }
  Result.OffsetXPx := Result.OffsetXPx + fPadding;
  Result.OffsetYPx := Result.OffsetYPx + fPadding;
end;

function TFNCPrintPreview.PaperRect: TRect;
var
  TmpW, TmpH: TRealType;
begin
  PaperMM(TmpW, TmpH);
  Result := PageDevice.PaperRect(TmpW, TmpH);
end;

procedure TFNCPrintPreview.DrawSheet(const APaper: TRect);
const
  ShadowPx = 3;
begin
  { The shadow first and offset, so the sheet lands on top of it. It is
    there to say "this is a sheet of paper" in one glance; without it a
    white rectangle on a light background is just a gap. }
  fCanvas.Pen.Style := cpsClear;
  fCanvas.Brush.Style := cbsSolid;
  fCanvas.Brush.Color := TColorToCADColor(fShadowColor);
  fCanvas.Graphics.FillRect(Rect(APaper.Left + ShadowPx, APaper.Top + ShadowPx,
    APaper.Right + ShadowPx, APaper.Bottom + ShadowPx));

  fCanvas.Brush.Color := TColorToCADColor(fPaperColor);
  fCanvas.Graphics.FillRect(APaper);

  fCanvas.Pen.Style := cpsSolid;
  fCanvas.Pen.Width := 1;
  fCanvas.Pen.Color := TColorToCADColor(fShadowColor);
  fCanvas.Brush.Style := cbsClear;
  fCanvas.Graphics.Rectangle(APaper.Left, APaper.Top, APaper.Right,
    APaper.Bottom);
end;

procedure TFNCPrintPreview.DrawMarginGuides(const ADevice: TCADPageDevice);
var
  TmpRect: TRect;
begin
  if not fShowMargins then
    Exit;
  if fSheet <> nil then
    TmpRect := CADSheetPrintableRectPx(fSheet, ADevice)
  else
    TmpRect := CADPrintableRectPx(fSetup, ADevice);
  if (TmpRect.Right <= TmpRect.Left) or (TmpRect.Bottom <= TmpRect.Top) then
    Exit;
  fCanvas.Pen.Style := cpsDash;
  fCanvas.Pen.Width := 1;
  fCanvas.Pen.Color := TColorToCADColor(fMarginColor);
  fCanvas.Brush.Style := cbsClear;
  fCanvas.Graphics.Rectangle(TmpRect.Left, TmpRect.Top, TmpRect.Right,
    TmpRect.Bottom);
end;

procedure TFNCPrintPreview.Draw(AGraphics: TTMSFNCGraphics; ARect: TRectF);
var
  TmpBounds: TRect;
  TmpDevice: TCADPageDevice;
  TmpPaperW, TmpPaperH: TRealType;
begin
  inherited;
  if AGraphics = nil then
    Exit;
  TmpBounds := Rect(Round(ARect.Left), Round(ARect.Top), Round(ARect.Right),
    Round(ARect.Bottom));

  fGraphics.Attach(AGraphics, TmpBounds);
  try
    { Inside Draw there is a scene, so the clip may be applied here -
      see TCADFNCGraphics.ApplyClip for why it is not applied by
      Attach. }
    fGraphics.ApplyClip;

    PaperMM(TmpPaperW, TmpPaperH);
    TmpDevice := PageDevice;
    if TmpDevice.PixelsPerMMX <= 0 then
      Exit;

    DrawSheet(TmpDevice.PaperRect(TmpPaperW, TmpPaperH));
    DrawMarginGuides(TmpDevice);

    if fCAD = nil then
      Exit;
    try
      if fSheet <> nil then
        CADDrawSheet(fCAD, fSheet, TmpDevice, fCanvas)
      else
        CADDrawPage(fCAD, fSetup, TmpDevice, fPageIndex, fCanvas);
    except
      { A setup that cannot produce a page shows an empty sheet. The
        alternative is an exception once per repaint, which on FMX is a
        modal dialog once per repaint. }
      on ECADPageError do
        ;
    end;
  finally
    fGraphics.ReleaseClip;
    fGraphics.Attach(nil, Rect(0, 0, 0, 0));
  end;
end;

end.
