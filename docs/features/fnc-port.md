# CADSys → TMS FNC port

Working copy: `delphi_libraries\CadSysFNC` (copied from `CADSys42`, branch `fix/phase1-memory-and-portability`).

## Plan

| Step | What | State |
|---|---|---|
| 1 | DUnitX suite compiling and green on VCL | **done** - 477 pass, 0 fail, 8 ignored; the FNC suite 20/20 |
| 2 | Drawing layer: shapes draw through a backend, not a `TCanvas` | **done** - both backends compiled and under test |
| 2b | Persistence: JSON instead of binary `TStream` (see `json-persistence.md`) | **done** |
| 2c | Colours carry alpha (`TCADColor` = `$AARRGGBB`); `TLayer` drops the VCL pen and brush | **done** |
| 3 | Remove the rest of the Windows-only code: `TLOGFONT`/`HFONT` in `TExtendedFont`, `TBitmap` in `TBitmap2D`, `WinAPI.Windows` uses | **done** |
| 4a | Drop `TPaintingThread`; replace XOR rubber-banding with a redrawn overlay | **done** |
| 4b-1 | `TFNCCADViewport` on `TTMSFNCCustomControl`, painting in `Draw` | **done** |
| 4b-2 | Input: replace the CAD program's HWND subclassing with FNC's `Handle*` virtuals | **done** |
| 4b-3 | `TFNCRuler` on `TTMSFNCCustomControl`; `Size` renamed `Thickness` | **done** |
| 5a | Decouple the rest of the UI: `ShowMessage`, `TCriticalSection`, the `TCanvas` parameters on `ClearCanvas` / `CopyToCanvas` / `DrawGrid` | **done** |
| 5b | `FNCCS4ExportVCL`: printing, clipboard and calibration as a VCL-only companion | **done** |
| 5c | `FNCCS4DXFModule` framework-free: `TProgressBar` becomes an event, the palette becomes `TCADColor` | **done** |
| 5d | `CADSys.inc` platform defines; conditional uses clauses; the back buffer per framework | **done** on VCL, unbuilt on FMX and LCL |
| 5e-1 | The library compiles with `CADSYS_FMX` | **done** |
| 5e-2 | An FMX demo: the library runs on FMX, not only compiles | **done** - drawing, zoom, grid, polyline and the ruler all work |
| 5e-3 | Lazarus: the `fpjson` / `base64` branches and the `.lpk` | blocked - no FNC Core for FPC installed |

## Step 2 design

```
shapes / tasks / layers ──► TDecorativeCanvas ──► TCADGraphics (FNCCS4Graphics, abstract, no VCL/FMX)
                                                    ├── TCADVCLGraphics (FNCCS4GraphicsVCL) → TCanvas / GDI
                                                    └── TCADFNCGraphics (FNCCS4GraphicsFNC) → TTMSFNCGraphics
```

* `FNCCS4Graphics` has no VCL, FMX or Windows dependency. Pen/brush enums mirror the VCL ones in the same ordinal order with a `c` prefix (`cpsDot`, `cpmXor`, `cbsSolid`), colours are `TCADColor` (`cadclRed` …, see *Colours carry alpha*), text flags equal the `DT_` values (`CAD_DT_CALCRECT` …).
* `TDecorativeCanvas` keeps its name and API. New: `Graphics`, `Pen`, `Brush`, `ClipRect`, `Polygon`, and `Create(AGraphics, AOwnsGraphics)`. `Create(TCanvas)` still works and builds a VCL backend. `Canvas` is now read-only and returns `nil` for non-VCL backends (transitional).
* The VCL backend reads/writes pen and brush straight on the `TCanvas`, so code that still touches the canvas (viewport internals) and code that goes through the layer can never disagree. GDI calls are the same as before → pixel-identical output.
* `TDecorativePen` methods now take a `TCADGraphics` instead of a `TCanvas` (public API change for anyone calling them directly).
* `AssignVCLPen` / `AssignVCLBrush` bridge the VCL `TPen`/`TBrush` still owned by the viewports (`RubberPen`). `TLayer` no longer needs them (2c); they go away with step 4.

### Call sites migrated

* **FNCCS4Shapes**: all `Cnv.Canvas.*` gone. `TText2D` selects its font through `Graphics.SelectFont(fExtFont.Spec)`; `TBitmap2D` uses `Graphics.DrawImage`.
* **FNCCS4Tasks**: on-screen rubber-band drawing goes through `OnScreenCanvas.Pen/Graphics`.
* **FNCCADSys4**: polygon helpers, place-holders, XOR checks, `TLayer.SetCanvas`, saved canvas state (now `TCADGraphicsState`), control-point and rubber drawing in both viewports.
* Still on `TCanvas` (step 4): the viewport off-screen bitmap, grid, clear, ruler, `CopyToCanvas`, `DrawAx`, printing metrics.

### Side effects worth knowing

