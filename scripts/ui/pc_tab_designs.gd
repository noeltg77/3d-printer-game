extends VBoxContainer
## PC tab: the design catalogue. Buy a licence to be able to print and sell a design.


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 14)
	add_child(Ui.note("Buy a design once and print as many as you like."))
	for product: String in Game.data.products:
		add_child(_card(StringName(product), Game.data.products[product]))


func _card(product: StringName, row: Dictionary) -> Control:
	var licence: Dictionary = row["licence"]
	var fee := int(licence["fee_cents"])
	var terms := ""
	if float(licence["royalty_pct"]) > 0.0:
		terms = "Designer takes %d%% of each sale" % roundi(float(licence["royalty_pct"]) * 100.0)

	var facts := "Prints in %s  |  Uses %d g  |  Sells for about %s" % [
		GameClock.duration_label(row["print_minutes"]), row["filament_grams"], Money.text(int(row["base_price_cents"]))]
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Ui.heading(row["name"]))
	text.add_child(Ui.label(row["description"], 16, Ui.MUTED))
	text.add_child(Ui.label(facts))

	var action: Control
	if Game.owns(product):
		action = Ui.label("Owned", 16, Ui.GOOD)
	else:
		var label := "Get it" if fee == 0 else "Buy for %s" % Money.text(fee)
		action = Ui.button(label, func() -> void: Game.buy_design(product), Game.bank.can_afford(fee))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.row([text, Ui.label(terms, 16, Ui.MUTED), action], 20)
