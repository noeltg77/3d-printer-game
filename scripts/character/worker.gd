class_name Worker
extends Node
## The mind of a member of staff. It sits on an Agent (the same character the
## player drives) and, whenever that character has nothing to do, looks round
## the room for a task that is one of its duties and sets the character to it.
##
## It finds tasks the way the player does: from the action lists of the things
## in the room. An Action with a `duty` is one staff may pick up, and a role's
## `duties` (data/staff.json) say which it does, most pressing first. Two
## workers never go for the same object at once.

## Game seconds between looks round the room.
const THINK_SECONDS := 1.5

## Object being worked on -> the worker on it, so nobody doubles up.
static var _claims: Dictionary[int, Worker] = {}

## Id of the member of staff this is (Staff.team).
var member_id := 0
## Set when their shift ends or they are let go: finish up and walk out.
var leaving := false

var _wait := 0.0
var _exit := Vector3.ZERO

@onready var _agent: Agent = get_parent()


func _ready() -> void:
	_exit = _agent.global_position


func _exit_tree() -> void:
	for target: int in _claims.keys():
		if _claims[target] == self:
			_claims.erase(target)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or _agent.is_busy():
		return
	_wait = THINK_SECONDS
	if leaving:
		_agent.enqueue(Action.new("Going home", _go_home))
		return
	# Nobody starts anything while the game is waiting for a quiet moment to save.
	var world_save: WorldSave = get_tree().get_first_node_in_group(&"world_save")
	if world_save != null and world_save.wants_quiet():
		return
	var job := _find_job()
	if job != null:
		_agent.enqueue(job)


## The first task going that is one of this worker's duties, or null.
func _find_job() -> Action:
	var member := Game.staff.member(member_id)
	if member.is_empty():
		return null
	var things := get_tree().get_nodes_in_group(&"interactable")
	for duty: String in Game.staff.duties(member):
		for thing: Interactable in things:
			if _claims.has(thing.get_instance_id()):
				continue
			for action in _flatten(thing.get_actions(_agent)):
				if action.enabled and action.duty == StringName(duty):
					return _claimed(thing, action)
	return null


## Every action in a menu, with those inside its submenus.
func _flatten(actions: Array[Action]) -> Array[Action]:
	var found: Array[Action] = []
	for action in actions:
		found.append(action)
		found.append_array(_flatten(action.children))
	return found


## The same task, holding its object for this worker while it is done.
func _claimed(thing: Interactable, action: Action) -> Action:
	var target := thing.get_instance_id()
	_claims[target] = self
	var job := Action.new(action.get_task_name(), func(agent: Agent) -> void:
		await action.run.call(agent)
		_claims.erase(target))
	return job


func _go_home(agent: Agent) -> void:
	await agent.walk_to(_exit)
	agent.queue_free()
