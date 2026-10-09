class_name StaffRoom
extends Node3D
## Where staff come in and go home: put it just inside the door. It keeps one
## character on the floor for every member of staff whose shift it is, and
## sends them out again when the shift ends or they are let go.

const CHARACTER := preload("res://scenes/characters/player.tscn")
const LOOK_PATH := "res://assets/models/characters/%s.glb"
## Real seconds between checks of who should be in.
const CHECK_SECONDS := 0.5

## Member id -> their character on the floor.
var _workers: Dictionary[int, Agent] = {}
var _wait := 0.0


func _ready() -> void:
	add_to_group(&"staff_room")


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_SECONDS
	var minute_of_day := fmod(Game.clock.minutes, GameClock.DAY)
	for member in Game.staff.team:
		if Game.staff.on_shift(member, minute_of_day) and not _workers.has(int(member["id"])):
			_bring_in(member)
	for id: int in _workers.keys():
		var agent := _workers[id]
		if not is_instance_valid(agent):
			_workers.erase(id)
			continue
		var member := Game.staff.member(id)
		if member.is_empty() or not Game.staff.on_shift(member, minute_of_day):
			(agent.get_node(^"Worker") as Worker).leaving = true


## The characters on the floor now.
func workers() -> Array[Agent]:
	var found: Array[Agent] = []
	for agent: Agent in _workers.values():
		if is_instance_valid(agent):
			found.append(agent)
	return found


func _bring_in(member: Dictionary) -> void:
	var agent: Agent = CHARACTER.instantiate()
	agent.is_player = false
	agent.name = "Staff_%d" % int(member["id"])
	(agent.get_node(^"Rig") as CharacterRig).model_override = load(LOOK_PATH % member["look"])
	get_parent().add_child(agent)
	agent.global_position = Vector3(global_position.x, 0.0, global_position.z)
	var mind := Worker.new()
	mind.name = "Worker"
	mind.member_id = int(member["id"])
	agent.add_child(mind)
	_workers[int(member["id"])] = agent
