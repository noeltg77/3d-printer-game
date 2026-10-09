extends SceneTree
## Rebuilds data/products.json from the design catalogue in docs/design_data/products.json.
## The catalogue is the record of the design and is never edited; anything the game
## needs that it does not hold is worked out by the rules below, or set per product
## in OVERRIDES. Change those and run this again, not the output.
## Run: godot --headless --path . --script res://scripts/dev/import_products.gd

const SOURCE := "res://docs/design_data/products.json"
const TARGET := "res://data/products.json"
const MODEL_PATH := "res://assets/models/prints/%s.glb"

## Catalogue tiers imported so far, and the number the game uses for each.
const TIERS := {"Garage": 1, "Spare room": 2, "Workshop": 3, "Factory": 4}
## Tiers whose every product must have a model. The others come in a few at a
## time: a product there with no model yet is left out, and counted.
const COMPLETE_TIERS: Array[String] = ["Garage"]
## Contract work has no marketplace demand. Such a design is never on general
## sale: a client supplies it with a contract (data/contracts.json), and it is
## imported, marked `contract_only`, once it has a model.
const SKIPPED_PATTERNS: Array[String] = ["Contracts"]
## Rows from before the catalogue that it places in a later tier. Kept exactly as
## they are until that tier is imported, because tests and the starting game use them.
const LEGACY: Array[String] = ["desk_organiser", "flexi_dragon"]

## Catalogue materials whose filament id in data/filaments.json is not just the name in lower case.
const FILAMENTS := {"Silk": "pla_silk", "Glow": "pla_glow", "Wood": "pla_wood", "Carbon PLA": "pla_cf", "Resin": "resin"}

## Orders per game day at the typical price for the cheapest design in each catalogue
## size band. Small, cheap things sell fastest.
const DEMAND_PER_DAY := {"XS": 3.0, "S": 2.5, "M": 2.0, "L": 1.5, "XL": 1.0, "XXL": 0.5}
## Dearer designs in a band sell slower: demand is multiplied by (cheapest price in
## the band / this price) to this power. At 1.0 every design in a band takes the same
## money in a day; at 0.0 price makes no difference to demand.
const DEMAND_PRICE_POWER := 0.5
## The catalogue's `purge_waste_g` is the filament a design's colour changes
## waste on a unit that purges this much each time. Dividing gives the number
## of changes, which the game then prices by the unit actually fitted.
const REFERENCE_PURGE_GRAMS := 4.0
## Game difficulty (0 to 1) for catalogue difficulty 1, and the step for each level above.
const DIFFICULTY_BASE := 0.05
const DIFFICULTY_STEP := 0.1
## A design costs this multiple of its typical sale price, tidied to end in 99.
const LICENCE_FEE_MULTIPLE := 2.0
## Models are built larger than life so they read at the game camera.
const MODEL_SCALE := 1.4
const SIZE_STEP_MM := 5

## What each design's card says in the Design Lab, by product id. Written by hand.
const DESCRIPTIONS := "res://data/import/product_descriptions.json"
## The game's materials. A product in one that isn't here yet (resin) is left out, and counted.
const FILAMENT_TABLE := "res://data/filaments.json"
## Small parts whose model was scaled up again to be visible (`builder.enlarge` in
## its generator), by product id. Their real size divides by this as well.
const ENLARGEMENT := "res://data/import/model_enlargement.json"

## Per product values that replace what the rules give. The names are for
## catalogue entries called after a real brand, which the game doesn't use.
const OVERRIDES := {
	"cable_management_clips_x12": {"licence": {"type": "one_off", "fee_pence": 0, "royalty_pct": 0.0}},
	"raspberry_pi_case": {"name": "Mini computer case"},
	"life_counter_mtg": {"name": "Life counter (card games)"},
	"infinity_style_gauntlet": {"name": "Gem gauntlet"},
	"replica_lightsaber_hilt": {"name": "Energy sword hilt"},
	"spotify_code_plaque": {"name": "Music code plaque"},
	"elf_on_the_shelf_props_set": {"name": "Shelf elf props set"},
	"gridfinity_baseplate_4x4": {"name": "Grid storage baseplate 4x4"},
	"gridfinity_bin_pack_x6": {"name": "Grid storage bin pack (x6)"},
	"benchy_pack_of_5": {"name": "Test boat (pack of 5)"},
	"arduino_mounting_plate": {"name": "Controller board mounting plate"},
	"gopro_mount_set": {"name": "Action camera mount set"},
	# Its model is shrunk to fit a shelf, so its real size can't be measured from it.
	"mandalorian_style_helmet": {"name": "Bounty hunter helmet", "size_mm": [240, 280, 300]},
}

