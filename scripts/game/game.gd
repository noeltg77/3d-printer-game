extends Node
## Autoload `Game`: the running business. Owns the simulation objects (clock,
## bank, marketplace, supplier), moves them on each frame and announces what
## happened. Scene nodes and UI read state from here and call the methods below;
## the rules themselves live in scripts/sim.

## Something the UI shows has changed (cash, orders, designs, stock).
signal changed
## A short message for the player. `tone` is &"good", &"bad" or empty.
signal notified(text: String, tone: StringName)
signal delivery_arrived(delivery: Supplier.Delivery)
## The daily courier is here to take whatever is in the outbox.
signal courier_arrived

const SPEEDS: Array[int] = [0, 1, 2, 4]
## Player preferences, kept apart from save games.
const SETTINGS_FILE := "user://settings.cfg"
## Bumped when a save from before can no longer be read.
const SAVE_VERSION := 1

var data: GameData
var clock: GameClock
var bank: Bank
var market: Marketplace
var supplier: Supplier
var owned_designs: Array[StringName] = []
## Mailer boxes in stock, one used per packed order.
var packaging := 0
var speed := 1
var rng := RandomNumberGenerator.new()
## Dev: id of a failure the next print is certain to hit. Cleared once used.
var force_failure := ""
## Where the game is saved. Empty turns saving and loading off, as it is for
## dev runs driven from the command line unless they pass --save=<path>.
var save_path := "user://save.json"
## Game minute of the last save this session, or -1 if there hasn't been one.
var saved_at := -1.0


func _ready() -> void:
	_load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay=") or arg.begins_with("--shot"):
			save_path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	new_game()


func _process(delta: float) -> void:
	var before := clock.minutes
	clock.advance(delta)
	for delivery in supplier.collect_due(clock.minutes):
		delivery_arrived.emit(delivery)
		notify("Delivery arrived: %s" % delivery.describe())
		changed.emit()
	for order in market.tick(before, clock.minutes, rng):
		notify("New order: %s for %s" % [product_name(order.product), Money.format(order.price)])
		changed.emit()
	for order in market.expire(clock.minutes):
		notify("Order #%d was cancelled: not dispatched in time" % order.id, &"bad")
		changed.emit()
	for outcome in market.deliver(clock.minutes, rng, data.settings["courier"]):
		_settle_delivery(outcome)
	if clock.crossed(before, data.settings["courier_minute_of_day"]):
		courier_arrived.emit()


func new_game() -> void:
	data = GameData.load_all()
	var start: Dictionary = data.settings["start"]
	clock = GameClock.new()
	clock.minutes = start["minute_of_day"]
	bank = Bank.new(int(start["cash_pence"]))
	market = Marketplace.new(data.marketplaces["craftsy"], data.products)
	market.comments = data.review_comments
	supplier = Supplier.new(data)
	owned_designs.assign(start["designs"])
	packaging = int(start["packaging"])
	rng.randomize()
	saved_at = -1.0
	set_speed(1)


func has_save() -> bool:
	return save_path != "" and FileAccess.file_exists(save_path)


## Writes the business, and the state of the world it is given, to the save
## file. False if saving is off or the file couldn't be written.
func save_game(world: Dictionary) -> bool:
	if save_path == "":
		return false
	var content := JSON.stringify({"version": SAVE_VERSION, "business": save(), "world": world}, "\t")
	# Written beside the save and swapped in, so a crash can't leave half a file.
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		return false
	saved_at = clock.minutes
	return true


## Reads the save file and restores the business from it. Returns the saved
## state of the world for the scene to rebuild, or {} if there is no save or it
## can't be read. An unreadable save is moved aside rather than overwritten.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION and parsed.get("business") is Dictionary:
		restore(parsed["business"])
		saved_at = clock.minutes
		return parsed.get("world", {})
	DirAccess.rename_absolute(save_path, save_path + ".unreadable")
	notify("The saved game couldn't be read, so this is a new one", &"bad")
	return {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)
	saved_at = -1.0


## The business as plain data: everything here that a save needs.
func save() -> Dictionary:
	return {
		"clock": clock.save(), "bank": bank.save(), "market": market.save(), "supplier": supplier.save(),
		"owned_designs": owned_designs, "packaging": packaging,
	}


