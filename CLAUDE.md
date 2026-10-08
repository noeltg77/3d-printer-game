# Print Shop Tycoon

Cosy isometric 3D printing business sim in Godot 4.7 (GDScript). `docs/GDD.md` is the source of truth for design and the phased build plan. Read the section for the current phase before starting work.

## Working rules

- One phase at a time, each on its own branch (`phase-N-short-name`). Don't start a phase until the previous one meets its "done when".
- Don't build systems from later phases early. Stub them if something needs to exist.
- Tick the checkboxes in `docs/GDD.md` section 5 as tasks land.
- Content is data driven: printers, filaments, products, parts, marketplaces and contracts live in `data/*.json`, never hard coded. Schemas are documented in `docs/data_schemas.md`; update it when a table changes.
- Simulation logic (economy, wear, failures) stays separate from scenes and visuals: plain `RefCounted` classes with no node dependencies, so it can be run and tested headless.
- Parody names only for brands and marketplaces. No real brands.
- UK English in names and text (colour, organiser, licence).

## Layout

- `docs/` GDD, data schemas, balancing notes (ignored by Godot)
- `tools/generators/` Blender Python asset generators, one per asset family (ignored by Godot)
- `tools/previews/` preview renders from the generators (git ignored)
- `assets/` generated `.glb` models, palette texture, shared material
- `data/` JSON content tables
- `scenes/` garage and later premises; `scenes/dev/` for test scenes
- `scripts/` gameplay code; `scripts/dev/` for headless tools, `scripts/import/` for import scripts

## Tools

Neither tool is on PATH. Run from the repo root.

- `godot` below is `S:\Godot Games\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe`
- `blender` below is `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (not `blender-launcher.exe`, which hides console output)

```
godot --headless --path . --import                                        # import new or changed assets
godot --headless --path . --script res://scripts/dev/validate_data.gd     # check data tables
godot --headless --path . --script res://scripts/dev/build_palette.gd     # rebuild palette.png from data/palette.json
godot --path . res://scenes/dev/asset_preview.tscn -- --shot=tools/previews/godot.png   # screenshot all models in engine
```

## Art pipeline

- Low poly, flat shaded, warm. Every asset is coloured from the shared palette: `data/palette.json` is the source, `assets/palette/palette.png` is built from it. Append new colours rather than reordering, because cell position is baked into model UVs.
- Generators are seeded, parameterised Blender Python scripts built on `tools/generators/common.py`. Same seed and parameters must give the same asset.
- Units are metres, origin at the centre of the asset's base.
- Generators give meshes a placeholder material named `palette_flat`. On import, `scripts/import/palette_post_import.gd` (set as the default scene import script in `project.godot`) swaps it for the shared `assets/materials/palette_flat.tres`.
- The loop for every asset: run the generator, look at the preview PNG in `tools/previews/`, fix and rerun until it looks right, then import into Godot and check it in `scenes/dev/asset_preview.tscn`. Never import an asset without checking its preview.

```
blender --background --factory-startup --python tools/generators/boxes.py -- --seed 1 --variant closed --out assets/models/props/box_closed_01.glb
```

## GDScript conventions

- Static typing everywhere (typed vars, parameters and return types).
- `snake_case` files, functions and variables; `PascalCase` classes and nodes; `UPPER_SNAKE` constants.
- Tabs for indentation. `##` doc comment at the top of each script saying what it is for.
