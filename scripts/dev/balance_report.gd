extends SceneTree
## Plays the game many times over with a simple scripted player and prints how
## it went: how long until a second printer is affordable, what a day earns, how
## often things go wrong and what each design is worth. Then it plays longer
## games that carry on into the small unit: when the move comes, whether the
## rent is covered and what the second marketplace and the new materials add.
## For judging balance changes to data/*.json without playing every one by hand.
## Run: godot --headless --path . --script res://scripts/dev/balance_report.gd
## Optional, after `--`: --days=7 --runs=200 --unit-days=28 --unit-runs=40
##   --part=garage or --part=unit for one half only, --designs=all for every design
##
## It uses the real rules (Marketplace, Supplier, PrintRisk, PrinterWear,
## FilamentRules) but not the scene, so the character is a single pair of hands
## with rough times for each job, and the player a set of habits (see PLAYERS).
##
## The catalogue is far bigger than one room can print, so the player does not
## buy everything. They take the listing (a design on a marketplace) that earns
## most for the time it takes, then the next, until the orders they expect would
## fill PRINTER_SHARE of the printers' day or all of the character's. When it is
## the printers that are full they save for another one, and when there is no
## room for another, for the move. When it is the character who is full they
## trade up: a listing that earns more a sale takes the place of the worst one.

const STEP := 5.0
## Game minutes of the character's time each job takes, walking included.
const HANDLE_PRINT := 22.0
const PACK_ORDER := 20.0
## Cash kept back when deciding whether something is affordable, in pence.
const RESERVE := 2000
const LOW_FILAMENT_GRAMS := 300.0
const LOW_PACKAGING := 3
## Share of a day the player lets expected orders fill. Printers keep some slack
## for failures and for sitting finished until someone comes; the character has none.
const PRINTER_SHARE := 0.8
const HANDS_SHARE := 1.0
const HOURS_IN_DAY := 24.0
## How many designs the short table lists from each end.
const BEST_SHOWN := 10
const WORST_SHOWN := 5
## How much more a sale a listing has to earn to be worth swapping the worst one for.
const TRADE_UP := 1.25
## The tier the long games play up to: the small unit.
const UNIT_TIER := 2
## Days the "a day lately" figures look back over.
const LATELY_DAYS := 7
## The colour every spool is ordered in. Colour makes no difference here.
const SPOOL_COLOUR := "red"
## Habits to compare in the garage. `reaction` is game minutes before the player
## notices a printer needs them; `preset` is what they always print at.
const PLAYERS: Array[Dictionary] = [
	{"name": "Attentive, Standard", "reaction": 10.0, "preset": "standard"},
	{"name": "Casual, Standard", "reaction": 60.0, "preset": "standard"},
	{"name": "Attentive, Draft", "reaction": 10.0, "preset": "draft"},
	{"name": "Attentive, Strong", "reaction": 10.0, "preset": "strong"},
]
## Habits to compare over the longer game. `moves` is whether they take the small
## unit when the garage is full; `buys` is the printer they add (the starter one if
## not given).
const UNIT_PLAYERS: Array[Dictionary] = [
	{"name": "Attentive, adds starter printers", "reaction": 10.0, "preset": "standard", "moves": true},
	{"name": "Attentive, adds fast printers", "reaction": 10.0, "preset": "standard", "moves": true, "buys": "zippy_a1_mini"},
	{"name": "Casual, adds starter printers", "reaction": 60.0, "preset": "standard", "moves": true},
	{"name": "Attentive, stays in the garage", "reaction": 10.0, "preset": "standard", "moves": false},
]

