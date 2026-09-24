# CADSys 4.2 — Optimization & Correctness Review

**Date:** 2026-08-28
**Scope:** `Sources/CADSys4.pas` (21 321 lines), `CS4Shapes.pas` (9 223), `CS4Tasks.pas` (3 653), `CS4DXFModule.pas` (2 180), `CS4BaseTypes.pas` (577), `CADSysRegister.pas` (84), plus the three demo apps under `Demos/delphi/`.
**Line numbers** refer to the working tree as of this date. `CS4Tasks.pas` numbers are **post** the `TCAD2DEditPrimitive` param-leak fix (file is 3 653 lines); everything else is unmodified.

## Method and confidence

Every finding below was read in the source before being written down. Findings marked **✔ verified** were re-opened and confirmed a second time against the exact lines quoted; findings marked **○ spot-check** were reported once and are consistent with the surrounding code but were not independently re-read — treat their reasoning as sound and their line numbers as approximate.

Nothing here was compiled or run. There is no Delphi toolchain available to the reviewer, so every "before/after" sketch is a design proposal, not a tested patch.

## How to read this

Findings are grouped by kind and ranked within each group by expected payoff. The groups themselves are roughly in priority order: a memory defect that corrupts the heap outranks a redraw that is twice as slow as it needs to be.

