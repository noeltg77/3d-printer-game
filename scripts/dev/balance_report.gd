extends SceneTree
## Plays the garage tier many times over with a simple scripted player and
## prints how it went: how long until a second printer is affordable, what a
## day earns, how often things go wrong and what each design is worth. For
## judging balance changes to data/*.json without playing every one by hand.
## Run: godot --headless --path . --script res://scripts/dev/balance_report.gd
## Optional, after `--`: --days=7 --runs=200
##
## It uses the real rules (Marketplace, Supplier, PrintRisk, PrinterWear) but
## not the scene, so the character is a single pair of hands with rough times
## for each job, and the player a set of habits (see PLAYERS).

const STEP := 5.0
## Game minutes of the character's time each job takes, walking included.
const HANDLE_PRINT := 22.0
const PACK_ORDER := 20.0
## Cash kept back when deciding whether something is affordable, in pence.
const RESERVE := 2000
const LOW_FILAMENT_GRAMS := 300.0
const LOW_PACKAGING := 3
## Habits to compare. `reaction` is game minutes before the player notices a
## printer needs them; `preset` is what they always print at.
const PLAYERS: Array[Dictionary] = [
	{"name": "Attentive, Standard", "reaction": 10.0, "preset": "standard"},
	{"name": "Casual, Standard", "reaction": 60.0, "preset": "standard"},
	{"name": "Attentive, Draft", "reaction": 10.0, "preset": "draft"},
	{"name": "Attentive, Strong", "reaction": 10.0, "preset": "strong"},
]

var _data: GameData
var _days := 7
var _runs := 200


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = arg.trim_prefix("--days=").to_int()
		elif arg.begins_with("--runs="):
			_runs = arg.trim_prefix("--runs=").to_int()
	_data = GameData.load_all()
	print("Garage balance: %d runs of %d game days each (one day is 10 minutes of play at 1x)\n" % [_runs, _days])
	for player in PLAYERS:
		_report(player)
	_design_table()
	quit()


func _report(player: Dictionary) -> void:
	var results: Array[Dictionary] = []
	for run in _runs:
		results.append(_play(player, run + 1))
	var second: Array[float] = []
	for result in results:
		if result["second_printer_day"] > 0.0:
			second.append(result["second_printer_day"])
	second.sort()
	print("== %s ==" % player["name"])
	if second.size() * 2 > _runs:
		print("  Second printer bought: day %.1f typically (quickest %.1f, slowest tenth after %.1f), in %d%% of runs" % [
			second[second.size() / 2], second[0], second[int(second.size() * 0.9)], roundi(100.0 * second.size() / _runs)])
	else:
		print("  Second printer bought in only %d%% of runs" % roundi(100.0 * second.size() / _runs))
	print("  Worth at the end (cash + printers): %s    Sold per day: %.1f    Printer busy: %d%%" % [
		_pounds(_mean(results, "worth")), _mean(results, "sold") / _days, roundi(_mean(results, "busy") * 100.0)])
	print("  Prints ruined: %.1f%%   flawed: %.1f%%   parcels refunded: %.1f%%   orders cancelled: %.1f%%   rating: %.2f (orders x%.2f)" % [
		_mean(results, "ruined") * 100.0, _mean(results, "flawed") * 100.0, _mean(results, "refunded") * 100.0,
		_mean(results, "cancelled") * 100.0, _mean(results, "rating"), _mean(results, "rating_multiplier")])
	print("  Spent on spare parts: %s    Parts fitted: %.1f    Breakdowns: %.2f\n" % [
		_pounds(_mean(results, "parts_spend")), _mean(results, "parts_fitted"), _mean(results, "breakdowns")])


## What each design earns for an hour of printer time, and how much of a
## printer's day its orders can fill, at its typical price.
func _design_table() -> void:
	var market := Marketplace.new(_data.marketplaces["craftsy"], _data.products)
	var printer: Dictionary = _data.printers.values()[0]
	var pla: Dictionary = _data.filaments["pla"]
	print("== Designs at their typical price, Standard, on the %s ==" % printer["name"])
	for product: String in _data.products:
		var row: Dictionary = _data.products[product]
		var price := int(row["base_price_pence"])
		var hours := float(row["print_minutes"]) / float(printer["speed_multiplier"]) / 60.0
		var cost := float(row["filament_grams"]) / 1000.0 * float(pla["price_pence_per_kg"]) + _mailer_pence() \
			+ float(printer["power_watts"]) / 1000.0 * hours * float(_data.settings["electricity_pence_per_kwh"])
		var profit := price - cost - market.fee_for(price) - market.royalty_for(StringName(product), price)
		print("  %-26s profit %s   %s an hour   orders fill %4.1f printer hours a day   licence %s" % [
			row["name"], _pounds(profit), _pounds(profit / hours), float(row["demand_per_day"]) * hours,
			_pounds(float(row["licence"]["fee_pence"]))])


