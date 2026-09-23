{ : The FMX port of the CAD2D demo.

  It follows Demos\CAD2D\VCL\MainFrm.pas handler for handler, so the
  two can be compared side by side and a difference in behaviour is a
  difference in the library rather than in the demo. Where something had
  to change, there is a comment saying why.

  Everything is built in code. The .fmx holds nothing but the form, so
  there is no resource to go stale and nothing here needs the IDE to
  have been opened.

  Three things are genuinely different from the VCL demo:

  <LI=Printing and clipboard are absent. They live in FNCCS4ExportVCL,
  which is VCL-only by construction - GDI and TClipboard have no FMX
  counterpart in this library yet. The menu items are present and say
  so, rather than being quietly missing.>
  <LI=The toolbar buttons show the running operation by their text
  rather than by TToolButton.Indeterminate, which FMX has no equivalent
  of.>
  <LI=Colours in the layers dialog come from a named palette; FMX has no
  TColorGrid.> }
unit MainFrm;

{$I ..\..\..\Sources\CADSys.inc}

{$IFNDEF CADSYS_FMX}
{$MESSAGE Fatal 'This demo must be compiled with CADSYS_FMX defined. Without it CADSys.inc selects the VCL, TFNCRuler and the viewports descend from the VCL TTMSFNCCustomControl, and their Parent is a TWinControl - which is what an unhelpful E2010 about TWinControl and TMainForm really means. Build it with Tools\build-fmx.cmd, or add CADSYS_FMX to the project conditional defines.'}
{$ENDIF}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.DateUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Menus, FMX.Dialogs,
  FMX.Layouts, FMX.Controls.Presentation,
  DemoLog, DemoDlg, LayersFrm,
  FNCCS4BaseTypes, FNCCS4Graphics, FNCCADSys4, FNCCS4Shapes, FNCCS4Tasks,
  FNCCS4DXFModule, FNCCS4Legacy, FNCCS4Views,
  { FNCCadSysRegister is here for its initialization section, not for
    the component palette: it is the only place that fills the class
    registry, and without it LoadFromFile and SaveToFile have no class
    to map the index they store onto. }
  FNCCadSysRegister;

type
  TMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    fCAD: TFNCCADCmp2D;
    fView: TFNCCADViewport2D;
    fRuler: TFNCRuler;
    fVRuler: TFNCRuler;
    fPrg: TFNCCADPrg2D;
    { : Where the drawing came from, so a saved view can name it.
      Empty until the drawing has been loaded from or saved to a
      file - a view of something unsaved has nothing to point at. }
    fDrawingFile: String;

    fBar: TToolBar;
    fMenu: TMainMenu;
    fPopup: TPopupMenu;
    fCoordLbl: TLabel;
    fStateLbl: TLabel;
    fLoggedScale: Single;

    { The button whose operation is running, and its unmodified text.
      FMX buttons have no Indeterminate, so the running operation is
      shown by decorating the caption. }
    fCurrentOpBtn: TButton;
    fCurrentOpText: string;
    { Where the next toolbar button goes, as a plain index. The buttons
      are positioned absolutely, in two rows, rather than aligned:
      fifteen of them never fit one row at a readable size, and
      alignment on the VCL side depends on a position tie-break that
      has already put controls in the wrong order twice. Absolute
      coordinates inside a top-aligned panel behave identically on both
      frameworks and cannot be argued with. }
    fButtonIndex: Integer;
    { Toolbar and status metrics. Not constants: see MeasureUI. }
    fBtnW, fBtnH, fRowH: Integer;

    { Menu items whose Checked state is the demo's own setting, exactly
      as in the VCL version. }
    fShowGridItem: TMenuItem;
    fKeepAspectItem: TMenuItem;
    fUseSnapItem: TMenuItem;
    fUseOrtoItem: TMenuItem;
    fUseAreaItem: TMenuItem;
    fLeftItem: TMenuItem;
    fCenterItem: TMenuItem;
    fRightItem: TMenuItem;
    fAcceptItem: TMenuItem;
    fCancelItem: TMenuItem;
    fZoomAreaItem: TMenuItem;
    fZoomInItem: TMenuItem;
    fZoomOutItem: TMenuItem;
    fZoomAllItem: TMenuItem;
    fPanItem: TMenuItem;

    { ---- construction ---- }
    function AddButton(const ACaption: string;
      const AClick: TNotifyEvent): TButton;
    function AddMenu(const AParent: TFmxObject;
      const ACaption: string): TMenuItem;
    function AddItem(const AParent: TFmxObject; const ACaption: string;
      const AClick: TNotifyEvent): TMenuItem;
    function AddCheckItem(const AParent: TFmxObject; const ACaption: string;
      const AClick: TNotifyEvent; const AChecked: Boolean): TMenuItem;
    procedure AddSeparator(const AParent: TFmxObject);
    procedure LayoutToolbar;
    procedure FormShow(Sender: TObject);
    procedure BuildControls;
    procedure BuildToolbar;
    procedure BuildMenu;
    procedure BuildPopup;

    { ---- helpers ---- }
    procedure StartDraw(const AButton: TButton;
      const AState: TCADStateClass; const AParam: TCADPrgParam);
    procedure StartSelection(const AAfterState: TCADStateClass);
    function LibraryFileName: string;

    { ---- library events ---- }
    procedure ViewMouseMove2D(Sender: TObject; Shift: TShiftState;
      WX, WY: TRealType; X, Y: Integer);
    procedure ViewDblClick(Sender: TObject);
    procedure ViewKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState);
    procedure PrgStartOperation(Sender: TObject;
      const Operation: TCADStateClass; const Param: TCADPrgParam);
    procedure PrgEndOperation(Sender: TObject;
      const Operation: TCADStateClass; const Param: TCADPrgParam);
    procedure PrgStopOperation(Sender: TObject;
      const Operation: TCADStateClass; const Param: TCADPrgParam);
    procedure PrgDescriptionChanged(Sender: TObject);
    procedure OnSelectedObj(Sender: TCAD2DSelectObjectsParam; Obj: TObject2D;
      CtrlPt: Integer; Added: Boolean);
    procedure PopupShown(Sender: TObject);
    procedure AppException(Sender: TObject; E: Exception);

    { ---- drawing ---- }
    procedure LineClick(Sender: TObject);
    procedure FrameClick(Sender: TObject);
    procedure RectangleClick(Sender: TObject);
    procedure EllipseClick(Sender: TObject);
    procedure FilledEllipseClick(Sender: TObject);
    procedure ArcClick(Sender: TObject);
    procedure PolylineClick(Sender: TObject);
    procedure PolygonClick(Sender: TObject);
    procedure SplineClick(Sender: TObject);
    procedure TextClick(Sender: TObject);
    procedure ImageClick(Sender: TObject);

    { ---- editing ---- }
    procedure MoveClick(Sender: TObject);
    procedure RotateClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure DefBlockClick(Sender: TObject);
    procedure AddBlockClick(Sender: TObject);

    { ---- program control ---- }
    procedure AcceptClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure SetPointClick(Sender: TObject);

    { ---- view ---- }
    procedure ZoomAreaClick(Sender: TObject);
    procedure ZoomInClick(Sender: TObject);
    procedure ZoomOutClick(Sender: TObject);
    procedure ZoomAllClick(Sender: TObject);
    procedure PanClick(Sender: TObject);
    procedure ShowGridClick(Sender: TObject);
    procedure KeepAspectClick(Sender: TObject);
    procedure UseSnapClick(Sender: TObject);
    procedure SnapChanged;
    procedure UseOrtoClick(Sender: TObject);
    procedure UseAreaClick(Sender: TObject);
    procedure LayersClick(Sender: TObject);
    procedure JustLeftClick(Sender: TObject);
    procedure JustCenterClick(Sender: TObject);
    procedure JustRightClick(Sender: TObject);

    { ---- files ---- }
    procedure NewClick(Sender: TObject);
    procedure LoadClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure MergeClick(Sender: TObject);
    procedure ImportDXFClick(Sender: TObject);
    procedure ImportLegacyClick(Sender: TObject);
    procedure SaveViewClick(Sender: TObject);
    procedure OpenViewClick(Sender: TObject);
    procedure LoadProgress(Sender: TObject; ReadPercent: Byte);
    procedure ViewPaint(Sender: TObject);
    procedure ExportDXFClick(Sender: TObject);
    procedure PrintActualClick(Sender: TObject);
    procedure PrintFitClick(Sender: TObject);
    procedure PrintScaleClick(Sender: TObject);
    procedure ClipboardClick(Sender: TObject);
    procedure NotOnFMX;
    procedure ExitClick(Sender: TObject);
    procedure TimeRepaintClick(Sender: TObject);
  end;

  { : The state the VCL demo uses to turn a selection into a source
    block. Copied unchanged apart from the input dialog. }
  TMyCADCreateTheSourceBlock = class(TCADState)
  public
    constructor Create(const CADPrg: TFNCCADPrg;
      const StateParam: TCADPrgParam;
      var NextState: TCADStateClass); override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

