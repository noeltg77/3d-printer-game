class_name Marketplace
extends RefCounted
## One online marketplace: the player's listings and the orders they bring in.
## Orders arrive at random while a design is listed, faster when it is priced
## below its typical price and slower above. An order must be packed and handed
## to the courier before its dispatch deadline or it is cancelled.

enum Status { OPEN, PACKED, SHIPPED, CANCELLED }


class Order:
	extends RefCounted
	var id: int
	var product: StringName
	var price: int
	var placed_at: float
	var due_at: float
	## When the courier took it, or -1 if it hasn't gone yet.
	var shipped_at := -1.0
	var status := Status.OPEN


## Row from data/marketplaces.json.
var config: Dictionary
## Product rows from data/products.json, by id.
var products: Dictionary
## product id -> { listed: bool, price: int, sold: int }
var listings: Dictionary[StringName, Dictionary] = {}
var orders: Array[Order] = []

var _next_id := 1


func _init(p_config: Dictionary, p_products: Dictionary) -> void:
	config = p_config
	products = p_products


## The listing for a design, created at its typical price and unlisted if new.
func listing(product: StringName) -> Dictionary:
	if not listings.has(product):
		listings[product] = {"listed": false, "price": int(products[product]["base_price_cents"]), "sold": 0}
	return listings[product]


func set_listing(product: StringName, listed: bool, price: int) -> void:
	var entry := listing(product)
	entry["listed"] = listed
	entry["price"] = maxi(price, 1)


## How demand scales at `price`: 1.0 at the typical price, more when cheaper.
func demand_multiplier(product: StringName, price: int) -> float:
	var typical: float = products[product]["base_price_cents"]
	var multiplier := pow(typical / maxf(price, 1.0), config["price_sensitivity"])
	return minf(multiplier, config["max_demand_multiplier"])


## Expected orders per game day for a design at a price.
func orders_per_day(product: StringName, price: int) -> float:
	return products[product]["demand_per_day"] * demand_multiplier(product, price)


## Rolls for new orders over a span of game minutes. Returns the ones placed.
func tick(from_minute: float, to_minute: float, rng: RandomNumberGenerator) -> Array[Order]:
	var placed: Array[Order] = []
	var days := (to_minute - from_minute) / GameClock.DAY
	for product in listings:
		var entry := listings[product]
		if not entry["listed"] or open_orders().size() >= int(config["max_open_orders"]):
			continue
		if rng.randf() < orders_per_day(product, entry["price"]) * days:
			var order := Order.new()
			order.id = _next_id
			order.product = product
			order.price = entry["price"]
			order.placed_at = to_minute
			order.due_at = to_minute + float(config["dispatch_minutes"])
			_next_id += 1
			orders.append(order)
			placed.append(order)
	return placed


## Cancels open orders that have passed their deadline. Returns them.
func expire(minute: float) -> Array[Order]:
	var cancelled: Array[Order] = []
	for order in orders:
		if order.status == Status.OPEN and minute > order.due_at:
			order.status = Status.CANCELLED
			cancelled.append(order)
	return cancelled


func open_orders() -> Array[Order]:
	return orders.filter(func(order: Order) -> bool: return order.status == Status.OPEN)


## Orders still in play: waiting to be packed, or packed and waiting for the courier.
func active_orders() -> Array[Order]:
	return orders.filter(func(order: Order) -> bool: return order.status in [Status.OPEN, Status.PACKED])


func mark_packed(order: Order) -> void:
	order.status = Status.PACKED


## Completes a sale. Returns what to put through the bank:
## { price, fee, royalty } in cents.
func ship(order: Order, minute := 0.0) -> Dictionary:
	order.status = Status.SHIPPED
	order.shipped_at = minute
	listing(order.product)["sold"] += 1
	return {"price": order.price, "fee": fee_for(order.price), "royalty": royalty_for(order.product, order.price)}


func fee_for(price: int) -> int:
	return roundi(price * float(config["fee_pct"])) + int(config["fee_fixed_cents"])


func royalty_for(product: StringName, price: int) -> int:
	return roundi(price * float(products[product]["licence"]["royalty_pct"]))
