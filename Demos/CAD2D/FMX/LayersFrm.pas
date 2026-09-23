{ : The FMX layers dialog - the counterpart of the VCL demo's
  DefLayersFrm.

  Built entirely in code, like the rest of this demo, so there is no
  .fmx resource to keep in step.

  One deliberate difference from the VCL original: colours are chosen
  from a named sixteen-entry palette rather than a colour grid. FMX has
  no TColorGrid, and the alternatives (TComboColorBox and friends) have
  moved between units across versions. A combo of named colours is
  plain, compiles everywhere, and this dialog exists to exercise the
  library's layer model rather than to be admired.

  The opacity sliders are not a simplification - they are the point.
  Layer colours carry an alpha channel since step 2c, and this is the
  only place in either demo where you can set it. }
unit LayersFrm;

{$I FMX.FNCCADSys.inc}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Layouts, FMX.Controls.Presentation,
  FMX.FNCCADSys4, FMX.FNCCS4Graphics;

type
  TLayersForm = class(TForm)
  private
    fCADCmp: TFNCCADCmp;
    fCurrLayer: Integer;
    fLayersList: TListBox;
    fActiveLayerBox: TComboBox;
    fNameEdit: TEdit;
    fPenWidthEdit: TEdit;
    fPenColorBox: TComboBox;
    fBrushColorBox: TComboBox;
    fPenStyleBox: TComboBox;
    fBrushStyleBox: TComboBox;
    fPenAlpha: TTrackBar;
    fBrushAlpha: TTrackBar;
    fPenAlphaLbl: TLabel;
    fBrushAlphaLbl: TLabel;
    fTransparentChk: TCheckBox;
    fActiveChk: TCheckBox;
    fVisibleChk: TCheckBox;

    function AddLabel(const AParent: TFmxObject; const AText: string): TLabel;
    procedure BuildUI;
    procedure FillPalette(const ABox: TComboBox);
    procedure FillNames(const ABox: TComboBox; const ANames: array of string);
    procedure AlphaChange(Sender: TObject);
    procedure LayerClick(Sender: TObject);
    procedure OKClick(Sender: TObject);
    procedure ShowAlphaValues;
    procedure LoadLayer(const AIndex: Integer);
    procedure SaveLayer;
  public
    procedure Execute(const ACADCmp: TFNCCADCmp);
  end;

implementation

{ The sixteen standard CAD colours, as TColor. Named rather than
  displayed as swatches: the point is to pick a known value, not to
  browse. }
const
  PaletteNames: array [0 .. 15] of string = ('Black', 'Maroon', 'Green',
    'Olive', 'Navy', 'Purple', 'Teal', 'Gray', 'Silver', 'Red', 'Lime',
    'Yellow', 'Blue', 'Fuchsia', 'Aqua', 'White');
  PaletteValues: array [0 .. 15] of TColor = ($000000, $000080, $008000,
    $008080, $800000, $800080, $808000, $808080, $C0C0C0, $0000FF, $00FF00,
    $00FFFF, $FF0000, $FF00FF, $FFFF00, $FFFFFF);

{ The pen and brush styles, in declaration order so the combo's
  ItemIndex is the ordinal. Named, not drawn: a sample swatch would
  have to be rendered by the very code under test. }
const
  PenStyleNames: array [0 .. 8] of string = ('Solid', 'Dash', 'Dot',
    'DashDot', 'DashDotDot', 'Clear', 'InsideFrame', 'UserStyle',
    'Alternate');
  BrushStyleNames: array [0 .. 7] of string = ('Solid', 'Clear',
    'Horizontal', 'Vertical', 'FDiagonal', 'BDiagonal', 'Cross',
    'DiagCross');

function PaletteIndexOf(const AColor: TColor): Integer;
var
  Cont: Integer;
begin
  for Cont := 0 to High(PaletteValues) do
    if PaletteValues[Cont] = AColor then
      Exit(Cont);
  Result := 0;
end;

