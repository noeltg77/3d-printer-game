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
## Every marketplace in the data, by id. Only the unlocked ones take orders.
var markets: Dictionary[StringName, Marketplace] = {}
## The first marketplace: the one a new business starts on.
var market: Marketplace
var trends: Trends
var supplier: Supplier
var studio: DesignStudio
var owned_designs: Array[StringName] = []
## Mailer boxes in stock, one used per packed order.
var packaging := 0
## How far the business has grown: 1 garage to 4 factory. Decides what the
## shops will sell (each row's `unlock_tier`).
var tier := 1
## Dev: the tier a new game starts at, from --tier=<n>.
var start_tier := 1
## Id of the place the business runs from (data/premises.json).
var premises: StringName = &"garage"
## Dev: the premises a new game starts in, from --premises=<id>.
var start_premises := ""

## The state of the world being carried from one scene to the next, when the
## business moves or a save belongs to different premises from the scene loaded.
var _handover: Dictionary = {}
var _has_handover := false
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
		elif arg.begins_with("--tier="):
			start_tier = arg.trim_prefix("--tier=").to_int()
		elif arg.begins_with("--premises="):
			start_premises = arg.trim_prefix("--premises=")
	new_game()


func _process(delta: float) -> void:
	var before := clock.minutes
	clock.advance(delta)
	for delivery in supplier.collect_due(clock.minutes):
		delivery_arrived.emit(delivery)
		notify("Delivery arrived: %s" % delivery.describe())
		changed.emit()
	if trends.tick(clock.minutes, rng):
		_share_trends()
		notify("In demand this week: %s. Gone quiet: %s." % [trends.category_name(trends.hot), trends.category_name(trends.cool).to_lower()])
		changed.emit()
	for shop: Marketplace in markets.values():
		if not unlocked(shop.config):
			continue
		for order in shop.tick(before, clock.minutes, rng):
			notify("New order on %s: %s for %s" % [shop.config["name"], product_name(order.product), Money.format(order.price)])
			changed.emit()
		for order in shop.expire(clock.minutes):
			notify("Order %s was cancelled: not dispatched in time" % shop.order_label(order), &"bad")
			changed.emit()
		for outcome in shop.deliver(clock.minutes, rng, data.settings["courier"]):
			_settle_delivery(outcome)
	if clock.crossed(before, data.settings["courier_minute_of_day"]):
		courier_arrived.emit()
	var rent := int(premises_row()["rent_pence_per_day"])
	if rent > 0 and clock.crossed(before, 0.0):
		bank.charge(rent, "Rent: %s" % premises_row()["name"], clock.minutes)
		notify("Rent paid on the %s: %s" % [String(premises_row()["name"]).to_lower(), Money.format(rent)])
		changed.emit()


func new_game() -> void:
	data = GameData.load_all()
	var start: Dictionary = data.settings["start"]
	clock = GameClock.new()
	clock.minutes = start["minute_of_day"]
	bank = Bank.new(int(start["cash_pence"]))
	markets.clear()
	for market_id: String in data.marketplaces:
		var shop := Marketplace.new(data.marketplaces[market_id], data.products)
		shop.comments = data.review_comments
		shop.plain_star_penalty = float(data.toggles["multicolour"]["off_star_penalty"])
		markets[StringName(market_id)] = shop
	market = markets.values()[0]
	trends = Trends.new(data.products, data.settings["trends"])
	supplier = Supplier.new(data)
	studio = DesignStudio.new(data.products, data.settings["design"])
	owned_designs.assign(start["designs"])
	packaging = int(start["packaging"])
	premises = StringName(start_premises if data.premises.has(start_premises) else start["premises"])
	tier = maxi(int(premises_row()["tier"]), start_tier)
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
		"clock": clock.save(), "bank": bank.save(), "markets": _save_markets(), "supplier": supplier.save(),
		"trends": trends.save(),
		"studio": studio.save(),
		"owned_designs": owned_designs, "packaging": packaging, "tier": tier, "premises": premises,
	}


## Puts the business back from save(). Designs the game no longer has are dropped.
func restore(state: Dictionary) -> void:
	clock.restore(state["clock"])
	bank.restore(state["bank"])
	# Saves from before there was more than one marketplace hold just the first.
	if state.has("market"):
		market.restore(state["market"])
	for market_id: String in state.get("markets", {}):
		if markets.has(StringName(market_id)):
			markets[StringName(market_id)].restore(state["markets"][market_id])
	if state.has("trends"):
		trends.restore(state["trends"])
	_share_trends()
	supplier.restore(state["supplier"])
	if state.has("studio"):
		studio.restore(state["studio"])
	_share_own_designs()
	owned_designs.clear()
	for product: String in state["owned_designs"]:
		if data.products.has(product):
			owned_designs.append(StringName(product))
	packaging = int(state["packaging"])
	if data.premises.has(state.get("premises", "")):
		premises = StringName(state["premises"])
	tier = maxi(maxi(int(state.get("tier", 1)), int(premises_row()["tier"])), start_tier)
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


## Row from data/premises.json for where the business is now.
func premises_row() -> Dictionary:
	return data.premises[premises]


