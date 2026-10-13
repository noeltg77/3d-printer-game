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
| `kind` | `fdm` or `resin`: how it makes things, and so what it takes (a filament's `process`), how it fails (a failure's `process`) and which kits fit (`fits_kind`). SLS is not in |
| `motion` | `bed_slinger`, `core_xy` or `resin_lift`. Picks the print animation |
| `auto_eject`, `auto_eject_tray` | Optional. A printer built to clear its own plate (a belt printer), and how many prints its tray holds. It behaves as if an auto-eject plate were fitted |
| `price_pence` | Supplier shop price |
| `speed_multiplier` | Divides a product's `print_minutes` |
| `build_volume_mm` | `[x, y, z]`. A product must fit, either way round on the bed, to be printable (`PrintRisk.fits`) |
| `reliability` | Base chance a print succeeds before wear, filament and preset modifiers |
| `wear_multiplier` | How hard this printer is on its parts. Multiplies all part wear |
| `parts` | Ids from `parts.json` a new one ships with, one per slot |
| `max_nozzle_temp_c` | Must be at least the filament's `nozzle_temp_c` |
| `enclosed`, `direct_drive`, `auto_bed_levelling` | Built-in capabilities. Upgrades can add them. What a printer can print follows from these and the temperature (`FilamentRules.problem`); there is no list of filaments |
| `power_watts` | Drives electricity cost per print |
| `model` | `asset` is the model file in `assets/models/printers/`; `generator` and `variant` say what built it. Each printer has its own variant, named for its id |

## filaments.json

| Field | Meaning |
| --- | --- |
| `family` | The plain filament this is a variety of, by its id. A design that allows a family allows every filament in it |
| `process` | Optional. `resin` for a resin: only a printer of that `kind` takes it. Filament printing if absent |
| `container` | Optional. `bottle` if it comes in a bottle, not on a spool. It needs a `bottle_<colour>.glb` for each of its colours |
| `post_minutes` | Optional. Character time to finish each plate before it is shelved: washing and curing, for resin |
| `price_pence_per_kg`, `spool_grams` | Spool cost is derived from these |
| `nozzle_temp_c` | Minimum nozzle temperature needed |
| `speed_multiplier` | Below 1.0 prints slower (TPU) |
| `value_multiplier` | Sale price uplift for items in this material: the buyer pays the listed price times this |
| `ease_of_printing` | 1 (fussy) to 5 (easy). Scales the chance of a print failing by (6 - ease) / 3 |
| `abrasive` | Multiplies nozzle wear by the nozzle's `abrasive_wear_multiplier` |
| `moisture_sensitivity` | How fast a spool in the open soaks up moisture: this times the game's `moisture.gain_per_day`, per game day |
| `drying_multiplier` | How much longer than plain PLA it takes to dry |
| `requires` | `enclosure` and `direct_drive` are hard limits: a printer without one can't load it. `hardened_nozzle` is advice: it prints on brass, at the cost of the nozzle |
| `failure_modifiers` | Multipliers on the weight of a failure from `failures.json`, by its id, e.g. `{ "warping": 1.6 }` |
| `colours` | Colours this filament is sold in |

Imported from `docs/design_data/filaments.json` (`materials`): PLA, three special PLAs, carbon PLA, PETG, TPU, ABS, ASA and the three resins. Nylon and polycarbonate are not in, and the design has no powder for an SLS machine. `failure_modifiers` come from the design's 1 to 5 scores: stringing is `1 + (score - 2) x 0.25`, warping `1 + (score - 1) x 0.2`. The shop only sells a filament once the business has reached its tier and some design in the game can be printed in it.

## products.json

Generated from `docs/design_data/products.json` by `scripts/dev/import_products.gd`. Don't edit it by hand: change the rules or per product overrides in that script and run it again. Every product needs a model at `assets/models/prints/<id>.glb`; the validator checks. Every Garage product is in. Spare room products come in as their models are built: one without a model is left out.

