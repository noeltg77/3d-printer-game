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
## What the mailer boxes of an old save are now.
const LEGACY_PACKAGING := Supplier.LEGACY_PACKAGING
## Kind of fitting (data/fittings.json) -> group of the node it adds to.
const FITTING_HOSTS := {"shelf": &"print_storage", "rack": &"filament_rack", "bench": &"workbench"}

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
## The rules for reordering what runs low (the Stockroom app).
var stock: Stockroom
## Enquiries from business clients and the contracts taken on (the Inbox app).
var contracts: Contracts
## The team, and who has applied to join it (the Rota app).
var staff: Staff
## What is happening to the business from outside, and the milestones it has reached.
var events: Events
var milestones: Milestones
## Running totals the milestones are judged on. See stat_view() for the rest.
var stats: Dictionary[String, int] = {}
var owned_designs: Array[StringName] = []
## The rules of packaging and postage (Shipping), and what the player has
## chosen: the packaging each design goes out in, where they have said (design
## id -> packaging id), and the courier's service each marketplace sends by
## (marketplace id -> service id).
var shipping: Shipping
## The rules of bought shelving and racks, and of printed storage bins.
var storage: StorageRules
var pack_choice: Dictionary[StringName, StringName] = {}
var service_choice: Dictionary[StringName, StringName] = {}
## Packaging in stock, by kind (data/packaging.json). One is used per packed order.
var packaging: Dictionary[StringName, int] = {}
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
## Stock key -> why its last reorder couldn't be placed, so the player is told once.
var _stock_blocked: Dictionary[String, String] = {}


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
		for outcome in shop.deliver(clock.minutes, rng, usual_shipping()):
			_settle_delivery(outcome)
	if clock.crossed(before, data.settings["courier_minute_of_day"]):
		courier_arrived.emit()
	var rent := int(premises_row()["rent_pence_per_day"])
	if rent > 0 and clock.crossed(before, 0.0):
		bank.charge(rent, "Rent: %s" % premises_row()["name"], clock.minutes)
		notify("Rent paid on the %s: %s" % [String(premises_row()["name"]).to_lower(), Money.format(rent)])
		changed.emit()
	if staff_capacity() > 0 and (clock.crossed(before, 0.0) or (staff.applicants.is_empty() and staff.team.size() < staff_capacity())):
		staff.refresh_applicants(rng, tier)
		changed.emit()
	var wages := staff.wages_per_day()
	if wages > 0 and clock.crossed(before, 0.0):
		bank.charge(wages, "Wages", clock.minutes)
		notify("Wages paid: %s" % Money.format(wages))
		changed.emit()
	if contracts_unlocked():
		_run_contracts(before)
	if tier >= int(data.settings["events"]["unlock_tier"]):
		_run_events()
	for row in milestones.check(stat_view(), clock.minutes):
		notify("Milestone: %s. %s" % [row["name"], milestone_text(row)], &"good")
		changed.emit()
	var stock_check := float(data.settings["stock"]["check_minutes"])
	if stock_unlocked() and floorf(clock.minutes / stock_check) != floorf(before / stock_check):
		restock()


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
	stock = Stockroom.new(data)
	contracts = Contracts.new(data)
	staff = Staff.new(data)
	events = Events.new(data.events, data.settings["events"])
	milestones = Milestones.new(data.milestones)
	stats = {"sales": 0, "month": 0, "month_pence": 0, "best_month_pence": 0, "streak": 0, "best_streak": 0,
		"contracts_done": 0, "largest_contract": 0, "staff_hired": 0, "moulded_items": 0}
	_stock_blocked.clear()
	owned_designs.assign(start["designs"])
	shipping = Shipping.new(data)
	storage = StorageRules.new(data)
	pack_choice.clear()
	service_choice.clear()
	packaging.clear()
	for kind: String in start["packaging"]:
		packaging[StringName(kind)] = int(start["packaging"][kind])
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
		"stock": stock.save(),
		"contracts": contracts.save(),
		"staff": staff.save(),
		"events": events.save(), "milestones": milestones.save(), "stats": stats,
		"owned_designs": owned_designs, "packaging": packaging, "tier": tier, "premises": premises,
		"pack_choice": pack_choice, "service_choice": service_choice,
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
	if state.has("stock"):
		stock.restore(state["stock"])
	if state.has("contracts"):
		contracts.restore(state["contracts"])
	if state.has("staff"):
		staff.restore(state["staff"])
	if state.has("events"):
		events.restore(state["events"])
	if state.has("milestones"):
		milestones.restore(state["milestones"])
	for stat: String in state.get("stats", {}):
		if stats.has(stat):
			stats[stat] = int(state["stats"][stat])
	_share_events()
	_share_own_designs()
	owned_designs.clear()
	for product: String in state["owned_designs"]:
		if data.products.has(product):
			owned_designs.append(StringName(product))
	packaging.clear()
	# Saves from before there was a choice of packaging hold a count of mailer boxes.
	var saved_packaging: Variant = state["packaging"]
	if not saved_packaging is Dictionary:
		saved_packaging = {LEGACY_PACKAGING: saved_packaging}
	for kind: String in saved_packaging:
		if data.packaging.has(kind):
			packaging[StringName(kind)] = int(saved_packaging[kind])
	pack_choice.clear()
	for product: String in state.get("pack_choice", {}):
		if data.products.has(product) and data.packaging.has(state["pack_choice"][product]):
			pack_choice[StringName(product)] = StringName(state["pack_choice"][product])
	service_choice.clear()
	for market_id: String in state.get("service_choice", {}):
		if markets.has(StringName(market_id)) and data.services.has(state["service_choice"][market_id]):
			service_choice[StringName(market_id)] = StringName(state["service_choice"][market_id])
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
	for worker: Agent in get_tree().get_nodes_in_group(&"staff"):
		if not worker.is_between_tasks():
			return "Wait for your staff to finish what they are doing"
	if staff.team.size() > int(row.get("staff", 0)):
		return "There is no room for your staff there"
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
	for kind: String in FITTING_HOSTS:
		var wanted := 0
		for fitting_id: String in basket.get("fittings", {}):
			if data.fittings[fitting_id]["kind"] == kind:
				wanted += int(basket["fittings"][fitting_id])
		if wanted > 0 and fitting_count(kind) + wanted > storage.limit(premises_row(), kind):
			return "No room here for more %s" % {"shelf": "shelving", "rack": "filament racks", "bench": "printer racks"}[kind]
	return ""


