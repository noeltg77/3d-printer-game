class_name Supplier
extends RefCounted
## The supplier shop: prices a basket and turns it into deliveries that arrive
## after a lead time. A basket is
##   { printers: { printer_id: qty }, spools: { spool key: qty }, packaging: { packaging id: packs },
##     parts: { part or upgrade id: packs }, dryers: { dryer_id: qty }, fittings: { fitting_id: qty } }
## A spool key is "material:colour" (FilamentRules.spool_key); a bare colour
## means PLA. Each printer, each dryer and each fitting (shelving, a rack) ships in its own box; spools, packaging and spare parts share one.


## What the mailer boxes of an old save are now.
const LEGACY_PACKAGING := "small_cardboard_box"


class Delivery:
	extends RefCounted
	var arrive_at: float
	## Name of the shop it was ordered from.
	var shop := ""
	## Empty unless this is a printer box.
	var printer: StringName = &""
	## Empty unless this is a filament dryer's box.
	var dryer: StringName = &""
	## Empty unless this is a flat packed fitting: shelving or a rack (data/fittings.json).
	var fitting: StringName = &""
	## One spool key per spool.
	var spools: Array[StringName] = []
	## Packaging, id -> how many, not packs.
	var packaging: Dictionary[StringName, int] = {}
	## Spare parts and upgrade kits, id -> how many, not packs.
	var parts: Dictionary[StringName, int] = {}

	func save() -> Dictionary:
		return {"arrive_at": arrive_at, "shop": shop, "printer": printer, "dryer": dryer, "fitting": fitting, "spools": spools,
			"packaging": packaging, "parts": parts}

	static func restored(data: Dictionary) -> Delivery:
		var delivery := Delivery.new()
		delivery.arrive_at = float(data["arrive_at"])
		delivery.shop = String(data["shop"])
		delivery.printer = StringName(data["printer"])
		delivery.dryer = StringName(data.get("dryer", ""))
		delivery.fitting = StringName(data.get("fitting", ""))
		for colour: String in data["spools"]:
			delivery.spools.append(StringName(colour))
		# Saves from before there were kinds of packaging hold a count of mailer boxes.
		var saved_packaging: Variant = data["packaging"]
		if not saved_packaging is Dictionary:
			saved_packaging = {LEGACY_PACKAGING: saved_packaging} if int(saved_packaging) > 0 else {}
		for kind: String in saved_packaging:
			delivery.packaging[StringName(kind)] = int(saved_packaging[kind])
		for part: String in data["parts"]:
			delivery.parts[StringName(part)] = int(data["parts"][part])
		return delivery

	func describe() -> String:
		if printer != &"":
			return "Printer"
		if dryer != &"":
			return "Filament dryer"
		if fitting != &"":
			return "Flat pack"
		var lines: PackedStringArray = []
		if not spools.is_empty():
			lines.append("%d spool%s" % [spools.size(), "" if spools.size() == 1 else "s"])
		var wraps := 0
		for count: int in packaging.values():
			wraps += count
		if wraps > 0:
			lines.append("%d boxes and bags" % wraps)
		var spares := 0
		for count: int in parts.values():
			spares += count
		if spares > 0:
			lines.append("%d part%s" % [spares, "" if spares == 1 else "s"])
		return ", ".join(lines)


var data: GameData
## Filament id -> what a shortage is doing to its price, as a multiplier. See Events.
var price_multipliers: Dictionary[String, float] = {}
## Not yet arrived, soonest first.
var pending: Array[Delivery] = []


func _init(p_data: GameData) -> void:
	data = p_data


