{ : The FMX port of the CAD2D demo.

  It follows Demos\CAD2D\VCL\MainFrm.pas handler for handler, so the
  two can be compared side by side and a difference in behaviour is a
  difference in the library rather than in the demo. Where something had
  to change, there is a comment saying why.

  Everything is built in code. The .fmx holds nothing but the form, so
  there is no resource to go stale and nothing here needs the IDE to
  have been opened.

  Three things are genuinely different from the VCL demo:

  <LI=Printing and clipboard are absent. They live in VCL.FNCCS4ExportVCL,
  which is VCL-only by construction - GDI and TClipboard have no FMX
  counterpart in this library yet. The menu items are present and say
  so, rather than being quietly missing.>
  <LI=The toolbar buttons show the running operation by their text
  rather than by TToolButton.Indeterminate, which FMX has no equivalent
  of.>
  <LI=Colours in the layers dialog come from a named palette; FMX has no
  TColorGrid.> }
unit MainFrm;

{$I FMX.FNCCADSys.inc}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.DateUtils, System.Diagnostics,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Menus, FMX.Dialogs,
  FMX.Layouts, FMX.Controls.Presentation,
  DemoLog, DemoDlg, LayersFrm, PrintPrvFrm,
  FMX.FNCCS4BaseTypes, FMX.FNCCS4Graphics, FMX.FNCCADSys4, FMX.FNCCS4Shapes, FMX.FNCCS4Tasks,
  FMX.FNCCS4DXFModule, FMX.FNCCS4Legacy, FMX.FNCCS4Print, FMX.FNCCS4Views,
  FMX.FNCCS4Image, FMX.FNCCS4SVG, FMX.FNCCS4PrintFMX,
{$IFDEF MSWINDOWS}
  FMX.FNCCS4GDI,
{$ENDIF}
  { FMX.FNCCadSysRegister is here for its initialization section, not for
    the component palette: it is the only place that fills the class
    registry, and without it LoadFromFile and SaveToFile have no class
    to map the index they store onto. }
  FMX.FNCCadSysRegister;

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
    fLoggedWindow: TRect2D;
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
    { : Whether the sheet's viewports have their handles on. }
    fHandlesItem: TMenuItem;
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
    procedure DeleteSelectionClick(Sender: TObject);
    procedure DefineViewFromAreaClick(Sender: TObject);
    procedure DefineViewFromSelectionClick(Sender: TObject);
    procedure PlaceViewClick(Sender: TObject);
    procedure ListViewsClick(Sender: TObject);
    procedure DefineView(const ASpec: TCADViewSpec; const AHow: string);
    function LinkedViewportCount(const AView: TCADNamedView): Integer;
    function ViewNames: string;
    procedure ViewportHandlesClick(Sender: TObject);
    procedure MarkViewportHandles;
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
    procedure NewSheetClick(Sender: TObject);
    procedure ShowSheetClick(Sender: TObject);
    procedure LoadProgress(Sender: TObject; ReadPercent: Byte);
    procedure ViewPaint(Sender: TObject);
    function IsSameRect2D(const A, B: TRect2D): Boolean;
    procedure ExportDXFClick(Sender: TObject);
    function ExportSheet: TCADSheet;
    function AskExportFile(const AFilter, AExt: string;
      out AFileName: string): Boolean;
    procedure ExportSVGClick(Sender: TObject);
    procedure ExportPNGClick(Sender: TObject);
    procedure ExportEMFClick(Sender: TObject);
    procedure CopySheetClick(Sender: TObject);
    procedure ViewportInsetClick(Sender: TObject);
    procedure SampleViewportHook(Sender: TObject;
      const AInfo: TCADSheetViewportDrawInfo;
      const APhase: TCADViewportDrawPhase);
    procedure PrintPreviewClick(Sender: TObject);
    procedure PrintActualClick(Sender: TObject);
    procedure PrintFitClick(Sender: TObject);
    procedure PrintScaleClick(Sender: TObject);
    procedure ClipboardClick(Sender: TObject);
    procedure PrintPages(const ASetup: TCADPageSetup);
    procedure ExitClick(Sender: TObject);
    procedure TimeRepaintClick(Sender: TObject);
    procedure GenerateTestDrawingClick(Sender: TObject);
    procedure BenchmarkClick(Sender: TObject);
    procedure SmallObjectsClick(Sender: TObject);
    function SmallObjectModeName: string;
  end;

  { : The state the VCL demo uses to turn a selection into a source
    block. Copied unchanged apart from the input dialog. }
  TMyCADCreateTheSourceBlock = class(TCADState)
  public
    constructor Create(const CADPrg: TFNCCADPrg;
      const StateParam: TCADPrgParam;
      var NextState: TCADStateClass); override;
  end;

  { : The state that deletes a selection from whichever space the
    viewport is showing - the model, or the sheet on the screen. }
  TMyCADDeleteSelection = class(TCADState)
  public
    constructor Create(const CADPrg: TFNCCADPrg;
      const StateParam: TCADPrgParam;
      var NextState: TCADStateClass); override;
  end;

  { : The states that turn an area, or a selection, into a named view.
    Both end in TMainForm.DefineView, which asks for the name. }
  TMyCADDefineViewFromArea = class(TCADState)
  public
    constructor Create(const CADPrg: TFNCCADPrg;
      const StateParam: TCADPrgParam;
      var NextState: TCADStateClass); override;
  end;

  TMyCADDefineViewFromSelection = class(TCADState)
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

  { The layer this demo draws viewport handles on. High, so that it is
    out of the way of anything a drawing uses, and set up when the
    handles are first turned on. }
  DEMO_HANDLE_LAYER = 254;

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

constructor TMyCADDeleteSelection.Create(const CADPrg: TFNCCADPrg;
  const StateParam: TCADPrgParam; var NextState: TCADStateClass);
var
  TmpIter: TGraphicObjIterator;
  TmpView: TFNCCADViewport2D;
  TmpIDs: array of LongInt;
  TmpCount, Cont: Integer;
begin
  inherited;
  if Param is TCAD2DSelectObjectsParam then
  begin
    TmpView := TFNCCADPrg2D(CADPrg).Viewport2D;
    { The identifiers first and the deletions afterwards: a delete frees
      the object, and walking a list of references to freed objects is
      asking for trouble. }
    SetLength(TmpIDs, TCAD2DSelectObjectsParam(Param).SelectedObjects.Count);
    TmpCount := 0;
    TmpIter := TCAD2DSelectObjectsParam(Param).SelectedObjects.GetIterator;
    try
      TmpIter.First;
      while TmpIter.Current <> nil do
      begin
        TmpIDs[TmpCount] := TmpIter.Current.ID;
        Inc(TmpCount);
        TmpIter.Next;
      end;
    finally
      TmpIter.Free;
    end;
    { Through the active space, which is the point of the command being
      here at all: on a sheet this takes the object off the paper
      instead of hunting down the model object that happens to share
      the number. }
    for Cont := 0 to TmpCount - 1 do
      TmpView.DeleteObjectFromActiveSpace(TmpIDs[Cont]);
    CADPrg.RepaintAfterOperation;
  end;
  NextState := CADPrg.DefaultState;
  Param.Free;
  Param := nil;
end;

{ The library's warning hook. A plain procedure, not a method -
  TCADWarningEvent is not of object - so it logs through the unit-level
  Log rather than through the form. This is where a task that refused to
  start says so: the engine resets a failed state constructor silently,
  and without this the command simply appears to do nothing. }
procedure DemoLibraryWarning(const AMessage: String);
begin
  Log('library: ' + AMessage);
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
  TmpFile, TmpEdit, TmpView, TmpJust, TmpPrint, TmpNamed, TmpExport: TMenuItem;
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
  TmpExport := AddMenu(TmpFile, 'Export sheet');
  AddItem(TmpExport, 'SVG...', ExportSVGClick);
  AddItem(TmpExport, 'PNG...', ExportPNGClick);
  AddItem(TmpExport, 'EMF...', ExportEMFClick);
  AddItem(TmpExport, 'To clipboard (vector)', CopySheetClick);
  AddSeparator(TmpFile);
  AddItem(TmpFile, 'Save view...', SaveViewClick);
  AddItem(TmpFile, 'Open view...', OpenViewClick);
  AddItem(TmpFile, 'New sheet', NewSheetClick);
  AddItem(TmpFile, 'Show sheet / model', ShowSheetClick);
  AddItem(TmpFile, 'Viewport inset...', ViewportInsetClick);
  AddSeparator(TmpFile);
  TmpPrint := AddMenu(TmpFile, 'Print');
  AddItem(TmpPrint, 'Preview...', PrintPreviewClick);
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
  AddItem(TmpEdit, 'Delete selection', DeleteSelectionClick);
  fHandlesItem := AddCheckItem(TmpEdit, 'Viewport handles',
    ViewportHandlesClick, False);
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
  { Named views: parts of the model with a name, kept in the drawing,
    that sheet viewports link to rather than copy. Define in the model,
    place on a sheet - as often as you like, at different scales. }
  TmpNamed := AddMenu(TmpView, 'Named views');
  AddItem(TmpNamed, 'Define from an area', DefineViewFromAreaClick);
  AddItem(TmpNamed, 'Define from a selection', DefineViewFromSelectionClick);
  AddItem(TmpNamed, 'Place on sheet...', PlaceViewClick);
  AddItem(TmpNamed, 'List (log)', ListViewsClick);
  AddSeparator(TmpView);
  AddItem(TmpView, 'Time a repaint', TimeRepaintClick);
  AddItem(TmpView, 'Generate test drawing...', GenerateTestDrawingClick);
  AddItem(TmpView, 'Benchmark (log)', BenchmarkClick);
  AddItem(TmpView, 'Small objects: dot', SmallObjectsClick);
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
  { The sample furniture for a viewport with an inset - see
    SampleViewportHook. It does nothing for a viewport without one. }
  fCAD.OnDrawSheetViewport := SampleViewportHook;

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
  CADSysOnWarning := DemoLibraryWarning;
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
  begin
    fView.DrawObject2DWithRubber(Obj, True);
    { Logged, because the rubber pen over a shape of the same colour
      can be hard to see, and "did it select?" is the first question
      asked of every one of these tasks.

      Only a real pick: the task also calls this for every selected
      object on every repaint, so that an application can put its
      highlight back, and those carry PICK_NOOBJECT. Logging them too
      buried the one line that mattered under a hundred that did
      not. }
    if CtrlPt <= PICK_INBBOX then
      Exit;
    if Added then
      Log(Format('selected %s id %d, control point %d',
        [Obj.ClassName, Obj.ID, CtrlPt]))
    else
      Log(Format('deselected %s id %d', [Obj.ClassName, Obj.ID]));
  end;
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

{ Puts every viewport handle on the sheet onto the handle layer. Done
  after showing them, and again after switching sheets, because a new
  handle arrives on layer zero like anything else added to a sheet. }
procedure TMainForm.MarkViewportHandles;
var
  Cont: Integer;
  TmpProxy: TCADSheetViewportProxy2D;
begin
  if fView.Sheet = nil then
    Exit;
  for Cont := 0 to fView.Sheet.ViewportCount - 1 do
  begin
    TmpProxy := CADSheetViewportProxy(fView.Sheet, fView.Sheet.Viewports[Cont]);
    if TmpProxy <> nil then
      TmpProxy.Layer := DEMO_HANDLE_LAYER;
  end;
end;

procedure TMainForm.ViewportHandlesClick(Sender: TObject);
begin
  if fView.Sheet = nil then
  begin
    Say('Viewport handles are a paper-space thing. File - Show sheet / '
      + 'model first.');
    Exit;
  end;
  fHandlesItem.IsChecked := not fHandlesItem.IsChecked;
  if fHandlesItem.IsChecked then
  begin
    { A layer of their own first. A handle is exactly the viewport's
      rectangle, so it lands precisely on top of the border the
      viewport already draws - turning them on looked like nothing
      happening at all until they were given a pen that says
      "handle". The library has no opinion about how they look; this
      is the application deciding. }
    fCAD.Layers[DEMO_HANDLE_LAYER].Name := 'Viewport handles';
    fCAD.Layers[DEMO_HANDLE_LAYER].Pen.Color := TColorToCADColor(cadtcRed);
    fCAD.Layers[DEMO_HANDLE_LAYER].Pen.Style := cpsDash;
    { One object per viewport, on the sheet, standing in for a
      rectangle that is not an object. From here on the ordinary tools
      work on it: pick it and drag it with Move, take a corner with
      Edit primitive, catch it in an area selection. }
    CADSheetShowViewportProxies(fView.Sheet);
    MarkViewportHandles;
    Log(Format('viewport handles on: %d', [fView.Sheet.ViewportCount]));
    Say('Handles on - the red dashed rectangles, one per viewport, '
      + 'sitting on the viewport borders. Move drags one, Edit '
      + 'primitive takes a corner. They are not saved and not '
      + 'printed: try the print preview with them on.');
  end
  else
  begin
    CADSheetHideViewportProxies(fView.Sheet);
    Log('viewport handles off');
  end;
  fView.Repaint;
end;

procedure TMainForm.DeleteSelectionClick(Sender: TObject);
begin
  { The same command in both spaces, on purpose: what gets picked and
    what gets deleted is whatever the viewport is showing. }
  StartSelection(TMyCADDeleteSelection);
end;

{ ===================== named views ===================== }

constructor TMyCADDefineViewFromArea.Create(const CADPrg: TFNCCADPrg;
  const StateParam: TCADPrgParam; var NextState: TCADStateClass);
var
  TmpArea: TRect2D;
begin
  inherited;
  if Param is TCADPrgSelectAreaParam then
  begin
    TmpArea := TCADPrgSelectAreaParam(Param).Area;
    try
      MainForm.DefineView(CADViewFromArea(TmpArea), 'from an area');
    except
      { Two clicks on the same spot: a point frames nothing, and the
        library says so rather than making a view of it. }
      on E: Exception do
        Say(E.Message);
    end;
    CADPrg.RepaintAfterOperation;
  end;
  NextState := CADPrg.DefaultState;
  Param.Free;
  Param := nil;
end;

constructor TMyCADDefineViewFromSelection.Create(const CADPrg: TFNCCADPrg;
  const StateParam: TCADPrgParam; var NextState: TCADStateClass);
begin
  inherited;
  if Param is TCAD2DSelectObjectsParam then
  begin
    try
      MainForm.DefineView(CADViewFromObjects(TCAD2DSelectObjectsParam(Param)
        .SelectedObjects), 'from a selection');
    except
      { Accept with nothing selected. }
      on E: Exception do
        Say(E.Message);
    end;
    CADPrg.RepaintAfterOperation;
  end;
  NextState := CADPrg.DefaultState;
  Param.Free;
  Param := nil;
end;

procedure TMainForm.DefineViewFromAreaClick(Sender: TObject);
begin
  if fView.Sheet <> nil then
  begin
    Say('A named view frames part of the model. File - Show sheet / model '
      + 'back to the model first.');
    Exit;
  end;
  if fPrg.IsBusy then
    fPrg.StopOperation;
  { Two clicks, opposite corners - the same task Zoom area uses, with
    our own state at the end of it instead of a zoom. }
  fPrg.StartOperation(TCADPrgSelectArea,
    TCADPrgSelectAreaParam.Create(TMyCADDefineViewFromArea, nil));
end;

procedure TMainForm.DefineViewFromSelectionClick(Sender: TObject);
begin
  if fView.Sheet <> nil then
  begin
    Say('A named view frames part of the model. File - Show sheet / model '
      + 'back to the model first.');
    Exit;
  end;
  { Pick the objects, then Accept (F2): the view frames them all, with
    a margin. }
  StartSelection(TMyCADDefineViewFromSelection);
end;

{ Names the view and keeps it in the drawing. A name that is already in
  the list redefines that view instead of adding a second one: the
  identifier stays, so every viewport linked to it, on every sheet,
  shows the new framing the next time it is drawn. That is the link
  doing its job - redefine a detail that is placed twice and watch both
  follow. Only the framing changes; whatever else the view carries
  stays as it was. }
procedure TMainForm.DefineView(const ASpec: TCADViewSpec; const AHow: string);
var
  TmpName: string;
  TmpSpec: TCADViewSpec;
  TmpNamed: TCADNamedView;
  TmpWin: TRect2D;
begin
  TmpName := Format('Detail %d', [fCAD.Views.Count + 1]);
  if not AskString('Named view', 'Name (an existing name redefines it)',
    TmpName) then
    Exit;
  TmpName := Trim(TmpName);
  if TmpName = '' then
    Exit;
  TmpWin := ASpec.Window;
  TmpNamed := fCAD.Views.FindByName(TmpName);
  if TmpNamed <> nil then
  begin
    TmpSpec := TmpNamed.Spec;
    TmpSpec.Window := ASpec.Window;
    TmpNamed.Spec := TmpSpec;
    Log(Format('named view redefined %s: %s, %.2f, %.2f .. %.2f, %.2f, '
      + '%d viewport(s) linked', [AHow, TmpNamed.Name, TmpWin.Left,
      TmpWin.Bottom, TmpWin.Right, TmpWin.Top,
      LinkedViewportCount(TmpNamed)]));
    Say(Format('"%s" redefined %s. The %d viewport(s) linked to it follow '
      + '- show a sheet to see.', [TmpNamed.Name, AHow,
      LinkedViewportCount(TmpNamed)]));
  end
  else
  begin
    TmpNamed := fCAD.Views.Add(TmpName, ASpec);
    Log(Format('named view defined %s: %s, %.2f, %.2f .. %.2f, %.2f, id %s',
      [AHow, TmpNamed.Name, TmpWin.Left, TmpWin.Bottom, TmpWin.Right,
      TmpWin.Top, TmpNamed.Id]));
    Say(Format('"%s" defined %s. Show a sheet, then View - Named views - '
      + 'Place on sheet.', [TmpNamed.Name, AHow]));
  end;
end;

{ A new viewport on the sheet on the screen, linked to a named view.
  The scale is drawing units to a millimetre of paper - 0 fits the view
  into the viewport. With a scale the viewport is sized to show exactly
  the view at that scale; fitted, it is 120 mm wide, or 100 mm tall if
  that is the smaller. Each new one steps down and right from the
  top-left corner, so that several placed in a row do not land on top
  of each other. Move and resize them afterwards with the viewport
  handles. }
procedure TMainForm.PlaceViewClick(Sender: TObject);
var
  TmpName, TmpScaleStr: string;
  TmpNamed: TCADNamedView;
  TmpVP: TCADSheetViewport;
  TmpWin: TRect2D;
  TmpScale, TmpWinW, TmpWinH, TmpW, TmpH: TRealType;
  TmpSheetW, TmpSheetH, TmpLeft, TmpTop: TRealType;
  TmpStep: Integer;
begin
  if fView.Sheet = nil then
  begin
    Say('A view is placed on a sheet. File - Show sheet / model first.');
    Exit;
  end;
  if fCAD.Views.Count = 0 then
  begin
    Say('No named views yet. In the model: View - Named views - Define '
      + 'from an area, or from a selection.');
    Exit;
  end;
  if fPrg.IsBusy then
    fPrg.StopOperation;
  TmpName := fCAD.Views[fCAD.Views.Count - 1].Name;
  if not AskString('Place a named view', Format('View (%s)', [ViewNames]),
    TmpName) then
    Exit;
  TmpNamed := fCAD.Views.FindByName(Trim(TmpName));
  if TmpNamed = nil then
  begin
    Say(Format('No view named "%s". There are: %s.', [TmpName, ViewNames]));
    Exit;
  end;
  TmpScaleStr := '0';
  if not AskString('Place a named view',
    'Drawing units per mm of paper (0 fits)', TmpScaleStr) then
    Exit;
  TmpScale := StrToFloatDef(Trim(TmpScaleStr), -1);
  if TmpScale < 0 then
  begin
    Say(Format('"%s" is not a scale. 0 fits; 2 is two drawing units to '
      + 'the millimetre.', [TmpScaleStr]));
    Exit;
  end;

  TmpWin := ReorderRect2D(TmpNamed.Spec.Window);
  TmpWinW := TmpWin.Right - TmpWin.Left;
  TmpWinH := TmpWin.Top - TmpWin.Bottom;
  if (TmpWinW <= 0) or (TmpWinH <= 0) then
  begin
    Say(Format('"%s" frames nothing - define it again.', [TmpNamed.Name]));
    Exit;
  end;
  if TmpScale > 0 then
  begin
    TmpW := TmpWinW / TmpScale;
    TmpH := TmpWinH / TmpScale;
  end
  else
  begin
    TmpW := 120;
    TmpH := 120 * TmpWinH / TmpWinW;
    if TmpH > 100 then
    begin
      TmpW := TmpW * 100 / TmpH;
      TmpH := 100;
    end;
  end;

  fView.Sheet.SizeMM(TmpSheetW, TmpSheetH);
  if (TmpW > TmpSheetW - 20) or (TmpH > TmpSheetH - 20) then
  begin
    Say(Format('At that scale "%s" is %.0f x %.0f mm, which does not fit '
      + 'on the paper. Try a larger number, or 0.', [TmpNamed.Name, TmpW,
      TmpH]));
    Exit;
  end;
  if (TmpW < 5) or (TmpH < 5) then
  begin
    Say(Format('At that scale "%s" is %.1f x %.1f mm - too small to see. '
      + 'Try a smaller number, or 0.', [TmpNamed.Name, TmpW, TmpH]));
    Exit;
  end;
  TmpStep := fView.Sheet.ViewportCount mod 6;
  TmpLeft := 20 + TmpStep * 15;
  TmpTop := TmpSheetH - 20 - TmpStep * 15;
  if TmpLeft + TmpW > TmpSheetW - 10 then
    TmpLeft := TmpSheetW - 10 - TmpW;
  if TmpTop - TmpH < 10 then
    TmpTop := 10 + TmpH;

  TmpVP := fView.Sheet.AddViewport;
  TmpVP.Name := TmpNamed.Name;
  TmpVP.RectMM := Rect2D(TmpLeft, TmpTop - TmpH, TmpLeft + TmpW, TmpTop);
  TmpVP.UnitsPerMM := TmpScale;
  { The link, not a copy: the viewport shows whatever the named view
    frames from now on. It also keeps a copy of its own, which is what
    it falls back on if the view is deleted. }
  TmpVP.LinkTo(TmpNamed);

  if fHandlesItem.IsChecked then
  begin
    CADSheetShowViewportProxies(fView.Sheet);
    MarkViewportHandles;
  end;
  Log(Format('placed "%s" on %s: %.1f x %.1f mm at %.1f, %.1f, '
    + 'units per mm %.4g, %d viewport(s) linked to it',
    [TmpNamed.Name, fView.Sheet.Name, TmpW, TmpH, TmpLeft, TmpTop - TmpH,
    TmpScale, LinkedViewportCount(TmpNamed)]));
  fView.Repaint;
end;

procedure TMainForm.ListViewsClick(Sender: TObject);
var
  Cont: Integer;
  TmpWin: TRect2D;
begin
  if fCAD.Views.Count = 0 then
  begin
    Say('No named views yet. In the model: View - Named views - Define '
      + 'from an area, or from a selection.');
    Exit;
  end;
  Log(Format('named views: %d', [fCAD.Views.Count]));
  for Cont := 0 to fCAD.Views.Count - 1 do
  begin
    TmpWin := fCAD.Views[Cont].Spec.Window;
    Log(Format('  %s: %.2f, %.2f .. %.2f, %.2f, %d viewport(s) linked, '
      + 'id %s', [fCAD.Views[Cont].Name, TmpWin.Left, TmpWin.Bottom,
      TmpWin.Right, TmpWin.Top, LinkedViewportCount(fCAD.Views[Cont]),
      fCAD.Views[Cont].Id]));
  end;
  Say(Format('%d named view(s): %s. The windows and links are in the log.',
    [fCAD.Views.Count, ViewNames]));
end;

{ How many sheet viewports, on all the sheets, show AView. }
function TMainForm.LinkedViewportCount(const AView: TCADNamedView): Integer;
var
  CSheet, CPort: Integer;
begin
  Result := 0;
  for CSheet := 0 to fCAD.Sheets.Count - 1 do
    for CPort := 0 to fCAD.Sheets[CSheet].ViewportCount - 1 do
      if fCAD.Sheets[CSheet].Viewports[CPort].LinkedView(fCAD) = AView then
        Inc(Result);
end;

function TMainForm.ViewNames: string;
var
  Cont: Integer;
begin
  Result := '';
  for Cont := 0 to fCAD.Views.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + fCAD.Views[Cont].Name;
  end;
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
var
  TmpSpace: String;
begin
  { Logged once, the first time a paint establishes it. ViewScale is
    zero until then - the canvas is the only thing that knows the
    display's scale and it does not exist before the first paint - so
    logging it from OnShow would only ever record the zero. On VCL it
    is one by construction; on FMX it is what decides whether the back
    buffer holds the display's real pixels. }
  { And the framing, every time it changes. Zoom and pan are the
    operations with nothing else to show for themselves: when one
    misbehaves, the only question worth asking is what window it
    produced, and an impression of it is no use at all. }
  if not IsSameRect2D(fLoggedWindow, fView.VisualRect) then
  begin
    fLoggedWindow := fView.VisualRect;
    if fView.Sheet <> nil then
      TmpSpace := ' mm, paper space'
    else
      TmpSpace := ' model';
    Log(Format('viewport: window %.2f,%.2f .. %.2f,%.2f (%.2f x %.2f)%s',
      [fView.VisualRect.Left, fView.VisualRect.Bottom, fView.VisualRect.Right,
      fView.VisualRect.Top, fView.VisualRect.Right - fView.VisualRect.Left,
      fView.VisualRect.Top - fView.VisualRect.Bottom, TmpSpace]));
  end;

  if fLoggedScale = fView.ViewScale then
    Exit;
  fLoggedScale := fView.ViewScale;
  Log(Format('viewport: ViewScale %.3f, buffer %d x %d',
    [fView.ViewScale, fView.ControlRect.Right, fView.ControlRect.Bottom]));
end;

{ : Two rectangles the same to within a whisker. The window is rebuilt
  by floating-point arithmetic on every repaint, so comparing it
  exactly would log a line for every paint. }
function TMainForm.IsSameRect2D(const A, B: TRect2D): Boolean;
begin
  Result := (Abs(A.Left - B.Left) < 1E-6) and (Abs(A.Right - B.Right) < 1E-6)
    and (Abs(A.Bottom - B.Bottom) < 1E-6) and (Abs(A.Top - B.Top) < 1E-6);
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

procedure TMainForm.PrintPreviewClick(Sender: TObject);
var
  TmpSetup: TCADPageSetup;
  TmpView: TCADViewSpec;
begin
  { Seeded from what is on screen, so the preview opens on the view the
    user is looking at rather than on the whole drawing. A saved view is
    most of a page setup already - which is why the setup holds one
    rather than a window of its own. }
  fView.CaptureView(TmpView);
  TmpSetup := TCADPageSetup.Default;
  TmpSetup.View := TmpView;
  TPrintPreviewForm.Execute(Self, fCAD, TmpSetup);
end;

procedure TMainForm.PrintPages(const ASetup: TCADPageSetup);
begin
{$IFDEF MSWINDOWS}
  { FMX has no print dialog of its own, so the printer is FMX's active
    one - the default printer unless the application chose another
    through FMX.Printer. }
  if CADFMXPrinterName = '' then
  begin
    Say('There is no printer.');
    Exit;
  end;
  { On the printer the dialog chose, through GDI on its own device
    context - FMX.FNCCS4PrintFMX. The same pages the preview shows. }
  CADPrintPagesFMX(fCAD, ASetup, 'CAD2D');
  Log('printed on ' + CADFMXPrinterName);
  Say('Sent to ' + CADFMXPrinterName + '.');
{$ELSE}
  Say('Printing from FMX is Windows-only: File - Print - Preview, then PDF.');
{$ENDIF}
end;

procedure TMainForm.PrintActualClick(Sender: TObject);
var
  TmpSetup: TCADPageSetup;
  TmpView: TCADViewSpec;
begin
  { What is on the screen, fitted to the page. }
  fView.CaptureView(TmpView);
  TmpSetup := TCADPageSetup.Default;
  TmpSetup.View := TmpView;
  PrintPages(TmpSetup);
end;

procedure TMainForm.PrintFitClick(Sender: TObject);
begin
  { The whole drawing: an empty window is the drawing's extension. }
  PrintPages(TCADPageSetup.Default);
end;

procedure TMainForm.PrintScaleClick(Sender: TObject);
var
  TmpSetup: TCADPageSetup;
  TmpView: TCADViewSpec;
  TmpScale: string;
begin
  TmpScale := '1';
  if not AskString('Print to scale', 'Drawing units per mm of paper',
    TmpScale) then
    Exit;
  fView.CaptureView(TmpView);
  TmpSetup := TCADPageSetup.Default;
  TmpSetup.View := TmpView;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := StrToFloatDef(Trim(TmpScale), 0);
  if TmpSetup.UnitsPerMM <= 0 then
  begin
    Say(Format('"%s" is not a scale.', [TmpScale]));
    Exit;
  end;
  { Tiled: a drawing larger than the paper at that scale goes on as many
    pages as it takes. }
  TmpSetup.Tiled := True;
  PrintPages(TmpSetup);
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

procedure TMainForm.NewSheetClick(Sender: TObject);
var
  TmpSheet: TCADSheet;
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpW, TmpH: TRealType;
begin
  { Paper space. Everything below is either a rectangle in millimetres
    of paper or a view captured off the screen - there is no
    sheet-specific drawing code anywhere in this handler, because a
    sheet's own objects are ordinary shapes. That is the whole design.

    A new sheet is A3 landscape, so 420 x 297. }
  TmpSheet := fCAD.Sheets.Add(Format('Sheet %d', [fCAD.Sheets.Count + 1]));
  TmpSheet.SizeMM(TmpW, TmpH);

  { A frame inside the margins and a title block in the bottom-right
    corner - millimetres, origin at the bottom-left of the paper, Y
    upwards as in the model. }
  TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10),
    Point2D(TmpW - 10, TmpH - 10)));
  TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(TmpW - 110, 10),
    Point2D(TmpW - 10, 35)));
  try
    TmpSheet.AddObject(TJustifiedVectText2D.Create(-1,
      CADSysFindFontByIndex(0), Rect2D(TmpW - 105, 18, TmpW - 15, 30), 6,
      TmpSheet.Name));
  except
    { RomanC.json is not beside the exe. A title block without its text
      is still a title block, and a demo that refuses to make a sheet
      over a missing font is not. }
    Log('sheet: no vector font registered, title block left blank');
  end;

  { One viewport over what is left of the paper, showing what the
    screen is showing. UnitsPerMM stays 0, which means fit - a scale is
    something to choose once there is something to look at. }
  TmpVP := TmpSheet.AddViewport;
  TmpVP.Name := 'Main';
  TmpVP.RectMM := Rect2D(15, 40, TmpW - 15, TmpH - 15);
  fView.CaptureView(TmpView);
  TmpVP.View := TmpView;

  Log(Format('sheet added: %s, %.0f x %.0f mm, viewport %.0f x %.0f mm',
    [TmpSheet.Name, TmpW, TmpH, TmpVP.WidthMM, TmpVP.HeightMM]));
  Say(Format('%s added. File - Print - Preview, then pick it in the Show '
    + 'box.', [TmpSheet.Name]));
