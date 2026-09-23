{: Saved views of a drawing.

   A <See Class=TCADViewSpec> is everything it takes to look at a drawing:
   which drawing, which part of it, and which layers are showing. It is a
   value, not a control and not a file format - a view file is one of these
   serialised, and a sheet (paper space, when it arrives) is several of them
   with annotation around them. Keeping it a value is what stops the two
   from needing separate code.

   Applying one needs no drawing code at all:
   <See Method=TFNCCADViewport@ApplyView> sets the framing the viewport
   already knows how to produce. The clipped-into-a-rectangle-on-a-sheet
   rendering only arrives with sheets.

     var
       TmpView: TCADViewSpec;
     begin
       TmpView.LoadFromFile('overview.cadview');
       CAD.LoadFromFile(TmpView.DrawingFile);
       Viewport.ApplyView(TmpView);
     end;

   The drawing is stored in the file as a path relative to the view file,
   and held in memory as an absolute one. <See Method=TCADViewSpec@LoadFromFile>
   and <See Method=TCADViewSpec@SaveToFile> convert between the two, so a
   caller never juggles both.
}
unit VCL.FNCCS4Views;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  { fpjson for TJSONObject itself: VCL.FNCCS4JSON hides the difference
    between the two JSON APIs, but not the name of the class. }
  SysUtils, Classes, fpjson,
{$ELSE}
  System.SysUtils, System.Classes, System.JSON,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4JSON;

