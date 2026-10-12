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
	"upgrades": "res://data/upgrades.json",
	"premises": "res://data/premises.json",
	"dryers": "res://data/dryers.json",
	"clients": "res://data/contracts.json",
	"events": "res://data/events.json",
	"milestones": "res://data/milestones.json",
	"roles": "res://data/staff.json",
	"shifts": "res://data/staff.json",
	"packaging": "res://data/packaging.json",
	"fittings": "res://data/fittings.json",
	"bands": "res://data/couriers.json",
	"couriers": "res://data/couriers.json",
	"services": "res://data/couriers.json",
}
const FAILURE_HAPPENS: PackedStringArray = ["start", "mid", "end"]
const FAILURE_OUTCOMES: PackedStringArray = ["scrap", "stop", "degraded"]
const SETTINGS := "res://data/game.json"
## The tray an auto-eject plate throws prints into.
const TRAY_MODEL := "res://assets/models/automation/eject_tray.glb"
## Where the model of a multicolour unit is found.
const UNIT_MODEL := "res://assets/models/printers/%s.glb"
const PART_MODEL := "res://assets/models/parts/%s.glb"
## What a kit with no model of its own is kept in: a multicolour unit, boxed until it is fitted.
const PART_BOX := "res://assets/models/props/parts_box.glb"
const DRYER_MODEL := "res://assets/models/props/%s.glb"
## A kind of packaging, made up as a parcel, and a pile of it flat on the packing station.
const PACKAGING_MODEL := "res://assets/models/packaging/%s.glb"
const PACKAGING_STACK := "res://assets/models/packaging/%s_stack.glb"
const REVIEWS := "res://data/reviews.json"

var printers: Dictionary = {}
var filaments: Dictionary = {}
var products: Dictionary = {}
var marketplaces: Dictionary = {}
## Print presets, in the order they are offered.
var presets: Dictionary = {}
var failures: Dictionary = {}
## Wear parts, by id.
var parts: Dictionary = {}
## Printer upgrades, by id.
var upgrades: Dictionary = {}
## The places the business can run from, by id, smallest first.
var premises: Dictionary = {}
## Filament dryers, by id.
var dryers: Dictionary = {}
## Clients who send contract enquiries, by id (data/contracts.json).
var clients: Dictionary = {}
## Things that happen to the business from outside (data/events.json), and
## the milestones it works towards (data/milestones.json), by id.
var events: Dictionary = {}
var milestones: Dictionary = {}
## Staff roles and the shifts they can work, by id, and the whole of data/staff.json.
var roles: Dictionary = {}
var shifts: Dictionary = {}
var staff_config: Dictionary = {}
## What orders are sent in, by id, cheapest and flimsiest first (data/packaging.json).
var packaging: Dictionary = {}
## Shelving and racks that can be bought and stood about the premises, by id (data/fittings.json).
var fittings: Dictionary = {}
## Parcel size bands, smallest first, and the couriers and their services, by id (data/couriers.json).
var bands: Dictionary = {}
var couriers: Dictionary = {}
var services: Dictionary = {}
## Print toggles such as multicolour, by id (the `toggles` list in data/presets.json).
var toggles: Dictionary = {}
## What each durability score (1 to 5) means, keyed by the score as text.
var durability_labels: Dictionary = {}
## Lines buyers write in reviews, by kind (data/reviews.json).
var review_comments: Dictionary = {}
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
	var staff_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLES["roles"]))
	if staff_file is Dictionary:
		data.staff_config = staff_file
	var presets_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLES["presets"]))
	if presets_file is Dictionary:
		data.durability_labels = presets_file.get("durability_labels", {})
		for toggle: Dictionary in presets_file.get("toggles", []):
			data.toggles[toggle["id"]] = toggle
	var reviews_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(REVIEWS))
	if reviews_file is Dictionary and reviews_file.get("comments") is Dictionary:
		data.review_comments = reviews_file["comments"]
	else:
		data.errors.append("%s: expected an object with a \"comments\" object" % REVIEWS)
	data._check_references()
	return data


