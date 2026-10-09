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
const TIERS := {"Garage": 1}
## Contract work has no marketplace demand. These wait for the contracts phase.
const SKIPPED_PATTERNS: Array[String] = ["Contracts"]
## Rows from before the catalogue that it places in a later tier. Kept exactly as
## they are until that tier is imported, because tests and the starting game use them.
const LEGACY: Array[String] = ["desk_organiser", "flexi_dragon"]

## Orders per game day at the typical price for the cheapest design in each catalogue
## size band. Small, cheap things sell fastest.
const DEMAND_PER_DAY := {"XS": 3.0, "S": 2.5, "M": 2.0, "L": 1.5}
## Dearer designs in a band sell slower: demand is multiplied by (cheapest price in
## the band / this price) to this power. At 1.0 every design in a band takes the same
## money in a day; at 0.0 price makes no difference to demand.
const DEMAND_PRICE_POWER := 0.5
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

## Per product values that replace what the rules give.
const OVERRIDES := {
	"cable_management_clips_x12": {"licence": {"type": "one_off", "fee_pence": 0, "royalty_pct": 0.0}},
}

## Field order in the output, and which numbers are written as whole numbers.
const FIELDS: Array[String] = [
	"id", "name", "category", "category_name", "description", "unlock_tier", "filament_grams", "print_minutes", "size_mm",
	"difficulty", "needs_supports", "colour_count", "allowed_filaments", "base_price_pence", "demand_per_day", "licence",
]
const WHOLE: Array[String] = ["unlock_tier", "filament_grams", "print_minutes", "size_mm", "colour_count", "base_price_pence", "fee_pence"]


## Cheapest catalogue price in each size band, in pounds.
var _band_floor := {}
var _descriptions := {}
## Imported products with nothing written for them, which fall back to their category name.
var _undescribed: PackedStringArray = []


func _init() -> void:
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for entry: Dictionary in catalogue["products"]:
		if TIERS.has(entry["unlock_tier"]) and not SKIPPED_PATTERNS.has(entry["demand_pattern"]):
			_band_floor[entry["size"]] = minf(_band_floor.get(entry["size"], INF), float(entry["base_price_gbp"]))
	_descriptions = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTIONS))
	var rows: Array[Dictionary] = []
	var skipped := 0
	var missing_models: PackedStringArray = []
	for entry: Dictionary in catalogue["products"]:
		if not TIERS.has(entry["unlock_tier"]):
			continue
		if SKIPPED_PATTERNS.has(entry["demand_pattern"]):
			skipped += 1
			continue
		if not ResourceLoader.exists(MODEL_PATH % entry["id"]):
			missing_models.append(entry["id"])
			continue
		rows.append(_convert(entry))
	if not missing_models.is_empty():
		printerr("No model for: ", ", ".join(missing_models), ". Build and import them first.")
		quit(1)
		return

	var imported := rows.size()
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
	print("Imported %d products, kept %d from before the catalogue, skipped %d contract only." % [imported, rows.size() - imported, skipped])
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
		"allowed_filaments": [String(entry["material"]).to_lower()],
		"base_price_pence": price,
		"demand_per_day": snappedf(DEMAND_PER_DAY[entry["size"]]
			* pow(_band_floor[entry["size"]] / float(entry["base_price_gbp"]), DEMAND_PRICE_POWER), 0.05),
		"licence": {"type": "one_off", "fee_pence": roundi(price * LICENCE_FEE_MULTIPLE / 100.0) * 100 - 1, "royalty_pct": 0.0},
	}
	if not _descriptions.has(entry["id"]):
		_undescribed.append(entry["id"])
	row.merge(OVERRIDES.get(entry["id"], {}), true)
	return row


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
	var size: Array = []
	for metres: float in [bounds.size.x, bounds.size.z, bounds.size.y]:
		size.append(maxi(SIZE_STEP_MM, roundi(metres / MODEL_SCALE * 1000.0 / SIZE_STEP_MM) * SIZE_STEP_MM))
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