type
  { : Raised when a view document is not one, or names a drawing that
    cannot be found. }
  ECADViewError = class(Exception);

  { : The layers a view shows, by index.

    Layers are a fixed array of 256 indexed by a Byte, so a set of Byte
    says everything there is to say. A view stores the <B=hidden> ones
    rather than the visible ones, because the ordinary case is that
    nothing is hidden and an empty set is the right default. }
  TCADLayerSet = set of Byte;

  { : A saved view of a drawing.

    Deliberately a record. It has no identity, nothing to free, and it is
    meant to be passed around, compared and stored inside other things -
    a sheet's viewport, a print setup - without anyone owning it. }
  TCADViewSpec = record
    { : What to call this view in a list. Not used to find anything. }
    Name: String;
    { : The drawing this view looks at.

      Absolute in memory, relative in the file. Empty means "whatever
      drawing is already loaded", which is what a view captured from a
      live viewport has until it is given one. }
    DrawingFile: String;
    { : The part of the drawing the view frames, in world coordinates.

      A request rather than a result: the viewport fits it to the shape
      of the control, so what comes back from
      <See Method=TFNCCADViewport@CaptureView> afterwards may be wider or
      taller. A rectangle survives that better than a centre and a scale,
      which is why it is stored this way. }
    Window: TRect2D;
    { : The aspect ratio to impose, or 0 to let the view stretch. }
    AspectRatio: TRealType;
    { : Whether <See Property=TCADViewSpec@HiddenLayers> means anything.

      False leaves the drawing's own layer visibility alone, which is not
      the same as "hide nothing": a view that was never told about layers
      must not silently switch them all back on. }
    UseLayerOverride: Boolean;
    { : The layers this view hides. Only when UseLayerOverride. }
    HiddenLayers: TCADLayerSet;
    { : Whether panning and zooming should be allowed to redefine this
      view. The library does not enforce it - it has no idea what the
      application means by an unsaved change - it only carries the flag. }
    Locked: Boolean;

    { : A view that frames nothing in particular and overrides nothing. }
    class function Default: TCADViewSpec; static;
    { : The view as a JSON document, kind "view". The caller owns it. }
    function SaveToJSON: TJSONObject;
    { : Reads a JSON document written by SaveToJSON. Raises
      <See Class=ECADViewError> if it is not one. }
    procedure LoadFromJSON(const AJSON: TJSONObject);
    { : Writes the view, making DrawingFile relative to AFileName. }
    procedure SaveToFile(const AFileName: String);
    { : Reads the view, making DrawingFile absolute from AFileName.

      It does not check that the drawing exists - see
      <See Method=TCADViewSpec@DrawingExists> - because a view of a
      drawing that has moved is still a view worth showing the user. }
    procedure LoadFromFile(const AFileName: String);
    { : Whether DrawingFile names a file that is there. }
    function DrawingExists: Boolean;
  end;

const
  { : The <I=kind> a view document carries, beside "drawing" and
    "library". }
  CADViewKind = 'view';
  { : The conventional extension. Nothing enforces it. }
  CADViewExtension = '.cadview';

{: The hidden layers as text, smallest index first: "3,7,128".

   Text rather than a JSON array of numbers on purpose. Building an array
   of numbers means naming a JSON number class, and the whole point of
   VCL.FNCCS4JSON is that the library names one in exactly one unit, where
   FPC's different spelling is one gap rather than three. A list of
   indices costs a split and reads better in the file than a bitmap.
}
function CADLayerSetToText(const ALayers: TCADLayerSet): String;
{: The inverse. Anything that is not a number in 0..255 is skipped
   rather than raising: a view file with a damaged layer list should
   still open. }
function CADTextToLayerSet(const AText: String): TCADLayerSet;

implementation

function CADLayerSetToText(const ALayers: TCADLayerSet): String;
var
  I: Integer;
  TmpParts: TStringList;
begin
  TmpParts := TStringList.Create;
  try
    TmpParts.Delimiter := ',';
    TmpParts.StrictDelimiter := True;
    for I := 0 to 255 do
      if Byte(I) in ALayers then
        TmpParts.Add(IntToStr(I));
    Result := TmpParts.DelimitedText;
  finally
    TmpParts.Free;
  end;
end;

function CADTextToLayerSet(const AText: String): TCADLayerSet;
var
  I, TmpValue: Integer;
  TmpParts: TStringList;
begin
  Result := [];
  if AText = '' then
    Exit;
  TmpParts := TStringList.Create;
  try
    TmpParts.Delimiter := ',';
    TmpParts.StrictDelimiter := True;
    TmpParts.DelimitedText := AText;
    for I := 0 to TmpParts.Count - 1 do
      if TryStrToInt(Trim(TmpParts[I]), TmpValue) then
        if (TmpValue >= 0) and (TmpValue <= 255) then
          Include(Result, Byte(TmpValue));
  finally
    TmpParts.Free;
  end;
end;

class function TCADViewSpec.Default: TCADViewSpec;
begin
  Result.Name := '';
  Result.DrawingFile := '';
  { Set field by field rather than through Rect2D: that lives in
    VCL.FNCCADSys4, which uses this unit, and a view has no business
    depending on the viewport it is applied to. W1 and W2 are the
    homogeneous components and are 1 for an ordinary rectangle. }
  Result.Window.Left := -100.0;
  Result.Window.Bottom := -100.0;
  Result.Window.W1 := 1.0;
  Result.Window.Right := 100.0;
  Result.Window.Top := 100.0;
  Result.Window.W2 := 1.0;
  Result.AspectRatio := 0.0;
  Result.UseLayerOverride := False;
  Result.HiddenLayers := [];
  Result.Locked := False;
end;

function TCADViewSpec.SaveToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    JSetStr(Result, 'format', CADSysJSONFormat);
    JSetStr(Result, 'version', CADSysJSONVersion);
    JSetStr(Result, 'kind', CADViewKind);
    JSetStr(Result, 'name', Name);
    JSetStr(Result, 'drawing', DrawingFile);
    JSetPoint2D(Result, 'min', Window.FirstEdge);
    JSetPoint2D(Result, 'max', Window.SecondEdge);
    JSetReal(Result, 'aspectRatio', AspectRatio);
    JSetBool(Result, 'locked', Locked);
    JSetBool(Result, 'layerOverride', UseLayerOverride);
    if UseLayerOverride then
      JSetStr(Result, 'hiddenLayers', CADLayerSetToText(HiddenLayers));
  except
    Result.Free;
    Raise;
  end;
end;

procedure TCADViewSpec.LoadFromJSON(const AJSON: TJSONObject);
begin
  if AJSON = nil then
    Raise ECADViewError.Create('TCADViewSpec: no document');
  if not SameText(JGetStr(AJSON, 'format'), CADSysJSONFormat) then
    Raise ECADViewError.Create
      ('TCADViewSpec: the document is not a CADSys document');
  if not SameText(JGetStr(AJSON, 'kind'), CADViewKind) then
    Raise ECADViewError.Create('TCADViewSpec: the document is not a view');

  Self := TCADViewSpec.Default;
  Name := JGetStr(AJSON, 'name');
  DrawingFile := JGetStr(AJSON, 'drawing');
  Window.FirstEdge := JGetPoint2D(AJSON, 'min');
  Window.SecondEdge := JGetPoint2D(AJSON, 'max');
  { Whatever the file said, a rectangle's homogeneous components are
    1: the transform code multiplies by them. }
  Window.W1 := 1.0;
  Window.W2 := 1.0;
  AspectRatio := JGetReal(AJSON, 'aspectRatio', 0.0);
  Locked := JGetBool(AJSON, 'locked', False);
  UseLayerOverride := JGetBool(AJSON, 'layerOverride', False);
  if UseLayerOverride then
    HiddenLayers := CADTextToLayerSet(JGetStr(AJSON, 'hiddenLayers'));
end;

procedure TCADViewSpec.SaveToFile(const AFileName: String);
var
  TmpDoc: TJSONObject;
  TmpKeep: String;
begin
  { Relative on the way out, so a view and its drawing can be moved,
    copied or checked in together. ExtractRelativePath gives the path
    back unchanged when the two are on different drives, which is the
    right answer - there is no relative path to be had. }
  TmpKeep := DrawingFile;
  try
    if DrawingFile <> '' then
      DrawingFile := ExtractRelativePath(ExtractFilePath(ExpandFileName(AFileName)),
        DrawingFile);
    TmpDoc := SaveToJSON;
    try
      JSONToFile(TmpDoc, AFileName, True);
    finally
      TmpDoc.Free;
    end;
  finally
    DrawingFile := TmpKeep;
  end;
end;

procedure TCADViewSpec.LoadFromFile(const AFileName: String);
var
  TmpDoc: TJSONObject;
begin
  TmpDoc := JSONFromFile(AFileName);
  try
    LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;
  { Absolute in memory. A caller that has the view has no reason to also
    have to remember where the view came from. }
  if DrawingFile <> '' then
    DrawingFile := ExpandFileName(ExtractFilePath(ExpandFileName(AFileName))
      + DrawingFile);
end;

function TCADViewSpec.DrawingExists: Boolean;
begin
  Result := (DrawingFile <> '') and FileExists(DrawingFile);
end;

end.
