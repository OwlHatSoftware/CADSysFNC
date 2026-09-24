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
  FMX.FNCCS4Print, FMX.FNCCS4Preview;

type
  TPrintPreviewForm = class(TForm)
  private
    fPreview: TFNCPrintPreview;
    fBar: TLayout;
    fPaper: TComboBox;
    fOrientation: TComboBox;
    fFit: TComboBox;
    fScale: TEdit;
    fTiled: TCheckBox;
    fMargin: TEdit;
    fPageLabel: TLabel;
    fPrevBtn, fNextBtn, fPrintBtn, fCloseBtn: TButton;
    { : The bar's controls in the order they were added, which is the
      order they are laid out in. }
    fCtrls: array of TControl;
    fCAD: TFNCCADCmp2D;
    fSetup: TCADPageSetup;
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
    procedure ApplySetup;
    procedure SettingChanged(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure PrintClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure PageChanged(Sender: TObject; const APageIndex,
      APageCount: Integer);
    procedure FormShow(Sender: TObject);
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
begin
  Caption := 'Print preview';
  Position := TFormPosition.OwnerFormCenter;
  OnShow := FormShow;

  fBar := TLayout.Create(Self);
  fBar.Parent := Self;
  fBar.Align := TAlignLayout.Top;

  { Created here, placed in LayoutBar - the same split as the VCL side,
    where it is forced by the framework rather than chosen. }
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

  Width := TmpLine * 58;
  Height := TmpLine * 44;

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
end;

procedure TPrintPreviewForm.FormShow(Sender: TObject);
begin
  LayoutBar;
end;

procedure TPrintPreviewForm.ApplySetup;
var
  TmpMargin, TmpScale: Double;
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

  fScale.Enabled := fSetup.Fit = pfScale;
  fTiled.Enabled := fSetup.Fit = pfScale;

  fPreview.Setup := fSetup;
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

procedure TPrintPreviewForm.PrintClick(Sender: TObject);
begin
  { The substantive difference between this file and its VCL twin.
    Printing is CADPrintPages in VCL.FNCCS4ExportVCL, which is VCL-only
    by construction - it wants a TPrinter and a GDI device context. The
    page model underneath is not, so an FMX printer path is a unit to
    write rather than a design to redo. }
  Log('PrintPreview: print asked for on FMX');
  ShowMessage('Printing is VCL-only for now. The preview is the library''s '
    + 'own control and draws through exactly the same page model the '
    + 'printer uses, so what you see here is what an FMX printer path '
    + 'would produce once there is one.');
end;

procedure TPrintPreviewForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