* **P4 partly fixed**: the VCL backend caches the `HFONT` and rebuilds it only when the font description changes. (`TExtendedFont` itself still recreates its own handle when `Height` is set; that goes in step 3.)
* **Latent text bug fixed**: `TText2D.fText` is an `AnsiString` but was passed as `PChar(fText)` to `DrawText`, which in Unicode Delphi hands GDI the ANSI bytes as UTF-16. The text now goes through a proper `string` conversion.

## FNC backend (`FNCCS4GraphicsFNC`) — known differences

* No raster operations: any pen mode other than `cpmCopy` draws in `XorColor`. XOR rubber-banding must become "redraw the overlay" (step 4).
* Hatched brushes draw solid.
* LOGFONT heights are converted to FNC sizes (points on VCL, DIPs on FMX); `Small Fonts` → `FallbackFontName` (Tahoma).
* LOGFONT escapement (CCW, 1/10°) → FNC angle (CW, degrees) — sign to be verified visually.
* Opaque text fills the whole text rectangle.
* Clip can only be narrowed (`SetClipRect`).
* VCL: `TBitmap2D` bitmaps are wrapped in a cached `TPicture` (FNC VCL draws `TPicture`). The cache is keyed on the object, so an in-place edit of the same bitmap is not picked up.
* Framework: VCL FNC by default; define `CADSYS_FMX` to compile against FMX FNC.

## Colours carry alpha

`TCADColor` is `$AARRGGBB`, not a VCL `TColor`. Convert with `TColorToCADColor` / `CADColorToTColor`, and never assign a `clXxx` constant to one directly - the byte order differs. Helpers: `CADColor(A,R,G,B)`, `CADColorAlpha`, `CADColorSetAlpha`, `CADColorIsOpaque`, `CADBlendColor`.

`TLayer` no longer owns a VCL `TPen`/`TBrush`; it owns a `TCADSimplePen` / `TCADSimpleBrush` (storage-only implementations of the drawing-layer pen and brush), so a layer colour carries its own alpha and `TLayer.SetCanvas` is a plain `Assign`. `TFNCCADCmp.DefaultLayersColor` stays published as a `TColor` so the Object Inspector keeps its colour picker.

What each backend does with the alpha:

| | |
|---|---|
| FNC | Real blending: the alpha becomes `Stroke.Opacity` / `Fill.Opacity` (and travels inside the colour on FMX). |
| VCL (GDI) | GDI has no alpha for pens and brushes, so a translucent colour is flattened onto `TCADGraphics.BlendBackground` - which the viewport sets to its background colour before each repaint. It looks right against a uniform background but does not blend with what was drawn underneath. Alpha 0 draws nothing at all. |

The CAD2D demos' layer dialog has pen and fill opacity sliders - the only place in either demo where a layer's alpha channel can be set.

### Migrating code that touches a layer

A layer's pen and brush are drawing-layer objects now, so their *styles* come from the drawing layer too - `cpsSolid`, `cpsDash`, `cbsSolid`, `cbsClear`, `cpmCopy`, `cpmXor` - not the VCL `ps*` / `bs*` / `pm*` constants. Code that still draws on a raw `TCanvas` (the XOR cursor cross, the grid, the 3D axes, the rulers, `ClearCanvas`) keeps the VCL constants; that code is step 4.

The trap is the colour: `TCADColor` is a distinct `Cardinal` type, so `Layer.Pen.Color := clRed` still *compiles* and quietly gives you `$000000FF` - alpha 0, an invisible layer. Every such call site has to go through `TColorToCADColor`, and every read that feeds a VCL control through `CADColorToTColor`. Call sites fixed when the type changed:

| Where | Was |
|---|---|
| `FNCCADSys4.TLayer.LoadFromJSON` | cast the styles to the VCL `TPenStyle` / `TPenMode` / `TBrushStyle` |
| `FNCCS4DXFModule` (2D and 3D readers) | `Pen.Color := Colors[…]` from the `TColor` DXF palette, and `Brush.Style := bsClear` |
| `FNCCS4DXFModule` (2D writer) | `ColorToIndex(Pen.Color, …)`, which takes a `TColor` |
| `Demos\CADCmpDemo` | a VCL `TBrush` passed to `SetDefaultBrush(const TCADBrush)`, plus seven `clXxx` layer colours |
| `Demos\PointsVectDemo` | set the pen through `OnScreenCanvas.Canvas` instead of the drawing layer |
| `Test\CADSys4.Tests.Structures` | `TPen` / `TBrush` locals, and `clBlack` / `psSolid` / `bsSolid` assertions |

`TFNCCADCmp.SetDefaultPen` / `SetDefaultBrush` take a `TCADPen` / `TCADBrush`; pass a `TCADSimplePen` / `TCADSimpleBrush`.

`TColorToCADColor` cannot resolve a VCL *system* colour (`clBtnFace`, `clWindow`, …) - the drawing layer has no VCL dependency, and a negative `TColor` comes out black. Call `ColorToRGB` first, as `DefaultLayersColor` now does.

