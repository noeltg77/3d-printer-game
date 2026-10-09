class_name Workbench
extends Interactable
## The workbench: printers stand on it, and it is the packing station where a
## finished item becomes a parcel for an order.

## Where printers go on the bench top, relative to the bench.
const PRINTER_SPOTS: Array[Vector3] = [Vector3(-0.42, 0.9, 0.03), Vector3(0.42, 0.9, 0.03)]

var _printers: Array[PrinterStation] = []


func _ready() -> void:
	super()
	add_to_group(&"workbench")


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("Mailer boxes: %d" % Game.packaging)]
	var orders: Array[Action] = []
	for order in Game.market.open_orders():
		orders.append(pack_action(order))
	if orders.is_empty():
		actions.append(Action.info("Pack order (no orders waiting)"))
	else:
		actions.append(Action.submenu("Pack order", orders))
	return actions


## The task of packing one order and taking the parcel to the outbox.
## Disabled, with the reason in its label, if it can't be done yet.
func pack_action(order: Marketplace.Order) -> Action:
	var label := "#%d %s, %s" % [order.id, Game.product_name(order.product), Money.format(order.price)]
	var problem := pack_problem(order)
	var action := Action.new(label if problem == "" else "%s: %s" % [label, problem], _pack.bind(order), problem == "")
	action.task_name = pack_task_name(order)
	return action


static func pack_task_name(order: Marketplace.Order) -> String:
	return "Pack order #%d" % order.id


func free_spots() -> int:
	return PRINTER_SPOTS.size() - _printers.size()


## Sets up a new printer on the next free spot. Null if the bench is full.
func install_printer(printer_id: StringName) -> PrinterStation:
	if free_spots() <= 0:
		return null
	var station := PrinterStation.create(printer_id)
	# A sibling rather than a child, so the bench and printer highlight separately.
	get_parent().add_child(station)
	station.global_transform = global_transform * Transform3D(Basis.IDENTITY, PRINTER_SPOTS[_printers.size()])
	_printers.append(station)
	Game.changed.emit()
	return station


## Why an order can't be packed right now, or "" if it can.
func pack_problem(order: Marketplace.Order) -> String:
	if _shelf().count_of(order.product) == 0:
		return "not printed yet"
	if Game.packaging <= 0:
		return "no mailer boxes"
	return ""


func _pack(agent: Agent, order: Marketplace.Order) -> void:
	if order.status != Marketplace.Status.OPEN or pack_problem(order) != "":
		agent.say("Can't pack order #%d right now" % order.id)
		return
	var shelf := _shelf()
	await agent.go_to(shelf)
	await agent.reach(func() -> void: agent.carry(shelf.take(order.product)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.reach()
	# The item goes in a box and comes back out as a parcel.
	var item := agent.release() as PrintedItem
	Game.packaging -= 1
	Game.market.mark_packed(order, item.durability, item.quality, item.is_flawed())
	item.queue_free()
	Game.changed.emit()
	await agent.reach(func() -> void: agent.carry(Parcel.create(order)))
	var outbox: Outbox = get_tree().get_first_node_in_group(&"outbox")
	await agent.go_to(outbox)
	await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")


func save() -> Dictionary:
	return {"printers": _printers.map(func(station: PrinterStation) -> Dictionary: return station.save())}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data["printers"]:
		if Game.data.printers.has(entry["id"]):
			var station := install_printer(StringName(entry["id"]))
			if station != null:
				station.restore(entry)