## One game from a new start. Returns the figures _report averages.
func _play(player: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var settings: Dictionary = _data.settings
	var preset: Dictionary = _data.presets[player["preset"]]
	var pla: Dictionary = _data.filaments["pla"]
	var clock := GameClock.new()
	clock.minutes = settings["start"]["minute_of_day"]
	var start := clock.minutes
	var bank := Bank.new(int(settings["start"]["cash_pence"]))
	var market := Marketplace.new(_data.marketplaces["craftsy"], _data.products)
	var supplier := Supplier.new(_data)
	var owned: Array[StringName] = []
	owned.assign(settings["start"]["designs"])
	var packaging := int(settings["start"]["packaging"])
	var spools: Array[float] = []
	var spares := {}
	var stock := {}
	var outbox: Array[Marketplace.Order] = []
	var printers: Array[Dictionary] = []
	var hands_free_at := start
	var tally := {"second_printer_day": 0.0, "sold": 0, "prints": 0, "ruined": 0, "flawed": 0, "refunded": 0,
		"breakdowns": 0, "parts_fitted": 0, "parts_spend": 0, "busy_minutes": 0.0, "printer_minutes": 0.0}
	var printer_id: String = _data.printers.keys()[0]
	var printer_spec: Dictionary = _data.printers[printer_id]
	var printers_bought := 1
	_order(supplier, bank, {"printers": {printer_id: 1}, "spools": {"red": 1}}, clock.minutes)
	for product in owned:
		market.set_listing(product, true, int(_data.products[product]["base_price_pence"]))

	while clock.minutes < start + _days * GameClock.DAY:
		var before := clock.minutes
		clock.minutes += STEP
		var now := clock.minutes
		for delivery in supplier.collect_due(now):
			for colour in delivery.spools:
				spools.append(float(pla["spool_grams"]))
			packaging += delivery.packaging
			for part in delivery.parts:
				spares[part] = int(spares.get(part, 0)) + delivery.parts[part]
			if delivery.printer != &"":
				printers.append({"wear": PrinterWear.new(_data.parts, printer_spec, float(settings["wear_rate"])),
					"grams": 0.0, "job": {}, "ends_at": 0.0, "needs_hands_at": -1.0, "waiting": ""})
		market.tick(before, now, rng)
		market.expire(now)
		if clock.crossed(before, settings["courier_minute_of_day"]):
			var transit: Array = settings["courier"]["delivery_minutes"]
			for order in outbox:
				var sale := market.ship(order, now, now + rng.randf_range(transit[0], transit[1]))
				bank.earn(sale["price"], "Sale", now)
				bank.charge(sale["fee"] + sale["royalty"], "Fees", now)
				tally["sold"] += 1
			outbox.clear()
		for outcome in market.deliver(now, rng, settings["courier"]):
			if not outcome["refund"].is_empty():
				var refund: Dictionary = outcome["refund"]
				bank.charge(refund["price"] - refund["fee"] - refund["royalty"], "Refund", now)
				tally["refunded"] += 1

		# Printers: finish what is running, then wait for the player's hands.
		for printer in printers:
			tally["printer_minutes"] += STEP
			if not printer["job"].is_empty() and printer["waiting"] == "":
				tally["busy_minutes"] += STEP
				if now >= printer["ends_at"]:
					_finish(printer, preset, pla, printer_spec, bank, now, tally)
					printer["needs_hands_at"] = now + float(player["reaction"])
			elif printer["job"].is_empty() and printer["needs_hands_at"] < 0.0:
				printer["needs_hands_at"] = now
		# The one pair of hands: printers first, then packing.
		for printer in printers:
			if hands_free_at > now or printer["needs_hands_at"] < 0.0 or printer["needs_hands_at"] > now:
				continue
			var spent := _tend(printer, preset, pla, printer_spec, owned, market, stock, spools, spares, rng, now, tally)
			if spent > 0.0:
				hands_free_at = now + spent
		for order in market.open_orders():
			if hands_free_at > now:
				break
			var shelf: Array = stock.get(order.product, [])
			if shelf.is_empty() or packaging <= 0:
				continue
			shelf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return not a["flawed"] and b["flawed"])
			var item: Dictionary = shelf.pop_front()
			packaging -= 1
			market.mark_packed(order, item["durability"], item["quality"], item["flawed"])
			outbox.append(order)
			hands_free_at = now + PACK_ORDER

		# Shopping, done from the PC in passing.
		var filament := 0.0
		for grams in spools:
			filament += grams
		for printer in printers:
			filament += printer["grams"]
		var coming_spools := supplier.pending.any(func(d: Supplier.Delivery) -> bool: return not d.spools.is_empty())
		if filament < LOW_FILAMENT_GRAMS * maxi(printers.size(), 1) and not coming_spools:
			_order(supplier, bank, {"spools": {"red": 1}}, now)
		var coming_boxes := supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.packaging > 0)
		if packaging < LOW_PACKAGING and not coming_boxes:
			_order(supplier, bank, {"packaging": 1}, now)
		for printer in printers:
			var wear: PrinterWear = printer["wear"]
			for slot in wear.slots():
				var part := wear.fitted[slot]
				var coming := supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.parts.has(part))
				if wear.is_worn(slot) and int(spares.get(part, 0)) == 0 and not coming:
					if _order(supplier, bank, {"parts": {part: 1}}, now):
						tally["parts_spend"] += supplier.price_of({"parts": {part: 1}})
		for product: String in _data.products:
			var fee := int(_data.products[product]["licence"]["fee_pence"])
			if not owned.has(StringName(product)) and bank.cash >= fee + RESERVE and not printers.is_empty():
				bank.spend(fee, "Licence", now)
				owned.append(StringName(product))
				market.set_listing(StringName(product), true, int(_data.products[product]["base_price_pence"]))
		if printers_bought == 1 and owned.size() >= _data.products.size() and bank.cash >= int(printer_spec["price_pence"]) + RESERVE:
			_order(supplier, bank, {"printers": {printer_id: 1}}, now)
			printers_bought = 2
			tally["second_printer_day"] = (now - start) / GameClock.DAY

	var cancelled := market.orders.filter(func(order: Marketplace.Order) -> bool: return order.status == Marketplace.Status.CANCELLED).size()
	return {
		"second_printer_day": tally["second_printer_day"],
		"worth": float(bank.cash + printers_bought * int(printer_spec["price_pence"])),
		"sold": float(tally["sold"]),
		"busy": tally["busy_minutes"] / maxf(tally["printer_minutes"], 1.0),
		"ruined": float(tally["ruined"]) / maxf(tally["prints"], 1.0),
		"flawed": float(tally["flawed"]) / maxf(tally["prints"], 1.0),
		"refunded": float(tally["refunded"]) / maxf(tally["sold"], 1.0),
		"cancelled": float(cancelled) / maxf(market.orders.size(), 1.0),
		"rating": market.rating(),
		"rating_multiplier": market.rating_multiplier(),
		"parts_spend": float(tally["parts_spend"]),
		"parts_fitted": float(tally["parts_fitted"]),
		"breakdowns": float(tally["breakdowns"]),
	}


