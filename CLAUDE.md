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
godot --path . res://scenes/garage/garage.tscn -- --shot=tools/previews/godot_garage.png   # screenshot any scene, then quit
```

`--shot=<png>` and `--shot-delay=<seconds>` work on every scene (the `DevShot` autoload, `scripts/dev/dev_shot.gd`). Use them to look at changes in engine rather than assuming they worked. Dev scenes: `scenes/dev/asset_preview.tscn` (every model in a grid) and `scenes/dev/character_preview.tscn` (one character per animation).

Checking gameplay without clicking: the `DevAutoplay` autoload (`scripts/dev/dev_autoplay.gd`) drives the real action menus from the command line, and combines with `--shot-times` for screenshots along the way.

```
godot --headless --path . --script res://scripts/dev/run_tests.gd    # unit tests for simulation classes
godot --path . res://scenes/garage/garage.tscn -- --time-scale=2 "--autoplay=Finisher 3>Load filament>Red;Finisher 3>Start print;wait>21;Finisher 3>Collect print" --shot=tools/previews/play.png --shot-times=4,12,30,45
```

## Gameplay architecture

Control is semi-autonomous: the player clicks an object, picks from its action list, and the character does the whole task. Tasks queue.

- `Interactable` (`scripts/interaction/`) is the base for anything clickable. Subclasses override `get_actions(agent)` to return `Action`s; each Action's `run` is a coroutine that drives the character. The script goes straight on the instanced model node in the scene, with `display_name` and `stand_offset` set there. It builds its own click collider from its meshes.
- `Agent` (`scripts/character/agent.gd`, `scenes/characters/player.tscn`) owns the task queue. Task code is a plain sequence of awaits: `go_to()`, `reach(callable)`, `carry()`, `release()`, `sit()`. A task must re-check its preconditions when it starts, because the world may have changed while it was queued.
- `InteractionController` handles hover, the popup menu and floor clicks. `Hud` shows the current task and queue.
- `FloorGrid` is the navigation: an A* grid, with every node in the `obstacle` group blocking the cells under it. Add floor-standing furniture to that group. No baking.
- Items are nodes that get reparented between slot markers, the character's `carry_socket` and printer mounts (`Spool`, `PrintedItem` in `scripts/items/`). Printed items use the tint material and take their filament's colour.
- Objects find each other through groups (`filament_rack`, `print_storage`, `floor_grid`, `player`), not hard-wired paths.
- The rules of the business live in `scripts/sim/` as plain classes with no node dependencies (`GameClock`, `Bank`, `Marketplace`, `Supplier`, plus `PrintJob`). Every one has tests in `scripts/dev/run_tests.gd`; add tests when adding rules.
- The `Game` autoload (`scripts/game/game.gd`) owns those objects, advances them each frame and emits `changed`, `notified`, `delivery_arrived` and `courier_arrived`. Scene nodes and UI read from `Game` and call its methods; they don't keep their own copies of cash, orders or designs.
- Game speed is `Engine.time_scale` (set through `Game.set_speed`), so walking, animation, prints and timers all follow it. Durations in data are game minutes; convert with `GameClock.to_seconds`.
- Physical stock is nodes, not counters: spools on the rack carry their own grams, finished prints sit in shelf slots, parcels sit on the outbox. Mailer boxes are the one counted stock (`Game.packaging`).
- The PC is `PcScreen` (`scripts/ui/`), one script per tab, each rebuilding itself in `refresh()` from `Game`. `Ui` has the helpers for building rows and labels in code.

## Art pipeline

- Low poly, flat shaded, warm. Every asset is coloured from the shared palette: `data/palette.json` is the source, `assets/palette/palette.png` is built from it. Append new colours rather than reordering, because cell position is baked into model UVs.
- Generators are seeded, parameterised Blender Python scripts built on `tools/generators/common.py`. Same seed and parameters must give the same asset.
- Units are metres, origin at the centre of the asset's base. The front of an asset faces Blender -Y, which is +Z in Godot.
- Parts that move in game (printer bed, gantry and toolhead, roller door, character limbs) are separate objects with their origin on the pivot. Attachment points are empties ("markers") such as `plate`, `spool_mount`, `spool_slot_1`, `carry_socket`. They import as named nodes, so gameplay code finds them by name.
- `tools/generators/manifest.json` lists every asset with its generator and arguments. Add new assets there, not as one-off commands, so everything can be rebuilt.
- The character is short and chunky (about 1.5 m, hips at 0.6 m). Furniture it uses is sized to match: chair seat at 0.4 m, desk top at 0.7 m, workbench at 0.9 m.
- Characters are animated in code, not with clips: `scripts/character/character_rig.gd` rotates the limb pivots (idle, walk, sit, plus carrying and a one-shot reach).
- Generators give meshes a placeholder material named `palette_flat`. On import, `scripts/import/palette_post_import.gd` (set as the default scene import script in `project.godot`) swaps it for the shared `assets/materials/palette_flat.tres`.
- The loop for every asset: run the generator, look at the preview PNG in `tools/previews/`, fix and rerun until it looks right, then import into Godot and check it in `scenes/dev/asset_preview.tscn`. Never import an asset without checking its preview.

```
blender --background --factory-startup --python tools/generators/build_all.py                    # rebuild everything in the manifest (about 10 s)
blender --background --factory-startup --python tools/generators/build_all.py -- --only printer  # only outputs whose path contains "printer"
blender --background --factory-startup --python tools/generators/boxes.py -- --seed 1 --variant closed --out assets/models/props/box_closed_01.glb
```

## GDScript conventions

- Static typing everywhere (typed vars, parameters and return types).
- `snake_case` files, functions and variables; `PascalCase` classes and nodes; `UPPER_SNAKE` constants.
- Tabs for indentation. `##` doc comment at the top of each script saying what it is for.
