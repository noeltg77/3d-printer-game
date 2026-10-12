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
## A shipped order is delivered some time later. It may go missing, arrive
## broken (weak prints in poor packaging, rough couriers) or be sent back
## (flawed or rough prints); each way the buyer is refunded and leaves a bad
## review. How it was sent is in the order's `shipping` (Shipping.terms). Otherwise the buyer may
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
const LOST_STARS := 1
## Quality at or above which nobody sends an item back for being rough.
const FINE_QUALITY := 3


class Order:
	extends RefCounted
	var id: int
	## Id of the marketplace it was placed on.
	var market: StringName
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
	## True if a design made for several colours went out in one.
	var plain := false
	## Why it was refunded: "damaged", "returned" or "lost". Empty otherwise.
	var refund_reason := ""
	## What it was packed in and how it was sent (Shipping.terms). Empty for
	## an order from before there was a choice.
	var shipping: Dictionary = {}
	## True if the courier held it up.
	var late := false

	func save() -> Dictionary:
		return {
			"id": id, "market": market, "product": product, "price": price, "placed_at": placed_at, "due_at": due_at,
			"shipped_at": shipped_at, "deliver_at": deliver_at, "status": status, "durability": durability,
			"quality": quality, "flawed": flawed, "plain": plain, "refund_reason": refund_reason,
			"shipping": shipping, "late": late,
		}

	static func restored(data: Dictionary) -> Order:
		var order := Order.new()
		order.id = int(data["id"])
		order.market = StringName(data.get("market", ""))
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
		order.plain = bool(data.get("plain", false))
		order.refund_reason = String(data["refund_reason"])
		order.shipping = data.get("shipping", {})
		order.late = bool(data.get("late", false))
		return order


## Row from data/marketplaces.json.
var config: Dictionary
## Product rows from data/products.json, by id.
var products: Dictionary
## Review wording from data/reviews.json: "damaged", "returned" and "1" to "5",
## each a list of lines. Optional.
var comments: Dictionary = {}
## product id -> { listed: bool, price: int, sold: int, colours: Array }.
## `colours` is whether each of the last few sent was in a colour buyers like.
var listings: Dictionary[StringName, Dictionary] = {}
var orders: Array[Order] = []
## What is in or out of fashion: product category -> demand multiplier (Trends).
var trend: Dictionary = {}
## What is happening to particular designs just now: product id -> demand
## multiplier (a design gone viral, or undercut by a rival). See Events.
var boost: Dictionary[StringName, float] = {}
## The business's own designs: product id -> how well each sells against the
## bought design (1.0 the same). Own designs owe no royalty.
var own_appeal: Dictionary[StringName, float] = {}
## What colours buyers like and what that does for demand. Optional.
var taste: ColourTaste = null
## Stars a buyer knocks off a multicolour design that arrives in one colour.
var plain_star_penalty := 0.0
## Oldest first. Each: { order, product, stars, text, minute }.
var reviews: Array[Dictionary] = []

var _next_id := 1


func _init(p_config: Dictionary, p_products: Dictionary) -> void:
	config = p_config
	products = p_products


## The listing for a design, created at its typical price and unlisted if new.
func listing(product: StringName) -> Dictionary:
	if not listings.has(product):
		listings[product] = {"listed": false, "price": typical_price(product), "sold": 0, "colours": []}
	return listings[product]


func set_listing(product: StringName, listed: bool, price: int) -> void:
	var entry := listing(product)
	entry["listed"] = listed
	entry["price"] = maxi(price, 1)


## What buyers here expect to pay for a design: its usual price, scaled by how
## cheap or dear this marketplace's buyers are.
func typical_price(product: StringName) -> int:
	return roundi(float(products[product]["base_price_pence"]) * float(config.get("price_expectation", 1.0)))


## How demand scales at `price`: 1.0 at the typical price, more when cheaper.
func demand_multiplier(product: StringName, price: int) -> float:
	var typical := float(typical_price(product))
	var multiplier := pow(typical / maxf(price, 1.0), config["price_sensitivity"])
	return minf(multiplier, config["max_demand_multiplier"])


## Expected orders per game day for a design at a price, at the current rating.
func orders_per_day(product: StringName, price: int) -> float:
	return (products[product]["demand_per_day"] * demand_multiplier(product, price) * rating_multiplier()
		* float(own_appeal.get(product, 1.0)) * float(config.get("audience", 1.0))
		* float(trend.get(products[product]["category"], 1.0)) * float(boost.get(product, 1.0))
		* colour_multiplier(product))