end;

procedure TMainForm.ShowSheetClick(Sender: TObject);
var
  TmpIndex, Cont: Integer;
begin
  if fCAD.Sheets.Count = 0 then
  begin
    Say('There are no sheets yet. File - New sheet makes one.');
    Exit;
  end;
  { Cycles: the model, then each sheet in turn, then back to the model.
    One menu item and no dialog - this is a demo, and what is being
    demonstrated is that a viewport can show a sheet, not how to choose
    one. }
  TmpIndex := -1;
  if fView.Sheet <> nil then
    for Cont := 0 to fCAD.Sheets.Count - 1 do
      if fCAD.Sheets[Cont] = fView.Sheet then
      begin
        TmpIndex := Cont;
        Break;
      end;
  Inc(TmpIndex);
  if TmpIndex >= fCAD.Sheets.Count then
  begin
    { Putting the sheet down restores the window the model had. }
    fView.Sheet := nil;
    Log('viewport: showing the model');
    Say('Showing the model.');
  end
  else
  begin
    fView.Sheet := fCAD.Sheets[TmpIndex];
    Log(Format('viewport: showing sheet %s, %d viewport(s), %d object(s)',
      [fView.Sheet.Name, fView.Sheet.ViewportCount,
      fView.Sheet.ObjectsCount]));
    Say(Format('Showing %s. The rulers are in millimetres of paper now, '
      + 'and so is everything you draw.', [fView.Sheet.Name]));
  end;
  { Handles belong to the sheet on the screen, so they follow it - and
    there are none to have in the model. The ones left on the sheet we
    just put down do no harm: they are not saved and not printed. }
  if fHandlesItem.IsChecked then
  begin
    if fView.Sheet <> nil then
    begin
      CADSheetShowViewportProxies(fView.Sheet);
      MarkViewportHandles;
    end
    else
      fHandlesItem.IsChecked := False;
  end;
  fView.Repaint;
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
var
  TmpView: TCADViewSpec;
  TmpWin: TRect2D;
