class_name Marketplace
extends RefCounted
## One online marketplace: the player's listings, the orders they bring in and
## what buyers make of what they get.
##
## Orders arrive at random while a design is listed, faster when it is priced
## below its typical price and slower above, and scaled by the seller rating.
## An order must be packed and handed to the courier before its dispatch
## deadline or it is cancelled.
##
## A shipped order is delivered some time later. It may arrive broken (weak
## prints in poor packaging) or be sent back (flawed or rough prints); either
## way the buyer is refunded and leaves a bad review. Otherwise the buyer may
## leave a review that follows the item's quality. The seller rating is the
## average of the most recent reviews.

enum Status { OPEN, PACKED, SHIPPED, CANCELLED, DELIVERED, REFUNDED }

const MAX_STARS := 5
## Stars a buyer gives for an item of quality 0, and for each point of quality.
const STARS_BASE := 3.2
const STARS_PER_QUALITY := 0.5
## Reviews wander this far either side of what the quality deserves.
const STARS_NOISE := 0.8
## Stars knocked off for an item that came out flawed.
const FLAW_PENALTY := 1.0
const DAMAGED_STARS := 1
const RETURNED_STARS := 2
## Quality at or above which nobody sends an item back for being rough.
const FINE_QUALITY := 3


class Order:
	extends RefCounted
	var id: int
	var product: StringName
	var price: int
	var placed_at: float
	var due_at: float
	## When the courier took it, or -1 if it hasn't gone yet.
	var shipped_at := -1.0
	## When it reaches the buyer, once shipped.
	var deliver_at := -1.0
	var status := Status.OPEN
	## What went in the parcel: the item's strength and finish (1 to 5) and
	## whether a failure spoiled it. Set when the order is packed.
	var durability := 3
	var quality := 3
	var flawed := false
	## Why it was refunded: "damaged" or "returned". Empty otherwise.
	var refund_reason := ""

	func save() -> Dictionary:
		return {
			"id": id, "product": product, "price": price, "placed_at": placed_at, "due_at": due_at,
			"shipped_at": shipped_at, "deliver_at": deliver_at, "status": status, "durability": durability,
			"quality": quality, "flawed": flawed, "refund_reason": refund_reason,
		}

	static func restored(data: Dictionary) -> Order:
		var order := Order.new()
		order.id = int(data["id"])
		order.product = StringName(data["product"])
		order.price = int(data["price"])
		order.placed_at = float(data["placed_at"])
		order.due_at = float(data["due_at"])
		order.shipped_at = float(data["shipped_at"])
		order.deliver_at = float(data["deliver_at"])
		order.status = int(data["status"]) as Status
		order.durability = int(data["durability"])
		order.quality = int(data["quality"])
		order.flawed = bool(data["flawed"])
		order.refund_reason = String(data["refund_reason"])
		return order


## Row from data/marketplaces.json.
var config: Dictionary
## Product rows from data/products.json, by id.
var products: Dictionary
## Review wording from data/reviews.json: "damaged", "returned" and "1" to "5",
## each a list of lines. Optional.
var comments: Dictionary = {}
## product id -> { listed: bool, price: int, sold: int }
var listings: Dictionary[StringName, Dictionary] = {}
var orders: Array[Order] = []
## The business's own designs: product id -> how well each sells against the
## bought design (1.0 the same). Own designs owe no royalty.
var own_appeal: Dictionary[StringName, float] = {}
## Oldest first. Each: { order, product, stars, text, minute }.
var reviews: Array[Dictionary] = []

var _next_id := 1


func _init(p_config: Dictionary, p_products: Dictionary) -> void:
	config = p_config
	products = p_products


## The listing for a design, created at its typical price and unlisted if new.
func listing(product: StringName) -> Dictionary:
	if not listings.has(product):
		listings[product] = {"listed": false, "price": int(products[product]["base_price_pence"]), "sold": 0}
	return listings[product]


