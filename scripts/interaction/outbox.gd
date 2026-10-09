class_name Outbox
extends Interactable
## The spot by the door where packed parcels wait. The courier takes everything
## here once a day, which is when each sale is paid and each crate for a
## contract counts as delivered.

## Parcels sit in a 2 x 2 grid and stack upwards.
const GRID := 0.3
const LAYER_HEIGHT := 0.15

var _parcels: Array[Parcel] = []


func _ready() -> void:
	super()
	add_to_group(&"outbox")
	Game.courier_arrived.connect(_on_courier_arrived)


func get_actions(_agent: Agent) -> Array[Action]:
	var courier := int(Game.data.settings["courier_minute_of_day"])
	return [Action.info("%d parcel%s waiting. Courier collects at %02d:%02d" % [
		_parcels.size(), "" if _parcels.size() == 1 else "s", courier / 60, courier % 60])]


func add(parcel: Parcel) -> void:
	var index := _parcels.size()
	Interactable.attach(parcel, self)
	parcel.position = Vector3((index % 2 - 0.5) * GRID, 0.012 + (index / 4) * LAYER_HEIGHT, (index / 2 % 2 - 0.5) * GRID)
	_parcels.append(parcel)


func _on_courier_arrived() -> void:
	if _parcels.is_empty():
		return
	var total := 0
	var sold := 0
	for parcel in _parcels:
		if parcel.contract > 0:
			Game.ship_contract(parcel.contract, parcel.count)
		else:
			total += parcel.order.price
			sold += 1
			Game.complete_sale(parcel.order)
		parcel.queue_free()
	if sold > 0:
		Game.notify("Courier collected %d parcel%s: %s in sales" % [sold, "" if sold == 1 else "s", Money.format(total)], &"good")
	_parcels.clear()


func save() -> Dictionary:
	return {"parcels": _parcels.map(func(parcel: Parcel) -> Dictionary:
		if parcel.contract > 0:
			return {"contract": parcel.contract, "count": parcel.count}
		return {"market": parcel.order.market, "id": parcel.order.id})}


func restore(data: Dictionary) -> void:
	# Saves from before there was more than one marketplace list bare order ids.
	for id: float in data.get("orders", []):
		var early := Game.market.order_by_id(int(id))
		if early != null:
			add(Parcel.create(early))
	for entry: Dictionary in data.get("parcels", []):
		if entry.has("contract"):
			if Game.contracts.by_id(int(entry["contract"])) != null:
				add(Parcel.create_crate(int(entry["contract"]), int(entry["count"])))
			continue
		var shop: Marketplace = Game.markets.get(StringName(entry["market"]))
		var order := shop.order_by_id(int(entry["id"])) if shop != null else null
		if order != null:
			add(Parcel.create(order))
