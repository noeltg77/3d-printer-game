class_name DeliveryBox
extends Interactable
## A supplier delivery sitting by the door until the character unpacks it:
## spools go to the rack, mailer boxes into stock, spare parts onto the
## shelving, a printer onto the bench, a dryer onto its spot.

const SUPPLIES_MODEL := preload("res://assets/models/props/box_closed_01.glb")
const PRINTER_MODEL := preload("res://assets/models/props/box_closed_02.glb")

var delivery: Supplier.Delivery


static func create(p_delivery: Supplier.Delivery) -> DeliveryBox:
	var box := DeliveryBox.new()
	box.delivery = p_delivery
	box.display_name = "Delivery: %s" % p_delivery.describe()
	box.stand_offset = Vector3(0.65, 0.0, 0.0)
	box.add_child((PRINTER_MODEL if p_delivery.printer != &"" or p_delivery.dryer != &"" else SUPPLIES_MODEL).instantiate())
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
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	if not shelf.can_store_parts(delivery.parts.keys()):
		agent.say("No shelf space for the spare parts")
		return
	var spot: DryerSpot = get_tree().get_first_node_in_group(&"dryer_spot")
	if delivery.dryer != &"" and spot.problem() != "":
		agent.say(spot.problem())
		return
	await agent.go_to(self)
	await agent.reach(_pick_up.bind(agent))
	if delivery.printer != &"":
		var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
		await agent.go_to(bench)
		await agent.reach(func() -> void: bench.install_printer(delivery.printer))
	if delivery.dryer != &"":
		await agent.walk_to(Vector3(spot.global_position.x, 0.0, spot.global_position.z + 0.6))
		await agent.reach(func() -> void: spot.install(delivery.dryer))
	if not delivery.spools.is_empty() or delivery.packaging > 0:
		var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
		await agent.go_to(rack)
		await agent.reach(func() -> void:
			for key in delivery.spools:
				var material := FilamentRules.material_of(key)
				rack.store(Spool.create(StringName(FilamentRules.colour_of(key)),
					float(Game.data.filaments[material]["spool_grams"]), StringName(material)))
			Game.packaging += delivery.packaging
			Game.changed.emit())
	if not delivery.parts.is_empty():
		await agent.go_to(shelf)
		await agent.reach(func() -> void:
			for part in delivery.parts:
				shelf.store_parts(part, delivery.parts[part]))
	agent.release()
	queue_free()


func _pick_up(agent: Agent) -> void:
	remove_collider()
	remove_from_group(&"obstacle")
	remove_from_group(&"delivery_box")
	agent.carry(self)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