func _check_storage() -> void:
	for row: Dictionary in fittings.values():
		if not ["shelf", "rack", "bench"].has(row.get("kind", "")):
			errors.append("fitting %s: kind must be \"shelf\", \"rack\" or \"bench\"" % row["id"])
		if not ResourceLoader.exists("res://assets/models/furniture/%s.glb" % row.get("model", "")):
			errors.append("fitting %s: no model \"%s\"" % [row["id"], row.get("model", "")])
		if row.get("kind", "") == "bench" and row.get("printer_spots", []).is_empty():
			errors.append("fitting %s: a bench or printer rack needs printer_spots" % row["id"])
	for design: String in settings.get("storage_bins", {}).get("designs", {}):
		if not products.has(design):
			errors.append("game.json storage_bins: unknown design \"%s\"" % design)


func _check_shipping() -> void:
	for row: Dictionary in packaging.values():
		for band: String in row["fits_bands"]:
			if not bands.has(band):
				errors.append("packaging %s: unknown band \"%s\"" % [row["id"], band])
		for model: String in [PACKAGING_MODEL % row["model"], PACKAGING_STACK % row["model"]]:
			if not ResourceLoader.exists(model):
				errors.append("packaging %s: no model at %s" % [row["id"], model])
	for row: Dictionary in services.values():
		if not couriers.has(row["courier"]):
			errors.append("service %s: unknown courier \"%s\"" % [row["id"], row["courier"]])
		for band: String in row["prices"]:
			if not bands.has(band):
				errors.append("service %s: unknown band \"%s\"" % [row["id"], band])
	var config: Dictionary = settings.get("shipping", {})
	var named: Array = [config.get("default_service", "")]
	named.append_array(config.get("buyer_pays", {}).values())
	for service: String in named:
		if not services.has(service):
			errors.append("game.json shipping: unknown service \"%s\"" % service)
	for kind: String in settings.get("start", {}).get("packaging", {}):
		if not packaging.has(kind):
			errors.append("game.json start: unknown packaging \"%s\"" % kind)
	if not errors.is_empty():
		return
	var rules := Shipping.new(self)
	for product: Dictionary in products.values():
		if rules.default_terms(product, 4).is_empty():
			errors.append("product %s: no packaging and service will take it" % product["id"])


## The row for something that is bought as a kit and kept on the shelving:
## a wear part or an upgrade. {} if there is no such thing.
func kit(id: String) -> Dictionary:
	return parts.get(id, upgrades.get(id, {}))


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


## The model file for a row of parts.json or upgrades.json, as it sits on the shelving.
static func part_model(row: Dictionary) -> String:
	return PART_MODEL % row["model"] if row.has("model") else PART_BOX