| Field | Meaning |
| --- | --- |
| `category` | Demand and trend group, e.g. `home_organisation`, `fidget_toys` |
| `category_name` | The category as shown to the player, e.g. "Valentine's Day". Optional: without it the id is tidied up and shown |
| `filament_grams` | Filament used per unit at the Standard preset |
| `print_minutes` | Print time per unit on a 1.0 speed printer at the Standard preset |
| `size_mm` | `[x, y, z]`, checked against printer build volume |
| `difficulty` | Adds to failure chance |
| `needs_supports` | Adds post-processing time and waste |
| `colour_count` | How many colours the design is made for. Above 1 it needs a printer with a multicolour unit and a spool for each; without, it prints in one colour and sells for less (the `multicolour` toggle in `presets.json`). The model has a mesh for each colour (see the art pipeline in `CLAUDE.md`) |
| `colour_swaps` | Only on designs with more than one colour: how many times the printer changes colour in a full colour print. From the catalogue's `purge_waste_g`, divided by the 4 g a reference unit purges each time |
| `allowed_filaments` | Filament ids or families the design works in |
| `base_price_pence` | Typical marketplace price before demand and rating effects |
| `demand_per_day` | Orders per game day when listed at the typical price |
| `licence` | `type` is `one_off` (pay `fee_pence` once), `royalty` (`royalty_pct` of each sale) or `personal_use` (cannot be sold) |
| `contract_only` | Optional. True for a design that is never on general sale: a client supplies it with a contract (`supplies` in `contracts.json`). It has no demand and no fee, and the Design Lab leaves it out. From the catalogue's "Contracts" demand pattern |

## marketplaces.json

| Field | Meaning |
| --- | --- |
| `order_prefix` | Letters in this marketplace's order numbers, e.g. `CR` for `#CR-1004` |
| `audience` | Multiplies all demand: how many buyers the marketplace has |
| `price_expectation` | Multiplies each design's `base_price_pence` to give the price buyers here think is normal. New listings start at it, and demand is judged against it |
| `fee_pct`, `fee_fixed_pence` | Taken from every sale |
| `dispatch_minutes` | How long an order can wait before it is cancelled |
| `max_open_orders` | No new orders arrive while this many are waiting to be packed |
| `price_sensitivity` | Demand is multiplied by (typical price / your price) to this power |
| `max_demand_multiplier` | Cap on the boost from pricing below typical |
| `review_chance` | Chance that a buyer who keeps the item leaves a review |
| `return_chance_flawed` | Chance a flawed print is sent back for a refund |
| `return_chance_per_quality_point` | Chance a print is sent back, for each point its quality is below 3 |
| `rating_window` | The seller rating is the average of this many most recent reviews |
| `rating_neutral`, `rating_demand_per_star` | Demand is multiplied by 1 + (rating - neutral) x per star |
| `rating_confidence_reviews` | The rating's effect on demand grows from nothing to full over this many reviews |
| `min_rating_multiplier`, `max_rating_multiplier` | Limits on that multiplier. A shop with no reviews is at 1.0 |

Stars for a print that is kept are `3.2 + 0.5 x quality`, less 1 if it is flawed, give or take 0.8 (`Marketplace.stars_for`). A parcel that arrives broken gets 1 star, a returned one 2, and both are refunded in full with the marketplace's fee and any royalty handed back.

## reviews.json

`comments`: the lines buyers write, as lists keyed by `damaged`, `returned` and the star counts `1` to `5`.

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

`toggles`, also beside the table, holds print options, by `id`. Imported from the design's `toggles`: `multicolour` and `batch_plate` so far.

| Field | Meaning |
| --- | --- |
| `name`, `description` | The option when on, as the print dialog offers it |
| `off_name`, `off_description` | The same when it is off |
| `off_price_multiplier` | A multicolour design printed in one colour sells for the listed price times this |
| `off_star_penalty` | Stars such a print loses in its review (`Marketplace.plain_star_penalty`) |

`batch_plate` is printing several copies at once. As many as fit on the bed can go on, all turned the same way and `gap_mm` apart (`PrintRisk.copies`), up to `max_copies`. A batch takes the copies' filament and `time_multiplier` of their time added up. It is rolled for once, so the copies fail or come out flawed together, and a multicolour unit changes colour the same number of times however many copies there are: the purged filament is shared.

