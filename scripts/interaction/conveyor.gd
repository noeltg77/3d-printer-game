class_name Conveyor
extends Interactable
## An overhead conveyor that carries finished prints from the printers to the
## shelving, so nobody has to. This script goes on its control cabinet, which is
## all there is until the kit (an upgrade with `fixture` "conveyor") has been
## bought and fitted from here; then the belt goes up.
##
## A printer with an auto-eject plate hands its prints over as they finish
## (PrinterStation). Each rises to the belt, rides to the end and drops onto the
## shelving. A print with nowhere to go waits at the end of the belt.

const FIXTURE := "conveyor"
## Metres a second along the belt, and seconds to rise to it and drop off it.
const SPEED := 1.2
const LIFT_TIME := 0.8
## Seconds between tries at shelving a print that found the shelves full.
const RETRY_SECONDS := 1.0

## The belt, and where its model's origin goes in the room.
@export var belt_scene: PackedScene
@export var belt_position := Vector3.ZERO

var installed := false

var _belt: Node3D = null
## Prints on the belt, and those at the end of it waiting for shelf space.
var _riding: Array[PrintedItem] = []
var _waiting: Array[PrintedItem] = []
var _retry := 0.0


func _ready() -> void:
	super()
	add_to_group(&"conveyor")


func _process(delta: float) -> void:
	if _waiting.is_empty():
		return
	_retry -= delta
	if _retry <= 0.0:
		_retry = RETRY_SECONDS
		for item in _waiting.duplicate():
			if _shelf().store(item):
				_waiting.erase(item)


func card_icon() -> String:
	return "settings"


func get_actions(_agent: Agent) -> Array[Action]:
	if installed:
		var carrying := _riding.size() + _waiting.size()
		var lines: Array[Action] = [Action.info("Conveyor running: %d on the belt" % carrying)]
		if not _waiting.is_empty():
			lines.append(Action.info("%d waiting for room on the shelving" % _waiting.size()))
		return lines
	var kit := kit_id()
	if kit == &"" or _shelf().spare_count(kit) == 0:
		return [Action.info("No conveyor fitted (buy the kit at the PC)")]
	var row: Dictionary = Game.data.upgrades[kit]
	var fit := Action.new("Fit the %s (%s)" % [String(row["name"]).to_lower(), GameClock.duration_label(row["install_minutes"])], _fit)
	fit.task_name = "Fit the conveyor"
	return [fit]


## Id of the upgrade that is the conveyor kit, or empty if the game has none.
static func kit_id() -> StringName:
	for upgrade: Dictionary in Game.data.upgrades.values():
		if upgrade.get("fixture", "") == FIXTURE:
			return StringName(upgrade["id"])
	return &""


## True if the belt can take `count` more prints and there will be shelf space for them.
func can_take(count: int) -> bool:
	return installed and _shelf().free_slots() - _riding.size() - _waiting.size() >= count


## Takes prints from a printer whose plate is at `from` and carries them to the shelving.
func send(items: Array[PrintedItem], from: Vector3) -> void:
	var start: Vector3 = (_belt.find_child("belt_start", true, false) as Node3D).global_position
	var end: Vector3 = (_belt.find_child("belt_end", true, false) as Node3D).global_position
	for index in items.size():
		var item := items[index]
		if item.get_parent() != null:
			item.get_parent().remove_child(item)
		get_parent().add_child(item)
		item.scale = Vector3.ONE
		item.global_position = from
		_riding.append(item)
		# Onto the belt level with the printer, or at the near end if it is beyond it.
		var along := clampf((from - start).dot(start.direction_to(end)), 0.0, start.distance_to(end))
		var joins := start + start.direction_to(end) * along
		var tween := create_tween()
		tween.tween_interval(index * 0.5)
		tween.tween_property(item, "global_position", joins, LIFT_TIME)
		tween.tween_property(item, "global_position", end, joins.distance_to(end) / SPEED)
		tween.tween_callback(_arrive.bind(item))


func install() -> void:
	if installed:
		return
	installed = true
	_belt = belt_scene.instantiate()
	get_parent().add_child(_belt)
	_belt.global_position = belt_position
	Game.changed.emit()


func _arrive(item: PrintedItem) -> void:
	_riding.erase(item)
	if not _shelf().store(item):
		_waiting.append(item)


func _fit(agent: Agent) -> void:
	var shelf := _shelf()
	var kit := kit_id()
	if installed or kit == &"" or shelf.spare_count(kit) == 0:
		agent.say("Can't fit the conveyor right now")
		return
	await agent.go_to(shelf.spot(kit))
	await agent.reach(func() -> void: agent.carry(shelf.take_spare(kit)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.work(float(Game.data.upgrades[kit]["install_minutes"]))
	await agent.reach(func() -> void:
		agent.release().queue_free()
		install())
	agent.say("The conveyor is running")


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")


func save() -> Dictionary:
	var carried: Array[Dictionary] = []
	for item: PrintedItem in _riding + _waiting:
		carried.append(item.save())
	return {"installed": installed, "carried": carried}


## Puts the belt back up. Whatever was on it is at the end, waiting to be shelved.
func restore(data: Dictionary) -> void:
	if not bool(data.get("installed", false)):
		return
	install()
	var end: Vector3 = (_belt.find_child("belt_end", true, false) as Node3D).global_position
	for entry: Dictionary in data.get("carried", []):
		var item := PrintedItem.restored(entry)
		if item != null:
			get_parent().add_child(item)
			item.global_position = end
			_waiting.append(item)