## Step 3: what is left of Windows

* **`TExtendedFont`** is a font *description* over `TCADFontSpec` - no `TLOGFONT`, no `HFONT`, no `TCanvas`, no destructor. Its published properties are unchanged, so existing code still compiles; `Canvas` and `Handle` are gone, and `TFaceName` is a plain `string` rather than `string[LF_FACESIZE]`. The VCL backend builds and caches the one GDI handle in `SelectFont`.
* **`TCADImage`** (in `FNCCS4Graphics`) owns the bytes of an encoded image, reads the pixel size out of the PNG or BMP header, and offers a cache slot so a backend decodes once rather than once per repaint. `TBitmap2D` holds one; its JSON is a base64 of those same bytes, so persistence no longer round-trips through a VCL bitmap. `CADImageFromBitmap` / `CADImageToBitmap` in `FNCCS4GraphicsVCL` bridge for callers that have a `TBitmap`.
* `TBitmap2D.CopyMode` is a `LongInt` defaulting to `CAD_SRCCOPY`; `TPlanarFieldGrid3D`'s colours are `TCADColor`; the DXF colour table is `TCADColor` and `ColorToIndex` takes one.
* **`CADSysWarn` / `CADSysOnWarning`**: the library cannot open a dialog and still build on FMX and LCL, so the five `ShowMessage` calls (a missing vector font, two unsupported DXF splines, unreadable DXF blocks) now go through a hook the application sets. Nil by default, which swallows the warning.
* `FNCCS4Shapes`, `FNCCS4Tasks` and `FNCCS4DXFModule` use no `WinAPI.Windows`, `Vcl.Graphics`, `Vcl.Dialogs` or `Vcl.Forms`. What is left: `FNCCS4GraphicsVCL` (by design), `FNCCADSys4` (the viewport, step 4b) and `Vcl.ComCtrls` in the DXF module for its `TProgressBar` (step 5).

## Step 4a: the overlay replaces XOR

The rubber band, the drag frame and the cursor cross used to be drawn on the control's canvas with `Pen.Mode = pmXOr`, and erased by drawing them a second time. No backend other than GDI has raster operations, so that had to go.

What replaces it: the viewport already keeps the finished drawing in an off-screen bitmap, so *restoring* the area under the overlay is just a blit, and the overlay is painted again from scratch.

```
viewport.BeginOverlay    -> blit the back buffer over the client area,
                            set OnScreenCanvas.Rubber
   ...the caller paints its part of the overlay...
viewport.EndOverlay      -> fire OnPaintOverlay, so every other owner
                            paints its part too
```