begin
{$IFDEF MSWINDOWS}
  if fView.Sheet <> nil then
  begin
    CopySheetClick(Sender);
    Exit;
  end;
  { The window on the screen, as large on paper as it is on the screen -
    a screen pixel taken as a ninety-sixth of an inch. }
  fView.CaptureView(TmpView);
  TmpWin := ReorderRect2D(TmpView.Window);
  CADCopyModelRectToClipboardWin(fCAD, TmpWin, (TmpWin.Right - TmpWin.Left) /
    Max(1, fView.Width * 25.4 / 96));
  Log('clipboard: the view');
  Say('The view is on the clipboard as a metafile, a PNG and a bitmap.');
{$ELSE}
  Say('The clipboard export is Windows-only.');
{$ENDIF}
end;

procedure TMainForm.ExitClick(Sender: TObject);
begin
  Close;
end;

{ A drawing to measure with: the given number of small shapes - lines,
  frames, filled ellipses, polylines and text - scattered over a square
  10000 units wide, a few units to twenty across each. At zoom-all most
  of them are a pixel or less, which is the case the drawing-speed work
  is about; zoomed in, they are ordinary shapes. The same seed every
  time, so two runs of the benchmark draw the same drawing. }
procedure TMainForm.GenerateTestDrawingClick(Sender: TObject);
var
  TmpStr: string;
  TmpCount, Cont: Integer;
  TmpX, TmpY, TmpS: TRealType;
  TmpObj: TObject2D;
  TmpOldDraw: Boolean;
  TmpWatch: TStopwatch;