## A print reaches its end, or the point it failed: wear, power and the result.
func _finish(printer: Dictionary, preset: Dictionary, pla: Dictionary, spec: Dictionary, bank: Bank, now: float, tally: Dictionary) -> void:
	var job: Dictionary = printer["job"]
	var wear: PrinterWear = printer["wear"]
	var fate: Dictionary = job["fate"]
	var ruined: bool = not fate.is_empty() and fate["failure"]["outcome"] != "degraded"
	var share: float = fate["at"] if ruined else 1.0
	var hours: float = job["minutes"] * share / 60.0
	wear.apply(hours, preset, pla)
	bank.charge(roundi(float(spec["power_watts"]) / 1000.0 * hours * float(_data.settings["electricity_pence_per_kwh"])), "Electricity", now)
	tally["prints"] += 1
	if ruined:
		printer["grams"] += job["grams"] * (1.0 - share)
		for slot: String in fate["failure"].get("damages", {}):
			wear.damage(StringName(slot), float(fate["failure"]["damages"][slot]))
		tally["ruined"] += 1
		tally["breakdowns"] += 1 if fate["failure"]["id"] == "breakdown" else 0
		printer["waiting"] = "clear"
	else:
		var item := {"durability": int(preset["durability"]), "quality": int(preset["quality"]), "flawed": false}
		if not fate.is_empty():
			item["flawed"] = true
			item["quality"] = maxi(item["quality"] - int(fate["failure"].get("quality_loss", 1)), 1)
			tally["flawed"] += 1
		job["item"] = item
		printer["waiting"] = "collect"