## failures.json

Ways a print can go wrong. Imported from `docs/design_data/failures.json`: the FDM failures that don't depend on worn parts, upgrades or multicolour units, which come in as those systems do.

The chance that a print fails at all is `(1 - printer reliability) x preset failure_multiplier x (6 - filament ease_of_printing) / 3 x (0.8 + 0.8 x product difficulty)`, capped at 85% (`PrintRisk.fail_chance`). If it does, one failure is picked by weight.

| Field | Meaning |
| --- | --- |
| `happens` | `start` (first 5% of the print), `mid` (anywhere from 10% to 90%) or `end` (found on completion) |
| `outcome` | `scrap`: the print stops and is binned. `stop`: the same, but the fix is to the printer rather than the bed. `degraded`: the print finishes as a flawed item |
| `weight` | How often it is the failure picked, relative to the others |
| `causes` | Condition flag to multiplier on `weight`. Flags so far: `draft_preset`, `no_auto_level`, `large_part`, `tall_thin_part`, `bedslinger_tall_part` (`PrintRisk.conditions`), `worn_<slot>` for each part below 30% health (`PrinterWear.flags`), `wet_filament`, and from a multicolour unit `multicolour_unit`, `tpu_in_multicolour` and `many_colour_swaps` (`Multicolour.flags`) |
| `requires` | Optional. A condition flag the failure can't happen without: `multicolour_unit` for the unit's own jam |
| `process` | Optional. `resin` for a failure of resin printers, which then never happens on a filament printer. Every other failure never happens on a resin one |
| `damages` | Part slot to health (0 to 1) the failure knocks off that part |
| `clear_minutes` | Scrap and stop only. Character time to put the printer right |
| `visual` | Scrap and stop only. What is left on the plate: `noodles`, `toppled`, `spaghetti` or `stalled` |
| `quality_loss` | Degraded only. Taken off the item's quality |
| `fix`, `player_text` | The action offered on the printer, and the message when it happens |

A ruined print only uses the filament and electricity up to the point it failed.

A failure with `weight` 0 is never rolled. `breakdown` is the one so far: the printer sets it off when a part runs out mid-print, filling `{part}` and `{text}` from the part's `slot_name` and `break_text`.

## upgrades.json

Kits fitted to a printer for good. Imported from `docs/design_data/parts.json` (`upgrades`): so far only the Garage ones whose effects the game models. Bought and delivered like spare parts (one to a pack), so an upgrade id must not match a part id.

| Field | Meaning |
| --- | --- |
| `description` | Plain-words pitch on its shop row |
| `model` | Optional. Its model file in `assets/models/parts/`, shown in the shop and on the shelving. A multicolour unit has none: it waits in a plain box, and its `multicolour.model` is what goes on the printer |
| `price_pence`, `install_minutes` | Shop price, and character time to fit it |
| `fits_motion` | Printer `motion` values it fits. Empty for any printer |
| `fits_printers` | Optional. Printer ids it fits, for a kit made for particular machines |
| `fits_kind` | Optional. Printer `kind` values it fits. Any kind if absent |
| `multicolour` | Optional. Makes the kit a multicolour unit; see below |
| `auto_eject` | Optional, with `grants: ["auto_eject"]`. Makes the kit an auto-eject plate: `tray` is how many prints the tray beside the printer holds. A good or flawed print is thrown off the plate as it finishes, onto the conveyor if the building has one and the shelving has room, or else into the tray. A failed print still has to be cleared by hand. A printer with one, told to keep its job going, restarts itself |
| `fixture` | Optional. The kit goes on the building, not a printer, and no printer will take it. `conveyor` is fitted from the `Conveyor` controls in a scene that has them (the factory), and carries prints from auto-eject plates to the shelving. `moulder` is the injection moulding machine, installed on the factory's `MouldingMachine` bay. The scene node a fixture goes on is in a group of the same name |
| `grants` | Printer capability fields it switches on, e.g. `auto_bed_levelling`. It can't be fitted to a printer that already has one of them |
| `failure_multipliers` | Failure id to multiplier on that failure's weight. The chance of a print failing at all shrinks by the share of weight removed (`PrintRisk.upgrade_scale`) |
| `time_multiplier` | Applied to print time |
| `wear_multiplier` | Applied to the wear of every part |

