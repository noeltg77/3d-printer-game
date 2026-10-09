extends VBoxContainer
## PC app: Printbay, for printers and other hardware. A card per printer with
## stat bars, plus tabs for packaging and (later) upgrades and spare parts.

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
const TABS := {"printers": "Printers", "packaging": "Packaging", "upgrades": "Upgrades", "parts": "Spare parts"}
const MOTIONS := {"bed_slinger": "Bed slinger", "core_xy": "Core XY"}
## Speed multiplier and build volume (litres) that fill a stat bar completely.
const FULL_SPEED := 3.0
const FULL_VOLUME := 40.0

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
		_:
			page = _coming_later()
	var body := Ui.panel(Ui.margin(page, 40, 28, 40, 28), Ui.box(PAGE, 0, 0, 0))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)


func _header() -> Control:
	var bench := _bench()
	var spots := bench.free_spots() + get_tree().get_nodes_in_group(&"printer").size()
	var tier := Ui.panel(Ui.text("Your tier: Garage · Space for %d printers" % spots, 14, PAGE, 800), Ui.box(NAVY_SOFT, 12, 14, 8))
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
	var picture := Ui.panel(PrinterIcon.create(spec["shop_colours"], 120), Ui.box(TILE, 16, 0, 0))
	picture.custom_minimum_size.y = 150
	var size: Array = spec["build_volume_mm"]
	var litres := float(size[0]) * float(size[1]) * float(size[2]) / 1000000.0
	var materials: PackedStringArray = []
	for filament_id: String in spec["supported_filaments"]:
		materials.append(Game.data.filaments[filament_id]["name"])

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

	var order := {"printers": {printer_id: 1}}
	var problem := "Unlocks when you move to a bigger space" if int(spec["unlock_tier"]) > 1 else Game.supplier_problem(order)
	if problem != "":
		column.add_child(Ui.panel(Ui.wrap(Ui.text(problem, 13, LOCK_TEXT, 800)), Ui.box(LOCK_BG, 12, 12, 10)))
	column.add_child(Ui.hbox([
		Ui.title(Money.text(int(spec["price_cents"])), 22), null,
		_disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14, BLUE_DARK, 15), problem != ""),
	]))
	var card := Ui.card(column, 22, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _stat(label: String, value: float, colour: Color) -> Control:
	return Ui.hbox([Ui.width(Ui.text(label, 13), 76), Ui.bar(value, colour, TILE)], 10)


func _packaging() -> Control:
	var config: Dictionary = Game.data.settings["supplier"]
	var low := Game.packaging <= Advice.LOW_PACKAGING
	var order := {"packaging": 1}
	var problem := Game.supplier_problem(order)
	var words := Ui.vbox([
		Ui.text("%s, pack of %d" % [config["packaging_name"], config["packaging_pack_size"]], 16, Ui.INK, 800),
		Ui.text("One is used for every order you pack. Arrives in %s." % GameClock.duration_label(config["filament_lead_minutes"]), 13, Ui.MUTED),
	], 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := Ui.panel(Ui.hbox([
		Ui.icon_tile("box", 52, 26, TILE, NAVY),
		words,
		Ui.pill("In stock: %d" % Game.packaging, Ui.RED_DARK if low else Ui.GREEN_DARK, Ui.RED_SOFT if low else Ui.GREEN_SOFT),
		Ui.width(Ui.text(Money.text(int(config["packaging_pack_cents"])), 17, Ui.INK, 800), 70),
		_disabled_if(Ui.button("Buy", _buy.bind(order), BLUE, Ui.WHITE, 44, 14), problem != ""),
	], 18), Ui.box(Ui.WHITE, 18, 18, 14, SHADOW, 3))
	var column := Ui.vbox([row], 12)
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return column


func _coming_later() -> Control:
	var words := Ui.vbox([
		Ui.title("Nothing on these shelves yet", 20),
		Ui.wrap(Ui.text("Nozzles, belts, build plates and upgrades arrive once printers start wearing out and breaking down.", 14, Ui.MUTED)),
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
