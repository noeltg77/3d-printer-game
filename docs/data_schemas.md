# Data schemas (draft)

All content lives in `data/*.json` and is loaded by `scripts/data/game_data.gd`. Balancing should never need a code change. Every number here is a placeholder.

Conventions:

- `id` is a unique snake_case string and is how tables reference each other.
- Money is an integer in pence (`*_pence`). GBP is assumed until the currency open question in the GDD is settled.
- Time is in game minutes (`*_minutes`). How long a game minute lasts in real time is a time scale question, not a data one.
- Multipliers are relative to 1.0. Chances and ratings are 0.0 to 1.0.
- `unlock_tier` is the progression tier (1 garage to 4 factory) where the entry first appears.
- Colours are names from `data/palette.json`.

Validate with:

```
godot --headless --path . --script res://scripts/dev/validate_data.gd
```

## palette.json

| Field | Meaning |
| --- | --- |
| `columns`, `cell_px` | Layout of the generated palette texture |
| `colours[]` | Ordered `{ name, hex }`. Order sets the texture cell, so append new colours rather than reordering |

## printers.json

| Field | Meaning |
| --- | --- |
| `name`, `brand`, `description` | Display text. Parody brands only |
| `kind` | `fdm` for now. Later: `resin`, `sls`, `industrial` |
| `motion` | `bed_slinger` or `core_xy` |
| `price_pence` | Supplier shop price |
| `speed_multiplier` | Divides a product's `print_minutes` |
| `build_volume_mm` | `[x, y, z]`. A product must fit to be printable |
| `reliability` | Base chance a print succeeds before wear, filament and preset modifiers |
| `max_nozzle_temp_c` | Must be at least the filament's `nozzle_temp_c` |
| `enclosed`, `direct_drive`, `auto_bed_levelling` | Built-in capabilities |
| `supported_filaments` | Filament ids it can print out of the box |
| `power_watts` | Drives electricity cost per print |
| `upgrade_slots` | Upgrade kinds that can be fitted (upgrades table comes in Phase 4/6) |
| `model` | Which asset generator, variant and colour builds its mesh |

## filaments.json

| Field | Meaning |
| --- | --- |
| `price_pence_per_kg`, `spool_grams` | Spool cost is derived from these |
| `nozzle_temp_c` | Minimum nozzle temperature needed |
| `speed_multiplier` | Below 1.0 prints slower (TPU) |
| `value_multiplier` | Sale price uplift for items in this material |
| `abrasive` | Speeds up nozzle wear, needs a hardened nozzle |
| `moisture_sensitivity` | How fast badly stored spools absorb moisture (Phase 6) |
| `requires` | `enclosure`, `hardened_nozzle`, `direct_drive` |
| `failure_modifiers` | Multipliers per failure type, e.g. `{ "warping": 1.6 }` (Phase 4) |
| `colours` | Colours this filament is sold in |

## products.json

| Field | Meaning |
| --- | --- |
| `category` | Demand and trend group, e.g. `home_organisation`, `fidget_toys` |
| `filament_grams` | Filament used per unit at the Standard preset |
| `print_minutes` | Print time per unit on a 1.0 speed printer at the Standard preset |
| `size_mm` | `[x, y, z]`, checked against printer build volume |
| `difficulty` | Adds to failure chance |
| `needs_supports` | Adds post-processing time and waste |
| `colour_count` | Above 1 needs a multicolour unit (Phase 7) |
| `allowed_filaments` | Filament ids the design works in |
| `base_price_pence` | Typical marketplace price before demand and rating effects |
| `licence` | `type` is `one_off` (pay `fee_pence` once), `royalty` (`royalty_pct` of each sale) or `personal_use` (cannot be sold) |

## Not drafted yet

Parts and upgrades, marketplaces, print presets, contracts, staff and events. Each gets a table when its phase starts.