## The node that takes on bought fittings of a kind: the shelving, the
## filament rack or the workbench.
func fitting_host(kind: String) -> Interactable:
	return get_tree().get_first_node_in_group(FITTING_HOSTS[kind])


## Takes payment for a printer sold second hand, once the courier has it.
func complete_resale(title: String, pence: int) -> void:
	bank.earn(pence, "Sold second hand: %s" % title, clock.minutes)
	notify("The %s has gone to its buyer: %s" % [title, Money.format(pence)], &"good")
	changed.emit()


## How many units of a kind of fitting ("shelf", "rack" or "bench") the
## business has: standing in the room, waiting to be put up, or on their way.
func fitting_count(kind: String) -> int:
	var host := fitting_host(kind)
	var count: int = host.call(&"unit_count") if host != null else 1
	var boxed: Array[Supplier.Delivery] = supplier.pending.duplicate()
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		boxed.append(box.delivery)
	for delivery in boxed:
		if delivery.fitting != &"" and data.fittings[delivery.fitting]["kind"] == kind:
			count += 1
	return count


## Pays for a basket and schedules its deliveries. `shop` is the name of the
## shop it was bought from. `quiet` leaves the announcing to the caller.
## False if it can't be ordered.
func place_supplier_order(basket: Dictionary, shop := "", quiet := false) -> bool:
	if supplier_problem(basket) != "":
		return false
	if shop == "":
		shop = data.settings["supplier"]["hardware_shop"]
	bank.spend(supplier.price_of(basket), "%s order" % shop, clock.minutes)
	supplier.place(basket, clock.minutes, shop)
	if not quiet:
		notify("Order placed with %s" % shop)
	changed.emit()
	return true


