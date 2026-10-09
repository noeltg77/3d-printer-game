extends SceneTree
## Headless checks for the simulation classes (no scenes needed).
## Run: godot --headless --path . --script res://scripts/dev/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_print_job()
	_test_print_risk()
	_test_clock()
	_test_bank()
	_test_money()
	_test_marketplace()
	_test_supplier()
	print("Tests passed" if _failures == 0 else "%d test(s) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAILED: ", what)


func _test_print_job() -> void:
	var job := PrintJob.new(10.0)
	_check(is_zero_approx(job.progress), "a new job starts at 0 progress")
	_check(not job.advance(4.0), "advancing part way does not finish the job")
	_check(is_equal_approx(job.progress, 0.4), "progress is elapsed over duration")
	_check(job.advance(6.0), "advance returns true on the step that finishes")
	_check(job.is_finished() and is_equal_approx(job.progress, 1.0), "a finished job is at full progress")
	_check(not job.advance(1.0), "a finished job does not finish twice")
	_check(is_equal_approx(job.progress, 1.0), "progress never goes past 1")
	_check(not job.ruined, "a job with no failure is not ruined")

	var scrapped := PrintJob.new(10.0)
	scrapped.fail({"id": "spaghetti", "outcome": "scrap"}, 0.4)
	_check(not scrapped.advance(3.0), "a doomed print runs normally until the failure strikes")
	_check(scrapped.advance(3.0) and scrapped.is_finished(), "a ruined print ends when the failure strikes")
	_check(scrapped.ruined and is_equal_approx(scrapped.progress, 0.4), "a ruined print stops at the point it failed")
	_check(not scrapped.advance(5.0) and is_equal_approx(scrapped.elapsed, 4.0), "a ruined print does not carry on")

	var spoiled := PrintJob.new(10.0)
	spoiled.fail({"id": "warping", "outcome": "degraded"}, 0.4)
	_check(not spoiled.advance(6.0), "a spoiled print keeps going past the point it went wrong")
	_check(spoiled.advance(4.0) and not spoiled.ruined and is_equal_approx(spoiled.progress, 1.0), "a spoiled print runs to the end")


func _test_print_risk() -> void:
	var data := GameData.load_all()
	var plodder: Dictionary = data.printers["plodder_mini"]
	var zippy: Dictionary = data.printers["zippy_x1"]
	var pla: Dictionary = data.filaments["pla"]
	var clips: Dictionary = data.products["cable_clips"]
	var dragon: Dictionary = data.products["flexi_dragon"]
	var draft: Dictionary = data.presets["draft"]
	var standard: Dictionary = data.presets["standard"]
	var strong: Dictionary = data.presets["strong"]

	var base := PrintRisk.fail_chance(plodder, standard, pla, clips)
	_check(base > 0.02 and base < 0.08, "a simple PLA print on the starter printer fails a few times in a hundred (got %.3f)" % base)
	_check(is_equal_approx(PrintRisk.fail_chance(plodder, draft, pla, clips), base * 1.5), "Draft is half as risky again as Standard")
	_check(PrintRisk.fail_chance(plodder, strong, pla, clips) < base, "Strong is a little safer than Standard")
	_check(PrintRisk.fail_chance(plodder, standard, pla, dragon) > base, "a harder design is riskier")
	_check(PrintRisk.fail_chance(plodder, standard, data.filaments["petg"], clips) > base, "a fussier filament is riskier")
	_check(PrintRisk.fail_chance(zippy, standard, pla, clips) < base * 0.5, "a more reliable printer clearly cuts the risk")
	_check(is_equal_approx(PrintRisk.fail_chance(plodder, standard, pla, clips, 0.1), base + 0.1), "extra risk is added on top")
	_check(is_equal_approx(PrintRisk.fail_chance(plodder, standard, pla, clips, 5.0), PrintRisk.MAX_CHANCE), "the chance is capped")
	_check(PrintRisk.band(0.03) == "Low" and PrintRisk.band(0.08) == "Medium" and PrintRisk.band(0.2) == "High", "risk bands")

	var flags := PrintRisk.conditions(plodder, draft, clips)
	_check(flags.has(&"draft_preset") and flags.has(&"no_auto_level"), "conditions note the preset and the missing bed levelling")
	_check(not PrintRisk.conditions(zippy, standard, clips).has(&"no_auto_level"), "a printer with bed levelling does not get that flag")
	_check(PrintRisk.conditions(plodder, standard, dragon).has(&"large_part"), "a part that nearly fills the bed is large")
	var tower := {"size_mm": [40, 40, 160]}
	var tall := PrintRisk.conditions(plodder, standard, tower)
	_check(tall.has(&"tall_thin_part") and tall.has(&"bedslinger_tall_part"), "a tower is tall and thin, and shaken by a bed slinger")
	_check(not PrintRisk.conditions(zippy, standard, tower).has(&"bedslinger_tall_part"), "a core XY does not shake tall parts")

	var first_layer: Dictionary = data.failures["first_layer"]
	_check(is_equal_approx(PrintRisk.weight_of(first_layer, [], pla), first_layer["weight"]), "with no causes a failure has its plain weight")
	_check(is_equal_approx(PrintRisk.weight_of(first_layer, flags, pla), float(first_layer["weight"]) * 2.0 * 1.2), "causes that apply multiply the weight")
	var stringing: Dictionary = data.failures["stringing"]
	_check(is_equal_approx(PrintRisk.weight_of(stringing, [], data.filaments["petg"]), float(stringing["weight"]) * 1.5), "a filament's own modifier multiplies the weight")

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_check(PrintRisk.roll(0.0, data.failures, flags, pla, rng).is_empty(), "a print with no risk never fails")
	var counts := {}
	for attempt in 4000:
		var fate := PrintRisk.roll(1.0, data.failures, [], pla, rng)
		var failure: Dictionary = fate["failure"]
		counts[failure["id"]] = counts.get(failure["id"], 0) + 1
		var span: Array = PrintRisk.WHEN[failure["happens"]]
		if fate["at"] < span[0] or fate["at"] > span[1]:
			_check(false, "%s struck at %.2f, outside when it happens" % [failure["id"], fate["at"]])
			break
	_check(counts.size() == data.failures.size(), "every failure can happen")
	_check(counts["first_layer"] > counts["tangled_spool"] * 2, "heavier failures happen more often")
	var failed := 0
	for attempt in 4000:
		failed += 0 if PrintRisk.roll(0.25, data.failures, [], pla, rng).is_empty() else 1
	_check(absi(failed - 1000) < 120, "prints fail about as often as their chance says (got %d of 4000)" % failed)