const
  { Fifteen buttons in three rows of five. The sizes are in MeasureUI,
    to mirror the VCL demo - here they really are constants. }
  BarColumns = 5;
  BarRows = 4;

constructor TMyCADCreateTheSourceBlock.Create(const CADPrg: TFNCCADPrg;
  const StateParam: TCADPrgParam; var NextState: TCADStateClass);
var
  TmpStr: String;
  TmpIter: TExclusiveGraphicObjIterator;
  TmpBlk: TSourceBlock2D;
begin
  inherited;
  if Param is TCAD2DSelectObjectsParam then
    with TCAD2DSelectObjectsParam(Param),
      TFNCCADCmp2D(CADPrg.Viewport.CADCmp) do
    begin
      TmpStr := '';
      if not AskString('Define block', 'Name', TmpStr) then
      begin
        NextState := CADPrg.DefaultState;
        Param.Free;
        Param := nil;
      end;
      TmpIter := SelectedObjects.GetExclusiveIterator;
      try
        TmpIter.First;
        while TmpIter.Current <> nil do
        begin
          RemoveObject(TmpIter.Current.ID);
          TmpIter.Next;
        end;
        TmpBlk := BlockObjects(StringToBlockName(TmpStr), TmpIter);
        if Assigned(TmpBlk) then
          TmpBlk.IsLibraryBlock := True;
      finally
        TmpIter.Free;
      end;
      CADPrg.RepaintAfterOperation;
    end;
  NextState := CADPrg.DefaultState;
  Param.Free;
  Param := nil;
end;

{ ===================== construction ===================== }

procedure TMainForm.LayoutToolbar;
var
  Cont: Integer;
  TmpCtrl: TControl;
begin
  { Plain numbers, and they can be: FMX coordinates are logical and the
    platform scales the whole scene, so these look the same at any DPI.
    The VCL demo has to measure its font instead, from OnShow, because
    the VCL scales a form's font after OnCreate and never scales
    controls created at run time - see the long note in its
    LayoutToolbar. The shape is kept the same on both sides so the
    difference is visible in a diff rather than hidden. }
  fBtnW := 96;
  fBtnH := 28;
  fRowH := 24;

  fButtonIndex := 0;
  for Cont := 0 to fBar.ControlsCount - 1 do
  begin
    TmpCtrl := fBar.Controls[Cont];
    if not(TmpCtrl is TButton) then
      Continue;
    TmpCtrl.SetBounds(4 + (fButtonIndex mod BarColumns) * (fBtnW + 4),
      4 + (fButtonIndex div BarColumns) * (fBtnH + 4), fBtnW, fBtnH);
    Inc(fButtonIndex);
  end;
  fBar.Height := BarRows * (fBtnH + 4) + 4;
  if fStateLbl <> nil then
    TControl(fStateLbl.Parent).Height := fRowH;
  Log(Format('LayoutToolbar: button %d x %d, bar %d high',
    [fBtnW, fBtnH, Round(fBar.Height)]));
  Log(Format('  ruler: RulerScale %.3f (FNC PaintScaleFactor %.3f), ' +
    'Thickness %d, Height %d, FontSize %d, label height %d',
    [fRuler.RulerScale, fRuler.PaintScaleFactor, fRuler.Thickness,
    Round(fRuler.Height), fRuler.FontSize, Abs(fRuler.RulerFontHeight)]));
  Log(Format('  vruler: RulerScale %.3f, Thickness %d, Width %d',
    [fVRuler.RulerScale, fVRuler.Thickness, Round(fVRuler.Width)]));
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  LayoutToolbar;
end;

