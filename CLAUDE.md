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
- `docs/design_data/` content designed ahead of the build (660 products, 38 printers, filaments, parts, presets, failures, shipping). Reference only: the game loads `data/`, and each phase imports what it needs from here. Read its README before adding content or product models
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
godot --path . res://scenes/garage/garage.tscn -- --time-scale=2 "--autoplay=call>place_supplier_order({\"printers\":{\"plodder_mini\":1},\"spools\":{\"red\":1}});wait>80;Delivery: 1 spool>Unpack;Delivery: Printer>Unpack;Plodder Mini>Load filament>Red;Plodder Mini>Print>Cable;shot>tools/previews/play.png;quit"
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
- Money is GBP pence (integers) in all data, simulation and saves. Show it only through `Money.format(pence, kind)` in `scripts/sim/money.gd`: `Money.PRICE` for shop and listing prices (rounds to .49 or .99 in the player's currency), the default `Money.EXACT` for balances, costs and totals. Never write a currency symbol in UI code. The player picks GBP, USD or EUR in the Settings app; `Game.set_currency` saves it to `user://settings.cfg` and emits `changed`.
- Physical stock is nodes, not counters: spools on the rack carry their own grams, finished prints sit in shelf slots, parcels sit on the outbox. Mailer boxes are the one counted stock (`Game.packaging`).
- The PC is `PcScreen` (`scripts/ui/pc/`), a full-screen "PlateOS" desktop. Each app is one script (`app_*.gd`) that rebuilds itself in `refresh()` from `Game`; register new apps in `PcScreen.APPS`. While the PC is open the character is held (`Agent.held`), so jobs queued from an app start when the player leaves the desk.

## UI look and feel

`docs/mockups/pc_screens.html` is the visual source of truth for all UI (open it in a browser). Every screen, in the PC or over the 3D view, follows it: Fredoka headings, Nunito body text, cream cards with a flat offset shadow, chunky rounded buttons, warm accent colours, dark taskbar chips. Never ship a screen in Godot's default dark theme, even as a placeholder.

- Build UI in code from `Ui` (`scripts/ui/ui.gd`): colour constants, `Ui.text` / `Ui.title`, `Ui.card`, `Ui.box`, `Ui.button`, `Ui.pill`, `Ui.bar`, `Ui.icon`, `Ui.hbox` / `Ui.vbox`. Add a helper there rather than styling a one-off.
- Set `Ui.theme()` on the top control of each screen and on popup menus.
- Icons are white line SVGs in `assets/ui/icons/`, tinted when used. Fonts are in `assets/fonts/` (see the README there about the licence files needed before release).
- The base window is 1600 x 900. Lay screens out with containers so they stretch, not fixed positions.
- Where a mock-up shows something from a later phase (reviews, part health, upgrades, print settings), leave it out or show an honest "not yet" state. Don't fill it with fake data.

## Art pipeline

- Low poly, flat shaded, warm. Every asset is coloured from the shared palette: `data/palette.json` is the source, `assets/palette/palette.png` is built from it. Append new colours rather than reordering, because cell position is baked into model UVs.
- Generators are seeded, parameterised Blender Python scripts built on `tools/generators/common.py`. Same seed and parameters must give the same asset.
- Units are metres, origin at the centre of the asset's base. The front of an asset faces Blender -Y, which is +Z in Godot.
- Parts that move in game (printer bed, gantry and toolhead, roller door, character limbs) are separate objects with their origin on the pivot. Attachment points are empties ("markers") such as `plate`, `spool_mount`, `spool_slot_1`, `carry_socket`. They import as named nodes, so gameplay code finds them by name.
- `tools/generators/manifest.json` lists every asset with its generator and arguments. Add new assets there, not as one-off commands, so everything can be rebuilt.
- The character is short and chunky: about 1.6 m with a head a third of that, hips at 0.47 m, shoulders at 0.94 m. Furniture it uses is sized to match: chair seat at 0.4 m, desk top at 0.7 m, workbench at 0.9 m. Body parts are rounded (capsule limbs, 2 to 3 segment bevels) to match the props. To judge a change against the furniture before importing, run `tools/generators/preview_character.py`, which renders front and three-quarter views beside the desk and chair.
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
