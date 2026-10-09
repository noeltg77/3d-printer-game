class_name FilamentRules
extends RefCounted
## What can be printed in what: whether a printer can run a filament, whether
## a design works in it, and the "material:colour" keys that orders and
## deliveries name spools by. Works on rows from data/filaments.json,
## printers.json, products.json and parts.json.

const DEFAULT_MATERIAL := "pla"
## How a printer makes things, and so what it can be fed: a printer's `kind`
## and a filament's `process`. Either is filament printing unless it says otherwise.
const DEFAULT_PROCESS := "fdm"


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


## True if any design in the game can be printed in a filament.
static func has_a_use(products: Dictionary, filament: Dictionary) -> bool:
	return products.values().any(func(product: Dictionary) -> bool: return suits(product, filament))


## True if printing this filament will chew through the nozzle fitted
## (`nozzle` is its row from data/parts.json).
static func wears_nozzle(filament: Dictionary, nozzle: Dictionary) -> bool:
	return filament["abrasive"] and float(nozzle["abrasive_wear_multiplier"]) > 1.0


## "pla_silk:pink". How a basket or a delivery names one spool.
static func spool_key(material: String, colour: String) -> String:
	return "%s:%s" % [material, colour]


## Material id from a spool key. A key with no material is PLA.
static func material_of(key: String) -> String:
	return key.get_slice(":", 0) if key.contains(":") else DEFAULT_MATERIAL


## Colour name from a spool key.
static func colour_of(key: String) -> String:
	return key.get_slice(":", 1) if key.contains(":") else key