function TMainForm.AddButton(const ACaption: string;
  const AClick: TNotifyEvent): TButton;
begin
  { Created only. Where it goes and how big it is belong to
    LayoutToolbar, which runs once the form is shown and its font is
    final. }
  Result := TButton.Create(Self);
  Result.Parent := fBar;
  Result.Text := ACaption;
  Result.OnClick := AClick;
end;

function TMainForm.AddMenu(const AParent: TFmxObject;
  const ACaption: string): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Parent := AParent;
  Result.Text := ACaption;
end;

function TMainForm.AddItem(const AParent: TFmxObject; const ACaption: string;
  const AClick: TNotifyEvent): TMenuItem;
begin
  Result := AddMenu(AParent, ACaption);
  Result.OnClick := AClick;
end;

function TMainForm.AddCheckItem(const AParent: TFmxObject;
  const ACaption: string; const AClick: TNotifyEvent;
  const AChecked: Boolean): TMenuItem;
begin
  Result := AddItem(AParent, ACaption, AClick);
  Result.IsChecked := AChecked;
end;

procedure TMainForm.AddSeparator(const AParent: TFmxObject);
begin
  AddMenu(AParent, '-');
end;

procedure TMainForm.BuildToolbar;
begin
  Log('BuildToolbar');
  fBar := TToolBar.Create(Self);
  fBar.Parent := Self;
  fBar.Align := TAlignLayout.Top;
  fBar.Height := BarRows * (fBtnH + 4) + 4;

  AddButton('Line', LineClick);
  AddButton('Frame', FrameClick);
  AddButton('Rect', RectangleClick);
  AddButton('Ellipse', EllipseClick);
  AddButton('Filled', FilledEllipseClick);
  AddButton('Arc', ArcClick);
  AddButton('Polyline', PolylineClick);
  AddButton('Polygon', PolygonClick);
  AddButton('Spline', SplineClick);
  AddButton('Text', TextClick);
  AddButton('Image', ImageClick);
  AddButton('Move', MoveClick);
  AddButton('Rotate', RotateClick);
  AddButton('Edit', EditClick);
  AddButton('Def blk', DefBlockClick);
  AddButton('Add blk', AddBlockClick);
end;

procedure TMainForm.BuildMenu;
var
  TmpFile, TmpEdit, TmpView, TmpJust, TmpPrint: TMenuItem;
begin
  Log('BuildMenu');
  fMenu := TMainMenu.Create(Self);
  fMenu.Parent := Self;

  TmpFile := AddMenu(fMenu, 'File');
  AddItem(TmpFile, 'New', NewClick);
  AddItem(TmpFile, 'Load...', LoadClick);
  AddItem(TmpFile, 'Save...', SaveClick);
  AddItem(TmpFile, 'Merge...', MergeClick);
  AddSeparator(TmpFile);
  AddItem(TmpFile, 'Import DXF...', ImportDXFClick);
  AddItem(TmpFile, 'Import legacy .CS2...', ImportLegacyClick);
  AddItem(TmpFile, 'Export DXF...', ExportDXFClick);
  AddSeparator(TmpFile);
  AddItem(TmpFile, 'Save view...', SaveViewClick);
  AddItem(TmpFile, 'Open view...', OpenViewClick);
  AddSeparator(TmpFile);
  TmpPrint := AddMenu(TmpFile, 'Print');
  { Present, and honest about why they do nothing. Leaving them out
    would hide a real gap in the port. }
  AddItem(TmpPrint, 'Actual view', PrintActualClick);
  AddItem(TmpPrint, 'Fit to page', PrintFitClick);
  AddItem(TmpPrint, 'To scale', PrintScaleClick);
  AddItem(TmpFile, 'Copy to clipboard', ClipboardClick);
  AddSeparator(TmpFile);
  AddItem(TmpFile, 'Exit', ExitClick);

  TmpEdit := AddMenu(fMenu, 'Edit');
  fAcceptItem := AddItem(TmpEdit, 'Accept', AcceptClick);
  fCancelItem := AddItem(TmpEdit, 'Cancel', CancelClick);
  AddSeparator(TmpEdit);
  AddItem(TmpEdit, 'Set point...', SetPointClick);
  AddSeparator(TmpEdit);
  AddItem(TmpEdit, 'Layers...', LayersClick);
  fUseAreaItem := AddCheckItem(TmpEdit, 'Use area to select objects',
    UseAreaClick, False);
  TmpJust := AddMenu(TmpEdit, 'Text alignment');
  fLeftItem := AddCheckItem(TmpJust, 'Left', JustLeftClick, True);
  fCenterItem := AddCheckItem(TmpJust, 'Center', JustCenterClick, False);
  fRightItem := AddCheckItem(TmpJust, 'Right', JustRightClick, False);

  TmpView := AddMenu(fMenu, 'View');
  fZoomAreaItem := AddItem(TmpView, 'Zoom area', ZoomAreaClick);
  fZoomInItem := AddItem(TmpView, 'Zoom in', ZoomInClick);
  fZoomOutItem := AddItem(TmpView, 'Zoom out', ZoomOutClick);
  fZoomAllItem := AddItem(TmpView, 'Zoom all', ZoomAllClick);
  fPanItem := AddItem(TmpView, 'Panning', PanClick);
  AddSeparator(TmpView);
  fShowGridItem := AddCheckItem(TmpView, 'Show grid', ShowGridClick, True);
  fKeepAspectItem := AddCheckItem(TmpView, 'Keep aspect', KeepAspectClick,
    True);
  fUseSnapItem := AddCheckItem(TmpView, 'Use snap', UseSnapClick, True);
  fUseOrtoItem := AddCheckItem(TmpView, 'Use orto', UseOrtoClick, False);
  AddSeparator(TmpView);
  AddItem(TmpView, 'Time a repaint', TimeRepaintClick);
end;

