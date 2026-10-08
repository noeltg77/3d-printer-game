extends VBoxContainer
## PC tab: the marketplace. Set a price and list each owned design, and see the
## orders that need printing, packing or are waiting for the courier.

const PRICE_STEP := 50


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 8)
	var market := Game.market
	var courier := int(Game.data.settings["courier_minute_of_day"])
	add_child(Ui.note("%s takes %.1f%% + %s of each sale. Pack orders at the workbench; the courier collects at %02d:%02d and that is when you are paid." % [
		market.config["name"], float(market.config["fee_pct"]) * 100.0,
		Money.text(int(market.config["fee_fixed_cents"])), courier / 60, courier % 60]))

	add_child(Ui.heading("Your listings"))
	add_child(Ui.row([Ui.cell("Design", 230, Ui.MUTED), Ui.cell("In stock", 80, Ui.MUTED), Ui.cell("Sold", 60, Ui.MUTED),
		Ui.cell("Price", 150, Ui.MUTED), Ui.cell("Expected sales", 150, Ui.MUTED)]))
	for product in Game.owned_designs:
		add_child(_listing_row(product))

	add_child(HSeparator.new())
	add_child(Ui.heading("Orders"))
	var orders := market.active_orders()
	if orders.is_empty():
		add_child(Ui.label("No orders waiting. Listed designs bring them in.", 16, Ui.MUTED))
	# Stock is shared out oldest order first, so one item only makes one order ready.
	var unclaimed: Dictionary[StringName, int] = {}
	for order in orders:
		if not unclaimed.has(order.product):
			unclaimed[order.product] = Game.stock_of(order.product)
		var in_stock := order.status == Marketplace.Status.OPEN and unclaimed[order.product] > 0
		if in_stock:
			unclaimed[order.product] -= 1
		add_child(_order_row(order, in_stock))


func _listing_row(product: StringName) -> Control:
	var market := Game.market
	var entry := market.listing(product)
	var price: int = entry["price"]
	var listed: bool = entry["listed"]
	var typical := int(Game.data.products[product]["base_price_cents"])
	var note := "typical %s" % Money.text(typical)
	var rate := "%.1f a day" % market.orders_per_day(product, price) if listed else "not listed"
	return Ui.row([
		Ui.cell(Game.product_name(product), 230),
		Ui.cell(str(Game.stock_of(product)), 80),
		Ui.cell(str(entry["sold"]), 60),
		Ui.row([
			Ui.button("-", _update_listing.bind(product, listed, price - PRICE_STEP), price > PRICE_STEP),
			Ui.cell(Money.text(price), 64),
			Ui.button("+", _update_listing.bind(product, listed, price + PRICE_STEP)),
		], 4),
		Ui.cell(rate, 110, Color.WHITE if listed else Ui.MUTED),
		Ui.label(note, 14, Ui.MUTED),
		null,
		Ui.button("Take down" if listed else "List for sale", _update_listing.bind(product, not listed, price)),
	])


func _order_row(order: Marketplace.Order, in_stock: bool) -> Control:
	var status := "Packed, waiting for the courier"
	var colour := Ui.GOOD
	if order.status == Marketplace.Status.OPEN:
		status = "Ready to pack" if in_stock else "Needs printing"
		colour = Color.WHITE if in_stock else Ui.BAD
	return Ui.row([
		Ui.cell("#%d" % order.id, 50, Ui.MUTED),
		Ui.cell(Game.product_name(order.product), 230),
		Ui.cell(Money.text(order.price), 80),
		Ui.cell("due in %s" % GameClock.duration_label(order.due_at - Game.clock.minutes), 150, Ui.MUTED),
		Ui.label(status, 16, colour),
	])


func _update_listing(product: StringName, listed: bool, price: int) -> void:
	Game.market.set_listing(product, listed, price)
	Game.changed.emit()
