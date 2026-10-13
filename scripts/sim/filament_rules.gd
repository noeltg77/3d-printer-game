class_name FilamentRules
extends RefCounted
## What can be printed in what: whether a printer can run a filament, whether
## a design works in it, and the "material:colour" keys that orders and
## deliveries name spools by ("material:colour:bulk" for a 5 kg reel). Works on rows from data/filaments.json,
## printers.json, products.json and parts.json.

const DEFAULT_MATERIAL := "pla"
## How a printer makes things, and so what it can be fed: a printer's `kind`
## and a filament's `process`. Either is filament printing unless it says otherwise.
const DEFAULT_PROCESS := "fdm"
## The last part of the key of a big reel, where a spool's key has none.
const BULK := "bulk"


## Why a printer can't print a filament, or "" if it can. `printer` is its row
## with any upgrades already applied (PrinterMods.apply).
static func problem(printer: Dictionary, filament: Dictionary) -> String:
	var process: String = filament.get("process", DEFAULT_PROCESS)
	if printer.get("kind", DEFAULT_PROCESS) != process:
		return "%s needs a resin printer" % filament["name"] if process == "resin" else "A resin printer takes resin, not filament"
	if float(printer["max_nozzle_temp_c"]) < float(filament["nozzle_temp_c"]):
		return "It can't get hot enough for %s" % filament["name"]
	if filament["requires"]["enclosure"] and not printer["enclosed"]:
		return "%s needs an enclosed printer" % filament["name"]
	if filament["requires"]["direct_drive"] and not printer["direct_drive"]:
		return "%s needs a direct drive printer" % filament["name"]
	return ""


## True if a design can be printed in a filament: its `allowed_filaments` names
## either the filament itself or the family it belongs to.
static func suits(product: Dictionary, filament: Dictionary) -> bool:
	var allowed: Array = product["allowed_filaments"]
	return allowed.has(filament["id"]) or allowed.has(filament["family"])


## Why none of these printers can print a design, or "" if at least one can.
## Each printer is its row with any upgrades applied; `filaments` is the whole
## table. With no printers to judge by there is no problem to report.
static func design_problem(printers: Array[Dictionary], product: Dictionary, filaments: Dictionary) -> String:
	if printers.is_empty():
		return ""
	var big_enough := printers.filter(func(printer: Dictionary) -> bool: return PrintRisk.fits(printer, product))
	if big_enough.is_empty():
		var size: Array = product["size_mm"]
		return "It is too big for your printers: %d x %d x %d mm" % [int(size[0]), int(size[1]), int(size[2])]
	var reason := ""
	for printer: Dictionary in big_enough:
		for filament: Dictionary in filaments.values():
			if not suits(product, filament):
				continue
			var why := problem(printer, filament)
			if why == "":
				return ""
			if reason == "":
				reason = why
	return reason


## True if any design in the game can be printed in a filament.
static func has_a_use(products: Dictionary, filament: Dictionary) -> bool:
	return products.values().any(func(product: Dictionary) -> bool: return suits(product, filament))


## True if printing this filament will chew through the nozzle fitted
## (`nozzle` is its row from data/parts.json).
static func wears_nozzle(filament: Dictionary, nozzle: Dictionary) -> bool:
	return filament["abrasive"] and float(nozzle["abrasive_wear_multiplier"]) > 1.0


## "pla_silk:pink". How a basket or a delivery names one spool. A big reel
## of it is "pla:pink:bulk".
static func spool_key(material: String, colour: String, bulk := false) -> String:
	return "%s:%s:%s" % [material, colour, BULK] if bulk else "%s:%s" % [material, colour]


## True if a spool key names a big reel.
static func is_bulk(key: String) -> bool:
	return key.get_slice_count(":") > 2 and key.get_slice(":", 2) == BULK


## True if a filament is sold on big reels as well as on spools.
static func has_bulk(filament: Dictionary) -> bool:
	return filament.has("bulk_grams")


## Grams on a new spool of a filament, or on a new big reel of it.
static func new_grams(filament: Dictionary, bulk := false) -> float:
	return float(filament["bulk_grams"] if bulk else filament["spool_grams"])


## "5 kg" or "750 g": a weight of filament as a shop would put it.
static func weight_label(grams: float) -> String:
	if grams >= 1000.0:
		return "%s kg" % String.num(grams / 1000.0, 1).trim_suffix(".0")
	return "%d g" % roundi(grams)


## Material id from a spool key. A key with no material is PLA.
static func material_of(key: String) -> String:
	return key.get_slice(":", 0) if key.contains(":") else DEFAULT_MATERIAL


## Colour name from a spool key.
static func colour_of(key: String) -> String:
	return key.get_slice(":", 1) if key.contains(":") else key
