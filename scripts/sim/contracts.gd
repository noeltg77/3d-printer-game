class_name Contracts
extends RefCounted
## Business to business work: clients who want a batch of one design, made to a
## spec, by a deadline.
##
## An enquiry arrives now and then from one of the clients in data/contracts.json,
## for a design the business owns or one the client supplies. It waits in the
## inbox for a while. Accepted, it becomes a contract: so many items, in a set
## filament and perhaps a set colour, to a quality bar, due at a courier
## collection some days off. Items go out in crates, as many at a time as are
## ready. The client pays on the last one, less a share of the price for every
## day it is late, and walks away if it is very late, paying a cut rate for what
## did arrive.

enum Status { OFFERED, ACTIVE, DONE, FAILED, DECLINED, EXPIRED }


class Contract:
	extends RefCounted
	var id: int
	## Id of the client, from data/contracts.json.
	var client: StringName
	var product: StringName
	## Filament id the items have to be printed in (any variety of it will do).
	var material: StringName = &"pla"
	## Palette colour they have to be, or empty for any.
	var colour: StringName = &""
	var quantity := 1
	## The lowest finish (1 to 5) and strength (1 to 5) the client takes.
	var min_quality := 1
	var min_durability := 1
	## Pence the client pays for each item.
	var unit_price := 0
	## Share of the whole price knocked off for each day late.
	var late_pct_per_day := 0.0
	## What the client wrote.
	var text := ""
	var status := Status.OFFERED
	var offered_at := 0.0
	## When the enquiry lapses if it isn't answered.
	var expires_at := 0.0
	## Game minutes allowed from accepting to the deadline, before it is set to a collection time.
	var allowed_minutes := 0.0
	var accepted_at := -1.0
	var due_at := -1.0
	## Items the courier has taken so far, and items crated up and waiting for it.
	var delivered := 0
	var packed := 0
	## When it was finished or lost, and what the client paid in the end.
	var closed_at := -1.0
	var paid := 0

	func save() -> Dictionary:
		return {
			"id": id, "client": client, "product": product, "material": material, "colour": colour, "quantity": quantity,
			"min_quality": min_quality, "min_durability": min_durability, "unit_price": unit_price,
			"late_pct_per_day": late_pct_per_day, "text": text, "status": status, "offered_at": offered_at,
			"expires_at": expires_at, "allowed_minutes": allowed_minutes, "accepted_at": accepted_at, "due_at": due_at,
			"delivered": delivered, "packed": packed, "closed_at": closed_at, "paid": paid,
		}

	static func restored(data: Dictionary) -> Contract:
		var contract := Contract.new()
		contract.id = int(data["id"])
		contract.client = StringName(data["client"])
		contract.product = StringName(data["product"])
		contract.material = StringName(data["material"])
		contract.colour = StringName(data["colour"])
		contract.quantity = int(data["quantity"])
		contract.min_quality = int(data["min_quality"])
		contract.min_durability = int(data["min_durability"])
		contract.unit_price = int(data["unit_price"])
		contract.late_pct_per_day = float(data["late_pct_per_day"])
		contract.text = String(data["text"])
		contract.status = int(data["status"]) as Status
		contract.offered_at = float(data["offered_at"])
		contract.expires_at = float(data["expires_at"])
		contract.allowed_minutes = float(data["allowed_minutes"])
		contract.accepted_at = float(data["accepted_at"])
		contract.due_at = float(data["due_at"])
		contract.delivered = int(data["delivered"])
		contract.packed = int(data.get("packed", 0))
		contract.closed_at = float(data["closed_at"])
		contract.paid = int(data["paid"])
		return contract


var data: GameData
## Every enquiry and contract there has been, oldest first.
var all: Array[Contract] = []

var _next_id := 1


func _init(p_data: GameData) -> void:
	data = p_data


func offers() -> Array[Contract]:
	return all.filter(func(contract: Contract) -> bool: return contract.status == Status.OFFERED)


func active() -> Array[Contract]:
	return all.filter(func(contract: Contract) -> bool: return contract.status == Status.ACTIVE)


## Contracts that are over one way or another, newest first. Enquiries that
## were turned down or lapsed are left out.
func finished() -> Array[Contract]:
	var found := all.filter(func(contract: Contract) -> bool: return contract.status in [Status.DONE, Status.FAILED])
	found.reverse()
	return found