var _data: GameData
var _days := 7
var _runs := 200
var _unit_days := 28
var _unit_runs := 40
var _part := ""
var _all_designs := false
## Id of the printer every game starts with.
var _starter := ""
## Ids of the marketplaces open by the small unit, earliest first.
var _shops: Array[String] = []
## The premises the long games move to.
var _unit: Dictionary = {}
## Every listing with its figures (see _figures), best earner for the time first.
var _wishlist: Array[Dictionary] = []
## product id -> the row of the filament it is printed in.
var _filament_of := {}
## "printer id:product id" -> whether that printer can print it.
var _printable := {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = arg.trim_prefix("--days=").to_int()
		elif arg.begins_with("--runs="):
			_runs = arg.trim_prefix("--runs=").to_int()
		elif arg.begins_with("--unit-days="):
			_unit_days = arg.trim_prefix("--unit-days=").to_int()
		elif arg.begins_with("--unit-runs="):
			_unit_runs = arg.trim_prefix("--unit-runs=").to_int()
		elif arg.begins_with("--part="):
			_part = arg.trim_prefix("--part=")
		elif arg == "--designs=all":
			_all_designs = true
	_data = GameData.load_all()
	_starter = _data.printers.keys()[0]
	for shop_id: String in _data.marketplaces:
		if int(_data.marketplaces[shop_id]["unlock_tier"]) <= UNIT_TIER:
			_shops.append(shop_id)
	_shops.sort_custom(func(a: String, b: String) -> bool:
		return int(_data.marketplaces[a]["unlock_tier"]) < int(_data.marketplaces[b]["unlock_tier"]))
	for place: Dictionary in _data.premises.values():
		if int(place["tier"]) == UNIT_TIER:
			_unit = place
	for product: String in _data.products:
		var row: Dictionary = _data.products[product]
		# A multicolour design wants a multicolour unit, which this player never buys.
		if int(row["unlock_tier"]) > UNIT_TIER or row.get("contract_only", false) or int(row.get("colour_count", 1)) > 1:
			continue
		var filament: Dictionary = _data.filaments[String(row["allowed_filaments"][0])]
		# Nor a hardened nozzle, and gritty filament eats a brass one in a few prints.
		if filament["abrasive"]:
			continue
		_filament_of[StringName(product)] = filament
		for shop_id in _shops:
			_wishlist.append(_figures(product, shop_id))
	_wishlist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["per_hour"] > b["per_hour"])

	if _part != "unit":
		print("Garage balance: %d runs of %d game days each (one day is 10 minutes of play at 1x)\n" % [_runs, _days])
		for player in PLAYERS:
			_report(player)
		_design_table()
	if _part != "garage":
		print("\n%s balance: %d runs of %d game days each, starting in the garage\n" % [_unit["name"], _unit_runs, _unit_days])
		for player in UNIT_PLAYERS:
			_unit_report(player)
		_unit_design_table()
	quit()


func _report(player: Dictionary) -> void:
	var results: Array[Dictionary] = []
	for run in _runs:
		results.append(_play(player, run + 1, _days))
	print("== %s ==" % player["name"])
	print("  Second printer bought%s" % _when(results, "second_printer_day"))
	print("  Worth at the end (cash + printers): %s    Sold per day: %.1f    Printer busy: %d%%    Designs owned: %.1f" % [
		_pounds(_mean(results, "worth")), _mean(results, "sold") / _days, roundi(_mean(results, "busy") * 100.0),
		_mean(results, "designs")])
	_trouble_lines(results)


## The longer game: the same figures, then what the move did.
func _unit_report(player: Dictionary) -> void:
	var results: Array[Dictionary] = []
	for run in _unit_runs:
		results.append(_play(player, run + 1, _unit_days))
	var moved: Array[Dictionary] = results.filter(func(result: Dictionary) -> bool: return result["moved_day"] > 0.0)
	print("== %s ==" % player["name"])
	print("  Second printer bought%s" % _when(results, "second_printer_day"))
	if player.get("moves", false):
		print("  Moved to the %s%s" % [String(_unit["name"]).to_lower(), _when(results, "moved_day")])
		print("  Third printer bought%s" % _when(results, "third_printer_day"))
		print("  Fourth printer bought%s" % _when(results, "fourth_printer_day"))
	print("  Worth at the end (cash + printers): %s    Gaining %s a day over the last %d days    Printers: %.1f" % [
		_pounds(_mean(results, "worth")), _pounds(_mean(results, "lately")), LATELY_DAYS, _mean(results, "printers")])
	print("  Designs owned: %.1f    Listings up: %.1f    Listings traded up: %.1f" % [
		_mean(results, "designs"), _mean(results, "listings"), _mean(results, "traded_up")])
	if not moved.is_empty():
		print("  Gaining a day: %s in the garage before the move, %s in the unit after %s rent" % [
			_pounds(_mean(moved, "gain_before")), _pounds(_mean(moved, "gain_after")), _pounds(float(_unit["rent_pence_per_day"]))])
	var sold := maxf(_mean(results, "sold"), 1.0)
	var by_shop: Array[String] = []
	for shop_id in _shops:
		by_shop.append("%s %d%% (rating %.2f, orders x%.2f)" % [_data.marketplaces[shop_id]["name"],
			roundi(_mean(results, "sold_on_" + shop_id) / sold * 100.0), _mean(results, "rating_" + shop_id),
			_mean(results, "rating_multiplier_" + shop_id)])
	print("  Sold per day: %.1f    Printer busy: %d%%    Sales: %s" % [
		sold / _unit_days, roundi(_mean(results, "busy") * 100.0), ", ".join(by_shop)])
	var by_material: Array[String] = []
	for material: String in _data.filaments:
		var share := _mean(results, "sold_in_" + material) / sold
		if share >= 0.005:
			by_material.append("%s %d%%" % [_data.filaments[material]["name"], roundi(share * 100.0)])
	print("  Sales by filament: %s" % ", ".join(by_material))
	_trouble_lines(results)


