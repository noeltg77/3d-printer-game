class_name Action
extends RefCounted
## Something the player can pick from an object's menu. Choosing it queues `run`
## on the character, who then carries out the whole task.

var label: String
## What to call the task while it is queued or running. The label if empty;
## set it when the label only makes sense inside its submenu.
var task_name := ""
## Coroutine taking the Agent that will do the task.
var run: Callable
var enabled := true
## Runs the moment it is picked instead of joining the character's queue.
## For entries that open a dialog rather than start a task.
var immediate := false
## If not empty this entry opens a submenu instead of running.
var children: Array[Action] = []
## The kind of job this is, if staff may pick it up for themselves: one of the
## duties in data/staff.json. Empty for something only the player decides.
var duty: StringName = &""


func _init(p_label: String, p_run := Callable(), p_enabled := true) -> void:
	label = p_label
	run = p_run
	enabled = p_enabled


func get_task_name() -> String:
	return label if task_name.is_empty() else task_name


## Marks the action as a job staff with that duty may pick up. Returns it.
func for_duty(p_duty: StringName) -> Action:
	duty = p_duty
	return self


## A greyed-out line that just tells the player something.
static func info(text: String) -> Action:
	return Action.new(text, Callable(), false)


static func submenu(p_label: String, p_children: Array[Action]) -> Action:
	var action := Action.new(p_label)
	action.children = p_children
	return action