func by_id(id: int) -> Contract:
	for contract in all:
		if contract.id == id:
			return contract
	return null


## True if a contract in progress is for this design.
func needs(product: StringName) -> bool:
	return active().any(func(contract: Contract) -> bool: return contract.product == product)


## Rolls for a new enquiry over a span of game minutes. `designs` are the
## designs the business owns and `tier` how far it has grown. Returns the
## enquiry, or null if none came.
func tick(from_minute: float, to_minute: float, rng: RandomNumberGenerator, designs: Array[StringName], tier: int) -> Contract:
	if offers().size() >= int(_rules()["max_offers"]):
		return null
	if rng.randf() >= float(_rules()["offers_per_day"]) * (to_minute - from_minute) / GameClock.DAY:
		return null
	return offer(to_minute, rng, designs, tier)


## Makes an enquiry from a client picked at random among those with something
## to ask for. Null if no client has.
func offer(minute: float, rng: RandomNumberGenerator, designs: Array[StringName], tier: int) -> Contract:
	var able: Array[Dictionary] = []
	for client: Dictionary in data.clients.values():
		if int(client["unlock_tier"]) <= tier and not wanted_by(client, designs, tier).is_empty():
			able.append(client)
	if able.is_empty():
		return null
	var client: Dictionary = able[rng.randi() % able.size()]
	var choices := wanted_by(client, designs, tier)
	var product: StringName = choices[rng.randi() % choices.size()]
	var row: Dictionary = data.products[product]
	var contract := Contract.new()
	contract.id = _next_id
	_next_id += 1
	contract.client = StringName(client["id"])
	contract.product = product
	contract.material = StringName(_filament_for(row))
	var colours: Array = data.filaments[contract.material]["colours"]
	# A design in several colours is left to the maker's taste.
	if int(row.get("colour_count", 1)) == 1 and rng.randf() < float(_rules()["colour_chance"]):
		contract.colour = StringName(colours[rng.randi() % colours.size()])
	contract.quantity = rng.randi_range(int(client["quantity"][0]), int(client["quantity"][1]))
	contract.min_quality = int(client["min_quality"])
	contract.min_durability = int(client.get("min_durability", 1))
	contract.unit_price = roundi(float(row["base_price_pence"]) * rng.randf_range(client["price_multiplier"][0], client["price_multiplier"][1]))
	contract.late_pct_per_day = float(client["late_pct_per_day"])
	var asks: Array = client["asks"]
	contract.text = asks[rng.randi() % asks.size()]
	contract.offered_at = minute
	contract.expires_at = minute + float(_rules()["offer_minutes"])
	# Time to print them all on a few printers, with some slack, and never less than a day.
	var print_minutes := float(row["print_minutes"]) * contract.quantity / float(client.get("assumed_printers", _rules()["assumed_printers"]))
	contract.allowed_minutes = maxf(print_minutes * rng.randf_range(client["slack"][0], client["slack"][1]), GameClock.DAY)
	all.append(contract)
	return contract


## The designs a client might ask for: those the business owns in the client's
## categories, and the ones the client brings itself, if the business has
## grown to the `tier` they are made for.
func wanted_by(client: Dictionary, designs: Array[StringName], tier: int) -> Array[StringName]:
	var found: Array[StringName] = []
	for design in designs:
		if data.products.has(design) and client["categories"].has(data.products[design]["category"]):
			found.append(design)
	for supplied: String in client.get("supplies", []):
		if data.products.has(supplied) and int(data.products[supplied]["unlock_tier"]) <= tier and not found.has(StringName(supplied)):
			found.append(StringName(supplied))
	return found


## Why an enquiry can't be taken on, or "" if it can.
func accept_problem(contract: Contract) -> String:
	if contract.status != Status.OFFERED:
		return "No longer on offer"
	if active().size() >= int(_rules()["max_active"]):
		return "You have as many contracts as you can run at once"
	return ""


## Takes an enquiry on. The deadline is the first courier collection after the
## time allowed (`courier_minute` is the minute of the day the courier comes).
func accept(contract: Contract, minute: float, courier_minute: float) -> bool:
	if accept_problem(contract) != "":
		return false
	contract.status = Status.ACTIVE
	contract.accepted_at = minute
	var earliest := minute + contract.allowed_minutes
	var day_start := floorf(earliest / GameClock.DAY) * GameClock.DAY
	contract.due_at = day_start + courier_minute + (GameClock.DAY if earliest > day_start + courier_minute else 0.0)
	return true