* Calls nest; only the outermost pair restores and fires. `EndOverlay` fires the event *before* decrementing, so a handler that brackets the overlay itself nests instead of recursing.
* `TFNCCADPrg` hooks `OnPaintOverlay`: it sends `cePaint` to the current state (which is how the state's `DrawOSD` gets drawn) and then paints the cursor cross.
* `DrawCursorCross` now records the position and refreshes the overlay; `HideCursorCross` refreshes it with the cross suppressed. `TFNCCADPrg2D` / `3D` override `UpdateCursorCrossPos` and `PaintCursorCross` instead of `DrawCursorCross` / `HideCursorCross`, which are concrete on `TFNCCADPrg`.
* `DrawObject2DWithRubber`, `DrawObject3DWithRubber` and the four `DrawOSD` implementations bracket themselves, so the ~40 existing call sites did not have to change. Each one restores and repaints, which makes them idempotent - the old "call it once to erase, once to draw" pairs still produce the right picture, at the cost of one extra blit.
* `RubberPen` is a `TCADSimplePen` in `cpmCopy` mode and its colour is plain, no longer pre-XOR-ed with the background.
* The `Cnv.Pen.Mode = cpmXor` test that told a shape to draw a cheap outline is now `Cnv.Rubber`, a property of `TDecorativeCanvas` the overlay sets.
* `TPaintingThread` and `UseThread` are gone. `UsePaintingThread`, `StopRepaint` and `WaitForRepaintEnd` remain, documented as doing nothing, because the library and application code calls them in dozens of places and a `.dfm` may still store the property. `InRepainting` is a real flag again, true while `UpdateViewport` is traversing the display list. `CopingFrequency` still works.

Known cost: the overlay restores the whole client area. That is one blit from a memory DC, the same one `Paint` already does, but a mouse move with a rubber band now does three of them. Step 4b can narrow it to a dirty rectangle once painting moves into `Draw`.

## Step 4b: on TTMSFNCCustomControl

An FNC control paints only inside `Draw(AGraphics, ARect)`, and that one fact drives everything here.

* The back buffer is a `TTMSFNCBitmap` - a `TPicture` on VCL, a `TBitmap` on FMX. Either way it has a `Canvas` the GDI backend draws the display list into unchanged, and it is what `TTMSFNCGraphics.DrawBitmap` takes, so the buffer reaches the screen without a framework-specific blit. None of the shape drawing moved.
* `Draw` blits the buffer, fires `OnPaint`, then paints the overlay through the new overridable `DrawOverlay`. `Paint`, `CreateParams`, `WMEraseBkgnd` and the `csOpaque` handling are gone.
* **The overlay became invalidate-driven**, which is better than 4a: `BeginOverlay` / `EndOverlay` only count, and leaving the outermost pair asks for a paint. Repeated asks in one message cycle coalesce, so 4a's three blits per mouse move are gone. The `DrawOSD` bodies did not change - outside a paint they draw into a detached `TCADFNCGraphics` and do nothing, and `Draw` then re-runs `cePaint` for real. That is what `TCADFNCGraphics.Attach` and its `fReady` gate are for.
* The 3D axis widget moved into `DrawOverlay`; it used to be painted straight after a blit that no longer exists. `DrawAx` draws through the drawing layer now - its arrow head walked off the canvas' `PenPos`, which the layer has no equivalent for, so the position is carried explicitly.
* `TFNCRuler` paints in `Draw` too, and `SetMark` records the mark instead of drawing it. Its `Size` is renamed **`Thickness`**, because FNC publishes a `Size` of its own and that one is an object. **A form that stored `Size` on a ruler must rename that line.** Nothing in the repo does.
* The published re-declarations of `Align`, `Enabled`, `Visible`, `PopupMenu`, `Height`, `Width` and the ruler's `Color` are gone - FNC publishes all of them, so the properties still exist and old `.dfm` files still load.

### Input (4b-2)

`TFNCCADPrg` used to subclass the viewport's window with `SetWindowLongPtr` and read `WM_MOUSEMOVE`, `WM_LBUTTONDOWN`, `WM_KEYDOWN` and friends out of the message stream. There is no window to subclass on FMX or LCL, so:

* The viewport overrides FNC's `HandleMouseDown` / `HandleMouseMove` / `HandleMouseUp` / `HandleDblClick` / `HandleKeyDown` / `HandleKeyUp` and offers them as hooks - `OnCADMouseDown` and siblings, public but not published. A hook returning **False** means the CAD program consumed the event, which is what the old code expressed by not propagating the message.
* `SetLinkedViewport` attaches and detaches those hooks. `SubclassedWinProc`, `fNewWndProc`, `fOldWndProc` and the `{$IFDEF windows}` branches around them are gone.
* `OnMouseDown2D` and its siblings moved out of the VCL `MouseDown` / `MouseMove` / `MouseUp` overrides into `DoCADMouseDown` / `DoCADMouseMove` / `DoCADMouseUp`, which the `Handle*` methods call **after** the CAD program has had the event and only if it did not consume it. That restores the ordering the subclassing produced - the VCL overrides ran *before* FNC routes anything, and do not exist on FMX at all - and it is why `DisableMouseEvents` still means something.
* `DisableMouseEvents` is no longer set by the library. It was only ever set around the original window procedure call; the suppression it expressed is now structural.
* Casualty: the `TFNCCADCmp3D developed by PV :)` easter egg on Alt+Shift+right-click went with the 3D `MouseDown` override.

### Two traps worth remembering

* **`TControl.Invalidate` is not asynchronous.** It does `Perform(CM_INVALIDATE, 0, 0)`, which enters the window procedure there and then. The CAD program subclasses that window and had a `CM_INVALIDATE` case that called `ViewOnPaint`, which now asks for the overlay, which invalidates... a stack overflow on the first repaint. The case is gone, `ViewOnPaint` only chains the application's handler, and `fInDraw` is set at the very top of `Draw` so the guards can see a paint is already running.
* **`TTMSFNCCustomControlBase.Invalidate` in FNC Core 4.4 is written `begin Invalidate; end`** - genuine infinite recursion. It is inside `{$IFDEF FMXLIB}`, so VCL is unaffected and `Invalidate` there is `TControl`'s. Step 5 must not call `Invalidate` on an FNC control when building for FMX.

### Known regression

`CopingFrequency` no longer shows partial results while a large drawing is traversed: the intermediate blits became invalidates and the paints coalesce. It defaults to 0, so this only matters if you set it.

## Tests

* `Test\CADSys4.Tests.Graphics.pas` (main runner): core layer, VCL backend pixel tests, and shapes drawn through a recording backend (proves no `TCanvas` is needed).
* `Test\CADSysFNCTests.dproj` + `CADSys4.Tests.GraphicsFNC.pas`: FNC backend drawn into a `TTMSFNCGraphics` bitmap canvas. Separate runner so the main suite does not depend on FNC.
* `Test\CADSys4.Tests.DXF.pas`: the DXF fixtures, split out of the old persistence suite when that became JSON.

Added with 2c: `Alpha_IsReadAndReplaced` and `Blend_MixesTowardsTheBackground` (the helpers), `TranslucentPen_IsFlattenedOntoTheBackground` and `FullyTransparentPen_DrawsNothing` (GDI), `Pen_Alpha_BecomesStrokeOpacity`, `Brush_Alpha_BecomesFillOpacity` and `Brush_ZeroAlpha_DisablesTheFill` (FNC), and `LayerColour_WritesHexWithAlphaOnlyWhenNeeded` (JSON).

### What the first run found

The suites had never been executed before step 4a landed. Their first run was 470/485, and three of the seven failures were real bugs rather than wrong expectations:

* **Non-solid brushes were silently solid.** `Vcl.Graphics.TBrush` forces `bsSolid` whenever `Color` is assigned, and the VCL backend set the style before the colour. Broken since 2c, invisible in the demo. Colour is written first now, in both the pen and the brush.
* **A shape loaded on its own had an empty `Box`.** No constructor can compute it - `_UpdateExtension` is virtual, so a base constructor would reach a descendant whose fields are not initialised yet - and nothing did it afterwards either. `CADSysObjectFromJSON` now calls `UpdateExtension` once the object is complete. The old binary `CreateFromStream` had the same hole; it stayed hidden because `AddObject` updates the extension, so whole documents were fine and only bare shapes were not.
* **`stSpace` never actually released the curve profile.** `stTime` holds one reference on the flattened profile for the object's lifetime - that reference is the cache - and switching away never gave it back, so `PopulateCurvePoints` / `FreeCurvePoints` cycled 1-2-1 and the profile stayed pinned. `SetPrimitiveSavingType` releases it on the way out of `stTime`, in `TCurve2D` and `TCurve3D` alike. Same class of bug as the M14 note in `TSweepedOutline3D`.

The other two were the tests' fault: `TFNCCADCmp.AddObject` assigns `Obj.Layer := CurrentLayer` by design, so setting `Layer` on a loose object before adding it is overwritten.

## Step 5: three frameworks from one source

### 5a-5c: what was still UI

Four kinds of coupling were left after step 4, none of them about drawing:

| Was | Is |
|---|---|
| `ShowMessage` in twelve places in `FNCCADSys4` | `CADSysWarn`, which calls the `CADSysOnWarning` hook if a program installed one and is otherwise silent. A library has no business opening a dialog. |
| `TCriticalSection` from `System.SyncObjs` | `TCADSysCriticalSection`, a thin wrapper, so the one synchronisation primitive the library uses has a single declaration to change |
| `ClearCanvas`, `CopyRectToCanvas`, `CopyToCanvas`, `DrawGrid` taking a `TCanvas` | they take a `TDecorativeCanvas`, like everything else |
| `TCADViewport.Calibrate`, `CopyToClipboard`, and the printer-DPI half of `CalibrateMM` | moved to `FNCCS4ExportVCL`. `CalibrateMM` keeps the geometry and takes the millimetres per pixel as parameters; asking the device for them is the caller's job now |
| `FNCCS4DXFModule.PositionBar: TProgressBar` | `OnProgress: TCADProgressEvent`, throttled to one call per 256 groups |
| the DXF `Colors` palette as `TColor` | `TCADColor`, with `ColorToIndex` taking one |

`FNCCS4ExportVCL` is where the VCL-only conveniences live: `CADCalibrate`,
`CADCopyToCanvas`, `CADCopyRectToCanvas`, `CADCopyToClipboard`,
`CADCanvasMMPerPixel`. A VCL program that used the old methods changes
`View.CopyToCanvas(...)` to `CADCopyToCanvas(View, ...)` and adds the unit.
Nothing was lost, and an FMX or LCL program simply does not have them yet.

### 5d: CADSys.inc

`Sources\CADSys.inc` derives exactly one of `CADSYS_VCL`, `CADSYS_FMX` and
`CADSYS_LCL`. FPC is always LCL; Delphi defaults to VCL; an FMX build says so
by defining `CADSYS_FMX` (or TMS's own `FMXLIB`) in the project or package.
**An existing VCL project needs no change**: defining nothing keeps today's
behaviour. Every unit includes it, framework-free ones too, because FPC needs
the mode and string dialect set first.

RTL units are spelled with their scope on Delphi and without it on FPC,
explicitly. TMS FNC writes them bare everywhere and leans on Delphi's unit
scope names; that works for TMS because it ships a separate copy of each unit
per framework, but here one copy carries all three, and `Graphics` meaning
whichever of `Vcl` and `FMX` the project lists first is not a risk worth
taking.

`FNCCADSys4` no longer uses `WinAPI.Windows`, `WinAPI.Messages`,
`Vcl.Controls` or `Vcl.ClipBrd`. The last thing holding `WinAPI.Windows` was
the `RGB` macro in `HSVToRGB`. `FNCCS4BaseTypes` is now framework-free on FMX
and LCL: its only framework type was `TCanvas`, in the GDI-backend
constructor of `TDecorativeCanvas`, its getter and the `Canvas` property, and
nothing in the library used that property.

### 5d: the back buffer

The one place that genuinely differs per framework.

| | |
|---|---|
| VCL | `TTMSFNCBitmap` is a `TPicture`, and the GDI backend draws the display list straight into `Bitmap.Canvas` - no FNC layer per line. Unchanged from step 4. |
| FMX, LCL | no GDI backend exists, so a `TTMSFNCGraphics` is created over the bitmap's canvas and a `TCADFNCGraphics` drives it. The backend owns the graphics, so freeing the off-screen canvas frees the stack. |

Consequences worth knowing:

* **`CreateOffScreenCanvas` lost its `TCanvas` parameter.** There is none to
  pass on FMX, and which backend belongs on the buffer is a decision only the
  viewport can make. A descendant that overrode it reads `OffScreenBitmap`
  instead. Breaking for anyone who overrode it; nothing here did.
* `BeginOffScreenScene` / `EndOffScreenScene` are no-ops on the VCL and are
  what makes drawing into the bitmap legal elsewhere. `UpdateViewport` is now
  only that bracket around `DoUpdateViewport`, which holds the old body.
* Resizing rebuilds the FMX/LCL drawing stack rather than reattaching it: a
  resized bitmap can hand out a different canvas object, and
  `TTMSFNCGraphics` has no way to be told.

### Still open for LCL

Two things to check on the first Lazarus build, both about type identity
rather than logic:

* `FNCCS4Graphics` spells the colour hook's parameter `System.UITypes.TColor`,
  qualified. FPC does ship a `System.UITypes`, and TMS FNC's LCL units reach
  it as bare `UITypes`, so both spellings should resolve - but if the
  qualified one does not, un-qualifying it is safe: that unit uses no
  framework, so `TColor` there can only mean one thing.
* `CADResolveSystemColor` is a procedural variable, and Delphi (and FPC)
  require *identical* signatures for assignment, not merely compatible ones.
  `FNCCS4GraphicsFNC` installs an LCL resolver wrapping `Graphics.ColorToRGB`;
  if LCL's `Graphics.TColor` turns out to be a distinct type from
  `System.UITypes.TColor`, the wrapper needs casts inside it - never a change
  to the hook's own type.

FPC also has no `System.JSON` and no `System.NetEncoding`. `fpjson` spells the
same classes with a different API, and `base64` replaces the encoder.

The JSON gap is now exactly one unit wide. `FNCCS4JSON` owns every JSON method
call in the library: `JSetValue` and `JAddItem` were added for the writing side
(`AddPair` / `AddElement` on Delphi, `Add` on both counts in `fpjson`), and 19
and 13 call sites respectively moved out of `FNCCADSys4` and `FNCCS4Shapes`.
The reading side was already wrapped - `JGetArray`, `JItemObject`,
`JItemArray` - with only `TJSONArray.Count` direct, which `fpjson` also has.
What those two units still name is `TJSONObject`, `TJSONArray` and their
`Create`, all spelled identically by `fpjson`.

`TCADJSONValue` is the alias for the base class the two implementations
disagree about: `TJSONValue` on Delphi, `TJSONData` on FPC. It appears in
`JSetValue`, `JAddItem`, `JSONToText`, `JSONToStream` and `JSONToFile` - which
were leaking `TJSONValue` into the interface - and in the unit's own locals.

So writing the LCL branches is a job inside `FNCCS4JSON` alone: member
attachment, the `TJSONNumber` / `TJSONBool` constructors and accessors
(`TJSONFloatNumber`, `TJSONBoolean`, `AsFloat` on FPC), and the text
round-trip (`Format` / `ParseJSONValue` versus `FormatJSON` / `GetJSON`).

### 5e-1: what FMX actually needed

`Tools\build-fmx.cmd` compiles `Test\CADSysFMXCheck.dpr`, which links every
unit and does nothing else. Compiling before there is a form to debug keeps
the unknowns to one at a time. It gives the compiler the FMX namespaces and
not the `Vcl` ones, so a bare `Graphics` or `Controls` left in a shared uses
clause cannot quietly resolve to the VCL unit; and it writes its dcus to
their own folder, because the same unit names built with different defines
must not mix.

The whole FMX-specific surface turned out to be the viewport and the ruler.
`FNCCS4Graphics`, `FNCCS4BaseTypes`, `FNCCS4JSON`, `FNCCS4GraphicsFNC`,
`FNCCS4Shapes`, `FNCCS4Tasks` and `FNCCS4DXFModule` compiled with nothing but
the string-cast warnings the VCL build already has.

| What | Why | Now |
|---|---|---|
| `SetBounds(...: Integer); override` | FMX declares it with `Single` coordinates | `Resize; override` - the hook all three agree on, and it fires only on a real size change |
| `ClientRect`, 32 sites | FMX controls have `LocalRect: TRectF` and no `ClientRect` | `ControlRect: TRect` on the viewport and the ruler, built from `Width` and `Height` |
| `Repaint; override` | FMX's `TControl.Repaint` is not virtual | `reintroduce` on FMX. It also keeps FNC out of a loop: its FMX `Invalidate` is `Repaint`, bound inside FNC's unit to the framework method |
| `Color := clWhite` | an FNC control's `Color` is a `TTMSFNCGraphicsColor` - `TAlphaColor` on FMX | `gcWhite`, declared per flavour; reading it back goes through the new `FNCToCADColor` |
| `property OnKeyPress` | FMX has no such event; the character arrives in `OnKeyDown`'s `KeyChar` | non-FMX only |
| `clBlack` … `clGreen` | declared in `Vcl.Graphics`, not `System.UITypes` - which has the values only inside `TColors` | `cadtcBlack` … `cadtcGreen` in `FNCCS4Graphics` |
| `with fOwnerView do … fSize` | FMX's `TControl` has an `FSize`, and Pascal does not distinguish it from `fSize`, so the axis indicator's size became the control's size | the `with` is gone, replaced by a local alias |

Two of those deserve remembering.

**`cadtc*` versus `cadcl*`.** The first are `TColor` (`$00BBGGRR`, no alpha),
the second `TCADColor` (`$AARRGGBB`). The prefixes differ by more than case on
purpose: Pascal would not have told `CADclRed` from `cadclRed`, and that
mistake produces a wrong colour rather than an error.

**`with` changes meaning when a base class grows.** The `fSize` case compiled
correctly on VCL for twenty years and silently meant something else the first
time it saw FMX. The other four `with <control> do` blocks in `FNCCADSys4`
name no field that could collide, so they were left alone.

### 5e-2: what only running it could find

`Demos\CAD2D\FMX` is the FMX demo, built by the same script. Its
job is not to show the library off but to execute the FMX-specific paths on a
real window. Everything is built in code; the `.fmx` holds only the form.

It writes a step log next to the exe - what it is about to do, before it does
it - because a failure here arrives as a Windows "application error" with no
indication of where it happened. Startup exceptions are caught in the `.dpr`
and anything later goes through `Application.OnException`, so a paint that
throws does not become one modal dialog per repaint. Four bugs came out of it,
and none of them could have been found by compiling.

**`EInvalidPointer` the moment the viewport got an alignment.** `ResizeOffScreen`
resized the bitmap and *then* tore down the drawing stack. An FMX
`TBitmap.SetSize` destroys the canvas object and makes a new one, and the
`TTMSFNCGraphics` on top is still holding the old reference, so the teardown
freed an object pointing at freed memory. The stack now comes down first and
is rebuilt afterwards. A VCL `TBitmap` keeps the same `TCanvas` across a
resize, which is why this could not happen there.

**`ECanvas` at construction.** `TCADFNCGraphics.Attach` applied the clip
immediately, and on FMX that is `Canvas.IntersectClipRect` - illegal outside
`BeginScene`/`EndScene`. The back buffer's stack is built while the viewport
is being constructed, where no scene exists or can. `Attach` now only records
the rectangle; `ApplyClip` applies it, called by whoever is inside a scene.

**Toolbar buttons vanishing when clicked.** The clip was never given back. On
FMX the canvas belongs to the framework and is shared for the whole scene, so
a clip left behind silently removes everything painted *after* the control.
It does not look like a clipping bug; it looks like siblings disappearing.
`ApplyClip` now takes a canvas-only `SaveState` and `ReleaseClip` restores it
- canvas-only because the full `SaveState` also copies Fill, Stroke and Font,
and restoring those would discard the pen and brush the caller just set.
`Attach` and the destructor both release, so the existing `Attach(nil, ...)`
in the `finally` blocks balances it.

**Finishing a polyline made the whole drawing disappear.** This is the
`DrawOnAdd` path: one object drawn straight into the back buffer rather than a
full repaint. Nothing opened a scene for it - silently, which is why the log
stayed empty - and simply wrapping it in `TTMSFNCGraphics.BeginScene` would
have been worse, because FNC's FMX implementation follows `BeginScene` with
`Clear(gcNull)`: adding one object would erase every object already there. So
the scene bracket **counts** (a full repaint opens one, an incremental draw
inside it must not close it early) and on FMX calls the **canvas's own**
`BeginScene`, which does only what its name says. LCL does not clear, and
keeps the FNC call.

Two general lessons. **FMX punishes unbalanced canvas state and stale canvas
references; the VCL forgives both.** And **a silent no-op is worse than an
exception**: three of these four produced no error at all, only wrong pixels.

### The two demos are one program written twice

`Demos\CAD2D\VCL` (`CadSysVCL.dproj`) and `Demos\CAD2D\FMX`
(`CadSysFMX.dproj`) are deliberately the same program in both frameworks:
same handler names, same order, UI built in code on both sides. Diff the two
`MainFrm.pas` files and what remains is the real difference between VCL and
FMX and nothing else - around 300 lines out of 1,030, all of it uses clauses,
`Caption` versus `Text`, `Checked` versus `IsChecked`, `alClient` versus
`TAlignLayout.Client`.

That is why the VCL demo no longer has a designed form. `Unit1.dfm` was 48KB
of designer output and could not be compared with anything, so a behavioural
difference between the two demos could never be pinned on the library rather
than on the forms. `DemoLog` is shared from `Demos\common`; `DemoDlg` and
`LayersFrm` exist on both sides with the same interface, even though the VCL
implementations are one-liners, because a difference that is only spelling is
noise in every future diff.

The one substantive difference is the last section of each file: printing and
clipboard export are real on VCL and report what is missing on FMX. Same four
handler names, same menu wiring, only the bodies differ.

**A VCL trap worth remembering:** VCL orders aligned controls by their
position, not by the order they were created, and every new control starts at
`Left`/`Top` = 0 - so a run of `alLeft` buttons comes out in whatever order
the tie-break produces. FMX orders by child index. Both demos now assign an
increasing position before setting `Align`.

### Corrected: FNC Core's FMX Invalidate

An earlier note here claimed `TTMSFNCCustomControlBase.Invalidate` under
`FMXLIB` was written `begin Invalidate; end` - infinite recursion. It is not;
it is `begin Repaint; end`. The real consequence is different and milder:
every `Invalidate` on FMX is a synchronous full repaint rather than a
coalesced request, so the overlay will be slower there than on VCL. Worth
revisiting, not a landmine.

### A trap that cost a build

A brace comment does not nest, so a directive quoted in prose inside one -
`{`&#36;`IFDEF CADSYS_VCL}` in a header comment explaining when to use it -
ends the comment at its own closing brace and turns the rest into code.
`CADSys.inc` did exactly this, and since every unit includes it the failure
would have been everywhere at once and pointed nowhere near the cause.
`Tools\check-comments.py` lexes the way Delphi does and flags it; run it
before a build if you have been writing documentation comments.

## Build loop

`Tools\build-and-test.cmd [BDSVER]` (default `23.0` = Delphi 12) builds the package into `Tools\build` (the installed `FNCCadSysVCL.bpl` is left alone) and the test runner, runs the tests, and writes `Tools\logs\build.log`, `test.log`, `results.xml`; then builds and runs the FNC runner (`build-fnc.log`, `test-fnc.log`).

Everything that the IDE could see twice is renamed, so the package installs next to the original `CADSys4Lite`:

| Was | Is |
|---|---|
| `CADSys4`, `CS4BaseTypes`, `CS4Shapes`, `CS4Tasks`, `CS4DXFModule`, `CS4Graphics`, `CS4GraphicsVCL`, `CS4GraphicsFNC`, `CS4JSON` | the same with an `FNC` prefix: `FNCCADSys4`, `FNCCS4BaseTypes`, … |
| `CADSysRegister.pas` | `FNCCadSysRegister.pas` |
| Lazarus `cadsysreg.pas`, `cadsys.dcr` | `FNCCadSysReg.pas`, `FNCCadSys.dcr` |
| `TCADCmp(2D/3D)`, `TCADViewport(2D/3D)`, the three 3D viewports, `TCADPrg(2D/3D)`, `TRuler` | `TFNCCADCmp…`, `TFNCCADViewport…`, `TFNCCADPrg…`, `TFNCRuler` |
| palette page `CadSys4` / `CADSys 4.2` | `FNCCadSys` |

Only the registered components were renamed; shape classes such as `TLine2D` keep their names, which is safe because they live in differently named units and are not registered with the IDE. The `CADSysRegisterClass` / `CADSysRegisterFont` routines also keep their names - only the unit around them changed. The demo `.dfm` files were patched to the new component class names.

The component bitmaps in `FNCCadSys.dcr` are still keyed to the old class names, so the palette will show default icons until the resource is rebuilt.

The Delphi package is `Packages\delphi\FNCCadSysVCL.dpk` (was `CADSys4Lite`, then `FNCCADSys` until the FMX package arrived and the name had to say which framework it was) and the Lazarus one `Packages\Lazarus\FNCCADSys.lpk` (was `cadsys`, package unit `FNCCADSys.pas`, registration unit still `cadsysreg.pas`). The Lazarus package lists the new units. After 5d the sources no longer name `WinAPI.Windows` or a `Vcl.` unit outside a `CADSYS_VCL` branch, so what is left before Lazarus can be attempted is 5e - the package file itself, and the `fpjson` / `base64` gaps above.

`FNCCS4GraphicsVCL` and `FNCCS4ExportVCL` are VCL-only by construction and belong in the VCL package alone; the FMX and LCL packages must not list them.