## Starts and ends events, and does what each one does.
func _run_events() -> void:
	for over in events.expire(clock.minutes):
		var row: Dictionary = data.events[over["id"]]
		_share_events()
		if row["over"] != "":
			notify(String(row["over"]).format({"what": event_target_name(over)}))
		changed.emit()
	var event := events.tick(clock.minutes, rng, tier, _event_candidates())
	if not event.is_empty():
		_begin_event(event)


## Carries out an event that has just started and tells the player.
func _begin_event(event: Dictionary) -> void:
	var row: Dictionary = data.events[event["id"]]
	var what := event_target_name(event)
	match row["kind"]:
		"power_cut":
			for printer: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
				printer.power_cut()
		"client_bust":
			var contract := contracts.by_id(int(event["target"]))
			var paid := contracts.bust(contract, clock.minutes)
			if paid > 0:
				bank.earn(paid, "Contract wound up: %s" % client_name(contract), clock.minutes)
	_share_events()
	notify(String(row["text"]).format({"what": what}), StringName(row["tone"]))
	changed.emit()


## What each kind of event could happen to right now (Events.tick).
func _event_candidates() -> Dictionary:
	var listed: Array[StringName] = []
	for shop in open_markets():
		for product in shop.listings:
			if shop.listings[product]["listed"] and not listed.has(product):
				listed.append(product)
	# A shortage is of something the business uses: what it has in stock, or failing that anything on sale.
	var filaments: Array[String] = []
	for key: String in stock_levels():
		var material := FilamentRules.material_of(key.trim_prefix(Stockroom.SPOOL))
		if Stockroom.is_spool(key) and not filaments.has(material):
			filaments.append(material)
	if filaments.is_empty():
		for filament: Dictionary in data.filaments.values():
			if unlocked(filament) and FilamentRules.has_a_use(data.products, filament):
				filaments.append(filament["id"])
	var printing := get_tree().get_nodes_in_group(&"printer").filter(
		func(printer: PrinterStation) -> bool: return printer.status == PrinterStation.Status.PRINTING)
	return {"product": listed, "filament": filaments, "printing": printing.slice(0, 1),
		"contract": contracts.active().map(func(contract: Contracts.Contract) -> int: return contract.id)}


## What an event is happening to, by name: a design, a filament or a client.
func event_target_name(event: Dictionary) -> String:
	match data.events[event["id"]]["target"]:
		"product":
			return product_name(event["target"]) if data.products.has(event["target"]) else "design"
		"filament":
			return data.filaments[event["target"]]["name"] if data.filaments.has(event["target"]) else "filament"
		"contract":
			var contract := contracts.by_id(int(event["target"]))
			return client_name(contract) if contract != null else "A client"
	return ""


## Tells the marketplaces and the supplier what the events going on are doing
## to demand and to prices.
func _share_events() -> void:
	var boost: Dictionary[StringName, float] = {}
	supplier.price_multipliers.clear()
	for event in events.active:
		match data.events[event["id"]]["kind"]:
			"demand":
				boost[StringName(event["target"])] = events.multiplier("demand", event["target"])
			"price":
				supplier.price_multipliers[String(event["target"])] = events.multiplier("price", event["target"])
	for shop: Marketplace in markets.values():
		shop.boost = boost


## The figures milestones are judged on: the running totals, and how things stand now.
func stat_view() -> Dictionary:
	var view: Dictionary = stats.duplicate()
	view["tier"] = tier
	return view


## A milestone's description, with any amount of money in the player's currency.
func milestone_text(row: Dictionary) -> String:
	return String(row["description"]).format({"amount": Money.format(int(row["at"]))})


## Counts money taken towards the best thirty days the business has had.
func _count_takings(pence: int) -> void:
	var month := floori(clock.minutes / GameClock.DAY / 30.0)
	if month != stats["month"]:
		stats["month"] = month
		stats["month_pence"] = 0
	stats["month_pence"] += pence
	stats["best_month_pence"] = maxi(stats["best_month_pence"], stats["month_pence"])


