class_name Workbench
extends Interactable
## The workbench: printers stand on it, and it is the packing station where a
## finished item becomes a parcel for an order, or a batch of them a crate for
## a contract.

## Where printers go, relative to this bench, in the order they fill. A longer
## bench sets more of them in its scene, and a print farm's also reach onto the
## other benches in the room, which are plain furniture: this one bench owns
## every printer, and is where orders are packed.
@export var printer_spots: Array[Vector3] = [Vector3(-0.42, 0.9, 0.03), Vector3(0.42, 0.9, 0.03)]

var _printers: Array[PrinterStation] = []


func _ready() -> void:
	super()
	add_to_group(&"workbench")


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("Mailer boxes: %d" % Game.packaging)]
	var orders: Array[Action] = []
	for order in Game.open_orders():
		orders.append(pack_action(order))
	if orders.is_empty():
		actions.append(Action.info("Pack order (no orders waiting)"))
	else:
		actions.append(Action.submenu("Pack order", orders))
	var crates: Array[Action] = []
	for contract in Game.contracts.active():
		crates.append(send_action(contract))
	if not crates.is_empty():
		actions.append(Action.submenu("Send to a client", crates))
	return actions


## The task of crating up whatever is ready for a contract and taking it to
## the outbox. Disabled, with the reason in its label, if it can't be done yet.
func send_action(contract: Contracts.Contract) -> Action:
	var ready := Game.contract_ready(contract)
	var label := "%s: %d x %s" % [Game.client_name(contract), ready, Game.product_name(contract.product)]
	var problem := send_problem(contract)
	if problem != "":
		label = "%s: %s (%s)" % [Game.client_name(contract), Game.product_name(contract.product), problem]
	var action := Action.new(label, _send.bind(contract.id), problem == "").for_duty(&"send")
	action.task_name = "Crate up %d for %s" % [ready, Game.client_name(contract)]
	return action


## Why nothing can be sent to a contract's client right now, or "" if it can.
func send_problem(contract: Contracts.Contract) -> String:
	if Game.contracts.remaining(contract) <= 0:
		return "all crated up, waiting for the courier"
	if Game.contract_ready(contract) == 0:
		return "none ready that meet the spec"
	if Game.packaging <= 0:
		return "no mailer boxes"
	return ""


func _send(agent: Agent, contract_id: int) -> void:
	var contract := Game.contracts.by_id(contract_id)
	if contract == null or contract.status != Contracts.Status.ACTIVE or send_problem(contract) != "":
		agent.say("Nothing to send to that client right now")
		return
	var shelf := _shelf()
	await agent.go_to(shelf)
	await agent.reach(func() -> void:
		# The rest ride along out of sight, inside the first.
		var taken := shelf.items_for(contract).slice(0, Game.contracts.remaining(contract))
		for index in taken.size():
			shelf.take_item(taken[index])
			if index == 0:
				agent.carry(taken[0])
			else:
				Interactable.attach(taken[index], taken[0])
				taken[index].visible = false)
	if agent.carried == null:
		return
	await agent.go_to(self)
	var first := agent.carried
	var count := 1 + first.get_children().filter(func(child: Node) -> bool: return child is PrintedItem).size()
	await agent.work(count * float(Game.data.settings["contracts"]["pack_minutes_per_item"]))
	agent.release().queue_free()
	Game.packaging -= 1
	Game.contracts.pack(contract, count)
	Game.changed.emit()
	await agent.reach(func() -> void: agent.carry(Parcel.create_crate(contract.id, count)))
	var outbox: Outbox = get_tree().get_first_node_in_group(&"outbox")
	await agent.go_to(outbox)
	await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))


## The task of packing one order and taking the parcel to the outbox.
## Disabled, with the reason in its label, if it can't be done yet.
func pack_action(order: Marketplace.Order) -> Action:
	var label := "%s %s, %s" % [Game.market_of(order).order_label(order), Game.product_name(order.product), Money.format(order.price)]
	var problem := pack_problem(order)
	var action := Action.new(label if problem == "" else "%s: %s" % [label, problem], _pack.bind(order), problem == "").for_duty(&"pack")
	action.task_name = pack_task_name(order)
	return action


static func pack_task_name(order: Marketplace.Order) -> String:
	return "Pack order %s" % Game.market_of(order).order_label(order)


func free_spots() -> int:
	return printer_spots.size() - _printers.size()


## Sets up a new printer on the next free spot. Null if the bench is full.
func install_printer(printer_id: StringName) -> PrinterStation:
	if free_spots() <= 0:
		return null
	var station := PrinterStation.create(printer_id)
	# A sibling rather than a child, so the bench and printer highlight separately.
	get_parent().add_child(station)
	station.global_transform = global_transform * Transform3D(Basis.IDENTITY, printer_spots[_printers.size()])
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
		agent.say("Can't pack that order right now")
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
	var value := float(Game.data.filaments[item.material]["value_multiplier"])
	if item.is_plain():
		value *= float(Game.data.toggles["multicolour"]["off_price_multiplier"])
		Game.notify("Order %s is going out in one colour, so the buyer pays less" % Game.market_of(order).order_label(order))
	Game.market_of(order).mark_packed(order, item.durability, item.quality, item.is_flawed(), value, item.is_plain())
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
