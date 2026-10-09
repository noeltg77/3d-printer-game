class_name GameData
extends RefCounted
## Loads the content tables in res://data and indexes them by id.
## Pure data, no scene dependencies, so simulation code and tests can use it headless.

const TABLES := {
	"printers": "res://data/printers.json",
	"filaments": "res://data/filaments.json",
	"products": "res://data/products.json",
	"marketplaces": "res://data/marketplaces.json",
	"presets": "res://data/presets.json",
	"failures": "res://data/failures.json",
	"parts": "res://data/parts.json",
}
const FAILURE_HAPPENS: PackedStringArray = ["start", "mid", "end"]
const FAILURE_OUTCOMES: PackedStringArray = ["scrap", "stop", "degraded"]
const SETTINGS := "res://data/game.json"

var printers: Dictionary = {}
var filaments: Dictionary = {}
var products: Dictionary = {}
var marketplaces: Dictionary = {}
## Print presets, in the order they are offered.
var presets: Dictionary = {}
var failures: Dictionary = {}
## Wear parts, by id.
var parts: Dictionary = {}
## What each durability score (1 to 5) means, keyed by the score as text.
var durability_labels: Dictionary = {}
## Starting conditions and global rates (data/game.json).
var settings: Dictionary = {}
## Problems found while loading. Empty when the data is valid.
var errors: PackedStringArray = []


static func load_all() -> GameData:
	var data := GameData.new()
	for table: String in TABLES:
		data.set(table, data._load_table(table, TABLES[table]))
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if settings is Dictionary:
		data.settings = settings
	else:
		data.errors.append("%s: expected an object" % SETTINGS)
	var presets_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLES["presets"]))
	if presets_file is Dictionary:
		data.durability_labels = presets_file.get("durability_labels", {})
	data._check_references()
	return data


func _load_table(table: String, path: String) -> Dictionary:
	var by_id := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get(table) is Array:
		errors.append("%s: expected an object with a \"%s\" array" % [path, table])
		return by_id
	for entry: Dictionary in parsed[table]:
		var id: String = entry.get("id", "")
		if id.is_empty():
			errors.append("%s: entry without an id" % path)
		elif by_id.has(id):
			errors.append("%s: duplicate id \"%s\"" % [path, id])
		else:
			by_id[id] = entry
	return by_id


func _check_references() -> void:
	var slots := {}
	for part: Dictionary in parts.values():
		slots[part["slot"]] = true
	for printer: Dictionary in printers.values():
		var fitted := {}
		for part_id: String in printer.get("parts", []):
			if not parts.has(part_id):
				errors.append("printer %s: unknown part \"%s\"" % [printer["id"], part_id])
			elif fitted.has(parts[part_id]["slot"]):
				errors.append("printer %s: two parts in the %s slot" % [printer["id"], parts[part_id]["slot"]])
			else:
				fitted[parts[part_id]["slot"]] = true
		for filament_id: String in printer.get("supported_filaments", []):
			if not filaments.has(filament_id):
				errors.append("printer %s: unknown filament \"%s\"" % [printer["id"], filament_id])
	for product: Dictionary in products.values():
		for filament_id: String in product.get("allowed_filaments", []):
			if not filaments.has(filament_id):
				errors.append("product %s: unknown filament \"%s\"" % [product["id"], filament_id])
	for product_id: String in settings.get("start", {}).get("designs", []):
		if not products.has(product_id):
			errors.append("game.json: unknown starting design \"%s\"" % product_id)
	if not presets.has(settings.get("default_preset", "")):
		errors.append("game.json: unknown default_preset \"%s\"" % settings.get("default_preset", ""))
	for failure: Dictionary in failures.values():
		if not FAILURE_HAPPENS.has(failure.get("happens", "")):
			errors.append("failure %s: happens must be one of %s" % [failure["id"], ", ".join(FAILURE_HAPPENS)])
		if not FAILURE_OUTCOMES.has(failure.get("outcome", "")):
			errors.append("failure %s: outcome must be one of %s" % [failure["id"], ", ".join(FAILURE_OUTCOMES)])
		elif failure["outcome"] == "degraded" and failure["happens"] == "start":
			errors.append("failure %s: a degraded print can't happen at the start" % failure["id"])
		for slot: String in failure.get("damages", {}):
			if not slots.has(slot):
				errors.append("failure %s: damages unknown part slot \"%s\"" % [failure["id"], slot])