## How many staff the premises have room for. None until there is a workshop.
func staff_capacity() -> int:
	return int(premises_row().get("staff", 0))


## Takes on one of today's applicants. False if it can't be done.
func hire_staff(index: int) -> bool:
	var member := staff.hire(index, clock.minutes, staff_capacity())
	if member.is_empty():
		return false
	stats["staff_hired"] += 1
	notify("%s has joined as your %s" % [member["name"], String(data.roles[member["role"]]["name"]).to_lower()], &"good")
	changed.emit()
	return true


func fire_staff(id: int) -> void:
	var member := staff.member(id)
	if member.is_empty():
		return
	notify("%s has left the business" % member["name"])
	staff.fire(id)
	changed.emit()


func set_staff_shift(id: int, shift: String) -> void:
	staff.set_shift(id, shift)
	changed.emit()


## True once the business is big enough for clients to come to it.
func contracts_unlocked() -> bool:
	return tier >= int(data.settings["contracts"]["unlock_tier"])


## Brings in new enquiries, lapses old ones and ends contracts that are far too late.
func _run_contracts(before: float) -> void:
	var enquiry := contracts.tick(before, clock.minutes, rng, owned_designs, tier)
	if enquiry != null:
		notify("New enquiry in your inbox: %s would like %d x %s" % [client_name(enquiry), enquiry.quantity, product_name(enquiry.product)])
		changed.emit()
	if not contracts.expire(clock.minutes).is_empty():
		changed.emit()
	for lost in contracts.fail_overdue(clock.minutes):
		var contract: Contracts.Contract = lost["contract"]
		if lost["payment"] > 0:
			bank.earn(lost["payment"], "Contract cut short: %s" % client_name(contract), clock.minutes)
		notify("%s have given up waiting for their %s and cancelled. They paid %s for the %d that arrived." % [
			client_name(contract), product_name(contract.product), Money.format(lost["payment"]), contract.delivered], &"bad")
		changed.emit()


func client_name(contract: Contracts.Contract) -> String:
	return data.clients[contract.client]["name"]


## Takes on an enquiry. False if it can't be.
func accept_contract(contract: Contracts.Contract) -> bool:
	if not contracts.accept(contract, clock.minutes, float(data.settings["courier_minute_of_day"])):
		return false
	notify("Contract agreed with %s: %d x %s" % [client_name(contract), contract.quantity, product_name(contract.product)], &"good")
	changed.emit()
	return true


func decline_contract(contract: Contracts.Contract) -> void:
	contracts.decline(contract)
	changed.emit()


## The designs that can be printed now: those the business owns, and those a
## client has supplied for a contract in progress.
func printable_designs() -> Array[StringName]:
	var found := owned_designs.duplicate()
	for contract in contracts.active():
		if not found.has(contract.product):
			found.append(contract.product)
	return found


## How many finished prints on the shelves could go to a contract now.
func contract_ready(contract: Contracts.Contract) -> int:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	return mini(shelf.items_for(contract).size(), contracts.remaining(contract)) if shelf != null else 0


## The courier has taken a crate for a contract. The last one gets it paid.
func ship_contract(id: int, count: int) -> void:
	var contract := contracts.by_id(id)
	if contract == null:
		return
	var outcome := contracts.deliver(contract, count, clock.minutes)
	if not outcome.is_empty():
		bank.earn(outcome["payment"], "Contract: %s" % client_name(contract), clock.minutes)
		stats["contracts_done"] += 1
		stats["largest_contract"] = maxi(stats["largest_contract"], contract.quantity)
		_count_takings(outcome["payment"])
		if outcome["penalty"] > 0:
			notify("%s have their %d x %s, late. They paid %s, after taking off %s." % [client_name(contract), contract.quantity,
				product_name(contract.product), Money.format(outcome["payment"]), Money.format(outcome["penalty"])], &"bad")
		else:
			notify("%s have their %d x %s, on time, and paid %s" % [client_name(contract), contract.quantity,
				product_name(contract.product), Money.format(outcome["payment"])], &"good")
	changed.emit()


