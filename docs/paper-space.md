# Editable paper space

What an application needs to let somebody design a sheet: draw on it, select,
move, delete and group what is on it, and take hold of the viewports. Unit names
are the VCL ones; on FMX read `FMX.` for `VCL.` and on LCL `LCLFNCCADSys4` for
`VCL.FNCCADSys4`.

The short version: a sheet's objects are ordinary `TObject2D` shapes in
millimetres of paper, so every shape, every task and the whole display list work
on a sheet already. What needed adding was a way to say *which space* an
operation happens in, because a drawing now has two.

---

## 1. The two spaces

Model space is the drawing's own display list, in drawing units. Paper space is
one `TCADSheet`'s own objects, in millimetres of paper, origin at the
bottom-left corner of the sheet with Y upwards. A sheet also carries viewports:
rectangles of paper showing windows of the model at their own scale.

A viewport control shows one or the other:

```pascal
TFNCCADViewport2D.Sheet: TCADSheet;      { nil is model space }
```

Setting it saves and restores the model's framing, points the display list at
the sheet's objects, and frames the paper. It also stops whatever task is
running, because a task's selection belongs to the space it was started in -
see §4.

## 2. Which space, as a value you can pass

```pascal
TCADSpace2D = record
  CAD: TFNCCADCmp2D;      { never nil in a usable space }
  Sheet: TCADSheet;       { nil means model space }
end;

function CADSpace(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet = nil): TCADSpace2D;
function CADSpaceIsPaper(const ASpace: TCADSpace2D): Boolean;
function CADSpaceObjects(const ASpace: TCADSpace2D): TGraphicObjList;
function CADSpaceAddObject(const ASpace: TCADSpace2D; const AID: LongInt;
  const AObj: TObject2D): TObject2D;
function CADSpaceGetObject(const ASpace: TCADSpace2D;
  const AID: LongInt): TGraphicObject;
procedure CADSpaceDeleteObject(const ASpace: TCADSpace2D; const AID: LongInt);
procedure CADSpaceRemoveObject(const ASpace: TCADSpace2D; const AID: LongInt);
procedure CADSpaceMoveObject(const ASpace: TCADSpace2D;
  const AIDOrigin, AIDDestination: LongInt);
```

A plain record with free functions: it needs no owner and can be built in the
call that uses it. `CADSpaceAddObject` is the one implementation of "where does
a new object go"; a negative `AID` asks the space for the next free identifier.

An object moves between spaces by remove-then-add, and there is deliberately no
single call for it: the space it arrives in has to give it an identifier.

## 3. Doing it through the viewport

For an application driving one viewport, these are the doors:

```pascal
TFNCCADViewport2D.ActiveSpace: TCADSpace2D;
TFNCCADViewport2D.ActiveObjects: TGraphicObjList;
TFNCCADViewport2D.AddObjectToActiveSpace(const AObj: TObject2D): TObject2D;
TFNCCADViewport2D.GetActiveObject(const AID: LongInt): TGraphicObject;
TFNCCADViewport2D.DeleteObjectFromActiveSpace(const AID: LongInt);
TFNCCADViewport2D.RemoveObjectFromActiveSpace(const AID: LongInt);
TFNCCADViewport.PixelAperture: TPoint2D;
TFNCCADViewport.LinkedPrg: TFNCCADPrg;
```

Every drawing task in `VCL.FNCCS4Tasks` goes through `AddObjectToActiveSpace`,
so "everything you draw" lands on the paper while a sheet is showing and in the
model otherwise, with no change on the application side.

`ActiveObjects` is the list being edited, by the same rule `DoUpdateViewport`,
`PickObject` and `GroupObjects` follow - so what is drawn, what is picked, what
an area selection collects and what a lookup finds are one list.

`PixelAperture` is one device pixel as a rectangle of the world. It is what
`PickObject` multiplies by its aperture in pixels; an application doing its own
hit testing wants the same figure rather than its own, or its idea of "near
enough" will disagree with the library's at every zoom level.

## 4. Identifiers: the trap