func _check_references() -> void:
	var slots := {}
	for part: Dictionary in parts.values():
		slots[part["slot"]] = true
	for upgrade: Dictionary in upgrades.values():
		if parts.has(upgrade["id"]):
			errors.append("upgrade %s: a part has the same id" % upgrade["id"])
		for failure_id: String in upgrade.get("failure_multipliers", {}):
			if not failures.has(failure_id):
				errors.append("upgrade %s: unknown failure \"%s\"" % [upgrade["id"], failure_id])
		for printer_id: String in upgrade.get("fits_printers", []):
			if not printers.has(printer_id):
				errors.append("upgrade %s: unknown printer \"%s\"" % [upgrade["id"], printer_id])
		if upgrade.has("auto_eject") and not ResourceLoader.exists(TRAY_MODEL):
			errors.append("upgrade %s: no tray model at %s" % [upgrade["id"], TRAY_MODEL])
		if upgrade.has("multicolour"):
			var unit: Dictionary = upgrade["multicolour"]
			for part_id: String in unit.get("parts", []):
				if not parts.has(part_id):
					errors.append("upgrade %s: unknown part \"%s\"" % [upgrade["id"], part_id])
			if not ResourceLoader.exists(UNIT_MODEL % unit.get("model", "")):
				errors.append("upgrade %s: no model \"%s\"" % [upgrade["id"], unit.get("model", "")])
	for printer: Dictionary in printers.values():
		var fitted := {}
		for part_id: String in printer.get("parts", []):
			if not parts.has(part_id):
				errors.append("printer %s: unknown part \"%s\"" % [printer["id"], part_id])
			elif fitted.has(parts[part_id]["slot"]):
				errors.append("printer %s: two parts in the %s slot" % [printer["id"], parts[part_id]["slot"]])
			else:
				fitted[parts[part_id]["slot"]] = true
	var families := {}
	var kinds := {}
	for printer: Dictionary in printers.values():
		kinds[printer.get("kind", "fdm")] = true
		if printer.get("auto_eject", false) and int(printer.get("auto_eject_tray", 0)) < 1:
			errors.append("printer %s: ejects its own prints but has no auto_eject_tray" % printer["id"])
	for filament: Dictionary in filaments.values():
		families[filament.get("family", "")] = true
		if not kinds.has(filament.get("process", "fdm")):
			errors.append("filament %s: no printer of kind \"%s\" to print it" % [filament["id"], filament.get("process", "fdm")])
		if not filaments.has(filament.get("family", "")):
			errors.append("filament %s: its family \"%s\" isn't the id of a filament" % [filament["id"], filament.get("family", "")])
		if filament.get("container", "spool") == "bottle":
			for colour: String in filament["colours"]:
				if not ResourceLoader.exists("res://assets/models/filament/bottle_%s.glb" % colour):
					errors.append("filament %s: no bottle model for \"%s\"" % [filament["id"], colour])
	for row: Dictionary in parts.values() + upgrades.values():
		if not ResourceLoader.exists(part_model(row)):
			errors.append("%s: no model \"%s\"" % [row["id"], row.get("model", "")])
	_check_shipping()
	_check_storage()
	for dryer: Dictionary in dryers.values():
		if not ResourceLoader.exists(DRYER_MODEL % dryer.get("model", "")):
			errors.append("dryer %s: no model \"%s\"" % [dryer["id"], dryer.get("model", "")])
		for family: String in dryer.get("dries", []):
			if not families.has(family):
				errors.append("dryer %s: unknown filament family \"%s\"" % [dryer["id"], family])
	for toggle: String in ["multicolour", "batch_plate"]:
		if not toggles.has(toggle):
			errors.append("presets.json: no \"%s\" toggle" % toggle)
	for product: Dictionary in products.values():
		if product.get("contract_only", false) and not clients.values().any(func(client: Dictionary) -> bool: return client.get("supplies", []).has(product["id"])):
			errors.append("product %s: contract only, but no client supplies it" % product["id"])
		if int(product.get("colour_count", 1)) > 1 and int(product.get("colour_swaps", 0)) < 1:
			errors.append("product %s: more than one colour but no colour_swaps" % product["id"])
		for filament_id: String in product.get("allowed_filaments", []):
			if not filaments.has(filament_id) and not families.has(filament_id):
				errors.append("product %s: unknown filament \"%s\"" % [product["id"], filament_id])
	for event: Dictionary in events.values():
		if not ["demand", "price", "power_cut", "client_bust"].has(event.get("kind", "")):
			errors.append("event %s: unknown kind \"%s\"" % [event["id"], event.get("kind", "")])
		if event.get("kind", "") == "power_cut" and not failures.has("power_cut"):
			errors.append("event %s: no \"power_cut\" failure for it to cause" % event["id"])
	if shifts.is_empty():
		errors.append("staff.json: no shifts")
	if staff_config.get("names", []).size() < int(staff_config.get("applicants", 0)) or staff_config.get("looks", []).is_empty():
		errors.append("staff.json: needs a name for every applicant and at least one look")
	for look: String in staff_config.get("looks", []):
		if not ResourceLoader.exists("res://assets/models/characters/%s.glb" % look):
			errors.append("staff.json: no character model \"%s\"" % look)
	for client: Dictionary in clients.values():
		for supplied: String in client.get("supplies", []):
			if not products.has(supplied):
				errors.append("client %s: unknown design \"%s\"" % [client["id"], supplied])
			elif not products[supplied].get("contract_only", false):
				errors.append("client %s: \"%s\" is on general sale, so it isn't the client's to supply" % [client["id"], supplied])
		for range_field: String in ["quantity", "price_multiplier", "slack"]:
			var span: Array = client.get(range_field, [])
			if span.size() != 2 or float(span[0]) > float(span[1]):
				errors.append("client %s: %s must be [lowest, highest]" % [client["id"], range_field])
		if client.get("asks", []).is_empty():
			errors.append("client %s: nothing to say in asks" % client["id"])
	for product_id: String in settings.get("start", {}).get("designs", []):
		if not products.has(product_id):
			errors.append("game.json: unknown starting design \"%s\"" % product_id)
	if not premises.has(settings.get("start", {}).get("premises", "")):
		errors.append("game.json: unknown starting premises \"%s\"" % settings.get("start", {}).get("premises", ""))
	for place: Dictionary in premises.values():
		if not ResourceLoader.exists(place.get("scene", "")):
			errors.append("premises %s: no scene at \"%s\"" % [place["id"], place.get("scene", "")])
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