## The player sees to a printer: clears or collects, fits worn parts, changes
## the spool and starts the next print. Returns the character minutes it took.
func _tend(printer: Dictionary, preset: Dictionary, pla: Dictionary, spec: Dictionary, owned: Array[StringName],
		market: Marketplace, stock: Dictionary, spools: Array[float], spares: Dictionary, rng: RandomNumberGenerator,
		now: float, tally: Dictionary) -> float:
	var spent := 0.0
	var wear: PrinterWear = printer["wear"]
	var job: Dictionary = printer["job"]
	if printer["waiting"] == "clear":
		spent += float(job["fate"]["failure"]["clear_minutes"]) + HANDLE_PRINT * 0.5
	elif printer["waiting"] == "collect":
		if not stock.has(job["product"]):
			stock[job["product"]] = []
		stock[job["product"]].append(job["item"])
		spent += HANDLE_PRINT * 0.5
	printer["job"] = {}
	printer["waiting"] = ""
	for slot in wear.slots():
		var part := wear.fitted[slot]
		if wear.is_worn(slot) and int(spares.get(part, 0)) > 0:
			spares[part] -= 1
			wear.replace(slot, part)
			tally["parts_fitted"] += 1
			spent += float(wear.part(slot)["replace_minutes"])
	if not wear.broken().is_empty():
		printer["needs_hands_at"] = now + STEP
		return spent
	var product := _choose(owned, market, stock)
	if product == &"":
		printer["needs_hands_at"] = now + STEP
		return spent
	var grams := float(_data.products[product]["filament_grams"]) * float(preset["filament_multiplier"])
	if printer["grams"] < grams:
		if spools.is_empty():
			printer["needs_hands_at"] = now + STEP
			return spent
		printer["grams"] = spools.pop_back()
		spent += HANDLE_PRINT * 0.5
	var minutes := float(_data.products[product]["print_minutes"]) * float(preset["time_multiplier"]) / float(spec["speed_multiplier"])
	var flags := PrintRisk.conditions(spec, preset, _data.products[product])
	flags.append_array(wear.flags())
	var chance := PrintRisk.fail_chance(spec, preset, pla, _data.products[product], wear.extra_fail_chance())
	var fate := PrintRisk.roll(chance, _data.failures, flags, pla, rng)
	var breakdown := wear.breaks_during(minutes / 60.0, preset, pla)
	var ruined_at: float = fate["at"] if not fate.is_empty() and fate["failure"]["outcome"] != "degraded" else 1.0
	if not breakdown.is_empty() and breakdown["at"] < ruined_at:
		var failure: Dictionary = _data.failures["breakdown"].duplicate()
		failure["damages"] = {String(breakdown["slot"]): 1.0}
		fate = {"failure": failure, "at": breakdown["at"]}
		ruined_at = breakdown["at"]
	printer["grams"] -= grams
	spent += HANDLE_PRINT * 0.5
	printer["job"] = {"product": product, "grams": grams, "minutes": minutes, "fate": fate}
	printer["ends_at"] = now + spent + minutes * ruined_at
	printer["needs_hands_at"] = -1.0
	return spent


## What to print next: whatever an order is waiting on, else one of each design
## to have ready, else nothing.
func _choose(owned: Array[StringName], market: Marketplace, stock: Dictionary) -> StringName:
	var spare := {}
	for product in owned:
		spare[product] = (stock.get(product, []) as Array).size()
	for order in market.open_orders():
		spare[order.product] = int(spare.get(order.product, 0)) - 1
	var pick: StringName = &""
	for product in owned:
		if spare[product] < 0 and (pick == &"" or spare[product] < spare[pick]):
			pick = product
	if pick != &"":
		return pick
	for product in owned:
		if spare[product] < 1:
			return product
	return &""


## Buys a basket if it can be afforded. Returns whether it was.
func _order(supplier: Supplier, bank: Bank, basket: Dictionary, now: float) -> bool:
	if not bank.spend(supplier.price_of(basket), "Order", now):
		return false
	supplier.place(basket, now)
	return true


func _mailer_pence() -> float:
	var config: Dictionary = _data.settings["supplier"]
	return float(config["packaging_pack_pence"]) / float(config["packaging_pack_size"])


func _mean(results: Array[Dictionary], key: String) -> float:
	var total := 0.0
	for result in results:
		total += float(result[key])
	return total / results.size()


## Report amounts are always pounds: this is a dev tool, not the game's UI.
func _pounds(pence: float) -> String:
	return "%.2f" % (pence / 100.0)