## What went wrong along the way, which reads the same for any length of game.
func _trouble_lines(results: Array[Dictionary]) -> void:
	print("  Prints ruined: %.1f%%   flawed: %.1f%%   parcels refunded: %.1f%%   orders cancelled: %.1f%%   rating: %.2f (orders x%.2f)" % [
		_mean(results, "ruined") * 100.0, _mean(results, "flawed") * 100.0, _mean(results, "refunded") * 100.0,
		_mean(results, "cancelled") * 100.0, _mean(results, "rating"), _mean(results, "rating_multiplier")])
	print("  Spent on spare parts: %s    Parts fitted: %.1f    Breakdowns: %.2f\n" % [
		_pounds(_mean(results, "parts_spend")), _mean(results, "parts_fitted"), _mean(results, "breakdowns")])


## ": day 2.4 typically (...), in 100% of runs" for the day something happened, 0 meaning it never did.
func _when(results: Array[Dictionary], key: String) -> String:
	var days: Array[float] = []
	for result in results:
		if result[key] > 0.0:
			days.append(result[key])
	days.sort()
	var share := roundi(100.0 * days.size() / results.size())
	if days.size() * 2 <= results.size():
		return " in only %d%% of runs" % share
	return ": day %.1f typically (quickest %.1f, slowest tenth after %.1f), in %d%% of runs" % [
		days[days.size() / 2], days[0], days[int(days.size() * 0.9)], share]


## What a design is worth on a marketplace at the typical price there, printed at
## Standard on the starter printer in its own filament: profit a sale in pence,
## printer hours a print, the hours of a day its expected orders take from a printer
## and from the character, and profit for each hour of printer and character time
## together. `tier` is when the listing opens: the later of the design's and the
## marketplace's.
func _figures(product: String, shop_id: String) -> Dictionary:
	var market := Marketplace.new(_data.marketplaces[shop_id], _data.products)
	var printer: Dictionary = _data.printers[_starter]
	var filament: Dictionary = _filament_of[StringName(product)]
	var row: Dictionary = _data.products[product]
	var listed := market.typical_price(StringName(product))
	var price := roundi(listed * float(filament["value_multiplier"]))
	var hours := float(row["print_minutes"]) / float(printer["speed_multiplier"]) / float(filament["speed_multiplier"]) / 60.0
	var hands := (HANDLE_PRINT + PACK_ORDER) / 60.0
	var cost := float(row["filament_grams"]) / 1000.0 * float(filament["price_pence_per_kg"]) + _mailer_pence() \
		+ float(printer["power_watts"]) / 1000.0 * hours * float(_data.settings["electricity_pence_per_kwh"])
	var profit := price - cost - market.fee_for(price) - market.royalty_for(StringName(product), price)
	var orders := float(row["demand_per_day"]) * float(market.config.get("audience", 1.0))
	return {
		"id": StringName(product),
		"shop": StringName(shop_id),
		"key": "%s:%s" % [shop_id, product],
		"tier": maxi(int(row["unlock_tier"]), int(market.config["unlock_tier"])),
		"name": row["name"],
		"category": row.get("category_name", String(row["category"]).capitalize()),
		"material": String(filament["id"]),
		"fee": int(row["licence"]["fee_pence"]),
		"listed": listed,
		"profit": profit,
		"hours": hours,
		"per_hour": profit / (hours + hands),
		"printer_load": orders * hours,
		"hands_load": orders * hands,
	}


## The garage's catalogue at typical prices: a line per category, then the best
## and worst earners. `--designs=all` lists every design instead.
func _design_table() -> void:
	var garage := _wishlist.filter(func(wish: Dictionary) -> bool: return wish["tier"] <= 1)
	print("== Designs at their typical price, Standard, on the %s ==" % _data.printers[_starter]["name"])
	print("  \"An hour\" counts printer time and the character's time to handle and pack it.\n")
	if _all_designs:
		for wish in garage:
			_design_line(wish)
		return
	var categories := {}
	for wish in garage:
		if not categories.has(wish["category"]):
			categories[wish["category"]] = []
		categories[wish["category"]].append(wish["per_hour"])
	print("  By category (designs, profit an hour from worst to best):")
	for category: String in categories:
		var rates: Array = categories[category]
		print("    %-28s %3d   %s to %s" % [category, rates.size(), _pounds(rates.min()), _pounds(rates.max())])
	var best := mini(BEST_SHOWN, garage.size())
	var worst := mini(WORST_SHOWN, garage.size() - best)
	print("\n  Best %d:" % best)
	for wish in garage.slice(0, best):
		_design_line(wish)
	if worst > 0:
		print("  Worst %d:" % worst)
		for wish in garage.slice(garage.size() - worst):
			_design_line(wish)


