class_name PrinterMods
extends RefCounted
## The upgrades fitted to one printer and what they add up to: capabilities the
## printer didn't come with, failures made less likely, faster prints and
## slower wear. Works on rows from data/upgrades.json.

const MOTION_NAMES := {"bed_slinger": "bed slinger", "core_xy": "core XY"}

## Upgrades table by id.
var upgrades: Dictionary
## Ids of the upgrades fitted, in the order they went on.
var fitted: Array[StringName] = []


func _init(p_upgrades: Dictionary) -> void:
	upgrades = p_upgrades


func has(upgrade: StringName) -> bool:
	return fitted.has(upgrade)


## Why an upgrade can't go on this printer (a row from data/printers.json), or
## "" if it can.
func problem(upgrade: StringName, printer: Dictionary) -> String:
	var row: Dictionary = upgrades[upgrade]
	if has(upgrade):
		return "Already fitted"
	var motions: Array = row["fits_motion"]
	if not motions.is_empty() and not motions.has(printer["motion"]):
		return "Doesn't fit a %s printer" % MOTION_NAMES.get(printer["motion"], printer["motion"])
	for capability: String in row["grants"]:
		if apply(printer).get(capability, false):
			return "This printer already has it built in"
	return ""


func fit(upgrade: StringName) -> void:
	if not has(upgrade):
		fitted.append(upgrade)


## The printer's row with every capability the upgrades grant switched on.
func apply(printer: Dictionary) -> Dictionary:
	var improved := printer.duplicate()
	for upgrade in fitted:
		for capability: String in upgrades[upgrade]["grants"]:
			improved[capability] = true
	return improved


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
	return {"fitted": fitted}


## Puts back saved upgrades, leaving out any the game no longer has.
func restore(data: Dictionary) -> void:
	fitted.clear()
	for upgrade: String in data["fitted"]:
		if upgrades.has(upgrade):
			fit(StringName(upgrade))


func _product(field: String) -> float:
	var total := 1.0
	for upgrade in fitted:
		total *= float(upgrades[upgrade][field])
	return total