Each space numbers its objects from its own counter, so **the same identifier
means a different object in each**. `TFNCCADCmp.GetObject(ID)` searches the
model; asked while the user is looking at a sheet it answers about the wrong
object, silently.

```pascal
TCADSheet.GetObject(const AID: LongInt): TObject2D;       { nil if absent }
TCADSheet.AddObject(const AObj: TObject2D;
  const AID: LongInt = -1): TObject2D;
```

An application that keeps identifiers - a selection, a reference from its own
data - uses `TFNCCADViewport2D.GetActiveObject` or `CADSpaceGetObject`.

`AddObject` follows the drawing's rule: a negative `AID` takes the next free one
from the sheet's counter, a given one is kept and moves the counter past it.
That is what lets a sheet reload with the identifiers it was saved with; before
that, sheet objects were renumbered from zero on every load.

Changing space while a task is running would carry its selection across, where
those identifiers mean something else. `SetSheet` therefore calls
`StopOperation` on `LinkedPrg` first. It is a no-op when nothing is running.

## 5. Hearing about changes

```pascal
TCADSheetChange = (scoAdded, scoRemoved, scoChanged);
TCADSheetObjectEvent = procedure(Sender: TObject; const ASheet: TCADSheet;
  const AObj: TGraphicObject; const AChange: TCADSheetChange) of object;

property TFNCCADCmp.OnSheetObjectChange: TCADSheetObjectEvent;
procedure TFNCCADCmp.SheetObjectChanged(const ASheet: TCADSheet;
  const AObj: TGraphicObject; const AChange: TCADSheetChange);
procedure TCADSheet.ObjectChanged(const AObj: TObject2D);
```

Paper space is saved with the drawing, so an application that marks a file
modified has to hear about a title block as well as about the model. `ASheet`
says which space it happened in, which `OnAddObject` cannot. It is deliberately
a second channel: a handler written before sheets existed assumes its object is
in the display list.

- `scoAdded` and `scoRemoved` are fired by `TCADSheet` itself. A removal is
  reported *before* the object is freed, so a handler can still look at it.
- `scoChanged` is fired by whoever moved or transformed something, through
  `TCADSheet.ObjectChanged` - a sheet cannot notice that by itself.
- `AObj` is nil for a change that is not about one object: `DeleteAllObjects`
  and `MoveObject` report that way.
- Stand-ins (§7) are not reported at all.

## 6. Sheet viewports: the numbers

```pascal
TCADSheetViewport.RectMM: TRect2D;            { where it sits on the paper }
TCADSheetViewport.View: TCADViewSpec;         { what it looks at }
TCADSheetViewport.UnitsPerMM: TRealType;      { 0 fits the view to the rectangle }
TCADSheetViewport.ShowBorder: Boolean;

function  EffectiveUnitsPerMM(const ACAD: TFNCCADCmp2D): TRealType;
function  ModelWindow(const ACAD: TFNCCADCmp2D): TRect2D;
function  ModelCentre(const ACAD: TFNCCADCmp2D): TPoint2D;
procedure SetModelCentre(const ACAD: TFNCCADCmp2D; const AModelCentre: TPoint2D);
procedure PanModelBy(const ACAD: TFNCCADCmp2D; const ADXModel, ADYModel: TRealType);
procedure ZoomBy(const ACAD: TFNCCADCmp2D; const AFactor: TRealType);
function  PointMMToModel(const ACAD: TFNCCADCmp2D; const APointMM: TPoint2D): TPoint2D;
function  ModelToPointMM(const ACAD: TFNCCADCmp2D; const APointModel: TPoint2D): TPoint2D;
```

Scale is drawing units to one millimetre of paper, as a draughtsman states it: a
plan drawn in millimetres at 1:100 is 100, the same plan drawn in metres at
1:100 is 0.1.

`ZoomBy` with a factor above one zooms in, about the viewport's own centre, and
pins a fitted viewport at the scale it was fitted to first so the first click
moves by the factor asked for. `PanModelBy` moves the window and leaves the
scale alone. The conversions are a straight proportion between the window and
the rectangle of paper, not the device transform - a viewport with no area
returns the point it was given.

