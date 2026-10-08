class_name GameData
extends RefCounted
## Loads the content tables in res://data and indexes them by id.
## Pure data, no scene dependencies, so simulation code and tests can use it headless.

const TABLES := {
	"printers": "res://data/printers.json",
	"filaments": "res://data/filaments.json",
	"products": "res://data/products.json",
	"marketplaces": "res://data/marketplaces.json",
}
const SETTINGS := "res://data/game.json"

var printers: Dictionary = {}
var filaments: Dictionary = {}
var products: Dictionary = {}
var marketplaces: Dictionary = {}
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
	for printer: Dictionary in printers.values():
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