### Multicolour units

A unit is an upgrade with `grants: ["multicolour"]` (so a printer takes only one) and a `multicolour` block. Imported from `docs/design_data/accessories.json` (`multicolour_units`): the four slot Spare room units that fit a printer the game has. The five slot Kestrel unit and the Workshop and Factory units are not in yet. The printer has to be empty of filament to have its first unit fitted.

| Field | Meaning |
| --- | --- |
| `slots` | Spools it holds. No more than the unit model has `spool_slot_*` markers |
| `max_linked` | How many of this unit one printer can have, the first included. Each further one is the same kit bought again and fitted to the same printer; it stacks on the last and adds its slots. The design allows up to 4; 2 is the most there is height for on the bench |
| `swap_seconds` | Real seconds a colour change takes, added to the print as game minutes |
| `purge_grams_per_swap` | Filament thrown away on each colour change, before the extra for contrast |
| `jam_chance_per_swap` | Added to the chance of the print failing, for each colour change. Against the game's `multicolour.reference_jam_chance` it also scales how often the failure is a jam |
| `soft_filament` | True if it is built for TPU. Otherwise TPU through it raises `tpu_in_multicolour` |
| `keeps_dry` | True if spools in it take up no moisture |
| `parts` | Ids from `parts.json` that come with it and wear alongside the printer's own |
| `model` | Its model file in `assets/models/printers/`. Each unit has its own (`unit_<id>`) |

A full colour print of a design changes colour `colour_swaps` times. Each change purges `purge_grams_per_swap x (1 + contrast_purge x contrast)`, where contrast is the average step up in lightness from one colour to the next, going round them in order (`Multicolour.contrast`): dark next to light wastes more than two close shades. The first colour takes `main_colour_share` of the design's filament and the others share the rest; the purged filament is split evenly between the spools.

## parts.json

Wear parts. Imported from `docs/design_data/parts.json`: one part for each slot in the GDD's list (nozzle, hotend, build plate, belts, PTFE tube, fans), plus the feeder rollers and nozzle wiper that come with a multicolour unit. The other Garage parts, alternative parts for a slot and upgrades are not in yet. Prices are the design's base prices; brand multipliers and own-brand parts are not applied.

| Field | Meaning |
| --- | --- |
| `slot`, `slot_name` | Where it fits (a printer has one part per slot) and what to call that in text |
| `model` | Its model file in `assets/models/parts/`, shown in the shop and on the shelving |
| `lifespan_print_hours` | Print hours from new to broken on a 1.0 wear printer at Standard, before the game's `wear_rate` |
| `abrasive_wear_multiplier` | Applied to wear when printing a filament with `abrasive` set |
| `max_extra_fail` | Added to the chance of every print failing when the part is at 0%. Nothing is added above 30% health, rising evenly below it |
| `replace_minutes` | Character time to fit a spare |
| `price_pence`, `pack_size` | Shop price of a pack, and how many spares are in it |
| `break_text` | The message when it gives out mid-print |

Health lost per print hour is `printer wear_multiplier x game wear_rate x preset wear_multiplier / lifespan_print_hours` (`PrinterWear.wear_per_hour`). At nothing the part is broken and the printer can't print until a spare is fitted.

## dryers.json

Filament dryers. Imported from `docs/design_data/accessories.json` (`dryers`): one Garage dryer and one for the small unit. Dry boxes, which only slow moisture down, are not in yet. The premises hold one dryer.

| Field | Meaning |
| --- | --- |
| `capacity` | Spools it holds at once. Its model needs a `spool_slot_<n>` marker for each |
| `model` | Its model file in `assets/models/props/` |
| `hours_to_dry` | Game hours to take a soaked spool of plain PLA to dry. A spool takes its share of that, times its filament's `drying_multiplier` |
| `power_watts` | Charged as electricity for the time it spends drying |
| `dries` | Filament families it gets hot enough for |

## premises.json