## Puts the business back from save(). Designs the game no longer has are dropped.
func restore(state: Dictionary) -> void:
	clock.restore(state["clock"])
	bank.restore(state["bank"])
	market.restore(state["market"])
	supplier.restore(state["supplier"])
	owned_designs.clear()
	for product: String in state["owned_designs"]:
		if data.products.has(product):
			owned_designs.append(StringName(product))
	packaging = int(state["packaging"])
	changed.emit()


## Changes the currency amounts are shown in and remembers it. Nothing in the
## game itself changes: everything is held in GBP and converted for display.
func set_currency(code: String) -> void:
	Money.set_currency(code)
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("display", "currency", Money.currency)
	config.save(SETTINGS_FILE)
	changed.emit()


## On first launch the currency follows the computer's region.
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK and config.has_section_key("display", "currency"):
		Money.set_currency(config.get_value("display", "currency"))
	else:
		Money.set_currency(Money.currency_for_locale(OS.get_locale()))


## 0 pauses. Everything in the scene follows, because it scales engine time.
func set_speed(new_speed: float) -> void:
	speed = int(new_speed)
	Engine.time_scale = new_speed
	changed.emit()


func notify(text: String, tone: StringName = &"") -> void:
	notified.emit(text, tone)


func product_name(product: StringName) -> String:
	return data.products[product]["name"]


func owns(product: StringName) -> bool:
	return owned_designs.has(product)


## Filament a design uses at a preset, in grams.
func print_grams(product: StringName, preset: StringName) -> float:
	return float(data.products[product]["filament_grams"]) * float(data.presets[preset]["filament_multiplier"])


## Chance (0 to 1) that printing a design this way goes wrong. `wear` is the
## state of the printer's parts, if it has any to count.
func fail_chance(printer: Dictionary, preset: StringName, filament: StringName, product: StringName, wear: PrinterWear = null) -> float:
	return PrintRisk.fail_chance(printer, data.presets[preset], data.filaments[filament], data.products[product],
		wear.extra_fail_chance() if wear != null else 0.0)


## Decides the fate of a print as it starts. Returns {} if it will go well, or
## { failure, at } with the failure's row and the progress at which it strikes.
func roll_print(printer: Dictionary, preset: StringName, filament: StringName, product: StringName, wear: PrinterWear = null) -> Dictionary:
	if data.failures.has(force_failure):
		var forced: Dictionary = data.failures[force_failure]
		force_failure = ""
		return {"failure": forced, "at": PrintRisk.strike_point(forced, rng)}
	var flags := PrintRisk.conditions(printer, data.presets[preset], data.products[product])
	if wear != null:
		flags.append_array(wear.flags())
	return PrintRisk.roll(fail_chance(printer, preset, filament, product, wear), data.failures, flags, data.filaments[filament], rng)


## Buys a design licence. False if it can't be afforded or is already owned.
func buy_design(product: StringName) -> bool:
	if owns(product):
		return false
	var fee := int(data.products[product]["licence"]["fee_pence"])
	if not bank.spend(fee, "Design licence: %s" % product_name(product), clock.minutes):
		return false
	owned_designs.append(product)
	changed.emit()
	return true


## Why a supplier basket can't be ordered, or "" if it can.
func supplier_problem(basket: Dictionary) -> String:
	if supplier.price_of(basket) <= 0:
		return "Basket is empty"
	if not bank.can_afford(supplier.price_of(basket)):
		return "Not enough cash"
	var incoming_spools := 0
	var incoming_printers := 0
	for delivery in supplier.pending:
		incoming_spools += delivery.spools.size()
		incoming_printers += 1 if delivery.printer != &"" else 0
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	if rack != null and Supplier.count_spools(basket) + incoming_spools > rack.free_slots() - _unpacked(&"spools"):
		return "Not enough room on the filament rack"
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	var part_ids: Array = basket.get("parts", {}).keys()
	for delivery in supplier.pending:
		part_ids.append_array(delivery.parts.keys())
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		part_ids.append_array(box.delivery.parts.keys())
	if shelf != null and not basket.get("parts", {}).is_empty() and not shelf.can_store_parts(part_ids):
		return "No shelf space for more spare parts"
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	if bench != null and Supplier.count_printers(basket) + incoming_printers > bench.free_spots() - _unpacked(&"printers"):
		return "No bench space for another printer"
	return ""


