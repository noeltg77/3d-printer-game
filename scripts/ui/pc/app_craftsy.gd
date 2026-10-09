extends VBoxContainer
## PC app: a marketplace's seller dashboard. One script serves every marketplace:
## the entry in PcScreen.APPS says which (`market`) and gives its colours. Headline numbers along the top,
## orders to pack and the listings table on the left, reviews and recent sales
## on the right.
## "Pack & ship" queues the packing job for the character.

const HOT_BG := Color("E3F3EA")
const COOL_BG := Color("F6E6E2")
const SHADOW := Color("F0DCD6")
const ROW := Color("FCF5F3")
const LABEL := Color("6E5E62")
const DONE_BG := Color("E7DEDB")
const TIP_BG := Color("EAF3EE")
const PRICE_STEP := 50
const RECENT_SALES := 4
const RECENT_REVIEWS := 4
const STAR := Color("E0A526")
## Listings table column widths, as shares of the row.
const COLUMNS: Array[float] = [2.2, 1.5, 1.0, 1.0, 0.7, 1.9]

var screen: PcScreen
## This app's entry in PcScreen.APPS.
var app: Dictionary = {}


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var market := _market()
	if not Game.unlocked(market.config):
		add_child(_locked_page())
		return
	var header := Ui.hbox([
		Ui.title(String(market.config["name"]).to_lower(), 32, _colour(), 700),
		Ui.title("%s · Seller dashboard" % Game.data.settings["business_name"], 22),
		null,
		Ui.button("+ More designs", func() -> void: screen.show_app("design_lab"), _colour(), Ui.WHITE, 46, 14, _dark(), 15),
	], 16)

	var left := Ui.vbox([_orders_card(), _listings_card()], 20)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := Ui.vbox([_trends_card(), _reviews_card(), _sales_card()], 20)
	right.custom_minimum_size.x = 400
	var side := Ui.scroll(right)
	side.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.custom_minimum_size.x = 412
	var lower := Ui.hbox([Ui.scroll(left), side], 20)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page := Ui.margin(Ui.vbox([header, _stats(), lower], 20), 40, 24, 40, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _stats() -> Control:
	var market := _market()
	var today_start := float(Game.clock.day - 1) * GameClock.DAY
	var sold_today := 0
	var takings := 0
	for order in market.orders:
		if order.shipped_at >= today_start and order.status != Marketplace.Status.REFUNDED:
			sold_today += 1
			takings += order.price
	var open := market.open_orders()
	var due_today := open.filter(func(order: Marketplace.Order) -> bool: return order.due_at < today_start + GameClock.DAY).size()
	var parcels := market.active_orders().size() - open.size()
	var courier := int(Game.data.settings["courier_minute_of_day"])
	var low := Game.packaging <= Advice.LOW_PACKAGING

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_child(_stat("Sales today", Money.format(takings), "%d sold today" % sold_today, Ui.GREEN_DARK))
	grid.add_child(_rating_stat())
	grid.add_child(_stat("To ship", "%d order%s" % [open.size(), "" if open.size() == 1 else "s"],
		"%d due today" % due_today if due_today > 0 else "Nothing due today", Ui.RED_DARK if due_today > 0 else Ui.GREEN_DARK))
	grid.add_child(_stat("Mailer boxes", "%d left" % Game.packaging,
		"Order more from %s" % Game.data.settings["supplier"]["hardware_shop"] if low else "One for every order",
		Ui.RED_DARK if low else LABEL))
	grid.add_child(_stat("Courier", "%02d:%02d" % [courier / 60, courier % 60],
		"%d parcel%s waiting to go" % [parcels, "" if parcels == 1 else "s"], Ui.GREEN_DARK if parcels > 0 else LABEL))
	return grid


## The seller rating, and what it is doing to how many orders come in.
func _rating_stat() -> Control:
	var market := _market()
	if market.reviews.is_empty():
		return _stat("Seller rating", "New shop", "No reviews yet", LABEL)
	var effect := market.rating_multiplier()
	var note := "Not changing your orders"
	var colour := LABEL
	if effect > 1.005:
		note = "Bringing %d%% more orders" % roundi((effect - 1.0) * 100.0)
		colour = Ui.GREEN_DARK
	elif effect < 0.995:
		note = "Costing you %d%% of orders" % roundi((1.0 - effect) * 100.0)
		colour = Ui.RED_DARK
	return _stat("Seller rating", "%.1f out of 5" % market.rating(), note, colour)


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
	for order in _market().active_orders():
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
				action = Ui.button("Pack & ship", _pack.bind(order), _colour(), Ui.WHITE)
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
			Ui.text("%s · Ship by day %d" % [Money.format(order.price), due.day], 13, LABEL),
		], 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(Ui.panel(Ui.hbox([
			Ui.width(Ui.text(_market().order_label(order), 14, Ui.INK, 800), 96), words, pill, action,
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
	var market := _market()
	var entry := market.listing(product)
	var price: int = entry["price"]
	var listed: bool = entry["listed"]
	var profit := Game.unit_profit(product, price, market)
	var cheaper := Ui.button("-", _update.bind(product, listed, price - PRICE_STEP), Ui.WHITE, Ui.INK, 30, 10)
	cheaper.disabled = price <= PRICE_STEP
	var toggle := Ui.button("Listed" if listed else "List it", _update.bind(product, not listed, price),
		Ui.GREEN if listed else Ui.INK, Ui.WHITE, 34, 10)
	toggle.custom_minimum_size.x = 76
	toggle.tooltip_text = "Click to take it down" if listed else "Click to put it up for sale"
	return _table_row([
		Ui.text(Game.product_name(product), 15, Ui.INK, 800),
		Ui.hbox([cheaper, Ui.width(Ui.text(Money.format(price), 15), 66),
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
	var shipped := _market().sold_orders()
	shipped.reverse()
	for order: Marketplace.Order in shipped.slice(0, RECENT_SALES):
		var when := GameClock.new()
		when.minutes = order.shipped_at
		var net := Game.unit_profit(order.product, order.price, _market())
		var refunded := order.status == Marketplace.Status.REFUNDED
		var note := "Day %d · about %s profit" % [when.day, Money.format(net)]
		if refunded:
			note = "Day %d · refunded: %s" % [when.day, "arrived broken" if order.refund_reason == "damaged" else "sent back"]
		elif order.status == Marketplace.Status.SHIPPED:
			note += " · on its way"
		rows.add_child(Ui.panel(Ui.vbox([
			Ui.hbox([Ui.text(Game.product_name(order.product), 14, Ui.INK, 800), null,
				Ui.text(Money.format(0 if refunded else order.price), 14, Ui.RED_DARK if refunded else Ui.GREEN_DARK, 800)]),
			Ui.text(note, 13, Ui.RED_DARK if refunded else LABEL),
		], 2), Ui.box(ROW, 16, 14, 12)))
	if shipped.is_empty():
		rows.add_child(Ui.panel(Ui.wrap(Ui.text("No sales yet. You are paid when the courier collects a packed order.", 14, LABEL)), Ui.box(ROW, 16, 14, 14)))
	var tip := "Tip: price below the typical price for more orders, or above it for more profit on each one. Fees are %.1f%% + %s a sale." % [
		float(_market().config["fee_pct"]) * 100.0, Money.format(int(_market().config["fee_fixed_pence"]))]
	rows.add_child(Ui.panel(Ui.wrap(Ui.text(tip, 13, Ui.GREEN_DARK, 800)), Ui.box(TIP_BG, 16, 14, 14)))
	return _section("Recent sales", rows)


## The latest reviews, newest first.
func _reviews_card() -> Control:
	var rows := Ui.vbox([], 10)
	var latest := _market().reviews.duplicate()
	latest.reverse()
	for review: Dictionary in latest.slice(0, RECENT_REVIEWS):
		var stars := int(review["stars"])
		var lines := Ui.vbox([
			Ui.hbox([Ui.pips(stars, Marketplace.MAX_STARS, STAR if stars >= 3 else Ui.RED), null,
				Ui.text(Game.product_name(review["product"]), 13, LABEL, 800)]),
		], 6)
		if review["text"] != "":
			lines.add_child(Ui.wrap(Ui.text("\"%s\"" % review["text"], 14, Ui.INK)))
		rows.add_child(Ui.panel(lines, Ui.box(ROW, 16, 14, 12)))
	if latest.is_empty():
		rows.add_child(Ui.panel(Ui.wrap(Ui.text("No reviews yet. Buyers leave them a day or two after the courier collects. Weak or rough prints get refunds and bad ones.", 14, LABEL)), Ui.box(ROW, 16, 14, 14)))
	return _section("Reviews", rows)


func _section(heading: String, content: Control) -> PanelContainer:
	return Ui.panel(Ui.vbox([Ui.title(heading, 20), content], 12), Ui.box(Ui.WHITE, 22, 20, 18, SHADOW, 4))


func _pack(order: Marketplace.Order) -> void:
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	agent.enqueue(bench.pack_action(order))
	screen.refresh()


func _update(product: StringName, listed: bool, price: int) -> void:
	_market().set_listing(product, listed, price)
	Game.changed.emit()


## What buyers are after this week, and what has gone quiet.
func _trends_card() -> Control:
	var trends := Game.trends
	if trends.hot == "":
		return _section("In demand", Ui.text("Nothing in particular yet.", 14, LABEL))
	var days := maxi(ceili((trends.until - Game.clock.minutes) / GameClock.DAY), 1)
	var rows := Ui.vbox([
		Ui.panel(Ui.vbox([
			Ui.text("Selling fast: %s" % trends.category_name(trends.hot), 14, Ui.GREEN_DARK, 800),
			Ui.text("About %d%% more orders" % roundi((trends.multiplier(trends.hot) - 1.0) * 100.0), 13, LABEL),
		], 0), Ui.box(HOT_BG, 16, 14, 10)),
		Ui.panel(Ui.vbox([
			Ui.text("Gone quiet: %s" % trends.category_name(trends.cool), 14, Ui.RED_DARK, 800),
			Ui.text("About %d%% fewer orders" % roundi((1.0 - trends.multiplier(trends.cool)) * 100.0), 13, LABEL),
		], 0), Ui.box(COOL_BG, 16, 14, 10)),
		Ui.text("Fashions move on in about %d day%s." % [days, "" if days == 1 else "s"], 13, LABEL),
	], 10)
	return _section("In demand", rows)


## Shown instead of the dashboard until the business is big enough to sell here.
func _locked_page() -> Control:
	var market := _market()
	var card := Ui.card(Ui.vbox([
		Ui.title(String(market.config["name"]).to_lower(), 32, _colour(), 700),
		Ui.wrap(Ui.text(market.config["description"], 15, Ui.INK)),
		Ui.wrap(Ui.text("%s only signs up sellers with proper premises. Move to a bigger space and you can open a shop here." % market.config["name"], 14, LABEL, 800)),
	], 12), 22, 28, SHADOW)
	card.custom_minimum_size.x = 620
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var page := Ui.margin(card, 40, 32, 40, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return page


func _market() -> Marketplace:
	return Game.markets[StringName(app.get("market", "craftsy"))]


func _colour() -> Color:
	return Color.html(app.get("colour", "C9415F"))


func _dark() -> Color:
	return Color.html(app.get("dark", "962E46"))
