# Migrating from CADSys 4.2

This is the list of everything an existing CADSys 4.2 program has to change, and
why. The shape hierarchy, the geometry, the display list and the interaction
model are unchanged — if your code builds shapes, walks the display list or
writes `TCADState` descendants, most of it will compile untouched. What changed
is the layer between the library and the framework.

Read it in this order: the first two sections affect every program, the rest only
if you used the feature.

---

## 1. Unit names

Every unit gained an `FNC` stem and a framework prefix:

| CADSys 4.2 | CADSysFNC (VCL) | on FMX |
|---|---|---|
| `CADSys4` | `VCL.FNCCADSys4` | `FMX.FNCCADSys4` |
| `CS4BaseTypes` | `VCL.FNCCS4BaseTypes` | `FMX.FNCCS4BaseTypes` |
| `CS4Shapes` | `VCL.FNCCS4Shapes` | `FMX.FNCCS4Shapes` |
| `CS4Tasks` | `VCL.FNCCS4Tasks` | `FMX.FNCCS4Tasks` |
| `CS4DXFModule` | `VCL.FNCCS4DXFModule` | `FMX.FNCCS4DXFModule` |
| `CADSysRegister` | `VCL.FNCCadSysRegister` | `FMX.FNCCadSysRegister` |

New units with no 4.2 counterpart: `FNCCS4Graphics` (the drawing layer),
`FNCCS4GraphicsVCL` and `FNCCS4GraphicsFNC` (its two backends), `FNCCS4JSON`,
`FNCCS4Legacy`, `FNCCS4Views`, `FNCCS4ExportVCL`, `FNCCS4Paper`,
`FNCCS4Print`, `FNCCS4Preview` and `FNCCS4PDF`.

`Sources` holds one master copy, named `VCL.*`; `Tools\gen-units.cmd` writes the
`FMX.*` and `LCL*` copies. The framework is a property of the *tree* you compile
against, not of a define your project sets — so a project cannot accidentally
select the wrong one.

**`FNCCadSysRegister` must be in your program's uses clause**, not just in the
package. Its `initialization` fills the class registry, and without it
`LoadFromFile` has no class to map a stored shape onto.

## 2. Component class names

| Was | Is |
|---|---|
| `TCADCmp2D`, `TCADCmp3D` | `TFNCCADCmp2D`, `TFNCCADCmp3D` |
| `TCADViewport2D`, `TCADViewport3D` (and the three 3D viewports) | `TFNCCADViewport…` |
| `TCADPrg2D`, `TCADPrg3D` | `TFNCCADPrg2D`, `TFNCCADPrg3D` |
| `TRuler` | `TFNCRuler` |
| palette page `CadSys4` / `CADSys 4.2` | `FNCCadSys` |

Shape classes keep their names — `TLine2D` is still `TLine2D` — because they live
in differently-named units and are not registered with the IDE. A `.dfm` that
carries one of the renamed components has to be edited; shapes in a saved drawing
are unaffected.

On FMX, `TFNCCADCmp` and `TFNCCADPrg` descend from `TFmxObject` rather than
`TComponent`. That is what lets the IDE tell the two frameworks' copies apart so
both palettes can be installed at once. They are still `TComponent` descendants
either way, so nothing you write against them changes.

## 3. The file format is JSON

`SaveToFile` and `LoadFromFile` keep their signatures and now read and write JSON
(UTF-8, no BOM). See [json-format.md](json-format.md) for the document shape.

**Existing binary drawings still load**, through `FNCCS4Legacy`:

```pascal
uses VCL.FNCCS4Legacy;

fCAD.LoadLegacyFile('old-drawing.CS2');
fCAD.SaveToFile('new-drawing.json');
```

Per-object persistence changed shape: `SaveToStream(Stream)` became
`SaveToJSON(AJSON: TJSONObject)` and `CreateFromStream(Stream, Version)` became
`CreateFromJSON(AJSON: TJSONObject)`. **If you wrote your own shape class, this
is the one place you have real work to do** — the two methods have to be
rewritten, and `TBadVersionEvent` now hands you a version *string* rather than a
stream.

Vector fonts are JSON too. The old `.fnt` files can no longer be read;
`RomanC.json` and `Monotxt.json` in `Demos\CAD2D\data` are converted copies.

## 4. Colours carry alpha

`TCADColor` is `$AARRGGBB` and is a distinct type from the VCL's `TColor`
(`$00BBGGRR`). Layers, pens and brushes use it.

**The trap:** `Layer.Pen.Color := clRed` still *compiles* and quietly gives you
`$000000FF` — alpha 0, an invisible layer. Convert explicitly:

