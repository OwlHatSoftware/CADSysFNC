{ : The VCL layers dialog.

  The counterpart of Demos\CAD2D\FMX\LayersFrm.pas, and built in code
  for the same reason: the two demos are meant to be read side by side,
  and a designed .dfm on one side and code on the other makes that
  impossible.

  It replaces the old DefLayersFrm, which used a TColorGrid and a
  TSpinEdit - neither of which has an FMX equivalent. A named
  sixteen-entry palette says the same thing in a way both frameworks can
  express, and the dialog exists to exercise the library's layer model
  rather than to be admired.

  The opacity sliders are not a simplification. Layer colours have
  carried an alpha channel since step 2c, and this is the only place in
  either demo where you can set it. }
unit LayersFrm;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  VCL.FNCCADSys4, VCL.FNCCS4Graphics;

type
  { : What a stacked row is, which decides its height. }
  TRowKind = (rkLabel, rkField, rkSlider, rkCheck);

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

    fRight: TPanel;
    fButtons: TPanel;
    fOK: TButton;

    { Where the next top-aligned control goes - see the note in
      MainFrm: VCL orders aligned controls by position, not by creation
      order. }
    fStackTop: Integer;
    { Every stacked control and what kind of row it is. LayoutDialog
      sizes them from measured text; nothing here has a height in
      pixels. }
    fRows: array of record
      Ctl: TControl;
      Kind: TRowKind;
    end;

    procedure AddRow(const AControl: TControl; const AKind: TRowKind);
    { : Sizes the whole dialog from the font it actually got.

      Called from OnShow, not from BuildUI, for the reason spelled out
      in MainFrm.LayoutToolbar: the VCL scales a form's font but not
      the controls a program creates itself, and it does the scaling
      after the form is constructed. A dialog built in code with
      pixel heights comes out with 24-pixel combo boxes holding
      30-pixel text on a 240 DPI display - cropped, and looking tiny
      beside everything around it.

      FMX needs none of this: its scene is scaled as a whole, so the
      FMX dialog keeps its plain constants. }
    procedure LayoutDialog;
    procedure FormShow(Sender: TObject);
    function AddLabel(const AParent: TWinControl; const AText: string): TLabel;
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

procedure TLayersForm.AddRow(const AControl: TControl;
  const AKind: TRowKind);
begin
  { A provisional position and height so the form is not nonsense
    before it is shown; LayoutDialog replaces both. The Top matters
    even so - the VCL orders top-aligned controls by position, and two
    controls both at zero come out in whatever order the tie-break
    gives. }
  AControl.Top := fStackTop;
  Inc(fStackTop, 28);
  AControl.Height := 24;
  AControl.Align := alTop;
  SetLength(fRows, Length(fRows) + 1);
  fRows[High(fRows)].Ctl := AControl;
  fRows[High(fRows)].Kind := AKind;
end;