func decline(contract: Contract) -> void:
	if contract.status == Status.OFFERED:
		contract.status = Status.DECLINED


## Lapses the enquiries nobody answered in time. Returns them.
func expire(minute: float) -> Array[Contract]:
	var lapsed: Array[Contract] = []
	for contract in offers():
		if minute > contract.expires_at:
			contract.status = Status.EXPIRED
			lapsed.append(contract)
	return lapsed


## True if the client would take an item. `item` describes it:
## { product, material, colour, quality, durability, flawed, plain }.
func wants(contract: Contract, item: Dictionary) -> bool:
	if StringName(item["product"]) != contract.product or item["flawed"] or item["plain"]:
		return false
	if int(item["quality"]) < contract.min_quality or int(item["durability"]) < contract.min_durability:
		return false
	if contract.colour != &"" and StringName(item["colour"]) != contract.colour:
		return false
	return data.filaments[item["material"]]["family"] == data.filaments[contract.material]["family"]


## Pence the whole contract is worth, delivered on time.
func value(contract: Contract) -> int:
	return contract.unit_price * contract.quantity


## Items still to be made or found: not yet with the client or crated up for them.
func remaining(contract: Contract) -> int:
	return contract.quantity - contract.delivered - contract.packed


## Records items going into a crate for the courier.
func pack(contract: Contract, count: int) -> void:
	contract.packed += count


## Whole days past the deadline, counting any part of a day as one.
func days_late(contract: Contract, minute: float) -> int:
	return ceili((minute - contract.due_at) / GameClock.DAY) if minute > contract.due_at else 0


## Pence that would come off the price if the contract were finished at `minute`.
func penalty(contract: Contract, minute: float) -> int:
	return mini(roundi(value(contract) * contract.late_pct_per_day * days_late(contract, minute)), value(contract))


## Records items reaching the client. Returns {} while more are owed, or
## { payment, penalty } in pence once the last has arrived.
func deliver(contract: Contract, count: int, minute: float) -> Dictionary:
	if contract.status != Status.ACTIVE:
		return {}
	contract.delivered = mini(contract.delivered + count, contract.quantity)
	contract.packed = maxi(contract.packed - count, 0)
	if contract.delivered < contract.quantity:
		return {}
	var taken_off := penalty(contract, minute)
	contract.status = Status.DONE
	contract.closed_at = minute
	contract.paid = value(contract) - taken_off
	return {"payment": contract.paid, "penalty": taken_off}


## Ends the contracts that are later than any client will put up with. Returns
## one { contract, payment } for each: what the client pays for what did arrive.
func fail_overdue(minute: float) -> Array[Dictionary]:
	var lost: Array[Dictionary] = []
	for contract in active():
		if days_late(contract, minute) > int(_rules()["max_late_days"]):
			contract.status = Status.FAILED
			contract.closed_at = minute
			contract.paid = roundi(contract.delivered * contract.unit_price * float(_rules()["failed_pay_multiplier"]))
			lost.append({"contract": contract, "payment": contract.paid})
	return lost


## Ends a contract because the client has gone under. Returns the pence the
## administrators pay for what had arrived, at the same cut rate as a contract
## cancelled for lateness.
func bust(contract: Contract, minute: float) -> int:
	if contract.status != Status.ACTIVE:
		return 0
	contract.status = Status.FAILED
	contract.closed_at = minute
	contract.paid = roundi(contract.delivered * contract.unit_price * float(_rules()["failed_pay_multiplier"]))
	return contract.paid


## The plain filament a design is made in: the first it allows.
func _filament_for(row: Dictionary) -> String:
	for allowed: String in row["allowed_filaments"]:
		if data.filaments.has(allowed):
			return allowed
	return FilamentRules.DEFAULT_MATERIAL


func _rules() -> Dictionary:
	return data.settings["contracts"]


func save() -> Dictionary:
	return {"next_id": _next_id, "all": all.map(func(contract: Contract) -> Dictionary: return contract.save())}


## Puts back saved contracts, leaving out any for a client, design or filament
## the game no longer has.
func restore(saved: Dictionary) -> void:
	all.clear()
	for entry: Dictionary in saved["all"]:
		if data.clients.has(entry["client"]) and data.products.has(entry["product"]) and data.filaments.has(entry["material"]):
			all.append(Contract.restored(entry))
	_next_id = int(saved["next_id"])
