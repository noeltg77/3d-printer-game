class_name PrinterWear
extends RefCounted
## The wear parts fitted to one printer and how healthy each is. Parts lose
## health with every hour printed. Below 30% a part starts adding to the chance
## of a print failing, and at nothing it breaks and the printer can't print
## until a new one is fitted. Works on rows from data/parts.json.

## Health (0 to 1) below which a part counts as worn.
const WORN_BELOW := 0.3
## Health at or below this is broken. Allows for rounding when a part runs out.
const BROKEN_AT := 0.0001

## Parts table by id.
var parts: Dictionary
## Slot -> id of the part fitted there.
var fitted: Dictionary[StringName, StringName] = {}
## Slot -> health, 1.0 new to 0.0 broken.
var health: Dictionary[StringName, float] = {}
## The printer's own wear multiplier times the game's wear rate.
var rate := 1.0


## Fits a new printer with the parts it ships with. `wear_rate` is the global
## rate from data/game.json.
func _init(p_parts: Dictionary, printer: Dictionary, wear_rate := 1.0) -> void:
	parts = p_parts
	rate = float(printer.get("wear_multiplier", 1.0)) * wear_rate
	for part_id: String in printer.get("parts", []):
		replace(StringName(parts[part_id]["slot"]), StringName(part_id))


func slots() -> Array[StringName]:
	var found: Array[StringName] = []
	found.assign(fitted.keys())
	return found


## Row of the part fitted in a slot.
func part(slot: StringName) -> Dictionary:
	return parts[fitted[slot]]


## Fits a new part, at full health.
func replace(slot: StringName, part_id: StringName) -> void:
	fitted[slot] = part_id
	health[slot] = 1.0


## Health a part loses for each hour of printing with this preset and filament.
func wear_per_hour(slot: StringName, preset: Dictionary, filament: Dictionary) -> float:
	var row := part(slot)
	var abrasion := float(row["abrasive_wear_multiplier"]) if filament["abrasive"] else 1.0
	return rate * float(preset["wear_multiplier"]) * abrasion / float(row["lifespan_print_hours"])


## Wears every part by `hours` of printing.
func apply(hours: float, preset: Dictionary, filament: Dictionary) -> void:
	for slot in slots():
		damage(slot, hours * wear_per_hour(slot, preset, filament))


## Takes health straight off a part, as a failure that damages it does.
func damage(slot: StringName, amount: float) -> void:
	if health.has(slot):
		health[slot] = clampf(health[slot] - amount, 0.0, 1.0)


## The first part to run out during a print of `hours`, as { slot, at } with
## the progress (0 to 1) at which it breaks. {} if they all last.
func breaks_during(hours: float, preset: Dictionary, filament: Dictionary) -> Dictionary:
	var first := {}
	for slot in slots():
		var lost := hours * wear_per_hour(slot, preset, filament)
		if lost <= 0.0 or health[slot] > lost:
			continue
		var at := health[slot] / lost
		if first.is_empty() or at < first["at"]:
			first = {"slot": slot, "at": at}
	return first


func is_worn(slot: StringName) -> bool:
	return health[slot] < WORN_BELOW


func is_broken(slot: StringName) -> bool:
	return health[slot] <= BROKEN_AT


## Slots whose part has broken.
func broken() -> Array[StringName]:
	var found: Array[StringName] = []
	for slot in slots():
		if is_broken(slot):
			found.append(slot)
	return found


## The slot in the worst state, or empty if nothing is fitted.
func worst() -> StringName:
	var found: StringName = &""
	for slot in slots():
		if found == &"" or health[slot] < health[found]:
			found = slot
	return found


## Chance of failure (0 to 1) the worn parts add to every print: each part adds
## nothing at 30% health, rising evenly to its `max_extra_fail` at 0%.
func extra_fail_chance() -> float:
	var extra := 0.0
	for slot in slots():
		extra += float(part(slot)["max_extra_fail"]) * clampf((WORN_BELOW - health[slot]) / WORN_BELOW, 0.0, 1.0)
	return extra


## Condition flags for the worn parts, e.g. `worn_nozzle`, for PrintRisk.
func flags() -> Array[StringName]:
	var found: Array[StringName] = []
	for slot in slots():
		if is_worn(slot):
			found.append(StringName("worn_%s" % slot))
	return found