procedure TMainForm.BuildPopup;
begin
  Log('BuildPopup');
  fPopup := TPopupMenu.Create(Self);
  fPopup.Parent := Self;
  fPopup.OnPopup := PopupShown;
  AddItem(fPopup, 'Accept', AcceptClick);
  AddItem(fPopup, 'Cancel', CancelClick);
  AddSeparator(fPopup);
  AddItem(fPopup, 'Zoom area', ZoomAreaClick);
  AddItem(fPopup, 'Zoom in', ZoomInClick);
  AddItem(fPopup, 'Zoom out', ZoomOutClick);
  AddItem(fPopup, 'Zoom all', ZoomAllClick);
  AddItem(fPopup, 'Panning', PanClick);
  AddSeparator(fPopup);
  AddItem(fPopup, 'Set point...', SetPointClick);
end;

procedure TMainForm.BuildControls;
var
  TmpStatus: TLayout;
begin
  Log('BuildControls: status');
  TmpStatus := TLayout.Create(Self);
  TmpStatus.Parent := Self;
  TmpStatus.Align := TAlignLayout.Bottom;
  TmpStatus.Height := fRowH;

  fCoordLbl := TLabel.Create(Self);
  fCoordLbl.Parent := TmpStatus;
  fCoordLbl.Align := TAlignLayout.Left;
  fCoordLbl.Width := fBtnW * 3;
  fCoordLbl.Margins.Rect := RectF(6, 0, 0, 0);

  fStateLbl := TLabel.Create(Self);
  fStateLbl.Parent := TmpStatus;
  fStateLbl.Align := TAlignLayout.Client;

  { The ruler goes on before the viewport: FMX gives an earlier child
    the edge it asks for, so Top is taken by the ruler and Client is
    what is left. }
  Log('BuildControls: ruler');
  fRuler := TFNCRuler.Create(Self);
  fRuler.Parent := Self;
  fRuler.Align := TAlignLayout.Top;
  fRuler.Orientation := otOrizontal;
  { Thickness only. The ruler sizes itself from it, scaled for the
    display - setting Height here as well would fight that, because
    Thickness is a logical value and Height is not. }
  fRuler.Thickness := 24;
  { FontSize left at 0, which means "use the control's own Font" - so
    the ruler's labels match the rest of the window without anyone
    doing DPI arithmetic. }
  fRuler.StepSize := 10.0;
  fRuler.StepDivisions := 5;

  { The vertical one, on the left, and created after the horizontal one
    so FMX gives it the edge below. The horizontal ruler therefore runs
    the full width and the vertical starts under it, which is the
    conventional corner: the top left square belongs to the horizontal
    one. }
  fVRuler := TFNCRuler.Create(Self);
  fVRuler.Parent := Self;
  fVRuler.Align := TAlignLayout.Left;
  fVRuler.Orientation := otVertical;
  fVRuler.Thickness := 24;
  fVRuler.StepSize := 10.0;
  fVRuler.StepDivisions := 5;

  Log('BuildControls: TFNCCADCmp2D');
  fCAD := TFNCCADCmp2D.Create(Self);

  Log('BuildControls: TFNCCADViewport2D');
  fView := TFNCCADViewport2D.Create(Self);
  fView.Parent := Self;
  fView.Align := TAlignLayout.Client;
  fView.CADCmp := fCAD;
  fView.GridDeltaX := 10.0;
  fView.GridDeltaY := 10.0;
  fView.OnMouseMove2D := ViewMouseMove2D;
  fView.OnPaint := ViewPaint;
  fView.OnDblClick := ViewDblClick;
  fView.OnKeyDown := ViewKeyDown;
  fView.PopupMenu := fPopup;
  fView.CanFocus := True;

  fRuler.LinkedViewport := fView;
  fVRuler.LinkedViewport := fView;

  Log('BuildControls: TFNCCADPrg2D');
  fPrg := TFNCCADPrg2D.Create(Self);
  fPrg.Viewport2D := fView;
  fPrg.OnStartOperation := PrgStartOperation;
  fPrg.OnEndOperation := PrgEndOperation;
  fPrg.OnStopOperation := PrgStopOperation;
  fPrg.OnDescriptionChanged := PrgDescriptionChanged;
end;

function TMainForm.LibraryFileName: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'Library.blk';
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  TmpStream: TFileStream;
begin
  Log('FormCreate');
  Application.OnException := AppException;
  Caption := 'CADSys FNC - FMX CAD2D';
  Width := 1100;
  Height := 720;

  OnShow := FormShow;
  BuildToolbar;
  BuildMenu;
  BuildPopup;
  BuildControls;

  if FileExists(LibraryFileName) then
  begin
    Log('loading block library');
    TmpStream := TFileStream.Create(LibraryFileName, fmOpenRead);
    try
      fCAD.LoadLibrary(TmpStream);
    finally
      TmpStream.Free;
    end;
  end;

  Log('configuring view and program');
  fCAD.DefaultLayersColor := cadtcBlack;
  fView.UsePaintingThread := False;
  fView.ShowGrid := fShowGridItem.IsChecked;
  if fKeepAspectItem.IsChecked then
    fView.AspectRatio := 1.0
  else
    fView.AspectRatio := 0.0;
  fView.ZoomWindow(Rect2D(-50, -50, 50, 50));

  fPrg.ShowCursorCross := True;
  { The grid step, not one unit. The grid is what a user aims at, and a
    snap an order of magnitude finer than the grid is indistinguishable
    from no snap at all - which is what the old 1.0 looked like at this
    zoom, where a unit is about nine pixels. }
  fPrg.XSnap := fView.GridDeltaX;
  fPrg.YSnap := fView.GridDeltaY;
  fPrg.UseSnap := fUseSnapItem.IsChecked;
  fPrg.UseOrto := fUseOrtoItem.IsChecked;
  SnapChanged;
  { Logged because the window has not always opened at the size asked
    for, and the toolbar and ruler layout depend on it. }
  Log(Format('form %d x %d, toolbar %d wide',
    [Round(Width), Round(Height), Round(fBar.Width)]));
  Log('FormCreate done');
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  TmpStream: TFileStream;
begin
  if fCAD.SourceBlocksCount = 0 then
    Exit;
  TmpStream := TFileStream.Create(LibraryFileName, fmOpenWrite or fmCreate);
  try
    fCAD.SaveLibrary(TmpStream);
  finally
    TmpStream.Free;
  end;
end;

