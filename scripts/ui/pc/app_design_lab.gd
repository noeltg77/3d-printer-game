extends VBoxContainer
## PC app: Design Lab, the catalogue of designs to license, and where the
## business makes its own versions of them. No mock-up existed for this one, so
## it follows the shop screens: a banner with a search box, categories down the
## left and a card per matching design. A design none of the business's
## printers can print says so on its card, and can be left out of the list.

const PURPLE := Color("7A5BC4")
const PURPLE_DARK := Color("573F92")
const TILE := Color("EFEAF8")
const SHADOW := Color("E2DCF0")
const FACT_BG := Color("EFEAF8")
const FACT_TEXT := Color("573F92")

const ALL := ""
## Stands in for a category: only the business's own designs.
const OWN := "__own"
const STAR := Color("E0A526")

var screen: PcScreen

## Category id being shown, or ALL.
var _category := ALL
var _search := ""
## Whether designs the business's printers can't print are left out.
var _printable_only := false
## Product id -> why it can't be printed ("" if it can), worked out afresh each refresh.
var _problems: Dictionary[StringName, String] = {}
var _printers: Array[Dictionary] = []
var _content: MarginContainer = null
var _categories_scroll: ScrollContainer = null
var _designs_scroll: ScrollContainer = null


func refresh() -> void:
	if _content == null:
		_build()
	# A refresh rebuilds both lists, so put them back where the player had scrolled to.
	var categories_at := _categories_scroll.scroll_vertical if _categories_scroll != null else 0
	var designs_at := _designs_scroll.scroll_vertical if _designs_scroll != null else 0
	_problems.clear()
	_printers = Game.printer_specs()
	Ui.clear(_content)
	_content.add_child(Ui.hbox([_sidebar(), _catalogue()], 24))
	_restore_scroll.call_deferred(_categories_scroll, categories_at)
	_restore_scroll.call_deferred(_designs_scroll, designs_at)