## Field order in the output, and which numbers are written as whole numbers.
const FIELDS: Array[String] = [
	"id", "name", "category", "category_name", "description", "unlock_tier", "filament_grams", "print_minutes", "size_mm",
	"difficulty", "needs_supports", "colour_count", "colour_swaps", "allowed_filaments", "base_price_pence", "demand_per_day", "licence", "contract_only",
]
const WHOLE: Array[String] = ["unlock_tier", "filament_grams", "print_minutes", "size_mm", "colour_count", "colour_swaps", "base_price_pence", "fee_pence"]


## Cheapest catalogue price in each size band, in pounds. Taken from the complete
## tiers only, so bringing in a later tier doesn't move the demand of an earlier one.
var _band_floor := {}
var _descriptions := {}
var _enlargement := {}
## Imported products with nothing written for them, which fall back to their category name.
var _undescribed: PackedStringArray = []


func _init() -> void:
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for entry: Dictionary in catalogue["products"]:
		if COMPLETE_TIERS.has(entry["unlock_tier"]) and not SKIPPED_PATTERNS.has(entry["demand_pattern"]):
			_band_floor[entry["size"]] = minf(_band_floor.get(entry["size"], INF), float(entry["base_price_gbp"]))
	# A band the complete tiers have nothing in (XL) takes its floor from the tiers that do.
	var later_floor := {}
	for entry: Dictionary in catalogue["products"]:
		if TIERS.has(entry["unlock_tier"]) and not SKIPPED_PATTERNS.has(entry["demand_pattern"]):
			later_floor[entry["size"]] = minf(later_floor.get(entry["size"], INF), float(entry["base_price_gbp"]))
	for band: String in later_floor:
		if not _band_floor.has(band):
			_band_floor[band] = later_floor[band]
	_descriptions = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTIONS))
	_enlargement = JSON.parse_string(FileAccess.get_file_as_string(ENLARGEMENT))
	var known_filaments := {}
	for filament: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(FILAMENT_TABLE))["filaments"]:
		known_filaments[filament["id"]] = true
	var rows: Array[Dictionary] = []
	var skipped := 0
	var contract_only := 0
	var waiting := 0
	var no_material := 0
	var missing_models: PackedStringArray = []
	for entry: Dictionary in catalogue["products"]:
		# A row kept from before the catalogue stays as it is until its tier is complete.
		if not TIERS.has(entry["unlock_tier"]) or LEGACY.has(entry["id"]):
			continue
		if SKIPPED_PATTERNS.has(entry["demand_pattern"]):
			if ResourceLoader.exists(MODEL_PATH % entry["id"]) and known_filaments.has(_filament(entry)):
				var for_clients := _convert(entry)
				for_clients.merge({"contract_only": true, "demand_per_day": 0.0, "licence": {"type": "one_off", "fee_pence": 0, "royalty_pct": 0.0}}, true)
				rows.append(for_clients)
				contract_only += 1
			else:
				skipped += 1
			continue
		if not ResourceLoader.exists(MODEL_PATH % entry["id"]):
			if COMPLETE_TIERS.has(entry["unlock_tier"]):
				missing_models.append(entry["id"])
			else:
				waiting += 1
			continue
		if not known_filaments.has(_filament(entry)):
			no_material += 1
			continue
		rows.append(_convert(entry))
	if not missing_models.is_empty():
		printerr("No model for: ", ", ".join(missing_models), ". Build and import them first.")
		quit(1)
		return

	var imported := rows.size() - contract_only
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TARGET))
	for row: Dictionary in current["products"]:
		if LEGACY.has(row["id"]):
			rows.append(row)

	var blocks: PackedStringArray = []
	for row in rows:
		blocks.append(_write_row(row))
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	file.store_string("{\n\t\"schema_version\": 1,\n\t\"products\": [\n%s\n\t]\n}\n" % ",\n".join(blocks))
	file.close()
	print("Imported %d products and %d for contracts only, kept %d from before the catalogue, skipped %d contract only, %d from later tiers with no model yet and %d in a material the game doesn't have yet." % [
		imported, contract_only, rows.size() - imported - contract_only, skipped, waiting, no_material])
	if not _undescribed.is_empty():
		print("No description yet for: ", ", ".join(_undescribed))
	quit(0)