{ ===================== helpers ===================== }

procedure TMainForm.StartDraw(const AButton: TButton;
  const AState: TCADStateClass; const AParam: TCADPrgParam);
begin
  if fPrg.IsBusy then
    fPrg.StopOperation;
  fCurrentOpBtn := AButton;
  fPrg.StartOperation(AState, AParam);
end;

procedure TMainForm.StartSelection(const AAfterState: TCADStateClass);
var
  TmpPar: TCADPrgParam;
begin
  if fUseAreaItem.IsChecked then
  begin
    TmpPar := TCAD2DSelectObjectsInAreaParam.Create(gmAllInside, AAfterState);
    fPrg.StartOperation(TCAD2DSelectObjectsInArea, TmpPar);
  end
  else
  begin
    TmpPar := TCAD2DSelectObjectsParam.Create(5, AAfterState);
    TCAD2DSelectObjectsParam(TmpPar).OnObjectSelected := OnSelectedObj;
    fPrg.StartOperation(TCAD2DSelectObjects, TmpPar);
  end;
end;

{ ===================== library events ===================== }

procedure TMainForm.AppException(Sender: TObject; E: Exception);
begin
  LogError('runtime', E);
  if fStateLbl <> nil then
    fStateLbl.Text := E.ClassName + ': ' + E.Message;
end;

procedure TMainForm.ViewMouseMove2D(Sender: TObject; Shift: TShiftState;
  WX, WY: TRealType; X, Y: Integer);
begin
  with fPrg.CurrentViewportSnappedPoint do
    fCoordLbl.Text := Format('X: %6.3f  Y: %6.3f', [X, Y]);
  { Each ruler marks its own axis: the horizontal one follows X, the
    vertical one Y. }
  fRuler.SetMark(WX);
  fVRuler.SetMark(WY);
end;

procedure TMainForm.ViewDblClick(Sender: TObject);
var
  TmpPt: TPoint2D;
  TmpObj: TObject2D;
  TmpN: Integer;
  TmpStr: String;
begin
  TmpPt := fPrg.CurrentViewportSnappedPoint;
  TmpObj := fView.PickObject(TmpPt, 5, False, TmpN);
  if TmpObj is TJustifiedVectText2D then
    with TJustifiedVectText2D(TmpObj) do
    begin
      TmpStr := Text;
      if not AskString('Edit text', 'String', TmpStr) then
        Exit;
      Text := TmpStr;
      fView.Repaint;
    end;
end;

procedure TMainForm.ViewKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
var
  TmpPt: TPoint2D;
begin
  { The VCL demo nudges the current point with the numeric keypad 8 and
    then replays a mouse move so the running task sees it. Same idea,
    FMX key codes. }
  if Key = vkUp then
  begin
    TmpPt := fPrg.CurrentViewportPoint;
    TmpPt.Y := TmpPt.Y + 10.0;
    fPrg.CurrentViewportPoint := TmpPt;
  end;
  fPrg.SendCADEvent(ceMouseMove, TMouseButton.mbLeft, [], 0);
end;

procedure TMainForm.PrgStartOperation(Sender: TObject;
  const Operation: TCADStateClass; const Param: TCADPrgParam);
begin
  if Assigned(fCurrentOpBtn) then
  begin
    fCurrentOpText := fCurrentOpBtn.Text;
    fCurrentOpBtn.Text := '> ' + fCurrentOpText;
  end;
end;

procedure TMainForm.PrgEndOperation(Sender: TObject;
  const Operation: TCADStateClass; const Param: TCADPrgParam);
begin
  if Assigned(fCurrentOpBtn) then
  begin
    fCurrentOpBtn.Text := fCurrentOpText;
    fCurrentOpBtn := nil;
  end;
end;

procedure TMainForm.PrgStopOperation(Sender: TObject;
  const Operation: TCADStateClass; const Param: TCADPrgParam);
begin
  PrgEndOperation(Sender, Operation, Param);
end;

procedure TMainForm.PrgDescriptionChanged(Sender: TObject);
begin
  fStateLbl.Text := TCADState(Sender).Description;
end;

procedure TMainForm.OnSelectedObj(Sender: TCAD2DSelectObjectsParam;
  Obj: TObject2D; CtrlPt: Integer; Added: Boolean);
begin
  if Assigned(Obj) then
    fView.DrawObject2DWithRubber(Obj, True);
end;

procedure TMainForm.PopupShown(Sender: TObject);
var
  TmpZooming: Boolean;
begin
  fAcceptItem.Enabled := fPrg.IsBusy;
  fCancelItem.Enabled := fPrg.IsBusy;
  TmpZooming := (fPrg.CurrentOperation = TCADPrgZoomArea) or
    (fPrg.CurrentOperation = TCADPrgRealTimePan) or fPrg.IsSuspended;
  fZoomAreaItem.Enabled := not TmpZooming;
  fZoomInItem.Enabled := not TmpZooming;
  fZoomOutItem.Enabled := not TmpZooming;
  fZoomAllItem.Enabled := not TmpZooming;
  fPanItem.Enabled := not TmpZooming;
end;

{ ===================== drawing ===================== }

procedure TMainForm.LineClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;

procedure TMainForm.FrameClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
    TFrame2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;

procedure TMainForm.RectangleClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
    TRectangle2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;

procedure TMainForm.EllipseClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
    TEllipse2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;

procedure TMainForm.FilledEllipseClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
    TFilledEllipse2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;

procedure TMainForm.ArcClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawArcPrimitive,
    TCAD2DDrawArcPrimitiveParam.Create(nil,
    TArc2D.Create(-1, Point2D(0, 0), Point2D(0, 0), 0, 0)));
end;

procedure TMainForm.PolylineClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawUnSizedPrimitive,
    TCAD2DDrawUnSizedPrimitiveParam.Create(nil,
    TPolyline2D.Create(-1, [Point2D(0, 0)]), 0, True));
end;

procedure TMainForm.PolygonClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DDrawUnSizedPrimitive,
    TCAD2DDrawUnSizedPrimitiveParam.Create(nil,
    TPolygon2D.Create(-1, [Point2D(0, 0)]), 0, True));
end;

procedure TMainForm.SplineClick(Sender: TObject);
var
  TmpSpline: TBSpline2D;
