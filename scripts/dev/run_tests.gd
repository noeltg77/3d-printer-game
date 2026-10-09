extends SceneTree
## Headless checks for the simulation classes (no scenes needed).
## Run: godot --headless --path . --script res://scripts/dev/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_print_job()
	_test_print_risk()
	_test_printer_wear()
	_test_printer_mods()
	_test_filaments()
	_test_moisture()
	_test_design_studio()
	_test_markets_and_trends()
	_test_clock()
	_test_bank()
	_test_money()
	_test_marketplace()
	_test_deliveries()
	_test_supplier()
	_test_saving()
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
	var clips: Dictionary = data.products["cable_management_clips_x12"]
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
	var rollable := data.failures.values().filter(func(row: Dictionary) -> bool: return float(row["weight"]) > 0.0).size()
	_check(counts.size() == rollable and not counts.has("breakdown"), "every failure with a weight can happen, and only those")
	_check(counts["first_layer"] > counts["tangled_spool"] * 2, "heavier failures happen more often")
	var failed := 0
	for attempt in 4000:
		failed += 0 if PrintRisk.roll(0.25, data.failures, [], pla, rng).is_empty() else 1
	_check(absi(failed - 1000) < 120, "prints fail about as often as their chance says (got %d of 4000)" % failed)


func _test_printer_wear() -> void:
	var data := GameData.load_all()
	var plodder: Dictionary = data.printers["plodder_mini"]
	var pla: Dictionary = data.filaments["pla"]
	var standard: Dictionary = data.presets["standard"]
	var wear := PrinterWear.new(data.parts, plodder, 1.0)
	_check(wear.slots().size() == plodder["parts"].size() and wear.slots().has(&"nozzle"), "a new printer has a part in every slot it ships with")
	_check(is_equal_approx(wear.health[&"nozzle"], 1.0) and is_zero_approx(wear.extra_fail_chance()), "new parts are at full health and add no risk")
	_check(wear.flags().is_empty() and wear.broken().is_empty(), "new parts are neither worn nor broken")

	var life := float(data.parts["brass_nozzle_0_4mm"]["lifespan_print_hours"]) / float(plodder["wear_multiplier"])
	wear.apply(life * 0.5, standard, pla)
	_check(is_equal_approx(wear.health[&"nozzle"], 0.5), "half a part's life in print hours takes half its health")
	_check(wear.health[&"belts"] > wear.health[&"nozzle"], "longer lived parts wear more slowly")
	_check(is_zero_approx(wear.extra_fail_chance()), "a part above 30% adds no risk")
	_check(wear.worst() == &"nozzle", "the nozzle is the first part to go")

	wear.apply(life * 0.35, standard, pla)
	_check(wear.is_worn(&"nozzle") and wear.flags().has(&"worn_nozzle"), "below 30% a part is worn and raises its flag")
	var half_way := float(data.parts["brass_nozzle_0_4mm"]["max_extra_fail"]) * 0.5
	_check(is_equal_approx(wear.extra_fail_chance(), half_way), "at 15% health a part adds half its extra risk")
	var base := PrintRisk.fail_chance(plodder, standard, pla, data.products["cable_management_clips_x12"])
	_check(PrintRisk.fail_chance(plodder, standard, pla, data.products["cable_management_clips_x12"], wear.extra_fail_chance()) > base * 1.5, "a worn nozzle clearly raises the chance of failure")
	var clog: Dictionary = data.failures["clog"]
	_check(PrintRisk.weight_of(clog, wear.flags(), pla) > float(clog["weight"]) * 2.0, "a worn nozzle makes clogs the likely failure")

	var breaks := wear.breaks_during(life * 0.3, standard, pla)
	_check(breaks.get("slot") == &"nozzle" and is_equal_approx(breaks["at"], 0.5), "a print longer than the part has left breaks it part way")
	_check(wear.breaks_during(life * 0.1, standard, pla).is_empty(), "a print the part can survive breaks nothing")
	wear.apply(life * 0.3 * breaks["at"], standard, pla)
	_check(wear.is_broken(&"nozzle") and wear.broken() == ([&"nozzle"] as Array[StringName]), "running a part to nothing breaks it")

	wear.replace(&"nozzle", &"brass_nozzle_0_4mm")
	_check(is_equal_approx(wear.health[&"nozzle"], 1.0) and wear.broken().is_empty(), "fitting a spare restores the slot")
	wear.damage(&"nozzle", 0.2)
	_check(is_equal_approx(wear.health[&"nozzle"], 0.8), "a failure can take health straight off a part")
	wear.damage(&"nozzle", 5.0)
	_check(is_zero_approx(wear.health[&"nozzle"]), "health never goes below nothing")

	var fast := PrinterWear.new(data.parts, plodder, 4.0)
	fast.apply(life * 0.125, standard, pla)
	_check(is_equal_approx(fast.health[&"nozzle"], 0.5), "the game's wear rate scales all wear")
	var draft_wear := PrinterWear.new(data.parts, plodder, 1.0)
	draft_wear.apply(10.0, data.presets["draft"], pla)
	var strong_wear := PrinterWear.new(data.parts, plodder, 1.0)
	strong_wear.apply(10.0, data.presets["strong"], pla)
	_check(draft_wear.health[&"nozzle"] < strong_wear.health[&"nozzle"], "Draft wears parts faster than Strong, hour for hour")
	var gritty := pla.duplicate()
	gritty["abrasive"] = true
	_check(is_equal_approx(wear.wear_per_hour(&"nozzle", standard, gritty), wear.wear_per_hour(&"nozzle", standard, pla) * 10.0), "abrasive filament eats a brass nozzle ten times faster")
	_check(is_equal_approx(wear.wear_per_hour(&"belts", standard, gritty), wear.wear_per_hour(&"belts", standard, pla)), "abrasive filament does not wear the belts any faster")