begin
  if fView.Sheet <> nil then
  begin
    Say('The test drawing goes in the model. File - Show sheet / model '
      + 'back to the model first.');
    Exit;
  end;
  TmpStr := '100000';
  if not AskString('Generate test drawing',
    'Number of objects (replaces the drawing)', TmpStr) then
    Exit;
  TmpCount := StrToIntDef(Trim(TmpStr), 0);
  if TmpCount <= 0 then
    Exit;
  if fPrg.IsBusy then
    fPrg.StopOperation;
  TmpWatch := TStopwatch.StartNew;
  RandSeed := 42;
  TmpOldDraw := fCAD.DrawOnAdd;
  fCAD.DrawOnAdd := False;
  try
    fCAD.DeleteAllObjects;
    for Cont := 0 to TmpCount - 1 do
    begin
      TmpX := Random * 10000;
      TmpY := Random * 10000;
      TmpS := 0.5 + Random * 20;
      case Cont mod 5 of
        0:
          TmpObj := TLine2D.Create(-1, Point2D(TmpX, TmpY),
            Point2D(TmpX + TmpS, TmpY + TmpS * 0.3));
        1:
          TmpObj := TFrame2D.Create(-1, Point2D(TmpX, TmpY),
            Point2D(TmpX + TmpS, TmpY + TmpS * 0.6));
        2:
          TmpObj := TFilledEllipse2D.Create(-1, Point2D(TmpX, TmpY),
            Point2D(TmpX + TmpS, TmpY + TmpS));
        3:
          TmpObj := TPolyline2D.Create(-1, [Point2D(TmpX, TmpY),
            Point2D(TmpX + TmpS, TmpY), Point2D(TmpX + TmpS, TmpY + TmpS),
            Point2D(TmpX + TmpS * 2, TmpY + TmpS)]);
      else
        TmpObj := TText2D.Create(-1, Rect2D(TmpX, TmpY, TmpX + TmpS * 3,
          TmpY + TmpS), TmpS, AnsiString('T' + IntToStr(Cont mod 100)));
      end;
      fCAD.CurrentLayer := Cont mod 4;
      fCAD.AddObject(-1, TmpObj);
    end;
  finally
    fCAD.DrawOnAdd := TmpOldDraw;
    fCAD.CurrentLayer := 0;
  end;
  Log(Format('test drawing: %d objects generated in %d ms',
    [TmpCount, TmpWatch.ElapsedMilliseconds]));
  fView.ZoomToExtension;
  { The buffer still holds the drawing from before; a zoom would only
    stretch that until the settle time is up. }
  fView.FlushViewChange;