Finding one:

```pascal
TCADSheet.ViewportIndexAt(const APointMM: TPoint2D): Integer;    { -1 for none }
TCADSheet.ViewportAt(const APointMM: TPoint2D): TCADSheetViewport;
```

Searched from the end, because the last viewport drawn is the one on top. The
device-pixel equivalents - `CADSheetViewportIndexAt`, `CADSheetViewportRectPx`,
`CADSheetViewportTransform`, `CADSheetPointToModel`, `CADSheetModelToPoint` -
are unchanged and still there for a printer or a preview.

## 7. Handles: editing a viewport with the ordinary tools

A `TCADSheetViewport` is not a shape, so nothing in the picking, selection,
rubber-band, move or edit-point machinery can touch it. One object stands in for
the rectangle instead:

```pascal
{ VCL.FNCCS4Shapes }
TCADSheetViewportProxy2D = class(TFrame2D)
  constructor CreateForViewport(const AID: LongInt;
    const AViewport: TCADSheetViewport);
  function StandsFor: TObject; override;          { the viewport }
  procedure Refresh;                              { pull RectMM back in }
  property Viewport: TCADSheetViewport;
end;

function CADSheetShowViewportProxies(const ASheet: TCADSheet): Integer;
function CADSheetHideViewportProxies(const ASheet: TCADSheet): Integer;
function CADSheetViewportProxy(const ASheet: TCADSheet;
  const AViewport: TCADSheetViewport): TCADSheetViewportProxy2D;
procedure CADSheetRefreshViewportProxies(const ASheet: TCADSheet);
```

With the handles on, `TCAD2DMoveObjects` moves a viewport and
`TCAD2DEditPrimitive` resizes it by a corner, with nothing written for either.
The viewport stays the truth: every change to the handle's shape is pushed onto
`RectMM` as it happens, and `Refresh` pulls the other way for a viewport moved
in code.

```pascal
{ VCL.FNCCADSys4 }
TGraphicObject.StandsFor: TObject; virtual;       { nil for everything in the document }
TCADSheet.RemoveStandInsFor(const AThing: TObject): Integer;
```

`StandsFor` is how the library tells a session's furniture from the drawing. A
stand-in is not written to a file, not drawn by `CADDrawSheet` - so it reaches
no printer, no PDF and no preview - and not reported through
`OnSheetObjectChange`, because showing the handles is not a change to the
document. Deleting a viewport takes its stand-in with it.

Two things are deliberately left to the application: **when** the handles are
there, and **how they look**. They arrive on layer zero like anything else added
to a sheet; the CAD2D demo puts them on a layer of their own with a red dashed
pen, because a handle is exactly the viewport's rectangle and otherwise lands
invisibly on top of the border the viewport already draws.

The handle is a `TFrame2D`, so it has two control points - the bottom-left and
the top-right corner - and those are the two a resize drags. Resizing is
`TCAD2DEditPrimitive`'s ordinary flow: select the handle, press and hold a
control point, drag, release, then accept the task. The task edits a copy, so
nothing reaches `RectMM` until it is accepted. The other two
corners are drawn but are not control points, here as on every frame and
rectangle in the library.

One library-side allowance for them: the handle's `OnMe` answers for its four
corners as well as its edges. The library measures a point against a line by
projecting it onto the segment, so a point past the end of a segment counts as
being on neither of the two lines that meet there - diagonally outside a corner
is a blind spot about an aperture wide. On an ordinary shape that is a
curiosity; on a handle it is the one place somebody aims for.

## 8. An application's own classes on a sheet

Sheet JSON goes through the same class registry as the model, so a registered
`TFrame2D` descendant - a legend box, a title block - round-trips on a sheet
with its own fields and its own identifier. Register it as usual:

```pascal
CADSysRegisterClass(150, TMyLegendBox);
```

A drawing whose custom class is **not** registered in the program opening it
still loads: the object is skipped, `CADSysWarn` is called, and everything else
on the sheet comes back.

## 9. Exploding into a space

