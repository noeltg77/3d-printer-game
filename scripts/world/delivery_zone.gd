extends Node3D
## Where supplier deliveries are dropped off. Each arriving delivery becomes a
## DeliveryBox on the next free spot, in a row along this node's Z axis.

const SPACING := 0.5
const SPOTS := 3


func _ready() -> void:
	add_to_group(&"delivery_zone")
	Game.delivery_arrived.connect(_on_delivery_arrived)


func _on_delivery_arrived(delivery: Supplier.Delivery) -> void:
	# Boxes still waiting to be unpacked are the ones in the group.
	var taken: Array[int] = []
	for waiting in get_tree().get_nodes_in_group(&"delivery_box"):
		taken.append(waiting.get_meta(&"spot", 0))
	# The first free spot; overflow piles onto the last one.
	var spot := 0
	while spot < SPOTS - 1 and taken.has(spot):
		spot += 1
	_put_down(delivery, spot)


func save() -> Dictionary:
	var waiting: Array[Dictionary] = []
	for box: DeliveryBox in get_tree().get_nodes_in_group(&"delivery_box"):
		waiting.append({"spot": box.get_meta(&"spot", 0), "delivery": box.delivery.save()})
	return {"boxes": waiting}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data["boxes"]:
		var delivery := Supplier.Delivery.restored(entry["delivery"])
		if (delivery.printer == &"" or Game.data.printers.has(delivery.printer)) and (delivery.dryer == &"" or Game.data.dryers.has(delivery.dryer)) \
				and (delivery.fitting == &"" or Game.data.fittings.has(delivery.fitting)):
			_put_down(delivery, int(entry["spot"]))


func _put_down(delivery: Supplier.Delivery, spot: int) -> void:
	var box := DeliveryBox.create(delivery)
	box.set_meta(&"spot", spot)
	get_parent().add_child(box)
	box.global_position = global_transform * Vector3(0.0, 0.0, spot * SPACING)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
