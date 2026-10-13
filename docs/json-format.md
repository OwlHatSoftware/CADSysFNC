# The CADSysFNC document format

Drawings, block libraries and vector fonts are JSON documents. CADSys 4.2's
binary `TStream` format is no longer what `SaveToFile` writes; it can still be
**read**, for migration, through `FNCCS4Legacy` (`LoadLegacyFile`,
`LoadLegacyStream`).

The text is UTF-8 without a BOM. Everything in this document is stable: a reader
may rely on the member names below.

## Document shapes

```jsonc
{
  "format": "cadsys-json",     // always; a file without it is rejected
  "version": "5.0",            // CADSysJSONVersion
  "kind": "drawing",           // "drawing" | "library" | "font"
  "layers":  [ ... ],          // only layers whose Modified flag is set
  "blocks":  [ ... ],          // source blocks (a library holds only these)
  "objectCount": 12,           // how many objects follow; for progress while streaming
  "objects": [ ... ]           // the display list
}
```

An object carries its class name, which is how the registry rebuilds it:

```jsonc
{
  "type": "TLine2D",           // CADSysFindClassByName
  "id": 12,
  "layer": 3,
  "visible": false,            // written only when not the default
  "transform": [ 1,0,0, 0,1,0, 0,0,1 ],   // only when the object has one
  "points": [ [0,0], [10,5] ], // [x, y] or [x, y, w] when w <> 1
  "growing": true
}
```

Conventions: 3D points are `[x, y, z]` (plus `w` when it is not 1), vectors are `[x, y, z]`, transforms are flat arrays in row order (9 numbers for 2D, 16 for 3D), enumerated values are written as names (`"savingType": "space"`, `"direction": "counterClockwise"`), colours as `#RRGGBB` while opaque and `#AARRGGBB` once they are not, and `TBitmap2D` images as a base64 PNG in `"bitmap"`.

A layer carries its pen and brush, whose styles are the drawing-layer names (`"solid"`, `"dash"`, `"clear"`, …) and whose colours follow the rule above, so a translucent layer round-trips its alpha:

```jsonc
{
  "index": 4,
  "name": "GHOST",
  "pen":   { "color": "#80FF0000", "width": 1, "style": "solid", "mode": "copy" },
  "brush": { "color": "#FFFFFF", "style": "solid" },
  "pattern": "1100",          // the decorative pen, when it has one
  "active": true, "visible": true, "opaque": false, "streamable": true
}
```

Reading is lenient: a missing member takes its default, an unknown enum name falls back to the default. A structurally wrong file (a member that must be an object or array and is not) raises `ECADJSONError`; a wrong `format`, `kind` or `version` raises `ECADFileNotValid`.

## Sheets and named views

A drawing with paper space carries two more top-level arrays, each written only
when it has something in it:

```jsonc
{
  "kind": "drawing",
  ...
  "sheets": [ {
    "name": "Sheet 1",
    "paper": "A3", "orientation": "landscape",
    "marginLeftMM": 10, "marginTopMM": 10, "marginRightMM": 10, "marginBottomMM": 10,
    "viewports": [ {
      "name": "Detail 1",
      "min": [20, 177], "max": [140, 277],   // the rectangle on the paper, mm
      "unitsPerMM": 0,                       // 0 fits the view to the rectangle
      "border": true,
      "view": { "kind": "view", ... },       // always written - see below
      "viewLink": "{8F1C...}"                // only when linked to a named view
    } ],
    "objects": [ ... ]                       // the sheet's own objects, in mm
  } ],
  "views": [ {
    "id": "{8F1C...}",                       // GUID; what viewLink refers to
    "view": { "kind": "view", "name": "Detail 1", "min": [..], "max": [..], ... }
  } ]
}
```

A linked viewport's `view` is a copy of the named view as it was when the file
was written, so a reader that ignores `viewLink` and `views` shows the same
thing. A `viewLink` that matches no `views` entry is not an error: the viewport
falls back to its `view`. Reading a `views` entry whose `id` is already present
(a drawing merged into itself) skips it.

## API

| Was | Is |
|---|---|
| `TGraphicObject.SaveToStream(Stream)` | `SaveToJSON(AJSON: TJSONObject)` |
| `TGraphicObjectClass.CreateFromStream(Stream, Version)` | `CreateFromJSON(AJSON: TJSONObject)` |
| class index word in the file | `"type"` with the class name; `CADSysObjectToJSON` / `CADSysObjectFromJSON` wrap the two sides |
| `TLayer.SaveToStream` / `LoadFromStream` | `SaveToJSON(AJSON)` / `LoadFromJSON(AJSON)` |
| `TLayers.SaveToStream` / `LoadFromStream` | `function SaveToJSON: TJSONArray` / `LoadFromJSON(AJSON: TJSONArray)` |
| `TFNCCADCmp.Save/LoadObjectsToStream`, `Save/LoadBlocksToStream` | `Save/LoadObjectsToJSON`, `Save/LoadBlocksToJSON`, all taking a `TJSONArray` |
| `TBadVersionEvent(..., Stream, var Resume)` | `TBadVersionEvent(..., const FileVersion: String; var Resume)`; `TBadVersionExEvent` is gone |

