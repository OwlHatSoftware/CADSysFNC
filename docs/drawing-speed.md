# Drawing speed

Two things the screen does to stay quick with a large drawing. Both apply to the
viewport only. A print, a PDF, the clipboard and `CopyToCanvas` draw every object
at full quality whatever the window is doing.

The CAD2D demos have a test drawing and a benchmark for measuring them:
**View → Generate test drawing...** and **View → Benchmark (log)**.

## Objects smaller than a pixel

```pascal
property TFNCCADViewport2D.SmallObjectMode: TCADSmallObjectMode;  { somDot }
property TFNCCADViewport2D.SmallObjectPixels: TRealType;          { 1.0 }
function TObject2D.CullWhenSmall: Boolean; virtual;               { True }
function CADIsSubPixel(const ABox: TRect2D;
  const APxPerUnitX, APxPerUnitY, AThreshold: TRealType): Boolean;
```

At zoom-all on a large drawing most objects are smaller than a pixel, and drawing
each one in full was most of the cost of a repaint. An object whose box is under
`SmallObjectPixels` on **both** axes is drawn according to `SmallObjectMode`:

| mode | on screen |
|---|---|
| `somDot` (default) | one pixel in the layer's pen colour, at the box centre |
| `somSkip` | nothing |
| `somDraw` | the whole object, as before |

`somDot` costs a little more than skipping and keeps a dense cluster visible;
skipping it would vanish at zoom-all. A long thin line is under a pixel one way
only, so it is still drawn. Picking is not affected: an object drawn as a dot can
still be picked by aiming at it.

Override `CullWhenSmall` to return `False` for a shape whose box does not say how
big it looks, such as a marker drawn the same number of pixels across at every
zoom. The sheet viewport handle does this, so it stays reachable however far out
the sheet is.

Measured with the demo benchmark, 100,000 objects:

| | before | dot | skip |
|---|---|---|---|
| VCL, repaint at zoom-all | 265 ms | 190 ms | 150 ms |
| FMX, repaint at zoom-all | 549 ms | 209 ms | 152 ms |

## Pan and zoom from the picture already drawn

```pascal
procedure TFNCCADViewport.BeginViewChange;
procedure TFNCCADViewport.EndViewChange;
function  TFNCCADViewport.InViewChange: Boolean;
procedure TFNCCADViewport.FlushViewChange;
property  TFNCCADViewport.ViewChangeSettleMS: Integer;   { 150 }
```

Inside a view change, a pan or zoom does not redraw the drawing. The control
shows the picture it already has, moved and stretched to the new view, with
what comes into view at the edges filled with the background. The overlay
(selections, handles, the rubber band) is drawn live on top, through the new
mapping, so it stays on its objects. When the change ends the drawing is redrawn
once.

- **A gesture** brackets itself. `TCADPrgRealTimePan` opens a change on mouse-down
  and closes it on mouse-up, cancel, accept or stop, so a drag costs one redraw.
- **A change nobody brackets**, such as a wheel step or a zoom click, opens one
  that a timer closes after `ViewChangeSettleMS` milliseconds without another
  change. A run of wheel steps costs one redraw, at the end. Set it to 0 to redraw
  on every change, as the library always did.
- **Some changes still redraw at once**: a resize, and a change between model and
  sheet, because the old picture has nothing to stretch. Anything that redraws
  the drawing (`Repaint`, a load, a change of content) also redraws it at once,
  mid-change or not. `RedrawObject` (`DrawOnAdd`) redraws the whole buffer rather
  than add one object to a picture drawn for another view.
- **`FlushViewChange`** redraws now if the view has moved, without closing
  anything. It is for code that is about to read the back buffer.

During the change a zoom looks soft or blocky until it settles. That is the
trade, and the same one a map viewer makes.

Measured with the demo benchmark, 100,000 objects, VCL: 50 pan steps redrawing
each time take about 7.3 s; the same 50 as one view change take 89 ms, the
final redraw included.