function TLayersForm.AddLabel(const AParent: TFmxObject;
  const AText: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Height := 20;
  Result.Text := AText;
end;

procedure TLayersForm.FillPalette(const ABox: TComboBox);
var
  Cont: Integer;
begin
  for Cont := 0 to High(PaletteNames) do
    ABox.Items.Add(PaletteNames[Cont]);
  ABox.ItemIndex := 0;
end;

procedure TLayersForm.FillNames(const ABox: TComboBox;
  const ANames: array of string);
var
  Cont: Integer;
begin
  for Cont := 0 to High(ANames) do
    ABox.Items.Add(ANames[Cont]);
  ABox.ItemIndex := 0;
end;

procedure TLayersForm.BuildUI;
var
  TmpRight: TLayout;
  TmpButtons: TLayout;
  TmpOK: TButton;
begin
  Caption := 'Layers';
  Width := 620;
  Height := 560;

  fLayersList := TListBox.Create(Self);
  fLayersList.Parent := Self;
  fLayersList.Align := TAlignLayout.Left;
  fLayersList.Width := 220;
  fLayersList.OnClick := LayerClick;

  TmpButtons := TLayout.Create(Self);
  TmpButtons.Parent := Self;
  TmpButtons.Align := TAlignLayout.Bottom;
  TmpButtons.Height := 44;

  TmpOK := TButton.Create(Self);
  TmpOK.Parent := TmpButtons;
  TmpOK.Align := TAlignLayout.Right;
  TmpOK.Margins.Rect := RectF(0, 8, 8, 8);
  TmpOK.Width := 90;
  TmpOK.Text := 'OK';
  TmpOK.OnClick := OKClick;

  TmpRight := TLayout.Create(Self);
  TmpRight.Parent := Self;
  TmpRight.Align := TAlignLayout.Client;
  TmpRight.Padding.Rect := RectF(10, 10, 10, 10);

  AddLabel(TmpRight, 'Name');
  fNameEdit := TEdit.Create(Self);
  fNameEdit.Parent := TmpRight;
  fNameEdit.Align := TAlignLayout.Top;

  AddLabel(TmpRight, 'Pen width');
  fPenWidthEdit := TEdit.Create(Self);
  fPenWidthEdit.Parent := TmpRight;
  fPenWidthEdit.Align := TAlignLayout.Top;

  AddLabel(TmpRight, 'Pen colour');
  fPenColorBox := TComboBox.Create(Self);
  fPenColorBox.Parent := TmpRight;
  fPenColorBox.Align := TAlignLayout.Top;
  FillPalette(fPenColorBox);

  AddLabel(TmpRight, 'Pen style');
  fPenStyleBox := TComboBox.Create(Self);
  fPenStyleBox.Parent := TmpRight;
  fPenStyleBox.Align := TAlignLayout.Top;
  FillNames(fPenStyleBox, PenStyleNames);

  fPenAlphaLbl := AddLabel(TmpRight, 'Pen opacity');
  fPenAlpha := TTrackBar.Create(Self);
  fPenAlpha.Parent := TmpRight;
  fPenAlpha.Align := TAlignLayout.Top;
  fPenAlpha.Min := 0;
  fPenAlpha.Max := 255;
  fPenAlpha.OnChange := AlphaChange;

  AddLabel(TmpRight, 'Brush colour');
  fBrushColorBox := TComboBox.Create(Self);
  fBrushColorBox.Parent := TmpRight;
  fBrushColorBox.Align := TAlignLayout.Top;
  FillPalette(fBrushColorBox);

  AddLabel(TmpRight, 'Brush style');
  fBrushStyleBox := TComboBox.Create(Self);
  fBrushStyleBox.Parent := TmpRight;
  fBrushStyleBox.Align := TAlignLayout.Top;
  FillNames(fBrushStyleBox, BrushStyleNames);

  fBrushAlphaLbl := AddLabel(TmpRight, 'Brush opacity');
  fBrushAlpha := TTrackBar.Create(Self);
  fBrushAlpha.Parent := TmpRight;
  fBrushAlpha.Align := TAlignLayout.Top;
  fBrushAlpha.Min := 0;
  fBrushAlpha.Max := 255;
  fBrushAlpha.OnChange := AlphaChange;

  fTransparentChk := TCheckBox.Create(Self);
  fTransparentChk.Parent := TmpRight;
  fTransparentChk.Align := TAlignLayout.Top;
  fTransparentChk.Height := 24;
  fTransparentChk.Text := 'Transparent';

  fActiveChk := TCheckBox.Create(Self);
  fActiveChk.Parent := TmpRight;
  fActiveChk.Align := TAlignLayout.Top;
  fActiveChk.Height := 24;
  fActiveChk.Text := 'Active';

  fVisibleChk := TCheckBox.Create(Self);
  fVisibleChk.Parent := TmpRight;
  fVisibleChk.Align := TAlignLayout.Top;
  fVisibleChk.Height := 24;
  fVisibleChk.Text := 'Visible';

  AddLabel(TmpRight, 'Current layer');
  fActiveLayerBox := TComboBox.Create(Self);
  fActiveLayerBox.Parent := TmpRight;
  fActiveLayerBox.Align := TAlignLayout.Top;
end;

procedure TLayersForm.ShowAlphaValues;
begin
  fPenAlphaLbl.Text := Format('Pen opacity: %d', [Round(fPenAlpha.Value)]);
  fBrushAlphaLbl.Text := Format('Brush opacity: %d',
    [Round(fBrushAlpha.Value)]);
end;

procedure TLayersForm.AlphaChange(Sender: TObject);
begin
  ShowAlphaValues;
end;

procedure TLayersForm.LoadLayer(const AIndex: Integer);
begin
  fCurrLayer := AIndex;
  if (fCurrLayer < 0) or (fCurrLayer > 255) then
    Exit;
  with fCADCmp.Layers[fCurrLayer] do
  begin
    fNameEdit.Text := Name;
    fPenWidthEdit.Text := IntToStr(Pen.Width);
    fPenColorBox.ItemIndex :=
      PaletteIndexOf(CADColorToTColor(Pen.Color));
    fBrushColorBox.ItemIndex :=
      PaletteIndexOf(CADColorToTColor(Brush.Color));
    fPenStyleBox.ItemIndex := Ord(Pen.Style);
    fBrushStyleBox.ItemIndex := Ord(Brush.Style);
    fPenAlpha.Value := CADColorAlpha(Pen.Color);
    fBrushAlpha.Value := CADColorAlpha(Brush.Color);
    fTransparentChk.IsChecked := not Opaque;
    fActiveChk.IsChecked := Active;
    fVisibleChk.IsChecked := Visible;
  end;
  ShowAlphaValues;
end;

procedure TLayersForm.SaveLayer;
begin
  if (fCurrLayer < 0) or (fCurrLayer > 255) then
    Exit;
  with fCADCmp.Layers[fCurrLayer] do
  begin
    Name := fNameEdit.Text;
    Pen.Width := StrToIntDef(fPenWidthEdit.Text, 1);
    { The palette gives a TColor; the slider supplies the alpha channel
      that layer colours have carried since step 2c. }
    Pen.Color := CADColorSetAlpha(
      TColorToCADColor(PaletteValues[Max(0, fPenColorBox.ItemIndex)]),
      Round(fPenAlpha.Value));
    Brush.Color := CADColorSetAlpha(
      TColorToCADColor(PaletteValues[Max(0, fBrushColorBox.ItemIndex)]),
      Round(fBrushAlpha.Value));
    Pen.Style := TCADPenStyle(Max(0, fPenStyleBox.ItemIndex));
    Brush.Style := TCADBrushStyle(Max(0, fBrushStyleBox.ItemIndex));
    Opaque := not fTransparentChk.IsChecked;
    Active := fActiveChk.IsChecked;
    Visible := fVisibleChk.IsChecked;
  end;
end;

procedure TLayersForm.LayerClick(Sender: TObject);
begin
  if fLayersList.ItemIndex = fCurrLayer then
    Exit;
  SaveLayer;
  LoadLayer(fLayersList.ItemIndex);
end;

procedure TLayersForm.OKClick(Sender: TObject);
begin
  SaveLayer;
  if fActiveLayerBox.ItemIndex >= 0 then
    fCADCmp.CurrentLayer := fActiveLayerBox.ItemIndex;
  ModalResult := mrOk;
end;

procedure TLayersForm.Execute(const ACADCmp: TFNCCADCmp);
var
  Cont: Integer;
  TmpStr: string;
begin
  fCADCmp := ACADCmp;
  fCurrLayer := -1;
  BuildUI;
  for Cont := 0 to 255 do
  begin
    TmpStr := Format('%d - %s', [Cont, fCADCmp.Layers[Cont].Name]);
    fLayersList.Items.Add(TmpStr);
    fActiveLayerBox.Items.Add(TmpStr);
  end;
  fLayersList.ItemIndex := 0;
  LoadLayer(0);
  fActiveLayerBox.ItemIndex := fCADCmp.CurrentLayer;
  ShowModal;
end;

end.