func _convert(entry: Dictionary) -> Dictionary:
	var price := roundi(float(entry["base_price_gbp"]) * 100.0)
	var row := {
		"id": entry["id"],
		"name": entry["name"],
		"category": _slug(entry["category"]),
		"category_name": entry["category"],
		"description": _descriptions.get(entry["id"], entry["category"]),
		"unlock_tier": TIERS[entry["unlock_tier"]],
		"filament_grams": entry["filament_g"],
		"print_minutes": roundi(float(entry["print_hours"]) * 60.0),
		"size_mm": _real_size_mm(entry["id"]),
		"difficulty": snappedf(DIFFICULTY_BASE + (float(entry["difficulty"]) - 1.0) * DIFFICULTY_STEP, 0.01),
		"needs_supports": false,
		"colour_count": entry["colours"],
		"allowed_filaments": [_filament(entry)],
		"base_price_pence": price,
		"demand_per_day": snappedf(DEMAND_PER_DAY.get(entry["size"], 1.0)
			* pow(_band_floor.get(entry["size"], float(entry["base_price_gbp"])) / float(entry["base_price_gbp"]), DEMAND_PRICE_POWER), 0.05),
		"licence": {"type": "one_off", "fee_pence": roundi(price * LICENCE_FEE_MULTIPLE / 100.0) * 100 - 1, "royalty_pct": 0.0},
	}
	# Only designs in more than one colour carry the field, so the rest of the table is unchanged.
	if int(entry["colours"]) > 1:
		row["colour_swaps"] = maxi(roundi(float(entry["purge_waste_g"]) / REFERENCE_PURGE_GRAMS), 1)
	if not _descriptions.has(entry["id"]):
		_undescribed.append(entry["id"])
	row.merge(OVERRIDES.get(entry["id"], {}), true)
	return row


## The id in data/filaments.json of the material a catalogue entry is printed in.
func _filament(entry: Dictionary) -> String:
	return FILAMENTS.get(entry["material"], String(entry["material"]).to_lower())


func _slug(text: String) -> String:
	var slug := ""
	for character in text.to_lower().replace("'", ""):
		slug += character if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") else "_"
	return slug


## The product's real size as [x, y, z] with z up, measured from its model.
func _real_size_mm(id: String) -> Array:
	var model: Node3D = (load(MODEL_PATH % id) as PackedScene).instantiate()
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	model.free()
	# Godot has y up; the data has z up.
	var scale := MODEL_SCALE * float(_enlargement.get(id, 1.0))
	var size: Array = []
	for metres: float in [bounds.size.x, bounds.size.z, bounds.size.y]:
		size.append(maxi(SIZE_STEP_MM, roundi(metres / scale * 1000.0 / SIZE_STEP_MM) * SIZE_STEP_MM))
	return size


func _write_row(row: Dictionary) -> String:
	var lines: PackedStringArray = []
	for field in FIELDS:
		# Rows kept from before the catalogue do not have every field.
		if not row.has(field):
			continue
		lines.append("\t\t\t\"%s\": %s" % [field, _write_value(field, row[field])])
	return "\t\t{\n%s\n\t\t}" % ",\n".join(lines)


func _write_value(field: String, value: Variant) -> String:
	if value is Dictionary:
		var parts: PackedStringArray = []
		for key: String in value:
			parts.append("\"%s\": %s" % [key, _write_value(key, value[key])])
		return "{ %s }" % ", ".join(parts)
	if value is Array:
		var parts: PackedStringArray = []
		for item: Variant in value:
			parts.append(_write_value(field, item))
		return "[%s]" % ", ".join(parts)
	if value is String:
		return JSON.stringify(value)
	if value is bool:
		return "true" if value else "false"
	if WHOLE.has(field):
		return str(roundi(value))
	var text := str(snappedf(value, 0.01))
	return text if text.contains(".") else text + ".0"
