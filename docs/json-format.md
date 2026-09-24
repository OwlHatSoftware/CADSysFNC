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
