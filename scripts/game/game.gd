extends Node
## Autoload `Game`: the running business. Owns the simulation objects (clock,
## bank, marketplace, supplier), moves them on each frame and announces what
## happened. Scene nodes and UI read state from here and call the methods below;
## the rules themselves live in scripts/sim.

## Something the UI shows has changed (cash, orders, designs, stock).
signal changed
## A short message for the player.
signal notified(text: String)
signal delivery_arrived(delivery: Supplier.Delivery)
## The daily courier is here to take whatever is in the outbox.
signal courier_arrived

const SPEEDS: Array[int] = [0, 1, 2, 4]

var data: GameData
var clock: GameClock
var bank: Bank
var market: Marketplace
var supplier: Supplier
var owned_designs: Array[StringName] = []
## Mailer boxes in stock, one used per packed order.
var packaging := 0
var speed := 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	new_game()


func _process(delta: float) -> void:
	var before := clock.minutes
	clock.advance(delta)
	for delivery in supplier.collect_due(clock.minutes):
		delivery_arrived.emit(delivery)
		notify("Delivery arrived: %s" % delivery.describe())
		changed.emit()
	for order in market.tick(before, clock.minutes, rng):
		notify("New order: %s for %s" % [product_name(order.product), Money.text(order.price)])
		changed.emit()
	for order in market.expire(clock.minutes):
		notify("Order #%d was cancelled: not dispatched in time" % order.id)
		changed.emit()
	if clock.crossed(before, data.settings["courier_minute_of_day"]):
		courier_arrived.emit()


func new_game() -> void:
	data = GameData.load_all()
	var start: Dictionary = data.settings["start"]
	clock = GameClock.new()
	clock.minutes = start["minute_of_day"]
	bank = Bank.new(int(start["cash_cents"]))
	market = Marketplace.new(data.marketplaces["craftsy"], data.products)
	supplier = Supplier.new(data)
	owned_designs.assign(start["designs"])
	packaging = int(start["packaging"])
	rng.randomize()
	set_speed(1)


## 0 pauses. Everything in the scene follows, because it scales engine time.
func set_speed(new_speed: float) -> void:
	speed = int(new_speed)
	Engine.time_scale = new_speed
	changed.emit()


func notify(text: String) -> void:
	notified.emit(text)


func product_name(product: StringName) -> String:
	return data.products[product]["name"]


func owns(product: StringName) -> bool:
	return owned_designs.has(product)


## Buys a design licence. False if it can't be afforded or is already owned.
func buy_design(product: StringName) -> bool:
	if owns(product):
		return false
	var fee := int(data.products[product]["licence"]["fee_cents"])
	if not bank.spend(fee, "Design licence: %s" % product_name(product), clock.minutes):
		return false
	owned_designs.append(product)
	changed.emit()
	return true


## Why a supplier basket can't be ordered, or "" if it can.
func supplier_problem(basket: Dictionary) -> String:
	if supplier.price_of(basket) <= 0:
		return "Basket is empty"
	if not bank.can_afford(supplier.price_of(basket)):
		return "Not enough cash"
	var incoming_spools := 0
	var incoming_printers := 0
	for delivery in supplier.pending:
		incoming_spools += delivery.spools.size()
		incoming_printers += 1 if delivery.printer != &"" else 0
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	if rack != null and Supplier.count_spools(basket) + incoming_spools > rack.free_slots() - _unpacked(&"spools"):
		return "Not enough room on the filament rack"
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	if bench != null and Supplier.count_printers(basket) + incoming_printers > bench.free_spots() - _unpacked(&"printers"):
		return "No bench space for another printer"
	return ""


## Pays for a basket and schedules its deliveries. False if it can't be ordered.
func place_supplier_order(basket: Dictionary) -> bool:
	if supplier_problem(basket) != "":
		return false
	bank.spend(supplier.price_of(basket), "%s order" % data.settings["supplier"]["name"], clock.minutes)
	supplier.place(basket, clock.minutes)
	changed.emit()
	return true


## Finished items of a design on the shelves.
func stock_of(product: StringName) -> int:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	return shelf.count_of(product) if shelf != null else 0


## Takes payment for a dispatched order, less the marketplace's cut.
func complete_sale(order: Marketplace.Order) -> void:
	var sale := market.ship(order)
	var market_name: String = market.config["name"]
	bank.earn(sale["price"], "Sale: %s (%s)" % [product_name(order.product), market_name], clock.minutes)
	bank.charge(sale["fee"], "%s fees" % market_name, clock.minutes)
	bank.charge(sale["royalty"], "Design royalty: %s" % product_name(order.product), clock.minutes)
	changed.emit()


## Charges for the electricity a finished print used.
func charge_electricity(watts: float, game_minutes: float, what: String) -> void:
	var kwh := watts / 1000.0 * game_minutes / 60.0
	bank.charge(roundi(kwh * float(data.settings["electricity_cents_per_kwh"])), "Electricity: %s" % what, clock.minutes)
	changed.emit()


## Spools or printers sitting in delivery boxes that haven't been unpacked yet.
func _unpacked(what: StringName) -> int:
	var count := 0
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		count += box.delivery.spools.size() if what == &"spools" else (1 if box.delivery.printer != &"" else 0)
	return count