end;

{ Times what the drawing-speed work changes, into the log. Each line is
  a number to compare before and after a change, on the same machine,
  with the same generated drawing:

  - a full repaint at zoom-all, where most objects are sub-pixel;
  - a full repaint zoomed in to a twentieth of the drawing;
  - one pan step, averaged over fifty, at zoom-all - redrawing the
    drawing each time, as with ViewChangeSettleMS 0;
  - one zoom step, averaged over ten, the same way;
  - the same pan steps as a view change, which moves the picture
    already drawn and redraws once at the end - that one redraw is
    included.

  Repaint here means the back buffer: the screen gets it on the next
  paint, which is not counted. The view is put back afterwards. }
procedure TMainForm.BenchmarkClick(Sender: TObject);
const
  PAN_STEPS = 50;
  ZOOM_STEPS = 10;
var
  TmpWatch: TStopwatch;
  TmpOld, TmpAll: TRect2D;
  TmpCX, TmpCY, TmpW, TmpH, TmpStep: TRealType;
  TmpFull, TmpIn, TmpPan, TmpZoom, TmpCached: Int64;
  TmpSettle: Integer;
  Cont: Integer;
begin
  if fPrg.IsBusy then
    fPrg.StopOperation;
  { Measured redrawing on every change first, the way it was. }
  TmpSettle := fView.ViewChangeSettleMS;
  fView.ViewChangeSettleMS := 0;
  TmpOld := fView.VisualRect;
  fView.ZoomToExtension;
  TmpAll := fView.VisualRect;

  TmpWatch := TStopwatch.StartNew;
  fView.Repaint;
  TmpFull := TmpWatch.ElapsedMilliseconds;

  TmpCX := (TmpAll.Left + TmpAll.Right) / 2;
  TmpCY := (TmpAll.Bottom + TmpAll.Top) / 2;
  TmpW := (TmpAll.Right - TmpAll.Left) / 40;
  TmpH := (TmpAll.Top - TmpAll.Bottom) / 40;
  fView.ZoomWindow(Rect2D(TmpCX - TmpW, TmpCY - TmpH, TmpCX + TmpW,
    TmpCY + TmpH));
  TmpWatch := TStopwatch.StartNew;
  fView.Repaint;
  TmpIn := TmpWatch.ElapsedMilliseconds;

  fView.ZoomWindow(TmpAll);
  TmpStep := (TmpAll.Right - TmpAll.Left) / 200;
  TmpWatch := TStopwatch.StartNew;
  for Cont := 1 to PAN_STEPS do
    fView.PanWindow(TmpStep, 0);
  TmpPan := TmpWatch.ElapsedMilliseconds;

  fView.ZoomWindow(TmpAll);
  TmpWatch := TStopwatch.StartNew;
  for Cont := 1 to ZOOM_STEPS div 2 do
  begin
    fView.ZoomIn;
    fView.ZoomOut;
  end;
  TmpZoom := TmpWatch.ElapsedMilliseconds;

  { And the same pan as a gesture: what the real-time pan does. }
  fView.ZoomWindow(TmpAll);
  TmpWatch := TStopwatch.StartNew;
  fView.BeginViewChange;
  try
    for Cont := 1 to PAN_STEPS do
      fView.PanWindow(TmpStep, 0);
  finally
    fView.EndViewChange;
  end;
  TmpCached := TmpWatch.ElapsedMilliseconds;

  fView.ViewChangeSettleMS := TmpSettle;
  fView.ZoomWindow(TmpOld);
  fView.FlushViewChange;
  Log(Format('benchmark: %d objects, small objects %s; repaint at zoom-all '
    + '%d ms, zoomed in %d ms; pan step %.1f ms; zoom step %.1f ms; '
    + '%d pan steps as one view change %d ms in all',
    [fCAD.ObjectsCount, SmallObjectModeName, TmpFull, TmpIn,
    TmpPan / PAN_STEPS, TmpZoom / ZOOM_STEPS, PAN_STEPS, TmpCached]));
  Say(Format('%d objects. Repaint: %d ms at zoom-all, %d ms zoomed in. '
    + 'Pan step %.1f ms, zoom step %.1f ms. Also in the log.',
    [fCAD.ObjectsCount, TmpFull, TmpIn, TmpPan / PAN_STEPS,
    TmpZoom / ZOOM_STEPS]));
