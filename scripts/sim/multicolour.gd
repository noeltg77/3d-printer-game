class_name Multicolour
extends RefCounted
## The rules for printing in more than one colour: how a design's filament is
## shared between its colours, how often the printer changes colour, and what
## each change costs in purged filament, time and the risk of a jam.
##
## `unit` is the `multicolour` block of a row in data/upgrades.json, or {} for a
## printer with no unit. `settings` is the `multicolour` block of data/game.json.

## Family of the soft filaments that jam in a unit not built for them.
const SOFT_FAMILY := "tpu"
## Condition flag for a print fed through a unit. Failures that `require` it
## can't happen without one.
const UNIT_FLAG := &"multicolour_unit"
const JAM_FAILURE := "filament_jam_feeder"


## How many colours a design is made for.
static func colours_of(product: Dictionary) -> int:
	return maxi(int(product.get("colour_count", 1)), 1)


## The share of a print's filament each colour takes: the first colour is the
## body of the thing, and the rest split what is left evenly.
static func shares(colours: int, settings: Dictionary) -> Array[float]:
	var found: Array[float] = []
	if colours <= 1:
		found.append(1.0)
		return found
	var main := float(settings["main_colour_share"])
	found.append(main)
	for i in colours - 1:
		found.append((1.0 - main) / (colours - 1))
	return found


## Colour changes in one print of a design in `colours` colours. A print in one
## colour never changes.
static func swaps(product: Dictionary, colours: int) -> int:
	return int(product.get("colour_swaps", 0)) if colours > 1 else 0


## How much lighter the next colour is, on average, going round the colours in
## order and back to the first. `lightness` is 0 (black) to 1 (white) for each.
## Going from dark to light takes more purging; light to dark takes no extra.
static func contrast(lightness: Array[float]) -> float:
	if lightness.size() < 2:
		return 0.0
	var rise := 0.0
	for index in lightness.size():
		rise += maxf(lightness[(index + 1) % lightness.size()] - lightness[index], 0.0)
	return rise / lightness.size()


## Grams thrown away on the colour changes of one print.
static func purge_grams(unit: Dictionary, changes: int, lightness: Array[float], settings: Dictionary) -> float:
	if unit.is_empty():
		return 0.0
	return changes * float(unit["purge_grams_per_swap"]) * (1.0 + float(settings["contrast_purge"]) * contrast(lightness))


## Grams each colour's spool gives up: its share of the print, plus an even
## share of what is purged.
static func grams_by_colour(print_grams: float, colours: int, purged: float, settings: Dictionary) -> Array[float]:
	var found: Array[float] = []
	for share in shares(colours, settings):
		found.append(print_grams * share + purged / colours)
	return found


## Game minutes the colour changes add to a print.
static func swap_minutes(unit: Dictionary, changes: int) -> float:
	return changes * float(unit["swap_seconds"]) / 60.0 if not unit.is_empty() else 0.0


## Chance (0 to 1) the colour changes add to a print failing.
static func jam_chance(unit: Dictionary, changes: int) -> float:
	return clampf(changes * float(unit["jam_chance_per_swap"]), 0.0, 1.0) if not unit.is_empty() else 0.0


## Condition flags for a print fed through a unit, for PrintRisk.
static func flags(unit: Dictionary, filament: Dictionary, changes: int, settings: Dictionary) -> Array[StringName]:
	var found: Array[StringName] = []
	if unit.is_empty():
		return found
	found.append(UNIT_FLAG)
	if is_soft(filament) and not unit["soft_filament"]:
		found.append(&"tpu_in_multicolour")
	if changes >= int(settings["many_swaps"]):
		found.append(&"many_colour_swaps")
	return found


## How a unit scales the weight of its own jam failure: a unit that jams twice
## as often per change as the reference one counts double.
static func failure_multipliers(unit: Dictionary, settings: Dictionary) -> Dictionary:
	if unit.is_empty():
		return {}
	return {JAM_FAILURE: float(unit["jam_chance_per_swap"]) / float(settings["reference_jam_chance"])}


static func is_soft(filament: Dictionary) -> bool:
	return filament.get("family", "") == SOFT_FAMILY


## Picks the spools to print a design from, out of what is loaded. `loaded` has
## one entry per slot: the id of the filament there, or "" if it is empty or
## can't be used. Returns slot numbers, one per colour: enough spools of one
## filament for every colour if there are, or else the first usable spool alone.
static func pick_slots(loaded: Array[String], colours: int) -> Array[int]:
	var by_material: Dictionary[String, Array] = {}
	var first: Array[int] = []
	for slot in loaded.size():
		if loaded[slot] == "":
			continue
		if first.is_empty():
			first.append(slot)
		if not by_material.has(loaded[slot]):
			by_material[loaded[slot]] = []
		by_material[loaded[slot]].append(slot)
	if colours > 1:
		for material in by_material:
			if by_material[material].size() >= colours:
				var picked: Array[int] = []
				picked.assign(by_material[material].slice(0, colours))
				return picked
	return first