begin
  TmpSpline := TBSpline2D.Create(-1, [Point2D(0, 0)]);
  TmpSpline.SavingType := stSpace;
  StartDraw(TButton(Sender), TCAD2DDrawUnSizedPrimitive,
    TCAD2DDrawUnSizedPrimitiveParam.Create(nil, TmpSpline, 0, True));
end;

procedure TMainForm.TextClick(Sender: TObject);
var
  TmpText: TJustifiedVectText2D;
  TmpHeight, TmpString: String;
begin
  TmpHeight := '5';
  TmpString := 'Text';
  if not AskTwoStrings('Add text', 'Height', 'String', TmpHeight,
    TmpString) then
    Exit;
  TmpText := TJustifiedVectText2D.Create(-1, CADSysFindFontByIndex(0),
    Rect2D(0, 0, 0, 0), StrToFloatDef(TmpHeight, 5), TmpString);
  if fLeftItem.IsChecked then
    TmpText.HorizontalJust := jhLeft
  else if fRightItem.IsChecked then
    TmpText.HorizontalJust := jhRight
  else if fCenterItem.IsChecked then
    TmpText.HorizontalJust := jhCenter;
  StartDraw(TButton(Sender), TCAD2DPositionObject,
    TCAD2DPositionObjectParam.Create(nil, TmpText));
end;

{ ===================== editing ===================== }

procedure TMainForm.ImageClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
  TmpStream: TFileStream;
  TmpImg: TCADImage;
begin
  { PNG and BMP only, and the filter says so rather than offering
    everything and failing later: TCADImage.ReadSize knows those two
    signatures, and the backends decode those two. A JPEG would load
    its bytes and then draw nothing. }
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'Images (*.png;*.bmp)|*.png;*.bmp|All files (*.*)|*.*';
    if not TmpDlg.Execute then
      Exit;
    TmpImg := TCADImage.Create;
    try
      TmpStream := TFileStream.Create(TmpDlg.FileName,
        fmOpenRead or fmShareDenyWrite);
      try
        TmpImg.LoadFromStream(TmpStream);
      finally
        TmpStream.Free;
      end;
      Log(Format('image: %s, %d x %d, %d bytes',
        [ExtractFileName(TmpDlg.FileName), TmpImg.Width, TmpImg.Height,
        Length(TmpImg.Data)]));
      if TmpImg.Width = 0 then
        Log('  no size read - the decoder will probably draw nothing');
      { Two corners, like a rectangle, because that is what a TBitmap2D
        is: the image is stretched between them and cannot be rotated.
        The constructor copies the image, so this one stays ours. }
      StartDraw(TButton(Sender), TCAD2DDrawSizedPrimitive,
        TCAD2DDrawSizedPrimitiveParam.Create(nil,
        TBitmap2D.Create(-1, Point2D(0, 0), Point2D(0, 0), TmpImg), 0, True));
    finally
      TmpImg.Free;
    end;
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.MoveClick(Sender: TObject);
begin
  StartSelection(TCAD2DMoveSelectedObjects);
end;

procedure TMainForm.RotateClick(Sender: TObject);
begin
  StartSelection(TCAD2DRotateSelectedObjects);
end;

procedure TMainForm.EditClick(Sender: TObject);
begin
  StartDraw(TButton(Sender), TCAD2DSelectObject,
    TCAD2DSelectObjectsParam.Create(5, TCAD2DEditSelectedPrimitive));
end;

procedure TMainForm.DefBlockClick(Sender: TObject);
begin
  StartSelection(TMyCADCreateTheSourceBlock);
end;

procedure TMainForm.AddBlockClick(Sender: TObject);
var
  TmpStr: String;
  TmpSrc: TSourceBlock2D;
begin
  TmpStr := '';
  if not AskString('Add block', 'Name', TmpStr) then
    Exit;
  TmpSrc := fCAD.FindSourceBlock(StringToBlockName(TmpStr));
  if TmpSrc <> nil then
    fPrg.StartOperation(TCAD2DPositionObject,
      TCAD2DPositionObjectParam.Create(nil, TBlock2D.Create(-1, TmpSrc)))
  else
    Say(Format('No block named "%s".', [TmpStr]));
end;

{ ===================== program control ===================== }

procedure TMainForm.AcceptClick(Sender: TObject);
begin
  fPrg.SendUserEvent(CADPRG_ACCEPT);
end;

procedure TMainForm.CancelClick(Sender: TObject);
begin
  fPrg.SendUserEvent(CADPRG_CANCEL);
  fPrg.StopOperation;
end;

procedure TMainForm.SetPointClick(Sender: TObject);
var
  TmpX, TmpY: String;
begin
  TmpX := Format('%6.3f', [fPrg.CurrentViewportPoint.X]);
  TmpY := Format('%6.3f', [fPrg.CurrentViewportPoint.Y]);
  if not AskTwoStrings('Insert point', 'X', 'Y', TmpX, TmpY) then
    Exit;
  fPrg.CurrentViewportPoint := Point2D(StrToFloatDef(TmpX, 0),
    StrToFloatDef(TmpY, 0));
  fPrg.SendCADEvent(ceMouseDown, TMouseButton.mbLeft, [], 0);
end;

{ ===================== view ===================== }

procedure TMainForm.ZoomAreaClick(Sender: TObject);
begin
  fPrg.SuspendOperation(TCADPrgZoomArea, nil);
end;

procedure TMainForm.ZoomInClick(Sender: TObject);
begin
  fView.ZoomIn;
end;

procedure TMainForm.ZoomOutClick(Sender: TObject);
begin
  fView.ZoomOut;
end;

procedure TMainForm.ZoomAllClick(Sender: TObject);
begin
  fView.ZoomToExtension;
end;

procedure TMainForm.PanClick(Sender: TObject);
begin
  fPrg.SuspendOperation(TCADPrgRealTimePan, nil);
end;

procedure TMainForm.ShowGridClick(Sender: TObject);
begin
  fShowGridItem.IsChecked := not fShowGridItem.IsChecked;
  fView.ShowGrid := fShowGridItem.IsChecked;
end;

