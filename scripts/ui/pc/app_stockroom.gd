extends VBoxContainer
## PC app: Stockroom. The finished prints on the shelving, with what each lot
## would make if it sold, and then what the business uses up, a tile each:
## what is on hand, what is on its way, and a rule that orders more when it
## runs low. Only what is in stock, coming or set to reorder shows, unless the
## player asks for everything. No mock-up existed for this one, so it follows
## the shop screens.

const SLATE := Color("4A6A8A")
const SLATE_DARK := Color("34506B")
const PAGE := Color("F3F5F8")
const TILE := Color("E4EAF1")
const SHADOW := Color("DAE1EA")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")
const COLUMNS := 5
const PICTURE := 92

## Kept between visits: whether to list what there is none of as well.
static var _everything := false

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
	var spools := _grid()
	for key in _spool_keys(levels):
		if _shown(key, levels):
			spools.add_child(_spool_tile(key, levels.get(key, {})))
	var parts := _grid()
	for part_id: String in Game.data.parts:
		if Game.unlocked(Game.data.parts[part_id]) and _shown(Stockroom.part_key(part_id), levels):
			parts.add_child(_part_tile(part_id, levels.get(Stockroom.part_key(part_id), {})))
	var packaging := _grid()
	for kind: String in Game.data.packaging:
		if Game.unlocked(Game.data.packaging[kind]) and _shown(Stockroom.packaging_key(kind), levels):
			packaging.add_child(_packaging_tile(kind, levels.get(Stockroom.packaging_key(kind), {})))
	var designs := Game.stocked_designs()
	var prints := _grid()
	var sat := 0
	for product in designs:
		prints.add_child(_print_tile(product))
		sat += Game.stock_of(product) * int(Game.best_sale(product)["profit"])
	var worth := Ui.pill("%s of profit sat on the shelf" % Money.format(sat), Ui.GREEN_DARK if sat > 0 else Ui.RED_DARK, Ui.GREEN_SOFT if sat > 0 else Ui.RED_SOFT, 14)
	_scroll = Ui.scroll(Ui.vbox([
		Ui.hbox([Ui.grow(_intro()), _everything_toggle()], 24),
		Ui.hbox([_heading("Finished prints", "On the shelving, ready to pack. Profit is what is left from selling each at its price, after costs and fees."), null,
			worth if not designs.is_empty() else Ui.spacer()], 14),
		_or_nothing(prints, "Nothing printed and waiting. What comes off the printers shows here until it is packed."),
		_heading("Filament", "Counted in spools with a decent amount left, on the rack or in a printer. Arrives in %s." % GameClock.duration_label(config["filament_lead_minutes"])),
		_or_nothing(spools, "No filament in stock or on its way."),
		_heading("Spare parts", "Counted on the shelving. Arrives in %s." % GameClock.duration_label(config["parts_lead_minutes"])),
		_or_nothing(parts, "No spare parts in stock or on their way."),
		_heading("Packaging", "Counted at the packing station. One goes out with every order."),
		_or_nothing(packaging, "No packaging in stock or on its way."),
	], 12))
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


## True if a stock belongs on the page: there is some, some is coming or it
## is set to reorder itself. Everything does once the player asks for it.
func _shown(key: String, levels: Dictionary) -> bool:
	if _everything or Game.stock.rule(key)["on"]:
		return true
	var level: Dictionary = levels.get(key, {})
	return int(level.get("have", 0)) > 0 or int(level.get("coming", 0)) > 0


func _everything_toggle() -> Control:
	var flip := func() -> void:
		_everything = not _everything
		refresh()
	var button := Ui.button("Showing everything" if _everything else "Showing what is in stock", flip,
		SLATE if _everything else Ui.WHITE, Ui.PAPER if _everything else Ui.INK, 40, 14, SLATE_DARK if _everything else SHADOW)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = "Click to list only what you have, what is coming and what reorders itself" if _everything \
		else "Click to list everything you could stock, to set it reordering"
	return button


## A section's tiles, or a line saying there are none.
func _or_nothing(grid: GridContainer, note: String) -> Control:
	if grid.get_child_count() > 0:
		return grid
	grid.queue_free()
	return Ui.panel(Ui.text(note, 14, Ui.MUTED), Ui.box(TILE, 14, 16, 12))


## The finished prints of one design: how many, how many are spoken for, and
## what the lot would leave if it sold.
func _print_tile(product: StringName) -> Control:
	var count := Game.stock_of(product)
	var sale := Game.best_sale(product)
	var shop: Marketplace = sale["shop"]
	var profit: int = sale["profit"]
	var ordered := Game.open_orders().filter(func(order: Marketplace.Order) -> bool: return order.product == product).size()
	var backdrop := Ui.panel(ModelPicture.of_product(product, PICTURE), Ui.box(TILE, 14, 0, 0))
	backdrop.custom_minimum_size.y = PICTURE + 16
	var name_line := Ui.text(Game.product_name(product), 16, Ui.INK, 800)
	name_line.clip_text = true
	name_line.tooltip_text = Game.product_name(product)
	name_line.mouse_filter = Control.MOUSE_FILTER_PASS
	var counts := Ui.hbox([Ui.pill("In stock: %d" % count, Ui.GREEN_DARK, Ui.GREEN_SOFT)], 6)
	if ordered > 0:
		counts.add_child(Ui.pill("Ordered: %d" % ordered, SLATE_DARK, TILE))
	var where := "%s on %s" % [Money.format(sale["price"]), shop.config["name"]] if sale["listed"] else "Not listed: %s if it were" % Money.format(sale["price"])
	var column := Ui.vbox([
		backdrop,
		Ui.vbox([name_line, Ui.text(where, 13, Ui.MUTED if sale["listed"] else Ui.AMBER_DARK)], 0),
		counts,
		Ui.hbox([Ui.text("Profit each", 13, Ui.MUTED), null, Ui.text(Money.format(profit), 14, Ui.INK, 800)]),
		Ui.hbox([Ui.text("Sat on the shelf", 13, Ui.MUTED), null,
			Ui.title(Money.format(profit * count), 18, Ui.GREEN_DARK if profit > 0 else Ui.RED_DARK)]),
	], 10)
	var card := Ui.panel(column, Ui.box(Ui.WHITE, 18, 14, 14, SHADOW, 3))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	return grid


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


