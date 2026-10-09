extends VBoxContainer
## PC app: Design Lab, the catalogue of designs to license. No mock-up existed
## for this one, so it follows the shop screens: a banner, then a card per design.

const PURPLE := Color("7A5BC4")
const PURPLE_DARK := Color("573F92")
const TILE := Color("EFEAF8")
const SHADOW := Color("E2DCF0")
const FACT_BG := Color("EFEAF8")
const FACT_TEXT := Color("573F92")

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("design lab", 32, Ui.PAPER, 700),
		Ui.text("Buy a design once, print as many as you like.", 15, Ui.PAPER),
	], 24), Ui.box(PURPLE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	for product: String in Game.data.products:
		grid.add_child(_card(StringName(product), Game.data.products[product]))
	var page := Ui.margin(Ui.scroll(grid), 32, 24, 32, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _card(product: StringName, row: Dictionary) -> Control:
	var licence: Dictionary = row["licence"]
	var fee := int(licence["fee_pence"])
	var royalty := float(licence["royalty_pct"])
	var facts := Ui.hbox([
		Ui.pill(GameClock.duration_label(row["print_minutes"]), FACT_TEXT, FACT_BG),
		Ui.pill("%d g" % row["filament_grams"], FACT_TEXT, FACT_BG),
		Ui.pill("Sells for about %s" % Money.format(int(row["base_price_pence"])), FACT_TEXT, FACT_BG),
	], 6)
	var column := Ui.vbox([
		Ui.hbox([Ui.icon_tile("design_lab", 52, 28, TILE, PURPLE_DARK), Ui.title(row["name"], 20)], 14),
		Ui.wrap(Ui.text(row["description"], 13, Ui.MUTED)),
		facts,
	], 12)
	if royalty > 0.0:
		column.add_child(Ui.text("The designer takes %d%% of each sale" % roundi(royalty * 100.0), 13, Ui.AMBER_DARK, 800))

	var action: Control
	if Game.owns(product):
		action = Ui.pill("Owned", Ui.GREEN_DARK, Ui.GREEN_SOFT, 14)
	else:
		var buy := Ui.button("Get it" if fee == 0 else "Buy", func() -> void: Game.buy_design(product), PURPLE, Ui.WHITE, 44, 14, PURPLE_DARK, 15)
		buy.disabled = not Game.bank.can_afford(fee)
		action = buy
	column.add_child(Ui.spacer())
	column.add_child(Ui.hbox([Ui.title("Free" if fee == 0 else Money.format(fee), 22), null, action]))
	var card := Ui.card(column, 22, 18, SHADOW)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card
