class_name Supplier
extends RefCounted
## The supplier shop: prices a basket and turns it into deliveries that arrive
## after a lead time. A basket is
##   { printers: { printer_id: qty }, spools: { colour: qty }, packaging: packs,
##     parts: { part_id: packs } }
## Each printer ships in its own box; spools, packaging and spare parts share one.


class Delivery:
	extends RefCounted
	var arrive_at: float
	## Name of the shop it was ordered from.
	var shop := ""
	## Empty unless this is a printer box.
	var printer: StringName = &""
	## One palette colour name per spool.
	var spools: Array[StringName] = []
	## Individual packaging units, not packs.
	var packaging := 0
	## Spare parts, part id -> individual parts, not packs.
	var parts: Dictionary[StringName, int] = {}

	func save() -> Dictionary:
		return {"arrive_at": arrive_at, "shop": shop, "printer": printer, "spools": spools, "packaging": packaging, "parts": parts}

	static func restored(data: Dictionary) -> Delivery:
		var delivery := Delivery.new()
		delivery.arrive_at = float(data["arrive_at"])
		delivery.shop = String(data["shop"])
		delivery.printer = StringName(data["printer"])
		for colour: String in data["spools"]:
			delivery.spools.append(StringName(colour))
		delivery.packaging = int(data["packaging"])
		for part: String in data["parts"]:
			delivery.parts[StringName(part)] = int(data["parts"][part])
		return delivery

	func describe() -> String:
		if printer != &"":
			return "Printer"
		var lines: PackedStringArray = []
		if not spools.is_empty():
			lines.append("%d spool%s" % [spools.size(), "" if spools.size() == 1 else "s"])
		if packaging > 0:
			lines.append("%d mailer boxes" % packaging)
		var spares := 0
		for count: int in parts.values():
			spares += count
		if spares > 0:
			lines.append("%d spare part%s" % [spares, "" if spares == 1 else "s"])
		return ", ".join(lines)


var data: GameData
## Not yet arrived, soonest first.
var pending: Array[Delivery] = []


func _init(p_data: GameData) -> void:
	data = p_data


func price_of(basket: Dictionary) -> int:
	var total := 0
	for printer_id: String in basket.get("printers", {}):
		total += int(data.printers[printer_id]["price_pence"]) * int(basket["printers"][printer_id])
	total += spool_price() * count_spools(basket)
	total += int(_config()["packaging_pack_pence"]) * int(basket.get("packaging", 0))
	for part_id: String in basket.get("parts", {}):
		total += int(data.parts[part_id]["price_pence"]) * int(basket["parts"][part_id])
	return total


## Price of one PLA spool. PLA is the only filament sold until Phase 6.
func spool_price() -> int:
	var pla: Dictionary = data.filaments["pla"]
	return roundi(pla["price_pence_per_kg"] * pla["spool_grams"] / 1000.0)


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
	supplies.packaging = int(basket.get("packaging", 0)) * int(_config()["packaging_pack_size"])
	for part_id: String in basket.get("parts", {}):
		supplies.parts[StringName(part_id)] = int(basket["parts"][part_id]) * int(data.parts[part_id]["pack_size"])
	if supplies.spools.is_empty() and supplies.packaging == 0:
		supplies.arrive_at = minute + float(_config()["parts_lead_minutes"])
	if not supplies.spools.is_empty() or supplies.packaging > 0 or not supplies.parts.is_empty():
		placed.append(supplies)
	for printer_id: String in basket.get("printers", {}):
		for i in int(basket["printers"][printer_id]):
			var box := Delivery.new()
			box.shop = shop
			box.arrive_at = minute + float(_config()["printer_lead_minutes"])
			box.printer = StringName(printer_id)
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