| Group | Count | Character |
|---|---|---|
| [1. Memory & lifetime](#1-memory--lifetime) | 14 | Leaks, double frees, use-after-free. Fix first — several are active corruption. |
| [2. Hot-path performance](#2-hot-path-performance) | 12 | Per-frame and per-point work. Biggest wins are in the repaint path. |
| [3. Modernization & portability](#3-modernization--portability) | 7 | Unicode, 64-bit, locale. These are blockers for a modern build, not polish. |
| [4. Structure](#4-structure) | 5 | Duplication that is already causing divergent bugs. |
| [5. API friction](#5-api-friction-from-the-demos) | 4 | What the demos reveal about the public surface. |

---

## Do these first

If nothing else gets done, these eight repay the effort fastest. Four are active memory corruption, three are single-line performance wins with no design risk, and one blocks 64-bit entirely.

| # | Finding | Why it leads |
|---|---|---|
| 1 | [M1 — Pan states double-free the rubber-band line](#m1--pan-states-double-free-the-rubber-band-line) | Heap corruption on a routine cancel. Five identical sites, one-line fix each. |
| 2 | [M2 — `TPointsSet2D.fCapacity` is a `Word` and truncates](#m2--fcapacity-is-a-word-and-silently-truncates-in-expand) | Silently destroys live points above ~32 k. Type widening. |
| 3 | [M3 — `DeleteBlock` frees before unlinking](#m3--deleteblock-frees-the-object-before-unlinking-it) | Retry loop calls `Free` twice on the same object. |
| 4 | [X5 — `Ord(Ch)` into a 256-slot list](#x5--ordch-indexes-a-256-slot-list-so-any-character-above-u00ff-raises-out-of-draw) | One curly quote or € in a vector-text shape raises out of every repaint. |
| 5 | [P1 — `RepaintRect` redraws the whole document](#p1--repaintrect-redraws-the-entire-document) | The FSM's partial-refresh path buys nothing today. |
| 6 | [P2 — `TPointsSet2D.Add` fires `OnChange` per point](#p2--tpointsset2dadd-fires-onchange-per-point-making-construction-on²) | O(n²) bounding-box recomputation on every polyline build. |
| 7 | [P3 — scratch buffer `GetMem`/`FreeMem` per primitive per frame](#p3--per-call-heap-scratch-buffer-in-the-polylinepolygon-draw-helpers) | One or two heap round-trips per shape per repaint. |
| 8 | [X2 — DXF parser mutates global `FormatSettings`](#x2--dxf-parser-mutates-the-global-decimal-separator-per-line) | Not thread-safe against the library's own painting thread. |

> **Correction (during implementation).** X1 was originally in this shortlist as "`TCADPrg` cannot work in a Win64 build." That overstated it: the `SetWindowLong` block sits inside `{$IFDEF windows}`, which is an **FPC/Lazarus** conditional — Delphi defines `MSWINDOWS`, not `windows`. In a Delphi build the `{$ELSE}` `WindowProc` branch compiles and the truncating code is dead. X1 is still worth fixing for FPC targets, but it is not a Delphi blocker. X5 takes its place above.

---

## 1. Memory & lifetime

### M1 — Pan states double-free the rubber-band line

**`CS4Tasks.pas:1718-1719, 1741-1742, 1767-1768, 1789-1790, 1814-1815` · high · ✔ verified**

```pascal
procedure TCADPrgPan.OnStop;
begin
  TCADPrgParam(Param).UserObject.Free;
  Param.Free;
  Param := nil;
end;
```

`TCADPrgParam.Destroy` (`CADSys4.pas:20142-20147`) unconditionally frees `fUserObject`, and `UserObject` is a plain property with no nil-ing setter (`CADSys4.pas:6720`). Freeing it by hand and then freeing the param frees the same `TLine2D` twice. The `ceMouseDown` site at 1789 hides the same bug inside `with TLine2D(UserObject) do ... Free;` — the bare `Free` binds to the line, not the state.

Under FastMM's full-debug mode this raises immediately; in a release build it is silent heap corruption that surfaces later as an unrelated AV.

```pascal
// after — at all five sites
Param.Free;          // TCADPrgParam.Destroy already frees UserObject
Param := nil;
```

**Risk:** none — local change.

---

### M2 — `fCapacity` is a `Word` and silently truncates in `Expand`

**`CADSys4.pas:813, 13031-13046, 13134` (3D twins at 13265-13281, 13367) · high · ✔ verified**

```pascal
fCapacity, fCount: Word;
...
procedure TPointsSet2D.Expand(const NewCapacity: Integer);
begin
  if NewCapacity <= fCapacity then Exit;
  ReAllocMem(fPoints, NewCapacity * SizeOf(TPoint2D));
  for Cont := fCapacity to NewCapacity - 1 do ...
  fCapacity := NewCapacity;     // Integer -> Word, truncates
end;
```

The growth site is `Expand(MaxIntValue([PutIndex + 1, fCapacity * 2 + 1]))`. Once `fCapacity` passes 32 767 the doubling asks for more than 65 535: `ReAllocMem` really allocates the larger block, but `fCapacity` stores the value modulo 65 536. The next `Put` then calls `Expand` with a number that passes the `NewCapacity <= fCapacity` guard, **shrinks** the buffer, and the zero-fill loop overwrites thousands of live points with zeros. No error is reported.

```pascal
// after
fCapacity, fCount: Integer;
procedure Expand(const NewCapacity: Integer);
function  Get(Index: Integer): TPoint2D; virtual;
procedure Put(PutIndex, ItemIndex: Integer; const Item: TPoint2D); virtual;
```

**Risk:** `Get`/`Put` are public and virtual and are overridden in `CS4Shapes.pas` and in the `PointsVectDemo` sample. Widening the index type is source-breaking for every descendant and must be done across all units in one change. `fCount: Word` also caps any point set at 65 535 points, which is the real limit worth lifting.

---

### M3 — `DeleteBlock` frees the object before unlinking it

**`CADSys4.pas:13848-13871`, with `16773-16779` and `14736-14755` · high · ✔ verified**

```pascal
procedure TGraphicObjList.DeleteBlock(ObjToDel: Pointer);
begin
  fListGuard.Enter;
  try
    // Free the first object. So if it cannot be deleted it will be later.
    if Assigned(TObjBlock(ObjToDel^).Obj) and fFreeOnClear then
      TObjBlock(ObjToDel^).Obj.Free;
    // First extract the block from all list.
    ...
```

The comment shows the intent: `TSourceBlock2D.Destroy` raises `ECADSourceBlockIsReferenced` while `fNReference > 0`, and `DeleteAllSourceBlocks` catches that and retries on a later pass. But `Obj.Free` runs *before* the block is unlinked, so when the destructor raises, the list still holds a pointer to an object whose destructor body has already run. The retry loop then calls `Free` on it a second time.

```pascal
// after — make the list consistent first, free outside the guard
procedure TGraphicObjList.DeleteBlock(ObjToDel: Pointer);
var TmpObj: TGraphicObject;
begin
  fListGuard.Enter;
  try
    TmpObj := TObjBlock(ObjToDel^).Obj;
    { unlink block; FreeMem(ObjToDel, SizeOf(TObjBlock)); Dec(fCount) }
  finally
    fListGuard.Leave;
  end;
  if fFreeOnClear and Assigned(TmpObj) then
    TmpObj.Free;      // list is already consistent if this raises
end;
```

**Risk:** `DeleteAllSourceBlocks` currently *relies* on the block staying in the list when the free fails. It has to be reworked into an explicit two-pass "delete every block with `fNReference = 0`, repeat until no progress" loop. Better still, replace the raising destructor with a non-throwing `CanDestroy: Boolean` so deletion order is decided without exceptions at all.

---

### M4 — Every `Raise` in a state constructor leaks the incoming param

**`CS4Tasks.pas:1937, 2017, 2138, 2243, 2403, 2509, 2628, 2820, 3251, 3358, 3376` · high · ○ spot-check**

```pascal
inherited;
if not(StateParam is TCAD2DTransformObjectsParam) then
  Raise ECADSysException.Create('TCAD2DTransformObjects: Invalid param');
```

`TCADState.Destroy` deliberately does not free `fParam` — the body is commented out at `CADSys4.pas:20173-20174`. When a constructor raises, Delphi runs the destructor, and `SendEvent`'s `except Reset; Break;` (`CADSys4.pas:20307`) never sees the param. It is orphaned, along with whatever it owns: selection lists, in-progress primitives.

Eleven sites. Worth a shared helper rather than eleven edits:

```pascal
class procedure TCADState.RequireParam(var P: TCADPrgParam; C: TClass;
  const Msg: String);
begin
  if not (P is C) then
  begin
    FreeAndNil(P);
    Raise ECADSysException.Create(Msg);
  end;
end;
```

**Risk:** `TCAD2DEditSelectedPrimitive` puts a *live drawing object* in `UserObject` (line 3390). Freeing that param would free the drawing's primitive, so `UserObject` must be nil'd first — exactly what line 3267 already does after the recent fix.

---

### M5 — `TCADPrgSelectAreaParam.Destroy` never frees `fCallerParam`

**`CS4Tasks.pas:1494-1498`, contract documented at `346-351` · high · ✔ verified**

```pascal
destructor TCADPrgSelectAreaParam.Destroy;
begin
  fFrame.Free;
  inherited Destroy;
end;
```

The declaration's own doc comment promises the opposite: *"This parameter will be freed when the parameter will be deleted. If you need it after the deletion of the parameter set it to nil after you have retrieved it."* `TCAD2DSelectObjectsInArea.Create` (2823) and `TCADPrgZoomArea.Create` (1628) both stash the incoming param as `CallerParam` on that promise. The success path nils it first (2788-2789); the cancel paths in `TCADPrgSelectArea` / `TCADPrgDragSelectArea` (1533, 1580) just call `Param.Free`, so the caller param leaks on every cancelled area-select and every cancelled zoom-window.

```pascal
destructor TCADPrgSelectAreaParam.Destroy;
begin
  fFrame.Free;
  fCallerParam.Free;   // the documented ownership
  inherited Destroy;
end;
```

**Risk — larger than first assessed. This fix must NOT be applied on its own.** `SuspendOperation` (`CADSys4.pas:20705-20706`) aliases the *suspended* state's param into the new state when the caller passes none, and `TCADPrgZoomArea.Create` (1628) stores whatever it receives as `CallerParam`. The demo does exactly this at `Demos/delphi/CAD2D/Unit1.pas:466` — `SuspendOperation(TCADPrgZoomArea, nil)` while a drawing task is in progress. Freeing `fCallerParam` in the destructor would then free the *drawing* task's parameter mid-operation, leaving `fSuspendedState.fParam` dangling and double-freeing it on resume.

So M5 belongs with M7/M8/A3 in the ownership phase, not in Phase 1. Its own direct consumer (2788-2789) does nil the field correctly; the hazard comes entirely from the aliasing.

---

### M6 — `TCADPrgPan.Create` dereferences a nil param and leaks a non-nil one

**`CS4Tasks.pas:1695-1703` · high · ✔ verified**

```pascal
{ No parameter. }
constructor TCADPrgPan.Create(const CADPrg: TCADPrg;
  const StateParam: TCADPrgParam; var NextState: TCADStateClass);
begin
  inherited Create(CADPrg, StateParam, NextState);
  Param := TCADPrgParam.Create(StateParam.AfterState);
```

The comment says the state takes no parameter. The documented usage — `StartOperation(TCADPrgPan, nil)` — therefore faults on `StateParam.AfterState`. And when a param *is* supplied, `Param` is overwritten without freeing it: the same defect class already fixed in `TCAD2DEditPrimitive.Create`.

```pascal
var AfterS: TCADStateClass;
begin
  inherited Create(CADPrg, StateParam, NextState);
  if Assigned(StateParam) then AfterS := StateParam.AfterState else AfterS := nil;
  StateParam.Free;                     // nil-safe
  Param := TCADPrgParam.Create(AfterS);
```

**Risk — the `StateParam.Free` half must wait.** Same aliasing hazard as M5: if `TCADPrgPan` is ever entered through `SuspendOperation(TCADPrgPan, nil)` while another task is running, `StateParam` *is* the suspended task's param and freeing it here would destroy it. Only the nil-guard is safe in isolation; the free belongs with M7/M8. (Mitigating fact: `TCADPrgPan` is referenced nowhere in the library or the demos outside its own declaration — the demos use `TCADPrgRealTimePan`, whose constructor does not touch `StateParam` and is clean.)

---

### M7 — `StartOperation` / `SuspendOperation` leak the caller's param on early exit

**`CADSys4.pas:20620-20628, 20690-20699` · high · ✔ verified**

```pascal
Result := False;
if not Assigned(fLinkedViewport) then
  Exit;
if fLinkedViewport.InRepainting then
  fLinkedViewport.WaitForRepaintEnd;
if fIsSuspended then
  Exit;
```

Ownership of `Param` transfers to `TCADPrg` only if the function proceeds. Three of the four early returns drop the reference on the floor, and the caller cannot free it either, because on the success path the FSM owns it. A `StartOperation` issued while another operation is suspended leaks the param and everything inside it.

```pascal
if (not Assigned(fLinkedViewport)) or fIsSuspended then
begin
  Param.Free;
  Exit;
end;
```

**Risk:** `Result := False` must then be documented as "param consumed". Any caller that currently frees its own param after a `False` result would double-free — grep `CS4Tasks.pas` and application code first.

---

### M8 — `SuspendOperation` aliases the suspended state's param

**`CADSys4.pas:20705-20706`, with `20184-20188` and `20357-20361` · high · ○ spot-check**

```pascal
fSuspendedState := CurrentState;
fIsSuspended := True;
if not Assigned(Param) then
  Param := fSuspendedState.fParam;
```

With no explicit param, the transient state now shares the suspended state's param object. If that transient state ends via `StopOperation`/`Reset`, `TCADState.OnStop` frees it while `fSuspendedState.fParam` still points at it; `GoToDefaultState` later restores the suspended state and `fCurrentState.fParam.Free` (20359) frees the same block again.

The clean fix is an explicit borrow flag on `TCADState` that suppresses the free on both paths, cleared on resume. Anything less will either double-free or leak, depending on which path runs.

**Risk:** changes when params are destroyed for every suspend/resume task. Needs a test that suspends, cancels the transient op, resumes, then ends normally.

---

### M9 — `TPaintingThread` is `FreeOnTerminate` and `WaitFor`-ed, and terminates twice

**`CADSys4.pas:14264, 14269-14273, 15511-15529` · high · ✔ verified**

```pascal
  FreeOnTerminate := True;
...
destructor TPaintingThread.Destroy;
begin
  DoTerminate;
  inherited;
end;
```

```pascal
TPaintingThread(fPaintingThread).Terminate;
if Assigned(fPaintingThread) then
  TPaintingThread(fPaintingThread).WaitFor;
```

`TThread.ThreadProc` already calls `DoTerminate` after `Execute` and then frees the instance because `FreeOnTerminate` is set. Calling `DoTerminate` again from the destructor re-`Synchronize`s `OnThreadEnded` — which runs the user's `OnPaint` a second time. Meanwhile `StopPaintingThread` may call `WaitFor` on a pointer the thread has already freed.

```pascal
// after
constructor TPaintingThread.Create(...);
begin
  inherited Create(True);
  FreeOnTerminate := False;    // owner controls lifetime
  ...
end;

destructor TPaintingThread.Destroy;
begin
  inherited;                   // drop the extra DoTerminate
end;

// StopPaintingThread:
TPaintingThread(fPaintingThread).Terminate;
TPaintingThread(fPaintingThread).WaitFor;
FreeAndNil(fPaintingThread);
```

**Risk:** with `FreeOnTerminate := False` the viewport must free the thread on *every* exit path, `Destroy` and `OnThreadEnded` included, or the thread object leaks instead.

---

### M10 — The painting thread iterates the shared display list with no lock

**`CADSys4.pas:14285-14335` · high · ○ spot-check**

`TmpCanvas.Lock` guards the GDI canvas, not the object list. `fViewGuard` is never entered in `Execute`, and `fCADCmp.IsBlocked` is a one-shot check at start rather than a held lock. Any concurrent `AddObject`/`DeleteObject` on the main thread corrupts the iterator mid-traversal, and `DrawObject` reads `fViewportToScreen` while the main thread may be rewriting it.

The naive fix — hold `fViewGuard` across the whole redraw — blocks the UI thread on every edit, which defeats the point of threaded painting. A snapshot-then-draw approach (copy the block pointers under the guard, release, then draw) is the right shape.

**Risk:** design-level change. Until it is done, `UseThread` should be documented as unsafe with concurrent edits.

---

### M11 — `TObject2DHandler.FreeInstance` checks the refcount too late

**`CADSys4.pas:16242-16255`, identical at `17892-17905` · medium · ✔ verified**

```pascal
destructor TObject2DHandler.Destroy;
begin
  if Assigned(fHandledObject) then
    fHandledObject.fHandler := nil;
  inherited;
end;

procedure TObject2DHandler.FreeInstance;
begin
  Dec(fRefCount);
  if fRefCount > 0 then
    Exit;
  inherited;
end;
```

Delphi calls `FreeInstance` *after* the `Destroy` body. So freeing a handler with refcount 2 runs the full teardown — clearing `fHandledObject.fHandler` — and then declines to release the memory. The block leaks and the surviving objects hold a pointer to a destructed instance. `FreeInstance` is the wrong hook for reference counting.

```pascal
procedure TObject2DHandler.Release;
begin
  Dec(fRefCount);
  if fRefCount <= 0 then
    Destroy;          // real teardown + FreeInstance
end;
// remove the FreeInstance override; callers use Release
```

**Risk:** every `fHandler.Free` site, including `TObject2D.Destroy`, must switch to `Release` or shared handlers get freed too early.

---

### M12 — `TContainer2D.Assign` dereferences nil on an empty source

**`CADSys4.pas:16643-16653`, 3D twin at `18298-18308` · medium · ✔ verified**

```pascal
TmpIter := TContainer2D(Obj).fObjects.GetIterator;
try
  repeat
    TmpClass := TGraphicObjectClass(TmpIter.Current.ClassType);
```

`repeat` runs the body once unconditionally. For an empty list the iterator's `fCurrent` is `fHead` = nil (`CADSys4.pas:14014-14031`), `GetCurrentObject` returns nil, and `.ClassType` faults. Copying an empty container or block is a legitimate operation. `TGraphicObjList.AddFromList` guards this exact case at 13741; `Assign` does not.

```pascal
TmpSrc := TmpIter.First;
while TmpSrc <> nil do
begin
  TmpObj := TGraphicObjectClass(TmpSrc.ClassType).Create(TmpSrc.ID);
  TmpObj.Assign(TmpSrc);
  fObjects.Add(TmpObj);
  TmpSrc := TmpIter.Next;
end;
```

**Risk:** none — local change.

---

### M13 — `ExplodeContainer` produces empty objects, leaks, and faults on an empty container

**`CS4Tasks.pas:3471-3506`, same shape in `ExplodeBlock` `3508-3532` · high · ✔ verified**

```pascal
TmpClass := TGraphicObjectClass(TmpIter.Current.ClassType);
TmpObj := TmpClass.Create(TmpIter.Current.ID);
// if (TmpObj is TCircle2D) then
//
// TmpObj.Assign(TmpIter.Current);
if (TmpObj is TPrimitive2D) then
```

Three defects in thirty lines. `TmpObj.Assign` is commented out, so every exploded primitive is added to the drawing default-constructed with no geometry. The `TContainer2D` branch recurses into a freshly created *empty* container and then neither frees nor adds `TmpObj`. And `repeat` runs before testing, so an empty container dereferences a nil `Current`.

`TCAD2DExplodeObjects.Create` (3608-3641) is itself entirely commented out, so this is currently reachable only by direct calls — which is probably why it has gone unnoticed.

```pascal
if TmpIter.First = nil then Exit;
while TmpIter.Current <> nil do
begin
  TmpObj := TGraphicObjectClass(TmpIter.Current.ClassType).Create(TmpIter.Current.ID);
  try
    TmpObj.Assign(TmpIter.Current);
    if TmpObj is TPrimitive2D then
    begin
      TPrimitive2D(TmpObj).Transform(AContainer2D.ModelTransform);
      ADestCAD.AddObject(-1, TObject2D(TmpObj));   // ownership passes
    end
    else if TmpObj is TContainer2D then
    begin
      ExplodeContainer(TContainer2D(TmpObj), ADestCAD);
      TmpObj.Free;
    end;
  except
    TmpObj.Free;
    raise;
  end;
  TmpIter.Next;
end;
```

**Risk:** restoring `Assign` changes output from blank shapes to real ones. That is the intent, but it is a behaviour change for anything that coped with the blanks.

---

### M14 — `TSweepedOutline3D.CreateSolidPolyface` leaks and never balances `BeginUseProfilePoints`

**`CS4Shapes.pas:8404-8505` · high · ✔ verified**

`TmpProf: TPointsSet3D` is created at 8436 and referenced eight more times; there is no `TmpProf.Free` on any path. The outer block is `try…except`, not `try…finally`, so `fBaseOutline.EndUseProfilePoints` runs *only* when an exception escapes — never on success, never on the early `Exit` at 8427. The unbalanced `Begin` permanently increments `fCountReference`, so the base outline's profile cache can never be released either.

```pascal
Result := Rect3D(0,0,0,0,0,0);
TmpProf := nil;
fBaseOutline.BeginUseProfilePoints;
try
  ...
finally
  TmpProf.Free;
  fBaseOutline.EndUseProfilePoints;
end;
```

**Risk:** none — local change; keep the `except` branch's `fPolyface := nil`.

Two smaller leaks in the same family, both ✔ verified in passing: `CS4DXFModule.pas:672-677` drops the fully built `TPolyline2D` when the SEQEND check raises (`FreeAndNil(Result)` before the raise), and `CADSysClearFontList` (`CS4Shapes.pas:5117-5124`) frees font entries without nil-ing them, so a second call double-frees.

---

## 2. Hot-path performance

### P1 — `RepaintRect` redraws the entire document

**`CADSys4.pas:15545-15626`, with `15623-15626` · high · ✔ verified**

```pascal
procedure TCADViewport.RepaintRect(const ARect: TRect2D);
begin
  UpdateViewport(ARect);
end;
```

and inside `UpdateViewport`:

```pascal
TmpClipRect := RectToRect2D(ClientRect);
...
  DrawObject(Tmp, fOffScreenCanvas, TmpClipRect);
```

`ARect` is used only to clear the background and draw the grid. The per-object cull in `TCADViewport2D.DrawObject` tests against `VisualRect` — the whole window — and the clip rect handed to each shape's `Draw` is the whole `ClientRect`. So the FSM's "repaint only this rectangle after the operation" path (`RepaintRectAfterOperation` → `GoToDefaultState` → `RepaintRect`) costs a full O(N) document redraw and buys nothing. Worse, drawing spills outside `ARect` onto pixels that were never cleared.

```pascal
// after: cull and clip against the requested rect
TmpClipRect := ARect;
...
  if TObject2D(Tmp).IsVisible(ARect, DrawMode) then
    DrawObject(Tmp, fOffScreenCanvas, TmpClipRect);
```

**Risk:** `DrawObject` reads `VisualRect` internally rather than taking a cull rect; adding an `ACullRect` parameter means threading it through the 2D and 3D overrides. Shapes whose `Draw` ignores the clip rect will also need a real GDI clip region set on the offscreen canvas.

---

### P2 — `TPointsSet2D.Add` fires `OnChange` per point, making construction O(n²)

**`CADSys4.pas:13118-13122, 13142-13145`, 3D twins at `13350, 13375` · high · ✔ verified**

```pascal
procedure TPointsSet2D.PutProp(Index: Word; const Item: TPoint2D);
begin
  Put(Index, Index, Item);
  CallOnChange;
end;

procedure TPointsSet2D.Add(const Item: TPoint2D);
begin
  PutProp(fCount, Item);
end;
```

`fPoints.OnChange` is wired to `UpdateExtension` in eight places in `CS4Shapes.pas` (3431, 3446, 3488, 5345, 6021, 6036, 6079, 6435). So every single `Add` triggers `_UpdateExtension`, which is a full `GetExtension` scan over all points *and* an `fOnChange` notification up to the CAD component. Building an n-point polyline costs O(n²) float work plus n redraw requests. `AddPoints` (13147) already batches correctly — `Add` is the odd one out, and it is what the shapes and the DXF importer call in loops.

```pascal
// after — an opt-in batch guard
procedure TPointsSet2D.BeginUpdate; begin Inc(fUpdateLock); end;
procedure TPointsSet2D.EndUpdate;
begin
  Dec(fUpdateLock);
  if fUpdateLock = 0 then CallOnChange;
end;

procedure TPointsSet2D.CallOnChange;
begin
  if (fUpdateLock > 0) or fDisableEvents or not Assigned(fOnChange) then Exit;
  ...
end;
```

**Risk:** none for existing callers — a single `Add` still notifies. Callers opt into the speedup. Note `DisableEvents` already exists and is used this way in a few constructors; `BeginUpdate/EndUpdate` is the re-entrant version of the same idea.

---

### P3 — Per-call heap scratch buffer in the polyline/polygon draw helpers

**`CADSys4.pas:12388-12391, 12488-12489` · high · ✔ verified**

```pascal
if ToBeClosed then
  AllocatedMem := (Count + 1) * SizeOf(TPoint)
else
  AllocatedMem := Count * SizeOf(TPoint);
GetMem(TmpPts, AllocatedMem);
```

```pascal
GetMem(TmpPts, Count * 3 * SizeOf(TPoint));
GetMem(FirstClipPts, Count * 3 * SizeOf(TPoint));
```

These are the terminal calls of `TPointsSet2D.DrawAsPolyline` / `DrawAsPolygon`, i.e. once per shape per frame. A drawing with 5 000 polylines does 5 000 alloc/free round-trips per repaint; the polygon path allocates `6 * Count * SizeOf(TPoint)` bytes and discards them immediately.

```pascal
threadvar
  _ScratchPts: array of TPoint;

procedure EnsureScratch(N: Integer); inline;
begin
  if Length(_ScratchPts) < N then SetLength(_ScratchPts, N * 2);
end;
// EnsureScratch(Count * 3); TmpPts := @_ScratchPts[0];  — nothing to free
```

**Risk:** the buffer must be `threadvar` because the library paints from `TPaintingThread`. The polygon helper needs two disjoint slices of it.

---

### P3b — bounds guard off by one in the same two helpers

**`CADSys4.pas:12385-12386, 12486` · medium · ✔ verified**

```pascal
if (Count = 0) or (EndIdx > Count) or (StartIdx > EndIdx) then
  Exit;
```

`EndIdx = Count` is admitted, so the loops read `PVectPoints2D(Vect)^[Count]` — one past the last point — and write `TmpPts^[Count]` into a buffer sized for exactly `Count` entries. `DrawSubsetAsPolyline` / `DrawSubsetAsPolygon` (13245, 13253) pass caller-supplied indices straight through with no validation of their own. Additionally, when `StartIdx = EndIdx` the `for` body never runs, yet the code below still reads `ClipRes` and `TmpPt2`, both uninitialised stack locals.

```pascal
if (Count = 0) or (StartIdx < 0) or (EndIdx >= Count) or (StartIdx >= EndIdx) then
  Exit;
ClipRes := [];
TmpPt2  := PVectPoints2D(Vect)^[StartIdx];
```

**Risk:** the stricter guard rejects the degenerate one-point subset that previously drew garbage. Confirm no shape in `CS4Shapes` relies on that call succeeding.

---

### P4 — A GDI font is created and destroyed on every `TText2D.Draw`

**`CS4Shapes.pas:4457`, with `3144-3148` and `3291-3300` · high · ✔ verified**

```pascal
procedure TExtendedFont.SetHeight(Value: Word);
begin
  LogFont.lfHeight := Value;
  SetNewValue;              // unconditional CreateFontIndirect + DeleteObject
end;
```

`TText2D.Draw` assigns `fExtFont.Height := TmpHeight` on every call, and `SetHeight` rebuilds the HFONT even when the value is unchanged. At a fixed zoom `TmpHeight` is constant frame to frame. GDI handle creation is among the slowest calls on the paint path; a drawing with a few hundred labels churns hundreds of font handles per frame.

```pascal
procedure TExtendedFont.SetHeight(Value: Integer);
begin
  if LogFont.lfHeight = Value then Exit;
  LogFont.lfHeight := Value;
  SetNewValue;
end;
```

**Risk:** the guard alone is free. Widening `Value` from `Word` to `Integer` is a public-API change, but it is also a correctness fix — a negative `lfHeight` (the "character height rather than cell height" convention) cannot currently be expressed at all.

---

### P5 — `stSpace` curves re-flatten on every draw, hit-test and `IsClosed`

**`CS4Shapes.pas:3865-3875`, default set at `7075` · high · ✔ verified**

```pascal
procedure TCurve2D.BeginUseProfilePoints;
begin
  if fSavingType = stSpace then
    WritableBox := PopulateCurvePoints(0);
end;

procedure TCurve2D.EndUseProfilePoints;
begin
  if fSavingType = stSpace then
    FreeCurvePoints;
end;
```

`FreeCurvePoints` drops the buffer, so the next `Draw`, `OnMe` or `GetIsClosed` re-runs the whole flattening — the trig loop, the extension scan, the bounding-box transform. `TOutline2D.GetIsClosed` (3582-3591) also wraps `Begin/End`, so a single hit-test on a closed curve can flatten it twice. `stSpace` is the **default for every 3D curve** (`TCurve3D.Create`, 7075).

The fix is a dirty flag rather than an unconditional rebuild:

```pascal
procedure TCurve2D.BeginUseProfilePoints;
begin
  if (fSavingType = stSpace) and fProfileDirty then
  begin
    WritableBox := PopulateCurvePoints(0);
    fProfileDirty := False;
  end;
  Inc(fCountReference);
end;
```

**Risk:** `stSpace` exists precisely to trade CPU for RAM. Retaining the buffer inverts that trade, so gate it behind an explicit "cache while visible" flag if memory matters for the target drawings.

---

### P6 — `SetCurvePrecision` does not invalidate the flattened profile

**`CS4Shapes.pas:3711-3715`, 3D twin at `7040-7044` · medium-high · ✔ verified**

```pascal
procedure TCurve2D.SetCurvePrecision(N: Word);
begin
  if fCurvePrecision <> N then
    fCurvePrecision := N;
end;
```

The setter immediately below it, `SetPrimitiveSavingType`, calls `UpdateExtension(Self)` — which makes the omission look accidental rather than deliberate. In `stTime` mode (the 2D default) the cache is rebuilt only from `_UpdateExtension`, so after a precision change the curve keeps drawing at the old segment count until some unrelated control-point edit happens.

```pascal
if fCurvePrecision <> N then
begin
  fCurvePrecision := N;
  UpdateExtension(Self);
end;
```

**Risk:** none — local change; costs one rebuild, matching the sibling setter.

---

### P7 — B-spline basis is evaluated by exponential recursion over every control point

**`CS4Shapes.pas:4299-4339`, callers at `4358` and `7777` · high · ✔ verified**

```pascal
T := Knot(I + K - 1, OK, N) - Knot(I, OK, N);
if T <> 0 then
  V := (U - Knot(I, OK, N)) * NBlend(I, K - 1, OK, N, U) / T;
```

```pascal
for I := 0 to N do
begin
  B := NBlend(I, K, K, N, U);
```

`NBlend` is the textbook Cox–de Boor recurrence with no memoisation: two recursive calls per level, four `Knot` evaluations each. And `BSpline2D` calls it for *all* `N+1` control points even though the basis has local support — at most `K` are non-zero for a given `U`, so on a 200-point spline roughly 98 % of the work computes exact zeros. Cost is `CurvePrecision × (N+1) × 2^(K-1)` where `O(CurvePrecision × K²)` suffices. Combined with P5, this runs on every draw for 3D splines.

```pascal
Span := FindSpan(U, N, K);        // knot interval containing U
BasisFuns(Span, U, K, Nb);        // the K non-zero basis values, O(K^2)
Result := Point2D(0, 0);
for I := 0 to K - 1 do
  AccumulateWeighted(Result, Points[Span - K + 1 + I], Nb[I]);
```

**Risk:** medium. The replacement must reproduce `Knot()`'s integer-clamped knot vector exactly or existing splines change shape. Worth a pixel-diff regression against saved drawings.

---

### P8 — Arc and ellipse flattening: fixed 50 segments, `Cos` and `Sin` recomputed per point

**`CS4Shapes.pas:3980-4003` (arc), `4203-4212` (ellipse), precision set at `4011` · medium · ✔ verified**

```pascal
CurrAngle := FStartAngle;
for Cont := 0 to NPts - 1 do
begin
  ProfilePoints.Add(Point2D(CX + RX * Cos(CurrAngle),
    CY - RY * Sin(CurrAngle)));
  CurrAngle := CurrAngle + Delta
end;
```

Two transcendental calls per point where `Math.SinCos` gives both for the price of one, and the whole loop can be an incremental rotation from a single precomputed `Cos(Delta)`/`Sin(Delta)` pair. Separately, `CurvePrecision` is hard-coded to 50 in the constructor with no zoom feedback: a 4-pixel circle costs the same 50 segments as a full-screen one, while a zoomed-in arc visibly polygonises.

```pascal
SinCos(Delta, SD, CD);
SinCos(FStartAngle, S, C);
for Cont := 0 to NPts - 1 do
begin
  ProfilePoints.Add(Point2D(CX + RX * C, CY - RY * S));
  T := C * CD - S * SD;  S := S * CD + C * SD;  C := T;
end;
```

**Risk:** incremental rotation accumulates error — re-seed from `SinCos` every ~64 points, or keep `SinCos` per point (still a 2× win) if exactness matters. Adaptive segment counts change `SaveToStream` output for `stSpace` curves, so version-gate that part.

---

### P9 — `TContainer2D.Draw` constructs a `TPen` and a `TBrush` on every call

**`CADSys4.pas:16681-16713`, 3D twin at `18336` · high · ✔ verified**

```pascal
TmpIter := fObjects.GetIterator;
TmpPen := TPen.Create;
TmpBrush := TBrush.Create;
try
  TmpTransf := MultiplyTransform2D(ModelTransform, VT);
  TmpObj := TObject2D(TmpIter.First);
  TmpPen.Assign(Cnv.Canvas.Pen);
  TmpBrush.Assign(Cnv.Canvas.Brush);
```

Two GDI-backed VCL objects created and destroyed per container per repaint, used only to snapshot and restore canvas state around the children. A plain record copy would do. Blocks nest, so it compounds per nesting level; the iterator is a third heap object plus two critical-section round-trips.

```pascal
type
  TPenState = record Color: TColor; Style: TPenStyle; Mode: TPenMode; Width: Integer; end;
var SavedPen: TPenState; SavedBrushColor: TColor; SavedBrushStyle: TBrushStyle;
```

**Risk:** if a child shape touches a pen property the snapshot does not cover (`Pen.Brush`, for instance), the restore becomes incomplete. Enumerate what the shapes actually set before switching.

---

### P10 — Object lookup by ID is a linear walk plus a heap-allocated iterator, done twice per delete

**`CADSys4.pas:15056-15064, 15077-15087, 13873-13894` · high · ✔ verified**

```pascal
procedure TCADCmp.DeleteObject(const ID: LongInt);
begin
  TmpObj := GetObject(ID);        // full scan #1 + iterator alloc #1
  if TmpObj = nil then Raise ...;
  fListOfObjects.Delete(ID);      // full scan #2 + iterator alloc #2
end;
```

`TGraphicObjList` is a hand-rolled doubly linked list with no ID index, and `TGraphicObjIterator.Create`/`Destroy` each enter and leave the list's critical section. Deleting M objects from a drawing of N costs 2·M·N pointer hops and 2·M iterator allocations. `RemoveObject` (15045) and `ChangeObjectLayer` (15066) have the same double-scan shape.

```pascal
private
  fIndex: TDictionary<LongInt, Pointer>;

procedure TCADCmp.DeleteObject(const ID: LongInt);
var B: PObjBlock;
begin
  B := fListOfObjects.FindBlock(ID);
  if B = nil then Raise ECADListObjNotFound.Create(...);
  fListOfObjects.DeleteBlock(B);
end;
```

**Risk:** every mutation path — `Add`, `Insert`, `Move`, `DeleteBlock`, `RemoveBlock`, `Clear` — plus the direct writes to `Obj.ID` at 14959, 15009 and 15032 must keep the index in sync, or lookups silently miss.

---

### P11 — Saving looks up each object's class by linear string search over 512 slots

**`CADSys4.pas:13577-13590`, called at `16575, 17067, 17195, 18235, 18699, 18815` · medium · ✔ verified**

```pascal
function CADSysFindClassIndex(const Name: String): Word;
begin
  for Cont := 0 to MAX_REGISTERED_CLASSES - 1 do
    if Assigned(GraphicObjectsRegistered[Cont]) and
      (GraphicObjectsRegistered[Cont].ClassName = Name) then
```

`MAX_REGISTERED_CLASSES` is 512. `TObject.ClassName` builds a fresh string from the ShortString VMT entry on *every* call — once for the argument and once for each registry entry compared. Saving 50 000 objects costs up to 25 million string comparisons and as many transient allocations.

```pascal
var ClassIndexMap: TDictionary<TClass, Word>;   // filled by CADSysRegisterClass

function CADSysFindClassIndex(const AClass: TClass): Word;
begin
  if not ClassIndexMap.TryGetValue(AClass, Result) then
    Raise ECADObjClassNotFound.Create('CADSysFindClassIndex: ' + AClass.ClassName);
end;
```

**Risk:** the string-keyed overload is public API (declared at 9597) and used from `CS4Shapes.pas:5763, 8612`. Keep it as a thin wrapper over the class-keyed version rather than removing it.

---

### P12 — Every paint erases the background and then blits over it

**`CADSys4.pas:15402, 15214-15221` · high · ✔ verified**

```pascal
ControlStyle := ControlStyle - [csOpaque];
```

```pascal
procedure TCADViewport.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  if (not Assigned(fOnClear)) and (not fTransparent) or
    (csDesigning in ComponentState) then
    inherited
  else
    Message.Result := 1;
end;
```

In the default configuration — no `OnClearCanvas`, not transparent — the condition is True, so `WM_ERASEBKGND` is handled by `TWinControl` and paints the control brush over the whole client area immediately before `DoCopyCanvas` blits the offscreen bitmap over the identical area. Removing `csOpaque` is what tells the VCL that erase is needed. The offscreen bitmap always covers 100 % of the client rect, so neither step is required. Result: one wasted full-client `FillRect` per frame plus visible flicker, in the interactive drag path.

```pascal
ControlStyle := ControlStyle + [csOpaque];
...
if fTransparent or (csDesigning in ComponentState) then
  inherited
else
  Message.Result := 1;
```

**Risk:** transparent mode genuinely needs the parent's pixels — keep that branch. Design-time rendering also relies on the inherited erase.

Related, ○ spot-check: `Invalidate` never calls the inherited `Invalidate` at run time (`15484-15499`), so N calls in one handler produce N immediate full-window blits instead of one coalesced `WM_PAINT`; `TCADCmp.RedrawObject` uses `Refresh` where `RefreshRect` exists; and `UpdateViewportOrientation` (`19149-19170`) repaints twice per 3D camera change because `UpdateViewportTransform` already repaints.

---

## 3. Modernization & portability

### X1 — Window subclassing casts pointers through `LongInt`

**`CADSys4.pas:20218-20250` · low for Delphi, high for FPC/Lazarus · ✔ verified**

> **Scope correction.** This whole block is guarded by `{$IFDEF windows}`. That is an FPC/Lazarus conditional; Delphi defines `MSWINDOWS` and `WIN32`/`WIN64`, never bare `windows`. So in the Delphi build the `{$ELSE}` branch compiles (`fNewWndProc, fOldWndProc: TWndMethod` and `V.WindowProc := fNewWndProc`, declaration at line 6920) and the truncating code below never runs. Fix it anyway — it is free and correct — but it does not block a Delphi Win64 build.

```pascal
fOldWndProc := {%H-}Pointer(SetWindowLong(V.Handle, gwl_wndProc,
{%H-}LongInt(fNewWndProc)));
```

`SetWindowLong` with `GWL_WNDPROC` accepts and returns a 32-bit value. On Win64 both the `MakeObjectInstance` pointer and the returned original WndProc are truncated, and the later `CallWindowProc` jumps to a bad address. The `{%H-}` hints suppress exactly the compiler warning that flags this. `TCADPrg` cannot work in a 64-bit build.

```pascal
fOldWndProc := Pointer(SetWindowLongPtr(V.Handle, GWLP_WNDPROC,
  LONG_PTR(fNewWndProc)));
...
SetWindowLongPtr(fLinkedViewport.Handle, GWLP_WNDPROC, LONG_PTR(fOldWndProc));
```

**Risk:** none on Win32 — `SetWindowLongPtr` maps to `SetWindowLong` there. The `{$ELSE}` non-Windows branch already uses `WindowProc` and is unaffected.

---

### X2 — DXF parser mutates the global decimal separator per line

**`CS4DXFModule.pas:323, 337-340, 349-352, 363-364`, writer at `441-443, 456-457` · high · ✔ verified**

```pascal
LastSep := FormatSettings.DecimalSeparator;
try
  ...
      if Pos('.', TxtLine) > 0 then
        FormatSettings.DecimalSeparator := '.'
      else
        FormatSettings.DecimalSeparator := ',';
      try
        fGroupValue := StrToFloat(Trim(TxtLine));
```

A global write/restore pair on every parsed group. DXF is always `.`-decimal, so the sniffing is pointless to begin with; worse, `FormatSettings` is process-global, so any other thread formatting a number mid-import — including this library's own `TPaintingThread` — sees a corrupted separator. An exception escaping between the two writes leaves the whole application's locale altered.

```pascal
// field, initialised once in the constructor
fFS := TFormatSettings.Invariant;
...
fGroupValue := StrToFloat(Trim(TxtLine), fFS);
TxtLine := Format('%.6f', [Double(GroupValue)], fFS);
```

**Risk:** none — invariant settings match what the code already forces.

---

### X3 — `array of Char` in the on-disk format silently doubled under Unicode

**`CADSys4.pas:526, 529`, consumed at `14792, 14814, 16787, 16796, 16865, 16891` · high · ✔ verified**

```pascal
TCADVersion = array [1 .. 6] of Char;
TSourceBlockName = array [0 .. 12] of Char;
```

`Char` is `WideChar` on Delphi 2009+, so `SizeOf(TCADVersion)` is 12 rather than 6 and `SizeOf(TSourceBlockName)` is 26 rather than 13. The file layout is defined by `SizeOf` at every one of these call sites, so the format silently doubled and legacy `.cad` files misparse from byte 0. The code is clearly being built on a modern compiler — scoped `WinAPI.Windows` units at 14516, `TJSONObject` at 17090.

```pascal
TCADVersion      = array [1 .. 6] of AnsiChar;
TSourceBlockName = array [0 .. 12] of AnsiChar;
```

**Risk:** comparisons such as `TmpVersion = CADSysVersion` (14815) and `Copy(TmpVersion, 1, 3) = 'CAD'` (14820) then compare Ansi against Unicode literals — add explicit casts. Also audit `TLayerName = String[31]` (line 571), which is already `AnsiChar`-based and therefore already inconsistent with its neighbours.

---

### X4 — `TText2D` stream I/O writes twice the byte length of an `AnsiString`

**`CS4Shapes.pas:4511-4513, 4538-4541`, field at `751` · high · ✔ verified**

```pascal
fText: AnsiString;
...
SetLength(fText, TmpInt);                  // TmpInt bytes allocated
Read(Pointer(fText)^, TmpInt * SizeOf(Char));   // 2*TmpInt bytes read
...
Write(Pointer(fText)^, TmpInt * SizeOf(Char));  // 2*TmpInt bytes written
```

`SizeOf(Char)` is 2 under Unicode but the string is `AnsiString`. The load path overruns the heap block by `Length(fText)` bytes on every text object; the save path reads past the end of the buffer and writes garbage into the file. Neither side is version-guarded, so the format is self-inconsistent with the `'CAD423'` guards immediately below it.

```pascal
SetLength(fText, TmpInt);
if TmpInt > 0 then
  Read(PAnsiChar(fText)^, TmpInt * SizeOf(AnsiChar));
```

**Risk:** this actually *restores* compatibility with pre-Unicode files (1 byte/char). Files written by the current broken build will not load — bump the version if any exist in the wild.

---

### X5 — `Ord(Ch)` indexes a 256-slot list, so any character above U+00FF raises out of `Draw`

**`CS4Shapes.pas:4832-4834`, with `4895-4901, 4917, 4957, 5003` · high · ✔ verified**

```pascal
function TVectFont.GetChar(Ch: Char): TVectChar;
begin
  Result := TVectChar(fVects[Ord(Ch)]);
end;
```

`fVects` is a 256-entry `TIndexedObjectList` and `TIndexedObjectList.GetObject` raises `ECADOutOfBound` beyond that (`CADSys4.pas:14221-14225`). But `TJustifiedVectText2D.fText` is `String` — UnicodeString (line 1168) — so `Ord(Ch)` reaches 65 535. A single em-dash, curly quote, €, Cyrillic or CJK character makes every repaint of that shape raise. `GetTextExtension` is on the `_UpdateExtension` path too, so the object cannot even be added to the drawing.

```pascal
function TVectFont.GetChar(Ch: Char): TVectChar;
begin
  if Ord(Ch) > 255 then
    Result := _NullChar
  else
    Result := TVectChar(fVects[Ord(Ch)]);
end;
```

Guard the three raw `fVects[Ord(Ch)]` sites the same way, or widen the list and key it by codepoint.

**Risk:** none — falls back to the `_NullChar` glyph already used for unmapped Latin-1 codes.

---

### X6 — `fGroupValue := varEmpty` stores integer 0, defeating every `varEmpty` guard

**`CS4DXFModule.pas:344, 356`, consumers at `644, 727, 733, 735` · medium · ✔ verified**

```pascal
try
  fGroupValue := StrToFloat(Trim(TxtLine));
except
  fGroupValue := varEmpty;
end;
```

`varEmpty` is a `TVarType` constant equal to 0, so this assigns the *value* 0. `VarType(fGroupValue)` then returns an integer type, never `varEmpty`. Guards written to catch the failure — `if VarType(Entry[50]) <> varEmpty then RotTransf := Rotate2D(DegToRad(Entry[50]))` — accept the bogus value instead, and an unparseable coordinate becomes a silent 0.0 at the origin.

```pascal
VarClear(fGroupValue);      // or: fGroupValue := Unassigned;
```

**Risk — lower than first assessed.** I originally worried this would turn silent wrong values into `EVariantError`. It will not: `VarType(...) <> varEmpty` guards are already pervasive in this unit (567, 592, 609, 625, 644, 727, 733, 735, 1683, 1714, 1742, 1783, 1796, 1811, 1823, 1848-1908, 1948, 2006-2029). They exist to catch *unset* table slots, which genuinely are Unassigned. The fix simply makes the parse-failure path look like the unset path, which is what those guards already expect — the else-branch (identity transform, skipped point) runs instead of silently using 0.0.

---

### X7 — `TGraphicObject` inherits `TInterfacedObject` for no reason

**`CADSys4.pas:1542` · medium · ✔ verified**

```pascal
TGraphicObject = class(TInterfacedObject)
```

A grep across all six units finds no `IInterface`, `IUnknown`, `Supports`, `QueryInterface` or `as I…` — the refcounting is dead weight on the most numerous class in the library. Every object carries `FRefCount` and three extra VMT entries. The latent hazard matters more than the size: `TInterfacedObject.BeforeDestruction` calls `System.Error(reInvalidPtr)` when `FRefCount <> 0`, so the moment any client assigns a `TGraphicObject` to an interface variable, the list's `Obj.Free` becomes a hard runtime error. Lifetime here is unambiguously owner-based (`FreeOnClear`), not refcounted.

```pascal
TGraphicObject = class(TObject)
```

**Risk:** breaks downstream application code that stores a `TGraphicObject` in an interface variable. Grep the consuming project first; nothing within these sources depends on it.

Two more in the same family, both ✔ verified: `TPointsSet3D.Expand` (`13272-13279`) has `X := 0` twice and never initialises `Z`, so grown slots carry whatever `ReAllocMem` returned straight into `GetExtension`; and `CADSysFindFontByIndex` (`CS4Shapes.pas:5050-5062`) indexes `VectFonts2DRegistered` with an unchecked `Word` read from a file, while every sibling accessor bounds-checks. `ReadAnEntry` (`CS4DXFModule.pas:406-410`) has the same shape — group codes above 1256 write past the end of the 513-element `TGroupTable`, and the callers declare it as a stack local.

---

## 4. Structure

### S1 — 2D and 3D code paths are duplicated near-verbatim, and have already diverged

**`CADSys4.pas:13031-13259` vs `13265-13498`; `16514-16757` vs `18167-18428`; `16763-17000` vs `18430-18660` · medium · ✔ verified**

Roughly 700 duplicated lines across point sets, containers and blocks. The pairs differ only in type names — and where they have drifted, it is by accident: `First` vs `Current` in `_UpdateExtension`, the missing `Z` initialiser at 13277, `GrowingEnabled := True` set in `TPrimitive3D.Create` but not in `TPrimitive2D.Create`. Every bug in section 1 above exists in two places, and several have been fixed in only one.

Worth doing incrementally — point sets first, containers last — not as a single change. `Get`/`Put` are virtual and overridden by descendants, and generic virtual methods have their own constraints.

---

### S2 — The object-drawing loop is duplicated between `UpdateViewport` and `TPaintingThread.Execute`

**`CADSys4.pas:14285-14336` vs `15569-15620` · medium · ✔ verified**

Three concrete divergences already: the `NODRAW` check happens before iterator creation in one copy and after `TmpIter.First` in the other; the batch test is `>=` in one and `=` in the other; and the threaded path's early `Exit`s bypass the final `Synchronize(DoCopyCanvasThreadSafe)`, so a `NODRAW` threaded repaint never presents the cleared buffer, while the synchronous path always runs `DoCopyCanvas(True)` in its `finally`.

Extract one shared `RenderObjects` body parameterised by a "present" callback and an abort check. Keep the `Terminated` test inline rather than behind an indirect call per object.

---

### S3 — `TRectangle2D` and `TFilledEllipse2D` are byte-identical copy-paste

**`CS4Shapes.pas:4132-4168` vs `4246-4283` · medium · ✔ verified**

Both `Draw` bodies and both `OnMe` bodies are textually identical apart from a comment. Both are "a `TCurve2D` whose profile is filled rather than stroked", but the shared behaviour lives in neither `TCurve2D` nor a common intermediate — so the loop-invariant `RectToRect2D(Cnv.Canvas.ClipRect)` fix and the P5 re-flatten fix each have to be applied twice.

**Risk:** `TFilledEllipse2D` descends from `TEllipse2D` and `TRectangle2D` from `TFrame2D`, and both hierarchies are exercised by `is` tests in `Assign` (4121, 4235) and by the class-registration tables. Reparenting changes those `is` results. The safe version is to move the two bodies into protected helpers on `TCurve2D` and have each class call them.

---

### S4 — `CADSysRegister` does runtime-critical initialisation in a design-time unit

**`CADSysRegister.pas:19-23, 27-45, 66-76` · medium · ○ spot-check**

The class registry, the default primitive handlers and the vector font list are all built in this unit's `initialization` — but the unit exists to supply `Register` for the IDE. An application that uses `CADSys4`/`CS4Shapes` without listing `CADSysRegister` gets an empty registry, and `CADSysFindClassByName` raises rather than returning nil. Object persistence and `TCAD2DEditPrimitiveParam.Create` both depend on it at runtime.

Separately: 21 3D classes are registered here, yet no 3D component is published to the palette even though `TCADCmp3D`, `TCADViewport3D` and `TCADPrg3D` all exist; and the three `RegisterComponents` calls should be one.

**Risk:** moving the initialisation changes unit init order. The Italian comment at line 27 records that this was already moved once to fix an ordering problem, so the destination unit must initialise after `CADSys4`.

---

### S5 — Dead code that reads as live

Three verified instances worth removing or restoring deliberately rather than leaving ambiguous:

- **`CS4BaseTypes.pas:405-442, 533-562`** — `TDecorativePen.CallLineDDA` has its `LineDDA` calls commented out (almost certainly because `Integer(Self)` breaks on 64-bit), leaving a plain solid segment. But `Polyline` still branches on `fPStyle.Size > 0` and loops `CallLineDDA` per segment instead of taking the single `WinAPI.Windows.Polyline` on the else branch — same pixels, N× the GDI calls, for a pattern feature that no longer works. `LineDDAMethod1`/`2` are now unreachable, and their `mod GetMaxBit` would divide by zero if they were reached with an empty pattern.
- **`CS4Tasks.pas:3132-3141`** — the "only registered classes are allowed" guard is unreachable: `CADSysFindClassByName` forwards to `CADSysFindClassIndex`, which raises rather than returning nil, so `if not Assigned(fCurrentPrimitive)` is dead — and would be too late anyway, since a nil class reference would have faulted on `.Create(0)`.
- **`CS4Tasks.pas:3380-3387, 3608-3641`** — commented-out blocks left in place after the recent param fix, and the entire `TCAD2DExplodeObjects.Create` body.

---

## 5. API friction, from the demos

### A1 — Use-after-free when cancelling the "Define Block" name dialog

**`Demos/delphi/CAD2D/Unit1.pas:171-177` · high · ✔ verified**

```pascal
with TCAD2DSelectObjectsParam(Param), TCADCmp2D(CADPrg.Viewport.CADCmp) do
  begin
    if not InputQuery('Define block', 'Name', TmpStr) then
     begin
       NextState := CADPrg.DefaultState;
       Param.Free;
       Param := nil;
     end;
    TmpIter := SelectedObjects.GetExclusiveIterator;
```

`SelectedObjects` resolves through the `with` binding opened on `Param`. Cancelling the prompt frees that very object, but there is no `Exit` and no `else` — execution falls straight through to `SelectedObjects.GetExclusiveIterator` on a freed object. This is the reference sample app, on a toolbar-reachable path.

The demo needs the `Exit`. But the root cause is that param ownership after `StartOperation`/`GoToDefaultState` is entirely convention-based, so a custom state author has to hand-roll teardown and remember to stop:

```pascal
procedure TCADState.AbortToDefault(var NextState: TCADStateClass);
// frees fParam, nils it, sets NextState := CADPrg.DefaultState
```

**Risk:** additive helper; no break to existing state classes.

---

### A2 — The canonical `BlockObjects` example leaks an iterator

**`Demos/delphi/CADCmpDemo/Unit1.pas:551-553`, library at `CADSys4.pas:17306-17324` · high · ✔ verified**

```pascal
// Create the source block.
CSCAD.BlockObjects('ABlock', Src.GetIterator);
// Remove the iterators.
Src.RemoveAllIterators;
```

`Src.GetIterator` heap-allocates a `TGraphicObjIterator` that is never captured or freed. `BlockObjects` never frees the `Objs` it receives (confirmed — no `Objs.Free` in the body). `RemoveAllIterators` only zeroes counters on the *list*; it does not touch the instance. Every call of this pattern leaks, and this is the demo's official example.

```pascal
function TCADCmp2D.BlockObjects(const SrcName: TSourceBlockName;
  const Objs: TGraphicObjList): TSourceBlock2D; overload;
// call site: CSCAD.BlockObjects('ABlock', Src);
```

**Risk:** add as an overload and keep the iterator-taking version, making it free `Objs` on exit — the demo never reuses the iterator afterwards.

---

### A3 — The "free your own Param, then nil it" protocol is undocumented

**`CADSys4.pas:20357-20359` vs `20171-20176` · high · ✔ verified**

```pascal
// GoToDefaultState:
if Assigned(fCurrentState.fParam) then
  fCurrentState.fParam.Free;

// TCADState.Destroy — the equivalent line is commented OUT:
//  if Assigned(Param) then
//     FreeAndNil(Param);
```

`TCADPrg` auto-frees `fCurrentState.fParam` on every return to the default state. So any state that frees `Param` early for its own reasons must also set `Param := nil`, or the framework double-frees. This rule appears nowhere in the public doc comments for `TCADPrgParam` or `TCADState` — which only document that the object *inside* a param is freed with it. It is discoverable only by reading `TCADPrg`'s internals, which is precisely why the demo's own custom state gets it half-right (A1) and why the `TCAD2DEditPrimitive` leak survived this long.

At minimum, document it on both classes. Better: a `TCADState.ReleaseParam` that frees and nils atomically, so there is a right way that is also the easy way.

---

### A4 — `AddObject` silently discards the ID the constructor was given

**`Demos/delphi/CADCmpDemo/Unit1.pas:74-78`, library at `CADSys4.pas:15009, 17373` · medium · ✔ verified**

```pascal
{ ... Note that to add an object and give it a
  free ID you can pass -1 as the object ID. }
CSCAD.AddObject(1, TEllipse2D.Create(1, Point2D(0, 0), Point2D(20, 20)));
```

`AddObject`/`InsertObject` always execute `Obj.ID := ID`, overwriting whatever the shape's constructor was handed. So every `TXxx2D.Create(ID, ...)` call site across both demos supplies a throwaway value that has no effect — and the documented `-1` idiom is never actually exercised in the tutorial that describes it. The ID is a container concern; the shape does not need it at construction time.

```pascal
function TCADCmp2D.AddObject(const Obj: TObject2D): TObject2D; overload;  // auto ID
function TCADCmp2D.AddObject(const ID: LongInt; const Obj: TObject2D): TObject2D; overload;
```

**Risk:** dropping the constructor parameter is source-breaking. Phase it in with ID-less constructor overloads while the ID-taking ones stay for compatibility.

Two smaller ones, both ✔ verified: `StringToBlockName` (`CADSys4.pas:16501-16512`) truncates block names at 13 characters with no signal, so `"ElectricalPanel_A"` and `"ElectricalPanel_B"` silently collide and `FindSourceBlock` returns the wrong block; and all ten toolbar handlers in `CAD2D/Unit1.pas` guard `StartOperation` with `if IsBusy then StopOperation`, which `StartOperation` already does internally (`20627-20628`) — harmless, but the reference sample is teaching a defensive pattern that says the guarantee is not trusted.

---

## Implementation status

Phase 1 has been implemented on the branch **`fix/phase1-memory-and-portability`**. **None of it has been compiled** — no Delphi toolchain was reachable — so treat the branch as a reviewed proposal, not a tested one. Every change carries a `CS4-FIX` comment naming the finding, so `grep -n "CS4-FIX" Sources/*.pas` lists them all in place.

Because `HEAD` stores these files LF and the working tree is CRLF, the branch opens with a labelled baseline commit of the four units as they stood (including your own uncommitted work). Review the fixes with `git diff --ignore-cr-at-eol` against that baseline; the whole-file noise is confined to the baseline commit itself.

| Finding | Status |
|---|---|
| M1 — pan double-free (5 sites) | **fixed** |
| M6 — `TCADPrgPan.Create` nil deref | **partly fixed** — nil-guard only; see the revised risk note |
| M12 — `TContainer2D/3D.Assign` nil deref | **fixed** |
| M14 — sweep leak / unbalanced `BeginUseProfilePoints` | **fixed** |
| P3b — draw-helper bounds + uninitialised locals | **fixed** |
| P4 — GDI font rebuilt per draw | **fixed** |
| P6 — `SetCurvePrecision` invalidation | **fixed** |
| X2 — DXF global `FormatSettings` | **fixed** |
| X5 — `Ord(Ch)` above U+00FF | **fixed** |
| X6 — `varEmpty` stores integer 0 | **fixed** |
| X1 — `SetWindowLongPtr` | **fixed** (FPC path only — see scope correction) |
| `TPointsSet3D.Expand` Z never initialised | **fixed** |
| `TLayers.RestoreLayers` brush leak | **fixed** |
| `CADSysFindFontByIndex` bounds / `CADSysClearFontList` dangling slots | **fixed** |
| DXF: `SetTextBuf`, `ReadPolyline2D` leak, `ReadAnEntry` extended-code bounds | **fixed** |
| DXF: `ReadAnEntry` never clears the group table | **fixed, isolated commit** — the one behaviour change in the set; revert that commit alone if an import regresses |
| M5 — `fCallerParam` ownership | **deferred** to the ownership phase (see its revised risk note) |
| X3 / X4 — file-format version gate | **not attempted** — see below |

### Phase 2a (branch `fix/phase1-memory-and-portability`, commit `1e8ecd9`)

A second, still-conservative pass: local changes only, no public signature changes, no geometry or format changes.

| Finding | Status |
|---|---|
| M11 — handler refcount via `FreeInstance` | **fixed** — replaced with an explicit `Release`; six call sites plus `CADSysRegister`'s finalization updated |
| M13 — `ExplodeContainer` / `ExplodeBlock` | **fixed** — `Assign` restored, nested copy no longer leaked, empty-source fault gone |
| P2 — `Add` fires `OnChange` per point | **fixed** — `BeginUpdate`/`EndUpdate` added; purely additive, existing callers unaffected until they opt in |
| P3 — scratch buffer allocated per shape per frame | **fixed** — 512-point stack buffer with heap fallback, in all three subset helpers |
| P9 — `TPen`/`TBrush` constructed per container draw | **fixed** — record snapshot; verified no shape assigns `Pen.Brush` or `Brush.Bitmap` |
| P12 — background erased then fully overpainted | **fixed** — `csOpaque` set, managed by `SetTransparent`, `WMEraseBkgnd` narrowed |
| S5 — `TDecorativePen.Polyline` dead pattern branch | **fixed** — single `WinAPI.Windows.Polyline`, identical pixels |
| **M4 — 11 state constructors leak `StateParam` on raise** | **deferred** — see below |
| Everything else in Phases 2-4 | **not started** |

**Why M4 moved out of the safe set.** Freeing `StateParam` before a constructor raises has exactly the hazard that kept M5 and M6 out of Phase 1: `SuspendOperation` (`CADSys4.pas:20705`) aliases the *suspended* state's param into `StateParam` when the caller passes `nil`, so a type-check failure in the new state would free a live task's parameter rather than an orphan. `SuspendOperation(TCAD2DSelectObjects, nil)` while a drawing task is running is a realistic path to exactly that. M4 is now the third finding blocked on the same root cause — which is the clearest argument yet that **M5/M7/M8/A3 are the linchpin** and should be the next real piece of work, not more leaf fixes.

Two Phase 2a changes alter observable behaviour and want a visual check: **P12** changes how the viewport paints, and **M13** changes what explode produces (from blank shapes to real ones). The nested-container transform composition in `ExplodeContainer` is the one part with no prior behaviour to compare against — the original never got far enough to define an intended nesting order.

### Why the file-format version gate is not in this branch

Version-gating X3/X4 was the chosen direction, and it remains the right one. I did not implement it blind, because the failure mode is "no drawing loads at all" and I have neither a compiler nor a single sample `.cad` file to check against.

The work itself is tractable and worth describing precisely, because the shape of it is what makes it risky:

The header is the chicken-and-egg. `TCADVersion` is read with `Read(fVersion, SizeOf(fVersion))`, and `SizeOf` is exactly the thing that changed — 6 bytes on a pre-Unicode build, 12 on the current one. Both spell `'CAD423'`, so the version string cannot discriminate between them. It has to be sniffed from the bytes:

```pascal
{ 'CAD423' as AnsiChar: 43 41 44 34 32 33
  'CAD423' as WideChar: 43 00 41 00 44 00 ...
  Byte 1 is 'A' in the first and #0 in the second - a clean discriminator. }
Stream.Read(Buf, 6);
FWideLegacy := Buf[1] = 0;
if FWideLegacy then
  Stream.Read(Buf2, 6);   { the other half of the 6 WideChars }
```

Then the *result of that sniff* has to reach `TSourceBlock2D.CreateFromStream` and `TText2D.CreateFromStream`, which currently receive only `Version: TCADVersion`. Threading a width flag through every `CreateFromStream` signature is the clean fix and a wide source change; a module-level `CADSysLoadIsWideLegacy` global is the small fix and is not re-entrant across concurrent loads.

What would make this safe to write: one `.cad` file saved by the **pre-Unicode** build and one saved by the **current** build. With both in hand the sniff can be verified against real bytes instead of reasoned about. If those exist, point me at them and this becomes a contained, testable change.

Two things to do before trusting the branch: build it, and run the FastMM check in Appendix B. The DXF group deserves a round-trip against a real file — import, export, re-import — because six of its changes touch the parser.

## Appendix A — Suggested sequencing

**Phase 1, no design risk.** M1, M5, M6, M12, M14, P4, P6, X1, X2, X6, and the small verified items (the `Z` typo, the two bounds checks, the DXF `SetTextBuf`, `FreeAndNil(Result)` in `ReadPolyline2D`, the `RestoreLayers` brush leak at `14538-14557`). All are local, each is testable in isolation, and together they remove most of the active corruption.

**Phase 2, needs a decision but not a redesign.** M2 (index widening), M3 + the `DeleteAllSourceBlocks` rework, M4 (shared `RequireParam`), M11, X3 + X4 (file-format versioning — decide once whether to restore the old layout or bump the version), P2, P3, P9, P12.

**Phase 3, real design work.** M7/M8/A3 together — the param ownership contract should be settled as one change, not three. M10 (thread safety). P1 (cull rect threaded through `DrawObject`). P10 (ID index). P7 (de Boor).

**Phase 4, opportunistic.** S1, S2, S3 — pick these up while touching the surrounding code rather than as standalone refactors.

## Appendix B — What needs a regression test before it changes

Four of the fixes above change observable output or on-disk bytes. Each wants a before/after comparison captured first:

1. **X3, X4** — file format. Save a drawing containing text, source blocks and the version header with the current build; confirm the fixed build reads it, and decide explicitly whether old files must still load.
2. **P7, P8** — curve geometry. Render a page of splines, arcs and ellipses to a bitmap and pixel-diff. Adaptive segment counts also change `stSpace` stream output.
3. **M13** — `ExplodeContainer` goes from emitting blank shapes to real ones. Capture what current callers actually receive.
4. **M7, M8, A3** — param lifetime. A test that starts an operation, suspends it, cancels the transient one, resumes, and ends normally will catch both the leak and the double-free; neither shows up in a simple happy-path run.

FastMM4 in full-debug mode, with `LogMemoryLeakDetailToFile` on, is the fastest way to confirm section 1 — most of those findings surface as a named class in the leak report within one interactive session.
