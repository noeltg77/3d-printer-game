class_name WorldSave
extends Node
## Ties the premises to the save file, and carries the world from one premises
## to the next when the business moves. On starting the scene it loads the save,
## if there is one, and has each part of the world rebuild itself from it. From
## then on it saves whenever the character is between tasks: as each run of
## jobs ends, every so often while standing idle, and when the game is closed.
##
## Saving only between tasks means nothing is ever half carried in a save. The
## price is that jobs still waiting in the queue are not kept. With staff on
## the floor everybody has to be between tasks at once, so while a save is
## owed nobody starts a new one (wants_quiet) and it happens as the last of
## them finishes.

## Real seconds between saves when one isn't asked for.
const AUTOSAVE_GAP := 20.0
## Save key -> group of the node that holds that part of the world. Restored in
## this order: printers first, then what they and the shelves hold.
const PARTS := {
	"bench": &"workbench",
	"rack": &"filament_rack",
	"dryer": &"dryer_spot",
	"shelf": &"print_storage",
	"outbox": &"outbox",
	"deliveries": &"delivery_zone",
	"character": &"player",
}

var _last_save_msec := 0
## A save was asked for mid-task and is owed as soon as the task ends.
var _owed := false


func _ready() -> void:
	add_to_group(&"world_save")
	var tick := Timer.new()
	tick.wait_time = AUTOSAVE_GAP
	tick.ignore_time_scale = true
	tick.autostart = true
	tick.timeout.connect(_autosave)
	add_child(tick)
	# Once every node in the scene is ready to be filled.
	_load.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _agent() != null and _everyone_between_tasks():
		Game.save_game(capture())


func _process(_delta: float) -> void:
	if _owed and _everyone_between_tasks():
		save_now()


## True while a save is waiting for everybody to finish what they are doing.
## Staff don't start anything new until it has happened.
func wants_quiet() -> bool:
	return _owed


## True when neither the player's character nor any member of staff is part
## way through a task.
func _everyone_between_tasks() -> bool:
	if not _agent().is_between_tasks():
		return false
	for worker: Agent in get_tree().get_nodes_in_group(&"staff"):
		if not worker.is_between_tasks():
			return false
	return true


## The state of everything in the scene that a save needs.
func capture() -> Dictionary:
	var world := {}
	for key: String in PARTS:
		var node := get_tree().get_first_node_in_group(PARTS[key])
		if node != null:
			world[key] = node.call(&"save")
	return world


## Saves now if the character is between tasks, or as soon as they are.
## Returns true if it was saved straight away.
func save_now() -> bool:
	if not _everyone_between_tasks():
		_owed = true
		return false
	_owed = false
	_last_save_msec = Time.get_ticks_msec()
	return Game.save_game(capture())


## Moves the business to other premises, taking everything along: printers,
## spools, stock, parcels and deliveries. False if it can't be done.
func move(place: StringName) -> bool:
	var world := capture()
	# Where the character stood means nothing in a different room.
	world.erase("character")
	if not Game.move_to(place):
		return false
	Game.hand_over(world)
	get_tree().change_scene_to_file(Game.premises_row()["scene"])
	return true


func _load() -> void:
	var arrived := Game.has_handover()
	var world := Game.take_handover() if arrived else Game.load_game()
	# The save may belong to premises other than the scene that was started.
	var scene: String = Game.premises_row()["scene"]
	if get_tree().current_scene.scene_file_path != scene:
		Game.hand_over(world)
		get_tree().change_scene_to_file(scene)
		return
	for key: String in PARTS:
		var node := get_tree().get_first_node_in_group(PARTS[key])
		if node != null and world.has(key):
			node.call(&"restore", world[key])
	_agent().became_idle.connect(_autosave)
	Game.changed.emit()
	if arrived:
		save_now()


func _autosave() -> void:
	var due := Time.get_ticks_msec() - _last_save_msec >= AUTOSAVE_GAP * 1000.0
	if due or _owed:
		save_now()


func _agent() -> Agent:
	return get_tree().get_first_node_in_group(&"player")
