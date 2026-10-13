extends VBoxContainer
## PC app: Printbay, for printers and other hardware. A card per printer with
## stat bars, plus tabs for packaging, upgrades and spare parts.

const NAVY := Color("1F3E7A")
const NAVY_SOFT := Color("2C5096")
const NAVY_TEXT := Color("B9C9EA")
const PAGE := Color("F3F5FA")
const BLUE := Color("3A6FD8")
const BLUE_DARK := Color("26509F")
const TILE := Color("E8EDF7")
const KIND_TEXT := Color("DDE6F7")
const SHADOW := Color("DCE2EE")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")
const TABS := {"printers": "Printers", "packaging": "Packaging", "upgrades": "Upgrades", "parts": "Spare parts", "dryers": "Dryers", "storage": "Storage"}
const MOTIONS := {"bed_slinger": "Bed slinger", "core_xy": "Core XY", "resin_lift": "Resin"}
## Speed multiplier and build volume (litres) that fill a stat bar completely.
const FULL_SPEED := 3.0
const FULL_VOLUME := 40.0
## Size of the picture at the start of a row, in pixels.
const ROW_PICTURE := 64

var screen: PcScreen

var _tab := "printers"


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	add_child(_header())
	var page: Control
	match _tab:
		"printers":
			page = _printers()
		"packaging":
			page = _packaging()
		"parts":
			page = _parts()
		"upgrades":
			page = _upgrades()
		"dryers":
			page = _dryers()
		"storage":
			page = _storage()
		_:
			page = _coming_later()
	var body := Ui.panel(Ui.margin(page, 40, 28, 40, 28), Ui.box(PAGE, 0, 0, 0))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)


func _header() -> Control:
	var bench := _bench()
	var spots := bench.free_spots() + get_tree().get_nodes_in_group(&"printer").size()
	var tier := Ui.panel(Ui.text("Your tier: %s · Space for %d printers" % [Game.tier_name(), spots], 14, PAGE, 800), Ui.box(NAVY_SOFT, 12, 14, 8))
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := Ui.hbox([
		Ui.title(Game.data.settings["supplier"]["hardware_shop"], 32, PAGE, 700),
		Ui.text("Machines, upgrades and spares for makers", 15, NAVY_TEXT),
		null, tier,
	], 20)

	var tabs := Ui.hbox([], 6)
	for id: String in TABS:
		var active := id == _tab
		var button := Ui.button(TABS[id], _pick.bind(id), PAGE if active else Ui.CLEAR, NAVY if active else NAVY_TEXT, 48, 14, Ui.CLEAR, 15)
		for state: StringName in [&"normal", &"hover", &"pressed"]:
			var style := Ui.box(PAGE if active else (Color(1, 1, 1, 0.08) if state == &"hover" else Ui.CLEAR), 14, 22, 0)
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
			button.add_theme_stylebox_override(state, style)
		tabs.add_child(button)

	var style := Ui.box(NAVY, 0, 40, 0)
	style.content_margin_top = 22
	return Ui.panel(Ui.vbox([top, tabs], 18), style)


func _printers() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	for printer_id: String in Game.data.printers:
		grid.add_child(_printer_card(printer_id, Game.data.printers[printer_id]))
	return Ui.scroll(grid)


