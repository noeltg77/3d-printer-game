class_name Supplier
extends RefCounted
## The supplier shop: prices a basket and turns it into deliveries that arrive
## after a lead time. A basket is
##   { printers: { printer_id: qty }, spools: { colour: qty }, packaging: packs }
## Each printer ships in its own box; spools and packaging share one.


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

	func describe() -> String:
		if printer != &"":
			return "Printer"
		var parts: PackedStringArray = []
		if not spools.is_empty():
			parts.append("%d spool%s" % [spools.size(), "" if spools.size() == 1 else "s"])
		if packaging > 0:
			parts.append("%d mailer boxes" % packaging)
		return ", ".join(parts)


var data: GameData
## Not yet arrived, soonest first.
var pending: Array[Delivery] = []


func _init(p_data: GameData) -> void:
	data = p_data


func price_of(basket: Dictionary) -> int:
	var total := 0
	for printer_id: String in basket.get("printers", {}):
		total += int(data.printers[printer_id]["price_cents"]) * int(basket["printers"][printer_id])
	total += spool_price() * count_spools(basket)
	total += int(_config()["packaging_pack_cents"]) * int(basket.get("packaging", 0))
	return total


## Price of one PLA spool. PLA is the only filament sold until Phase 6.
func spool_price() -> int:
	var pla: Dictionary = data.filaments["pla"]
	return roundi(pla["price_cents_per_kg"] * pla["spool_grams"] / 1000.0)


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
	if not supplies.spools.is_empty() or supplies.packaging > 0:
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