func set_listing(product: StringName, listed: bool, price: int) -> void:
	var entry := listing(product)
	entry["listed"] = listed
	entry["price"] = maxi(price, 1)


## How demand scales at `price`: 1.0 at the typical price, more when cheaper.
func demand_multiplier(product: StringName, price: int) -> float:
	var typical: float = products[product]["base_price_pence"]
	var multiplier := pow(typical / maxf(price, 1.0), config["price_sensitivity"])
	return minf(multiplier, config["max_demand_multiplier"])


## Expected orders per game day for a design at a price, at the current rating.
func orders_per_day(product: StringName, price: int) -> float:
	return (products[product]["demand_per_day"] * demand_multiplier(product, price) * rating_multiplier()
		* float(own_appeal.get(product, 1.0)))


## Rolls for new orders over a span of game minutes. Returns the ones placed.
func tick(from_minute: float, to_minute: float, rng: RandomNumberGenerator) -> Array[Order]:
	var placed: Array[Order] = []
	var days := (to_minute - from_minute) / GameClock.DAY
	# Counted once and kept up to date below: going through every order for every listing is slow.
	var open := open_orders().size()
	for product in listings:
		var entry := listings[product]
		if not entry["listed"] or open >= int(config["max_open_orders"]):
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
			open += 1
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


## Every order the courier has taken, whatever became of it since. Oldest first.
func sold_orders() -> Array[Order]:
	return orders.filter(func(order: Order) -> bool: return order.shipped_at >= 0.0)


## Records the order as packed, along with what the item in the parcel is like.
## `value_multiplier` is the premium for the filament it was printed in: the
## buyer pays that much more than the listed price.
func mark_packed(order: Order, durability := 3, quality := 3, flawed := false, value_multiplier := 1.0) -> void:
	order.status = Status.PACKED
	order.price = roundi(order.price * value_multiplier)
	order.durability = durability
	order.quality = quality
	order.flawed = flawed


## Completes a sale and sends it on its way, to arrive at `deliver_at`.
## Returns what to put through the bank: { price, fee, royalty } in pence.
func ship(order: Order, minute := 0.0, deliver_at := 0.0) -> Dictionary:
	order.status = Status.SHIPPED
	order.shipped_at = minute
	order.deliver_at = maxf(deliver_at, minute)
	listing(order.product)["sold"] += 1
	return _amounts(order)


func fee_for(price: int) -> int:
	return roundi(price * float(config["fee_pct"])) + int(config["fee_fixed_pence"])


func royalty_for(product: StringName, price: int) -> int:
	if own_appeal.has(product):
		return 0
	return roundi(price * float(products[product]["licence"]["royalty_pct"]))


## Chance (0 to 1) that a parcel arrives broken. `shipping` holds the
## packaging's `protection` (1 to 5) and the courier's `damage_multiplier`.
static func damage_chance(durability: int, shipping: Dictionary) -> float:
	var packaging := (6.0 - float(shipping["protection"])) / 3.0
	return clampf((5 - durability) * 0.02 * packaging * float(shipping["damage_multiplier"]), 0.0, 1.0)


## Chance (0 to 1) that the buyer sends an item back for not being good enough.
func return_chance(quality: int, flawed: bool) -> float:
	var rough := maxi(FINE_QUALITY - quality, 0) * float(config["return_chance_per_quality_point"])
	return clampf(rough + (float(config["return_chance_flawed"]) if flawed else 0.0), 0.0, 1.0)


## Stars (1 to 5) a buyer gives an item that arrived and was kept.
static func stars_for(quality: int, flawed: bool, rng: RandomNumberGenerator) -> int:
	var deserved := STARS_BASE + STARS_PER_QUALITY * quality - (FLAW_PENALTY if flawed else 0.0)
	return clampi(roundi(deserved + rng.randf_range(-STARS_NOISE, STARS_NOISE)), 1, MAX_STARS)


