extends VBoxContainer
## PC app: Stockroom. Everything the business uses up, in one list: what is on
## hand, what is on its way, and a rule for each that orders more when it runs
## low. No mock-up existed for this one, so it follows the shop screens.

const SLATE := Color("4A6A8A")
const SLATE_DARK := Color("34506B")
const PAGE := Color("F3F5F8")
const TILE := Color("E4EAF1")
const SHADOW := Color("DAE1EA")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")

var screen: PcScreen

var _scroll: ScrollContainer = null


func refresh() -> void:
	var scrolled := _scroll.scroll_vertical if _scroll != null else 0
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("stockroom", 32, Ui.PAPER, 700),
		Ui.text("What you have, what is coming, and what orders itself.", 15, Ui.PAPER),
	], 24), Ui.box(SLATE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var levels := Game.stock_levels()
	var config: Dictionary = Game.data.settings["supplier"]
	var rows := Ui.vbox([_intro()], 10)
	rows.add_child(_heading("Filament", "Counted in spools with a decent amount left, on the rack or in a printer. Arrives in %s." % GameClock.duration_label(config["filament_lead_minutes"])))
	for key in _spool_keys(levels):
		rows.add_child(_spool_row(key, levels.get(key, {})))
	rows.add_child(_heading("Spare parts", "Counted on the shelving. Arrives in %s." % GameClock.duration_label(config["parts_lead_minutes"])))
	for part_id: String in Game.data.parts:
		if Game.unlocked(Game.data.parts[part_id]):
			rows.add_child(_part_row(part_id, levels.get(Stockroom.part_key(part_id), {})))
	rows.add_child(_heading("Packaging", "One mailer box goes out with every order."))
	rows.add_child(_packaging_row(levels.get(Stockroom.PACKAGING, {})))
	_scroll = Ui.scroll(rows)
	var page := Ui.panel(Ui.margin(_scroll, 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)
	_restore_scroll.call_deferred(scrolled)


func _restore_scroll(at: int) -> void:
	if at == 0:
		return
	# The list has no height to scroll through until it has been laid out.
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


func _intro() -> Control:
	if Game.stock_unlocked():
		return Ui.wrap(Ui.text("Switch on a rule and the stockroom orders for you: when what you have, plus what is already on its way, drops to the level you set, it buys the amount you set. It won't order what you can't afford or have no room for.", 14, Ui.MUTED))
	return Ui.panel(Ui.wrap(Ui.text("Automatic reordering comes with a bigger space: there is more to keep track of in a %s. Until then this is your stock at a glance." % String(
		Game.data.settings["tier_names"][int(Game.data.settings["stock"]["unlock_tier"]) - 1]).to_lower(), 14, LOCK_TEXT, 800)), Ui.box(LOCK_BG, 14, 16, 12))


func _heading(title: String, note: String) -> Control:
	var row := Ui.hbox([Ui.title(title, 20), Ui.text(note, 13, Ui.MUTED)], 14)
	row.custom_minimum_size.y = 40
	return row


## Every kind of spool worth a row: those in stock, on their way or with a
## rule first, then the rest of what the filament shop sells.
func _spool_keys(levels: Dictionary) -> Array[String]:
	var first: Array[String] = []
	var rest: Array[String] = []
	for filament: Dictionary in Game.data.filaments.values():
		if not Game.unlocked(filament) or not FilamentRules.has_a_use(Game.data.products, filament):
			continue
		for colour: String in filament["colours"]:
			var key := Stockroom.spool_key(filament["id"], colour)
			if levels.has(key) or Game.stock.rules.has(key):
				first.append(key)
			else:
				rest.append(key)
	first.append_array(rest)
	return first


func _spool_row(key: String, level: Dictionary) -> Control:
	var spool := key.trim_prefix(Stockroom.SPOOL)
	var material := FilamentRules.material_of(spool)
	var colour := FilamentRules.colour_of(spool)
	var title := "%s %s" % [Palette.display_name(colour), Game.data.filaments[material]["name"]]
	return _row(key, SpoolIcon.create(Palette.colour(colour), 40, Ui.WHITE), title, level, "spool", "spools",
		"%s a spool" % Money.format(Game.supplier.spool_price(material)), 1)


func _part_row(part_id: String, level: Dictionary) -> Control:
	var part: Dictionary = Game.data.parts[part_id]
	var pack := int(part["pack_size"])
	return _row(Stockroom.part_key(part_id), Ui.icon_tile("wrench", 40, 22, TILE, SLATE_DARK, 12), part["name"], level, "pack" if pack > 1 else "one", "packs" if pack > 1 else "",
		"%s %s" % [Money.format(int(part["price_pence"])), "a pack of %d" % pack if pack > 1 else "each"], pack)


func _packaging_row(level: Dictionary) -> Control:
	var config: Dictionary = Game.data.settings["supplier"]
	return _row(Stockroom.PACKAGING, Ui.icon_tile("box", 40, 22, TILE, SLATE_DARK, 12), config["packaging_name"], level, "pack", "packs",
		"%s a pack of %d" % [Money.format(int(config["packaging_pack_pence"])), int(config["packaging_pack_size"])], int(config["packaging_pack_size"]))


## One stock: what there is, and its rule. `unit` and `units` name what is
## ordered ("spool", "spools"); `pack` is how many come in each.
func _row(key: String, picture: Control, title: String, level: Dictionary, unit: String, units: String, price: String, pack: int) -> Control:
	var have := int(level.get("have", 0))
	var coming := int(level.get("coming", 0))
	var rule := Game.stock.rule(key)
	var on: bool = rule["on"]
	var point := int(rule["point"])
	var quantity := int(rule["quantity"])
	var words := Ui.vbox([
		Ui.text(title, 16, Ui.INK, 800),
		Ui.text(price, 13, Ui.MUTED),
	], 0)
	words.custom_minimum_size.x = 250
	var cells: Array = [
		picture, words,
		Ui.width(Ui.pill("In stock: %d" % have, Ui.GREEN_DARK if have > 0 else Ui.MUTED, Ui.GREEN_SOFT if have > 0 else TILE), 110),
		Ui.width(Ui.pill("On the way: %d" % coming, SLATE_DARK, TILE) if coming > 0 else Ui.spacer(), 120),
		null,
	]
	if Game.stock_unlocked():
		var toggle := Ui.button("Reordering" if on else "Reorder for me", _change.bind(key, not on, point, quantity),
			Ui.GREEN if on else Ui.WHITE, Ui.WHITE if on else Ui.INK, 36, 12, Ui.GREEN_DARK if on else SHADOW, 14)
		toggle.custom_minimum_size.x = 150
		toggle.tooltip_text = "Click to stop" if on else "Click to have this ordered when it runs low"
		var amount := "%d %s" % [quantity, unit if quantity == 1 else units] if units != "" else str(quantity)
		if pack > 1:
			amount += " (%d)" % (quantity * pack)
		cells.append_array([
			Ui.text("when down to", 13, Ui.MUTED),
			_stepper(str(point), _change.bind(key, on, point - 1, quantity), _change.bind(key, on, point + 1, quantity), point <= 0),
			Ui.text("order", 13, Ui.MUTED),
			_stepper(amount, _change.bind(key, on, point, quantity - 1), _change.bind(key, on, point, quantity + 1), quantity <= 1),
			toggle,
		])
	return Ui.panel(Ui.hbox(cells, 12), Ui.box(Ui.WHITE, 16, 16, 10, SHADOW, 3))


func _stepper(value: String, fewer: Callable, more: Callable, at_least: bool) -> Control:
	var less := Ui.button("-", fewer, TILE, Ui.INK, 30, 11, Ui.CLEAR, 15)
	less.disabled = at_least
	var label := Ui.text(value, 14, Ui.INK, 800)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 92
	return Ui.hbox([less, label, Ui.button("+", more, TILE, Ui.INK, 30, 11, Ui.CLEAR, 15)], 4)


func _change(key: String, on: bool, point: int, quantity: int) -> void:
	Game.set_stock_rule(key, on, point, quantity)
