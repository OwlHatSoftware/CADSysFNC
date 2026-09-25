{ : The print preview dialog, FMX.

  Demos\CAD2D\VCL\PrintPrvFrm.pas is the same dialog written for the
  VCL - same class name, same Execute, same handler names, same order.
  Diff them. Two things differ and both are substantive: the Print
  button prints there and says what is missing here, and LayoutBar uses
  plain numbers here and measures the font there.

  The preview itself is the library's TFNCPrintPreview, unchanged from
  the VCL side. It is an FNC control drawing through the same
  CADDrawPage the printer uses, so a page looks the same on both
  frameworks without either demo doing anything about it. That is worth
  more than the printing this side is missing. }
unit PrintPrvFrm;

{$I FMX.FNCCADSys.inc}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.ListBox,
  FMX.Layouts, FMX.Controls.Presentation, FMX.Dialogs,
  DemoLog,
  FMX.FNCCS4BaseTypes, FMX.FNCCS4Graphics, FMX.FNCCADSys4, FMX.FNCCS4Views,
  FMX.FNCCS4Print, FMX.FNCCS4Preview, FMX.FNCCS4PDF;

type
  TPrintPreviewForm = class(TForm)
  private
    fPreview: TFNCPrintPreview;
    fBar: TLayout;
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
      order they are laid out in. }
    fCtrls: array of TControl;
    fCAD: TFNCCADCmp2D;
    fSetup: TCADPageSetup;
    { : False until the first layout has chosen the dialog's size. }
    fSized: Boolean;
    { : LayoutBar sets fBar.Height, which OnResize is listening to. }
    fInLayout: Boolean;
    procedure BuildControls;
    procedure Track(const ACtrl: TControl);
    function AddLabel(const ACaption: string): TLabel;
    function AddCombo(const AItems: array of string;
      const AIndex: Integer): TComboBox;
    function AddEdit(const AText: string): TEdit;
    function AddButton(const ACaption: string;
      const AClick: TNotifyEvent): TButton;
    { : How wide this control has to be. Chosen rather than measured -
      see the note in LayoutBar. }
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
  Result.Text := ACaption;
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
  Result.OnChangeTracking := SettingChanged;
  Track(Result);
end;

function TPrintPreviewForm.AddButton(const ACaption: string;
  const AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := fBar;
  Result.Text := ACaption;
  Result.OnClick := AClick;
  Track(Result);
end;

procedure TPrintPreviewForm.BuildControls;
var
  Cont: Integer;
begin
  Caption := 'Print preview';
  Position := TFormPosition.OwnerFormCenter;
  { No Scaled here, and no monitor-DPI hook: FMX coordinates are
    logical and the platform scales the scene. The VCL twin needs both
    - see the note in its BuildControls. }
  OnShow := FormShow;
  OnResize := FormResize;

  fBar := TLayout.Create(Self);
  fBar.Parent := Self;
  fBar.Align := TAlignLayout.Top;

  { Created here, placed in LayoutBar - the same split as the VCL side,
    where it is forced by the framework rather than chosen. }
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
  fTiled.Text := 'Tiled';
  fTiled.OnChange := SettingChanged;
  Track(fTiled);

  fPrevBtn := AddButton('<', PrevClick);
  fNextBtn := AddButton('>', NextClick);
  fPageLabel := AddLabel('Page 1 of 1');
  fPrintBtn := AddButton('Print...', PrintClick);
  fPDFBtn := AddButton('PDF...', PDFClick);
  fCloseBtn := AddButton('Close', CloseClick);

  fPreview := TFNCPrintPreview.Create(Self);
  fPreview.Parent := Self;
  fPreview.Align := TAlignLayout.Client;
  fPreview.CADCmp := fCAD;
  fPreview.OnPageChanged := PageChanged;
end;

function TPrintPreviewForm.MeasureControl(const ACtrl: TControl;
  const ALine: Integer): Integer;
begin
  { Plain numbers, in the same shape as the VCL's measurements, so the
    two files still diff to their real difference. A character is about
    half a line high in the default font, which is close enough when the
    platform is doing the scaling. }
  if ACtrl = fPageLabel then
    Result := ALine * 7
  else if ACtrl is TLabel then
    Result := Round(TLabel(ACtrl).Text.Length * ALine * 0.55) + ALine div 2
  else if ACtrl is TComboBox then
    Result := ALine * 7
  else if ACtrl is TEdit then
    Result := ALine * 3
  else if ACtrl is TCheckBox then
    Result := ALine * 4
  else if ACtrl is TButton then
    Result := Max(ALine * 2,
      Round(TButton(ACtrl).Text.Length * ALine * 0.55)) + ALine * 2
  else
    Result := ALine * 4;
end;

procedure TPrintPreviewForm.LayoutBar;
var
  TmpLine, TmpPad, TmpCtrlH, TmpRowH, TmpX, TmpY, TmpRows, TmpW, Cont: Integer;
  TmpCtrl: TControl;
begin
  if fInLayout then
    Exit;
  fInLayout := True;
  try
  { Plain numbers, and they can be: FMX coordinates are logical and the
    platform scales the whole scene, so these look the same at any DPI.
    The VCL twin has to measure its font instead, from OnShow, because
    the VCL scales a form's font after OnCreate and never scales
    controls created at run time - which is exactly how that dialog came
    out with a 150% font in 100% boxes. The shape is kept the same on
    both sides so the difference is visible in a diff rather than
    hidden. }
  TmpLine := 15;
  TmpPad := Max(TmpLine div 2, 4);
  TmpCtrlH := TmpLine * 2;
  TmpRowH := TmpCtrlH + TmpPad;

  { The opening size only - after that the window belongs to whoever is
    holding it. }
  if not fSized then
  begin
    fSized := True;
    Width := TmpLine * 58;
    Height := TmpLine * 44;
  end;

  TmpX := TmpPad;
  TmpY := TmpPad;
  TmpRows := 1;
  for Cont := 0 to High(fCtrls) do
  begin
    TmpCtrl := fCtrls[Cont];
    TmpW := MeasureControl(TmpCtrl, TmpLine);
    if (TmpX > TmpPad) and (TmpX + TmpW > Width - TmpPad) then
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

  Log(Format('PrintPreview: layout line %d, bar %d high in %d row(s)',
    [TmpLine, Round(fBar.Height), TmpRows]));
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
    layout change - the same on both sides. }
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

  fSetup.Tiled := fTiled.IsChecked;
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
  fPageLabel.Text := Format('Page %d of %d', [APageIndex + 1, APageCount]);
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
begin
  { The substantive difference between this file and its VCL twin.
    Printing is CADPrintPages in VCL.FNCCS4ExportVCL, which is VCL-only
    by construction - it wants a TPrinter and a GDI device context. The
    page model underneath is not, so an FMX printer path is a unit to
    write rather than a design to redo. }
  Log('PrintPreview: print asked for on FMX');
  ShowMessage('Sending pages to a printer is VCL-only for now. PDF is not: '
    + 'the PDF button beside this one works here exactly as it does on '
    + 'the VCL side, from the same page model, and most things that want '
    + 'a printed drawing will take a PDF.');
end;

procedure TPrintPreviewForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