## What the small unit adds: its designs by filament on each marketplace, what the
## garage's designs earn on the new marketplace, and the best of the new listings.
func _unit_design_table() -> void:
	print("== What the %s adds, at typical prices, Standard, on the %s ==" % [String(_unit["name"]).to_lower(), _data.printers[_starter]["name"]])
	print("  Single colour designs in filament a brass nozzle can take. Profit an hour from worst to best, then the middle one.\n")
	for shop_id in _shops:
		var shop_name: String = _data.marketplaces[shop_id]["name"]
		for tier in range(1, UNIT_TIER + 1):
			var groups := {}
			for wish in _wishlist:
				if wish["shop"] != StringName(shop_id) or int(_data.products[String(wish["id"])]["unlock_tier"]) != tier:
					continue
				if not groups.has(wish["material"]):
					groups[wish["material"]] = []
				groups[wish["material"]].append(wish["per_hour"])
			for material: String in groups:
				var rates: Array = groups[material]
				rates.sort()
				var can := "" if _can_print(_starter, _wishlist_id(material)) else "   (not on the %s)" % _data.printers[_starter]["name"]
				print("    %-8s %-18s %-12s %3d   %s to %s, middle %s%s" % [shop_name, _data.settings["tier_names"][tier - 1],
					_data.filaments[material]["name"], rates.size(), _pounds(rates[0]), _pounds(rates[-1]), _pounds(rates[rates.size() / 2]), can])
	var fresh := _wishlist.filter(func(wish: Dictionary) -> bool: return wish["tier"] == UNIT_TIER)
	print("\n  Best %d new listings:" % mini(BEST_SHOWN, fresh.size()))
	for wish in fresh.slice(0, BEST_SHOWN):
		_design_line(wish, true)


## Any design printed in a material, to ask whether a printer can run it.
func _wishlist_id(material: String) -> StringName:
	for wish in _wishlist:
		if wish["material"] == material:
			return wish["id"]
	return &""


func _design_line(wish: Dictionary, with_shop := false) -> void:
	var where := " on %s" % _data.marketplaces[String(wish["shop"])]["name"] if with_shop else ""
	print("    %-40s profit %6s   %5s an hour   orders fill %4.1f printer hours a day   licence %s%s" % [
		wish["name"], _pounds(wish["profit"]), _pounds(wish["per_hour"]), wish["printer_load"], _pounds(wish["fee"]), where])


## True if a printer can print a design at all: it fits the bed and the printer
## can run its filament.
func _can_print(printer_id: String, product: StringName) -> bool:
	var key := "%s:%s" % [printer_id, product]
	if not _printable.has(key):
		var spec: Dictionary = _data.printers[printer_id]
		_printable[key] = PrintRisk.fits(spec, _data.products[String(product)]) \
			and FilamentRules.problem(spec, _filament_of[product]) == ""
	return _printable[key]