```pascal
Layer.Pen.Color := TColorToCADColor(clRed);
SomeVCLControl.Color := CADColorToTColor(Layer.Pen.Color);
```

`TColorToCADColor` cannot resolve a VCL *system* colour (`clBtnFace`,
`clWindow`, …) — the drawing layer has no VCL dependency — so call `ColorToRGB`
on one first.

Pen and brush styles come from the drawing layer now, not the VCL: `cpsSolid`,
`cpsDash`, `cbsSolid`, `cbsClear`, `cpmCopy`, `cpmXor` in place of `ps*`, `bs*`
and `pm*`. `TLayer` owns a `TCADSimplePen` / `TCADSimpleBrush` rather than a VCL
`TPen` / `TBrush`, so `TFNCCADCmp.SetDefaultPen` and `SetDefaultBrush` take those.

`TFNCCADCmp.DefaultLayersColor` stays a `TColor`, so the Object Inspector keeps
its colour picker.

On the VCL backend a translucent colour is flattened onto
`TCADGraphics.BlendBackground`, which the viewport sets to its own background
before each repaint: right against a uniform background, not a real blend with
what is underneath. GDI has no alpha for pens and brushes. The FNC backend blends
properly.

## 5. Drawing goes through a backend

`TDecorativeCanvas` keeps its name and most of its API, but it now wraps a
`TCADGraphics` rather than a `TCanvas`. `TDecorativeCanvas.Canvas` is read-only
and returns `nil` for anything but the VCL backend; the `Create(TCanvas)`
overload is VCL-only. `TDecorativePen`'s methods take a `TCADGraphics`.

`ClearCanvas`, `CopyRectToCanvas`, `CopyToCanvas` and `DrawGrid` take a
`TDecorativeCanvas` instead of a `TCanvas`.

**Hatched fills are drawn by the library**, line by line, because
`TTMSFNCGraphics` cannot hatch a non-rectangular shape at all. The lines sit on a
grid anchored to the coordinate origin, so two shapes that touch have hatching
that lines up — but an *opaque* hatch no longer fills the gaps between its lines.

## 6. What moved to `FNCCS4ExportVCL`

Printing, clipboard and calibration are VCL-only and live in their own unit as
free functions:

| Was | Is |
|---|---|
| `View.Calibrate(…)` | `CADCalibrate(View, …)` |
| `View.CopyToCanvas(…)` | `CADCopyToCanvas(View, …)` |
| `View.CopyRectToCanvas(…)` | `CADCopyRectToCanvas(View, …)` |
| `View.CopyToClipboard(…)` | `CADCopyToClipboard(View, …)` |

`CalibrateMM` keeps the geometry but takes the millimetres per pixel as
parameters; asking the device for them is the caller's job.

An FMX program simply does not have these yet.

## 7. Painting, input and threads

* **`TPaintingThread` is gone.** `UsePaintingThread`, `StopRepaint` and
  `WaitForRepaintEnd` still exist and do nothing, so old code compiles.
  `CopingFrequency` still works but no longer shows partial results during a long
  repaint — the intermediate blits became invalidates, and those coalesce.
* **XOR rubber-banding is gone**, replaced by an overlay that is restored from
  the back buffer and repainted. No backend but GDI has raster operations. The
  ~40 call sites in the library bracket themselves, so shape and task code did
  not change.
* **The CAD program no longer subclasses the viewport's window.** Input arrives
  through FNC's `HandleMouseDown` / `HandleMouseMove` / `HandleKeyDown` virtuals,
  offered as the public hooks `OnCADMouseDown` and siblings. A hook returning
  `False` means the CAD program consumed the event. `DisableMouseEvents` is no
  longer set by the library.
* **`CreateOffScreenCanvas` takes no parameter.** If you overrode it, read
  `OffScreenBitmap` instead.
* Casualty: the `TCADCmp3D developed by PV :)` easter egg on Alt+Shift+right-click.

## 8. The ruler

* **`Size` is now `Thickness`** — FNC publishes a `Size` of its own, and it is an
  object. A `.dfm` that stored `Size` on a ruler has to be edited.
* On a *vertical* ruler `Thickness` is a **floor**, not the width: the ruler
  measures its own labels and widens itself if they do not fit.
* `FontSize` defaults to 0, meaning "follow the control's `Font`" on VCL and LCL,
  and 8pt logical on FMX — there is no control font on FMX.
* `TFNCRuler` does not use FNC's `PaintScaleFactor`; it carries `RulerScale` and
  advances it itself, because Windows reports the *old* monitor's DPI while a
  window is being dragged between displays.

## 9. Printing, paper and sheets — all new

