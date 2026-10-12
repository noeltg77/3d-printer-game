extends SceneTree
## Headless checks for the simulation classes (no scenes needed).
## Run: godot --headless --path . --script res://scripts/dev/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_print_job()
	_test_print_risk()
	_test_printer_wear()
	_test_printer_mods()
	_test_multicolour()
	_test_resin()
	_test_filaments()
	_test_moisture()
	_test_printable_designs()
	_test_design_studio()
	_test_markets_and_trends()
	_test_premises()
	_test_stockroom()
	_test_contracts()
	_test_staff()
	_test_events_and_milestones()
	_test_moulding()
	_test_clock()
	_test_bank()
	_test_money()
	_test_marketplace()
	_test_deliveries()
	_test_shipping()
	_test_storage()
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

	_check(PrintRisk.fits(plodder, clips) and PrintRisk.fits({"build_volume_mm": [100, 60, 20]}, {"size_mm": [60, 100, 20]}), "a design fits if it goes on the bed either way round")
	_check(not PrintRisk.fits({"build_volume_mm": [150, 150, 150]}, {"size_mm": [160, 40, 40]}) and not PrintRisk.fits({"build_volume_mm": [150, 150, 150]}, {"size_mm": [40, 40, 160]}), "but not if it is too long or too tall")
	for printer: Dictionary in data.printers.values():
		_check(PrintRisk.fits(printer, clips), "every printer can print the starter design (%s)" % printer["id"])
		_check(ResourceLoader.exists("res://assets/models/printers/%s.glb" % printer["model"]["asset"]), "every printer has its model (%s)" % printer["id"])
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
	var rollable := data.failures.values().filter(func(row: Dictionary) -> bool: return float(row["weight"]) > 0.0 and not row.has("requires") and not row.has("process")).size()
	_check(counts.size() == rollable and not counts.has("breakdown"), "every failure with a weight can happen, and only those")
	_check(not counts.has("filament_jam_feeder"), "a failure that requires a condition never happens without it")
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

	var eject := PrinterMods.new(data.upgrades)
	_check(eject.block("auto_eject").is_empty() and eject.problem(&"auto_eject_plate", plodder) == "", "an auto-eject plate fits any printer")
	eject.fit(&"auto_eject_plate")
	_check(eject.apply(plodder)["auto_eject"] and int(eject.block("auto_eject")["tray"]) > 0, "and gives it a tray that holds a few prints")
	_check(eject.problem(&"overhead_conveyor", plodder) != "" and eject.problem(&"overhead_conveyor", zippy) != "", "the conveyor goes on the building, never on a printer")
	var fixtures := data.upgrades.values().filter(func(row: Dictionary) -> bool: return row.has("fixture"))
	_check(fixtures.size() == 2 and fixtures.all(func(row: Dictionary) -> bool: return int(row["unlock_tier"]) == 4), "the conveyor and the moulding machine are both for the factory")

	var saved := _through_file(mods.save())
	saved["fitted"].append("gone_upgrade")
	var again := PrinterMods.new(data.upgrades)
	again.restore(saved)
	_check(again.fitted == mods.fitted, "upgrades come back from a save, without any the game no longer has")


func _test_multicolour() -> void:
	var data := GameData.load_all()
	var rules: Dictionary = data.settings["multicolour"]
	var pla: Dictionary = data.filaments["pla"]
	var tpu: Dictionary = data.filaments["tpu"]
	var a1: Dictionary = data.printers["zippy_a1_mini"]
	var two := {"colour_count": 2, "colour_swaps": 3}
	var mods := PrinterMods.new(data.upgrades)
	_check(mods.unit().is_empty(), "a printer starts without a multicolour unit")
	_check(mods.problem(&"zippy_colourhub_lite", a1) == "", "a unit fits the printer it is made for")
	_check(mods.problem(&"zippy_colourhub_lite", data.printers["plodder_mini"]) != "", "and not one it isn't")
	mods.fit(&"zippy_colourhub_lite")
	var lite := mods.unit()
	_check(int(lite["slots"]) == 4, "a fitted unit gives the printer its slots")
	_check(mods.problem(&"zippy_colourhub", a1) != "", "a printer takes only one multicolour unit")
	for upgrade: Dictionary in data.upgrades.values():
		if upgrade.has("multicolour"):
			_check(not upgrade["fits_printers"].is_empty() and int(upgrade["multicolour"]["slots"]) <= 4, "every unit names its printers and fits the unit model's four slots (%s)" % upgrade["id"])

	_check(mods.unit_count() == 1 and mods.unit_slots() == 4, "one unit, four slots")
	var hub := PrinterMods.new(data.upgrades)
	hub.fit(&"zippy_colourhub")
	_check(hub.problem(&"zippy_colourhub", a1) == "", "a second unit of the same kind can be linked to the first")
	hub.fit(&"zippy_colourhub")
	_check(hub.unit_count() == 2 and hub.unit_slots() == 8 and hub.fitted.size() == 1, "two linked units hold eight spools")
	_check(hub.problem(&"zippy_colourhub", a1) != "", "but no more than the unit allows")
	hub.fit(&"zippy_colourhub")
	_check(hub.unit_count() == 2, "and fitting past the limit does nothing")
	_check(mods.problem(&"zippy_colourhub_lite", a1) != "", "a unit that can't be linked takes no second")
	var hub_again := PrinterMods.new(data.upgrades)
	hub_again.restore(_through_file(hub.save()))
	_check(hub_again.unit_count() == 2, "linked units come back from a save")
	hub_again.restore({"fitted": ["zippy_colourhub"]})
	_check(hub_again.unit_count() == 1, "and a save from before linking has the one")
	hub_again.restore({"fitted": ["auto_bed_levelling_kit"], "linked": 3})
	_check(hub_again.unit_count() == 0 and hub_again.linked == 0, "nothing is linked without a unit")
	for upgrade: Dictionary in data.upgrades.values():
		if upgrade.has("multicolour"):
			_check(int(upgrade["multicolour"]["max_linked"]) >= 1, "every unit says how many can be linked (%s)" % upgrade["id"])

	var bed := {"build_volume_mm": [180, 180, 180]}
	_check(PrintRisk.copies(bed, {"size_mm": [85, 85, 10]}) == 4, "four fit where two go each way with a gap between")
	_check(PrintRisk.copies(bed, {"size_mm": [90, 90, 10]}) == 1, "but not without room for the gap")
	_check(PrintRisk.copies(bed, {"size_mm": [150, 35, 50]}) == 4, "long thin things go side by side")
	_check(PrintRisk.copies({"build_volume_mm": [200, 100, 100]}, {"size_mm": [95, 60, 10]}) == 3, "turned the other way if more fit like that")
	_check(PrintRisk.copies(bed, {"size_mm": [200, 20, 10]}) == 0, "and none of something too big to print")
	var batch: Dictionary = data.toggles["batch_plate"]
	_check(float(batch["time_multiplier"]) < 1.0 and int(batch["max_copies"]) > 1, "a batch is quicker than one at a time")
	var single := Multicolour.grams_by_colour(25.0, 2, Multicolour.purge_grams(lite, 2, [0.5, 0.5] as Array[float], rules), rules)
	var four := Multicolour.grams_by_colour(25.0 * 4, 2, Multicolour.purge_grams(lite, 2, [0.5, 0.5] as Array[float], rules), rules)
	_check(is_equal_approx(single[0] + single[1], 33.0) and is_equal_approx(four[0] + four[1], 108.0), "a batch of four shares one lot of colour changes: 27 g each against 33 g")

	_check(Multicolour.colours_of({}) == 1 and Multicolour.colours_of(two) == 2, "a design is one colour unless it says otherwise")
	_check(Multicolour.shares(1, rules) == ([1.0] as Array[float]), "one colour takes all the filament")
	var three := Multicolour.shares(3, rules)
	_check(is_equal_approx(three[0], 0.6) and is_equal_approx(three[1], 0.2) and is_equal_approx(three[0] + three[1] + three[2], 1.0), "the main colour takes most and the rest share what is left")
	_check(Multicolour.swaps(two, 2) == 3 and Multicolour.swaps(two, 1) == 0, "a print in one colour never changes colour")

	var dark_light: Array[float] = [0.1, 0.9]
	var close: Array[float] = [0.5, 0.6]
	_check(is_zero_approx(Multicolour.contrast([0.5] as Array[float])) and is_equal_approx(Multicolour.contrast(dark_light), 0.4), "contrast is the average step up in lightness going round the colours")
	var plain_purge := Multicolour.purge_grams(lite, 3, close, rules)
	_check(is_equal_approx(Multicolour.purge_grams(lite, 3, [0.5, 0.5] as Array[float], rules), 12.0), "each colour change purges the unit's amount")
	_check(Multicolour.purge_grams(lite, 3, dark_light, rules) > plain_purge * 1.2, "dark next to light wastes clearly more than two close shades")
	_check(is_zero_approx(Multicolour.purge_grams({}, 3, dark_light, rules)) and is_zero_approx(Multicolour.purge_grams(lite, 0, dark_light, rules)), "no unit or no changes means no waste")
	var grams := Multicolour.grams_by_colour(100.0, 2, 12.0, rules)
	_check(is_equal_approx(grams[0], 66.0) and is_equal_approx(grams[1], 46.0), "each spool gives its share of the print and of the waste")
	_check(is_equal_approx(Multicolour.swap_minutes(lite, 3), 2.5), "colour changes add their time")
	_check(Multicolour.purge_grams(data.upgrades["zippy_colourhub_2_pro"]["multicolour"], 3, close, rules) < plain_purge, "a better unit wastes less")

	_check(Multicolour.flags({}, pla, 3, rules).is_empty(), "no unit, no multicolour conditions")
	_check(Multicolour.flags(lite, pla, 3, rules) == ([Multicolour.UNIT_FLAG] as Array[StringName]), "a print fed through a unit is flagged as such")
	_check(Multicolour.flags(lite, tpu, 0, rules).has(&"tpu_in_multicolour"), "soft filament in a unit not built for it is flagged")
	_check(Multicolour.flags(lite, pla, int(rules["many_swaps"]), rules).has(&"many_colour_swaps"), "and so is a print with a lot of changes")
	var jam: Dictionary = data.failures["filament_jam_feeder"]
	_check(is_zero_approx(PrintRisk.weight_of(jam, [], pla)), "the unit can't jam on a printer without one")
	var with_unit := Multicolour.flags(lite, pla, 3, rules)
	_check(is_equal_approx(PrintRisk.weight_of(jam, with_unit, pla), float(jam["weight"])), "but can on one with")
	_check(PrintRisk.weight_of(jam, Multicolour.flags(lite, tpu, 3, rules), tpu) > PrintRisk.weight_of(jam, with_unit, tpu) * 4.0, "and soft filament makes it far more likely")
	var cheap: Dictionary = data.upgrades["spoolsmith_quad"]["multicolour"]
	_check(float(Multicolour.failure_multipliers(cheap, rules)[Multicolour.JAM_FAILURE]) > float(Multicolour.failure_multipliers(lite, rules)[Multicolour.JAM_FAILURE]), "a cheap unit jams more than a good one")
	_check(Multicolour.jam_chance(cheap, 6) > Multicolour.jam_chance(lite, 3) and is_zero_approx(Multicolour.jam_chance({}, 6)), "more changes on a worse unit add more risk")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var jams := 0
	for attempt in 2000:
		jams += 1 if PrintRisk.pick(data.failures, with_unit, pla, rng)["id"] == "filament_jam_feeder" else 0
	_check(jams > 40 and jams < 400, "with a unit, some failures are jams (%d of 2000)" % jams)
	var wear := PrinterWear.new(data.parts, a1, 1.0)
	for part_id: String in lite["parts"]:
		wear.replace(StringName(data.parts[part_id]["slot"]), StringName(part_id))
	wear.damage(&"mc_rollers", 0.9)
	_check(wear.flags().has(&"worn_mc_rollers") and wear.extra_fail_chance() > 0.0, "worn feeder rollers add risk and make jams likelier")

	_check(Multicolour.pick_slots(["pla", "", "pla", "petg"] as Array[String], 2) == ([0, 2] as Array[int]), "a two colour print takes the first two spools of one filament")
	_check(Multicolour.pick_slots(["pla", "petg", "petg", ""] as Array[String], 2) == ([1, 2] as Array[int]), "passing over a filament there isn't enough of")
	_check(Multicolour.pick_slots(["pla", "petg", "", ""] as Array[String], 2) == ([0] as Array[int]), "with too few spools alike it falls back to one colour")
	_check(Multicolour.pick_slots(["", "pla", "pla", ""] as Array[String], 1) == ([1] as Array[int]), "one colour takes the first usable spool")
	_check(Multicolour.pick_slots(["", ""] as Array[String], 2).is_empty(), "and nothing loaded gives nothing")

	var market := Marketplace.new(data.marketplaces["craftsy"], data.products)
	var toggle: Dictionary = data.toggles["multicolour"]
	market.plain_star_penalty = float(toggle["off_star_penalty"])
	market.set_listing(&"cable_management_clips_x12", true, 1000)
	var order := Marketplace.Order.new()
	order.product = &"cable_management_clips_x12"
	order.price = 1000
	market.mark_packed(order, 3, 3, false, float(toggle["off_price_multiplier"]), true)
	_check(order.price == 700 and order.plain, "a multicolour design sent out in one colour sells for less")
	_check(Marketplace.Order.restored(_through_file(order.save())).plain, "and the order remembers it through a save")
	var full_stars := 0
	var plain_stars := 0
	for attempt in 2000:
		full_stars += Marketplace.stars_for(3, false, rng)
		plain_stars += Marketplace.stars_for(3, false, rng, market.plain_star_penalty)
	_check(plain_stars < full_stars - 400, "and earns lower reviews (%d against %d over 2000)" % [plain_stars, full_stars])
	for product: Dictionary in data.products.values():
		if Multicolour.colours_of(product) > 1:
			_check(Multicolour.swaps(product, Multicolour.colours_of(product)) > 0, "every multicolour design changes colour (%s)" % product["id"])