## One game from a new start. Returns the figures the reports average.
func _play(player: Dictionary, seed_value: int, days: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var settings: Dictionary = _data.settings
	var preset: Dictionary = _data.presets[player["preset"]]
	var clock := GameClock.new()
	clock.minutes = settings["start"]["minute_of_day"]
	var start := clock.minutes
	var bank := Bank.new(int(settings["start"]["cash_pence"]))
	var supplier := Supplier.new(_data)
	var shops: Dictionary[StringName, Marketplace] = {}
	for shop_id in _shops:
		shops[StringName(shop_id)] = Marketplace.new(_data.marketplaces[shop_id], _data.products)
	var owned: Array[StringName] = []
	owned.assign(settings["start"]["designs"])
	var printers: Array[Dictionary] = []
	# Ids of the printers paid for, the starter first. They count from the day they are ordered.
	var bought: Array[String] = [_starter]
	var outbox: Array[Marketplace.Order] = []
	var tally := {"sold": 0, "prints": 0, "ruined": 0, "flawed": 0, "refunded": 0, "breakdowns": 0, "parts_fitted": 0,
		"parts_spend": 0, "busy_minutes": 0.0, "printer_minutes": 0.0, "printer_days": [], "moved_day": 0.0,
		"worth_at_move": 0.0, "worth_days": [], "traded_up": 0, "sold_on": {}, "sold_in": {}}
	# Everything _tend and _choose need to see, so they take one argument.
	var s := {"rng": rng, "preset": preset, "bank": bank, "shops": shops, "tier": 1, "owned": owned, "printers": printers,
		"place": _data.premises[String(settings["start"]["premises"])], "stock": {}, "spools": {}, "spares": {}, "short": {},
		"selling": {}, "tally": tally}
	var packaging := int(settings["start"]["packaging"])
	var hands_free_at := start
	# Hours of a day the listings' expected orders take, and the cash at which the shopping is worth another look.
	var listed := {}
	var printer_load := 0.0
	var hands_load := 0.0
	for wish in _wishlist:
		if owned.has(wish["id"]) and wish["shop"] == StringName(_shops[0]):
			listed[wish["key"]] = wish
			s["selling"][wish["id"]] = 1
			shops[wish["shop"]].set_listing(wish["id"], true, wish["listed"])
			printer_load += wish["printer_load"]
			hands_load += wish["hands_load"]
	var shop_again_at := 0
	_order(supplier, bank, {"printers": {_starter: 1}, "spools": {SPOOL_COLOUR: 1}}, clock.minutes)

	while clock.minutes < start + days * GameClock.DAY:
		var before := clock.minutes
		clock.minutes += STEP
		var now := clock.minutes
		for delivery in supplier.collect_due(now):
			for key in delivery.spools:
				var material := FilamentRules.material_of(String(key))
				if not s["spools"].has(material):
					s["spools"][material] = []
				s["spools"][material].append(float(_data.filaments[material]["spool_grams"]))
			packaging += delivery.packaging
			for part in delivery.parts:
				s["spares"][part] = int(s["spares"].get(part, 0)) + delivery.parts[part]
			if delivery.printer != &"":
				var spec: Dictionary = _data.printers[String(delivery.printer)]
				printers.append({"id": String(delivery.printer), "spec": spec,
					"wear": PrinterWear.new(_data.parts, spec, float(settings["wear_rate"])),
					"material": "", "grams": 0.0, "job": {}, "ends_at": 0.0, "needs_hands_at": -1.0, "waiting": ""})
		var open := _open_shops(s)
		for market in open:
			market.tick(before, now, rng)
			market.expire(now)
		if clock.crossed(before, settings["courier_minute_of_day"]):
			var transit: Array = settings["courier"]["delivery_minutes"]
			for order in outbox:
				var sale := shops[order.market].ship(order, now, now + rng.randf_range(transit[0], transit[1]))
				bank.earn(sale["price"], "Sale", now)
				bank.charge(sale["fee"] + sale["royalty"], "Fees", now)
				tally["sold"] += 1
				tally["sold_on"][order.market] = int(tally["sold_on"].get(order.market, 0)) + 1
				var material: String = _filament_of[order.product]["id"]
				tally["sold_in"][material] = int(tally["sold_in"].get(material, 0)) + 1
			outbox.clear()
		for market in open:
			for outcome in market.deliver(now, rng, settings["courier"]):
				if not outcome["refund"].is_empty():
					var refund: Dictionary = outcome["refund"]
					bank.charge(refund["price"] - refund["fee"] - refund["royalty"], "Refund", now)
					tally["refunded"] += 1
		if clock.crossed(before, 0.0):
			var rent := int(s["place"]["rent_pence_per_day"])
			if rent > 0:
				bank.charge(rent, "Rent", now)
			tally["worth_days"].append(_worth(bank, bought))

		# Printers: finish what is running, then wait for the player's hands.
		for printer in printers:
			tally["printer_minutes"] += STEP
			if not printer["job"].is_empty() and printer["waiting"] == "":
				tally["busy_minutes"] += STEP
				if now >= printer["ends_at"]:
					_finish(printer, preset, bank, now, tally)
					printer["needs_hands_at"] = now + float(player["reaction"])
			elif printer["job"].is_empty() and printer["needs_hands_at"] < 0.0:
				printer["needs_hands_at"] = now
		# The one pair of hands: printers first, then packing.
		for printer in printers:
			if hands_free_at > now or printer["needs_hands_at"] < 0.0 or printer["needs_hands_at"] > now:
				continue
			var spent := _tend(s, printer, now)
			if spent > 0.0:
				hands_free_at = now + spent
		if hands_free_at <= now:
			for order in _waiting(s):
				if hands_free_at > now:
					break
				var shelf: Array = s["stock"].get(order.product, [])
				if shelf.is_empty() or packaging <= 0:
					continue
				shelf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return not a["flawed"] and b["flawed"])
				var item: Dictionary = shelf.pop_front()
				packaging -= 1
				shops[order.market].mark_packed(order, item["durability"], item["quality"], item["flawed"],
					float(_filament_of[order.product]["value_multiplier"]))
				outbox.append(order)
				hands_free_at = now + PACK_ORDER

		# Shopping, done from the PC in passing. Filament first: a spool of each kind in use.
		var grams_of := {}
		for product in owned:
			grams_of[_filament_of[product]["id"]] = 0.0
		for material: String in s["spools"]:
			for grams: float in s["spools"][material]:
				grams_of[material] = float(grams_of.get(material, 0.0)) + grams
		for printer in printers:
			if printer["material"] != "":
				grams_of[printer["material"]] = float(grams_of.get(printer["material"], 0.0)) + float(printer["grams"])
		for material: String in grams_of:
			# The everyday filament is on every printer; the others are a spool at a time.
			var low := LOW_FILAMENT_GRAMS * (maxi(printers.size(), 1) if material == FilamentRules.DEFAULT_MATERIAL else 1)
			if grams_of[material] >= low and not s["short"].has(material):
				continue
			var coming := supplier.pending.any(func(d: Supplier.Delivery) -> bool:
				return d.spools.any(func(key: StringName) -> bool: return FilamentRules.material_of(String(key)) == material))
			if not coming:
				_order(supplier, bank, {"spools": {FilamentRules.spool_key(material, SPOOL_COLOUR): 1}}, now)
		s["short"].clear()
		var coming_boxes := supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.packaging > 0)
		if packaging < LOW_PACKAGING and not coming_boxes:
			_order(supplier, bank, {"packaging": 1}, now)
		for printer in printers:
			var wear: PrinterWear = printer["wear"]
			for slot in wear.slots():
				var part := wear.fitted[slot]
				var coming := supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.parts.has(part))
				if wear.is_worn(slot) and int(s["spares"].get(part, 0)) == 0 and not coming:
					if _order(supplier, bank, {"parts": {part: 1}}, now):
						tally["parts_spend"] += supplier.price_of({"parts": {part: 1}})
		# Listings, printers and the move: nothing about the choice changes until there is the cash for the next thing.
		if not printers.is_empty() and bank.cash >= shop_again_at:
			shop_again_at = _shop(s, player, supplier, listed, bought, [printer_load, hands_load], now, start)
			printer_load = s["loads"][0]
			hands_load = s["loads"][1]

	var cancelled := 0
	var placed := 0
	for market: Marketplace in shops.values():
		placed += market.orders.size()
		cancelled += market.orders.filter(func(order: Marketplace.Order) -> bool: return order.status == Marketplace.Status.CANCELLED).size()
	var first: Marketplace = shops[StringName(_shops[0])]
	var worth := float(_worth(bank, bought))
	var worth_days: Array = tally["worth_days"]
	var printer_days: Array = tally["printer_days"]
	var result := {
		"second_printer_day": printer_days[0] if printer_days.size() > 0 else 0.0,
		"third_printer_day": printer_days[1] if printer_days.size() > 1 else 0.0,
		"fourth_printer_day": printer_days[2] if printer_days.size() > 2 else 0.0,
		"moved_day": tally["moved_day"],
		"worth": worth,
		"lately": 0.0,
		"gain_before": 0.0,
		"gain_after": 0.0,
		"printers": float(bought.size()),
		"sold": float(tally["sold"]),
		"busy": tally["busy_minutes"] / maxf(tally["printer_minutes"], 1.0),
		"ruined": float(tally["ruined"]) / maxf(tally["prints"], 1.0),
		"flawed": float(tally["flawed"]) / maxf(tally["prints"], 1.0),
		"refunded": float(tally["refunded"]) / maxf(tally["sold"], 1.0),
		"cancelled": float(cancelled) / maxf(placed, 1.0),
		"rating": first.rating(),
		"rating_multiplier": first.rating_multiplier(),
		"parts_spend": float(tally["parts_spend"]),
		"parts_fitted": float(tally["parts_fitted"]),
		"breakdowns": float(tally["breakdowns"]),
		"designs": float(owned.size()),
		"listings": float(listed.size()),
		"traded_up": float(tally["traded_up"]),
	}
	if worth_days.size() > LATELY_DAYS:
		result["lately"] = (float(worth_days[-1]) - float(worth_days[-1 - LATELY_DAYS])) / LATELY_DAYS
	if tally["moved_day"] > 0.0:
		# The cost of the move itself is left out of both: it is paid once, and the question is what a day earns.
		var cash_at_start := float(settings["start"]["cash_pence"])
		result["gain_before"] = (tally["worth_at_move"] + float(_unit["move_cost_pence"]) - cash_at_start) / tally["moved_day"]
		result["gain_after"] = (worth - tally["worth_at_move"]) / maxf(days - tally["moved_day"], 0.01)
	for shop_id in _shops:
		result["sold_on_" + shop_id] = float(tally["sold_on"].get(StringName(shop_id), 0))
		result["rating_" + shop_id] = shops[StringName(shop_id)].rating()
		result["rating_multiplier_" + shop_id] = shops[StringName(shop_id)].rating_multiplier()
	for material: String in _data.filaments:
		result["sold_in_" + material] = float(tally["sold_in"].get(material, 0))
	return result


