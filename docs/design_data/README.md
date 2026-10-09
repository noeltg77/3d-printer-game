# Design data (not yet in the game)

Content worked out ahead of the build: 660 products, 38 printers across 10 brands, 197 filaments, parts and upgrades, accessories, presets, failures and shipping. These files are the reference for later phases. **The game does not load them.** The live tables are in `data/`, and each phase imports what it needs from here into `data/`, converting as it goes.

Stored exactly as supplied on 2026-10-09. Don't edit them to match the game; change the import instead, so they stay a clean record of the design.

## What each file is for, and when

| File | Contents | Imported in |
| --- | --- | --- |
| `presets.json` | Draft, Standard, Strong and four later presets; support, brim and other toggles; durability and quality scales | Phase 4 (the three Garage presets), rest in Phase 6 |
| `failures.json` | 24 failure types with causes, outcomes, player text and the roll rules | Phase 4 (FDM failures), resin, SLS and belt ones in Phase 9 |
| `parts.json` | Wear parts with lifespans, upgrades with effects, wear modifiers | Phase 4 (Garage wear parts and spares), upgrades in Phase 6 |
| `shipping.json` | Parcel bands, packaging, fillers and extras, 7 couriers, 22 services, damage and review rules | Bags, boxes, parcel bands and five couriers' services are in (`data/packaging.json`, `data/couriers.json`). Not yet: crates and pallets, fillers and extras, FreightFolk, GlobeHop, collection fees and cut off times |
| `filaments.json` | 25 materials, 8 brands, 197 colour and material combinations | Garage PLA colours can come in any time; other materials in Phase 6 |
| `accessories.json` | Multicolour units, dryers and dry boxes, moisture rules | Dryers in Phase 6, multicolour units in Phase 7 (the four slot Spare room ones so far, as rows in `data/upgrades.json`) |
| `printers.json` | 12 form factors, 10 brands, 38 printers | Garage printers any time; others as tiers unlock (Phases 6, 8, 9) |
| `products.json` | 660 products: 160 Garage, 474 Spare room, 19 Workshop, 7 Factory | Garage, Spare room and Workshop imported, less the contract only ones, which are marked `contract_only` and come with a client's contract once they have a model and a client to supply them. The Factory products are resin and are in too |

## Differences from the live game to resolve on import

- **Currency.** Settled: the game runs in GBP like these files, and converts only for display. The files hold pounds with decimals (`*_gbp`); `data/` holds integer pence (`*_pence`), so multiply by 100 on import.
- **Tiers.** These files name tiers (`Garage`, `Spare room`, `Workshop`, `Factory`); `data/` uses numbers 1 to 4.
- **Field names and units.** For example `print_hours` here against `print_minutes` in `data/`, `filament_g` against `filament_grams`, `difficulty` 1 to 5 here against 0 to 1.
- **Product ids.** Resolved for the Garage: `data/products.json` uses the ids here. Two rows from before this list remain, `desk_organiser` and `flexi_dragon`, because this list places them in the Spare room (as `desk_organiser`, now two colour, and `articulated_dragon`). Replace them when that tier is imported.
- **Printer prices.** The Plodder Mini is 179 here and 159 in the game. Starting cash was tuned around 159.
- **Shop and marketplace names.** Spoolhouse, Plainly and Meadow match. The marketplace is "Craftsy" in the game.

## Importing products

`data/products.json` is written by `scripts/dev/import_products.gd`, not by hand. It converts the fields above and works out what this list does not hold:

- `size_mm` is measured from the product's model, scaled back down to real size. A small part whose generator calls `builder.enlarge(...)` to make it visible needs the same factor in `data/import/model_enlargement.json`, or the import records it too big.
- `demand_per_day` comes from the size band (XS 3, S 2.5, M 2, L 1.5, XL 1 for the cheapest design in the band; the cheapest Garage design, or for XL, which the Garage has none of, the cheapest Spare room one) and falls for dearer designs, by the square root of the price ratio. Seasons and demand patterns are not applied yet, so seasonal products sell all year.
- `licence` is a one-off fee of twice the typical price.
- `description` is written by hand in `data/import/product_descriptions.json`, one line per product id. A product with nothing there shows its category name, and the import lists it.
- `colour_swaps`, for a design in more than one colour, is the catalogue's `purge_waste_g` divided by 4 g: the number of colour changes, which the game prices by the unit fitted.
- `OVERRIDES` in the script sets these per product where a rule is not good enough (the free starting design).

These rules were set with `scripts/dev/balance_report.gd`; see `docs/balance_notes.md` before changing them.

To change a product, change the rules or `OVERRIDES` and run the script again. A product is only imported once its model exists.

## Brief for building product models

Each product needs a small model that grows on the print bed and then sits on a shelf.

- One `.glb` per product at `assets/models/prints/<product id>.glb`, using the id from `products.json` exactly. `PrintedItem` loads the model by product id.
- Built by `tools/generators/prints.py` (or further `prints_*.py` files, one per category) and listed in `tools/generators/manifest.json`. Follow the art pipeline in `CLAUDE.md`: render the preview, look at it, then import.
- Use the tint material (`MeshBuilder(material=common.TINT_MATERIAL_NAME)`), so the game colours the item to match its filament. One colour per model for now.
- Origin at the centre of the base, sitting on z = 0, because the print animation grows the model upwards from the bed.
- Size for readability at the game camera, not realism: the existing five are roughly 1.3 to 1.5 times real size. Keep within the product's size band so it fits a shelf slot (about 0.35 m wide).
- Bevel edges to match the props.
- For anything hollow and open-topped (pots, cups, bins, tubs, trays) use `builder.shell(radius, height, wall, colour, segments=...)` from `common.py`. It makes the walls and floor as one piece, so corners and the base are right by construction. Don't assemble containers from separate wall boxes. Rectangular ones use `builder.tray(size, wall, colour, ...)` the same way. `shell(..., open_base=True)` and `builder.outline(points, ...)` make bare walls open at both ends (rings, cookie cutters of any shape), `builder.plate(points, ...)` a flat silhouette and `builder.ball(...)` a faceted globe.
- Shapes shared between products (slotted racks, divided trays, laid-out sets) live in `tools/generators/print_shapes.py`. Check there before writing a new one.
- To review a batch, `tools/generators/preview_prints.py -- --generator prints_home` renders every item from one generator on a single sheet, from the front and from above, and prints each triangle count and size.
- Keep models light: most should be under about 200 triangles. A row of small bevelled boxes to fake a curve adds up fast.
- Before calling a model done, check the preview against what the code comments claim, and look from above as well as from the game angle (`common.render_preview(path, direction=(0.15, -0.5, 1.0))`), since the game camera looks down into open shapes.
- **Multicolour products** (178, all Spare room or later) are built by `tools/generators/prints_multicolour.py`. Each colour of the design is a mesh of its own: the main mesh holds everything in the first colour, and each further colour is a child mesh named `colour_2`, `colour_3` and so on. The game tints each mesh with the spool that printed it, so the model only decides which parts share a colour. Put the bulk of the item in the first colour, which takes most of the filament. All 168 Spare room ones are built: the first six in `prints_multicolour.py`, the rest by group of categories in `prints_mc_*.py`. The four contract only ones and the five for the Workshop and Factory are in `prints_mc_later.py`.
- A few catalogue entries are named after real brands. Their ids stay as they are, their models are generic, and `OVERRIDES` in the import gives them a name the game can use.
- A Spare room product is imported as soon as its model exists; the import leaves out the ones without and says how many.
- Prefer a few parameterised shapes per category (bins, stands, clips, hooks, pots, trays) over 660 one-offs. Many products are variations on the same form.
