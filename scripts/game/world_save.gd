class_name WorldSave
extends Node
## Ties the premises to the save file. On starting the scene it loads the save,
## if there is one, and has each part of the world rebuild itself from it. From
## then on it saves whenever the character is between tasks: as each run of
## jobs ends, every so often while standing idle, and when the game is closed.
##
## Saving only between tasks means nothing is ever half carried in a save. The
## price is that jobs still waiting in the queue are not kept.

## Real seconds between saves when one isn't asked for.
const AUTOSAVE_GAP := 20.0
## Save key -> group of the node that holds that part of the world. Restored in
## this order: printers first, then what they and the shelves hold.
const PARTS := {
	"bench": &"workbench",
	"rack": &"filament_rack",
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _agent() != null and _agent().is_between_tasks():
		Game.save_game(capture())


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
	if not _agent().is_between_tasks():
		_owed = true
		return false
	_owed = false
	_last_save_msec = Time.get_ticks_msec()
	return Game.save_game(capture())


func _load() -> void:
	var world := Game.load_game()
	for key: String in PARTS:
		var node := get_tree().get_first_node_in_group(PARTS[key])
		if node != null and world.has(key):
			node.call(&"restore", world[key])
	_agent().became_idle.connect(_autosave)
	Game.changed.emit()


func _autosave() -> void:
	var due := Time.get_ticks_msec() - _last_save_msec >= AUTOSAVE_GAP * 1000.0
	if (due or _owed) and _agent().is_between_tasks():
		save_now()


func _agent() -> Agent:
	return get_tree().get_first_node_in_group(&"player")
