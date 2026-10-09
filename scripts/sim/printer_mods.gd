class_name PrinterMods
extends RefCounted
## The upgrades fitted to one printer and what they add up to: capabilities the
## printer didn't come with, failures made less likely, faster prints and
## slower wear. A multicolour unit is an upgrade too: its row carries a
## `multicolour` block (see Multicolour). Works on rows from data/upgrades.json.

const MOTION_NAMES := {"bed_slinger": "bed slinger", "core_xy": "core XY"}

## Upgrades table by id.
var upgrades: Dictionary
## Ids of the upgrades fitted, in the order they went on.
var fitted: Array[StringName] = []
## Further multicolour units linked to the first one, for more slots.
var linked := 0


func _init(p_upgrades: Dictionary) -> void:
	upgrades = p_upgrades


func has(upgrade: StringName) -> bool:
	return fitted.has(upgrade)


## Why an upgrade can't go on this printer (a row from data/printers.json), or
## "" if it can.
func problem(upgrade: StringName, printer: Dictionary) -> String:
	var row: Dictionary = upgrades[upgrade]
	if has(upgrade):
		# Another of the multicolour unit already on links to it, up to its limit.
		if not row.has("multicolour"):
			return "Already fitted"
		return "" if unit_count() < int(row["multicolour"].get("max_linked", 1)) else "No more of these can be linked"
	var motions: Array = row["fits_motion"]
	if not motions.is_empty() and not motions.has(printer["motion"]):
		return "Doesn't fit a %s printer" % MOTION_NAMES.get(printer["motion"], printer["motion"])
	var models: Array = row.get("fits_printers", [])
	if not models.is_empty() and not models.has(printer["id"]):
		return "Doesn't fit the %s" % printer["name"]
	for capability: String in row["grants"]:
		if printer.get(capability, false):
			return "This printer already has it built in"
		if apply(printer).get(capability, false):
			return "This printer already has one"
	return ""


## Fits an upgrade. A second multicolour unit of the kind already on is linked to it.
func fit(upgrade: StringName) -> void:
	if not has(upgrade):
		fitted.append(upgrade)
	elif problem(upgrade, {}) == "":
		linked += 1


## The printer's row with every capability the upgrades grant switched on.
func apply(printer: Dictionary) -> Dictionary:
	var improved := printer.duplicate()
	for upgrade in fitted:
		for capability: String in upgrades[upgrade]["grants"]:
			improved[capability] = true
	return improved


## The multicolour unit fitted (the `multicolour` block of its upgrade row), or
## {} if there isn't one.
func unit() -> Dictionary:
	for upgrade in fitted:
		if upgrades[upgrade].has("multicolour"):
			return upgrades[upgrade]["multicolour"]
	return {}


## How many multicolour units are on: the first and those linked to it.
func unit_count() -> int:
	return 0 if unit().is_empty() else 1 + linked


## Spools the multicolour units hold between them. 0 without one.
func unit_slots() -> int:
	return int(unit().get("slots", 0)) * unit_count()


## Failure id -> multiplier on how likely that failure is, across all upgrades.
func failure_multipliers() -> Dictionary:
	var combined := {}
	for upgrade in fitted:
		var each: Dictionary = upgrades[upgrade]["failure_multipliers"]
		for failure: String in each:
			combined[failure] = float(combined.get(failure, 1.0)) * float(each[failure])
	return combined


## Multiplier on how long prints take.
func time_multiplier() -> float:
	return _product("time_multiplier")


## Multiplier on how fast parts wear.
func wear_multiplier() -> float:
	return _product("wear_multiplier")


func save() -> Dictionary:
	return {"fitted": fitted, "linked": linked}


## Puts back saved upgrades, leaving out any the game no longer has.
func restore(data: Dictionary) -> void:
	fitted.clear()
	linked = 0
	for upgrade: String in data["fitted"]:
		if upgrades.has(upgrade):
			fit(StringName(upgrade))
	linked = clampi(int(data.get("linked", 0)), 0, maxi(int(unit().get("max_linked", 1)) - 1, 0))


func _product(field: String) -> float:
	var total := 1.0
	for upgrade in fitted:
		total *= float(upgrades[upgrade][field])
	return total