## True once the business is big enough for stock to reorder itself.
func stock_unlocked() -> bool:
	return tier >= int(data.settings["stock"]["unlock_tier"])


## Sets the reorder rule for a stock (see Stockroom).
func set_stock_rule(key: String, on: bool, point: int, quantity: int) -> void:
	stock.set_rule(key, on, point, quantity)
	_stock_blocked.erase(key)
	changed.emit()


## What is in stock and on its way, by Stockroom key, as { have, coming }.
## Spools count if they are on the rack or in a printer and not nearly empty;
## spare parts if they are on the shelving. What is coming is whatever has been
## ordered or is sitting in a box by the door.
func stock_levels() -> Dictionary:
	var levels := {}
	var loaded: Array[Spool] = []
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	if rack != null:
		loaded.append_array(rack.spools())
	for printer: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		loaded.append_array(printer.spools.filter(func(spool: Spool) -> bool: return spool != null))
	for spool in loaded:
		_stock_add(levels, Stockroom.spool_key(spool.material, spool.colour), "have", 1 if spool.grams >= Advice.LOW_SPOOL_GRAMS else 0)
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	for box in (shelf.spares() if shelf != null else ([] as Array[SparePart])):
		if data.parts.has(box.part):
			_stock_add(levels, Stockroom.part_key(box.part), "have", box.count)
	for kind in packaging:
		_stock_add(levels, Stockroom.packaging_key(kind), "have", packaging[kind])
	var coming: Array[Supplier.Delivery] = supplier.pending.duplicate()
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		coming.append(box.delivery)
	for delivery in coming:
		for spool in delivery.spools:
			_stock_add(levels, Stockroom.spool_key(FilamentRules.material_of(spool), FilamentRules.colour_of(spool)), "coming", 1)
		for part in delivery.parts:
			if data.parts.has(part):
				_stock_add(levels, Stockroom.part_key(part), "coming", delivery.parts[part])
		for kind in delivery.packaging:
			_stock_add(levels, Stockroom.packaging_key(kind), "coming", delivery.packaging[kind])
	return levels


func _stock_add(levels: Dictionary, key: String, field: String, amount: int) -> void:
	if not levels.has(key):
		levels[key] = {"have": 0, "coming": 0}
	levels[key][field] += amount


## Orders whatever the stockroom's rules say has run low. Anything there is no
## cash or room for is left out, and the player told why, once.
func restock() -> void:
	var due := stock.due(stock_levels())
	var basket := {}
	var ordered: PackedStringArray = []
	for key in due:
		var with_it := Stockroom.add_to_basket(basket, key, due[key])
		var problem := supplier_problem(with_it)
		if problem == "":
			basket = with_it
			ordered.append(stock_name(key))
			_stock_blocked.erase(key)
		elif _stock_blocked.get(key, "") != problem:
			_stock_blocked[key] = problem
			notify("The stockroom couldn't reorder %s: %s" % [stock_name(key), problem.to_lower()], &"bad")
	if ordered.is_empty():
		return
	for spools: bool in [true, false]:
		var part := Stockroom.shop_part(basket, spools)
		if not part.is_empty():
			place_supplier_order(part, data.settings["supplier"]["filament_shop" if spools else "hardware_shop"], true)
	notify("The stockroom reordered: %s" % ", ".join(ordered))


## What a Stockroom key is called: "Red PLA", "Brass nozzle 0.4mm", "Small cardboard box".
func stock_name(key: String) -> String:
	if Stockroom.is_packaging(key):
		return data.packaging[key.trim_prefix(Stockroom.PACKAGING)]["name"]
	if not Stockroom.is_spool(key):
		return data.parts[key.trim_prefix(Stockroom.PART)]["name"]
	var spool := key.trim_prefix(Stockroom.SPOOL)
	return "%s %s" % [Palette.display_name(FilamentRules.colour_of(spool)), data.filaments[FilamentRules.material_of(spool)]["name"]]