function TLayersForm.AddLabel(const AParent: TWinControl;
  const AText: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Caption := AText;
  AddRow(Result, rkLabel);
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
  TmpRight: TPanel;
  TmpButtons: TPanel;
  TmpOK: TButton;
begin
  fStackTop := 0;
  fRows := nil;
  Caption := 'Layers';
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;
  OnShow := FormShow;

  fLayersList := TListBox.Create(Self);
  fLayersList.Parent := Self;
  fLayersList.Align := alLeft;
  fLayersList.OnClick := LayerClick;

  TmpButtons := TPanel.Create(Self);
  TmpButtons.Parent := Self;
  TmpButtons.Align := alBottom;
  TmpButtons.BevelOuter := bvNone;
  fButtons := TmpButtons;

  TmpOK := TButton.Create(Self);
  TmpOK.Parent := TmpButtons;
  TmpOK.Align := alRight;
  TmpOK.AlignWithMargins := True;
  TmpOK.Caption := 'OK';
  fOK := TmpOK;
  TmpOK.Default := True;
  TmpOK.OnClick := OKClick;

  TmpRight := TPanel.Create(Self);
  TmpRight.Parent := Self;
  TmpRight.Align := alClient;
  TmpRight.BevelOuter := bvNone;
  fRight := TmpRight;

  AddLabel(TmpRight, 'Name');
  fNameEdit := TEdit.Create(Self);
  fNameEdit.Parent := TmpRight;
  AddRow(fNameEdit, rkField);

  AddLabel(TmpRight, 'Pen width');
  fPenWidthEdit := TEdit.Create(Self);
  fPenWidthEdit.Parent := TmpRight;
  AddRow(fPenWidthEdit, rkField);

  AddLabel(TmpRight, 'Pen colour');
  fPenColorBox := TComboBox.Create(Self);
  fPenColorBox.Parent := TmpRight;
  fPenColorBox.Style := csDropDownList;
  AddRow(fPenColorBox, rkField);
  FillPalette(fPenColorBox);

  AddLabel(TmpRight, 'Pen style');
  fPenStyleBox := TComboBox.Create(Self);
  fPenStyleBox.Parent := TmpRight;
  fPenStyleBox.Style := csDropDownList;
  AddRow(fPenStyleBox, rkField);
  FillNames(fPenStyleBox, PenStyleNames);

  fPenAlphaLbl := AddLabel(TmpRight, 'Pen opacity');
  fPenAlpha := TTrackBar.Create(Self);
  fPenAlpha.Parent := TmpRight;
  AddRow(fPenAlpha, rkSlider);
  fPenAlpha.Min := 0;
  fPenAlpha.Max := 255;
  fPenAlpha.OnChange := AlphaChange;

  AddLabel(TmpRight, 'Brush colour');
  fBrushColorBox := TComboBox.Create(Self);
  fBrushColorBox.Parent := TmpRight;
  fBrushColorBox.Style := csDropDownList;
  AddRow(fBrushColorBox, rkField);
  FillPalette(fBrushColorBox);

  AddLabel(TmpRight, 'Brush style');
  fBrushStyleBox := TComboBox.Create(Self);
  fBrushStyleBox.Parent := TmpRight;
  fBrushStyleBox.Style := csDropDownList;
  AddRow(fBrushStyleBox, rkField);
  FillNames(fBrushStyleBox, BrushStyleNames);

  fBrushAlphaLbl := AddLabel(TmpRight, 'Brush opacity');
  fBrushAlpha := TTrackBar.Create(Self);
  fBrushAlpha.Parent := TmpRight;
  AddRow(fBrushAlpha, rkSlider);
  fBrushAlpha.Min := 0;
  fBrushAlpha.Max := 255;
  fBrushAlpha.OnChange := AlphaChange;

  fTransparentChk := TCheckBox.Create(Self);
  fTransparentChk.Parent := TmpRight;
  fTransparentChk.Caption := 'Transparent';
  AddRow(fTransparentChk, rkCheck);

  fActiveChk := TCheckBox.Create(Self);
  fActiveChk.Parent := TmpRight;
  fActiveChk.Caption := 'Active';
  AddRow(fActiveChk, rkCheck);

  fVisibleChk := TCheckBox.Create(Self);
  fVisibleChk.Parent := TmpRight;
  fVisibleChk.Caption := 'Visible';
  AddRow(fVisibleChk, rkCheck);

  AddLabel(TmpRight, 'Current layer');
  fActiveLayerBox := TComboBox.Create(Self);
  fActiveLayerBox.Parent := TmpRight;
  fActiveLayerBox.Style := csDropDownList;
  AddRow(fActiveLayerBox, rkField);
end;

procedure TLayersForm.LayoutDialog;
var
  Cont, Line, Gap, Top, H: Integer;
begin
  { Measured, not assumed. Everything below is a multiple of the height
    of a line of the form's own font, so the dialog is right at any
    DPI without knowing what the DPI is. }
  Canvas.Font := Font;
  Line := Canvas.TextHeight('Wg');
  if Line < 8 then
    Line := 8;
  Gap := Line div 3;

  Top := 0;
  for Cont := 0 to High(fRows) do
  begin
    case fRows[Cont].Kind of
      rkLabel:
        H := Line + Gap;
      rkSlider:
        H := Line * 5 div 2;
      rkCheck:
        H := Line + Gap * 2;
    else
      { rkField - an edit or a combo. Two lines, the same as the
        toolbar buttons in MainFrm, which is what stops the text being
        cropped by its own box. }
      H := Line * 2;
    end;
    fRows[Cont].Ctl.Top := Top;
    fRows[Cont].Ctl.Height := H;
    Inc(Top, H + Gap);
  end;

  fRight.Padding.SetBounds(Gap * 2, Gap * 2, Gap * 2, Gap * 2);
  fLayersList.Width := Line * 16;
  fButtons.Height := Line * 3;
  fOK.Margins.SetBounds(0, Gap, Gap * 2, Gap);
  fOK.Width := Line * 7;

  { Sized to what the rows actually came to, so the last one cannot be
    cropped however the font turns out. }
  ClientWidth := fLayersList.Width + Line * 24;
  ClientHeight := Top + Gap * 4 + fButtons.Height;
end;

procedure TLayersForm.FormShow(Sender: TObject);
begin
  LayoutDialog;
end;

procedure TLayersForm.ShowAlphaValues;
begin
  fPenAlphaLbl.Caption := Format('Pen opacity: %d', [fPenAlpha.Position]);
  fBrushAlphaLbl.Caption := Format('Brush opacity: %d',
    [fBrushAlpha.Position]);
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
    fPenColorBox.ItemIndex := PaletteIndexOf(CADColorToTColor(Pen.Color));
    fBrushColorBox.ItemIndex := PaletteIndexOf(CADColorToTColor(Brush.Color));
    fPenStyleBox.ItemIndex := Ord(Pen.Style);
    fBrushStyleBox.ItemIndex := Ord(Brush.Style);
    fPenAlpha.Position := CADColorAlpha(Pen.Color);
    fBrushAlpha.Position := CADColorAlpha(Brush.Color);
    fTransparentChk.Checked := not Opaque;
    fActiveChk.Checked := Active;
    fVisibleChk.Checked := Visible;
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
      fPenAlpha.Position);
    Brush.Color := CADColorSetAlpha(
      TColorToCADColor(PaletteValues[Max(0, fBrushColorBox.ItemIndex)]),
      fBrushAlpha.Position);
    Pen.Style := TCADPenStyle(Max(0, fPenStyleBox.ItemIndex));
    Brush.Style := TCADBrushStyle(Max(0, fBrushStyleBox.ItemIndex));
    Opaque := not fTransparentChk.Checked;
    Active := fActiveChk.Checked;
    Visible := fVisibleChk.Checked;
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
