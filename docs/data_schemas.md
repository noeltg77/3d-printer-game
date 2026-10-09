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
| `wear_multiplier` | How hard this printer is on its parts. Multiplies all part wear |
| `parts` | Ids from `parts.json` a new one ships with, one per slot |
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
| `ease_of_printing` | 1 (fussy) to 5 (easy). Scales the chance of a print failing by (6 - ease) / 3 |
| `abrasive` | Speeds up nozzle wear, needs a hardened nozzle |
| `moisture_sensitivity` | How fast badly stored spools absorb moisture (Phase 6) |
| `requires` | `enclosure`, `hardened_nozzle`, `direct_drive` |
| `failure_modifiers` | Multipliers on the weight of a failure from `failures.json`, by its id, e.g. `{ "warping": 1.6 }` |
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

## presets.json

Print presets, offered in file order. Imported from `docs/design_data/presets.json` (the three Garage ones so far).

| Field | Meaning |
| --- | --- |
| `description` | Shown on the preset's card in the print dialog |
| `settings_hint` | The real slicer settings it stands for, shown as a tooltip |
| `time_multiplier`, `filament_multiplier` | Applied to the product's `print_minutes` and `filament_grams` |
| `failure_multiplier` | Applied to the chance of the print failing |
| `wear_multiplier` | Applied to part wear from the print (used once parts wear) |
| `durability` | 1 to 5, not 0 to 1. How well the item survives the post |
| `quality` | 1 to 5, not 0 to 1. The finish, before any failure lowers it |

`durability_labels`, beside the table, gives the sentence shown for each durability score.

## failures.json

Ways a print can go wrong. Imported from `docs/design_data/failures.json`: the FDM failures that don't depend on worn parts, upgrades or multicolour units, which come in as those systems do.

The chance that a print fails at all is `(1 - printer reliability) x preset failure_multiplier x (6 - filament ease_of_printing) / 3 x (0.8 + 0.8 x product difficulty)`, capped at 85% (`PrintRisk.fail_chance`). If it does, one failure is picked by weight.

| Field | Meaning |
| --- | --- |
| `happens` | `start` (first 5% of the print), `mid` (anywhere from 10% to 90%) or `end` (found on completion) |
| `outcome` | `scrap`: the print stops and is binned. `stop`: the same, but the fix is to the printer rather than the bed. `degraded`: the print finishes as a flawed item |
| `weight` | How often it is the failure picked, relative to the others |
| `causes` | Condition flag to multiplier on `weight`. Flags so far: `draft_preset`, `no_auto_level`, `large_part`, `tall_thin_part`, `bedslinger_tall_part` (`PrintRisk.conditions`), and `worn_<slot>` for each part below 30% health (`PrinterWear.flags`) |
| `damages` | Part slot to health (0 to 1) the failure knocks off that part |
| `clear_minutes` | Scrap and stop only. Character time to put the printer right |
| `visual` | Scrap and stop only. What is left on the plate: `noodles`, `toppled`, `spaghetti` or `stalled` |
| `quality_loss` | Degraded only. Taken off the item's quality |
| `fix`, `player_text` | The action offered on the printer, and the message when it happens |

A ruined print only uses the filament and electricity up to the point it failed.

A failure with `weight` 0 is never rolled. `breakdown` is the one so far: the printer sets it off when a part runs out mid-print, filling `{part}` and `{text}` from the part's `slot_name` and `break_text`.

## parts.json

Wear parts. Imported from `docs/design_data/parts.json`: one part for each slot in the GDD's list (nozzle, hotend, build plate, belts, PTFE tube, fans). The other Garage parts, alternative parts for a slot and upgrades are not in yet. Prices are the design's base prices; brand multipliers and own-brand parts are not applied.

| Field | Meaning |
| --- | --- |
| `slot`, `slot_name` | Where it fits (a printer has one part per slot) and what to call that in text |
| `lifespan_print_hours` | Print hours from new to broken on a 1.0 wear printer at Standard, before the game's `wear_rate` |
| `abrasive_wear_multiplier` | Applied to wear when printing a filament with `abrasive` set |
| `max_extra_fail` | Added to the chance of every print failing when the part is at 0%. Nothing is added above 30% health, rising evenly below it |
| `replace_minutes` | Character time to fit a spare |
| `price_pence`, `pack_size` | Shop price of a pack, and how many spares are in it |
| `break_text` | The message when it gives out mid-print |

Health lost per print hour is `printer wear_multiplier x game wear_rate x preset wear_multiplier / lifespan_print_hours` (`PrinterWear.wear_per_hour`). At nothing the part is broken and the printer can't print until a spare is fitted.

## game.json

Starting conditions and global rates. Not a table of rows.

| Field | Meaning |
| --- | --- |
| `start.cash_pence`, `start.packaging`, `start.designs`, `start.minute_of_day` | What a new game begins with |
| `electricity_pence_per_kwh` | Charged when a print finishes, from the printer's `power_watts` and the print time |
| `courier_minute_of_day` | When parcels in the outbox are collected and paid |
| `default_preset` | The preset the print dialog opens on |
| `wear_rate` | Multiplies all part wear. Above 1 because the design's lifespans are in real printer hours, which would take many sessions to matter. A balancing knob |
| `bank_name`, `business_name` | Names shown on the PC |
| `supplier` | The filament and hardware shop names, lead times in game minutes (filament, printers, spare parts), and the packaging pack size and price |

One game day is 1440 game minutes and lasts 10 real minutes at 1x (`GameClock.MINUTES_PER_SECOND`).

## Not drafted yet

Upgrades, shipping, contracts, staff and events. Each gets a table when its phase starts.