## What one unit of a design costs to make and wrap: filament, electricity on
## the starter printer, and the packaging it goes out in.
func unit_cost(product: StringName) -> int:
	var row: Dictionary = data.products[product]
	var pla: Dictionary = data.filaments["pla"]
	var printer: Dictionary = data.printers.values()[0]
	var filament := float(row["filament_grams"]) / 1000.0 * float(pla["price_pence_per_kg"])
	var kwh := float(printer["power_watts"]) / 1000.0 * float(row["print_minutes"]) / 60.0
	return roundi(filament + kwh * float(data.settings["electricity_pence_per_kwh"]) + packaging_price(packaging_of(product)))


## What is left from one sale at `price` after costs, postage and a
## marketplace's fees and royalty. The first marketplace's, unless told which.
func unit_profit(product: StringName, price: int, shop: Marketplace = null) -> int:
	if shop == null:
		shop = market
	return price - unit_cost(product) - postage_shortfall(product, shop) - shop.fee_for(price) - shop.royalty_for(product, price)


## What one of a kind of packaging costs, in pence. 0 for none.
func packaging_price(kind: StringName) -> float:
	if not data.packaging.has(kind):
		return 0.0
	return float(data.packaging[kind]["price_pence"]) / float(data.packaging[kind]["pack_size"])


## "small cardboard boxes", "poly mailer bags": a kind of packaging, in the plural.
func packaging_plural(kind: StringName) -> String:
	var title := String(data.packaging[kind]["name"]).to_lower()
	return title + ("es" if title.ends_with("x") else "s")


## How many of a kind of packaging are in stock.
func packaging_count(kind: StringName) -> int:
	return int(packaging.get(kind, 0))


func packaging_total() -> int:
	var total := 0
	for kind in packaging:
		total += packaging[kind]
	return total


## Takes one of a kind of packaging out of stock. False if there is none.
func use_packaging(kind: StringName) -> bool:
	if packaging_count(kind) <= 0:
		return false
	packaging[kind] -= 1
	changed.emit()
	return true


func add_packaging(kind: StringName, count: int) -> void:
	packaging[kind] = packaging_count(kind) + count
	changed.emit()


## The packaging a design goes out in: what the player chose for it, if that
## is still something it fits, else the usual box for its size.
func packaging_of(product: StringName) -> StringName:
	var band := shipping.band_of(data.products[product])
	var chosen: StringName = pack_choice.get(product, &"")
	if data.packaging.has(chosen) and unlocked(data.packaging[chosen]) and shipping.fits(data.packaging[chosen], band):
		return chosen
	return shipping.default_packaging(band, tier)


## Every kind of packaging on sale that a design fits in.
func packaging_options(product: StringName) -> Array[StringName]:
	return shipping.packaging_for(shipping.band_of(data.products[product]), tier)


func set_packaging_choice(product: StringName, kind: StringName) -> void:
	pack_choice[product] = kind
	changed.emit()


## The courier's service a marketplace sends by.
func service_of(shop: Marketplace) -> StringName:
	var chosen: StringName = service_choice.get(StringName(shop.config["id"]), &"")
	if data.services.has(chosen) and unlocked(data.services[chosen]):
		return chosen
	return StringName(data.settings["shipping"]["default_service"])


func set_service(shop: Marketplace, service: StringName) -> void:
	service_choice[StringName(shop.config["id"])] = service
	changed.emit()


## How a design sold on a marketplace is sent, as things stand
## (Shipping.terms): in its packaging, by the marketplace's service or, for a
## parcel that service won't take, the nearest that will. {} if nothing will.
func shipping_terms(product: StringName, shop: Marketplace) -> Dictionary:
	var kind := packaging_of(product)
	if kind == &"":
		return {}
	var band := shipping.band_of(data.products[product])
	var service := shipping.service_for(service_of(shop), shipping.parcel_band(data.packaging[kind], band), tier)
	if service == &"":
		return {}
	return shipping.terms(data.packaging[kind], data.services[service], band)


## How an order from before there was a choice was sent.
func usual_shipping() -> Dictionary:
	return shipping.default_terms(data.products.values()[0], tier)