## Pays for a basket and schedules its deliveries. `shop` is the name of the
## shop it was bought from. False if it can't be ordered.
func place_supplier_order(basket: Dictionary, shop := "") -> bool:
	if supplier_problem(basket) != "":
		return false
	if shop == "":
		shop = data.settings["supplier"]["hardware_shop"]
	bank.spend(supplier.price_of(basket), "%s order" % shop, clock.minutes)
	supplier.place(basket, clock.minutes, shop)
	notify("Order placed with %s" % shop)
	changed.emit()
	return true


## What one unit of a design costs to make and send: filament, electricity on
## the starter printer, and a mailer box.
func unit_cost(product: StringName) -> int:
	var row: Dictionary = data.products[product]
	var pla: Dictionary = data.filaments["pla"]
	var config: Dictionary = data.settings["supplier"]
	var printer: Dictionary = data.printers.values()[0]
	var filament := float(row["filament_grams"]) / 1000.0 * float(pla["price_pence_per_kg"])
	var kwh := float(printer["power_watts"]) / 1000.0 * float(row["print_minutes"]) / 60.0
	var mailer := float(config["packaging_pack_pence"]) / float(config["packaging_pack_size"])
	return roundi(filament + kwh * float(data.settings["electricity_pence_per_kwh"]) + mailer)


## What is left from one sale at `price` after costs, marketplace fees and royalty.
func unit_profit(product: StringName, price: int) -> int:
	return price - unit_cost(product) - market.fee_for(price) - market.royalty_for(product, price)


## Finished items of a design on the shelves.
func stock_of(product: StringName) -> int:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	return shelf.count_of(product) if shelf != null else 0


## Takes payment for a dispatched order, less the marketplace's cut.
func complete_sale(order: Marketplace.Order) -> void:
	var transit: Array = data.settings["courier"]["delivery_minutes"]
	var sale := market.ship(order, clock.minutes, clock.minutes + rng.randf_range(transit[0], transit[1]))
	var market_name: String = market.config["name"]
	bank.earn(sale["price"], "Sale: %s (%s)" % [product_name(order.product), market_name], clock.minutes)
	bank.charge(sale["fee"], "%s fees" % market_name, clock.minutes)
	bank.charge(sale["royalty"], "Design royalty: %s" % product_name(order.product), clock.minutes)
	changed.emit()


## Chance (0 to 1) that an item of this strength arrives broken, in the
## packaging and with the courier the business uses.
func damage_chance(durability: int) -> float:
	return Marketplace.damage_chance(durability, data.settings["courier"])


## Puts a delivered order's refund through the bank and announces how it went.
func _settle_delivery(outcome: Dictionary) -> void:
	var order: Marketplace.Order = outcome["order"]
	var title := product_name(order.product)
	var review: Dictionary = outcome["review"]
	if not outcome["refund"].is_empty():
		var refund: Dictionary = outcome["refund"]
		var market_name: String = market.config["name"]
		var why := "arrived broken" if order.refund_reason == "damaged" else "sent back"
		bank.charge(refund["price"], "Refund: %s (%s)" % [title, why], clock.minutes)
		if refund["fee"] > 0:
			bank.earn(refund["fee"], "%s fees returned" % market_name, clock.minutes)
		if refund["royalty"] > 0:
			bank.earn(refund["royalty"], "Design royalty returned: %s" % title, clock.minutes)
		notify("Order #%d %s: %s refunded. \"%s\"" % [order.id, why, Money.format(refund["price"]), review["text"]], &"bad")
	elif not review.is_empty():
		var stars := int(review["stars"])
		notify("%d star review for %s: \"%s\"" % [stars, title, review["text"]], &"good" if stars >= 4 else (&"bad" if stars <= 2 else &""))
	changed.emit()


## Charges for the electricity a finished print used.
func charge_electricity(watts: float, game_minutes: float, what: String) -> void:
	var kwh := watts / 1000.0 * game_minutes / 60.0
	bank.charge(roundi(kwh * float(data.settings["electricity_pence_per_kwh"])), "Electricity: %s" % what, clock.minutes)
	changed.emit()


## Spools or printers sitting in delivery boxes that haven't been unpacked yet.
func _unpacked(what: StringName) -> int:
	var count := 0
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		count += box.delivery.spools.size() if what == &"spools" else (1 if box.delivery.printer != &"" else 0)
	return count