func _spool_tile(key: String, level: Dictionary) -> Control:
	var spool := key.trim_prefix(Stockroom.SPOOL)
	var material := FilamentRules.material_of(spool)
	var colour := FilamentRules.colour_of(spool)
	var title := "%s %s" % [Palette.display_name(colour), Game.data.filaments[material]["name"]]
	return _tile(key, ModelPicture.of_spool(StringName(colour), PICTURE), title, level, "spool", "spools",
		"%s a spool" % Money.format(Game.supplier.spool_price(material)), 1)


func _part_tile(part_id: String, level: Dictionary) -> Control:
	var part: Dictionary = Game.data.parts[part_id]
	var pack := int(part["pack_size"])
	return _tile(Stockroom.part_key(part_id), ModelPicture.create(GameData.part_model(part), PICTURE), part["name"], level, "pack" if pack > 1 else "one", "packs" if pack > 1 else "",
		"%s %s" % [Money.format(int(part["price_pence"])), "a pack of %d" % pack if pack > 1 else "each"], pack)


func _packaging_tile(kind: String, level: Dictionary) -> Control:
	var wrap: Dictionary = Game.data.packaging[kind]
	return _tile(Stockroom.packaging_key(kind), ModelPicture.create(GameData.PACKAGING_MODEL % wrap["model"], PICTURE), wrap["name"], level, "pack", "packs",
		"%s a pack of %d" % [Money.format(int(wrap["price_pence"])), int(wrap["pack_size"])], int(wrap["pack_size"]))


## One stock: what there is, and its rule. `unit` and `units` name what is
## ordered ("spool", "spools"); `pack` is how many come in each.
func _tile(key: String, picture: Control, title: String, level: Dictionary, unit: String, units: String, price: String, pack: int) -> Control:
	var have := int(level.get("have", 0))
	var coming := int(level.get("coming", 0))
	var rule := Game.stock.rule(key)
	var on: bool = rule["on"]
	var point := int(rule["point"])
	var quantity := int(rule["quantity"])
	var backdrop := Ui.panel(picture, Ui.box(TILE, 14, 0, 0))
	backdrop.custom_minimum_size.y = PICTURE + 16
	var name_line := Ui.text(title, 16, Ui.INK, 800)
	name_line.clip_text = true
	name_line.tooltip_text = title
	name_line.mouse_filter = Control.MOUSE_FILTER_PASS
	var counts := Ui.hbox([Ui.pill("In stock: %d" % have, Ui.GREEN_DARK if have > 0 else Ui.MUTED, Ui.GREEN_SOFT if have > 0 else TILE)], 6)
	if coming > 0:
		counts.add_child(Ui.pill("On the way: %d" % coming, SLATE_DARK, TILE))
	var column := Ui.vbox([backdrop, Ui.vbox([name_line, Ui.text(price, 13, Ui.MUTED)], 0), counts], 10)
	if Game.stock_unlocked():
		var toggle := Ui.button("Reordering" if on else "Reorder for me", _change.bind(key, not on, point, quantity),
			Ui.GREEN if on else Ui.WHITE, Ui.WHITE if on else Ui.INK, 36, 12, Ui.GREEN_DARK if on else SHADOW, 14)
		toggle.tooltip_text = "Click to stop" if on else "Click to have this ordered when it runs low"
		var amount := "%d %s" % [quantity, unit if quantity == 1 else units] if units != "" else str(quantity)
		if pack > 1:
			amount += " (%d)" % (quantity * pack)
		column.add_child(Ui.hbox([
			Ui.text("When down to", 13, Ui.MUTED), null,
			_stepper(str(point), _change.bind(key, on, point - 1, quantity), _change.bind(key, on, point + 1, quantity), point <= 0),
		]))
		column.add_child(Ui.hbox([
			Ui.text("Order", 13, Ui.MUTED), null,
			_stepper(amount, _change.bind(key, on, point, quantity - 1), _change.bind(key, on, point, quantity + 1), quantity <= 1),
		]))
		column.add_child(toggle)
	var card := Ui.panel(column, Ui.box(Ui.WHITE, 18, 14, 14, SHADOW, 3))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _stepper(value: String, fewer: Callable, more: Callable, at_least: bool) -> Control:
	var less := Ui.button("-", fewer, TILE, Ui.INK, 30, 11, Ui.CLEAR, 15)
	less.disabled = at_least
	var label := Ui.text(value, 14, Ui.INK, 800)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 78
	return Ui.hbox([less, label, Ui.button("+", more, TILE, Ui.INK, 30, 11, Ui.CLEAR, 15)], 4)


func _change(key: String, on: bool, point: int, quantity: int) -> void:
	Game.set_stock_rule(key, on, point, quantity)
