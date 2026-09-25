{ : The print preview dialog, VCL.

  Demos\CAD2D\FMX\PrintPrvFrm.pas is the same dialog written for FMX -
  same class name, same Execute, same handler names, same order. Diff
  them. Two things differ and both are substantive: the Print button
  really prints here and says what is missing there, and LayoutBar
  measures the font here and uses plain numbers there.

  The preview itself is the library's TFNCPrintPreview on both sides,
  unchanged, which is the point of it being an FNC control. }
unit PrintPrvFrm;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  Vcl.Graphics, Vcl.Printers,
  DemoLog,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCADSys4, VCL.FNCCS4Views,
  VCL.FNCCS4Print, VCL.FNCCS4Preview, VCL.FNCCS4PDF, VCL.FNCCS4ExportVCL;

type
  TPrintPreviewForm = class(TForm)
  private
    fPreview: TFNCPrintPreview;
    fBar: TPanel;
    { : Model, or one of the drawing's sheets. A sheet carries its own
      paper and its own scales, so choosing one puts the rest of the
      bar to sleep. }
    fSheetBox: TComboBox;
    fPaper: TComboBox;
    fOrientation: TComboBox;
    fFit: TComboBox;
    fScale: TEdit;
    fTiled: TCheckBox;
    fMargin: TEdit;
    fPageLabel: TLabel;
    fPrevBtn, fNextBtn, fPrintBtn, fPDFBtn, fCloseBtn: TButton;
    { : The bar's controls in the order they were added, which is the
      order they are laid out in. A list rather than ControlCount,
      because the VCL orders aligned controls by position and the
      positions are what LayoutBar is about to decide. }
    fCtrls: array of TControl;
    fCAD: TFNCCADCmp2D;
    fSetup: TCADPageSetup;
    { : False until the first layout has chosen the dialog's size.
      After that the size belongs to whoever is holding the window. }
    fSized: Boolean;
    { : LayoutBar sets fBar.Height, which resizes the client area, which
      is what OnResize is listening to. }
    fInLayout: Boolean;
    procedure BuildControls;
    procedure Track(const ACtrl: TControl);
    function AddLabel(const ACaption: string): TLabel;
    function AddCombo(const AItems: array of string;
      const AIndex: Integer): TComboBox;
    function AddEdit(const AText: string): TEdit;
    function AddButton(const ACaption: string;
      const AClick: TNotifyEvent): TButton;
    { : How wide this control has to be for its own text not to clip.
      See the note in LayoutBar for why it is measured rather than
      chosen. }
    function MeasureControl(const ACtrl: TControl;
      const ALine: Integer): Integer;
    procedure LayoutBar;
    { : Reads the bar into fSetup and hands it to the preview. One
      direction only - the controls are the truth and the setup is
      rebuilt from them, so there is no state to get out of step. }
    { : The sheet the Show box names, or nil for the model. }
    function SelectedSheet: TCADSheet;
    procedure ApplySetup;
    procedure SettingChanged(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure PDFClick(Sender: TObject);
    procedure PrintClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure PageChanged(Sender: TObject; const APageIndex,
      APageCount: Integer);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormAfterMonitorDpiChanged(Sender: TObject;
      OldDPI, NewDPI: Integer);
  public
    { : Shows the dialog. ASetup seeds the controls; what the user ends
      up with is not read back, because the demo has nowhere to keep
      it - a real application would return it. }
    class procedure Execute(const AOwner: TComponent;
      const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup);
  end;

implementation

class procedure TPrintPreviewForm.Execute(const AOwner: TComponent;
  const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup);
var
  TmpForm: TPrintPreviewForm;
begin
  Log('PrintPreview: open');
  TmpForm := TPrintPreviewForm.CreateNew(AOwner);
  try
    TmpForm.fCAD := ACAD;
    TmpForm.fSetup := ASetup;
    TmpForm.BuildControls;
    TmpForm.ApplySetup;
    TmpForm.ShowModal;
  finally
    TmpForm.Free;
  end;
  Log('PrintPreview: closed');
end;

procedure TPrintPreviewForm.Track(const ACtrl: TControl);
begin
  SetLength(fCtrls, Length(fCtrls) + 1);
  fCtrls[High(fCtrls)] := ACtrl;
end;

function TPrintPreviewForm.AddLabel(const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := fBar;
  Result.Caption := ACaption;
  { LayoutBar decides the width, so AutoSize has to let go of it. }
  Result.AutoSize := False;
  Track(Result);
end;

function TPrintPreviewForm.AddCombo(const AItems: array of string;
  const AIndex: Integer): TComboBox;
var
  Cont: Integer;
begin
  Result := TComboBox.Create(Self);
  Result.Parent := fBar;
  Result.Style := csDropDownList;
  for Cont := Low(AItems) to High(AItems) do
    Result.Items.Add(AItems[Cont]);
  Result.ItemIndex := AIndex;
  Result.OnChange := SettingChanged;
  Track(Result);
end;

function TPrintPreviewForm.AddEdit(const AText: string): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := fBar;
  Result.Text := AText;
  Result.OnChange := SettingChanged;
  Track(Result);
end;

function TPrintPreviewForm.AddButton(const ACaption: string;
  const AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := fBar;
  Result.Caption := ACaption;
  Result.OnClick := AClick;
  Track(Result);
end;

procedure TPrintPreviewForm.BuildControls;
var
  Cont: Integer;
begin
  Caption := 'Print preview';
  Position := poOwnerFormCenter;
  { NOT Scaled, and the log is why.

    The VCL rescales a form's font relative to the PixelsPerInch the
    form has recorded, which for a designed form comes from its .dfm.
    A form built with CreateNew has no .dfm, so it records 96 while
    its font is inherited from whatever display it was created on. On
    a 240 DPI screen that leaves the two disagreeing by a factor of
    2.5, and the arithmetic comes out as:

      240 -> 96   scale 96/96  = 1.0   nothing happens
      96 -> 240   scale 240/96 = 2.5   the font is now far too big

    which is exactly what the demo log showed: line height 41, then 41
    again on the other monitor, then 100 on the way back.

    So the VCL is told not to try, and LayoutBar sets the font itself.

    The catch on this side is that a form which is not Scaled is also a
    form whose CurrentPPI the VCL stops updating: it read 96 for a
    whole session, including while the window was plainly on the 240
    DPI screen with a 2223 pixel client area. The number that does
    track is Monitor.PixelsPerInch - which the main form's own log line
    has been printing all along, beside a CurrentPPI that agreed with
    it only because that form is Scaled. }
  Scaled := False;
  OnShow := FormShow;
  OnResize := FormResize;
  OnAfterMonitorDpiChanged := FormAfterMonitorDpiChanged;

  fBar := TPanel.Create(Self);
  fBar.Parent := Self;
  fBar.Align := alTop;
  fBar.BevelOuter := bvNone;

  { Created here, placed in LayoutBar. Nothing gets a position or a size
    in this method, because neither can be known until the form has been
    shown and the VCL has scaled its font. }
  AddLabel('Show');
  fSheetBox := AddCombo(['Model'], 0);
  if fCAD <> nil then
    for Cont := 0 to fCAD.Sheets.Count - 1 do
      fSheetBox.Items.Add(fCAD.Sheets[Cont].Name);

  AddLabel('Paper');
  fPaper := AddCombo(['A5', 'A4', 'A3', 'A2', 'A1', 'A0', 'Letter', 'Legal',
    'Tabloid'], 1);
  fOrientation := AddCombo(['Portrait', 'Landscape'], 0);
  AddLabel('Margin mm');
  fMargin := AddEdit('10');
  fFit := AddCombo(['Fit to page', 'To scale'], 0);
  AddLabel('units/mm');
  fScale := AddEdit('1');

  fTiled := TCheckBox.Create(Self);
  fTiled.Parent := fBar;
  fTiled.Caption := 'Tiled';
  fTiled.OnClick := SettingChanged;
  Track(fTiled);

  fPrevBtn := AddButton('<', PrevClick);
  fNextBtn := AddButton('>', NextClick);
  fPageLabel := AddLabel('Page 1 of 1');
  fPrintBtn := AddButton('Print...', PrintClick);
  fPDFBtn := AddButton('PDF...', PDFClick);
  fCloseBtn := AddButton('Close', CloseClick);

  fPreview := TFNCPrintPreview.Create(Self);
  fPreview.Parent := Self;
  fPreview.Align := alClient;
  fPreview.CADCmp := fCAD;
  fPreview.OnPageChanged := PageChanged;
end;

function TPrintPreviewForm.MeasureControl(const ACtrl: TControl;
  const ALine: Integer): Integer;
var
  Cont: Integer;
begin
  Canvas.Font := Font;
  if ACtrl = fPageLabel then
    { Measured against the widest caption it will ever hold, not the one
      it holds now - otherwise it fits 'Page 1 of 1' and clips the
      moment a drawing needs ten sheets. }
    Result := Canvas.TextWidth('Page 88 of 88') + ALine
  else if ACtrl is TLabel then
    Result := Canvas.TextWidth(TLabel(ACtrl).Caption) + ALine div 2
  else if ACtrl is TComboBox then
  begin
    Result := 0;
    for Cont := 0 to TComboBox(ACtrl).Items.Count - 1 do
      Result := Max(Result, Canvas.TextWidth(TComboBox(ACtrl).Items[Cont]));
    { The widest entry in the list, plus room for the drop-down arrow.
      A combo sized to the entry it happens to be showing is how
      'Landscape' came out as 'Lar'. }
    Result := Result + ALine * 2;
  end
  else if ACtrl is TEdit then
    Result := Canvas.TextWidth('00000') + ALine
  else if ACtrl is TCheckBox then
    Result := Canvas.TextWidth(TCheckBox(ACtrl).Caption) + ALine * 2
  else if ACtrl is TButton then
    Result := Canvas.TextWidth(TButton(ACtrl).Caption) + ALine * 2
  else
    Result := ALine * 4;
end;

procedure TPrintPreviewForm.LayoutBar;
var
  TmpLine, TmpPad, TmpCtrlH, TmpRowH, TmpX, TmpY, TmpRows, TmpW, Cont: Integer;
  TmpPPI: Integer;
  TmpCtrl: TControl;
begin
  if fInLayout then
    Exit;
  fInLayout := True;
  try
  { The same trap as the main form's LayoutToolbar, and it caught this
    dialog too: the VCL scales a form's font for the display, but it
    does so AFTER OnCreate, and it never scales controls created at run
    time at all. A bar built with 96 dpi pixel positions therefore draws
    a 150% font into 100% boxes - the combos read 'Lar' and 'Fit t', the
    labels sit on top of them, and the buttons run off the end.

    So: run from OnShow, when the scaling has happened, and measure
    rather than calculate. A control sized to its own widest text cannot
    clip, at any DPI, in any font. The line height is the unit for
    everything else, so padding and control heights grow with it.

    FMX needs none of this - see the note in its LayoutBar. }

  { The font first, because everything below is measured from it.

    Twelve pixels at 96 dpi is what the main demo form's .dfm gives it,
    so the two windows come out the same size on the same display - it
    logs font 12 at 96 and font 30 at 240, and so does this.

    From the monitor, not from the form: see BuildControls for why
    CurrentPPI is not usable here. Monitor can be nil before the window
    has been placed, and the screen is the right answer then, because
    that is the display it is about to appear on. }
  TmpPPI := Screen.PixelsPerInch;
  if Monitor <> nil then
    TmpPPI := Monitor.PixelsPerInch;
  if TmpPPI < 48 then
    TmpPPI := 96;
  Font.Height := -((12 * TmpPPI) div 96);
  Canvas.Font := Font;
  TmpLine := Canvas.TextHeight('Wg');
  if TmpLine < 8 then
    TmpLine := 15;
  TmpPad := Max(TmpLine div 2, 4);
  TmpCtrlH := TmpLine * 2;
  TmpRowH := TmpCtrlH + TmpPad;

  { The opening size only. After that the window belongs to whoever is
    holding it: a DPI change has already been given a new size by the
    VCL, and a user who has resized the dialog did so on purpose.
    Measured in line heights because a CreateNew form has no .dfm for
    the VCL to scale. }
  if not fSized then
  begin
    fSized := True;
    ClientWidth := TmpLine * 58;
    ClientHeight := TmpLine * 44;
  end;

  TmpX := TmpPad;
  TmpY := TmpPad;
  TmpRows := 1;
  for Cont := 0 to High(fCtrls) do
  begin
    TmpCtrl := fCtrls[Cont];
    TmpW := MeasureControl(TmpCtrl, TmpLine);
    { Wrapping rather than clipping. A bar that needs two rows at 200%
      is a bar that needs two rows; hiding the end of it is not an
      improvement. }
    if (TmpX > TmpPad) and (TmpX + TmpW > ClientWidth - TmpPad) then
    begin
      TmpX := TmpPad;
      Inc(TmpY, TmpRowH);
      Inc(TmpRows);
    end;
    if TmpCtrl is TLabel then
      TmpCtrl.SetBounds(TmpX, TmpY + (TmpCtrlH - TmpLine) div 2, TmpW, TmpLine)
    else
      TmpCtrl.SetBounds(TmpX, TmpY, TmpW, TmpCtrlH);
    Inc(TmpX, TmpW + TmpPad);
  end;
  fBar.Height := TmpRows * TmpRowH + TmpPad;

  { Both PPIs, because the difference between them is the whole of this
    problem and the next person to read this log should see it. }
  Log(Format('PrintPreview: layout line %d, font %d, bar %d high in ' +
    '%d row(s), client %d x %d, monitor PPI %d, form PPI %d',
    [TmpLine, Abs(Font.Height), fBar.Height, TmpRows, ClientWidth,
    ClientHeight, TmpPPI, CurrentPPI]));
  finally
    fInLayout := False;
  end;
end;

procedure TPrintPreviewForm.FormShow(Sender: TObject);
begin
  LayoutBar;
end;

procedure TPrintPreviewForm.FormResize(Sender: TObject);
begin
  { The bar wraps to the width it has, so the width changing is a
    layout change. It is also how a DPI change reaches here on a build
    where the monitor event does not: the VCL resizes the window either
    way. }
  LayoutBar;
end;

procedure TPrintPreviewForm.FormAfterMonitorDpiChanged(Sender: TObject;
  OldDPI, NewDPI: Integer);
begin
  { Dragged to a display with a different DPI: the VCL has just rescaled
    the font, so measuring again is the whole of the work. }
  Log(Format('PrintPreview: DPI %d -> %d', [OldDPI, NewDPI]));
  LayoutBar;
end;

function TPrintPreviewForm.SelectedSheet: TCADSheet;
begin
  { Item 0 is the model, so a sheet's index is one less than the box's.
    The list is built once, in BuildControls, and the dialog has no way
    to add a sheet - so there is nothing here to keep in step. }
  Result := nil;
  if (fCAD = nil) or (fSheetBox = nil) then
    Exit;
  if (fSheetBox.ItemIndex <= 0) or
    (fSheetBox.ItemIndex > fCAD.Sheets.Count) then
    Exit;
  Result := fCAD.Sheets[fSheetBox.ItemIndex - 1];
end;

procedure TPrintPreviewForm.ApplySetup;
var
  TmpMargin, TmpScale: Double;
  TmpSheet: TCADSheet;
begin
  fSetup.Paper := TCADPaperKind(fPaper.ItemIndex);
  if fOrientation.ItemIndex = 1 then
    fSetup.Orientation := pgoLandscape
  else
    fSetup.Orientation := pgoPortrait;

  { A half-typed number is not an error, it is somebody typing. The
    previous value stands until the field makes sense again. }
  if TryStrToFloat(fMargin.Text, TmpMargin) and (TmpMargin >= 0) then
    fSetup.Margins := TCADPageMargins.Uniform(TmpMargin);

  if fFit.ItemIndex = 1 then
    fSetup.Fit := pfScale
  else
    fSetup.Fit := pfFitToPage;
  if TryStrToFloat(fScale.Text, TmpScale) and (TmpScale > 0) then
    fSetup.UnitsPerMM := TmpScale;

  fSetup.Tiled := fTiled.Checked;
  fSetup.KeepAspect := True;

  TmpSheet := SelectedSheet;
  fPreview.Setup := fSetup;
  fPreview.Sheet := TmpSheet;

  { A sheet has its own paper, its own margins and a scale per
    viewport, so the page controls have nothing to say about one.
    Disabled rather than hidden: the bar keeps its shape, and it is
    plain what they belong to. }
  fPaper.Enabled := TmpSheet = nil;
  fOrientation.Enabled := TmpSheet = nil;
  fMargin.Enabled := TmpSheet = nil;
  fFit.Enabled := TmpSheet = nil;
  fScale.Enabled := (TmpSheet = nil) and (fSetup.Fit = pfScale);
  fTiled.Enabled := (TmpSheet = nil) and (fSetup.Fit = pfScale);

  if TmpSheet <> nil then
    Log(Format('PrintPreview: sheet %s, %s, %d viewport(s), %d object(s)',
      [TmpSheet.Name, CADPaperKindName(TmpSheet.Paper),
      TmpSheet.ViewportCount, TmpSheet.ObjectsCount]))
  else
    Log(Format('PrintPreview: %s %s, %.1f mm margins, %s, %d page(s)',
      [CADPaperKindName(fSetup.Paper),
      BoolToStr(fSetup.Orientation = pgoLandscape, True),
      fSetup.Margins.Left, BoolToStr(fSetup.Fit = pfScale, True),
      fPreview.PageCount]));
end;

procedure TPrintPreviewForm.SettingChanged(Sender: TObject);
begin
  ApplySetup;
end;

procedure TPrintPreviewForm.PrevClick(Sender: TObject);
begin
  fPreview.PreviousPage;
end;

procedure TPrintPreviewForm.NextClick(Sender: TObject);
begin
  fPreview.NextPage;
end;

procedure TPrintPreviewForm.PageChanged(Sender: TObject; const APageIndex,
  APageCount: Integer);
begin
  fPageLabel.Caption := Format('Page %d of %d', [APageIndex + 1, APageCount]);
  fPrevBtn.Enabled := APageIndex > 0;
  fNextBtn.Enabled := APageIndex < APageCount - 1;
end;

procedure TPrintPreviewForm.PDFClick(Sender: TObject);
var
  TmpDlg: TSaveDialog;
  TmpName: String;
begin
  TmpDlg := TSaveDialog.Create(Self);
  try
    TmpDlg.Filter := 'PDF document|*.pdf';
    TmpDlg.DefaultExt := 'pdf';
    if not TmpDlg.Execute then
      Exit;
    TmpName := TmpDlg.FileName;
  finally
    TmpDlg.Free;
  end;
  { Byte for byte the same routine on both frameworks, because the PDF
    path is framework-free: the page model lays the page out and FNC's
    own PDF engine is a TTMSFNCGraphics like any other. This handler is
    identical in the VCL twin - diff them. }
  Log('PrintPreview: writing ' + TmpName);
  { One sheet or the setup's pages, and the same two lines on both
    frameworks either way. }
  if SelectedSheet <> nil then
    CADSaveSheetsToPDF(fCAD, fCAD.Sheets, TmpName, fSheetBox.ItemIndex - 1,
      fSheetBox.ItemIndex - 1)
  else
    CADSavePagesToPDF(fCAD, fSetup, TmpName);
  Log('PrintPreview: written');
end;

procedure TPrintPreviewForm.PrintClick(Sender: TObject);
var
  TmpDlg: TPrintDialog;
begin
  TmpDlg := TPrintDialog.Create(Self);
  try
    if not TmpDlg.Execute then
      Exit;
  finally
    TmpDlg.Free;
  end;
  Log('PrintPreview: printing');
  { The same setup - or the same sheet - the preview has been drawing,
    onto a printer instead of a window. If the paper does not match the
    preview, the bug is in the page model and both are wrong
    together, which is the point. }
  if SelectedSheet <> nil then
    CADPrintSheets(fCAD, fCAD.Sheets, Printer, fSheetBox.ItemIndex - 1,
      fSheetBox.ItemIndex - 1)
  else
    CADPrintPages(fCAD, fSetup, Printer);
  Log('PrintPreview: printed');
end;

procedure TPrintPreviewForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
