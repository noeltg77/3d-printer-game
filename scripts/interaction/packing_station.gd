class_name PackingStation
extends Interactable
## The packing station: where the boxes, bags and envelopes are kept, and
## where a finished item becomes a parcel for an order, or a batch of them a
## crate for a contract.
##
## What is in stock shows as piles in the model's `stock_slot_*` markers, a
## kind to a slot. An order is packed on the `pack_spot` marker: the packaging
## is laid open there, the item goes in, and it is closed up.

## Real seconds (at 1x) for the item to drop into its packaging, and for the flaps to shut.
const DROP_SECONDS := 0.35
const CLOSE_SECONDS := 0.4
## How much of the packaging's width an item may fill once it is inside.
const FILL := 0.8

var _stock_slots: Array[Node3D] = []
var _pack_spot: Node3D = null


func _ready() -> void:
	super()
	add_to_group(&"packing_station")
	_stock_slots.assign(find_children("stock_slot_*", "Node3D", true, false))
	_stock_slots.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	_pack_spot = find_child("pack_spot", true, false)
	Game.changed.connect(_show_stock)
	_show_stock()


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = []
	for kind: String in Game.data.packaging:
		if Game.packaging_count(StringName(kind)) > 0:
			actions.append(Action.info("%s: %d" % [Game.data.packaging[kind]["name"], Game.packaging_count(StringName(kind))]))
	if actions.is_empty():
		actions.append(Action.info("No packaging: buy some at %s" % Game.data.settings["supplier"]["hardware_shop"]))
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


## Why an order can't be packed right now, or "" if it can.
func pack_problem(order: Marketplace.Order) -> String:
	if _shelf().count_of(order.product) == 0:
		return "not printed yet"
	return wrap_problem(order)


## Why there is nothing to send an order in, or "" if there is.
static func wrap_problem(order: Marketplace.Order) -> String:
	var terms := Game.shipping_terms(order.product, Game.market_of(order))
	if terms.is_empty():
		return "no courier will take it"
	if Game.packaging_count(StringName(terms["packaging"])) <= 0:
		return "no %s" % Game.packaging_plural(StringName(terms["packaging"]))
	return ""


func _pack(agent: Agent, order: Marketplace.Order) -> void:
	if order.status != Marketplace.Status.OPEN or pack_problem(order) != "":
		agent.say("Can't pack that order right now")
		return
	var shelf := _shelf()
	await agent.go_to(shelf.spot(order.product))
	await agent.reach(func() -> void: agent.carry(shelf.take(order.product)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	var item := agent.carried as PrintedItem
	var shop := Game.market_of(order)
	var terms := Game.shipping_terms(order.product, shop)
	# The last of the packaging may have gone while this was queued.
	if order.status != Marketplace.Status.OPEN or terms.is_empty() or not Game.use_packaging(StringName(terms["packaging"])):
		agent.say("Can't pack that order right now")
		await agent.go_to(shelf.spot(item))
		await agent.reach(func() -> void: shelf.store(agent.release()))
		return
	var kind: Dictionary = Game.data.packaging[terms["packaging"]]
	var parcel := Parcel.create(order, StringName(kind["id"]))
	Interactable.attach(parcel, _pack_spot)
	parcel.set_open(1.0)
	await agent.reach(func() -> void:
		Interactable.attach(agent.release(), _pack_spot)
		item.position.y = parcel.height + 0.02)
	# The item goes in, shrunk to fit if the model is bigger than the packaging.
	var across: float = kind["look"]["size"][0]
	var fit := minf(1.0, FILL * across / maxf(maxf(item.footprint.x, item.footprint.y), 0.01))
	var drop := create_tween().set_parallel()
	drop.tween_property(item, "position:y", 0.01, DROP_SECONDS)
	drop.tween_property(item, "scale", Vector3.ONE * fit, DROP_SECONDS)
	await drop.finished
	await agent.work(float(kind["pack_minutes"]))
	item.visible = false
	await parcel.close(CLOSE_SECONDS)
	var value := float(Game.data.filaments[item.material]["value_multiplier"])
	if item.is_plain():
		value *= float(Game.data.toggles["multicolour"]["off_price_multiplier"])
		Game.notify("Order %s is going out in one colour, so the buyer pays less" % shop.order_label(order))
	shop.mark_packed(order, item.durability, item.quality, item.is_flawed(), value, item.is_plain(), terms)
	item.queue_free()
	Game.changed.emit()
	await agent.reach(func() -> void: agent.carry(parcel))
	var outbox: Outbox = get_tree().get_first_node_in_group(&"outbox")
	await agent.go_to(outbox)
	await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))


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
	if crate_kind() == &"":
		return "no boxes"
	return ""


## The box a crate for a client is made up from: the biggest in stock. &"" if there is none.
static func crate_kind() -> StringName:
	var best: StringName = &""
	for kind: String in Game.data.packaging:
		var row: Dictionary = Game.data.packaging[kind]
		if row["kind"] == "box" and Game.packaging_count(StringName(kind)) > 0:
			best = StringName(kind)
	return best


func _send(agent: Agent, contract_id: int) -> void:
	var contract := Game.contracts.by_id(contract_id)
	if contract == null or contract.status != Contracts.Status.ACTIVE or send_problem(contract) != "":
		agent.say("Nothing to send to that client right now")
		return
	var shelf := _shelf()
	await agent.go_to(shelf.spot(contract.product))
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
	var crate := Parcel.create_crate(contract.id, count)
	Interactable.attach(crate, _pack_spot)
	crate.set_open(1.0)
	await agent.reach(func() -> void:
		Interactable.attach(agent.release(), _pack_spot)
		first.visible = false)
	await agent.work(count * float(Game.data.settings["contracts"]["pack_minutes_per_item"]))
	first.queue_free()
	Game.use_packaging(crate_kind())
	await crate.close(CLOSE_SECONDS)
	Game.contracts.pack(contract, count)
	Game.changed.emit()
	await agent.reach(func() -> void: agent.carry(crate))
	var outbox: Outbox = get_tree().get_first_node_in_group(&"outbox")
	await agent.go_to(outbox)
	await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))


## Puts a pile in a slot for each kind of packaging in stock, in the table's order.
func _show_stock() -> void:
	var kinds: Array[String] = []
	for kind: String in Game.data.packaging:
		if Game.packaging_count(StringName(kind)) > 0:
			kinds.append(kind)
	for index in _stock_slots.size():
		var slot := _stock_slots[index]
		var wanted := kinds[index] if index < kinds.size() else ""
		if slot.get_meta(&"kind", "") == wanted:
			continue
		slot.set_meta(&"kind", wanted)
		for pile in slot.get_children():
			pile.queue_free()
		if wanted != "":
			slot.add_child((load(GameData.PACKAGING_STACK % Game.data.packaging[wanted]["model"]) as PackedScene).instantiate())


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")