None of this existed in 4.2, so there is nothing to migrate; it is here
because it is where the paper types live and one of them moved.

* **`FNCCS4Print`** is the page model: `TCADPageSetup` (a record), and
  `CADDrawPage`, which is the only routine that renders a page. The preview
  control, the printer and the PDF writer all call it.
* **`FNCCS4Paper`** holds the paper itself — `TCADPaperKind`,
  `TCADPageOrientation`, `TCADPageMargins`, `TCADPageDevice`, `CADMMPerInch`.
  It was part of `FNCCS4Print` until sheets arrived: a sheet belongs to the
  drawing, and `FNCCADSys4` cannot use the unit that uses it. **`FNCCS4Print`
  repeats every one of those names as an alias and forwards `CADPaperSizeMM`
  and `CADPaperKindName`**, so code that only prints needs no change. Code that
  wants the paper without the page model can use `FNCCS4Paper` alone.
* **`TFNCPrintPreview`** (`FNCCS4Preview`) is an FNC control, on the palette,
  VCL and FMX. **`CADPrintPages`** (`FNCCS4ExportVCL`) prints; **`CADSavePagesToPDF`**
  (`FNCCS4PDF`) writes a PDF on all three frameworks.
* **Sheets** — paper space — live on the drawing: `TFNCCADCmp.Sheets`, saved as
  a `sheets` array beside `layers` and `objects`. A drawing with no sheets
  writes no `sheets` member, so a file written before they existed is
  unchanged by a load and save.

  A sheet's own objects are ordinary `TObject2D` **in millimetres of paper**,
  origin at the bottom-left corner, Y upwards as in the model — so a title
  block is shapes, and the shape library, the fonts and the DXF import work on
  a sheet unchanged. Each `TCADSheetViewport` is a rectangle in those
  millimetres showing a window of the model at its own `UnitsPerMM`, or 0 to
  fit. `CADDrawSheet` draws one; `CADPrintSheets` and `CADSaveSheetsToPDF`
  print and export them.

* **`TCADGraphics.PushClip` / `PopClip` nest.** They were one level deep when
  printing introduced them. Each rectangle is intersected with the one already
  in force before a backend sees it, which matters because the backends
  disagree: GDI's `IntersectClipRect` narrows the clip and FNC's `ClipRect`
  replaces it. A backend of your own that can clip should override
  `DoPushClip` / `DoPopClip` and may assume the rectangle it is handed is
  already inside whatever it had; one that cannot clip inherits a pair that do
  nothing, and overflows visibly rather than being silently wrong somewhere
  else.

## 10. Smaller things

* `TExtendedFont` is a font *description* now: no `Canvas`, no `Handle`, no
  `TLOGFONT`. Its published properties are unchanged and `TFaceName` is a plain
  `string`.
* `TBitmap2D` holds a `TCADImage` (the encoded bytes) rather than a VCL
  `TBitmap`. `CADImageFromBitmap` / `CADImageToBitmap` in `FNCCS4GraphicsVCL`
  bridge if you have one.
* `TCADViewport.ControlRect: TRect` replaces `ClientRect`, which FMX controls do
  not have. **On FMX it returns device pixels**; `ControlRect(cruLogical)` is the
  old meaning.
* `FNCCS4DXFModule.PositionBar: TProgressBar` became the `OnProgress` event,
  throttled to one call per 256 groups. The DXF colour palette is `TCADColor`.
* The library never opens a dialog. The twelve `ShowMessage` calls became
  `CADSysWarn`, which calls the `CADSysOnWarning` hook if you install one and is
  otherwise silent. **Install one** if you want to hear about a missing vector
  font or an unsupported DXF entity.
* `CADSysJSONFormat` and `CADSysJSONVersion` live in `FNCCS4JSON` and are
  re-declared in `FNCCADSys4`, so either uses clause reaches them.
* **Snap is not the grid.** `XSnap` / `YSnap` are independent of `GridDeltaX` /
  `GridDeltaY`; set finer than the grid and snapping looks like it does nothing.
  That one is unchanged from 4.2, but it catches everybody.

---

## If you are writing your own shape class

Two things to know beyond the JSON rewrite in §3:

* **`TGraphicObject.Create(ID)` is not virtual**, so an instance the registry
  builds has only the base constructor run. Any field your class adds has to be
  guarded in `Assign`.
* A shape loaded on its own has no `Box` until something calls
  `UpdateExtension` — no constructor can compute it, because `_UpdateExtension`
  is virtual and a base constructor would reach a descendant whose fields are not
  initialised yet. `CADSysObjectFromJSON` does it for you; if you build an object
  by hand, you do it.