func _test_clock() -> void:
	var clock := GameClock.new()
	clock.minutes = 8 * 60.0
	_check(clock.label() == "Day 1, 08:00", "clock label at the start of day 1")
	clock.advance(600.0)
	_check(clock.day == 2 and clock.label() == "Day 2, 08:00", "600 real seconds is one game day")
	_check(clock.crossed(clock.minutes - 30.0, 7 * 60.0 + 45.0), "crossed() sees a time of day inside the span")
	_check(not clock.crossed(clock.minutes - 30.0, 9 * 60.0), "crossed() ignores a time of day still ahead")
	clock.minutes = 1440.0 + 10.0
	_check(clock.crossed(1430.0, 5.0), "crossed() works across midnight")
	_check(GameClock.duration_label(200.0) == "3h 20m", "duration label in hours and minutes")
	_check(GameClock.duration_label(1680.0) == "1d 4h", "duration label in days and hours")
	_check(is_equal_approx(GameClock.to_seconds(240.0), 100.0), "a 4 hour print lasts 100 real seconds")


func _test_bank() -> void:
	var bank := Bank.new(1000)
	_check(not bank.spend(1500, "too much", 0.0) and bank.cash == 1000, "spend refuses when short and takes nothing")
	_check(bank.spend(400, "spool", 10.0) and bank.cash == 600, "spend deducts when affordable")
	bank.charge(700, "fees", 20.0)
	_check(bank.cash == -100, "charge can take cash below zero")
	bank.earn(2500, "sale", 30.0)
	_check(bank.cash == 2400, "earn adds cash")
	var totals := bank.totals_since(15.0)
	_check(totals["income"] == 2500 and totals["expenses"] == 700, "totals only count entries since the given minute")


