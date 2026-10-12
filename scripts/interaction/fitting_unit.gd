class_name FittingUnit
extends Interactable
## A bought fitting standing where the player put it: a bay of shelving, a
## filament rack or a printer rack (a row of data/fittings.json). It only adds
## spaces to the premises' own StorageShelf, FilamentRack or Workbench (its `host`),
## which keeps track of what is on it: clicking it offers the host's actions,
## and the chance to stand it somewhere else.

const MODEL_PATH := "res://assets/models/furniture/%s.glb"

## Id of the row in data/fittings.json.
var fitting: StringName
## The StorageShelf or FilamentRack it belongs to.
var host: Interactable


static func create(p_fitting: StringName, p_host: Interactable) -> FittingUnit:
	var row: Dictionary = Game.data.fittings[p_fitting]
	var unit := FittingUnit.new()
	unit.fitting = p_fitting
	unit.host = p_host
	unit.name = "Fitting_%s" % p_fitting
	unit.display_name = row["name"]
	var stand: Array = row["stand_offset"]
	unit.stand_offset = Vector3(stand[0], stand[1], stand[2])
	unit.add_child((load(MODEL_PATH % row["model"]) as PackedScene).instantiate())
	return unit


func _ready() -> void:
	super()
	add_to_group(&"obstacle")
	add_to_group(&"fitting_unit")


func card_icon() -> String:
	return "stockroom"


func get_actions(agent: Agent) -> Array[Action]:
	var actions := host.get_actions(agent)
	var move := Action.new("Stand it somewhere else...", _choose_spot)
	move.immediate = true
	actions.append(move)
	if in_use():
		actions.append(Action.info("Sell or scrap it (empty it first)"))
	else:
		actions.append(Action.submenu("Sell or scrap it", [sell_action(), scrap_action()]).tuck())
	return actions


## True while anything stands on it: it can't be sold or scrapped until it is empty.
func in_use() -> bool:
	return host.call(&"unit_in_use", self)


## What it would fetch second hand, in pence.
func resale_value() -> int:
	return roundi(float(Game.data.fittings[fitting]["price_pence"]) * float(Game.data.settings["resale"]["fitting_share"]))


## The task of taking it down and boxing it for whoever buys it second hand.
func sell_action() -> Action:
	var action := Action.new("Sell it second hand for %s" % Money.format(resale_value()), _part_with.bind(true))
	action.task_name = "Take down the %s to sell" % display_name.to_lower()
	return action


## The task of taking it down and throwing it out.
func scrap_action() -> Action:
	var action := Action.new("Scrap it for nothing", _part_with.bind(false))
	action.task_name = "Scrap the %s" % display_name.to_lower()
	return action


func _part_with(agent: Agent, sell: bool) -> void:
	if in_use():
		agent.say("The %s has to be empty first" % display_name.to_lower())
		return
	var rules: Dictionary = Game.data.settings["resale"]
	var title := display_name
	var pence := resale_value()
	var tree := get_tree()
	await agent.go_to(self)
	await agent.work(float(rules["scrap_minutes"]))
	if in_use():
		agent.say("The %s has to be empty first" % title.to_lower())
		return
	await agent.reach(func() -> void:
		host.call(&"remove_unit", self)
		# Gone from the room, but not freed until this task, which is its own, is over.
		visible = false
		remove_collider()
		remove_from_group(&"obstacle")
		remove_from_group(&"fitting_unit")
		remove_from_group(&"interactable")
		(tree.get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
		var flat_pack := Node3D.new()
		flat_pack.add_child(DeliveryBox.PRINTER_MODEL.instantiate())
		agent.carry(flat_pack))
	if sell:
		var station: PackingStation = tree.get_first_node_in_group(&"packing_station")
		await agent.go_to(station)
		await agent.work(float(rules["pack_minutes"]))
		agent.release().queue_free()
		await agent.reach(func() -> void: agent.carry(Parcel.create_resale(title, pence)))
		var outbox: Outbox = tree.get_first_node_in_group(&"outbox")
		await agent.go_to(outbox)
		await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))
		Game.notify("%s boxed up for its buyer. You are paid %s when the courier collects it." % [title, Money.format(pence)])
	else:
		await agent.walk_to(tree.get_first_node_in_group(&"bin").global_position)
		await agent.reach(func() -> void: agent.release().queue_free())
		agent.say("Scrapped the %s" % title.to_lower())
	queue_free()


## A shelving unit opens the shelving's panel when clicked, as the shelving
## itself does. A rack has the usual menu.
func wants_panel() -> bool:
	return host is StorageShelf


func open_panel() -> void:
	(host as StorageShelf).open_panel()


## Lets the player pick somewhere else for it to stand.
func choose_spot() -> void:
	Placer.begin(self, fitting, _queue_move, self)


func _choose_spot(_agent: Agent) -> void:
	choose_spot()


func _queue_move(to: Transform3D) -> void:
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	agent.enqueue(Action.new("Move the %s" % display_name.to_lower(), move_to.bind(to)))


## The task of walking over and shifting it to `to`.
func move_to(agent: Agent, to: Transform3D) -> void:
	await agent.go_to(self)
	await agent.reach()
	global_transform = to
	if host.has_method(&"unit_moved"):
		host.call(&"unit_moved", self)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
	await agent.walk_to(get_stand_point())
	await agent.face(global_position)
	await agent.reach()


func save() -> Dictionary:
	return {"fitting": fitting, "x": global_position.x, "z": global_position.z, "yaw": global_rotation.y}


## Where a saved unit stood.
static func saved_transform(data: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(data["yaw"])), Vector3(float(data["x"]), 0.0, float(data["z"])))