The places the business can run from, smallest first.

| Field | Meaning |
| --- | --- |
| `tier` | The tier the business is at once it moves in. Shops sell rows whose `unlock_tier` is no higher |
| `scene` | The scene for the place. It needs the same parts as the garage scene (see `WorldSave.PARTS`), each with at least as many slots as the place before, so everything fits when the business moves |
| `move_cost_pence` | Paid once to move in |
| `rent_pence_per_day` | Charged at midnight every game day |
| `staff` | How many staff the place has room for: none in the garage, one in the small unit, then more. Staff also need a `StaffRoom` node in the scene, where they come in |
| `max_printers` | The most places for printers the premises can have, on its own benches and on bought benches and racks together. More than `printer_spots`, so that taking benches out for racks is worth it |
| `shelf_units`, `rack_units` | How many bays of shelving and how many filament racks the place has room for, counting the one in the scene. The rest are bought (fittings.json) |
| `printer_spots`, `shelf_slots`, `rack_slots` | Shown on the place's card. They describe the scene; they don't set it. A scene with several benches still has one `Workbench`, whose `printer_spots` reach onto the others |

## contracts.json

`clients`: the businesses that send contract enquiries (`Contracts`). Written for the game; the design data has no clients, only the contract only products.

| Field | Meaning |
| --- | --- |
| `name`, `about` | Shown in the Inbox. Parody names only |
| `categories` | Product categories it buys. It asks for designs the business owns in these |
| `supplies` | Optional. Ids of `contract_only` products it brings itself, which the business can print for it without owning them |
| `quantity` | `[fewest, most]` items in one contract |
| `price_multiplier` | `[lowest, highest]` multiple of the design's `base_price_pence` it pays for each. There are no marketplace fees on a contract |
| `slack` | `[tightest, loosest]`. The time allowed is the quantity's print time, on the game's `contracts.assumed_printers`, times this, and never less than a day |
| `min_quality`, `min_durability` | The lowest finish and strength (1 to 5) it takes. `min_durability` is optional. It never takes a flawed item, or a multicolour design printed in one colour |
| `late_pct_per_day` | Share of the whole price knocked off for each day, or part of one, past the deadline |
| `asks` | Things it writes, one picked at random for each enquiry |
| `assumed_printers` | Optional. How many printers this client assumes when working out the time to allow, in place of the game's `contracts.assumed_printers`. The factory's clients assume a farm, so they allow less time for each item |

## events.json

`events`: things that happen to the business from outside (`Events`). One starts every few days. Written for the game, from the list in the GDD.

| Field | Meaning |
| --- | --- |
| `kind` | What it does. `demand` scales orders for one design and `price` the price of one filament, both by `multiplier` for as long as it lasts. `power_cut` stops every print in progress (the `power_cut` failure). `client_bust` ends one contract, paid at the cut rate for what had arrived |
| `target` | What it happens to, and so what there has to be for it to happen at all: `product` (a design listed for sale), `filament` (one in stock), `printing` (a print running) or `contract` (one in progress) |
| `weight` | How often it is the one picked, relative to the others |
| `days` | `[shortest, longest]` it lasts, in game days. `[0, 0]` for one that is over at once |
| `multiplier` | For `demand` and `price` |
| `tone` | `good` or `bad`, for the colour of its message and its card in the Inbox |
| `text`, `over` | What the player is told when it starts and when it ends. `{what}` is the design, filament or client |

## milestones.json

`milestones`: the firsts and totals the sandbox points the player at (`Milestones`), in the order the Stats app lists them.

| Field | Meaning |
| --- | --- |
| `name`, `description` | Shown in the Stats app and when it is reached. `{amount}` in the description is `at` as money |
| `stat` | The figure it is judged on: `sales`, `best_month_pence`, `best_streak`, `contracts_done`, `largest_contract`, `staff_hired` (`Game.stats`) or `tier` |
| `at` | The value the figure has to reach |

## staff.json

Written for the game; the design data has no staff. Every number is a placeholder.

`roles`: the jobs staff can be taken on to do.