## How the colours a design has been going out in scale its demand
## (ColourTaste.demand): 1.0 until some have been sent.
func colour_multiplier(product: StringName) -> float:
	return 1.0 if taste == null else taste.demand(listing(product)["colours"])


## Notes the colours of a print that has just been packed for a buyer:
## `liked` if they are among the ones buyers like the design best in.
func note_colour(product: StringName, liked: bool) -> void:
	if taste == null or taste.favourites(products[product]).is_empty():
		return
	var recent: Array = listing(product)["colours"]
	recent.append(liked)
	while recent.size() > taste.window():
		recent.pop_front()


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
			order.market = StringName(config["id"])
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
## `value_multiplier` is the premium for the filament it was printed in, less
## the discount for a multicolour design printed in one colour: the buyer pays
## the listed price times this. `plain` says it was such a print. `shipping`
## is what it was packed in and how it is being sent (Shipping.terms).
func mark_packed(order: Order, durability := 3, quality := 3, flawed := false, value_multiplier := 1.0, plain := false,
		shipping: Dictionary = {}) -> void:
	order.status = Status.PACKED
	order.shipping = shipping
	order.price = roundi(order.price * value_multiplier)
	order.durability = durability
	order.quality = quality
	order.flawed = flawed
	order.plain = plain


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


## Stars (1 to 5) a buyer gives an item that arrived and was kept. `penalty` is
## taken off for anything else that let them down.
static func stars_for(quality: int, flawed: bool, rng: RandomNumberGenerator, penalty := 0.0) -> int:
	var deserved := STARS_BASE + STARS_PER_QUALITY * quality - (FLAW_PENALTY if flawed else 0.0) - penalty
	return clampi(roundi(deserved + rng.randf_range(-STARS_NOISE, STARS_NOISE)), 1, MAX_STARS)


## Delivers the shipped orders that have arrived by `minute`. Returns one
## outcome for each: { order, refund, review }. `refund` is {} or the
## { price, fee, royalty } to put back through the bank; `review` is {} or the
## review the buyer left. `usual` is how an order with no `shipping` of its
## own was sent.
func deliver(minute: float, rng: RandomNumberGenerator, usual: Dictionary) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	for order in orders:
		if order.status != Status.SHIPPED or order.deliver_at > minute:
			continue
		var shipping := usual if order.shipping.is_empty() else order.shipping
		var outcome := {"order": order, "refund": {}, "review": {}}
		if rng.randf() < float(shipping.get("lost_chance", 0.0)):
			outcome["refund"] = _refund(order, "lost")
			outcome["review"] = _review(order, LOST_STARS, "lost", minute, rng)
		elif rng.randf() < damage_chance(order.durability, shipping):
			outcome["refund"] = _refund(order, "damaged")
			outcome["review"] = _review(order, DAMAGED_STARS, "damaged", minute, rng)
		elif rng.randf() < return_chance(order.quality, order.flawed):
			outcome["refund"] = _refund(order, "returned")
			outcome["review"] = _review(order, RETURNED_STARS, "returned", minute, rng)
		else:
			order.status = Status.DELIVERED
			if rng.randf() < float(config["review_chance"]):
				var penalty := (plain_star_penalty if order.plain else 0.0) - float(shipping.get("star_bonus", 0.0))
				if order.late:
					penalty += float(shipping.get("late_star_penalty", 0.0))
				var stars := stars_for(order.quality, order.flawed, rng, penalty)
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


## "#CR-1004": an order's number as buyers and the player see it.
func order_label(order: Order) -> String:
	return "#%s-%d" % [config.get("order_prefix", "OR"), 1000 + order.id]


## Puts back a saved shop. Listings, orders and reviews for designs the game
## no longer has are dropped.
func restore(data: Dictionary) -> void:
	listings.clear()
	orders.clear()
	reviews.clear()
	for product: String in data["listings"]:
		if products.has(product):
			var entry: Dictionary = data["listings"][product]
			listings[StringName(product)] = {"listed": bool(entry["listed"]), "price": int(entry["price"]), "sold": int(entry["sold"]),
				"colours": (entry.get("colours", []) as Array).map(func(liked: Variant) -> bool: return bool(liked))}
	for entry: Dictionary in data["orders"]:
		if products.has(entry["product"]):
			var order := Order.restored(entry)
			order.market = StringName(config["id"])
			orders.append(order)
	for entry: Dictionary in data["reviews"]:
		if products.has(entry["product"]):
			reviews.append({
				"order": int(entry["order"]), "product": StringName(entry["product"]), "stars": int(entry["stars"]),
				"minute": float(entry["minute"]), "text": String(entry["text"]),
			})
	_next_id = int(data["next_id"])