func _printer_card(printer_id: String, spec: Dictionary) -> Control:
	var owned := 0
	for station: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		owned += 1 if station.spec == spec else 0
	var picture := Ui.panel(ModelPicture.of_printer(spec, 170), Ui.box(TILE, 16, 0, 0))
	picture.custom_minimum_size.y = 186
	var size: Array = spec["build_volume_mm"]
	var litres := float(size[0]) * float(size[1]) * float(size[2]) / 1000000.0
	var materials: PackedStringArray = []
	# One name per family it can print: the plain filament the family is named after.
	for filament: Dictionary in Game.data.filaments.values():
		if filament["id"] == filament["family"] and FilamentRules.problem(spec, filament) == "":
			materials.append(filament["name"])

	var column := Ui.vbox([
		picture,
		Ui.hbox([Ui.pill(MOTIONS.get(spec["motion"], spec["motion"]), NAVY, KIND_TEXT), null,
			Ui.text("You own %d" % owned if owned > 0 else "", 12, Ui.MUTED, 800)]),
		Ui.title(spec["name"], 20),
		Ui.wrap(Ui.text(spec["description"], 13, Ui.MUTED)),
		Ui.vbox([
			_stat("Speed", float(spec["speed_multiplier"]) / FULL_SPEED, BLUE),
			_stat("Reliability", float(spec["reliability"]), Ui.GREEN),
			_stat("Build size", litres / FULL_VOLUME, Ui.ORANGE),
		], 8),
		Ui.text("Prints: %s" % ", ".join(materials), 13, Ui.MUTED),
	], 12)
	var too_big := 0
	for product: Dictionary in Game.data.products.values():
		too_big += 0 if PrintRisk.fits(spec, product) else 1
	var extras: PackedStringArray = []
	if spec["auto_bed_levelling"]:
		extras.append("levels its own bed")
	if spec["direct_drive"]:
		extras.append("direct drive")
	if spec["enclosed"] and spec.get("kind", "fdm") == "fdm":
		extras.append("enclosed")
	if spec.get("auto_eject", false):
		extras.append("clears its own plate")
	if not extras.is_empty():
		column.add_child(Ui.wrap(Ui.text("Built in: %s" % ", ".join(extras), 13, Ui.GREEN_DARK, 800)))
	if too_big > 0:
		column.add_child(Ui.wrap(Ui.text("Too small for %d of the %d designs" % [too_big, Game.data.products.size()], 13, LOCK_TEXT, 800)))

	var order := {"printers": {printer_id: 1}}
	var problem := Game.supplier_problem(order) if Game.unlocked(spec) else "Unlocks when you move to a bigger space"
	if problem != "":
		column.add_child(Ui.panel(Ui.wrap(Ui.text(problem, 13, LOCK_TEXT, 800)), Ui.box(LOCK_BG, 12, 12, 10)))
	column.add_child(Ui.hbox([
		Ui.title(Money.format(int(spec["price_pence"])), 22), null,
		_disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14, BLUE_DARK, 15), problem != ""),
	]))
	var card := Ui.card(column, 22, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _stat(label: String, value: float, colour: Color) -> Control:
	return Ui.hbox([Ui.width(Ui.text(label, 13), 76), Ui.bar(value, colour, TILE)], 10)


func _packaging() -> Control:
	var rows := Ui.vbox([], 12)
	var lead := GameClock.duration_label(Game.supplier.lead_minutes("filament"))
	rows.add_child(Ui.wrap(Ui.text("One goes out with every order, and each design is sent in the kind you pick on its listing. Kept at the packing station. Arrives in %s." % lead, 14, Ui.MUTED)))
	for kind: String in Game.data.packaging:
		var wrap: Dictionary = Game.data.packaging[kind]
		var count := Game.packaging_count(StringName(kind))
		var order := {"packaging": {kind: 1}}
		var problem := Game.supplier_problem(order) if Game.unlocked(wrap) else "Unlocks when you move to a bigger space"
		var fits: PackedStringArray = []
		for band: String in wrap["fits_bands"]:
			fits.append(String(Game.data.bands[band]["name"]).to_lower())
		var words := Ui.vbox([
			Ui.text("%s, pack of %d" % [wrap["name"], int(wrap["pack_size"])], 16, Ui.INK, 800),
			Ui.text("%s Takes a %s." % [wrap["description"], " or ".join(fits)], 13, Ui.MUTED),
		], 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := _disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != "")
		buy.tooltip_text = problem
		var scores := Ui.vbox([
			Ui.hbox([Ui.width(Ui.text("Protection", 12, Ui.MUTED), 72), Ui.pips(int(wrap["protection"]), 5, BLUE, TILE, 10)], 6),
			Ui.hbox([Ui.width(Ui.text("Looks", 12, Ui.MUTED), 72), Ui.pips(int(wrap["presentation"]), 5, BLUE, TILE, 10)], 6),
		], 4)
		rows.add_child(Ui.panel(Ui.hbox([
			ModelPicture.tile(GameData.PACKAGING_MODEL % wrap["model"], ROW_PICTURE, TILE),
			words,
			scores,
			Ui.width(Ui.pill("In stock: %d" % count, Ui.GREEN_DARK if count > 0 else Ui.MUTED, Ui.GREEN_SOFT if count > 0 else TILE) if Game.unlocked(wrap)
				else Ui.pill("Needs more space", LOCK_TEXT, LOCK_BG), 130),
			Ui.width(Ui.text(Money.format(Game.supplier.packaging_price(kind)), 17, Ui.INK, 800), 70),
			buy,
		], 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	return Ui.scroll(rows)


func _parts() -> Control:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	var lead := GameClock.duration_label(Game.supplier.lead_minutes("parts"))
	var rows := Ui.vbox([
		Ui.wrap(Ui.text("Spares wait on your shelving until a printer needs one. Check a printer's Parts menu to see what is wearing. Arrives in %s." % lead, 14, Ui.MUTED)),
	], 12)
	for part_id: String in Game.data.parts:
		var part: Dictionary = Game.data.parts[part_id]
		var order := {"parts": {part_id: 1}}
		var problem := Game.supplier_problem(order) if Game.unlocked(part) else "Unlocks when you move to a bigger space"
		var pack := int(part["pack_size"])
		var words := Ui.vbox([
			Ui.text(part["name"] if pack == 1 else "%s, pack of %d" % [part["name"], pack], 16, Ui.INK, 800),
			Ui.text(part["description"], 13, Ui.MUTED),
		], 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spare := shelf.spare_count(StringName(part_id))
		var buy := _disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != "")
		buy.tooltip_text = problem
		rows.add_child(Ui.panel(Ui.hbox([
			ModelPicture.tile(GameData.part_model(part), ROW_PICTURE, TILE),
			words,
			Ui.width(_worn_note(StringName(part["slot"])) if Game.unlocked(part) else Ui.pill("Needs more space", LOCK_TEXT, LOCK_BG), 150),
			Ui.pill("On the shelf: %d" % spare, Ui.GREEN_DARK if spare > 0 else Ui.MUTED, Ui.GREEN_SOFT if spare > 0 else TILE),
			Ui.width(Ui.text(Money.format(Game.supplier.part_price(part_id)), 17, Ui.INK, 800), 70),
			buy,
		], 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	return Ui.scroll(rows)


## The worst state of this kind of part across the printers, if any is worn.
func _worn_note(slot: StringName) -> Control:
	var worst := 1.0
	for station: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		if station.wear.health.has(slot):
			worst = minf(worst, station.wear.health[slot])
	if worst <= PrinterWear.BROKEN_AT:
		return Ui.pill("Worn out", Ui.RED_DARK, Ui.RED_SOFT)
	if worst < PrinterWear.WORN_BELOW:
		return Ui.pill("Worn: %d%% left" % maxi(roundi(worst * 100.0), 1), Ui.AMBER_DARK, Ui.AMBER_SOFT)
	return Ui.spacer()


## A row per upgrade kit: what it does, what it fits and how many you have.
func _upgrades() -> Control:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	var printers := get_tree().get_nodes_in_group(&"printer")
	var rows := Ui.vbox([
		Ui.wrap(Ui.text("A kit waits on your shelving until you fit it from a printer's Upgrades menu. Each printer needs its own, and it stays on for good.", 14, Ui.MUTED)),
	], 12)
	for upgrade_id: String in Game.data.upgrades:
		var upgrade: Dictionary = Game.data.upgrades[upgrade_id]
		var order := {"parts": {upgrade_id: 1}}
		var problem := Game.supplier_problem(order) if Game.unlocked(upgrade) else "Unlocks when you move to a bigger space"
		var fitted := 0
		var could_fit := 0
		for station: PrinterStation in printers:
			# A second multicolour unit can go on a printer that has one, so "fitted" and "could fit" overlap.
			fitted += 1 if station.mods.has(StringName(upgrade_id)) else 0
			could_fit += 1 if station.mods.problem(StringName(upgrade_id), station.spec) == "" else 0
		var motions: PackedStringArray = []
		for motion: String in upgrade["fits_motion"]:
			motions.append(MOTIONS.get(motion, motion))
		var fits := ", ".join(motions).to_lower() + " printers" if not motions.is_empty() else "any printer"
		# A kit made for particular printers names them.
		var models: PackedStringArray = []
		for printer_id: String in upgrade.get("fits_printers", []):
			models.append(Game.data.printers[printer_id]["name"])
		if not models.is_empty():
			fits = " and ".join(models)
		var fixture: bool = upgrade.has("fixture")
		if fixture:
			fits = "the building, once, where it is marked out"
		var words := Ui.vbox([
			Ui.text(upgrade["name"], 16, Ui.INK, 800),
			Ui.wrap(Ui.text(upgrade["description"], 13, Ui.MUTED)),
			Ui.text("Fits: %s · Takes %s to fit" % [fits, GameClock.duration_label(upgrade["install_minutes"])], 13, NAVY, 800),
		], 2)
		if upgrade.has("multicolour"):
			var unit: Dictionary = upgrade["multicolour"]
			var links := int(unit["max_linked"])
			words.add_child(Ui.text("Holds %d spools%s · Throws away about %s g on each colour change%s" % [int(unit["slots"]),
				"" if links <= 1 else ", or %d with %d linked" % [int(unit["slots"]) * links, links],
				String.num(float(unit["purge_grams_per_swap"]), 1), " · Keeps its spools dry" if unit["keeps_dry"] else ""], 13, NAVY, 800))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var owned := shelf.spare_count(StringName(upgrade_id))
		var state := Ui.pill("On the shelf: %d" % owned, Ui.GREEN_DARK, Ui.GREEN_SOFT) if owned > 0 else Ui.pill(
			"Fitted to %d printer%s" % [fitted, "" if fitted == 1 else "s"] if fitted > 0 else "Not fitted", Ui.MUTED, TILE)
		if fixture:
			# The thing in the scene it goes on is in a group named after the fixture.
			var place := get_tree().get_first_node_in_group(StringName(upgrade["fixture"]))
			if place == null:
				problem = "There is nowhere for it here"
			elif place.get(&"installed"):
				problem = "Already fitted"
				state = Ui.pill("Fitted", Ui.GREEN_DARK, Ui.GREEN_SOFT)
			elif owned > 0 and problem == "":
				problem = "You have one waiting to be fitted"
		var buy := _disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != "")
		buy.tooltip_text = problem
		# A multicolour unit is shown as it looks on the printer.
		var model: String = GameData.UNIT_MODEL % upgrade["multicolour"]["model"] if upgrade.has("multicolour") else GameData.part_model(upgrade)
		var cells: Array = [ModelPicture.tile(model, ROW_PICTURE, TILE), words]
		if not fixture and not printers.is_empty() and could_fit == 0 and owned == 0 and fitted == 0:
			cells.append(Ui.pill("Won't fit your printers", LOCK_TEXT, LOCK_BG))
		cells.append_array([state, Ui.width(Ui.text(Money.format(int(upgrade["price_pence"])), 17, Ui.INK, 800), 70), buy])
		rows.add_child(Ui.panel(Ui.hbox(cells, 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	return Ui.scroll(rows)


## A row per filament dryer. The premises have room for one.
func _storage() -> Control:
	var place := Game.premises_row()
	var rows := Ui.vbox([
		Ui.wrap(Ui.text("More room for stock, spools and printers. It arrives flat packed: click the box, choose where it stands, and it is put up there. You can stand it somewhere else later. If you move, it comes with you.", 14, Ui.MUTED)),
	], 12)
	for fitting_id: String in Game.data.fittings:
		var fitting: Dictionary = Game.data.fittings[fitting_id]
		var kind: String = fitting["kind"]
		var order := {"fittings": {fitting_id: 1}}
		var places := Game.storage.places(StringName(fitting_id))
		var free_standing := kind == "units"
		var have := Game.fittings_owned(StringName(fitting_id)) if free_standing else (Game.printer_places() if places > 0 else Game.fitting_count(kind))
		var limit := 9999 if free_standing else (StorageRules.max_printers(place) if places > 0 else Game.storage.limit(place, kind))
		var problem := Game.supplier_problem(order) if Game.unlocked(fitting) else "Unlocks when you move to a bigger space"
		var words := Ui.vbox([
			Ui.text(fitting["name"], 16, Ui.INK, 800),
			Ui.wrap(Ui.text(fitting["description"], 13, Ui.MUTED)),
			Ui.text(("Places for %d printer%s. The %s has room for %d printers in all: take a bench out to make room." % [places, "" if places == 1 else "s", String(place["name"]).to_lower(), limit]) if places > 0
				else ("Feeds printers on the rack next to it: within %.1f m. As many as you have floor for." % float(Game.data.settings["multicolour"]["rack_link_metres"]) if free_standing
				else "The %s has room for %d in all, counting the one that was here." % [String(place["name"]).to_lower(), limit]), 13, NAVY, 800),
		], 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := _disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != "")
		buy.tooltip_text = problem
		var cells: Array = [ModelPicture.tile(FittingUnit.MODEL_PATH % fitting["model"], ROW_PICTURE, TILE), words]
		cells.append(Ui.pill("You have %d" % have if free_standing else ("%d of %d printer places" if places > 0 else "You have %d of %d") % [have, limit],
			Ui.GREEN_DARK if have < limit else LOCK_TEXT, Ui.GREEN_SOFT if have < limit else LOCK_BG))
		cells.append_array([Ui.width(Ui.text(Money.format(int(fitting["price_pence"])), 17, Ui.INK, 800), 70), buy])
		rows.add_child(Ui.panel(Ui.hbox(cells, 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	var bins := Ui.vbox([Ui.title("Print your own", 20)], 6)
	bins.add_child(Ui.wrap(Ui.text("A printed storage bin takes one space on the shelving and holds several prints. Buy the design in Design Lab, print one, then click the shelving and choose Storage bins.", 14, Ui.MUTED)))
	for design: String in Game.data.settings["storage_bins"]["designs"]:
		bins.add_child(Ui.hbox([
			ModelPicture.of_product(StringName(design), 44),
			Ui.text("%s: holds %s" % [Game.product_name(StringName(design)), Game.storage.bin_summary(StringName(design))], 14, Ui.INK, 800),
		], 12))
	rows.add_child(Ui.panel(bins, Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	return Ui.scroll(rows)


func _dryers() -> Control:
	var spot: DryerSpot = get_tree().get_first_node_in_group(&"dryer_spot")
	var rows := Ui.vbox([
		Ui.wrap(Ui.text("Filament soaks up damp from the air while it sits on the rack, the fussier kinds fastest. Wet filament strings and fails. A dryer bakes it out again in a few hours. There is room for one.", 14, Ui.MUTED)),
	], 12)
	for dryer_id: String in Game.data.dryers:
		var dryer: Dictionary = Game.data.dryers[dryer_id]
		var order := {"dryers": {dryer_id: 1}}
		var owned := spot != null and String(spot.dryer_id()) == dryer_id
		var problem := Game.supplier_problem(order) if Game.unlocked(dryer) else "Unlocks when you move to a bigger space"
		var names: PackedStringArray = []
		for family: String in dryer["dries"]:
			names.append(Game.data.filaments[family]["name"])
		var words := Ui.vbox([
			Ui.text(dryer["name"], 16, Ui.INK, 800),
			Ui.wrap(Ui.text(dryer["description"], 13, Ui.MUTED)),
			Ui.text("Holds %d spool%s · Dries a wet one in about %s · For %s and their varieties" % [int(dryer["capacity"]), "" if int(dryer["capacity"]) == 1 else "s",
				GameClock.duration_label(float(dryer["hours_to_dry"]) * 60.0 * float(Game.data.settings["moisture"]["wet_at"])), ", ".join(names)], 13, NAVY, 800),
		], 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := _disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != "")
		buy.tooltip_text = problem
		var cells: Array = [ModelPicture.tile(GameData.DRYER_MODEL % dryer["model"], ROW_PICTURE, TILE), words]
		if owned:
			cells.append(Ui.pill("You have this one", Ui.GREEN_DARK, Ui.GREEN_SOFT))
		elif problem != "" and problem != "Not enough cash":
			cells.append(Ui.pill(problem, LOCK_TEXT, LOCK_BG))
		cells.append_array([Ui.width(Ui.text(Money.format(int(dryer["price_pence"])), 17, Ui.INK, 800), 70), buy])
		rows.add_child(Ui.panel(Ui.hbox(cells, 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3)))
	return Ui.scroll(rows)


func _coming_later() -> Control:
	var words := Ui.vbox([
		Ui.title("Nothing on these shelves yet", 20),
		Ui.wrap(Ui.text("Upgrades that make a printer faster, tougher or less fussy arrive when you outgrow the garage.", 14, Ui.MUTED)),
	], 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := Ui.panel(Ui.hbox([Ui.icon_tile("wrench", 52, 26, TILE, NAVY), words], 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3))
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return row


func _disabled_if(button: Button, disabled: bool) -> Button:
	button.disabled = disabled
	return button


func _pick(tab: String) -> void:
	_tab = tab
	refresh.call_deferred()


func _buy(order: Dictionary) -> void:
	Game.place_supplier_order(order, Game.data.settings["supplier"]["hardware_shop"])


func _bench() -> Workbench:
	return get_tree().get_first_node_in_group(&"workbench")
