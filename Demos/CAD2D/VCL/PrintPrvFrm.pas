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
  VCL.FNCCS4Print, VCL.FNCCS4Preview, VCL.FNCCS4ExportVCL;

type
  TPrintPreviewForm = class(TForm)
  private
    fPreview: TFNCPrintPreview;
    fBar: TPanel;
    fPaper: TComboBox;
    fOrientation: TComboBox;
    fFit: TComboBox;
    fScale: TEdit;
    fTiled: TCheckBox;
    fMargin: TEdit;
    fPageLabel: TLabel;
    fPrevBtn, fNextBtn, fPrintBtn, fCloseBtn: TButton;
    { : The bar's controls in the order they were added, which is the
      order they are laid out in. A list rather than ControlCount,
      because the VCL orders aligned controls by position and the
      positions are what LayoutBar is about to decide. }
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
    { : How wide this control has to be for its own text not to clip.
      See the note in LayoutBar for why it is measured rather than
      chosen. }
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
begin
  Caption := 'Print preview';
  Position := poOwnerFormCenter;
  OnShow := FormShow;
  OnAfterMonitorDpiChanged := FormAfterMonitorDpiChanged;

  fBar := TPanel.Create(Self);
  fBar.Parent := Self;
  fBar.Align := alTop;
  fBar.BevelOuter := bvNone;

  { Created here, placed in LayoutBar. Nothing gets a position or a size
    in this method, because neither can be known until the form has been
    shown and the VCL has scaled its font. }
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
  TmpCtrl: TControl;
begin
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
  Canvas.Font := Font;
  TmpLine := Canvas.TextHeight('Wg');
  if TmpLine < 8 then
    TmpLine := 15;
  TmpPad := Max(TmpLine div 2, 4);
  TmpCtrlH := TmpLine * 2;
  TmpRowH := TmpCtrlH + TmpPad;

  { A CreateNew form has no .dfm, so nothing scales its size either.
    Measured in line heights for the same reason as everything else. }
  ClientWidth := TmpLine * 58;
  ClientHeight := TmpLine * 44;

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

  Log(Format('PrintPreview: layout line %d, bar %d high in %d row(s), ' +
    'form PPI %d', [TmpLine, fBar.Height, TmpRows, CurrentPPI]));
end;

procedure TPrintPreviewForm.FormShow(Sender: TObject);
begin
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

  fSetup.Tiled := fTiled.Checked;
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
  fPageLabel.Caption := Format('Page %d of %d', [APageIndex + 1, APageCount]);
  fPrevBtn.Enabled := APageIndex > 0;
  fNextBtn.Enabled := APageIndex < APageCount - 1;
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
  { The same setup the preview has been drawing, onto a printer instead
    of a window. If the paper does not match the preview, the bug is in
    the page model and both are wrong together - which is the point. }
  CADPrintPages(fCAD, fSetup, Printer);
  Log('PrintPreview: printed');
end;

procedure TPrintPreviewForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