```pascal
{ VCL.FNCCS4Tasks }
procedure Explode(AObject2D: TObject2D; const ADest: TCADSpace2D);
procedure ExplodeOutline2D / ExplodeContainer / ExplodeBlock /
          ExplodeFrame2D / ExplodePolygon2D;      { same shape }
```

Public for the first time - these were unit-local, and the task that would have
called them is an empty shell - and taking a space rather than a drawing, so
exploding a title block on a sheet leaves the pieces on the paper.
`Viewport.ActiveSpace` is the destination an interactive caller wants. The
pieces keep the source's layer and get fresh identifiers from the space they
land in; the original is neither changed nor removed.

## 10. Named views: one detail, several viewports

A named view is a part of the model with a name, kept in the drawing. Sheet
viewports **link** to it rather than copy it, so a detail placed on three sheets
- or twice on one, at two scales - is defined once, and redefining it moves all
of them.

```pascal
TFNCCADCmp.Views: TCADViews;                  { the drawing's named views }

TCADViews.Add(const AName: String; const ASpec: TCADViewSpec): TCADNamedView;
TCADViews.Delete(const AIndex: Integer);      { unlinks first - see below }
TCADViews.Clear;
TCADViews.FindByName / FindById / IndexOfName / IndexOfId;
TCADViews.Count, Items[]                      { default }

TCADNamedView.Id: String;                     { a GUID, made once, never changes }
TCADNamedView.Name: String;                   { the spec's own Name }
TCADNamedView.Spec: TCADViewSpec;             { assign it to redefine }

{ making the spec from what somebody pointed at }
function CADViewFromArea(const AArea: TRect2D;
  const AMarginFraction: TRealType = 0.05): TCADViewSpec;
function CADViewFromObjects(const AObjects: TGraphicObjList;
  const AMarginFraction: TRealType = 0.05): TCADViewSpec;
```

`CADViewFromObjects` frames the union of the objects' boxes. Both add a margin
of the larger side times the fraction on every side, so a single horizontal line
still frames something with height; both raise `ECADPageError` for a point or an
empty list rather than return a view that frames nothing (which a viewport would
read as "fit the whole drawing").

On the viewport:

```pascal
TCADSheetViewport.LinkTo(const AView: TCADNamedView);
TCADSheetViewport.Unlink(const ACAD: TFNCCADCmp);    { keeps what it showed }
TCADSheetViewport.IsLinked: Boolean;
TCADSheetViewport.ViewLink: String;                  { the Id it links to }
TCADSheetViewport.LinkedView(const ACAD: TFNCCADCmp): TCADNamedView;  { or nil }
TCADSheetViewport.EffectiveView(const ACAD: TFNCCADCmp): TCADViewSpec;
```

What is shared and what is not:

- **Shared** - the framing (`Window`) and everything else in the spec, layer
  overrides included. That is what the link is for.
- **Per viewport** - `RectMM`, `UnitsPerMM`, `ShowBorder`. The same detail at
  1:5 and at 1:20 is two viewports linked to one view.

`EffectiveView` is what everything that draws, frames or hit-tests a viewport
asks: the linked view when the link finds one, the viewport's own `View`
otherwise. Panning a linked viewport (`SetModelCentre`, `PanModelBy`) moves the
named view, and so every viewport linked to it; zooming changes `UnitsPerMM`,
which is the viewport's own.

A linked viewport always keeps a copy of its own. `LinkTo` takes one, `TCADSheet`
refreshes it before saving, and it is what the viewport falls back on when the
link finds nothing. Hence:

- **Deleting a view** unlinks its viewports first. Each keeps showing what it
  showed; nothing on any sheet goes blank.
- **Assigning `View`** on a linked viewport ends the link. Setting a view of its
  own is a statement that it no longer follows the named one.
- **A file read by something that does not know about links** shows exactly
  what this library shows, from the copy.
- **A link to a view the drawing does not have** - a sheet merged in from
  another drawing - is not an error: the viewport shows its copy, and
  `IsLinked` stays true while `LinkedView` answers nil.