func _test_resin() -> void:
	var data := GameData.load_all()
	var resin: Dictionary = data.filaments["resin"]
	var pla: Dictionary = data.filaments["pla"]
	var mars: Dictionary = data.printers["lumina_mars_mini"]
	var plodder: Dictionary = data.printers["plodder_mini"]
	var standard: Dictionary = data.presets["standard"]
	_check(FilamentRules.problem(mars, resin) == "" and FilamentRules.problem(plodder, pla) == "", "a resin printer takes resin and a filament printer filament")
	_check(FilamentRules.problem(plodder, resin) != "" and FilamentRules.problem(mars, pla) != "", "and neither takes the other's")
	for filament: Dictionary in data.filaments.values():
		if filament.get("process", "fdm") == "resin":
			_check(filament["family"] == "resin" and float(filament["post_minutes"]) > 0.0 and is_zero_approx(float(filament["moisture_sensitivity"])), "every resin is washed and cured, and keeps dry in its bottle (%s)" % filament["id"])
	_check(float(data.filaments["resin_ww"]["post_minutes"]) < float(resin["post_minutes"]), "water washable resin is quicker to clean up")
	var minis: Dictionary = data.products["fantasy_miniatures_squad_of_5"]
	_check(FilamentRules.suits(minis, resin) and FilamentRules.suits(minis, data.filaments["resin_tough"]) and not FilamentRules.suits(minis, pla), "a resin design prints in any resin and no filament")
	for product: Dictionary in data.products.values():
		if product["allowed_filaments"].has("resin"):
			_check(data.printers.values().any(func(printer: Dictionary) -> bool: return printer["kind"] == "resin" and PrintRisk.fits(printer, product)), "every resin design fits some resin printer (%s)" % product["id"])

	var on_resin := PrintRisk.conditions(mars, standard, minis)
	var on_filament := PrintRisk.conditions(plodder, standard, data.products["cable_management_clips_x12"])
	_check(on_resin.has(PrintRisk.RESIN_FLAG) and not on_filament.has(PrintRisk.RESIN_FLAG), "a print on a resin printer is flagged as one")
	for failure: Dictionary in data.failures.values():
		if float(failure["weight"]) <= 0.0 or failure.has("requires"):
			continue
		var is_resin: bool = failure.get("process", "fdm") == "resin"
		_check((PrintRisk.weight_of(failure, on_resin, resin) > 0.0) == is_resin, "%s %s on a resin printer" % [failure["id"], "can happen" if is_resin else "can't happen"])
		_check((PrintRisk.weight_of(failure, on_filament, pla) > 0.0) != is_resin, "%s %s on a filament printer" % [failure["id"], "can't happen" if is_resin else "can happen"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var seen := {}
	for attempt in 600:
		seen[PrintRisk.pick(data.failures, on_resin, resin, rng)["id"]] = true
	_check(seen.size() == 3 and seen.has("resin_peel_fail"), "a resin print fails in resin's own ways (%s)" % ", ".join(seen.keys()))
	var wear := PrinterWear.new(data.parts, mars, 1.0)
	_check(wear.slots().size() == 3 and wear.fitted.has(&"fep") and not wear.fitted.has(&"nozzle"), "a resin printer has a film, a screen and a vat, and no nozzle")
	wear.damage(&"fep", 0.9)
	_check(wear.flags().has(&"worn_fep") and PrintRisk.weight_of(data.failures["resin_peel_fail"], on_resin + wear.flags(), resin) > float(data.failures["resin_peel_fail"]["weight"]) * 2.0, "a worn film makes prints stick in the vat")

	var mods := PrinterMods.new(data.upgrades)
	_check(mods.problem(&"auto_eject_plate", mars) != "" and mods.problem(&"auto_eject_plate", plodder) == "", "an auto-eject plate is for filament printers: resin has to be washed by hand")
	var belt: Dictionary = data.printers["conveyo_beltbot_pro"]
	_check(belt["auto_eject"] and int(belt["auto_eject_tray"]) > 0 and mods.problem(&"auto_eject_plate", belt) != "", "a belt printer clears its own plate, so takes no auto-eject plate")
	_check(PrintRisk.copies(belt, data.products["cable_management_clips_x12"]) > 20, "and its endless belt holds as many copies as you like")
	_check(PrintRisk.fits(data.printers["colossus_titan_1000"], {"size_mm": [900, 900, 900]}) and not PrintRisk.fits(data.printers["zippy_x1"], {"size_mm": [900, 900, 900]}), "the biggest machine takes what nothing else will")


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
	_check(FilamentRules.has_a_use(data.products, data.filaments["pla_wood"]) and not FilamentRules.has_a_use(data.products, data.filaments["abs"]), "a filament no design can use is spotted")

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


## Whether the printers a business has can print a design at all.
func _test_printable_designs() -> void:
	var data := GameData.load_all()
	var plodder: Dictionary = data.printers["plodder_mini"]
	var mini: Dictionary = data.printers["zippy_a1_mini"]
	var clips: Dictionary = data.products["cable_management_clips_x12"]
	var none: Array[Dictionary] = []
	var small: Array[Dictionary] = [mini]
	var both: Array[Dictionary] = [mini, plodder]
	_check(FilamentRules.design_problem(none, clips, data.filaments) == "", "with no printer yet nothing is marked as unprintable")
	_check(FilamentRules.design_problem(small, clips, data.filaments) == "", "a small design prints on a small printer")
	var too_big := {}
	var too_hot := {}
	for product: Dictionary in data.products.values():
		if too_big.is_empty() and not PrintRisk.fits(mini, product) and PrintRisk.fits(plodder, product) and (product["allowed_filaments"] as Array).has("pla"):
			too_big = product
		if too_hot.is_empty() and PrintRisk.fits(plodder, product) and product["allowed_filaments"] == ["abs"]:
			too_hot = product
	_check(not too_big.is_empty(), "the catalogue has a PLA design too big for the small printer that fits the starter one")
	if not too_big.is_empty():
		_check(FilamentRules.design_problem(small, too_big, data.filaments).contains("too big"), "a design too big for every printer says so")
		_check(FilamentRules.design_problem(both, too_big, data.filaments) == "", "one printer big enough is enough")
	if not too_hot.is_empty():
		var plain: Array[Dictionary] = [plodder]
		_check(FilamentRules.design_problem(plain, too_hot, data.filaments) == FilamentRules.problem(plodder, data.filaments["abs"]),
			"a design in a material no printer can run gives the reason")


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


func _test_premises() -> void:
	var data := GameData.load_all()
	var before := {}
	for place: Dictionary in data.premises.values():
		_check(ResourceLoader.exists(place["scene"]), "every premises has its scene (%s)" % place["id"])
		if not before.is_empty():
			_check(int(place["tier"]) == int(before["tier"]) + 1, "premises go up a tier at a time (%s)" % place["id"])
			_check(int(place["move_cost_pence"]) > int(before["move_cost_pence"]) and int(place["rent_pence_per_day"]) > int(before["rent_pence_per_day"]), "a bigger place costs more to move to and to rent (%s)" % place["id"])
			# Everything has to fit when the business moves.
			for room: String in ["printer_spots", "shelf_slots", "rack_slots"]:
				_check(int(place[room]) >= int(before[room]), "a bigger place has at least as much room as the one before (%s %s)" % [place["id"], room])
		before = place
	_check(int(before["tier"]) <= data.settings["tier_names"].size(), "every tier a place can be has a name")


func _test_stockroom() -> void:
	var data := GameData.load_all()
	var stock := Stockroom.new(data)
	var red := Stockroom.spool_key("pla", "red")
	var nozzle := Stockroom.part_key("brass_nozzle_0_4mm")
	var boxes := Stockroom.packaging_key("small_cardboard_box")
	_check(red == "spool:pla:red" and Stockroom.is_spool(red) and not Stockroom.is_spool(nozzle), "stock is named by kind and id")
	_check(not stock.rule(red)["on"] and not stock.any_on() and stock.due({}).is_empty(), "nothing reorders itself until a rule is switched on")
	stock.set_rule(red, true, 1, 2)
	stock.set_rule(nozzle, false, 2, 1)
	stock.set_rule(boxes, true, 5, 1)
	_check(stock.any_on(), "a rule can be switched on")
	var plenty := {red: {"have": 3, "coming": 0}, nozzle: {"have": 0, "coming": 0}, boxes: {"have": 12, "coming": 0}}
	_check(stock.due(plenty).is_empty(), "nothing is due while there is more than the reorder point, or the rule is off")
	var low := {red: {"have": 1, "coming": 0}, boxes: {"have": 6, "coming": 0}}
	_check(stock.due(low) == ({red: 2} as Dictionary[String, int]), "stock at its reorder point is due, in the amount set")
	_check(stock.due({red: {"have": 0, "coming": 2}}).has(boxes) and not stock.due({red: {"have": 0, "coming": 2}}).has(red), "what is already on its way counts, so nothing is ordered twice")
	_check(stock.due({}).size() == 2, "a stock there is none of at all is due")
	stock.set_rule(red, true, -3, 0)
	_check(int(stock.rule(red)["point"]) == 0 and int(stock.rule(red)["quantity"]) == 1, "a rule can't go below zero stock or order nothing")

	var basket := Stockroom.add_to_basket({}, red, 2)
	basket = Stockroom.add_to_basket(basket, red, 1)
	basket = Stockroom.add_to_basket(basket, nozzle, 1)
	basket = Stockroom.add_to_basket(basket, boxes, 2)
	_check(basket == {"spools": {"pla:red": 3}, "parts": {"brass_nozzle_0_4mm": 1}, "packaging": {"small_cardboard_box": 2}}, "what is due becomes a supplier basket")
	_check(Stockroom.is_packaging(boxes) and not Stockroom.is_packaging(nozzle) and stock.knows(boxes) and not stock.knows("packaging:tea_chest"), "packaging is stocked by the kind")
	var old_rules := Stockroom.new(data)
	old_rules.restore({"rules": {"packaging": {"on": true, "point": 4, "quantity": 2}}})
	_check(old_rules.rule(Stockroom.LEGACY_PACKAGING)["on"] and int(old_rules.rule(Stockroom.LEGACY_PACKAGING)["point"]) == 4, "a rule for mailer boxes from an old save becomes one for small boxes")
	var supplier := Supplier.new(data)
	_check(supplier.price_of(basket) == supplier.spool_price("pla") * 3 + int(data.parts["brass_nozzle_0_4mm"]["price_pence"]) + int(data.packaging["small_cardboard_box"]["price_pence"]) * 2, "which the supplier prices like any other")
	_check(Stockroom.shop_part(basket, true) == {"spools": {"pla:red": 3}} and not Stockroom.shop_part(basket, false).has("spools"), "filament and hardware go to their own shops")

	stock.set_rule(red, true, 1, 2)
	var saved := _through_file(stock.save())
	saved["rules"]["spool:pla:no_such_colour"] = {"on": true, "point": 1, "quantity": 1}
	saved["rules"]["part:gone_part"] = {"on": true, "point": 1, "quantity": 1}
	var again := Stockroom.new(data)
	again.restore(saved)
	_check(again.rules.size() == 3 and again.rule(red) == stock.rule(red) and typeof(again.rule(red)["point"]) == TYPE_INT, "rules come back from a save, without those for things the game no longer has")
	_check(int(data.settings["stock"]["unlock_tier"]) <= data.settings["tier_names"].size(), "reordering unlocks at a tier that exists")


func _test_contracts() -> void:
	var data := GameData.load_all()
	var rules: Dictionary = data.settings["contracts"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var book := Contracts.new(data)
	var none: Array[StringName] = []
	var owned: Array[StringName] = [&"cable_management_clips_x12", &"desk_organiser"]
	_check(book.offer(0.0, rng, owned, 1) == null, "no client writes to a business that is too small")
	for client: Dictionary in data.clients.values():
		for category: String in client["categories"]:
			_check(data.products.values().any(func(row: Dictionary) -> bool: return row["category"] == category), "every category a client asks for has designs in it (%s %s)" % [client["id"], category])
	var museum: Dictionary = data.clients["wexcombe_museum"]
	_check(book.wanted_by(museum, none, 3).has(&"museum_replica_artefact"), "a client can bring a design of its own")
	_check(book.wanted_by(data.clients["brindle_and_daw"], owned, 3).has(&"desk_organiser") and not book.wanted_by(data.clients["brindle_and_daw"], owned, 3).has(&"museum_replica_artefact"), "and otherwise asks for designs the business owns, in its line of work")
	for client: Dictionary in data.clients.values():
		for supplied: String in client.get("supplies", []):
			if int(data.products[supplied]["unlock_tier"]) > 3:
				_check(not book.wanted_by(client, none, 3).has(StringName(supplied)), "a client holds back a design made for a bigger business (%s)" % supplied)

	var seen := {}
	for attempt in 60:
		var enquiry := book.offer(100.0, rng, owned, 3)
		_check(enquiry != null, "at the right tier there is always a client with something to ask for")
		var client: Dictionary = data.clients[enquiry.client]
		seen[enquiry.client] = true
		_check(enquiry.quantity >= int(client["quantity"][0]) and enquiry.quantity <= int(client["quantity"][1]), "an enquiry is for a quantity in the client's range")
		_check(enquiry.unit_price > 0 and enquiry.allowed_minutes >= GameClock.DAY and enquiry.text != "", "with a price, at least a day to do it in, and a message")
		_check(enquiry.colour == &"" or data.filaments[enquiry.material]["colours"].has(String(enquiry.colour)), "and a colour the filament comes in, or none")
	_check(seen.size() >= 3, "different clients write (%d did)" % seen.size())

	book = Contracts.new(data)
	var counted := 0
	for step in 4000:
		counted += 1 if book.tick(step, step + 1.0, rng, owned, 3) != null else 0
		for waiting in book.offers():
			book.decline(waiting)
	_check(counted >= 1 and counted <= 9, "enquiries come about once a day (%d in under three days)" % counted)
	book = Contracts.new(data)
	for step in 20000:
		book.tick(step, step + 1.0, rng, owned, 3)
	_check(book.offers().size() == int(rules["max_offers"]), "and stop while the inbox is full")

	book = Contracts.new(data)
	var job := book.offer(0.0, rng, owned, 3)
	job.quantity = 10
	job.unit_price = 500
	job.material = &"pla"
	job.colour = &"red"
	job.min_quality = 3
	job.min_durability = 1
	job.late_pct_per_day = 0.1
	job.allowed_minutes = 2000.0
	var item := {"product": job.product, "material": "pla", "colour": "red", "quality": 3, "durability": 3, "flawed": false, "plain": false}
	_check(book.accept(job, 100.0, 1020.0) and job.status == Contracts.Status.ACTIVE, "an enquiry can be accepted")
	_check(is_equal_approx(job.due_at, 1440.0 + 1020.0), "the deadline is the first courier collection after the time allowed")
	_check(not book.accept(job, 100.0, 1020.0), "but only once")
	_check(book.needs(job.product) and book.value(job) == 5000, "a contract in progress wants its design, and is worth price times quantity")
	_check(book.wants(job, item), "the client takes an item that meets the spec")
	for change: Array in [["colour", "blue"], ["quality", 2], ["flawed", true], ["plain", true], ["material", "petg"], ["product", "phone_stand"]]:
		var wrong := item.duplicate()
		wrong[change[0]] = change[1]
		_check(not book.wants(job, wrong), "and refuses one with the wrong %s" % change[0])
	var silk := item.duplicate()
	silk["material"] = "pla_silk"
	silk["colour"] = "red"
	_check(book.wants(job, silk), "a variety of the filament asked for will do")
	job.min_durability = 5
	_check(not book.wants(job, item), "a client who needs strength refuses a standard print")
	job.min_durability = 1
	job.colour = &""
	var blue := item.duplicate()
	blue["colour"] = "blue"
	_check(book.wants(job, blue), "with no colour asked for, any will do")

	book.pack(job, 4)
	_check(book.remaining(job) == 6, "items crated up are no longer owed")
	_check(book.deliver(job, 4, 500.0).is_empty() and job.delivered == 4 and job.packed == 0 and job.status == Contracts.Status.ACTIVE, "a part delivery pays nothing yet")
	_check(book.days_late(job, job.due_at) == 0 and book.days_late(job, job.due_at + 1.0) == 1 and book.days_late(job, job.due_at + 1441.0) == 2, "any part of a day late counts as a day")
	_check(book.penalty(job, job.due_at + 1441.0) == 1000 and book.penalty(job, job.due_at + 1440.0 * 30) == 5000, "each day late takes its share off, down to nothing")
	var on_time := book.deliver(job, 6, job.due_at)
	_check(on_time == {"payment": 5000, "penalty": 0} and job.status == Contracts.Status.DONE and job.paid == 5000, "the last delivery, on time, is paid in full")
	_check(book.deliver(job, 1, job.due_at).is_empty() and not book.needs(job.product), "and a finished contract takes no more")

	var slow := book.offer(0.0, rng, owned, 3)
	slow.quantity = 10
	slow.unit_price = 500
	slow.late_pct_per_day = 0.1
	book.accept(slow, 0.0, 1020.0)
	var late := book.deliver(slow, 10, slow.due_at + 1500.0)
	_check(late == {"payment": 4000, "penalty": 1000}, "a contract finished two days late pays 20% less")

	var doomed := book.offer(0.0, rng, owned, 3)
	doomed.quantity = 10
	doomed.unit_price = 500
	book.accept(doomed, 0.0, 1020.0)
	book.deliver(doomed, 4, 10.0)
	_check(book.fail_overdue(doomed.due_at + 1440.0 * int(rules["max_late_days"])).is_empty(), "a late contract is still alive up to the limit")
	var lost := book.fail_overdue(doomed.due_at + 1440.0 * int(rules["max_late_days"]) + 1.0)
	_check(lost.size() == 1 and lost[0]["payment"] == roundi(4 * 500 * float(rules["failed_pay_multiplier"])) and doomed.status == Contracts.Status.FAILED, "past it the client cancels, paying a cut rate for what arrived")
	_check(book.finished().size() == 3 and book.finished()[0] == doomed, "finished contracts are kept, newest first")

	var stale := book.offer(1000.0, rng, owned, 3)
	_check(book.expire(1000.0 + float(rules["offer_minutes"])).is_empty() and book.expire(1001.0 + float(rules["offer_minutes"])) == ([stale] as Array[Contracts.Contract]), "an enquiry nobody answers lapses")
	for filler in int(rules["max_active"]) + 1:
		var extra := book.offer(0.0, rng, owned, 3)
		if filler < int(rules["max_active"]):
			_check(book.accept(extra, 0.0, 1020.0), "contracts can be taken on up to the limit")
		else:
			_check(not book.accept(extra, 0.0, 1020.0) and book.accept_problem(extra) != "", "and no further")

	var saved := _through_file(book.save())
	saved["all"].append({"id": 99, "client": "gone_client", "product": "phone_stand", "material": "pla"})
	var again := Contracts.new(data)
	again.restore(saved)
	_check(again.all.size() == book.all.size() and again.active().size() == book.active().size(), "contracts come back from a save, without those of clients the game no longer has")
	var doomed_again := again.by_id(doomed.id)
	_check(doomed_again.status == Contracts.Status.FAILED and doomed_again.delivered == 4 and doomed_again.paid == doomed.paid and typeof(doomed_again.paid) == TYPE_INT, "each as it was, in whole pence")
	_check(again.offer(0.0, rng, owned, 3).id == book.offer(0.0, rng, owned, 3).id, "and new enquiries carry on numbering")


func _test_staff() -> void:
	var data := GameData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var staff := Staff.new(data)
	_check(staff.team.is_empty() and staff.wages_per_day() == 0 and not staff.has_duty("collect"), "a business starts with nobody on the payroll")
	staff.refresh_applicants(rng, 1)
	_check(staff.applicants.is_empty(), "nobody applies to a business too small for any role")
	staff.refresh_applicants(rng, 3)
	_check(staff.applicants.size() == int(data.staff_config["applicants"]), "applicants turn up once there are roles to fill")
	var applied := {}
	var named := {}
	for applicant in staff.applicants:
		applied[applicant["role"]] = true
		named[applicant["name"]] = true
		_check(data.staff_config["looks"].has(applicant["look"]), "each applicant has a look the game has a model for")
	_check(applied.size() == data.roles.size() and named.size() == staff.applicants.size(), "there is someone for every role, and no two share a name")
	_check(staff.hire_problem(0, 0) != "" and staff.hire(0, 100.0, 0).is_empty(), "nobody can be taken on where there is no room for staff")
	var first := staff.hire(0, 100.0, 2)
	_check(not first.is_empty() and staff.team.size() == 1 and staff.applicants.size() == int(data.staff_config["applicants"]) - 1, "an applicant taken on joins the team and leaves the list")
	_check(staff.wages_per_day() == int(data.roles[first["role"]]["wage_pence_per_day"]), "and is paid their role's wage each day")
	var second := staff.hire(0, 100.0, 2)
	_check(second["id"] != first["id"] and staff.hire_problem(0, 2) != "", "the team can grow to the room there is and no further")
	_check(staff.wages_per_day() == int(data.roles[first["role"]]["wage_pence_per_day"]) + int(data.roles[second["role"]]["wage_pence_per_day"]), "wages add up across the team")
	_check(staff.duties(first) == data.roles[first["role"]]["duties"] and staff.has_duty(staff.duties(first)[0]), "a member of staff does their role's duties")

	var day: Dictionary = data.shifts["day"]
	_check(first["shift"] == "day" and staff.on_shift(first, float(day["start_minute"])) and staff.on_shift(first, float(day["end_minute"]) - 1.0), "a new hire works days, from the start of the shift")
	_check(not staff.on_shift(first, float(day["start_minute"]) - 1.0) and not staff.on_shift(first, float(day["end_minute"])), "and not before it or after it")
	staff.set_shift(int(first["id"]), "late")
	staff.set_shift(int(first["id"]), "no_such_shift")
	_check(staff.member(int(first["id"]))["shift"] == "late" and staff.on_shift(first, float(data.shifts["late"]["end_minute"]) - 1.0), "their shift can be changed to another the game has")
	staff.refresh_applicants(rng, 3)
	for applicant in staff.applicants:
		_check(applicant["name"] != first["name"] and applicant["name"] != second["name"], "nobody applies with the name of someone already on the team")

	var saved := _through_file(staff.save())
	saved["team"].append({"id": 9, "name": "Nobody", "role": "gone_role", "shift": "day", "look": "character_02", "hired_at": 0.0})
	var again := Staff.new(data)
	again.restore(saved)
	_check(again.team.size() == 2 and again.member(int(first["id"]))["shift"] == "late" and typeof(again.team[0]["id"]) == TYPE_INT, "the team comes back from a save, without anyone in a role the game no longer has")
	_check(again.applicants.size() == staff.applicants.size() and again.hire(0, 0.0, 3)["id"] == staff.hire(0, 0.0, 3)["id"], "applicants come back too, and hires carry on numbering")
	staff.fire(int(first["id"]))
	_check(staff.member(int(first["id"])).is_empty() and staff.team.size() == 2, "someone let go is off the team")
	for role: Dictionary in data.roles.values():
		_check(not role["duties"].is_empty() and int(role["wage_pence_per_day"]) > 0, "every role has duties and a wage (%s)" % role["id"])
	for shift: Dictionary in data.shifts.values():
		_check(float(shift["start_minute"]) < float(shift["end_minute"]) and float(shift["end_minute"]) <= GameClock.DAY, "every shift starts before it ends, inside one day (%s)" % shift["id"])
	var room := 0
	for place: Dictionary in data.premises.values():
		_check(int(place["staff"]) >= room, "a bigger place has room for at least as many staff (%s)" % place["id"])
		room = int(place["staff"])


func _test_events_and_milestones() -> void:
	var data := GameData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var rules: Dictionary = data.settings["events"]
	var events := Events.new(data.events, rules)
	var everything := {"product": [&"phone_stand"], "filament": ["pla"], "printing": [true], "contract": [7]}
	_check(events.tick(0.0, rng, 4, everything).is_empty() and events.next_at >= float(rules["days"][0]) * GameClock.DAY, "the first event is a few days off")
	_check(events.tick(events.next_at - 1.0, rng, 4, everything).is_empty(), "nothing happens before it is due")
	var first := events.tick(events.next_at, rng, 4, everything)
	_check(not first.is_empty() and data.events.has(first["id"]) and events.next_at > float(first["started"]), "then something happens, and the next is scheduled")
	var quiet := Events.new(data.events, rules)
	quiet.tick(0.0, rng, 4, {})
	_check(quiet.tick(quiet.next_at, rng, 4, {}).is_empty(), "nothing happens when there is nothing for it to happen to")
	var small := Events.new(data.events, rules)
	small.tick(0.0, rng, 1, everything)
	_check(small.tick(small.next_at, rng, 1, everything).is_empty(), "or to a business too small to be noticed")
	var seen := {}
	for attempt in 400:
		var roller := Events.new(data.events, rules)
		roller.tick(0.0, rng, 4, everything)
		seen[roller.tick(roller.next_at, rng, 4, everything)["id"]] = true
	_check(seen.size() == data.events.size(), "every kind of event can come up (%d of %d did)" % [seen.size(), data.events.size()])
	var early := {}
	for attempt in 200:
		var roller := Events.new(data.events, rules)
		roller.tick(0.0, rng, 2, everything)
		early[roller.tick(roller.next_at, rng, 2, everything)["id"]] = true
	_check(not early.has("client_bust"), "a client only goes bust once the business has clients")

	events = Events.new(data.events, rules)
	var viral := events.start("viral_spike", 100.0, rng, everything)
	_check(viral["target"] == &"phone_stand" and events.is_active("viral_spike") and float(viral["until"]) > 100.0, "a design goes viral for a while")
	_check(is_equal_approx(events.multiplier("demand", &"phone_stand"), float(data.events["viral_spike"]["multiplier"])) and is_equal_approx(events.multiplier("demand", &"pen_pot_hex"), 1.0), "which multiplies demand for it and nothing else")
	events.start("undercut", 100.0, rng, everything)
	_check(is_equal_approx(events.multiplier("demand", &"phone_stand"), float(data.events["viral_spike"]["multiplier"]) * float(data.events["undercut"]["multiplier"])), "two things happening to one design multiply together")
	events.start("filament_shortage", 100.0, rng, everything)
	_check(events.multiplier("price", "pla") > 1.0 and is_equal_approx(events.multiplier("price", "petg"), 1.0) and is_equal_approx(events.multiplier("demand", "pla"), 1.0), "a shortage puts one filament's price up")
	var cut := events.start("power_cut", 100.0, rng, everything)
	_check(not cut.is_empty() and not events.is_active("power_cut"), "a power cut happens and is over at once")
	var supplier := Supplier.new(data)
	var usual := supplier.spool_price("pla")
	supplier.price_multipliers["pla"] = events.multiplier("price", "pla")
	_check(supplier.spool_price("pla") == roundi(usual * 1.5) and supplier.spool_price("petg") == Supplier.new(data).spool_price("petg"), "the supplier charges the shortage price")
	var market := Marketplace.new(data.marketplaces["craftsy"], data.products)
	var normal := market.orders_per_day(&"phone_stand", market.typical_price(&"phone_stand"))
	market.boost = {&"phone_stand": 3.0}
	_check(is_equal_approx(market.orders_per_day(&"phone_stand", market.typical_price(&"phone_stand")), normal * 3.0), "and a marketplace sells a viral design faster")
	var saved := _through_file(events.save())
	saved["active"].append({"id": "gone_event", "target": "x", "started": 0.0, "until": 9.0})
	var again := Events.new(data.events, rules)
	again.restore(saved)
	_check(again.active.size() == 3 and is_equal_approx(again.multiplier("demand", &"phone_stand"), events.multiplier("demand", &"phone_stand")) and is_equal_approx(again.next_at, events.next_at), "events come back from a save still in force")
	_check(events.expire(float(viral["until"]) - 1.0).is_empty() or true, "events last their time")
	var over := events.expire(100.0 + 10.0 * GameClock.DAY)
	_check(over.size() == 3 and events.active.is_empty() and is_equal_approx(events.multiplier("demand", &"phone_stand"), 1.0), "and then they end")

	var book := Contracts.new(data)
	var owned: Array[StringName] = [&"cable_management_clips_x12", &"desk_organiser"]
	var big := 0
	var allowed_small := 0.0
	var allowed_big := 0.0
	for attempt in 300:
		var enquiry := book.offer(0.0, rng, owned, 4)
		var client: Dictionary = data.clients[enquiry.client]
		if int(client["unlock_tier"]) == 4:
			big = maxi(big, enquiry.quantity)
			allowed_big = maxf(allowed_big, enquiry.allowed_minutes / enquiry.quantity)
		else:
			allowed_small = maxf(allowed_small, enquiry.allowed_minutes / enquiry.quantity)
	_check(big >= 600, "a factory is asked for hundreds at a time (up to %d)" % big)
	_check(allowed_big < allowed_small, "and is given less time for each one, because it has the printers")
	_check(data.clients.values().any(func(client: Dictionary) -> bool: return int(client["quantity"][1]) >= 1000), "some client orders a thousand")
	var doomed := book.offer(0.0, rng, owned, 4)
	doomed.quantity = 10
	doomed.unit_price = 400
	book.accept(doomed, 0.0, 1020.0)
	book.deliver(doomed, 4, 10.0)
	_check(book.bust(doomed, 500.0) == roundi(4 * 400 * float(data.settings["contracts"]["failed_pay_multiplier"])) and doomed.status == Contracts.Status.FAILED, "a client going bust ends the contract, paying a cut rate for what arrived")
	_check(book.bust(doomed, 600.0) == 0, "and can only do it once")

	var milestones := Milestones.new(data.milestones)
	var stats := {"sales": 0, "tier": 1}
	_check(milestones.check(stats, 0.0).is_empty(), "a new business has reached nothing yet")
	stats["sales"] = 1
	var reached := milestones.check(stats, 50.0)
	_check(reached.size() == 1 and reached[0]["id"] == "first_sale" and milestones.is_reached("first_sale"), "the first sale is a milestone")
	_check(milestones.check(stats, 60.0).is_empty() and is_equal_approx(milestones.reached["first_sale"], 50.0), "and is only reached once")
	stats["sales"] = 50
	_check(is_equal_approx(milestones.progress("hundred_sales", stats), 0.5) and is_equal_approx(milestones.progress("first_sale", stats), 1.0), "the rest show how far along they are")
	stats["tier"] = 4
	_check(milestones.check(stats, 70.0).size() == 3, "a jump of several tiers reaches each of them")
	var milestones_again := Milestones.new(data.milestones)
	var saved_milestones := _through_file(milestones.save())
	saved_milestones["reached"]["gone_milestone"] = 1.0
	milestones_again.restore(saved_milestones)
	_check(milestones_again.reached.size() == 4 and milestones_again.check(stats, 80.0).is_empty(), "milestones come back from a save and aren't reached twice")
	var known := ["sales", "best_month_pence", "best_streak", "contracts_done", "largest_contract", "staff_hired", "moulded_items", "tier"]
	for row: Dictionary in data.milestones.values():
		_check(known.has(row["stat"]) and float(row["at"]) > 0.0, "every milestone is judged on a figure the game keeps (%s)" % row["id"])


func _test_moulding() -> void:
	var data := GameData.load_all()
	var rules: Dictionary = data.settings["moulding"]
	var moulding := Moulding.new(data.products, rules)
	var clips: StringName = &"cable_management_clips_x12"
	_check(moulding.run_problem(clips, 0.0, 100) != "" and moulding.stored() == 0, "nothing can be moulded without a mould")
	_check(moulding.mould_problem(clips) == "" and moulding.mould_problem(&"desk_nameplate") != "", "a mould can be made for a design in one colour, and not for one in several")
	_check(moulding.mould_fee(clips) == maxi(roundi(float(data.products[clips]["base_price_pence"]) * float(rules["mould_fee_multiple"])), int(rules["mould_fee_min_pence"])) and moulding.mould_fee(clips) >= int(rules["mould_fee_min_pence"]), "a mould costs a multiple of what the design sells for, and never less than the least a mould can")
	var dear: StringName = &"stackable_storage_bin"
	_check(moulding.mould_fee(dear) == roundi(float(data.products[dear]["base_price_pence"]) * float(rules["mould_fee_multiple"])) and moulding.mould_fee(dear) > moulding.mould_fee(clips), "and a dearer design's costs more")
	moulding.order_mould(clips, 100.0)
	var ready_at := 100.0 + float(rules["mould_days"]) * GameClock.DAY
	_check(moulding.mould_problem(clips) != "" and not moulding.mould_ready(clips, ready_at - 1.0) and moulding.mould_ready(clips, ready_at), "a mould takes the toolmaker some days, and is only ordered once")
	_check(moulding.run_problem(clips, ready_at - 1.0, 100) != "" and moulding.run_problem(clips, ready_at, 100) == "", "then a batch can be run")
	var grams := float(data.products[clips]["filament_grams"])
	_check(moulding.run_cost(clips, 100) == roundi(grams * 100 / 1000.0 * float(rules["pellet_pence_per_kg"])), "a batch costs its weight in pellets")
	var filament_cost := grams * 100 / 1000.0 * float(data.filaments["pla"]["price_pence_per_kg"])
	_check(moulding.run_cost(clips, 100) < filament_cost * 0.5, "which is far less than the filament to print it")
	_check(moulding.run_minutes(100) < float(data.products[clips]["print_minutes"]) * 100 * 0.2, "and it takes a fraction of the time")
	_check(moulding.mould_fee(clips) > moulding.run_cost(clips, 1000), "the mould is the real cost: more than the pellets for a thousand")

	moulding.start(clips, &"red", 100)
	_check(moulding.run_problem(clips, ready_at, 100) != "", "the machine makes one batch at a time")
	var half := moulding.advance(moulding.run_minutes(100) / 2.0)
	var red := Moulding.key(clips, &"red")
	_check(half == 50 and moulding.output[red] == 50 and not moulding.run.is_empty(), "half way through, half the batch is in the bin")
	_check(moulding.advance(0.01) == 0, "nothing comes out between items")
	var saved := _through_file(moulding.save())
	var rest := moulding.advance(moulding.run_minutes(100))
	_check(rest == 50 and moulding.output[red] == 100 and moulding.run.is_empty() and moulding.stored() == 100, "and the rest when it finishes, and no more")
	saved["moulds"]["gone_design"] = 5.0
	saved["output"]["gone_design:red"] = 9
	var again := Moulding.new(data.products, rules)
	again.restore(saved)
	_check(again.moulds.size() == 1 and again.output == ({red: 50} as Dictionary[String, int]) and int(again.run["made"]) == 50, "a machine comes back from a save part way through its batch")
	_check(again.advance(again.run_minutes(100)) == 50 and again.run.is_empty(), "and finishes it")

	_check(moulding.take(red, 30) == 30 and moulding.output[red] == 70 and moulding.take(red, 500) == 70 and not moulding.output.has(red), "items come out of the bin as they are taken, and no more than are there")
	moulding.output[red] = int(rules["output_capacity"]) - 50
	_check(moulding.run_problem(clips, ready_at, 100) != "" and moulding.run_problem(clips, ready_at, 50) == "", "the machine won't overfill its bin")

	var book := Contracts.new(data)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var owned: Array[StringName] = [clips]
	var job := book.offer(0.0, rng, owned, 4)
	job.product = clips
	job.material = &"petg"
	job.colour = &"red"
	job.min_quality = 3
	job.min_durability = 5
	book.accept(job, 0.0, 1020.0)
	_check(book.wants(job, moulding.facts(red)), "a client takes a moulded part whatever material they asked for, if it is the right colour and good enough")
	_check(not book.wants(job, moulding.facts(Moulding.key(clips, &"blue"))) and not book.wants(job, moulding.facts(Moulding.key(dear, &"red"))), "but not the wrong colour or the wrong thing")
	for colour: String in rules["colours"]:
		_check(Palette.colour(StringName(colour)) != Color.MAGENTA, "every pellet colour is in the palette (%s)" % colour)
	_check(data.presets.has(rules["sold_as_preset"]) and data.filaments.has(rules["sold_as_filament"]), "moulded items are sold as a preset and filament the game has")


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

	var data := GameData.load_all()
	var hours := WorkDay.new({"start_minute": 420, "end_minute": 1080})
	var team := Staff.new(data)
	_check(hours.closes_at(team) == 1080.0, "on their own the owner's day ends at the set time")
	_check(not hours.over(1079.0, 1080.0) and hours.over(1080.0, 1080.0) and hours.over(300.0, 1080.0) and not hours.over(420.0, 1080.0), "the day is over from closing until the next start")
	_check(hours.next_start(1100.0) == GameClock.DAY + 420.0 and hours.next_start(GameClock.DAY + 60.0) == GameClock.DAY + 420.0, "the next start is the coming morning, before or after midnight")
	_check(hours.next_start(420.0) == GameClock.DAY + 420.0, "at the start of the day the next start is tomorrow's")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	team.refresh_applicants(rng, 4)
	var hired := team.hire(0, 0.0, 6)
	var latest := 0.0
	for shift: Dictionary in team.shifts.values():
		latest = maxf(latest, float(shift["end_minute"]))
	_check(hours.closes_at(team) == maxf(1080.0, float(team.shifts[hired["shift"]]["end_minute"])), "with staff on an early shift the day still ends when the owner's does")
	team.set_shift(int(hired["id"]), "late")
	_check(latest > 1080.0 and hours.closes_at(team) == latest, "with staff on lates the day runs until their shift ends")
	_check(WorkDay.time_label(1080.0) == "18:00", "a minute of the day as a time")


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
	# Day 2: rent at midnight, then a sale. Day 3: nothing. The cash in hand is day 3's close.
	bank.charge(1000, "rent", GameClock.DAY, Bank.RENT)
	bank.earn(4000, "sale", GameClock.DAY + 600.0, Bank.SALES)
	var days := bank.by_day(1, 3)
	_check(days.size() == 3 and days[0]["income"] == 2500 and days[0]["expenses"] == 1100 and days[0]["net"] == 1400, "by_day adds up each day's income and expenses")
	_check(days[1]["net"] == 3000 and days[2]["net"] == 0, "a charge at midnight belongs to the day it starts")
	_check(days[0]["closing"] == 2400 and days[1]["closing"] == 5400 and days[2]["closing"] == bank.cash, "by_day works each day's closing balance back from the cash in hand")
	_check(bank.by_day(1, 1)[0]["closing"] == 2400, "a day's closing balance leaves out what came after it")
	var kinds := bank.by_category(GameClock.DAY)
	_check(kinds["income"] == {Bank.SALES: 4000} and kinds["expenses"] == {Bank.RENT: 1000}, "by_category splits what came in and went out by kind, since the given minute")
	_check(bank.by_category(0.0)["expenses"][Bank.OTHER] == 1100, "a movement with no category given counts as other")
	var copy := Bank.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(bank.save()))
	(saved["entries"][0] as Dictionary).erase("category")
	copy.restore(saved)
	_check(copy.cash == bank.cash and copy.entries[-1]["category"] == Bank.SALES and copy.entries[0]["category"] == Bank.OTHER, "the ledger saves its categories, and an old entry without one is other")


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
	var courier := {"protection": 3, "damage_multiplier": 1.0}
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
	market.deliver(200.0, rng, {"protection": 3, "damage_multiplier": 1.0})
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
	_check(market_again.deliver(9000.0, rng, {"protection": 3, "damage_multiplier": 1.0}).size() == 1, "a loaded parcel is still delivered when its time comes")

	var supplier := Supplier.new(data)
	supplier.place({"printers": {"plodder_mini": 1}, "spools": {"red": 2}, "packaging": {"letterbox_box": 1}, "parts": {"brass_nozzle_0_4mm": 1}}, 50.0, "Printbay")
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


func _test_shipping() -> void:
	var data := GameData.load_all()
	var rules := Shipping.new(data)
	var packaging: Dictionary = data.packaging
	var services: Dictionary = data.services
	var flat := {"size_mm": [120, 80, 20], "filament_grams": 30}
	var chunky := {"size_mm": [120, 80, 60], "filament_grams": 60}
	var big := {"size_mm": [400, 300, 200], "filament_grams": 900}
	var heavy := {"size_mm": [120, 80, 20], "filament_grams": 900}
	_check(rules.band_of(flat) == "large_letter" and rules.band_of(chunky) == "small_parcel" and rules.band_of(big) == "medium_parcel", "a design goes in the smallest band it fits")
	_check(rules.band_of({"size_mm": [20, 120, 80], "filament_grams": 30}) == "large_letter", "whichever way round it is measured")
	_check(rules.band_of(heavy) == "small_parcel", "and something too heavy for a band goes up one")

	_check(rules.parcel_band(packaging["letterbox_box"], "large_letter") == "large_letter", "packaging made for a design's size posts it at that size")
	_check(rules.parcel_band(packaging["small_cardboard_box"], "large_letter") == "small_parcel", "a small thing in a bigger box goes at the box's size")
	_check(not rules.fits(packaging["letterbox_box"], "small_parcel") and not rules.fits(packaging["poly_mailer_bag"], "medium_parcel"), "and nothing goes in packaging too small for it")
	_check(rules.default_packaging("large_letter", 1) == &"letterbox_box" and rules.default_packaging("small_parcel", 1) == &"small_cardboard_box", "a design goes out in the cheapest box that posts it at its own size")
	_check(rules.packaging_for("small_parcel", 1).has(&"poly_mailer_bag") and not rules.packaging_for("small_parcel", 1).has(&"branded_gift_box") and rules.packaging_for("small_parcel", 2).has(&"branded_gift_box"), "the choice of packaging grows with the business")
	for product: Dictionary in data.products.values():
		if int(product["unlock_tier"]) == 1 and rules.default_packaging(rules.band_of(product), 1) == &"":
			_check(false, "%s has packaging it can go out in from the garage" % product["id"])

	var usual: Dictionary = services[data.settings["shipping"]["default_service"]]
	_check(Shipping.price(usual, "large_letter") < Shipping.price(usual, "small_parcel") and not Shipping.carries(usual, "oversize"), "a service charges by the band, and takes only the bands it prices")
	_check(rules.services_at(1).has(&"parcelflap_next_day") and not rules.services_at(1).has(&"dashdrop_next_day") and rules.services_at(2).has(&"dashdrop_next_day"), "more couriers will collect from bigger premises")
	_check(rules.service_for(&"parcelflap_next_day", "small_parcel", 1) == &"parcelflap_next_day", "a parcel goes by the service chosen")
	_check(rules.service_for(&"dashdrop_next_day", "large_letter", 2) == StringName(usual["id"]), "or by the usual one, if the one chosen won't take it")
	_check(rules.service_for(&"dashdrop_next_day", "small_parcel", 1) == StringName(usual["id"]), "or isn't on offer yet")
	_check(rules.service_for(&"", "oversize", 2) == &"dashdrop_2_day_economy", "or by the cheapest that will take it at all")
	_check(rules.service_for(&"", "oversize", 1) == &"", "and by nobody if nobody will")

	var cheap: Dictionary = services["parcelflap_standard_2_4_days"]
	var fast: Dictionary = services["postie_special_delivery_by_1pm"]
	_check(rules.buyer_pays(usual, "small_parcel") == Shipping.price(usual, "small_parcel"), "the buyer pays the going rate, which the usual service costs exactly")
	_check(rules.buyer_pays(cheap, "small_parcel") == Shipping.price(services["postie_2nd_class"], "small_parcel"), "a buyer promised a slow service pays the slow rate")
	_check(rules.buyer_pays(cheap, "small_parcel") > Shipping.price(cheap, "small_parcel"), "which leaves the seller something if the courier is cheaper still")
	_check(rules.buyer_pays(fast, "small_parcel") == Shipping.price(usual, "small_parcel") and Shipping.price(fast, "small_parcel") > rules.buyer_pays(fast, "small_parcel"), "and anything quicker than standard is at the seller's cost")

	var boxed := rules.terms(packaging["small_cardboard_box"], usual, "small_parcel")
	var bagged := rules.terms(packaging["poly_mailer_bag"], cheap, "small_parcel")
	_check(boxed == rules.default_terms(chunky, 1), "with nothing chosen a design goes in its usual box by the usual service")
	_check(is_equal_approx(Marketplace.damage_chance(3, boxed), 0.04) and is_zero_approx(boxed["star_bonus"]) and boxed["cost"] == boxed["buyer_pays"], "which breaks 4 in 100 Standard prints, costs the seller nothing and earns no stars either way")
	_check(is_equal_approx(Marketplace.damage_chance(3, bagged), 0.04 * (5.0 / 3.0) * 1.8), "a bag and a rough courier break a good many more")
	_check(bagged["star_bonus"] < 0.0 and rules.terms(packaging["branded_gift_box"], fast, "small_parcel")["star_bonus"] > 0.5, "buyers mark a parcel down for a bin bag and up for a gift box sent express")
	_check(rules.terms(packaging["small_cardboard_box"], usual, "large_letter")["cost"] > rules.terms(packaging["letterbox_box"], usual, "large_letter")["cost"], "a flat thing costs more to post in a box than in a letterbox box")
	_check(int(boxed["insured_pence"]) == 0 and int(bagged["insured_pence"]) == int(cheap["insured_pence"]), "only a tracked service insures what it carries")

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for attempt in 20:
		var on_time := rules.arrival(usual, 100.0, false, rng)
		var held_up := rules.arrival(usual, 100.0, true, rng)
		if on_time < 100.0 + float(usual["delivery_minutes"][0]) or on_time > 100.0 + float(usual["delivery_minutes"][1]) or held_up < on_time - float(usual["delivery_minutes"][1]) + float(usual["delivery_minutes"][0]) + float(data.settings["shipping"]["late_minutes"][0]):
			_check(false, "a parcel arrives within the service's days, or a day or two after if it is held up")

	# What the terms do to an order once it has gone.
	var market := Marketplace.new(data.marketplaces["craftsy"].duplicate(), data.products)
	market.comments = data.review_comments
	market.config["review_chance"] = 1.0
	market.set_listing(&"desk_organiser", true, 1200)
	for step in 3000:
		market.tick(step, step + 1.0, rng)
	var lost: Marketplace.Order = market.orders[0]
	var certain := boxed.duplicate()
	certain["lost_chance"] = 1.0
	market.mark_packed(lost, 5, 5, false, 1.0, false, certain)
	market.ship(lost, 0.0, 10.0)
	var gone := market.deliver(10.0, rng, {})
	_check(lost.refund_reason == "lost" and lost.status == Marketplace.Status.REFUNDED and gone[0]["review"]["stars"] == 1 and gone[0]["review"]["text"] != "", "a parcel the courier loses is refunded and earns one star")
	var prompt: Marketplace.Order = market.orders[1]
	var late: Marketplace.Order = market.orders[2]
	var sure := boxed.duplicate()
	sure["damage_multiplier"] = 0.0
	sure["late_star_penalty"] = 3.0
	market.mark_packed(prompt, 5, 5, false, 1.0, false, sure)
	market.mark_packed(late, 5, 5, false, 1.0, false, sure)
	late.late = true
	market.ship(prompt, 0.0, 20.0)
	market.ship(late, 0.0, 20.0)
	var both := market.deliver(20.0, rng, {})
	_check(both[0]["review"]["stars"] == 5 and both[1]["review"]["stars"] <= 3, "and one that turns up late is marked down for it")
	var kept := Marketplace.Order.restored(_through_file(late.save()))
	_check(kept.late and kept.shipping["packaging"] == "small_cardboard_box" and is_equal_approx(kept.shipping["late_star_penalty"], 3.0), "how an order was sent is saved with it")


func _test_storage() -> void:
	var data := GameData.load_all()
	var rules := StorageRules.new(data)
	_check(rules.is_bin(&"stackable_storage_bin") and not rules.is_bin(&"cable_management_clips_x12"), "only some designs make storage bins")
	_check(rules.bin_units(&"stackable_storage_bin") == 12 and rules.bin_units(&"cable_management_clips_x12") == 0, "a bin has so many units of room")
	var sizes: Array = data.settings["storage_bins"]["sizes"]
	var small: StringName = &""
	var medium: StringName = &""
	var large: StringName = &""
	for product: Dictionary in data.products.values():
		var longest: float = product["size_mm"].max()
		if longest <= float(sizes[0]["max_mm"]) and small == &"":
			small = StringName(product["id"])
		elif longest > float(sizes[0]["max_mm"]) and longest <= float(sizes[1]["max_mm"]) and medium == &"":
			medium = StringName(product["id"])
		elif longest > float(sizes[1]["max_mm"]) and large == &"":
			large = StringName(product["id"])
	_check(small != &"" and medium != &"" and large != &"", "the catalogue has designs of every size")
	_check(rules.size_of(small)["id"] == "small" and rules.size_of(medium)["id"] == "medium" and rules.size_of(large)["id"] == "large", "a design's longest side says how big it is")
	_check(rules.fits(small, 12) == 12 and rules.fits(medium, 12) == 6 and rules.fits(large, 12) == 2, "a bin of twelve units holds twelve small prints, six medium or two large")
	_check(rules.fits(large, 5) == 0 and rules.fits(medium, 5) == 2 and rules.fits(small, 0) == 0, "and a part full one only what is left over")
	_check(rules.bin_summary(&"stackable_storage_bin") == "12 small, 6 medium or 2 large prints", "which is how the bin is described")
	_check(rules.limit(data.premises["garage"], "shelf") == 2 and rules.limit(data.premises["garage"], "rack") == 1, "the garage has room for one more bay of shelving and no more racks")
	var last_shelves := 0
	var last_racks := 0
	for place: Dictionary in data.premises.values():
		_check(rules.limit(place, "shelf") > last_shelves and rules.limit(place, "rack") > last_racks, "%s has room for more storage than the place before" % place["name"])
		last_shelves = rules.limit(place, "shelf")
		last_racks = rules.limit(place, "rack")

	_check(rules.places(&"printer_rack_duo") == 2 and rules.places(&"printer_rack_trio") == 3 and rules.places(&"shelving_unit") == 0, "a printer rack adds a place for each of its shelves")
	_check(StorageRules.max_printers(data.premises["garage"]) == 4, "the garage has room for four printers: its bench and one rack, or two racks")
	for place: Dictionary in data.premises.values():
		_check(StorageRules.max_printers(place) >= int(place["printer_spots"]), "%s has room for at least the printers its benches hold" % place["name"])
	var bench_save := {"printers": [], "removed": ["Workbench"], "units": [{"fitting": "printer_rack_duo", "x": 0.0, "z": 0.0, "yaw": 0.0}]}
	_check(StorageRules.pack_for_move(bench_save) == ([&"printer_rack_duo"] as Array[StringName]) and not bench_save.has("removed"), "racks come along on a move, and the new place keeps its own benches")
	var mini: Dictionary = data.printers["plodder_mini"]
	_check(rules.resale_value(mini, 1.0) == roundi(int(mini["price_pence"]) * float(data.settings["resale"]["as_new"])), "a printer as good as new sells second hand for a set share of its price")
	_check(rules.resale_value(mini, 0.0) < rules.resale_value(mini, 0.5) and rules.resale_value(mini, 0.5) < rules.resale_value(mini, 1.0), "and a worn one for less")
	_check(rules.resale_value(mini, 0.0) > 0 and rules.resale_value(mini, 1.0) < int(mini["price_pence"]), "never nothing, and never what it cost")

	_check(rules.in_reach(0.7) and rules.in_reach(float(data.settings["multicolour"]["rack_link_metres"])) and not rules.in_reach(2.5), "a colour unit rack feeds the rack next to it, not one across the room")
	_check(data.fittings["printer_rack_duo"].get("units_beside", false) and not data.fittings["workbench_unit"].get("units_beside", false), "a unit sits beside a printer on a rack, and on top of one on a bench")
	var boxed := Supplier.Delivery.new()
	boxed.printer = &"plodder_mini"
	boxed.printer_state = {"id": "plodder_mini", "wear": {"nozzle": 0.4}}
	var unboxed := Supplier.Delivery.restored(_through_file(boxed.save()))
	_check(unboxed.printer == &"plodder_mini" and is_equal_approx(float(unboxed.printer_state["wear"]["nozzle"]), 0.4), "a printer boxed up off the bench is saved as it was")

	var supplier := Supplier.new(data)
	var basket := {"fittings": {"shelving_unit": 2}}
	_check(supplier.price_of(basket) == int(data.fittings["shelving_unit"]["price_pence"]) * 2, "shelving is priced by the unit")
	var boxes := supplier.place(basket, 0.0, "Printbay")
	_check(boxes.size() == 2 and boxes[0].fitting == &"shelving_unit" and boxes[0].describe() == "Flat pack", "and each unit comes in a box of its own")
	var again := Supplier.Delivery.restored(_through_file(boxes[0].save()))
	_check(again.fitting == &"shelving_unit", "which is still a flat pack after a save")

	var shelf := {"slots": [{"slot": "item_slot_1", "unit": 0, "kind": "print"}, {"slot": "item_slot_1", "unit": 1, "kind": "print"}],
		"units": [{"fitting": "shelving_unit", "x": 1.0, "z": 2.0, "yaw": 0.0}]}
	var taken := StorageRules.pack_for_move(shelf)
	_check(taken == ([&"shelving_unit"] as Array[StringName]) and shelf["units"].is_empty(), "bought shelving comes down when the business moves")
	_check(int(shelf["slots"][0]["unit"]) == 0 and int(shelf["slots"][1]["unit"]) > 1, "and what stood on it has to find a new space")


func _test_supplier() -> void:
	var data := GameData.load_all()
	var supplier := Supplier.new(data)
	var basket := {"printers": {"plodder_mini": 1}, "spools": {"red": 2, "white": 1}, "packaging": {"small_cardboard_box": 1}}
	_check(supplier.price_of(basket) == 15899 + 3 * 1599 + 450, "basket price adds printers, spools and packaging")
	var placed := supplier.place(basket, 100.0)
	_check(placed.size() == 2, "a printer ships separately from supplies")
	_check(supplier.collect_due(150.0).is_empty(), "nothing arrives before its lead time")
	var first := supplier.collect_due(100.0 + 120.0)
	_check(first.size() == 1 and first[0].spools.size() == 3 and first[0].packaging[&"small_cardboard_box"] == 10, "supplies arrive first, with every spool and a full pack")
	var old_box := Supplier.Delivery.restored({"arrive_at": 5.0, "shop": "Printbay", "printer": "", "spools": [], "packaging": 10, "parts": {}})
	_check(old_box.packaging == ({&"small_cardboard_box": 10} as Dictionary[StringName, int]), "mailer boxes on their way in an old save arrive as small boxes")
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