func _test_printer_mods() -> void:
	var data := GameData.load_all()
	var plodder: Dictionary = data.printers["plodder_mini"]
	var zippy: Dictionary = data.printers["zippy_x1"]
	var pla: Dictionary = data.filaments["pla"]
	var mods := PrinterMods.new(data.upgrades)
	_check(mods.failure_multipliers().is_empty() and is_equal_approx(mods.time_multiplier(), 1.0) and is_equal_approx(mods.wear_multiplier(), 1.0), "a printer with no upgrades is unchanged")
	_check(mods.problem(&"auto_bed_levelling_kit", plodder) == "", "bed levelling fits the starter printer")
	_check(mods.problem(&"auto_bed_levelling_kit", zippy) != "", "but not a printer of the wrong kind, or one that has it already")
	_check(mods.problem(&"anti_vibration_feet", zippy) == "", "an upgrade that fits anything fits a core XY")

	var flags := PrintRisk.conditions(plodder, data.presets["standard"], data.products["cable_management_clips_x12"])
	var before := PrintRisk.fail_chance(plodder, data.presets["standard"], pla, data.products["cable_management_clips_x12"])
	mods.fit(&"auto_bed_levelling_kit")
	_check(mods.has(&"auto_bed_levelling_kit") and mods.problem(&"auto_bed_levelling_kit", plodder) != "", "an upgrade can only be fitted once")
	var improved := mods.apply(plodder)
	_check(improved["auto_bed_levelling"] and not plodder["auto_bed_levelling"], "bed levelling gives the printer the capability without touching its data row")
	var levelled := PrintRisk.conditions(improved, data.presets["standard"], data.products["cable_management_clips_x12"])
	_check(flags.has(&"no_auto_level") and not levelled.has(&"no_auto_level"), "so the missing bed levelling flag goes")
	var scale := PrintRisk.upgrade_scale(data.failures, levelled, pla, mods.failure_multipliers())
	_check(scale < 0.92 and scale > 0.6, "bed levelling clearly cuts the chance of a failure (to %.2f of what it was)" % scale)
	_check(before * scale < before, "and the print is less likely to fail")
	var first_layer: Dictionary = data.failures["first_layer"]
	_check(is_equal_approx(PrintRisk.weight_of(first_layer, levelled, pla, mods.failure_multipliers()), float(first_layer["weight"]) * 0.4), "first layer failures become much rarer")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var plain := 0
	var upgraded := 0
	for attempt in 3000:
		plain += 1 if PrintRisk.pick(data.failures, flags, pla, rng)["id"] == "first_layer" else 0
		upgraded += 1 if PrintRisk.pick(data.failures, levelled, pla, rng, mods.failure_multipliers())["id"] == "first_layer" else 0
	_check(upgraded * 3 < plain, "and are picked far less often (%d against %d)" % [upgraded, plain])
	_check(is_equal_approx(PrintRisk.upgrade_scale(data.failures, flags, pla, {}), 1.0), "no upgrades means no change to the chance")

	mods.fit(&"frame_stiffening_braces")
	mods.fit(&"cable_chain_kit")
	_check(is_equal_approx(mods.time_multiplier(), 0.95) and is_equal_approx(mods.wear_multiplier(), 0.9), "braces speed prints up and a cable chain slows wear")
	_check(is_equal_approx(float(mods.failure_multipliers()["layer_shift"]), 0.8), "upgrades' effects on failures combine")
	var wear := PrinterWear.new(data.parts, plodder, 1.0)
	var plain_wear := wear.wear_per_hour(&"nozzle", data.presets["standard"], pla)
	wear.upgrade_multiplier = mods.wear_multiplier()
	_check(is_equal_approx(wear.wear_per_hour(&"nozzle", data.presets["standard"], pla), plain_wear * 0.9), "slower wear reaches every part")

	var saved := _through_file(mods.save())
	saved["fitted"].append("gone_upgrade")
	var again := PrinterMods.new(data.upgrades)
	again.restore(saved)
	_check(again.fitted == mods.fitted, "upgrades come back from a save, without any the game no longer has")


