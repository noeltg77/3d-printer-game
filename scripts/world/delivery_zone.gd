extends Node3D
## Where supplier deliveries are dropped off. Each arriving delivery becomes a
## DeliveryBox on the next free spot, in a row along this node's Z axis.

const SPACING := 0.5
const SPOTS := 3
## How much floor a waiting box takes up, in metres.
const BOX := 0.6


func _ready() -> void:
	add_to_group(&"delivery_zone")
	add_to_group(&"keep_clear")
	Game.delivery_arrived.connect(_on_delivery_arrived)


## The floor the row of boxes needs, which furniture must leave free.
func clear_area() -> Rect2:
	var reach := (SPOTS - 1) * SPACING
	return Placer.floor_rect(global_transform, Vector3(0.0, 0.0, reach / 2.0), Vector2(BOX, reach + BOX))


func clear_reason() -> String:
	return "That is where deliveries are left"


## Sets a box down on the next free spot: a delivery, or a printer boxed up off the bench.
func put_down(delivery: Supplier.Delivery) -> void:
	_on_delivery_arrived(delivery)


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