procedure TMainForm.KeepAspectClick(Sender: TObject);
begin
  fKeepAspectItem.IsChecked := not fKeepAspectItem.IsChecked;
  if fKeepAspectItem.IsChecked then
    fView.AspectRatio := 1.0
  else
    fView.AspectRatio := 0.0;
  fView.ZoomWindow(fView.VisualRect);
end;

procedure TMainForm.SnapChanged;
begin
  { Written down rather than left to the eye: "snap does nothing" and
    "snap is off" look alike on screen, and this says which. }
  if fPrg.UseSnap then
    Log(Format('snap on, step %.2f x %.2f', [fPrg.XSnap, fPrg.YSnap]))
  else
    Log('snap off');
end;

procedure TMainForm.UseSnapClick(Sender: TObject);
begin
  fUseSnapItem.IsChecked := not fUseSnapItem.IsChecked;
  fPrg.UseSnap := fUseSnapItem.IsChecked;
  SnapChanged;
end;

procedure TMainForm.UseOrtoClick(Sender: TObject);
begin
  fUseOrtoItem.IsChecked := not fUseOrtoItem.IsChecked;
  fPrg.UseOrto := fUseOrtoItem.IsChecked;
end;

procedure TMainForm.UseAreaClick(Sender: TObject);
begin
  fUseAreaItem.IsChecked := not fUseAreaItem.IsChecked;
end;

procedure TMainForm.LayersClick(Sender: TObject);
var
  TmpForm: TLayersForm;
begin
  TmpForm := TLayersForm.CreateNew(Self);
  try
    TmpForm.Execute(fCAD);
    fView.Repaint;
  finally
    TmpForm.Free;
  end;
end;

procedure TMainForm.JustLeftClick(Sender: TObject);
begin
  fLeftItem.IsChecked := True;
  fCenterItem.IsChecked := False;
  fRightItem.IsChecked := False;
end;

procedure TMainForm.JustCenterClick(Sender: TObject);
begin
  fLeftItem.IsChecked := False;
  fCenterItem.IsChecked := True;
  fRightItem.IsChecked := False;
end;

procedure TMainForm.JustRightClick(Sender: TObject);
begin
  fLeftItem.IsChecked := False;
  fCenterItem.IsChecked := False;
  fRightItem.IsChecked := True;
end;

{ ===================== files ===================== }

procedure TMainForm.NewClick(Sender: TObject);
begin
  fCAD.DeleteAllObjects;
  fCAD.DeleteSavedSourceBlocks;
  fCAD.RepaintViewports;
end;

procedure TMainForm.LoadClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
begin
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys drawing (*.json)|*.json|All files (*.*)|*.*';
    if TmpDlg.Execute then
    begin
      fCAD.OnLoadProgress := LoadProgress;
      try
        fCAD.LoadFromFile(TmpDlg.FileName);
      finally
        fCAD.OnLoadProgress := nil;
      end;
      fDrawingFile := TmpDlg.FileName;
    end;
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.SaveClick(Sender: TObject);
var
  TmpDlg: TSaveDialog;
begin
  TmpDlg := TSaveDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys drawing (*.json)|*.json|All files (*.*)|*.*';
    TmpDlg.DefaultExt := 'json';
    if TmpDlg.Execute then
    begin
      fCAD.SaveToFile(TmpDlg.FileName);
      fDrawingFile := TmpDlg.FileName;
    end;
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.MergeClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
begin
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys drawing (*.json)|*.json|All files (*.*)|*.*';
    if TmpDlg.Execute then
      fCAD.MergeFromFile(TmpDlg.FileName);
  finally
    TmpDlg.Free;
  end;
end;

{ : Hooked to the legacy reader while an import runs.

  Every object is logged, not every hundredth: DemoLog is unbuffered,
  so if the import dies the last line in the file is the last thing the
  reader touched - which is the only way to find out where in a 1.2 MB
  drawing it went wrong. Noisy on purpose, and only while importing. }
const
  { True logs every object a legacy import reads, which is how the
    empty-container crash was found: DemoLog is unbuffered, so the last
    line written is the last thing the reader touched. It is also slow
    enough to dominate the import, so it stays off. }
  LegacyFine = False;

var
  fLegacyCount: Integer = 0;

procedure LegacyProgress(const AWhat: string; const AIndex: Integer;
  const APosition: Int64);
begin
  { Every five hundredth object, not every one. DemoLog opens, appends
    and closes the file per line - which is what makes it survive a
    hard crash, and what made a 7554 object import take a minute when
    this logged all of them. The milestones still bracket a failure
    closely enough to find it, and LegacyFine turns the rest back on
    when they are wanted. }
  if AWhat = 'added' then
  begin
    Inc(fLegacyCount);
    if not LegacyFine and (fLegacyCount mod 500 <> 0) then
      Exit;
  end
  else if (AWhat = 'object') and not LegacyFine then
    Exit;
  Log(Format('  legacy: %s %d at %d', [AWhat, AIndex, APosition]));
end;

