extends VBoxContainer
## PC app: the marketplace seller dashboard. Headline numbers along the top,
## orders to pack and the listings table on the left, recent sales on the right.
## "Pack & ship" queues the packing job for the character.

const ROSE := Color("C9415F")
const ROSE_DARK := Color("962E46")
const SHADOW := Color("F0DCD6")
const ROW := Color("FCF5F3")
const LABEL := Color("6E5E62")
const DONE_BG := Color("E7DEDB")
const TIP_BG := Color("EAF3EE")
const PRICE_STEP := 50
const RECENT_SALES := 6
## Listings table column widths, as shares of the row.
const COLUMNS: Array[float] = [2.2, 1.5, 1.0, 1.0, 0.7, 1.9]

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var market := Game.market
	var header := Ui.hbox([
		Ui.title(String(market.config["name"]).to_lower(), 32, ROSE, 700),
		Ui.title("%s · Seller dashboard" % Game.data.settings["business_name"], 22),
		null,
		Ui.button("+ More designs", func() -> void: screen.show_app("design_lab"), ROSE, Ui.WHITE, 46, 14, ROSE_DARK, 15),
	], 16)

	var left := Ui.vbox([_orders_card(), _listings_card()], 20)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lower := Ui.hbox([Ui.scroll(left), _sales_card()], 20)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page := Ui.margin(Ui.vbox([header, _stats(), lower], 20), 40, 24, 40, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _stats() -> Control:
	var market := Game.market
	var today_start := float(Game.clock.day - 1) * GameClock.DAY
	var sold_today := 0
	var takings := 0
	for order in market.orders:
		if order.status == Marketplace.Status.SHIPPED and order.shipped_at >= today_start:
			sold_today += 1
			takings += order.price
	var open := market.open_orders()
	var due_today := open.filter(func(order: Marketplace.Order) -> bool: return order.due_at < today_start + GameClock.DAY).size()
	var parcels := market.active_orders().size() - open.size()
	var courier := int(Game.data.settings["courier_minute_of_day"])
	var low := Game.packaging <= Advice.LOW_PACKAGING

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_child(_stat("Sales today", Money.format(takings), "%d sold today" % sold_today, Ui.GREEN_DARK))
	grid.add_child(_stat("To ship", "%d order%s" % [open.size(), "" if open.size() == 1 else "s"],
		"%d due today" % due_today if due_today > 0 else "Nothing due today", Ui.RED_DARK if due_today > 0 else Ui.GREEN_DARK))
	grid.add_child(_stat("Mailer boxes", "%d left" % Game.packaging,
		"Order more from %s" % Game.data.settings["supplier"]["hardware_shop"] if low else "One for every order",
		Ui.RED_DARK if low else LABEL))
	grid.add_child(_stat("Courier", "%02d:%02d" % [courier / 60, courier % 60],
		"%d parcel%s waiting to go" % [parcels, "" if parcels == 1 else "s"], Ui.GREEN_DARK if parcels > 0 else LABEL))
	return grid


func _stat(label: String, value: String, note: String, note_colour: Color) -> Control:
	var card := Ui.panel(Ui.vbox([
		Ui.text(label, 13, LABEL, 800), Ui.title(value, 30), Ui.text(note, 13, note_colour, 800),
	], 2), Ui.box(Ui.WHITE, 20, 20, 16, SHADOW, 4))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _orders_card() -> Control:
	var rows := Ui.vbox([], 10)
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	var queued := agent.get_queued_labels()
	# Stock is shared out oldest order first, so one item only makes one order ready.
	var unclaimed: Dictionary[StringName, int] = {}
	for order in Game.market.active_orders():
		if not unclaimed.has(order.product):
			unclaimed[order.product] = Game.stock_of(order.product)
		var status := "Packed"
		var pill := Ui.pill(status, Ui.GREEN_DARK, Ui.GREEN_SOFT)
		var action := Ui.button("Done", Callable(), DONE_BG, LABEL)
		action.disabled = true
		if order.status == Marketplace.Status.OPEN:
			var in_stock := unclaimed[order.product] > 0
			unclaimed[order.product] -= 1 if in_stock else 0
			if queued.has(Workbench.pack_task_name(order)):
				pill = Ui.pill("Queued", Ui.GREEN_DARK, Ui.GREEN_SOFT)
				action = Ui.button("Queued", Callable(), DONE_BG, LABEL)
				action.disabled = true
			elif in_stock and bench.pack_problem(order) == "":
				pill = Ui.pill("Ready to pack", Ui.AMBER_DARK, Ui.AMBER_SOFT)
				action = Ui.button("Pack & ship", _pack.bind(order), ROSE, Ui.WHITE)
			else:
				var reason := "Needs printing" if not in_stock else "No mailer boxes"
				pill = Ui.pill(reason, Ui.RED_DARK, Ui.RED_SOFT)
				action = Ui.button("Pack & ship", Callable(), DONE_BG, LABEL)
				action.disabled = true
		action.custom_minimum_size.x = 120
		var due := GameClock.new()
		due.minutes = order.due_at
		var words := Ui.vbox([
			Ui.text(Game.product_name(order.product), 15, Ui.INK, 800),
			Ui.text("%s · Ship by day %d" % [Money.format(order.price, Money.PRICE), due.day], 13, LABEL),
		], 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(Ui.panel(Ui.hbox([
			Ui.width(Ui.text("#CR-%d" % (1000 + order.id), 14, Ui.INK, 800), 96), words, pill, action,
		], 16), Ui.box(ROW, 14, 14, 10)))
	if rows.get_child_count() == 0:
		rows.add_child(Ui.text("No orders waiting. Listed designs bring them in.", 14, LABEL))
	return _section("Orders to pack", rows)


func _listings_card() -> Control:
	var table := Ui.vbox([], 8)
	table.add_child(Ui.margin(_table_row([
		Ui.text("Item", 13, LABEL, 800), Ui.text("Price", 13, LABEL, 800), Ui.text("Cost to make", 13, LABEL, 800),
		Ui.text("Profit", 13, LABEL, 800), Ui.text("Sold", 13, LABEL, 800), Ui.text("For sale", 13, LABEL, 800),
	]), 14, 0, 14, 0))
	for product in Game.owned_designs:
		table.add_child(Ui.panel(_listing_row(product), Ui.box(ROW, 14, 14, 10)))
	return _section("Your listings", table)


func _listing_row(product: StringName) -> Control:
	var market := Game.market
	var entry := market.listing(product)
	var price: int = entry["price"]
	var listed: bool = entry["listed"]
	var profit := Game.unit_profit(product, price)
	var cheaper := Ui.button("-", _update.bind(product, listed, price - PRICE_STEP), Ui.WHITE, Ui.INK, 30, 10)
	cheaper.disabled = price <= PRICE_STEP
	var toggle := Ui.button("Listed" if listed else "List it", _update.bind(product, not listed, price),
		Ui.GREEN if listed else Ui.INK, Ui.WHITE, 34, 10)
	toggle.custom_minimum_size.x = 76
	toggle.tooltip_text = "Click to take it down" if listed else "Click to put it up for sale"
	return _table_row([
		Ui.text(Game.product_name(product), 15, Ui.INK, 800),
		Ui.hbox([cheaper, Ui.width(Ui.text(Money.format(price, Money.PRICE), 15), 66),
			Ui.button("+", _update.bind(product, listed, price + PRICE_STEP), Ui.WHITE, Ui.INK, 30, 10)], 4),
		Ui.text(Money.format(Game.unit_cost(product)), 15),
		Ui.text(Money.format(profit), 15, Ui.GREEN_DARK if profit > 0 else Ui.RED_DARK, 800),
		Ui.text(str(entry["sold"]), 15),
		Ui.hbox([toggle, Ui.text("%.1f a day" % market.orders_per_day(product, price) if listed else "", 13, LABEL)], 10),
	])


## Lays cells out in the listings table's column proportions.
func _table_row(cells: Array) -> Control:
	var row := Ui.hbox([], 12)
	for index in cells.size():
		var cell: Control = cells[index]
		Ui.grow(cell, COLUMNS[index])
		cell.custom_minimum_size.x = 0
		if cell is Label:
			cell.clip_text = true
		row.add_child(cell)
	return row


func _sales_card() -> Control:
	var rows := Ui.vbox([], 10)
	var shipped := Game.market.orders.filter(func(order: Marketplace.Order) -> bool: return order.status == Marketplace.Status.SHIPPED)
	shipped.reverse()
	for order: Marketplace.Order in shipped.slice(0, RECENT_SALES):
		var when := GameClock.new()
		when.minutes = order.shipped_at
		var net := Game.unit_profit(order.product, order.price)
		rows.add_child(Ui.panel(Ui.vbox([
			Ui.hbox([Ui.text(Game.product_name(order.product), 14, Ui.INK, 800), null, Ui.text(Money.format(order.price, Money.PRICE), 14, Ui.GREEN_DARK, 800)]),
			Ui.text("Day %d · about %s profit" % [when.day, Money.format(net)], 13, LABEL),
		], 2), Ui.box(ROW, 16, 14, 12)))
	if shipped.is_empty():
		rows.add_child(Ui.panel(Ui.wrap(Ui.text("No sales yet. You are paid when the courier collects a packed order.", 14, LABEL)), Ui.box(ROW, 16, 14, 14)))
	var tip := "Tip: price below the typical price for more orders, or above it for more profit on each one. Fees are %.1f%% + %s a sale." % [
		float(Game.market.config["fee_pct"]) * 100.0, Money.format(int(Game.market.config["fee_fixed_pence"]))]
	rows.add_child(Ui.panel(Ui.wrap(Ui.text(tip, 13, Ui.GREEN_DARK, 800)), Ui.box(TIP_BG, 16, 14, 14)))
	var card := _section("Recent sales", rows)
	card.custom_minimum_size.x = 400
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return card


func _section(heading: String, content: Control) -> PanelContainer:
	return Ui.panel(Ui.vbox([Ui.title(heading, 20), content], 12), Ui.box(Ui.WHITE, 22, 20, 18, SHADOW, 4))


func _pack(order: Marketplace.Order) -> void:
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	agent.enqueue(bench.pack_action(order))
	screen.refresh()


func _update(product: StringName, listed: bool, price: int) -> void:
	Game.market.set_listing(product, listed, price)
	Game.changed.emit()
