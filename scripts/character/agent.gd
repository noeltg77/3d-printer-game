class_name Agent
extends Node3D
## The character as a worker: takes queued Actions and carries them out one at
## a time, walking, reaching, carrying and sitting as each task asks.
## Task code drives it with `await`: go_to(), reach(), carry(), release(), sit().

## The current task or the queue changed.
signal status_changed
## Went from busy to having nothing left to do.
signal became_idle
## The character has something to tell the player, e.g. why a task was dropped.
signal said(text: String)

const WALK_SPEED := 1.7
const TURN_SPEED := 10.0
const SEAT_TIME := 0.3

signal _arrived

var current_label := ""
var carried: Node3D = null
var seated := false

var _queue: Array[Action] = []
var _busy := false
var _strolling := false
var _path: PackedVector3Array = []
var _path_index := 0
var _seat_return := Vector3.ZERO

@onready var rig: CharacterRig = $Rig


func _ready() -> void:
	add_to_group(&"player")


func _process(delta: float) -> void:
	if _path.is_empty():
		return
	var to_next := _path[_path_index] - global_position
	var step := WALK_SPEED * delta
	if to_next.length() <= step:
		global_position = _path[_path_index]
		_path_index += 1
		if _path_index >= _path.size():
			_path = []
			rig.pose = CharacterRig.Pose.IDLE
			_arrived.emit()
		return
	var direction := to_next.normalized()
	global_position += direction * step
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-TURN_SPEED * delta))


func is_busy() -> bool:
	return _busy


func get_queued_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for action in _queue:
		labels.append(action.get_task_name())
	return labels


## Adds a task to the end of the queue and starts on it if idle.
func enqueue(action: Action) -> void:
	_queue.append(action)
	status_changed.emit()
	if not _busy:
		_run_queue()


## Free walk from a click on the floor. Only when idle; clicking again while
## strolling changes the destination.
func stroll_to(point: Vector3) -> void:
	if _strolling:
		_set_path(point)
	elif not _busy:
		enqueue(Action.new("Walking", _stroll.bind(point)))


func say(text: String) -> void:
	said.emit(text)


## Walks to a point on the floor, round any obstacles.
func walk_to(point: Vector3) -> void:
	if seated:
		await stand_up()
	if _set_path(point):
		await _arrived


## Walks to where an Interactable is used from, then turns to face it.
func go_to(target: Interactable) -> void:
	await walk_to(target.get_stand_point())
	await face(target.global_position)


func face(point: Vector3) -> void:
	var offset := point - global_position
	var yaw := rotation.y + angle_difference(rotation.y, atan2(offset.x, offset.z))
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", yaw, 0.15)
	await tween.finished


## Reaches forward. `at_peak` runs at full stretch: the moment to grab or place.
func reach(at_peak := Callable()) -> void:
	rig.reach()
	await rig.reach_peaked
	if at_peak.is_valid():
		at_peak.call()
	await get_tree().create_timer(CharacterRig.REACH_TIME / 2.0).timeout


## Takes hold of an item. Does nothing if given null.
func carry(item: Node3D) -> void:
	if item == null:
		return
	Interactable.attach(item, rig.get_carry_socket())
	carried = item
	rig.carrying = true


## Lets go of the carried item and returns it, for the caller to put somewhere.
func release() -> Node3D:
	var item := carried
	carried = null
	rig.carrying = false
	return item


## Sits on `seat`, facing the way it faces. Stands up again before the next walk.
func sit(seat: Node3D) -> void:
	_seat_return = global_position
	var yaw := rotation.y + angle_difference(rotation.y, seat.global_rotation.y)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", seat.global_position, SEAT_TIME)
	tween.tween_property(self, "rotation:y", yaw, SEAT_TIME)
	rig.pose = CharacterRig.Pose.SIT
	seated = true
	await tween.finished


func stand_up() -> void:
	rig.pose = CharacterRig.Pose.IDLE
	seated = false
	var tween := create_tween()
	tween.tween_property(self, "global_position", _seat_return, SEAT_TIME)
	await tween.finished


func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var action: Action = _queue.pop_front()
		current_label = action.get_task_name()
		status_changed.emit()
		await action.run.call(self)
	current_label = ""
	_busy = false
	status_changed.emit()
	became_idle.emit()


func _stroll(_agent: Agent, point: Vector3) -> void:
	_strolling = true
	await walk_to(point)
	_strolling = false


## Starts walking towards `point`. False if there is nowhere to go.
func _set_path(point: Vector3) -> bool:
	var grid: FloorGrid = get_tree().get_first_node_in_group(&"floor_grid")
	var path := grid.find_path(global_position, point)
	if path.is_empty():
		return false
	_path = path
	_path_index = 0
	rig.pose = CharacterRig.Pose.WALK
	return true