Merging a drawing into itself skips views whose `Id` is already there, so links
still find one view each.

The demo has it under **View - Named views**: *Define from an area* and *Define
from a selection* in the model (an existing name redefines that view),
*Place on sheet...* on a sheet (name, then drawing units per mm, 0 to fit), and
*List (log)*.

## 11. A viewport's furniture: content inset, draw hook, application data

A Gantt sheet needs, per viewport, a timescale across the top for exactly the
dates that viewport shows and a column of lane headers down its left for
exactly its lanes. Drawn as model objects they would sit at the edge of the
model, not of each viewport. Three things make it possible.

**The content inset** keeps the model out of margins inside the viewport:

```pascal
TCADSheetViewport.ContentInsetMM: TRect2D;   { Left, Top, Right, Bottom - each a width, mm }
function TCADSheetViewport.ContentRectMM: TRect2D;   { RectMM less the inset }
function CADSheetViewportContentRectPx(const ASheet: TCADSheet;
  const AViewport: TCADSheetViewport; const ADevice: TCADPageDevice): TRect;
```

Zero by default, which is the viewport as it always was. Everything that
places, fits or inverts the model uses the content rectangle -
`EffectiveUnitsPerMM`, `ModelWindow`, `PointMMToModel`, `ModelToPointMM`,
`CADSheetViewportTransform` and the clip the model is drawn in. Finding a
viewport, its border and its handles keep using `RectMM`, so the whole
viewport, margins included, is still what is clicked and dragged. An inset
larger than the rectangle leaves an empty content rectangle, never an
inside-out one.

**The draw hook** is called for every viewport as it is drawn, before the
model and after it, on every device a sheet goes to - the editing viewport,
the preview, the printer, the PDF, PNG, SVG and EMF exports:

```pascal
procedure TForm1.CADDrawSheetViewport(Sender: TObject;
  const AInfo: TCADSheetViewportDrawInfo; const APhase: TCADViewportDrawPhase);
var
  R: TRect;
begin
  if APhase <> vdpAfterModel then
    Exit;
  { The top margin, in device pixels: OuterPx is the viewport, ContentPx is
    where the model went. }
  R := Rect(AInfo.ContentPx.Left, AInfo.OuterPx.Top,
    AInfo.ContentPx.Right, AInfo.ContentPx.Top);
  AInfo.Canvas.Graphics.Brush.Style := cbsSolid;
  AInfo.Canvas.Graphics.Brush.Color := cadclSilver;
  AInfo.Canvas.Graphics.FillRect(R);
  { AInfo.ModelWindow is the part of the model shown; AInfo.ModelToDevice
    takes a model point to the device, so a tick at a date lands over it. }
end;
```

`TCADSheetViewportDrawInfo` carries the sheet and the viewport, the canvas and
the page device, the outer and content rectangles in device pixels, the
model-to-device transform, the model window, the device's pixels per
millimetre and the draw mode. The clip is the whole viewport, margins
included. Pen, brush, font and any clip the handler pushes and forgets are put
back afterwards, so a careless handler cannot spoil the rest of the sheet. The
border is drawn last, over both phases.

Sizes on the device come from `AInfo.PixelsPerMM`: a 3 mm header row is
`Round(3 * AInfo.PixelsPerMM)` pixels on the screen and on paper alike, and a
font height in pixels is worked out the same way.

**Application data** is text the library saves, loads and copies and never
reads - typically JSON:

```pascal
TCADSheetViewport.AppData: String;   { which lanes, which date window }
TCADSheet.AppData: String;           { the sheet's place in a series }
```

Both are written to the file only when not empty (see json-format.md).

The demo has a sample under **Sheet - Viewport inset...**, which sets an inset
on the selected viewport, and a hook that prints the model window in the top
margin.

## 12. What the library does not decide

- when the viewport handles are shown, and what they look like;
- when the application switches space;
- what a named view is called, or whether two may share a name - the `Id` is
  what tells them apart;
- undo. The library reports what happened on a sheet through
  `OnSheetObjectChange`; what an undo stack is made of is the application's.