## Cash and what the printers cost, in pence.
func _worth(bank: Bank, bought: Array[String]) -> int:
	var total := bank.cash
	for printer_id in bought:
		total += int(_data.printers[printer_id]["price_pence"])
	return total


## The marketplaces the business has reached.
func _open_shops(s: Dictionary) -> Array[Marketplace]:
	var open: Array[Marketplace] = []
	for market: Marketplace in s["shops"].values():
		if int(market.config["unlock_tier"]) <= int(s["tier"]):
			open.append(market)
	return open


## Orders waiting to be packed on every open marketplace, most urgent first.
func _waiting(s: Dictionary) -> Array[Marketplace.Order]:
	var open := _open_shops(s)
	if open.size() == 1:
		return open[0].open_orders()
	var found: Array[Marketplace.Order] = []
	for market in open:
		found.append_array(market.open_orders())
	found.sort_custom(func(a: Marketplace.Order, b: Marketplace.Order) -> bool: return a.due_at < b.due_at)
	return found


## The player looks at what to buy: listings while there is room for their orders,
## better listings in place of the worst once the character has no time for more,
## then a printer when the printers are what is full, then the move when the room
## is. `listed` is every listing that is up, by its key. Leaves the new loads in s["loads"] and returns the cash at which it is worth
## looking again.
func _shop(s: Dictionary, player: Dictionary, supplier: Supplier, listed: Dictionary, bought: Array[String],
		loads: Array, now: float, start: float) -> int:
	var bank: Bank = s["bank"]
	var owned: Array[StringName] = s["owned"]
	var tally: Dictionary = s["tally"]
	var printer_load: float = loads[0]
	var hands_load: float = loads[1]
	var room := 0.0
	for printer_id in bought:
		room += float(_data.printers[printer_id]["speed_multiplier"]) / float(_data.printers[_starter]["speed_multiplier"])
	room *= HOURS_IN_DAY * PRINTER_SHARE
	var printers_full := false
	var again_at := 1 << 60
	var selling: Dictionary = s["selling"]
	var worst := _worst(listed)
	for wish in _wishlist:
		if wish["tier"] > s["tier"] or listed.has(wish["key"]):
			continue
		if not bought.any(func(printer_id: String) -> bool: return _can_print(printer_id, wish["id"])):
			continue
		var drop := {}
		if hands_load + wish["hands_load"] > HOURS_IN_DAY * HANDS_SHARE:
			# No time for more orders, so only a listing that beats the worst one, in its place.
			if worst.is_empty() or wish["profit"] < worst["profit"] * TRADE_UP 					or hands_load - worst["hands_load"] + wish["hands_load"] > HOURS_IN_DAY * HANDS_SHARE:
				continue
			drop = worst
		if printer_load + wish["printer_load"] - float(drop.get("printer_load", 0.0)) > room:
			printers_full = true
			continue
		# The best listing that fits is worth waiting for. One for a design already owned is free.
		var fee: int = 0 if owned.has(wish["id"]) else wish["fee"]
		if bank.cash < fee + RESERVE:
			again_at = mini(again_at, fee + RESERVE)
			if drop.is_empty():
				break
			continue
		if fee > 0:
			bank.spend(fee, "Licence", now)
		if not owned.has(wish["id"]):
			owned.append(wish["id"])
		if not drop.is_empty():
			listed.erase(drop["key"])
			selling[drop["id"]] = int(selling[drop["id"]]) - 1
			(s["shops"][drop["shop"]] as Marketplace).set_listing(drop["id"], false, drop["listed"])
			printer_load -= drop["printer_load"]
			hands_load -= drop["hands_load"]
			tally["traded_up"] += 1
		listed[wish["key"]] = wish
		selling[wish["id"]] = int(selling.get(wish["id"], 0)) + 1
		(s["shops"][wish["shop"]] as Marketplace).set_listing(wish["id"], true, wish["listed"])
		printer_load += wish["printer_load"]
		hands_load += wish["hands_load"]
		if not drop.is_empty():
			worst = _worst(listed)
	s["loads"] = [printer_load, hands_load]
	if not printers_full:
		return again_at
	var day := (now - start) / GameClock.DAY
	if bought.size() < int(s["place"]["printer_spots"]):
		var printer_id: String = player.get("buys", _starter)
		var price := int(_data.printers[printer_id]["price_pence"]) + RESERVE
		if bank.cash < price:
			return mini(again_at, price)
		_order(supplier, bank, {"printers": {printer_id: 1}}, now)
		bought.append(printer_id)
		tally["printer_days"].append(day)
		return 0
	if player.get("moves", false) and int(s["tier"]) < UNIT_TIER:
		var price := int(_unit["move_cost_pence"]) + RESERVE
		if bank.cash < price:
			return mini(again_at, price)
		bank.spend(int(_unit["move_cost_pence"]), "Move", now)
		s["place"] = _unit
		s["tier"] = UNIT_TIER
		tally["moved_day"] = day
		tally["worth_at_move"] = float(_worth(bank, bought))
		return 0
	return again_at