## What posting one of a design costs the business over what its buyer pays
## towards it. Negative if the buyer pays more than the courier charges.
func postage_shortfall(product: StringName, shop: Marketplace) -> int:
	var terms := shipping_terms(product, shop)
	return int(terms.get("cost", 0)) - int(terms.get("buyer_pays", 0))


## Finished items of a design on the shelves.
func stock_of(product: StringName) -> int:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	return shelf.count_of(product) if shelf != null else 0


## Takes payment for a dispatched order, less the marketplace's cut, and pays
## the courier. The buyer's share of the postage comes in with the sale.
func complete_sale(order: Marketplace.Order) -> void:
	var shop := market_of(order)
	if order.shipping.is_empty():
		order.shipping = usual_shipping()
	var service: Dictionary = data.services[order.shipping["service"]]
	order.late = rng.randf() < float(order.shipping["late_chance"])
	var sale := shop.ship(order, clock.minutes, shipping.arrival(service, clock.minutes, order.late, rng))
	var market_name: String = shop.config["name"]
	bank.earn(sale["price"], "Sale: %s (%s)" % [product_name(order.product), market_name], clock.minutes)
	stats["sales"] += 1
	_count_takings(sale["price"])
	bank.charge(sale["fee"], "%s fees" % market_name, clock.minutes)
	bank.charge(sale["royalty"], "Design royalty: %s" % product_name(order.product), clock.minutes)
	if int(order.shipping["buyer_pays"]) > 0:
		bank.earn(int(order.shipping["buyer_pays"]), "Postage paid by the buyer (%s)" % shop.order_label(order), clock.minutes)
	bank.charge(int(order.shipping["cost"]), "Postage: %s (%s)" % [service["name"], shop.order_label(order)], clock.minutes)
	changed.emit()


## Chance (0 to 1) that an item of this strength arrives broken, sent the
## usual way: or, given a design and the marketplace it is for, the way that
## design is sent from there.
func damage_chance(durability: int, product: StringName = &"", shop: Marketplace = null) -> float:
	var terms := usual_shipping() if product == &"" else shipping_terms(product, shop if shop != null else market)
	return Marketplace.damage_chance(durability, terms) if not terms.is_empty() else 0.0


## Puts a delivered order's refund through the bank and announces how it went.
func _settle_delivery(outcome: Dictionary) -> void:
	var order: Marketplace.Order = outcome["order"]
	var title := product_name(order.product)
	var review: Dictionary = outcome["review"]
	if not outcome["refund"].is_empty():
		var refund: Dictionary = outcome["refund"]
		var market_name: String = market_of(order).config["name"]
		var why: String = {"damaged": "arrived broken", "lost": "lost in the post"}.get(order.refund_reason, "sent back")
		bank.charge(refund["price"], "Refund: %s (%s)" % [title, why], clock.minutes)
		if int(order.shipping.get("buyer_pays", 0)) > 0:
			bank.charge(int(order.shipping["buyer_pays"]), "Postage refunded (%s)" % market_of(order).order_label(order), clock.minutes)
		# A tracked service pays out for what it loses, up to what it insures.
		var cover := mini(int(order.shipping.get("insured_pence", 0)), int(refund["price"]) + int(order.shipping.get("buyer_pays", 0)))
		if order.refund_reason == "lost" and cover > 0:
			bank.earn(cover, "Insurance: %s" % data.services[order.shipping["service"]]["name"], clock.minutes)
		if refund["fee"] > 0:
			bank.earn(refund["fee"], "%s fees returned" % market_name, clock.minutes)
		if refund["royalty"] > 0:
			bank.earn(refund["royalty"], "Design royalty returned: %s" % title, clock.minutes)
		stats["streak"] = 0
		notify("Order %s %s: %s refunded. \"%s\"" % [market_of(order).order_label(order), why, Money.format(refund["price"]), review["text"]], &"bad")
	elif not review.is_empty():
		var stars := int(review["stars"])
		stats["streak"] = stats["streak"] + 1 if stars >= Marketplace.MAX_STARS else 0
		stats["best_streak"] = maxi(stats["best_streak"], stats["streak"])
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
