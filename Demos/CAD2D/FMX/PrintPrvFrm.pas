{ : The print preview dialog, FMX.

  Demos\CAD2D\VCL\PrintPrvFrm.pas is the same dialog written for the
  VCL - same class name, same Execute, same handler names, same order.
  Diff them. The one substantive difference is at the bottom: the Print
  button prints there and says what is missing here, because printing
  lives in VCL.FNCCS4ExportVCL and has no FMX equivalent yet.

  The preview itself is the library's TFNCPrintPreview, unchanged from
  the VCL side. It is an FNC control drawing through the same
  CADDrawPage the printer uses, so a page looks the same on both
  frameworks without either demo doing anything about it. That is worth
  more than the printing this side is missing. }
unit PrintPrvFrm;

{$I FMX.FNCCADSys.inc}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
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
    fCAD: TFNCCADCmp2D;
    fSetup: TCADPageSetup;
    procedure BuildControls;
    function AddLabel(const ACaption: string; var ALeft: Integer): TLabel;
    function AddCombo(const AItems: array of string; const AIndex,
      AWidth: Integer; var ALeft: Integer): TComboBox;
    function AddEdit(const AText: string; const AWidth: Integer;
      var ALeft: Integer): TEdit;
    function AddButton(const ACaption: string; const AWidth: Integer;
      const AClick: TNotifyEvent; var ALeft: Integer): TButton;
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

function TPrintPreviewForm.AddLabel(const ACaption: string;
  var ALeft: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := fBar;
  Result.Text := ACaption;
  Result.Position.X := ALeft;
  Result.Position.Y := 12;
  Result.Width := 8 * Length(ACaption) + 8;
  ALeft := ALeft + Round(Result.Width) + 6;
end;

function TPrintPreviewForm.AddCombo(const AItems: array of string;
  const AIndex, AWidth: Integer; var ALeft: Integer): TComboBox;
var
  Cont: Integer;
begin
  Result := TComboBox.Create(Self);
  Result.Parent := fBar;
  for Cont := Low(AItems) to High(AItems) do
    Result.Items.Add(AItems[Cont]);
  Result.ItemIndex := AIndex;
  Result.Position.X := ALeft;
  Result.Position.Y := 8;
  Result.Width := AWidth;
  Result.OnChange := SettingChanged;
  ALeft := ALeft + AWidth + 10;
end;

function TPrintPreviewForm.AddEdit(const AText: string; const AWidth: Integer;
  var ALeft: Integer): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := fBar;
  Result.Text := AText;
  Result.Position.X := ALeft;
  Result.Position.Y := 8;
  Result.Width := AWidth;
  Result.OnChangeTracking := SettingChanged;
  ALeft := ALeft + AWidth + 10;
end;

function TPrintPreviewForm.AddButton(const ACaption: string;
  const AWidth: Integer; const AClick: TNotifyEvent;
  var ALeft: Integer): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := fBar;
  Result.Text := ACaption;
  Result.Position.X := ALeft;
  Result.Position.Y := 7;
  Result.Width := AWidth;
  Result.OnClick := AClick;
  ALeft := ALeft + AWidth + 6;
end;

procedure TPrintPreviewForm.BuildControls;
var
  TmpLeft: Integer;
begin
  Caption := 'Print preview';
  Position := TFormPosition.OwnerFormCenter;
  Width := 900;
  Height := 700;

  fBar := TLayout.Create(Self);
  fBar.Parent := Self;
  fBar.Align := TAlignLayout.Top;
  fBar.Height := 44;

  TmpLeft := 8;
  AddLabel('Paper', TmpLeft);
  fPaper := AddCombo(['A5', 'A4', 'A3', 'A2', 'A1', 'A0', 'Letter', 'Legal',
    'Tabloid'], 1, 80, TmpLeft);
  fOrientation := AddCombo(['Portrait', 'Landscape'], 0, 90, TmpLeft);
  AddLabel('Margin mm', TmpLeft);
  fMargin := AddEdit('10', 40, TmpLeft);
  fFit := AddCombo(['Fit to page', 'To scale'], 0, 100, TmpLeft);
  AddLabel('units/mm', TmpLeft);
  fScale := AddEdit('1', 50, TmpLeft);

  fTiled := TCheckBox.Create(Self);
  fTiled.Parent := fBar;
  fTiled.Text := 'Tiled';
  fTiled.Position.X := TmpLeft;
  fTiled.Position.Y := 12;
  fTiled.Width := 55;
  fTiled.OnChange := SettingChanged;
  TmpLeft := TmpLeft + 65;

  fPrevBtn := AddButton('<', 30, PrevClick, TmpLeft);
  fNextBtn := AddButton('>', 30, NextClick, TmpLeft);
  fPageLabel := AddLabel('Page 1 of 1', TmpLeft);
  fPageLabel.Width := 90;
  TmpLeft := TmpLeft + 40;
  fPrintBtn := AddButton('Print...', 70, PrintClick, TmpLeft);
  fCloseBtn := AddButton('Close', 70, CloseClick, TmpLeft);

  fPreview := TFNCPrintPreview.Create(Self);
  fPreview.Parent := Self;
  fPreview.Align := TAlignLayout.Client;
  fPreview.CADCmp := fCAD;
  fPreview.OnPageChanged := PageChanged;
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