end;

{ Cycles what the screen does with an object smaller than a pixel:
  a dot (the default), nothing, or the whole object as before. For
  comparing the three with the benchmark, and by eye. }
procedure TMainForm.SmallObjectsClick(Sender: TObject);
begin
  case fView.SmallObjectMode of
    somDot:
      fView.SmallObjectMode := somSkip;
    somSkip:
      fView.SmallObjectMode := somDraw;
  else
    fView.SmallObjectMode := somDot;
  end;
  (Sender as TMenuItem).Text := 'Small objects: ' + SmallObjectModeName;
  Log('small objects: ' + SmallObjectModeName);
  fView.Repaint;
end;

function TMainForm.SmallObjectModeName: string;
begin
  case fView.SmallObjectMode of
    somDot:
      Result := 'dot';
    somSkip:
      Result := 'skip';
  else
    Result := 'draw';
  end;
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

{ ------------------------------------------------------------------
  Sheet output and viewport furniture (CS-04 to CS-07, CS-01)
  ------------------------------------------------------------------ }

function TMainForm.ExportSheet: TCADSheet;
begin
  { The sheet on the screen, or the first one when the model is. }
  Result := fView.Sheet;
  if (Result = nil) and (fCAD.Sheets.Count > 0) then
    Result := fCAD.Sheets[0];
  if Result = nil then
    Say('There are no sheets yet. File - New sheet makes one.');
