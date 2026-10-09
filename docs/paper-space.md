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

## 10. What the library does not decide

- when the viewport handles are shown, and what they look like;
- when the application switches space;
- undo. The library reports what happened on a sheet through
  `OnSheetObjectChange`; what an undo stack is made of is the application's.