## Delivers the shipped orders that have arrived by `minute`. Returns one
## outcome for each: { order, refund, review }. `refund` is {} or the
## { price, fee, royalty } to put back through the bank; `review` is {} or the
## review the buyer left.
func deliver(minute: float, rng: RandomNumberGenerator, shipping: Dictionary) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	for order in orders:
		if order.status != Status.SHIPPED or order.deliver_at > minute:
			continue
		var outcome := {"order": order, "refund": {}, "review": {}}
		if rng.randf() < damage_chance(order.durability, shipping):
			outcome["refund"] = _refund(order, "damaged")
			outcome["review"] = _review(order, DAMAGED_STARS, "damaged", minute, rng)
		elif rng.randf() < return_chance(order.quality, order.flawed):
			outcome["refund"] = _refund(order, "returned")
			outcome["review"] = _review(order, RETURNED_STARS, "returned", minute, rng)
		else:
			order.status = Status.DELIVERED
			if rng.randf() < float(config["review_chance"]):
				var stars := stars_for(order.quality, order.flawed, rng)
				outcome["review"] = _review(order, stars, str(stars), minute, rng)
		outcomes.append(outcome)
	return outcomes


## Average stars over the most recent reviews, or 0 if there are none yet.
func rating() -> float:
	var recent := reviews.slice(-int(config["rating_window"]))
	if recent.is_empty():
		return 0.0
	var total := 0
	for review in recent:
		total += int(review["stars"])
	return float(total) / recent.size()


## How the seller rating scales demand: 1.0 with no reviews or at the neutral
## rating, less below it and a little more above. The first few reviews count
## for less, so one unlucky buyer can't sink a new shop.
func rating_multiplier() -> float:
	if reviews.is_empty():
		return 1.0
	var confidence := minf(reviews.size() / float(config["rating_confidence_reviews"]), 1.0)
	var swing := (rating() - float(config["rating_neutral"])) * float(config["rating_demand_per_star"]) * confidence
	return clampf(1.0 + swing, float(config["min_rating_multiplier"]), float(config["max_rating_multiplier"]))


func _amounts(order: Order) -> Dictionary:
	return {"price": order.price, "fee": fee_for(order.price), "royalty": royalty_for(order.product, order.price)}


func _refund(order: Order, reason: String) -> Dictionary:
	order.status = Status.REFUNDED
	order.refund_reason = reason
	listing(order.product)["sold"] -= 1
	return _amounts(order)


func _review(order: Order, stars: int, kind: String, minute: float, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array = comments.get(kind, [])
	var review := {
		"order": order.id, "product": order.product, "stars": stars, "minute": minute,
		"text": lines[rng.randi() % lines.size()] if not lines.is_empty() else "",
	}
	reviews.append(review)
	return review


## The order with this id, or null.
func order_by_id(id: int) -> Order:
	for order in orders:
		if order.id == id:
			return order
	return null


func save() -> Dictionary:
	return {
		"listings": listings, "reviews": reviews, "next_id": _next_id,
		"orders": orders.map(func(order: Order) -> Dictionary: return order.save()),
	}


## Puts back a saved shop. Listings, orders and reviews for designs the game
## no longer has are dropped.
func restore(data: Dictionary) -> void:
	listings.clear()
	orders.clear()
	reviews.clear()
	for product: String in data["listings"]:
		if products.has(product):
			var entry: Dictionary = data["listings"][product]
			listings[StringName(product)] = {"listed": bool(entry["listed"]), "price": int(entry["price"]), "sold": int(entry["sold"])}
	for entry: Dictionary in data["orders"]:
		if products.has(entry["product"]):
			orders.append(Order.restored(entry))
	for entry: Dictionary in data["reviews"]:
		if products.has(entry["product"]):
			reviews.append({
				"order": int(entry["order"]), "product": StringName(entry["product"]), "stars": int(entry["stars"]),
				"minute": float(entry["minute"]), "text": String(entry["text"]),
			})
	_next_id = int(data["next_id"])
