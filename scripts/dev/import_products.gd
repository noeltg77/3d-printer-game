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

## Orders per game day at the typical price, by catalogue size band. Small, cheap things sell fastest.
const DEMAND_PER_DAY := {"XS": 5.0, "S": 3.5, "M": 3.0, "L": 2.5}
## Game difficulty (0 to 1) for catalogue difficulty 1, and the step for each level above.
const DIFFICULTY_BASE := 0.05
const DIFFICULTY_STEP := 0.1
## A design costs this multiple of its typical sale price, tidied to end in 99.
const LICENCE_FEE_MULTIPLE := 1.2
## Models are built larger than life so they read at the game camera.
const MODEL_SCALE := 1.4
const SIZE_STEP_MM := 5

## Per product values that replace what the rules give.
const OVERRIDES := {
	"cable_management_clips_x12": {
		"description": "Small, quick and boring. Sells forever.",
		"licence": {"type": "one_off", "fee_pence": 0, "royalty_pct": 0.0},
	},
	"phone_stand": {"description": "Props a phone up at a sensible angle. A steady seller."},
	"low_poly_planter": {"description": "Faceted pot for succulents. Looks more expensive than it is."},
	"mail_sorter": {"description": "Three slots for the post, the bills and the things to deal with later."},
}

## Field order in the output, and which numbers are written as whole numbers.
const FIELDS: Array[String] = [
	"id", "name", "category", "category_name", "description", "unlock_tier", "filament_grams", "print_minutes", "size_mm",
	"difficulty", "needs_supports", "colour_count", "allowed_filaments", "base_price_pence", "demand_per_day", "licence",
]
const WHOLE: Array[String] = ["unlock_tier", "filament_grams", "print_minutes", "size_mm", "colour_count", "base_price_pence", "fee_pence"]


func _init() -> void:
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
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
	quit(0)


func _convert(entry: Dictionary) -> Dictionary:
	var price := roundi(float(entry["base_price_gbp"]) * 100.0)
	var row := {
		"id": entry["id"],
		"name": entry["name"],
		"category": _slug(entry["category"]),
		"category_name": entry["category"],
		"description": entry["category"],
		"unlock_tier": TIERS[entry["unlock_tier"]],
		"filament_grams": entry["filament_g"],
		"print_minutes": roundi(float(entry["print_hours"]) * 60.0),
		"size_mm": _real_size_mm(entry["id"]),
		"difficulty": snappedf(DIFFICULTY_BASE + (float(entry["difficulty"]) - 1.0) * DIFFICULTY_STEP, 0.01),
		"needs_supports": false,
		"colour_count": entry["colours"],
		"allowed_filaments": [String(entry["material"]).to_lower()],
		"base_price_pence": price,
		"demand_per_day": DEMAND_PER_DAY[entry["size"]],
		"licence": {"type": "one_off", "fee_pence": roundi(price * LICENCE_FEE_MULTIPLE / 100.0) * 100 - 1, "royalty_pct": 0.0},
	}
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