procedure TMainForm.ViewPaint(Sender: TObject);
begin
  { Logged once, the first time a paint establishes it. ViewScale is
    zero until then - the canvas is the only thing that knows the
    display's scale and it does not exist before the first paint - so
    logging it from OnShow would only ever record the zero. On VCL it
    is one by construction; on FMX it is what decides whether the back
    buffer holds the display's real pixels. }
  if fLoggedScale = fView.ViewScale then
    Exit;
  fLoggedScale := fView.ViewScale;
  Log(Format('viewport: ViewScale %.3f, buffer %d x %d',
    [fView.ViewScale, fView.ControlRect.Right, fView.ControlRect.Bottom]));
end;

procedure TMainForm.LoadProgress(Sender: TObject; ReadPercent: Byte);
begin
  { OnLoadProgress fires for a JSON load and for a legacy import alike,
    so this one handler covers both. ProcessMessages because the read
    holds the main thread: without it the number is written and never
    painted. }
  fStateLbl.Text := Format('Loading... %d%%', [ReadPercent]);
  Application.ProcessMessages;
end;

procedure TMainForm.ImportLegacyClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
  TmpStart: TDateTime;
begin
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys binary drawing (*.cs2)|*.cs2;*.CS2|' +
      'All files (*.*)|*.*';
    if not TmpDlg.Execute then
      Exit;
    Log('importing legacy ' + ExtractFileName(TmpDlg.FileName));
    TmpStart := Now;
    fLegacyCount := 0;
    fCAD.OnLoadProgress := LoadProgress;
    CADLegacyProgress := LegacyProgress;
    try
      fCAD.LoadLegacyFile(TmpDlg.FileName);
    except
      on E: Exception do
      begin
        { The reader stops at the first thing it cannot read, and says
          what. Whatever it managed is still in the component, which is
          usually what you want to look at to work out why. }
        LogError('legacy import', E);
        CADSysWarn('Could not read all of the drawing: ' + E.Message);
      end;
    end;
    CADLegacyProgress := nil;
    fCAD.OnLoadProgress := nil;
    fStateLbl.Text := Format('Imported %d ms', [MilliSecondsBetween(Now, TmpStart)]);
    Log(Format('  imported in %d ms', [MilliSecondsBetween(Now, TmpStart)]));
    fView.ZoomToExtension;
  finally
    CADLegacyProgress := nil;
    fCAD.OnLoadProgress := nil;
    TmpDlg.Free;
  end;
end;

procedure TMainForm.ImportDXFClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
begin
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'DXF (*.dxf)|*.dxf|All files (*.*)|*.*';
    if not TmpDlg.Execute then
      Exit;
    with TDXF2DImport.Create(TmpDlg.FileName, fCAD) do
      try
        SetTextFont(CADSysFindFontByIndex(0));
        ReadDXF;
        fView.ZoomToExtension;
      finally
        Free;
      end;
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.ExportDXFClick(Sender: TObject);
var
  TmpDlg: TSaveDialog;
begin
  TmpDlg := TSaveDialog.Create(Self);
  try
    TmpDlg.Filter := 'DXF (*.dxf)|*.dxf|All files (*.*)|*.*';
    TmpDlg.DefaultExt := 'dxf';
    if not TmpDlg.Execute then
      Exit;
    with TDXF2DExport.Create(TmpDlg.FileName, fCAD) do
      try
        WriteDXF;
      finally
        Free;
      end;
  finally
    TmpDlg.Free;
  end;
end;

{ The four below are the substantive difference between this file and
  its VCL twin, where they all do the real thing. They keep the same
  names and the same menu wiring so that a diff shows only the bodies,
  and they say what is missing rather than leaving the menu items out -
  hiding them would make this demo look more complete than it is. }

procedure TMainForm.NotOnFMX;
begin
  Say('Printing and clipboard export live in FNCCS4ExportVCL, which is '
    + 'VCL-only: they are built on the GDI canvas and TClipboard. There '
    + 'is no FMX equivalent in the library yet.');
end;

procedure TMainForm.PrintActualClick(Sender: TObject);
begin
  NotOnFMX;
end;

procedure TMainForm.PrintFitClick(Sender: TObject);
begin
  NotOnFMX;
end;

procedure TMainForm.PrintScaleClick(Sender: TObject);
begin
  NotOnFMX;
end;

procedure TMainForm.SaveViewClick(Sender: TObject);
var
  TmpDlg: TSaveDialog;
  TmpView: TCADViewSpec;
  TmpName: String;
begin
  { A view records which drawing it looks at, so there has to be one to
    point at. An unsaved drawing has no path to store. }
  if fDrawingFile = '' then
  begin
    Say('Save the drawing first. A view names the drawing it looks at, '
      + 'and this one has not been saved anywhere yet.');
    Exit;
  end;
  TmpName := 'View';
  if not AskString('Save view', 'Name', TmpName) then
    Exit;
  TmpDlg := TSaveDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys view (*.cadview)|*.cadview|All files (*.*)|*.*';
    TmpDlg.DefaultExt := 'cadview';
    if not TmpDlg.Execute then
      Exit;
    { Whatever the viewport is showing now, layers included. }
    fView.CaptureView(TmpView);
    TmpView.Name := TmpName;
    TmpView.DrawingFile := fDrawingFile;
    TmpView.SaveToFile(TmpDlg.FileName);
    Log(Format('view saved: %s -> %s', [TmpDlg.FileName, fDrawingFile]));
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.OpenViewClick(Sender: TObject);
var
  TmpDlg: TOpenDialog;
  TmpView: TCADViewSpec;
begin
  TmpDlg := TOpenDialog.Create(Self);
  try
    TmpDlg.Filter := 'CADSys view (*.cadview)|*.cadview|All files (*.*)|*.*';
    if not TmpDlg.Execute then
      Exit;
    TmpView.LoadFromFile(TmpDlg.FileName);
  finally
    TmpDlg.Free;
  end;
  if not TmpView.DrawingExists then
  begin
    { Named rather than silently empty: a view whose drawing has moved is
      the one failure this feature will actually meet. }
    Say('The drawing this view refers to was not found:' + sLineBreak
      + TmpView.DrawingFile);
    Exit;
  end;
  { The drawing first and the framing second: ApplyView sets layer
    visibility on whatever drawing is loaded. }
  fCAD.OnLoadProgress := LoadProgress;
  try
    fCAD.LoadFromFile(TmpView.DrawingFile);
  finally
    fCAD.OnLoadProgress := nil;
  end;
  fDrawingFile := TmpView.DrawingFile;
  fView.ApplyView(TmpView);
  Log(Format('view "%s" applied from %s', [TmpView.Name, TmpView.DrawingFile]));
end;

procedure TMainForm.ClipboardClick(Sender: TObject);
begin
  NotOnFMX;
end;

procedure TMainForm.ExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.TimeRepaintClick(Sender: TObject);
var
  TmpStart: TDateTime;
  TmpMs: Int64;
begin
  TmpStart := Now;
  fView.Repaint;
  TmpMs := Round((Now - TmpStart) * 24 * 60 * 60 * 1000);
  Say(Format('Repaint: %d ms for %d objects.', [TmpMs, fCAD.ObjectsCount]));
end;

initialization

{ The vector font the text tool and the DXF reader need. Registered from
  the file next to the exe, exactly as the VCL demo does it. }
if FileExists(ExtractFilePath(ParamStr(0)) + 'RomanC.json') then
  CADSysRegisterFontFromFile(0, ExtractFilePath(ParamStr(0)) +
    'RomanC.json');

end.