## Why the business can't move to other premises right now, or "" if it can.
func move_problem(place: StringName) -> String:
	var row: Dictionary = data.premises[place]
	if place == premises:
		return "You are here"
	if int(row["tier"]) < tier:
		return "You have outgrown it"
	if not bank.can_afford(int(row["move_cost_pence"])):
		return "Not enough cash"
	for printer: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		if printer.status == PrinterStation.Status.PRINTING:
			return "Wait for your prints to finish first"
	return ""


## Pays to move the business to other premises. The scene change is the
## caller's job (WorldSave.move). False if it can't be done.
func move_to(place: StringName) -> bool:
	if move_problem(place) != "":
		return false
	var row: Dictionary = data.premises[place]
	bank.spend(int(row["move_cost_pence"]), "Move to the %s" % String(row["name"]).to_lower(), clock.minutes)
	premises = place
	tier = maxi(tier, int(row["tier"]))
	notify("Moved in to the %s" % String(row["name"]).to_lower(), &"good")
	changed.emit()
	return true


## Leaves the state of the world for the next scene to pick up.
func hand_over(world: Dictionary) -> void:
	_handover = world
	_has_handover = true


func has_handover() -> bool:
	return _has_handover


## The world left by hand_over(). It can only be taken once.
func take_handover() -> Dictionary:
	var world := _handover
	_handover = {}
	_has_handover = false
	return world


## True if the business has grown enough for a data row (anything with an
## `unlock_tier`) to be on sale.
func unlocked(row: Dictionary) -> bool:
	return int(row["unlock_tier"]) <= tier


## "Garage", "Spare room" and so on.
func tier_name() -> String:
	return data.settings["tier_names"][tier - 1]


func product_name(product: StringName) -> String:
	return data.products[product]["name"]


func owns(product: StringName) -> bool:
	return owned_designs.has(product)


## Filament a design uses at a preset, in grams.
func print_grams(product: StringName, preset: StringName) -> float:
	return float(data.products[product]["filament_grams"]) * float(data.presets[preset]["filament_multiplier"])


## Chance (0 to 1) that printing a design this way goes wrong. `wear` and
## `mods` are the state of the printer's parts and its upgrades, if it has any.
## `swaps` is how many times its multicolour unit changes colour in the print.
func fail_chance(printer: Dictionary, preset: StringName, filament: StringName, product: StringName,
		wear: PrinterWear = null, mods: PrinterMods = null, moisture := 0.0, swaps := 0) -> float:
	var spec := mods.apply(printer) if mods != null else printer
	var extra := Moisture.extra_fail_chance(moisture, data.settings["moisture"]) + (wear.extra_fail_chance() if wear != null else 0.0)
	if mods != null:
		extra += Multicolour.jam_chance(mods.unit(), swaps)
	var chance := PrintRisk.fail_chance(spec, data.presets[preset], data.filaments[filament], data.products[product], extra)
	if mods == null:
		return chance
	var flags := _print_flags(spec, preset, product, wear, moisture, filament, mods, swaps)
	return chance * PrintRisk.upgrade_scale(data.failures, flags, data.filaments[filament], _failure_multipliers(mods))


## Decides the fate of a print as it starts. Returns {} if it will go well, or
## { failure, at } with the failure's row and the progress at which it strikes.
func roll_print(printer: Dictionary, preset: StringName, filament: StringName, product: StringName,
		wear: PrinterWear = null, mods: PrinterMods = null, moisture := 0.0, swaps := 0) -> Dictionary:
	if data.failures.has(force_failure):
		var forced: Dictionary = data.failures[force_failure]
		force_failure = ""
		return {"failure": forced, "at": PrintRisk.strike_point(forced, rng)}
	var spec := mods.apply(printer) if mods != null else printer
	return PrintRisk.roll(fail_chance(printer, preset, filament, product, wear, mods, moisture, swaps), data.failures,
		_print_flags(spec, preset, product, wear, moisture, filament, mods, swaps), data.filaments[filament], rng,
		_failure_multipliers(mods))


## The condition flags for a print: from the printer, preset and design, plus
## any worn parts, wet filament and what a multicolour unit adds.
func _print_flags(spec: Dictionary, preset: StringName, product: StringName, wear: PrinterWear, moisture := 0.0,
		filament: StringName = &"pla", mods: PrinterMods = null, swaps := 0) -> Array[StringName]:
	var flags := PrintRisk.conditions(spec, data.presets[preset], data.products[product])
	if Moisture.is_wet(moisture, data.settings["moisture"]):
		flags.append(&"wet_filament")
	if wear != null:
		flags.append_array(wear.flags())
	if mods != null:
		flags.append_array(Multicolour.flags(mods.unit(), data.filaments[filament], swaps, data.settings["multicolour"]))
	return flags


## Failure id -> multiplier on its weight, from a printer's upgrades and how
## prone its multicolour unit is to jamming.
func _failure_multipliers(mods: PrinterMods) -> Dictionary:
	if mods == null:
		return {}
	var multipliers := mods.failure_multipliers()
	multipliers.merge(Multicolour.failure_multipliers(mods.unit(), data.settings["multicolour"]))
	return multipliers