| Field | Meaning |
| --- | --- |
| `name`, `description` | Shown in the Rota app |
| `unlock_tier` | The tier from which people apply for the job. All three open at tier 2, where the small unit has room for one of them, so which to take on is the player's choice |
| `wage_pence_per_day` | Charged at midnight for every day the person is on the team, shift worked or not |
| `duties` | The kinds of task they look for, most pressing first. Each matches the `duty` of an `Action` in the code: `clear` (a failed print), `collect` (a finished one), `reprint` (start a printer's last job again, if the printer is set to keep going), `pack` (an order), `send` (a contract crate) |

`shifts`: the hours staff can work, by `id`, with a `name` and a `start_minute` and `end_minute` of the day. A new hire starts on the first.

Beside the tables: `applicants` is how many people apply each day (the first few cover every role), `looks` the character models they can have, and `names` what they can be called.

## game.json

Starting conditions and global rates. Not a table of rows.

| Field | Meaning |
| --- | --- |
| `tier_names` | What tiers 1 to 4 are called |
| `start.cash_pence`, `start.packaging`, `start.designs`, `start.premises`, `start.minute_of_day` | What a new game begins with |
| `electricity_pence_per_kwh` | Charged when a print finishes, from the printer's `power_watts` and the print time |
| `courier_minute_of_day` | When parcels in the outbox are collected and paid |
| `work_day.start_minute`, `work_day.end_minute` | The working day when the owner is on their own. After the end the night can be skipped to the next start. With staff the day ends when the last of their shifts does, if that is later |
| `work_day.night_speed` | How many times faster than 1x the game runs while the night is skipped |
| `shipping` | `default_service`: the service a marketplace sends by until the player picks another, and a parcel goes by if the one picked won't take it. `buyer_pays`: speed class to the service whose price the buyer is charged for postage (anything quicker than standard is charged at the standard rate). `late_minutes`: `[shortest, longest]` a held up parcel is delayed, and `late_star_penalty` what the buyer knocks off for it. `stars_per_presentation_point`: stars a review moves for each point the packaging's `presentation` is above or below `neutral_presentation`. `speed_stars`: stars added by speed class |
| `storage_bins` | Printed storage bins (`StorageRules`). `designs`: design id to the units of room a bin printed from it has. `sizes`: the size classes, smallest first, each with a `name`, the longest side in mm a design may have to count as it (`max_mm`, none on the last) and the units one print of that size takes up (`cost`) |
| `resale` | Selling a printer second hand: it fetches its price new times `worn_out` (every part spent) to `as_new` (every part fresh), by the average health of its parts. `pack_minutes` to box it, `scrap_minutes` to strip one for the bin, `box_minutes` to box one up to keep. A bought fitting (shelving, a rack, a bench) sells for `fitting_share` of its price, once it is empty |
| `finishing` | The finishing bench: `minutes` of the character's time for one print, the `quality_gain` it gets and the `max_quality` it stops at. A print can be finished once |
| `default_preset` | The preset the print dialog opens on |
| `moisture` | `gain_per_day`: moisture (0 to 1) a filament with sensitivity 1.0 gains in a day in the open. `wet_at`: the level at which a spool is wet. Every `step` beyond that adds `extra_fail_per_step` to the chance of a print failing, and wet filament raises the `wet_filament` flag for failures |
| `multicolour` | `main_colour_share`: the share of a multicolour print's filament its first colour takes. `contrast_purge`: how much more a colour change purges going from black to white. `many_swaps`: colour changes at which a print raises `many_colour_swaps`. `reference_jam_chance`: the `jam_chance_per_swap` of a unit that jams as often as the jam failure's `weight` says |
| `moulding` | Rules for the injection moulding machine (`Moulding`). A mould for a design costs `mould_fee_multiple` times its `base_price_pence`, and at least `mould_fee_min_pence`, and takes `mould_days` to arrive. A run is `batch` items, each taking `minutes_per_item`, after `setup_minutes` of the character's time, and uses the design's `filament_grams` in pellets at `pellet_pence_per_kg`; `power_watts` is charged for the run. The output bin holds `output_capacity`. Moulded items come in the `colours` listed, at `quality` and `durability`, and on the shelf count as printed at `sold_as_preset` in `sold_as_filament` |
| `events` | `unlock_tier`: the tier from which events happen. `days`: `[shortest, longest]` gap between one starting and the next |
| `contracts` | `unlock_tier`: the tier at which clients start writing. `offers_per_day`: enquiries a day, while fewer than `max_offers` are waiting; each waits `offer_minutes` for an answer. `max_active`: contracts that can run at once. `assumed_printers`: printers a client assumes when working out how long to allow. `colour_chance`: chance an enquiry for a single colour design names the colour. `max_late_days`: days late past which the client cancels, paying `failed_pay_multiplier` of the price for what arrived. `pack_minutes_per_item`: character time to crate each item |
| `stock` | `unlock_tier`: the tier at which the Stockroom app's reorder rules switch on. `check_minutes`: how often, in game minutes, the rules are checked |
| `design` | Rules for the business's own designs (`DesignStudio`). `unlock_tier`: when they become possible. `base_minutes`: PC time for a V1, times (1 + the item's difficulty); an iteration takes `iteration_time` of that, a fix `fix_minutes`. Quality starts at `base_quality` plus a skill level for every `designs_per_skill_level` designs finished (to `max_skill`), rises by one per iteration to `max_version`, and stops at `max_quality`. `fault_chance`, less `fault_chance_per_skill` per skill level, is the chance a new version hides a fault. Demand for an own design is `appeal_base + appeal_per_quality x quality` times the bought design's |
| `trends` | One product category is in demand and one has gone quiet, for a random `days` range (`[shortest, longest]`), scaling its orders by `hot_multiplier` or `cool_multiplier`. Only categories with at least `min_designs` designs take part, and never those listed in `seasonal`, which wait for a calendar (`Trends`) |
| `colour_taste` | The colours buyers like a design best in (`ColourTaste`). Each design has up to `favourites` of them, out of the colours its `allowed_filaments` come in: first those listed for its category in `categories`, then whichever suit the design itself. A listing's orders scale with the last `window` sent: by `liked_demand` if all were in a favourite colour, `other_demand` if none were, and in between otherwise. A product row may name its own with `popular_colours` |
| `wear_rate` | Multiplies all part wear. Above 1 because the design's lifespans are in real printer hours, which would take many sessions to matter. A balancing knob |
| `bank_name`, `business_name` | Names shown on the PC. `business_name` is only what a new business is called if the player doesn't name it |
| `tips` | Lines for the loading screen, one shown each time. Each a sentence or two a non printer owner could follow |
| `supplier` | The filament and hardware shop names, lead times in game minutes (filament, printers, spare parts) |