func _test_money() -> void:
	var chosen := Money.currency
	Money.set_currency("GBP")
	_check(Money.format(1250) == "£12.50", "GBP exact")
	_check(Money.format(-5) == "-£0.05", "GBP negative under a pound")
	_check(Money.format(-300) == "-£3.00", "GBP negative")
	_check(Money.format(123456) == "£1,234.56", "GBP over a thousand")
	_check(Money.format(123456789) == "£1,234,567.89", "GBP over a million")
	_check(Money.format(0) == "£0.00", "GBP zero")
	_check(Money.format(1599) == "£15.99", "a GBP price shows exactly as stored")

	Money.set_currency("USD")
	_check(Money.format(1000) == "$12.70", "USD exact uses the rate")
	_check(Money.format(-1000) == "-$12.70", "USD negative")
	_check(Money.format(100000) == "$1,270.00", "USD over a thousand")
	_check(Money.format(1599) == "$20.31", "a price converts exactly, with no rounding to a tidy ending")
	_check(Money.to_display(1599) + Money.to_display(-1599) == 0, "a price and the charge for it are the same amount")

	Money.set_currency("EUR")
	_check(Money.format(1000) == "11,70 €", "EUR puts the symbol after and uses a decimal comma")
	_check(Money.format(-1000) == "-11,70 €", "EUR negative")
	_check(Money.format(100000) == "1.170,00 €", "EUR over a thousand uses a dot separator")
	_check(Money.format(123456789) == "1.444.444,43 €", "EUR over a million")

	Money.set_currency("XXX")
	_check(Money.currency == "EUR", "an unknown currency code is ignored")
	_check(Money.currency_for_locale("en_GB") == "GBP", "en_GB starts in pounds")
	_check(Money.currency_for_locale("en_US") == "USD", "en_US starts in dollars")
	_check(Money.currency_for_locale("de_DE") == "EUR" and Money.currency_for_locale("fr_FR.UTF-8") == "EUR", "eurozone locales start in euros")
	_check(Money.currency_for_locale("ja_JP") == "GBP" and Money.currency_for_locale("en") == "GBP", "anything else starts in pounds")
	Money.set_currency(chosen)


func _test_marketplace() -> void:
	var data := GameData.load_all()
	var market := Marketplace.new(data.marketplaces["craftsy"], data.products)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_check(market.tick(0.0, 1440.0, rng).is_empty(), "nothing sells until it is listed")

	var typical: int = data.products["desk_organiser"]["base_price_pence"]
	market.set_listing(&"desk_organiser", true, typical)
	_check(is_equal_approx(market.demand_multiplier(&"desk_organiser", typical), 1.0), "demand is 1x at the typical price")
	_check(market.demand_multiplier(&"desk_organiser", typical * 2) < 0.25, "doubling the price cuts demand hard")
	_check(is_equal_approx(market.demand_multiplier(&"desk_organiser", 1), 2.0), "the demand boost from underpricing is capped")

	# Many small ticks over ten days should land near the expected order count
	# if nothing limits open orders.
	market.config = market.config.duplicate()
	market.config["max_open_orders"] = 1000
	for step in 14400:
		market.tick(step, step + 1.0, rng)
	var expected: float = data.products["desk_organiser"]["demand_per_day"] * 10.0
	_check(absf(market.orders.size() - expected) < expected * 0.5, "order rate is close to demand_per_day (got %d, expected about %d)" % [market.orders.size(), expected])

	var order := market.orders[0]
	_check(market.fee_for(1200) == 98, "fee is 6.5% plus 20 cents")
	market.mark_packed(order)
	_check(not market.open_orders().has(order) and market.active_orders().has(order), "a packed order is active but no longer open")
	var sale := market.ship(order)
	_check(sale["price"] == typical and sale["royalty"] == 0, "shipping an order reports its price")
	_check(market.listing(&"desk_organiser")["sold"] == 1, "shipping counts a sale on the listing")
	_check(market.royalty_for(&"flexi_dragon", 1500) == 150, "royalty designs take their cut")

	var late := market.orders[1]
	var cancelled := market.expire(late.due_at + 1.0)
	_check(cancelled.has(late) and late.status == Marketplace.Status.CANCELLED, "orders past their deadline are cancelled")
	_check(order.status == Marketplace.Status.SHIPPED, "shipped orders are not cancelled")


func _test_supplier() -> void:
	var data := GameData.load_all()
	var supplier := Supplier.new(data)
	var basket := {"printers": {"plodder_mini": 1}, "spools": {"red": 2, "white": 1}, "packaging": 1}
	_check(supplier.price_of(basket) == 15899 + 3 * 1599 + 499, "basket price adds printers, spools and packaging")
	var placed := supplier.place(basket, 100.0)
	_check(placed.size() == 2, "a printer ships separately from supplies")
	_check(supplier.collect_due(150.0).is_empty(), "nothing arrives before its lead time")
	var first := supplier.collect_due(100.0 + 120.0)
	_check(first.size() == 1 and first[0].spools.size() == 3 and first[0].packaging == 10, "supplies arrive first, with every spool and a full pack")
	var second := supplier.collect_due(100.0 + 180.0)
	_check(second.size() == 1 and second[0].printer == &"plodder_mini", "the printer arrives after its longer lead time")
	_check(supplier.pending.is_empty(), "collected deliveries are no longer pending")