## True once the business is big enough to make its own designs.
func design_unlocked() -> bool:
	return tier >= int(data.settings["design"]["unlock_tier"])


## Why the next version of an own design can't be started, or "" if it can.
func design_problem(product: StringName) -> String:
	if not design_unlocked():
		return "Needs a bigger space"
	if studio.needs_fix(product):
		return "Fix its fault first"
	if studio.has(product) and not studio.can_improve(product):
		return "As good as it gets"
	return ""


## The character has finished the next version of an own design at the PC.
func finish_design(product: StringName) -> void:
	var record := studio.complete(product, rng)
	if not owns(product):
		owned_designs.append(product)
	_share_own_designs()
	notify("Your own %s is ready: version %d, quality %d out of %d. Print one to test it." % [
		product_name(product), record["version"], record["quality"], int(data.settings["design"]["max_quality"])], &"good")
	changed.emit()


## The character has put right a fault a test print found.
func finish_design_fix(product: StringName) -> void:
	studio.fix(product)
	notify("Fixed the fault in your %s design" % product_name(product), &"good")
	changed.emit()


## Tells the marketplaces which designs are the business's own.
func _share_own_designs() -> void:
	for shop: Marketplace in markets.values():
		shop.own_appeal.clear()
		for product in studio.designs:
			shop.own_appeal[product] = studio.appeal(product)


## Tells the marketplaces what is in and out of fashion.
func _share_trends() -> void:
	for shop: Marketplace in markets.values():
		shop.trend = trends.multipliers()


func _save_markets() -> Dictionary:
	var saved := {}
	for market_id in markets:
		saved[market_id] = markets[market_id].save()
	return saved


## The marketplaces the business can sell on now.
func open_markets() -> Array[Marketplace]:
	var found: Array[Marketplace] = []
	for shop: Marketplace in markets.values():
		if unlocked(shop.config):
			found.append(shop)
	return found


## The marketplace an order was placed on.
func market_of(order: Marketplace.Order) -> Marketplace:
	return markets.get(order.market, market)


## Orders waiting to be packed, across every marketplace, most urgent first.
func open_orders() -> Array[Marketplace.Order]:
	var found: Array[Marketplace.Order] = []
	for shop in open_markets():
		found.append_array(shop.open_orders())
	found.sort_custom(func(a: Marketplace.Order, b: Marketplace.Order) -> bool: return a.due_at < b.due_at)
	return found


## True if any design is up for sale anywhere.
func anything_listed() -> bool:
	for shop in open_markets():
		if shop.listings.values().any(func(entry: Dictionary) -> bool: return entry["listed"]):
			return true
	return false


## Buys a design licence. False if it is already owned, is for a later tier than the
## business has reached, or can't be afforded.
func buy_design(product: StringName) -> bool:
	if owns(product) or not unlocked(data.products[product]):
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
	if not basket.get("dryers", {}).is_empty():
		var spot: DryerSpot = get_tree().get_first_node_in_group(&"dryer_spot")
		var on_its_way := supplier.pending.any(func(delivery: Supplier.Delivery) -> bool: return delivery.dryer != &"")
		if on_its_way or get_tree().get_nodes_in_group(&"delivery_box").any(func(box: DeliveryBox) -> bool: return box.delivery.dryer != &""):
			return "A dryer is already on its way"
		if spot != null and basket["dryers"].has(String(spot.dryer_id())):
			return "You already have this one"
		if spot != null and spot.problem() != "":
			return spot.problem()
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


## What is left from one sale at `price` after costs and a marketplace's fees
## and royalty. The first marketplace's, unless told which.
func unit_profit(product: StringName, price: int, shop: Marketplace = null) -> int:
	if shop == null:
		shop = market
	return price - unit_cost(product) - shop.fee_for(price) - shop.royalty_for(product, price)


## Finished items of a design on the shelves.
func stock_of(product: StringName) -> int:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	return shelf.count_of(product) if shelf != null else 0


## Takes payment for a dispatched order, less the marketplace's cut.
func complete_sale(order: Marketplace.Order) -> void:
	var transit: Array = data.settings["courier"]["delivery_minutes"]
	var shop := market_of(order)
	var sale := shop.ship(order, clock.minutes, clock.minutes + rng.randf_range(transit[0], transit[1]))
	var market_name: String = shop.config["name"]
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
		var market_name: String = market_of(order).config["name"]
		var why := "arrived broken" if order.refund_reason == "damaged" else "sent back"
		bank.charge(refund["price"], "Refund: %s (%s)" % [title, why], clock.minutes)
		if refund["fee"] > 0:
			bank.earn(refund["fee"], "%s fees returned" % market_name, clock.minutes)
		if refund["royalty"] > 0:
			bank.earn(refund["royalty"], "Design royalty returned: %s" % title, clock.minutes)
		notify("Order %s %s: %s refunded. \"%s\"" % [market_of(order).order_label(order), why, Money.format(refund["price"]), review["text"]], &"bad")
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
