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


func get_actions(agent: Agent) -> Array[Action]:
	var actions := host.get_actions(agent)
	var move := Action.new("Stand it somewhere else...", _choose_spot)
	move.immediate = true
	actions.append(move)
	return actions


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
