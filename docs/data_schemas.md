# Data schemas (draft)

All content lives in `data/*.json` and is loaded by `scripts/data/game_data.gd`. Balancing should never need a code change. Every number here is a placeholder.

Conventions:

- `id` is a unique snake_case string and is how tables reference each other.
- Money is an integer in GBP pence (`*_pence`), everywhere: data, simulation and saves. The player's display currency is applied only when an amount is shown, by `Money.format`. Every amount converts exactly, so a price shown always equals the amount charged. Give shop and listing prices a .49 or .99 ending in the data so they look tidy in pounds; in other currencies they come out as whatever the rate gives.
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

## currencies.json

Display currencies, keyed by code. Not a table of rows with ids.

| Field | Meaning |
| --- | --- |
| `name` | Shown in the Settings picker |
| `rate` | Fixed multiplier from GBP |
| `symbol`, `symbol_after` | The symbol and whether it follows the number (with a space) |
| `decimal`, `thousands` | Separator characters |

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
| `shop_colours` | `top`, `left`, `right` hex colours for the flat printer drawing on its shop card |

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
| `demand_per_day` | Orders per game day when listed at the typical price |
| `licence` | `type` is `one_off` (pay `fee_pence` once), `royalty` (`royalty_pct` of each sale) or `personal_use` (cannot be sold) |

## marketplaces.json

| Field | Meaning |
| --- | --- |
| `fee_pct`, `fee_fixed_pence` | Taken from every sale |
| `dispatch_minutes` | How long an order can wait before it is cancelled |
| `max_open_orders` | No new orders arrive while this many are waiting to be packed |
| `price_sensitivity` | Demand is multiplied by (typical price / your price) to this power |
| `max_demand_multiplier` | Cap on the boost from pricing below typical |

## game.json

Starting conditions and global rates. Not a table of rows.

| Field | Meaning |
| --- | --- |
| `start.cash_pence`, `start.packaging`, `start.designs`, `start.minute_of_day` | What a new game begins with |
| `electricity_pence_per_kwh` | Charged when a print finishes, from the printer's `power_watts` and the print time |
| `courier_minute_of_day` | When parcels in the outbox are collected and paid |
| `bank_name`, `business_name` | Names shown on the PC |
| `supplier` | The filament and hardware shop names, lead times in game minutes, and the packaging pack size and price |

One game day is 1440 game minutes and lasts 10 real minutes at 1x (`GameClock.MINUTES_PER_SECOND`).

## Not drafted yet

Parts and upgrades, print presets, contracts, staff and events. Each gets a table when its phase starts.