end;

function TMainForm.AskExportFile(const AFilter, AExt: string;
  out AFileName: string): Boolean;
var
  TmpDlg: TSaveDialog;
begin
  AFileName := '';
  TmpDlg := TSaveDialog.Create(Self);
  try
    TmpDlg.Filter := AFilter;
    TmpDlg.DefaultExt := AExt;
    Result := TmpDlg.Execute;
    if Result then
      AFileName := TmpDlg.FileName;
  finally
    TmpDlg.Free;
  end;
end;

procedure TMainForm.ExportSVGClick(Sender: TObject);
var
  TmpSheet: TCADSheet;
  TmpName: string;
begin
  TmpSheet := ExportSheet;
  if (TmpSheet = nil) or not AskExportFile('SVG (*.svg)|*.svg', 'svg',
    TmpName) then
    Exit;
  CADSaveSheetsToSVG(fCAD, [TmpSheet], TmpName);
  Log('export: SVG ' + TmpName);
  Say(Format('%s written as SVG, at the size of its paper.', [TmpSheet.Name]));
end;

procedure TMainForm.ExportPNGClick(Sender: TObject);
var
  TmpSheet: TCADSheet;
  TmpName, TmpDPI: string;
begin
  TmpSheet := ExportSheet;
  if TmpSheet = nil then
    Exit;
  TmpDPI := '300';
  if not AskString('Export PNG', 'Dots per inch', TmpDPI) then
    Exit;
  if StrToIntDef(Trim(TmpDPI), 0) <= 0 then
  begin
    Say(Format('"%s" is not a resolution.', [TmpDPI]));
    Exit;
  end;
  if not AskExportFile('PNG (*.png)|*.png', 'png', TmpName) then
    Exit;
  try
    CADSaveSheetToImage(fCAD, TmpSheet, TmpName, StrToInt(Trim(TmpDPI)));
  except
    on E: ECADPageError do
    begin
      Say(E.Message);
      Exit;
    end;
  end;
  Log('export: PNG ' + TmpName);
  Say(Format('%s written as PNG at %s dpi.', [TmpSheet.Name, Trim(TmpDPI)]));
end;

procedure TMainForm.ExportEMFClick(Sender: TObject);
var
  TmpSheet: TCADSheet;
  TmpName: string;
begin
{$IFDEF MSWINDOWS}
  TmpSheet := ExportSheet;
  if (TmpSheet = nil) or not AskExportFile('Enhanced metafile (*.emf)|*.emf',
    'emf', TmpName) then
    Exit;
  CADSaveSheetToEMF(fCAD, TmpSheet, TmpName);
  Log('export: EMF ' + TmpName);
  Say(Format('%s written as an enhanced metafile.', [TmpSheet.Name]));
{$ELSE}
  Say('Metafiles are a Windows thing.');
{$ENDIF}
end;

procedure TMainForm.CopySheetClick(Sender: TObject);
var
  TmpSheet: TCADSheet;
begin
{$IFDEF MSWINDOWS}
  TmpSheet := ExportSheet;
  if TmpSheet = nil then
    Exit;
  CADCopySheetToClipboardWin(fCAD, TmpSheet);
  Log('export: ' + TmpSheet.Name + ' to the clipboard');
  Say(Format('%s is on the clipboard as a metafile, a PNG and a bitmap. '
    + 'Word and PowerPoint paste the metafile, which stays sharp.',
    [TmpSheet.Name]));
{$ELSE}
  Say('The clipboard export is Windows-only.');
{$ENDIF}
end;

procedure TMainForm.ViewportInsetClick(Sender: TObject);
var
  TmpVP: TCADSheetViewport;
  TmpText: string;
  TmpParts: TArray<string>;
  TmpValues: array [0 .. 3] of TRealType;
  TmpInset: TRect2D;
  Cont: Integer;