func price_of(basket: Dictionary) -> int:
	var total := 0
	for printer_id: String in basket.get("printers", {}):
		total += int(data.printers[printer_id]["price_pence"]) * int(basket["printers"][printer_id])
	for key: String in basket.get("spools", {}):
		total += spool_price(FilamentRules.material_of(key)) * int(basket["spools"][key])
	for kind: String in basket.get("packaging", {}):
		total += int(data.packaging[kind]["price_pence"]) * int(basket["packaging"][kind])
	for part_id: String in basket.get("parts", {}):
		total += int(data.kit(part_id)["price_pence"]) * int(basket["parts"][part_id])
	for dryer_id: String in basket.get("dryers", {}):
		total += int(data.dryers[dryer_id]["price_pence"]) * int(basket["dryers"][dryer_id])
	for fitting_id: String in basket.get("fittings", {}):
		total += int(data.fittings[fitting_id]["price_pence"]) * int(basket["fittings"][fitting_id])
	return total


## Price of one spool of a filament.
func spool_price(material := FilamentRules.DEFAULT_MATERIAL) -> int:
	var filament: Dictionary = data.filaments[material]
	return roundi(filament["price_pence_per_kg"] * filament["spool_grams"] / 1000.0 * float(price_multipliers.get(material, 1.0)))


static func count_spools(basket: Dictionary) -> int:
	var count := 0
	for quantity: int in basket.get("spools", {}).values():
		count += quantity
	return count


static func count_printers(basket: Dictionary) -> int:
	var count := 0
	for quantity: int in basket.get("printers", {}).values():
		count += quantity
	return count


## Turns a basket into pending deliveries. Paying for it is the caller's job.
func place(basket: Dictionary, minute: float, shop := "") -> Array[Delivery]:
	var placed: Array[Delivery] = []
	var supplies := Delivery.new()
	supplies.shop = shop
	supplies.arrive_at = minute + float(_config()["filament_lead_minutes"])
	for colour: String in basket.get("spools", {}):
		for i in int(basket["spools"][colour]):
			supplies.spools.append(StringName(colour))
	for kind: String in basket.get("packaging", {}):
		supplies.packaging[StringName(kind)] = int(basket["packaging"][kind]) * int(data.packaging[kind]["pack_size"])
	for part_id: String in basket.get("parts", {}):
		supplies.parts[StringName(part_id)] = int(basket["parts"][part_id]) * int(data.kit(part_id).get("pack_size", 1))
	if supplies.spools.is_empty() and supplies.packaging.is_empty():
		supplies.arrive_at = minute + float(_config()["parts_lead_minutes"])
	if not supplies.spools.is_empty() or not supplies.packaging.is_empty() or not supplies.parts.is_empty():
		placed.append(supplies)
	for printer_id: String in basket.get("printers", {}):
		for i in int(basket["printers"][printer_id]):
			var box := Delivery.new()
			box.shop = shop
			box.arrive_at = minute + float(_config()["printer_lead_minutes"])
			box.printer = StringName(printer_id)
			placed.append(box)
	for dryer_id: String in basket.get("dryers", {}):
		for i in int(basket["dryers"][dryer_id]):
			var box := Delivery.new()
			box.shop = shop
			box.arrive_at = minute + float(_config()["printer_lead_minutes"])
			box.dryer = StringName(dryer_id)
			placed.append(box)
	for fitting_id: String in basket.get("fittings", {}):
		for i in int(basket["fittings"][fitting_id]):
			var box := Delivery.new()
			box.shop = shop
			box.arrive_at = minute + float(_config()["printer_lead_minutes"])
			box.fitting = StringName(fitting_id)
			placed.append(box)
	pending.append_array(placed)
	pending.sort_custom(func(a: Delivery, b: Delivery) -> bool: return a.arrive_at < b.arrive_at)
	return placed


## Removes and returns the deliveries that have arrived by `minute`.
func collect_due(minute: float) -> Array[Delivery]:
	var due: Array[Delivery] = []
	while not pending.is_empty() and pending[0].arrive_at <= minute:
		due.append(pending.pop_front())
	return due


func _config() -> Dictionary:
	return data.settings["supplier"]


func save() -> Dictionary:
	return {"pending": pending.map(func(delivery: Delivery) -> Dictionary: return delivery.save())}


func restore(data: Dictionary) -> void:
	pending.clear()
	for entry: Dictionary in data["pending"]:
		pending.append(Delivery.restored(entry))
