extends VBoxContainer
## PC app: Spoolhouse, the filament shop. Spool cards in the middle, materials
## and what is already on the rack on the left, and the basket on the right.

const WARM := Color("FFF1DE")
const WARM_LINE := Color("F0C08C")
const WARM_TEXT := Color("6B5A45")
const DISABLED_LINE := Color("E6DCCB")
const BRAND := "Plainly"

var screen: PcScreen

## Palette colour name -> number of spools wanted.
var _basket: Dictionary = {}
var _search := ""
var _content: MarginContainer = null


func refresh() -> void:
	if _content == null:
		_build()
	Ui.clear(_content)
	_content.add_child(Ui.hbox([_sidebar(), _catalogue(), _basket_card()], 24))


func _build() -> void:
	add_theme_constant_override(&"separation", 0)
	var shop: String = Game.data.settings["supplier"]["filament_shop"]
	var search := LineEdit.new()
	search.placeholder_text = "Search colours"
	search.custom_minimum_size = Vector2(340, 44)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.text_changed.connect(func(typed: String) -> void:
		_search = typed
		refresh.call_deferred())
	var banner := Ui.panel(Ui.hbox([
		Ui.title(shop.to_lower(), 32, Ui.PAPER, 700),
		Ui.text("Filament, by the roll.", 15, Ui.PAPER),
		null, search,
	], 24), Ui.box(Ui.ORANGE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	_content = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right"]:
		_content.add_theme_constant_override(side, 32)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		_content.add_theme_constant_override(side, 24)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)


func _sidebar() -> Control:
	var materials := Ui.vbox([], 8)
	for filament: Dictionary in Game.data.filaments.values():
		var stocked := int(filament["unlock_tier"]) <= 1
		var row := Ui.hbox([
			Ui.text(filament["name"], 15, Ui.PAPER if stocked else Ui.MUTED, 800), null,
			Ui.text("In stock" if stocked else "Coming later", 12, Color(Ui.PAPER, 0.8) if stocked else Ui.MUTED),
		])
		var style := Ui.box(Ui.INK, 14, 14, 0) if stocked else Ui.outlined(Ui.WHITE, DISABLED_LINE, 14, 14, 0)
		var entry := Ui.panel(row, style)
		entry.custom_minimum_size.y = 48
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		materials.add_child(entry)

	var shelf := Ui.vbox([Ui.text("Your rack", 14, Ui.INK, 800)], 4)
	var rack := _rack()
	var low := ""
	for spool in rack.spools():
		shelf.add_child(Ui.text("%s %s · %d g" % [String(spool.material).to_upper(), Palette.display_name(spool.colour), roundi(spool.grams)], 13, Ui.MUTED))
		if spool.grams < Advice.LOW_SPOOL_GRAMS:
			low = "%s is running low" % Palette.display_name(spool.colour)
	if rack.spools().is_empty():
		shelf.add_child(Ui.text("Nothing on it yet.", 13, Ui.MUTED))
	if low != "":
		shelf.add_child(Ui.text(low, 12, Ui.RED, 800))

	var column := Ui.vbox([Ui.title("Material", 18), materials, Ui.panel(shelf, Ui.box(Ui.INSET, 16, 14, 14))], 12)
	column.custom_minimum_size.x = 220
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return column


func _catalogue() -> Control:
	var rack := _rack()
	var coming := 0
	for delivery in Game.supplier.pending:
		coming += delivery.spools.size()
	var room := maxi(rack.free_slots() - coming - _in_basket(), 0)
	var notice := Ui.panel(Ui.hbox([
		Ui.icon("box", 28, Ui.ORANGE_DARK),
		Ui.vbox([
			Ui.text("Room for %d more spool%s on your rack" % [room, "" if room == 1 else "s"], 15, Ui.INK, 800),
			Ui.text("%d of %d slots used, %d on the way. Every spool is 1 kg." % [
				rack.spools().size(), rack.spools().size() + rack.free_slots(), coming], 13, WARM_TEXT),
		], 0),
	], 16), Ui.outlined(WARM, WARM_LINE, 18, 18, 14))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	for colour: String in Game.data.filaments["pla"]["colours"]:
		if _search.strip_edges() == "" or Palette.display_name(colour).containsn(_search.strip_edges()):
			grid.add_child(_spool_card(StringName(colour)))
	var column := Ui.vbox([notice, Ui.scroll(grid)], 16)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column


func _spool_card(colour: StringName) -> Control:
	var picture := Ui.panel(SpoolIcon.create(Palette.colour(colour), 96), Ui.box(Ui.SOFT, 14, 0, 0))
	picture.custom_minimum_size.y = 120
	var card := Ui.card(Ui.vbox([
		picture,
		Ui.hbox([Ui.pill("PLA", Ui.PAPER, Ui.INK), null, Ui.text(BRAND, 12, Ui.MUTED)]),
		Ui.title(Palette.display_name(colour), 17),
		Ui.hbox([
			Ui.text(Money.format(Game.supplier.spool_price(), Money.PRICE), 16, Ui.INK, 800), null,
			Ui.button("Add", _add.bind(String(colour), 1)),
		]),
	], 8), 20, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _basket_card() -> Control:
	var config: Dictionary = Game.data.settings["supplier"]
	var lines := Ui.vbox([], 12)
	for colour: String in _basket:
		var quantity: int = _basket[colour]
		var name_and_count := Ui.vbox([
			Ui.text("PLA %s" % Palette.display_name(colour), 14, Ui.INK, 800),
			Ui.text("Qty %d" % quantity, 12, Ui.MUTED),
		], 0)
		name_and_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove := Ui.button("-", _add.bind(colour, -1), Ui.INSET, Ui.INK, 30, 10)
		remove.tooltip_text = "Take one out"
		lines.add_child(Ui.hbox([
			SpoolIcon.create(Palette.colour(colour), 36, Ui.WHITE), name_and_count, remove,
			Ui.text(Money.format(Game.supplier.spool_price() * quantity), 14, Ui.INK, 800),
		], 12))
	if _basket.is_empty():
		lines.add_child(Ui.text("Nothing in it yet.", 14, Ui.MUTED))

	var order := _order()
	var total := Game.supplier.price_of(order)
	var problem := Game.supplier_problem(order)
	var arrives := GameClock.new()
	arrives.minutes = Game.clock.minutes + float(config["filament_lead_minutes"])
	var minute := int(arrives.minute_of_day)
	var delivery := Ui.panel(Ui.hbox([
		Ui.text("Standard · %s" % GameClock.duration_label(config["filament_lead_minutes"]), 14), null, Ui.text("Free", 14),
	]), Ui.box(Ui.SOFT, 12, 12, 10))

	var column := Ui.vbox([
		Ui.title("Basket", 22), lines,
		Ui.text("Delivery", 14, Ui.INK, 800), delivery,
		Ui.hbox([Ui.title("Total", 22), null, Ui.title(Money.format(total), 22)]),
		Ui.wrap(Ui.text("Arrives day %d at %02d:%02d. Paid from %s." % [
			arrives.day, minute / 60, minute % 60, Game.data.settings["bank_name"]], 12, Ui.MUTED)),
	], 14)
	if total > 0 and problem != "":
		column.add_child(Ui.wrap(Ui.text(problem, 13, Ui.RED, 800)))
	var place := Ui.button("Place order", _place, Ui.ORANGE, Ui.PAPER, 52, 16, Ui.ORANGE_DARK, 19, true)
	place.disabled = problem != ""
	column.add_child(place)

	var card := Ui.card(column, 24, 20)
	card.custom_minimum_size.x = 340
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return card


func _add(colour: String, by: int) -> void:
	var quantity := int(_basket.get(colour, 0)) + by
	if quantity <= 0:
		_basket.erase(colour)
	else:
		_basket[colour] = quantity
	refresh.call_deferred()


func _place() -> void:
	if Game.place_supplier_order(_order(), Game.data.settings["supplier"]["filament_shop"]):
		_basket = {}


func _order() -> Dictionary:
	return {"printers": {}, "spools": _basket, "packaging": 0}


func _in_basket() -> int:
	return Supplier.count_spools(_order())


func _rack() -> FilamentRack:
	return get_tree().get_first_node_in_group(&"filament_rack")
