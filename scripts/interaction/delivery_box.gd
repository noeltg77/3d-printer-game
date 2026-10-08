class_name DeliveryBox
extends Interactable
## A supplier delivery sitting by the door until the character unpacks it:
## spools go to the rack, mailer boxes into stock, a printer onto the bench.

const SUPPLIES_MODEL := preload("res://assets/models/props/box_closed_01.glb")
const PRINTER_MODEL := preload("res://assets/models/props/box_closed_02.glb")

var delivery: Supplier.Delivery


static func create(p_delivery: Supplier.Delivery) -> DeliveryBox:
	var box := DeliveryBox.new()
	box.delivery = p_delivery
	box.display_name = "Delivery: %s" % p_delivery.describe()
	box.stand_offset = Vector3(0.65, 0.0, 0.0)
	box.add_child((PRINTER_MODEL if p_delivery.printer != &"" else SUPPLIES_MODEL).instantiate())
	return box


func _ready() -> void:
	super()
	add_to_group(&"delivery_box")
	add_to_group(&"obstacle")


func get_actions(_agent: Agent) -> Array[Action]:
	var action := Action.new("Unpack", _unpack)
	action.task_name = "Unpack %s" % delivery.describe().to_lower()
	return [action]


func _unpack(agent: Agent) -> void:
	await agent.go_to(self)
	await agent.reach(_pick_up.bind(agent))
	if delivery.printer != &"":
		var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
		await agent.go_to(bench)
		await agent.reach(func() -> void: bench.install_printer(delivery.printer))
	else:
		var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
		await agent.go_to(rack)
		await agent.reach(func() -> void:
			for colour in delivery.spools:
				rack.store(Spool.create(colour))
			Game.packaging += delivery.packaging
			Game.changed.emit())
	agent.release()
	queue_free()


func _pick_up(agent: Agent) -> void:
	remove_collider()
	remove_from_group(&"obstacle")
	remove_from_group(&"delivery_box")
	agent.carry(self)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