One game day is 1440 game minutes and lasts 10 real minutes at 1x (`GameClock.MINUTES_PER_SECOND`).

## fittings.json

Storage that is bought and stood wherever the player likes.

| Field | Meaning |
| --- | --- |
| `kind` | `shelf` (spaces for prints and spares, added to the premises' shelving), `rack` (slots for spools, added to its filament rack) or `bench` (a printer rack: places for printers, added to its workbench) |
| `model` | Model in `assets/models/furniture/`. Its `item_slot_*`, `spool_slot_*` or `printer_spot_*` markers are the room it adds |
| `stand_offset` | Where the character stands to use it, from its origin |
| `price_pence`, `unlock_tier` | As elsewhere |

A `bench` row also has `printer_spots`: where on it each printer stands, as `[x, y, z]` from its origin, and may set `units_beside`: there is no room above a printer on it for a multicolour unit, which has to sit in a colour unit rack close by. A `units` row is such a rack: `unit_bays` is where in it each unit sits. It feeds printers within the `rack_link_metres` of the `multicolour` settings in game.json, and there is no limit on how many a place has.

How many shelving units and racks a place holds is on its row in premises.json: `shelf_units` and `rack_units`, each counting the one built in to the scene. Benches and printer racks are limited together, by the places for printers they add up to: the row's `max_printers`.

## packaging.json

What an order goes out in. Kept, counted by kind, at the packing station (`Game.packaging`).

| Field | Meaning |
| --- | --- |
| `kind` | `bag` or `box`. A design goes out in the cheapest box that fits unless the player picks something else for it |
| `fits_bands` | The parcel bands it is made for (see couriers.json). A design fits packaging made for its own band or a bigger one; in a bigger one the parcel is posted at that size (`Shipping.parcel_band`) |
| `protection` | 1 to 5. A parcel arrives broken with chance `(5 - durability) x 2% x (6 - protection) / 3 x` the service's `damage_multiplier` (`Marketplace.damage_chance`) |
| `presentation` | 1 to 5. Moves the buyer's review (the `shipping` settings in game.json) |
| `pack_minutes` | Character time to pack an order in it |
| `pack_size`, `price_pence` | How many come in a pack, and what the pack costs |
| `weight_grams` | From the design data. Not used yet |
| `model` | Its models in `assets/models/packaging/`: `<model>.glb` made up as a parcel, with `flap_*` meshes the game opens and shuts, and `<model>_stack.glb` flat in a pile. Both built by `tools/generators/parcels.py` from `look` (`colour`, `accent`, `size` in metres) |

Imported from `docs/design_data/shipping.json` (`packaging`): the ten bags and boxes. Crates, pallets and inner bags are not in, nor the fillers and extras. Prices are the design's price each, in packs of ten.

## couriers.json

Three lists: `bands`, `couriers` and `services`.

A band is a size of parcel, smallest first: `max_size_mm` (longest side first) and `max_weight_grams`. A design falls in the smallest band it fits by its `size_mm` and `filament_grams` (`Shipping.band_of`).

A courier has a `name`, `tagline`, `description` and `colour`. A service is one thing a courier offers:

| Field | Meaning |
| --- | --- |
| `courier` | Id of the courier |
| `speed` | `economy`, `standard`, `express`, `priority` or `same_day`. Decides what the buyer pays towards postage and moves the review (the `shipping` settings in game.json) |
| `delivery_minutes` | `[shortest, longest]` from collection to the buyer's door |
| `prices` | Band id to what the seller pays, in pence. A band not listed is one the service won't take |
| `damage_multiplier` | How rough it is with a parcel. See `protection` above |
| `lost_chance` | Chance (0 to 1) a parcel never arrives: refunded, one star |
| `late_chance` | Chance (0 to 1) it is held up for `late_minutes` and marked down |
| `tracked`, `insured_pence` | A tracked service pays out for a parcel it loses, up to this much |

Each marketplace sends by one service, picked in its app (`Game.service_choice`). The buyer pays the going rate for the speed promised and the seller pays the courier, so a cheaper service leaves a little over and a dearer one costs. What an order was packed in and sent by is recorded on it when it is packed (`Shipping.terms`).

Imported from `docs/design_data/shipping.json` (`parcel_bands`, `couriers`, `services`). FreightFolk and GlobeHop are not in: nothing goes by the pallet and there are no buyers abroad. Collection fees, drop off walks and order cut off times are not modelled: one courier run a day takes everything.

## research.json

What the owner can study at the PC (`Research`, the Skillshed app).

`branches`: the boughs of the skill tree, top to bottom.

| Field | Meaning |
|---|---|
| `id`, `name` | Key and what the player reads |
| `colour` | Hex colour that marks the branch in the app |
| `about` | One line on what the branch is for |

`courses`: in the order they are taught within a branch. The tree places each one a step along from the course it `requires`.

| Field | Meaning |
|---|---|
| `id`, `name`, `description` | Key and what the player reads |
| `icon` | Line icon on its badge in the tree, a file name in `assets/ui/icons/` without `.svg` |
| `branch` | Id of the branch it belongs to |
| `unlock_tier` | Premises tier needed to take it |
| `requires` | Id of the course that must be learned first, or "" |
| `minutes` | Game minutes of study at the desk |
| `fee_pence` | Paid once, on starting |
| `effects` | Multipliers once learned, by key: `fail_chance`, `print_time`, `clear_time`, `wear`, `replace_time`, `worn_risk` (the failure risk worn parts add), `spool_price`, `parts_price`, `packaging_price`, `lead_time` (supplies, not printers). Every learned course's multiply together |