## The listing that earns least a sale, or {} if nothing is listed.
func _worst(listed: Dictionary) -> Dictionary:
	var worst := {}
	for wish: Dictionary in listed.values():
		if worst.is_empty() or wish["profit"] < worst["profit"]:
			worst = wish
	return worst


## A print reaches its end, or the point it failed: wear, power and the result.
func _finish(printer: Dictionary, preset: Dictionary, bank: Bank, now: float, tally: Dictionary) -> void:
	var job: Dictionary = printer["job"]
	var wear: PrinterWear = printer["wear"]
	var spec: Dictionary = printer["spec"]
	var filament: Dictionary = _filament_of[job["product"]]
	var fate: Dictionary = job["fate"]
	var ruined: bool = not fate.is_empty() and fate["failure"]["outcome"] != "degraded"
	var share: float = fate["at"] if ruined else 1.0
	var hours: float = job["minutes"] * share / 60.0
	wear.apply(hours, preset, filament)
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
func _tend(s: Dictionary, printer: Dictionary, now: float) -> float:
	var spent := 0.0
	var preset: Dictionary = s["preset"]
	var stock: Dictionary = s["stock"]
	var spares: Dictionary = s["spares"]
	var tally: Dictionary = s["tally"]
	var spec: Dictionary = printer["spec"]
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
	var product := _choose(s, printer)
	if product == &"":
		printer["needs_hands_at"] = now + STEP
		return spent
	var row: Dictionary = _data.products[String(product)]
	var filament: Dictionary = _filament_of[product]
	var material: String = filament["id"]
	var grams := float(row["filament_grams"]) * float(preset["filament_multiplier"])
	if printer["material"] != material or printer["grams"] < grams:
		# _choose only offers a design there is a spool for. A part used spool of
		# another kind goes back on the rack; the end of one of the same kind is binned.
		if printer["material"] != material and printer["grams"] > 0.0:
			s["spools"][printer["material"]].append(printer["grams"])
		var rack: Array = s["spools"][material]
		rack.sort()
		printer["grams"] = rack.pop_back()
		printer["material"] = material
		spent += HANDLE_PRINT * 0.5
	var minutes := float(row["print_minutes"]) * float(preset["time_multiplier"]) / float(spec["speed_multiplier"]) \
		/ float(filament["speed_multiplier"])
	var flags := PrintRisk.conditions(spec, preset, row)
	flags.append_array(wear.flags())
	var chance := PrintRisk.fail_chance(spec, preset, filament, row, wear.extra_fail_chance())
	var fate := PrintRisk.roll(chance, _data.failures, flags, filament, s["rng"])
	var breakdown := wear.breaks_during(minutes / 60.0, preset, filament)
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