func _test_filaments() -> void:
	var data := GameData.load_all()
	var plodder: Dictionary = data.printers["plodder_mini"]
	var zippy: Dictionary = data.printers["zippy_x1"]
	var clips: Dictionary = data.products["cable_management_clips_x12"]
	var standard: Dictionary = data.presets["standard"]
	_check(FilamentRules.problem(plodder, data.filaments["pla"]) == "", "the starter printer prints PLA")
	_check(FilamentRules.problem(plodder, data.filaments["petg"]) == "", "and is just hot enough for PETG")
	_check(FilamentRules.problem(plodder, data.filaments["abs"]) != "", "but not hot enough for ABS")
	_check(FilamentRules.problem(plodder, data.filaments["tpu"]) != "", "and can't feed TPU without direct drive")
	_check(FilamentRules.problem(zippy, data.filaments["asa"]) == "" and FilamentRules.problem(zippy, data.filaments["tpu"]) == "", "an enclosed direct drive printer handles ASA and TPU")
	var mods := PrinterMods.new(data.upgrades)
	mods.fit(&"direct_drive_conversion")
	_check(FilamentRules.problem(mods.apply(plodder), data.filaments["tpu"]) == "", "a direct drive conversion lets the starter printer print TPU")
	var hot_open := plodder.duplicate()
	hot_open["max_nozzle_temp_c"] = 280
	_check(FilamentRules.problem(hot_open, data.filaments["abs"]).contains("enclosed"), "ABS on an open printer is refused for want of an enclosure")
	var tent := PrinterMods.new(data.upgrades)
	tent.fit(&"snap_on_enclosure")
	_check(FilamentRules.problem(tent.apply(hot_open), data.filaments["abs"]) == "", "a snap-on enclosure lets it print ABS")

	_check(FilamentRules.suits(clips, data.filaments["pla"]) and FilamentRules.suits(clips, data.filaments["pla_silk"]), "a PLA design prints in any filament of the PLA family")
	var tough := {"allowed_filaments": ["pla", "petg"]}
	_check(FilamentRules.suits(tough, data.filaments["petg"]) and not FilamentRules.suits(tough, data.filaments["tpu"]), "and in the other filaments it names, but no others")
	_check(FilamentRules.suits(data.products["flexi_dragon"], data.filaments["pla_glow"]) and not FilamentRules.suits(data.products["flexi_dragon"], data.filaments["petg"]), "a PLA-only design takes the fancy PLAs but not PETG")
	_check(FilamentRules.has_a_use(data.products, data.filaments["pla_wood"]) and not FilamentRules.has_a_use(data.products, data.filaments["asa"]), "a filament no design can use is spotted")

	_check(FilamentRules.spool_key("pla_silk", "pink") == "pla_silk:pink", "a spool key names material and colour")
	_check(FilamentRules.material_of("pla_silk:pink") == "pla_silk" and FilamentRules.colour_of("pla_silk:pink") == "pink", "and can be taken apart again")
	_check(FilamentRules.material_of("red") == "pla" and FilamentRules.colour_of("red") == "red", "a bare colour is a PLA spool")

	var supplier := Supplier.new(data)
	_check(supplier.spool_price("pla") == 1599 and supplier.spool_price("pla_cf") == 3399, "each filament has its own spool price")
	_check(supplier.price_of({"spools": {"red": 1, "pla_cf:ink": 2, "petg:teal": 1}}) == 1599 + 2 * 3399 + 1899, "a mixed basket adds each spool at its own price")
	var box := supplier.place({"spools": {"pla_cf:ink": 2, "red": 1}}, 0.0)[0]
	_check(box.spools.size() == 3 and box.spools.has(&"pla_cf:ink") and box.describe() == "3 spools", "a delivery carries each spool's key")
	_check(Supplier.Delivery.restored(_through_file(box.save())).spools == box.spools, "and keeps them through a save")

	var brass: Dictionary = data.parts["brass_nozzle_0_4mm"]
	var hardened: Dictionary = data.parts["hardened_steel_nozzle_0_4mm"]
	_check(FilamentRules.wears_nozzle(data.filaments["pla_glow"], brass), "glow filament chews a brass nozzle")
	_check(not FilamentRules.wears_nozzle(data.filaments["pla_glow"], hardened) and not FilamentRules.wears_nozzle(data.filaments["pla"], brass), "but not a hardened one, and plain PLA chews nothing")
	var wear := PrinterWear.new(data.parts, plodder, 1.0)
	var on_brass := wear.wear_per_hour(&"nozzle", standard, data.filaments["pla_cf"])
	wear.replace(&"nozzle", &"hardened_steel_nozzle_0_4mm")
	var on_hardened := wear.wear_per_hour(&"nozzle", standard, data.filaments["pla_cf"])
	_check(on_brass > on_hardened * 50.0, "carbon filament wears brass far faster than hardened steel")
	_check(is_equal_approx(on_hardened, wear.wear_per_hour(&"nozzle", standard, data.filaments["pla"])), "a hardened nozzle wears the same whatever is printed")

	_check(PrintRisk.fail_chance(plodder, standard, data.filaments["pla_cf"], clips) > PrintRisk.fail_chance(plodder, standard, data.filaments["pla"], clips) * 2.5, "fussier filaments fail more often")
	var stringing: Dictionary = data.failures["stringing"]
	_check(PrintRisk.weight_of(stringing, [], data.filaments["tpu"]) > PrintRisk.weight_of(stringing, [], data.filaments["pla"]), "stringy filaments string more")

	var market := Marketplace.new(data.marketplaces["craftsy"].duplicate(), data.products)
	market.config["max_open_orders"] = 1000
	market.set_listing(&"cable_management_clips_x12", true, 400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for step in 2000:
		market.tick(step, step + 1.0, rng)
	var plain := market.orders[0]
	var fancy := market.orders[1]
	market.mark_packed(plain, 3, 3, false)
	market.mark_packed(fancy, 3, 3, false, float(data.filaments["pla_cf"]["value_multiplier"]))
	_check(plain.price == 400 and fancy.price == 560, "a print in a premium filament sells for more than the listed price")
	_check(market.ship(fancy)["fee"] == market.fee_for(560), "and the marketplace takes its cut of the higher price")


func _test_moisture() -> void:
	var data := GameData.load_all()
	var rules: Dictionary = data.settings["moisture"]
	var pla: Dictionary = data.filaments["pla"]
	var tpu: Dictionary = data.filaments["tpu"]
	var petg: Dictionary = data.filaments["petg"]
	_check(is_equal_approx(Moisture.gain_per_day(pla, rules), 0.08), "PLA in the open gains 8% moisture a day")
	_check(Moisture.gain_per_day(tpu, rules) > Moisture.gain_per_day(pla, rules) * 1.9, "thirstier filaments soak it up faster")
	_check(is_equal_approx(Moisture.after(0.1, GameClock.DAY * 2.0, pla, rules), 0.26), "moisture builds up with time in the open")
	_check(is_equal_approx(Moisture.after(0.95, GameClock.DAY * 30.0, pla, rules), 1.0), "and stops at soaked")
	_check(Moisture.label(0.1, rules) == "dry" and Moisture.label(0.25, rules) == "damp" and Moisture.label(0.4, rules) == "wet", "a spool goes from dry to damp to wet")
	_check(not Moisture.is_wet(0.39, rules) and Moisture.is_wet(0.4, rules), "wet starts at the threshold")
	_check(is_zero_approx(Moisture.extra_fail_chance(0.4, rules)), "a spool that is only just wet adds no risk yet")
	_check(is_equal_approx(Moisture.extra_fail_chance(0.6, rules), 0.03) and is_equal_approx(Moisture.extra_fail_chance(1.0, rules), 0.09), "each further 20% of moisture adds 3% to the chance of failure")
	var plodder: Dictionary = data.printers["plodder_mini"]
	var clips: Dictionary = data.products["cable_management_clips_x12"]
	var dry_chance := PrintRisk.fail_chance(plodder, data.presets["standard"], pla, clips)
	_check(PrintRisk.fail_chance(plodder, data.presets["standard"], pla, clips, Moisture.extra_fail_chance(1.0, rules)) > dry_chance * 2.5, "a soaked spool makes failure far more likely")
	var stringing: Dictionary = data.failures["stringing"]
	_check(is_equal_approx(PrintRisk.weight_of(stringing, [&"wet_filament"], pla), float(stringing["weight"]) * 2.5), "and stringing the likely result")

	var mini: Dictionary = data.dryers["dryhive_mini_dryer_s1"]
	var duo: Dictionary = data.dryers["dryhive_duo_dryer_s2"]
	_check(Moisture.can_dry(mini, pla) and Moisture.can_dry(mini, data.filaments["pla_silk"]) and not Moisture.can_dry(mini, petg), "the small dryer handles the PLA family but not PETG")
	_check(Moisture.can_dry(duo, petg) and Moisture.can_dry(duo, data.filaments["asa"]), "the bigger one handles the fussier filaments")
	_check(is_equal_approx(Moisture.hours_to_dry(0.5, mini, pla), 3.0), "a half soaked PLA spool dries in half the dryer's time")
	_check(is_equal_approx(Moisture.hours_to_dry(0.5, duo, petg), 0.5 * 5.0 * 1.5), "PETG takes half as long again")
	_check(is_equal_approx(Moisture.dried(0.5, 90.0, mini, pla), 0.25), "moisture falls steadily in the dryer")
	_check(is_zero_approx(Moisture.dried(0.5, 600.0, mini, pla)), "and stops at dry")

	var supplier := Supplier.new(data)
	_check(supplier.price_of({"dryers": {"dryhive_mini_dryer_s1": 1}}) == 3899, "a dryer has its shop price")
	var boxes := supplier.place({"dryers": {"dryhive_mini_dryer_s1": 1}, "spools": {"red": 1}}, 0.0)
	_check(boxes.size() == 2 and boxes[1].dryer == &"dryhive_mini_dryer_s1" and boxes[1].describe() == "Filament dryer", "a dryer comes in a box of its own")
	_check(Supplier.Delivery.restored(_through_file(boxes[1].save())).dryer == &"dryhive_mini_dryer_s1", "and survives a save while on its way")


func _test_design_studio() -> void:
	var data := GameData.load_all()
	var rules: Dictionary = data.settings["design"].duplicate()
	var studio := DesignStudio.new(data.products, rules)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var clips := &"cable_management_clips_x12"
	var dragon := &"flexi_dragon"
	_check(not studio.has(clips) and studio.version(clips) == 0 and is_equal_approx(studio.appeal(clips), 1.0), "a design not yet made is no different from the bought one")
	_check(studio.minutes_for(dragon) > studio.minutes_for(clips), "harder items take longer to design")
	_check(studio.next_quality(clips) == int(rules["base_quality"]), "a beginner's first version is of basic quality")

	rules["fault_chance"] = 0.0
	var first := studio.complete(clips, rng)
	_check(first["version"] == 1 and first["quality"] == 2 and not first["faulty"] and not first["tested"], "finishing a design gives an untested V1")
	_check(studio.appeal(clips) < 1.0, "a basic own design sells a little worse than the bought one")
	_check(studio.minutes_for(clips) < float(rules["base_minutes"]), "an iteration is quicker than starting from nothing")
	_check(studio.printed(clips) == "sound" and studio.designs[clips]["tested"], "the first print of a sound design proves it")
	_check(studio.printed(clips) == "", "later prints have nothing new to say")
	studio.complete(clips, rng)
	studio.complete(clips, rng)
	_check(studio.version(clips) == 3 and studio.designs[clips]["quality"] == 4 and not studio.can_improve(clips), "each iteration adds a point of quality, up to V3")
	_check(studio.appeal(clips) > 1.0, "a well worked own design outsells the bought one")
	_check(studio.skill() == 1 and studio.next_quality(dragon) == 3, "three finished designs make the next one start better")
	_check(studio.fault_chance() < 0.3, "and skill makes hidden faults rarer")

	rules["fault_chance"] = 1.0
	studio.complete(dragon, rng)
	_check(studio.is_faulty(dragon) and not studio.needs_fix(dragon), "a fault stays hidden until something is printed")
	_check(studio.printed(dragon) == "fault" and studio.needs_fix(dragon), "the first print shows it up")
	_check(studio.printed(dragon) == "" and studio.is_faulty(dragon), "and every print is flawed until it is fixed")
	studio.fix(dragon)
	_check(not studio.is_faulty(dragon) and not studio.needs_fix(dragon) and studio.designs[dragon]["tested"], "fixing it leaves a sound, tested design")

	var saved := _through_file(studio.save())
	saved["designs"]["gone_design"] = {"version": 1, "quality": 2, "faulty": false, "fault_known": false, "tested": true}
	var again := DesignStudio.new(data.products, rules)
	again.restore(saved)
	_check(again.designs.size() == 2 and again.version(clips) == 3 and again.completed == studio.completed, "own designs and skill come back from a save")

	var market := Marketplace.new(data.marketplaces["craftsy"], data.products)
	var bought := market.orders_per_day(dragon, 1500)
	_check(market.royalty_for(dragon, 1500) == 150, "a bought royalty design takes its cut")
	market.own_appeal[dragon] = 1.2
	_check(market.royalty_for(dragon, 1500) == 0, "an own design owes no royalty")
	_check(is_equal_approx(market.orders_per_day(dragon, 1500), bought * 1.2), "and its appeal scales the orders it brings")


func _test_markets_and_trends() -> void:
	var data := GameData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var craftsy := Marketplace.new(data.marketplaces["craftsy"], data.products)
	var biddle := Marketplace.new(data.marketplaces["biddle"], data.products)
	var stand := &"phone_stand"
	var usual := int(data.products[stand]["base_price_pence"])
	_check(craftsy.typical_price(stand) == usual and biddle.typical_price(stand) < usual, "bargain hunters expect to pay less than the usual price")
	_check(biddle.listing(stand)["price"] == biddle.typical_price(stand), "a new listing starts at what that marketplace's buyers expect")
	_check(biddle.orders_per_day(stand, biddle.typical_price(stand)) > craftsy.orders_per_day(stand, usual) * 1.3, "a bigger audience brings more orders at the expected price")
	_check(biddle.orders_per_day(stand, usual) < craftsy.orders_per_day(stand, usual), "but the usual price is too dear for them")
	_check(biddle.fee_for(1000) > craftsy.fee_for(1000), "and it takes a bigger cut")
	biddle.set_listing(stand, true, biddle.typical_price(stand))
	biddle.config = biddle.config.duplicate()
	biddle.config["max_open_orders"] = 1000
	for step in 3000:
		biddle.tick(step, step + 1.0, rng)
	var order := biddle.orders[0]
	_check(order.market == &"biddle" and biddle.order_label(order) == "#BD-1001", "an order knows which marketplace it came from")
	var again := Marketplace.new(biddle.config, data.products)
	again.restore(_through_file(biddle.save()))
	_check(again.orders[0].market == &"biddle", "and still does after a save")

	var trends := Trends.new(data.products, data.settings["trends"])
	_check(trends.multipliers().is_empty() and is_equal_approx(trends.multiplier("kitchen"), 1.0), "before anything trends, demand is normal")
	_check(trends.candidates().has("kitchen") and not trends.candidates().has("easter"), "only categories with a few designs can trend")
	_check(not trends.candidates().has("christmas") and not trends.candidates().has("halloween"), "and seasonal ones are left out")
	_check(trends.tick(0.0, rng) and trends.hot != "" and trends.cool != "" and trends.hot != trends.cool, "the first tick picks something in demand and something gone quiet")
	_check(trends.multiplier(trends.hot) > 1.0 and trends.multiplier(trends.cool) < 1.0, "which sell faster and slower")
	_check(trends.until >= 3.0 * GameClock.DAY and trends.until <= 5.0 * GameClock.DAY, "for a few days")
	_check(not trends.tick(trends.until - 1.0, rng), "nothing changes until the time is up")
	var was_hot := trends.hot
	var was_cool := trends.cool
	_check(trends.tick(trends.until, rng) and trends.hot != was_hot and trends.cool != was_cool and trends.hot != was_cool, "then fashion moves on to something new")
	var hot_product: StringName = &""
	for product: String in data.products:
		if data.products[product]["category"] == trends.hot:
			hot_product = StringName(product)
			break
	var price := craftsy.typical_price(hot_product)
	var normal := craftsy.orders_per_day(hot_product, price)
	craftsy.trend = trends.multipliers()
	_check(is_equal_approx(craftsy.orders_per_day(hot_product, price), normal * float(data.settings["trends"]["hot_multiplier"])), "a design in a trending category brings more orders")
	var later := Trends.new(data.products, data.settings["trends"])
	later.restore(_through_file(trends.save()))
	_check(later.hot == trends.hot and later.cool == trends.cool and is_equal_approx(later.until, trends.until), "trends come back from a save")
	_check(trends.category_name("home_organisation") == "Home organisation", "a category has a name for the player")


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


func _test_deliveries() -> void:
	var data := GameData.load_all()
	var courier: Dictionary = data.settings["courier"]
	_check(is_equal_approx(Marketplace.damage_chance(3, courier), 0.04), "a Standard print breaks in the post 4 times in 100")
	_check(is_equal_approx(Marketplace.damage_chance(2, courier), 0.06), "a Draft print breaks more often")
	_check(is_zero_approx(Marketplace.damage_chance(5, courier)), "a Strong print never breaks in the post")
	var rough := {"protection": 1, "damage_multiplier": 1.8}
	_check(is_equal_approx(Marketplace.damage_chance(3, rough), 0.04 * (5.0 / 3.0) * 1.8), "poor packaging and a rough courier both add to the damage")

	var market := Marketplace.new(data.marketplaces["craftsy"].duplicate(), data.products)
	market.comments = data.review_comments
	market.config["max_open_orders"] = 100000
	market.config["review_chance"] = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_check(is_zero_approx(market.rating()) and is_equal_approx(market.rating_multiplier(), 1.0), "a shop with no reviews has no rating and normal demand")
	_check(is_zero_approx(market.return_chance(3, false)), "nobody sends back a good print")
	_check(market.return_chance(1, false) > 0.0 and market.return_chance(3, true) > market.return_chance(1, false), "rough prints come back sometimes, flawed ones often")

	var total_good := 0
	var total_flawed := 0
	for attempt in 300:
		total_good += Marketplace.stars_for(3, false, rng)
		total_flawed += Marketplace.stars_for(2, true, rng)
	_check(total_good / 300.0 > 4.4, "good prints average well over four stars (got %.2f)" % (total_good / 300.0))
	_check(total_flawed / 300.0 < 3.6, "flawed prints average clearly lower (got %.2f)" % (total_flawed / 300.0))

	market.set_listing(&"desk_organiser", true, 1200)
	for step in 3000:
		market.tick(step, step + 1.0, rng)
	var sent := market.orders.duplicate()
	_check(sent.size() >= 4, "enough orders arrived to test with")

	# A strong, good print: always arrives, is kept and is reviewed.
	var good: Marketplace.Order = sent[0]
	market.mark_packed(good, 5, 3, false)
	market.ship(good, 100.0, 500.0)
	_check(market.deliver(499.0, rng, courier).is_empty(), "nothing is delivered before it arrives")
	var arrived := market.deliver(500.0, rng, courier)
	_check(arrived.size() == 1 and arrived[0]["order"] == good, "a parcel is delivered when its time comes")
	_check(arrived[0]["refund"].is_empty() and good.status == Marketplace.Status.DELIVERED, "a strong, good print is delivered and kept")
	_check(arrived[0]["review"]["stars"] >= 4 and arrived[0]["review"]["text"] != "", "and earns a good review with something to say")
	_check(market.deliver(9999.0, rng, courier).is_empty(), "an order is only delivered once")
	_check(market.sold_orders().has(good), "a delivered order still counts as sold")

	# Packaging that can't protect anything: the parcel always arrives broken.
	var doomed: Marketplace.Order = sent[1]
	market.mark_packed(doomed, 1, 3, false)
	market.ship(doomed, 100.0, 200.0)
	var sold_before: int = market.listing(&"desk_organiser")["sold"]
	var broken := market.deliver(200.0, rng, {"protection": 1, "damage_multiplier": 100.0})
	_check(doomed.status == Marketplace.Status.REFUNDED and doomed.refund_reason == "damaged", "a parcel that breaks is refunded")
	_check(broken[0]["refund"]["price"] == doomed.price and broken[0]["refund"]["fee"] == market.fee_for(doomed.price), "the refund gives back the price, and the fee comes back to the seller")
	_check(broken[0]["review"]["stars"] == 1, "a broken parcel earns a one star review")
	_check(market.listing(&"desk_organiser")["sold"] == sold_before - 1, "a refunded order no longer counts as sold on the listing")

	# A flawed print that is certain to be sent back.
	market.config["return_chance_flawed"] = 1.0
	var flawed: Marketplace.Order = sent[2]
	market.mark_packed(flawed, 5, 2, true)
	market.ship(flawed, 100.0, 300.0)
	var back := market.deliver(300.0, rng, courier)
	_check(flawed.refund_reason == "returned" and back[0]["review"]["stars"] == 2, "a returned print is refunded and earns two stars")

	_check(is_equal_approx(market.rating(), (float(arrived[0]["review"]["stars"]) + 1.0 + 2.0) / 3.0), "the rating is the average of the reviews")
	_check(market.rating_multiplier() < 0.7, "a poor rating cuts demand")
	var few := market.rating_multiplier()
	market.config["rating_confidence_reviews"] = 30
	_check(market.rating_multiplier() > few and market.rating_multiplier() < 1.0, "the first few reviews count for less")
	market.config["rating_confidence_reviews"] = 5
	var poor := market.orders_per_day(&"desk_organiser", 1200)
	for count in 20:
		market.reviews.append({"stars": 5})
	_check(is_equal_approx(market.rating(), 5.0), "only the most recent reviews count towards the rating")
	_check(market.rating_multiplier() > 1.0 and market.orders_per_day(&"desk_organiser", 1200) > poor * 1.5, "a great rating brings the orders back, and a few more")
	_check(market.rating_multiplier() <= float(market.config["max_rating_multiplier"]), "the boost from a great rating is capped")


## What a save file does to state: written as JSON text and read back.
func _through_file(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func _test_saving() -> void:
	var data := GameData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3

	var clock := GameClock.new()
	clock.minutes = 3456.5
	var clock_again := GameClock.new()
	clock_again.restore(_through_file(clock.save()))
	_check(is_equal_approx(clock_again.minutes, 3456.5) and clock_again.label() == clock.label(), "the clock comes back at the same time")

	var bank := Bank.new(30000)
	bank.spend(1599, "Spoolhouse order", 10.0)
	bank.earn(449, "Sale", 20.0)
	var bank_again := Bank.new()
	bank_again.restore(_through_file(bank.save()))
	_check(bank_again.cash == bank.cash and bank_again.entries == bank.entries, "the bank comes back with its cash and every entry")
	_check(typeof(bank_again.cash) == TYPE_INT and typeof(bank_again.entries[0]["amount"]) == TYPE_INT, "money is still whole pence after loading")

	var market := Marketplace.new(data.marketplaces["craftsy"].duplicate(), data.products)
	market.comments = data.review_comments
	market.config["review_chance"] = 1.0
	market.set_listing(&"cable_management_clips_x12", true, 399)
	for step in 2000:
		market.tick(step, step + 1.0, rng)
	var first := market.orders[0]
	var second := market.orders[1]
	market.mark_packed(first, 5, 3, false)
	market.ship(first, 100.0, 200.0)
	market.deliver(200.0, rng, data.settings["courier"])
	market.mark_packed(second, 2, 1, true)
	market.ship(second, 100.0, 9000.0)
	var saved_market := _through_file(market.save())
	saved_market["listings"]["gone_design"] = {"listed": true, "price": 100, "sold": 0}
	var market_again := Marketplace.new(market.config, data.products)
	market_again.restore(saved_market)
	_check(market_again.listing(&"cable_management_clips_x12") == market.listing(&"cable_management_clips_x12"), "listings come back with their price and sales")
	_check(not market_again.listings.has(&"gone_design"), "a listing for a design the game no longer has is dropped")
	_check(market_again.orders.size() == market.orders.size() and market_again.open_orders().size() == market.open_orders().size(), "every order comes back in the state it was in")
	var second_again := market_again.order_by_id(second.id)
	_check(second_again.status == Marketplace.Status.SHIPPED and second_again.durability == 2 and second_again.flawed and is_equal_approx(second_again.deliver_at, 9000.0), "a parcel in the post comes back with what is inside it")
	_check(market_again.reviews.size() == 1 and is_equal_approx(market_again.rating(), market.rating()), "reviews and the rating come back")
	var next_before := market.tick(0.0, 1440.0 * 50.0, rng)
	var next_after := market_again.tick(0.0, 1440.0 * 50.0, rng)
	_check(not next_before.is_empty() and not next_after.is_empty() and next_after[0].id == next_before[0].id, "new orders carry on numbering from where they left off")
	_check(market_again.deliver(9000.0, rng, data.settings["courier"]).size() == 1, "a loaded parcel is still delivered when its time comes")

	var supplier := Supplier.new(data)
	supplier.place({"printers": {"plodder_mini": 1}, "spools": {"red": 2}, "packaging": 1, "parts": {"brass_nozzle_0_4mm": 1}}, 50.0, "Printbay")
	var supplier_again := Supplier.new(data)
	supplier_again.restore(_through_file(supplier.save()))
	_check(supplier_again.pending.size() == 2 and supplier_again.pending[0].describe() == supplier.pending[0].describe(), "deliveries on their way come back")
	var due := supplier_again.collect_due(50.0 + 180.0)
	_check(due.size() == 2 and due[0].parts[&"brass_nozzle_0_4mm"] == 3 and due[1].printer == &"plodder_mini" and due[0].shop == "Printbay", "and arrive with everything that was ordered")

	var wear := PrinterWear.new(data.parts, data.printers["plodder_mini"], 4.0)
	wear.apply(30.0, data.presets["standard"], data.filaments["pla"])
	var saved_wear := _through_file(wear.save())
	saved_wear["fitted"]["belts"] = "gone_part"
	var wear_again := PrinterWear.new(data.parts, data.printers["plodder_mini"], 4.0)
	wear_again.restore(saved_wear)
	_check(is_equal_approx(wear_again.health[&"nozzle"], wear.health[&"nozzle"]) and wear_again.worst() == &"nozzle", "a printer's parts come back as worn as they were")
	_check(wear_again.fitted[&"belts"] == &"gt2_timing_belt" and is_equal_approx(wear_again.health[&"belts"], 1.0), "a part the game no longer has is swapped for the standard one")

	var job := PrintJob.new(120.0)
	job.fail(data.failures["spaghetti"], 0.6)
	job.advance(30.0)
	var job_again := PrintJob.restored(_through_file(job.save()))
	_check(is_equal_approx(job_again.progress, 0.25) and job_again.ruined, "a print in progress comes back part way through, still doomed")
	_check(not job_again.advance(30.0) and job_again.advance(30.0) and is_equal_approx(job_again.progress, 0.6), "and fails at the same point it would have")


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

	var spares := {"parts": {"brass_nozzle_0_4mm": 2, "ptfe_tube": 1}}
	_check(supplier.price_of(spares) == 2 * 699 + 449, "spare parts are priced by the pack")
	var parts_box := supplier.place(spares, 0.0)
	_check(parts_box.size() == 1 and parts_box[0].parts[&"brass_nozzle_0_4mm"] == 6 and parts_box[0].parts[&"ptfe_tube"] == 1, "a delivery holds every part in each pack")
	_check(parts_box[0].describe() == "7 parts", "a parts delivery says how many parts it holds")
	_check(supplier.price_of({"parts": {"auto_bed_levelling_kit": 1}}) == 3899, "upgrade kits are bought the same way as parts")
	_check(supplier.place({"parts": {"auto_bed_levelling_kit": 2}}, 5000.0)[0].parts[&"auto_bed_levelling_kit"] == 2, "and come one to a pack")
	_check(supplier.collect_due(120.0).size() == 1, "spare parts arrive after the parts lead time")