`TFNCCADCmp` keeps `SaveToFile`, `LoadFromFile`, `MergeFromFile`, `SaveToStream`, `LoadFromStream`, `MergeFromStream`, `SaveLibrary` and `LoadLibrary` with their old signatures — they now read and write JSON text (UTF-8, no BOM). New alongside them: `SaveToJSON`, `LoadFromJSON`, `MergeFromJSON`, `SaveLibraryToJSON`, `LoadLibraryFromJSON`, `SaveToJSONString`, `LoadFromJSONString`.

`FNCCS4JSON.pas` holds the conversion helpers (`JGetStr`, `JSetReal`, `Point2DToJSON`, `JGetTransf3D`, `JSONFromFile`, …). It uses `System.JSON` and no UI framework.

`TCADVersion`, `CADSysVersion` and `TFNCCADCmp.Version` still exist but no longer drive file I/O; the JSON header carries the format version.

## Streaming a drawing

`SaveToJSON` and `LoadFromJSON` work on a complete `System.JSON` tree. For a
large drawing that tree is most of the cost: a hundred thousand lines are
millions of `TJSONValue` objects, held all at once. The streaming pair writes
and reads the same document one object at a time (Delphi only; the LCL tree has
no streaming reader):

```pascal
procedure TFNCCADCmp.SaveToJSONWriter(const AWriter: TJsonWriter);
procedure TFNCCADCmp.LoadFromJSONReader(const AReader: TJsonReader);
procedure TFNCCADCmp.MergeFromJSONReader(const AReader: TJsonReader);
```

- **Same document.** The writer produces the members `SaveToJSON` builds, in the
  same order and with the same values. A number is written as the text the tree
  holds for it, so not even the last digit differs. Each object still saves itself
  through its own `SaveToJSON` into a small tree that is written and freed before
  the next, so an application's own classes need nothing new.
- **One value, inside anything.** The writer writes the drawing where a value is
  expected, and the reader starts on the drawing's `StartObject` (or before the
  first token) and stops on its `EndObject`. An application can put the drawing
  inside a document of its own, with members before and after it.
- **Order matters when reading.** A stream cannot go back, so the header
  (`format`, `version`, `kind`) must come before the content, and `blocks` before
  `objects`. Anything this library writes is in that order; anything else raises
  `ECADFileNotValid`. Members the reader does not know are skipped.
- **Progress** comes from `objectCount`. A document written before that member
  existed still loads, and reports 100 once it has finished.
- **Dates.** A `TJsonTextReader` with `DateParseHandling` set to `DateTime` would
  turn a sheet called `2026-10-12` into a date. The loader sets it to `None` for
  as long as it reads and puts it back afterwards.

`FNCCS4JSON` has the two bridges, for anyone streaming documents of their own:
`JWriteValue(Writer, Value)` writes a tree to a writer, and `JReadValue(Reader)`
builds a tree from the value the reader is on.

## Choosing the class an object is loaded as

```pascal
TCADMapObjectClassEvent = procedure(Sender: TObject; const ATypeName: String;
  var AClass: TGraphicObjectClass) of object;

property TFNCCADCmp.OnMapObjectClass: TCADMapObjectClassEvent;
property TDXF2DImport.OnMapObjectClass: TCADMapObjectClassEvent;
```

Called for every object created while a drawing loads, by any of the load methods,
tree or streaming. That includes source blocks and what is inside them, a
container's children and every sheet's own objects. `AClass` arrives as the
registered class of that name, or nil when none is registered. The handler may
replace it, typically with a descendant of its own, so a `TLine2D` in the file
comes back as the application's line without the drawing being converted
afterwards. Left nil, the object is skipped as an unknown class, as it always was.

The class is created through `CreateFromJSON`, so the replacement must read what
the stored class wrote. A descendant does.

The map lives on the thread for the duration of one load, because the objects
inside a block or a container are created by their parent's `CreateFromJSON` and
never see the drawing. `CADSysPushObjectClassMap` and `CADSysPopObjectClassMap`
are public for an application that reads objects on its own. A load nested inside
another does not inherit the outer map.

On the DXF importer the same event is called for every entity read, block contents
included. A different class has the entity recreated as that class through its
JSON. Leaving `AClass` unchanged or nil keeps the entity as read. Block instances
and containers are left alone: they hold references that a round trip would have
to resolve again.

## Fonts

Vector fonts are JSON too (`"kind": "font"`, a `chars` array of `{ "code", "vectors" }`). `CADSysRegisterFontFromFile` reads a JSON font; `CADSysSaveFontToFile` writes one. The demo fonts were converted: `RomanC.json` and `Monotxt.json` sit beside the old `.fnt` files, which the library can no longer read.

## Reading a CADSys 4.2 drawing

`FNCCS4Legacy` reads the old binary format. It is a one-way migration path, not a
supported format: load the file, then save it as JSON.

```pascal
uses VCL.FNCCS4Legacy;

fCAD.LoadLegacyFile('old-drawing.CS2');
fCAD.SaveToFile('new-drawing.json');
```

Nothing in this repository is a drawing the original library made, so the legacy
reader is covered by synthesised fixtures only. If you have a real `.CS2` that
fails to load, it is worth reporting.
