# Design data (not yet in the game)

Content worked out ahead of the build: 660 products, 38 printers across 10 brands, 197 filaments, parts and upgrades, accessories, presets, failures and shipping. These files are the reference for later phases. **The game does not load them.** The live tables are in `data/`, and each phase imports what it needs from here into `data/`, converting as it goes.

Stored exactly as supplied on 2026-10-09. Don't edit them to match the game; change the import instead, so they stay a clean record of the design.

## What each file is for, and when

| File | Contents | Imported in |
| --- | --- | --- |
| `presets.json` | Draft, Standard, Strong and four later presets; support, brim and other toggles; durability and quality scales | Phase 4 (the three Garage presets), rest in Phase 6 |
| `failures.json` | 24 failure types with causes, outcomes, player text and the roll rules | Phase 4 (FDM failures), resin, SLS and belt ones in Phase 9 |
| `parts.json` | Wear parts with lifespans, upgrades with effects, wear modifiers | Phase 4 (Garage wear parts and spares), upgrades in Phase 6 |
| `shipping.json` | Parcel bands, packaging, fillers and extras, 7 couriers, 22 services, damage and review rules | Phase 4 for delivery damage (Garage packaging and couriers), rest as tiers unlock |
| `filaments.json` | 25 materials, 8 brands, 197 colour and material combinations | Garage PLA colours can come in any time; other materials in Phase 6 |
| `accessories.json` | Multicolour units, dryers and dry boxes, moisture rules | Dryers in Phase 6, multicolour units in Phase 7 |
| `printers.json` | 12 form factors, 10 brands, 38 printers | Garage printers any time; others as tiers unlock (Phases 6, 8, 9) |
| `products.json` | 660 products: 160 Garage, 474 Spare room, 19 Workshop, 7 Factory | Garage products once their models exist; others as tiers unlock |

## Differences from the live game to resolve on import

- **Currency.** Settled: the game runs in GBP like these files, and converts only for display. The files hold pounds with decimals (`*_gbp`); `data/` holds integer pence (`*_pence`), so multiply by 100 on import.
- **Tiers.** These files name tiers (`Garage`, `Spare room`, `Workshop`, `Factory`); `data/` uses numbers 1 to 4.
- **Field names and units.** For example `print_hours` here against `print_minutes` in `data/`, `filament_g` against `filament_grams`, `difficulty` 1 to 5 here against 0 to 1.
- **Product ids.** The five designs currently in `data/products.json` were invented before this list. `phone_stand` and `desk_organiser` match ids here; `cable_clips`, `plant_pot` and `flexi_dragon` do not (nearest: `cable_management_clips_x12`, `low_poly_planter`, `articulated_dragon`). Rename them when the catalogue is imported.
- **Printer prices.** The Plodder Mini is 179 here and 159 in the game. Starting cash was tuned around 159.
- **Shop and marketplace names.** Spoolhouse, Plainly and Meadow match. The marketplace is "Craftsy" in the game.

## Brief for building product models

Each product needs a small model that grows on the print bed and then sits on a shelf.

- One `.glb` per product at `assets/models/prints/<product id>.glb`, using the id from `products.json` exactly. `PrintedItem` loads the model by product id.
- Built by `tools/generators/prints.py` (or further `prints_*.py` files, one per category) and listed in `tools/generators/manifest.json`. Follow the art pipeline in `CLAUDE.md`: render the preview, look at it, then import.
- Use the tint material (`MeshBuilder(material=common.TINT_MATERIAL_NAME)`), so the game colours the item to match its filament. One colour per model for now.
- Origin at the centre of the base, sitting on z = 0, because the print animation grows the model upwards from the bed.
- Size for readability at the game camera, not realism: the existing five are roughly 1.3 to 1.5 times real size. Keep within the product's size band so it fits a shelf slot (about 0.35 m wide).
- Bevel edges to match the props.
- For anything hollow and open-topped (pots, cups, bins, tubs, trays) use `builder.shell(radius, height, wall, colour, segments=...)` from `common.py`. It makes the walls and floor as one piece, so corners and the base are right by construction. Don't assemble containers from separate wall boxes.
- Keep models light: most should be under about 200 triangles. A row of small bevelled boxes to fake a curve adds up fast.
- Before calling a model done, check the preview against what the code comments claim, and look from above as well as from the game angle (`common.render_preview(path, direction=(0.15, -0.5, 1.0))`), since the game camera looks down into open shapes.
- **Start with the 160 Garage products**, all single-colour PLA. The 178 multicolour products (all Spare room or later) need a way to colour parts separately that doesn't exist yet; leave them until Phase 7 decides it.
- Prefer a few parameterised shapes per category (bins, stands, clips, hooks, pots, trays) over 660 one-offs. Many products are variations on the same form.