begin
  if fView.Sheet = nil then
  begin
    Say('An inset belongs to a sheet viewport. File - Show sheet / model '
      + 'first.');
    Exit;
  end;
  if fView.Sheet.ViewportCount = 0 then
  begin
    Say('This sheet has no viewports.');
    Exit;
  end;
  { The last viewport placed: a demo, not a picker. }
  TmpVP := fView.Sheet.Viewports[fView.Sheet.ViewportCount - 1];
  TmpInset := TmpVP.ContentInsetMM;
  if (TmpInset.Left = 0) and (TmpInset.Top = 0) and (TmpInset.Right = 0) and
    (TmpInset.Bottom = 0) then
    TmpText := '25; 10; 0; 0'
  else
    TmpText := Format('%g; %g; %g; %g', [TmpInset.Left, TmpInset.Top,
      TmpInset.Right, TmpInset.Bottom]);
  { Semicolons: a decimal comma is a comma too. }
  if not AskString('Viewport inset', Format('Margins inside "%s", mm: left; '
    + 'top; right; bottom', [TmpVP.Name]), TmpText) then
    Exit;
  TmpParts := TmpText.Split([';']);
  if Length(TmpParts) <> 4 then
  begin
    Say('Four numbers, separated by semicolons: left; top; right; bottom.');
    Exit;
  end;
  for Cont := 0 to 3 do
  begin
    TmpValues[Cont] := StrToFloatDef(Trim(TmpParts[Cont]), -1);
    if TmpValues[Cont] < 0 then
    begin
      Say(Format('"%s" is not a margin.', [Trim(TmpParts[Cont])]));
      Exit;
    end;
  end;
  { Rect2D takes left, bottom, right, top; each one here is a width. }
  TmpVP.ContentInsetMM := Rect2D(TmpValues[0], TmpValues[3], TmpValues[2],
    TmpValues[1]);
  Log(Format('viewport "%s": inset %g; %g; %g; %g mm', [TmpVP.Name,
    TmpValues[0], TmpValues[1], TmpValues[2], TmpValues[3]]));
  fView.Repaint;
  Say('The model keeps out of those margins now. The sample hook draws in '
    + 'them: the model window''s X range and ten ticks across the top, the '
    + 'Y range down the left - in the preview, the PDF and every export '
    + 'too.');
end;

procedure TMainForm.SampleViewportHook(Sender: TObject;
  const AInfo: TCADSheetViewportDrawInfo;
  const APhase: TCADViewportDrawPhase);
var
  G: TCADGraphics;
  TmpBand, TmpR: TRect;
  TmpFont: TCADFontSpec;
  TmpWin: TRect2D;
  TmpPt: TPoint2D;
  I, TmpTick: Integer;
begin
  { What an application draws per viewport: here, a band in each margin
    with ticks at tenths of the model window and the range written in
    it. A viewport without an inset has no margins and gets nothing. }
  if APhase <> vdpAfterModel then
    Exit;
  G := AInfo.Canvas.Graphics;
  TmpWin := ReorderRect2D(AInfo.ModelWindow);
  G.Pen.Style := cpsSolid;
  G.Pen.Color := cadclGray;
  G.Pen.Width := Max(1, Round(0.2 * AInfo.PixelsPerMM));
  G.Brush.Style := cbsSolid;
  G.Brush.Color := CADColor($FF, $F2, $F2, $EC);
  TmpFont := TCADFontSpec.Default;
  TmpFont.FaceName := 'Arial';

  if AInfo.ContentPx.Top > AInfo.OuterPx.Top then
  begin
    TmpBand := Rect(AInfo.ContentPx.Left, AInfo.OuterPx.Top,
      AInfo.ContentPx.Right, AInfo.ContentPx.Top);
    G.Rectangle(TmpBand.Left, TmpBand.Top, TmpBand.Right, TmpBand.Bottom);
    TmpTick := (TmpBand.Bottom - TmpBand.Top) div 3;
    for I := 0 to 10 do
    begin
      TmpPt := TransformPoint2D(Point2D(TmpWin.Left + I * (TmpWin.Right -
        TmpWin.Left) / 10, TmpWin.Top), AInfo.ModelToDevice);
      G.MoveTo(Round(TmpPt.X), TmpBand.Bottom);
      G.LineTo(Round(TmpPt.X), TmpBand.Bottom - TmpTick);
    end;
    TmpFont.Height := -Max(1, Round((TmpBand.Bottom - TmpBand.Top) * 0.4));
    G.SelectFont(TmpFont);
    try
      G.FontColor := cadclBlack;
      G.Transparent := True;
      TmpR := Rect(TmpBand.Left + Round(AInfo.PixelsPerMM), TmpBand.Top,
        TmpBand.Right, TmpBand.Bottom - TmpTick);
      G.DrawText(Format('x %.5g .. %.5g', [TmpWin.Left, TmpWin.Right]), TmpR,
        CAD_DT_SINGLELINE or CAD_DT_VCENTER or CAD_DT_NOPREFIX);
    finally
      G.ResetFont;
    end;
  end;

  if AInfo.ContentPx.Left > AInfo.OuterPx.Left then
  begin
    TmpBand := Rect(AInfo.OuterPx.Left, AInfo.ContentPx.Top,
      AInfo.ContentPx.Left, AInfo.ContentPx.Bottom);
    G.Rectangle(TmpBand.Left, TmpBand.Top, TmpBand.Right, TmpBand.Bottom);
    TmpTick := (TmpBand.Right - TmpBand.Left) div 4;
    for I := 0 to 10 do
    begin
      TmpPt := TransformPoint2D(Point2D(TmpWin.Left, TmpWin.Bottom + I *
        (TmpWin.Top - TmpWin.Bottom) / 10), AInfo.ModelToDevice);
      G.MoveTo(TmpBand.Right, Round(TmpPt.Y));
      G.LineTo(TmpBand.Right - TmpTick, Round(TmpPt.Y));
    end;
    TmpFont.Height := -Max(1, Round(3 * AInfo.PixelsPerMM));
    G.SelectFont(TmpFont);
    try
      G.FontColor := cadclBlack;
      G.Transparent := True;
      TmpR := Rect(TmpBand.Left + Round(AInfo.PixelsPerMM),
        TmpBand.Top + Round(AInfo.PixelsPerMM), TmpBand.Right - TmpTick,
        TmpBand.Bottom);
      G.DrawText(Format('y %.5g .. %.5g', [TmpWin.Bottom, TmpWin.Top]), TmpR,
        CAD_DT_WORDBREAK or CAD_DT_NOPREFIX);
    finally
      G.ResetFont;
    end;
  end;
end;

initialization

{ The vector font the text tool and the DXF reader need. Registered from
  the file next to the exe, exactly as the VCL demo does it. }
if FileExists(ExtractFilePath(ParamStr(0)) + 'RomanC.json') then
  CADSysRegisterFontFromFile(0, ExtractFilePath(ParamStr(0)) +
    'RomanC.json');


end.