func _build() -> void:
	add_theme_constant_override(&"separation", 0)
	var search := LineEdit.new()
	search.placeholder_text = "Search designs"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(340, 44)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.text_changed.connect(func(typed: String) -> void:
		_search = typed
		_show_from_top())
	var banner := Ui.panel(Ui.hbox([
		Ui.title("design lab", 32, Ui.PAPER, 700),
		Ui.text("Buy a design once, print as many as you like.", 15, Ui.PAPER),
		null, search,
	], 24), Ui.box(PURPLE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	_content = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right"]:
		_content.add_theme_constant_override(side, 32)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		_content.add_theme_constant_override(side, 24)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)


## True if a design belongs in the list for this category and search text.
## The search looks in the design's name and its category.
static func matches(row: Dictionary, category: String, search: String) -> bool:
	# A design a client supplies with a contract isn't for sale.
	if row.get("contract_only", false):
		return false
	if category == OWN and not Game.studio.has(StringName(row["id"])):
		return false
	if category != ALL and category != OWN and row["category"] != category:
		return false
	var wanted := search.strip_edges()
	return wanted == "" or String(row["name"]).containsn(wanted) or category_label(row).containsn(wanted)


## True if a design is shown at all. Designs for a later tier are held back until
## the business has moved, unless the player already has them.
static func offered(row: Dictionary) -> bool:
	var product := StringName(row["id"])
	return Game.unlocked(row) or Game.owns(product) or Game.studio.has(product)


## The category as shown to the player.
static func category_label(row: Dictionary) -> String:
	if row.has("category_name"):
		return row["category_name"]
	var words := String(row["category"]).replace("_", " ")
	return words.left(1).to_upper() + words.substr(1)


func _sidebar() -> Control:
	# Categories in catalogue order, each with how many designs match the search.
	var names := {}
	var counts := {}
	var total := 0
	for row: Dictionary in Game.data.products.values():
		var category: String = row["category"]
		if not offered(row):
			continue
		if not names.has(category):
			names[category] = category_label(row)
			counts[category] = 0
		if _shown(row, ALL):
			counts[category] += 1
			total += 1
	var own := 0
	for product in Game.studio.designs:
		own += 1 if _shown(Game.data.products[product], OWN) else 0
	var list := Ui.vbox([_category_button(ALL, "All designs", total), _category_button(OWN, "Your own designs", own)], 6)
	for category: String in names:
		list.add_child(_category_button(category, names[category], counts[category]))
	_categories_scroll = Ui.scroll(list)
	var column := Ui.vbox([_printable_toggle(), Ui.title("Category", 18), _categories_scroll], 12)
	column.custom_minimum_size.x = 260
	return column


## Why none of the business's printers can print a design, or "" if one can.
func _problem(product: StringName) -> String:
	if not _problems.has(product):
		_problems[product] = FilamentRules.design_problem(_printers, Game.data.products[product], Game.data.filaments)
	return _problems[product]


## True if a design is in the list as it stands: it matches the category and
## search, and can be printed if only printable designs are wanted.
func _shown(row: Dictionary, category: String) -> bool:
	return matches(row, category, _search) and not (_printable_only and _problem(StringName(row["id"])) != "")


## The switch that leaves out what the business's printers can't print.
func _printable_toggle() -> Control:
	var flip := func() -> void:
		_printable_only = not _printable_only
		_show_from_top()
	var button := Ui.button("Only what I can print: %s" % ("on" if _printable_only else "off"), flip,
		PURPLE if _printable_only else Ui.WHITE, Ui.PAPER if _printable_only else Ui.INK, 44, 14, PURPLE_DARK if _printable_only else SHADOW)
	button.tooltip_text = "Leaves out designs that are too big for your printers, or need a material none of them can print."
	button.disabled = _printers.is_empty()
	if _printers.is_empty():
		button.tooltip_text = "You need a printer first."
	return button


func _category_button(category: String, label: String, count: int) -> Button:
	var chosen := category == _category
	var choose := func() -> void:
		_category = category
		_show_from_top()
	var text_colour := Ui.PAPER if chosen else (Ui.INK if count > 0 else Ui.MUTED)
	var entry := Ui.button("%s · %d" % [label, count], choose, PURPLE if chosen else Ui.WHITE, text_colour, 40, 14,
		PURPLE_DARK if chosen else SHADOW)
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.clip_text = true
	return entry


func _catalogue() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	var held_back := 0
	for product: String in Game.data.products:
		var row: Dictionary = Game.data.products[product]
		if not _shown(row, _category):
			continue
		if offered(row):
			grid.add_child(_card(StringName(product), row))
		else:
			held_back += 1
	var later := "%d more design%s here once you move to a bigger space." % [held_back, "" if held_back == 1 else "s"]
	if grid.get_child_count() == 0:
		grid.free()
		_designs_scroll = null
		var nothing := Ui.card(Ui.vbox([
			Ui.title("No designs match" if held_back == 0 else "Nothing here yet", 20),
			Ui.text(("Try a different search, pick All designs, or turn off Only what I can print." if _printable_only
				else "Try a different search, or pick All designs.") if held_back == 0 else later, 14, Ui.MUTED),
		], 6), 22, 24, SHADOW)
		nothing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nothing.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return nothing
	var page := Ui.vbox([grid], 20)
	if held_back > 0:
		page.add_child(Ui.panel(Ui.hbox([Ui.icon("box", 24, PURPLE_DARK), Ui.text(later, 14, PURPLE_DARK, 800)], 12), Ui.box(TILE, 16, 18, 14)))
	_designs_scroll = Ui.scroll(page)
	return _designs_scroll


## Redraws after the category or search changed, starting from the top of the list.
func _show_from_top() -> void:
	_designs_scroll = null
	refresh.call_deferred()


func _restore_scroll(scroller: ScrollContainer, at: int) -> void:
	if at == 0:
		return
	# The list has no height to scroll through until it has been laid out.
	await get_tree().process_frame
	if is_instance_valid(scroller):
		scroller.scroll_vertical = at


func _card(product: StringName, row: Dictionary) -> Control:
	var licence: Dictionary = row["licence"]
	var fee := int(licence["fee_pence"])
	var royalty := float(licence["royalty_pct"])
	# The facts wrap onto a second line when there are too many for the card.
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override(&"h_separation", 6)
	facts.add_theme_constant_override(&"v_separation", 6)
	for fact: Control in [
		Ui.pill(GameClock.duration_label(row["print_minutes"]), FACT_TEXT, FACT_BG),
		Ui.pill("%d g" % row["filament_grams"], FACT_TEXT, FACT_BG),
		Ui.pill("Sells for about %s" % Money.format(int(row["base_price_pence"])), FACT_TEXT, FACT_BG),
	]:
		facts.add_child(fact)
	var column := Ui.vbox([
		Ui.hbox([Ui.panel(ModelPicture.of_product(product, 84), Ui.box(TILE, 14, 4, 4)), Ui.wrap(Ui.title(row["name"], 20))], 14),
		Ui.wrap(Ui.text(row["description"], 13, Ui.MUTED)),
		facts,
	], 12)
	var problem := _problem(product)
	if problem != "":
		facts.add_child(Ui.pill("Can't print it yet", Ui.RED_DARK, Ui.RED_SOFT))
		facts.move_child(facts.get_child(-1), 0)
		column.add_child(Ui.wrap(Ui.text("None of your printers can print this. %s." % problem, 13, Ui.RED_DARK, 800)))
	if royalty > 0.0 and not Game.studio.has(product):
		column.add_child(Ui.text("The designer takes %d%% of each sale" % roundi(royalty * 100.0), 13, Ui.AMBER_DARK, 800))
	var colours := Multicolour.colours_of(row)
	if colours > 1:
		facts.add_child(Ui.pill("%d colours" % colours, FACT_TEXT, FACT_BG))
		column.add_child(Ui.wrap(Ui.text("Needs a printer with a multicolour unit to print in all %d colours. In one colour it sells for %d%% less." % [
			colours, roundi((1.0 - float(Game.data.toggles["multicolour"]["off_price_multiplier"])) * 100.0)], 13, Ui.AMBER_DARK, 800)))

	if Game.storage.is_bin(product):
		column.add_child(Ui.wrap(Ui.text("Use it in your own workshop: on the shelving it holds %s in one space. Or sell it like anything else." % Game.storage.bin_summary(product), 13, Ui.GREEN_DARK, 800)))
	column.add_child(_own_design(product))
	var action: Control
	if Game.studio.has(product):
		action = Ui.pill("Your own design", Ui.GREEN_DARK, Ui.GREEN_SOFT, 14)
	elif Game.owns(product):
		action = Ui.pill("Owned", Ui.GREEN_DARK, Ui.GREEN_SOFT, 14)
	else:
		# Still for sale to a business that can't print it: the printer may be next on the list.
		var buy := Ui.button("Get it" if fee == 0 else "Buy", func() -> void: Game.buy_design(product), PURPLE, Ui.WHITE, 44, 14, PURPLE_DARK, 15)
		if problem != "":
			buy = Ui.button("Buy anyway", func() -> void: Game.buy_design(product), Ui.WHITE, PURPLE_DARK, 44, 14, SHADOW, 15)
		buy.disabled = not Game.bank.can_afford(fee)
		action = buy
	column.add_child(Ui.spacer())
	column.add_child(Ui.hbox([Ui.title("No fee" if Game.studio.has(product) else ("Free" if fee == 0 else Money.format(fee)), 22), null, action]))
	var card := Ui.card(column, 22, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


## The part of a card about the business's own version of the design: how
## good it is and the next thing to do to it, or the offer to make one.
func _own_design(product: StringName) -> Control:
	var studio := Game.studio
	var computer: Computer = get_tree().get_first_node_in_group(&"computer")
	var rows := Ui.vbox([], 8)
	if not studio.has(product):
		if not Game.design_unlocked():
			rows.add_child(Ui.text("Design your own once you have a bigger space", 13, Ui.MUTED))
			return rows
		rows.add_child(Ui.wrap(Ui.text("Or make your own: no fee and no royalty, but %s at the PC. It would come out at quality %d of %d." % [
			GameClock.duration_label(studio.minutes_for(product)), studio.next_quality(product), int(Game.data.settings["design"]["max_quality"])], 13, Ui.MUTED)))
		rows.add_child(_task_button("Design your own", computer.design_action(product)))
		return rows
	var record := studio.designs[product]
	var selling := roundi((studio.appeal(product) - 1.0) * 100.0)
	rows.add_child(Ui.hbox([
		Ui.pill("V%d" % record["version"], Ui.PAPER, PURPLE_DARK, 13),
		Ui.pips(int(record["quality"]), int(Game.data.settings["design"]["max_quality"]), STAR),
		Ui.text("Sells as well as the bought one" if selling == 0 else "%d%% %s orders than the bought one" % [absi(selling), "more" if selling > 0 else "fewer"], 13, Ui.MUTED),
	], 10))
	if studio.needs_fix(product):
		rows.add_child(Ui.text("The test print found a fault. Prints come out flawed until it is fixed.", 13, Ui.RED_DARK, 800))
		rows.add_child(_task_button("Fix it (%s)" % GameClock.duration_label(studio.fix_minutes()), computer.fix_action(product)))
	elif not record["tested"]:
		rows.add_child(Ui.text("Not tested yet. Print one before you rely on it.", 13, Ui.AMBER_DARK, 800))
	if studio.can_improve(product) and not studio.needs_fix(product):
		rows.add_child(_task_button("Improve to V%d (%s)" % [record["version"] + 1, GameClock.duration_label(studio.minutes_for(product))],
			computer.design_action(product)))
	return rows


## A button that queues a job at the desk and leaves the PC so it can start.
func _task_button(label: String, action: Action) -> Button:
	var button := Ui.button(label, func() -> void:
		(get_tree().get_first_node_in_group(&"player") as Agent).enqueue(action)
		screen.close(), Ui.WHITE, PURPLE_DARK, 38, 12, SHADOW, 14)
	button.disabled = not action.enabled
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return button