## What a printer should print next: whatever an order is waiting on, else one of
## each design to have ready while there is shelf for it, else nothing. Only
## designs it can print and has filament for, and staying on the spool that is
## loaded when there is nothing to choose between two.
func _choose(s: Dictionary, printer: Dictionary) -> StringName:
	var owned: Array[StringName] = s["owned"]
	var stock: Dictionary = s["stock"]
	var spare := {}
	var on_hand := 0
	for product in owned:
		spare[product] = (stock.get(product, []) as Array).size()
		on_hand += spare[product]
	# A print on another printer counts as made, unless it is known to be ruined.
	for other: Dictionary in s["printers"]:
		if not other["job"].is_empty() and other["waiting"] != "clear":
			spare[other["job"]["product"]] = int(spare.get(other["job"]["product"], 0)) + 1
			on_hand += 1
	for order in _waiting(s):
		spare[order.product] = int(spare.get(order.product, 0)) - 1
	var ahead := on_hand < int(s["place"]["shelf_slots"])
	var selling: Dictionary = s["selling"]
	var pick: StringName = &""
	for product in owned:
		# A design that has been taken down is only printed for the orders it still has.
		if spare[product] >= (1 if ahead and int(selling.get(product, 0)) > 0 else 0) or not _can_print(printer["id"], product):
			continue
		if not _has_spool(s, printer, product):
			continue
		if pick == &"" or spare[product] < spare[pick] \
				or (spare[product] == spare[pick] and _loaded(printer, product) and not _loaded(printer, pick)):
			pick = product
	return pick


func _loaded(printer: Dictionary, product: StringName) -> bool:
	return printer["material"] == _filament_of[product]["id"]


## True if there is filament to print a design on a printer: on it already, or a
## spool on the rack. Notes the filament as short when there isn't.
func _has_spool(s: Dictionary, printer: Dictionary, product: StringName) -> bool:
	var filament: Dictionary = _filament_of[product]
	var grams := float(_data.products[String(product)]["filament_grams"]) * float(s["preset"]["filament_multiplier"])
	if printer["material"] == filament["id"] and printer["grams"] >= grams:
		return true
	for spool: float in s["spools"].get(filament["id"], []):
		if spool >= grams:
			return true
	# A print bigger than a whole spool can't be made this way at all.
	if grams <= float(filament["spool_grams"]):
		s["short"][filament["id"]] = true
	return false


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
