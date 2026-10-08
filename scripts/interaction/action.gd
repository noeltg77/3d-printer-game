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
## If not empty this entry opens a submenu instead of running.
var children: Array[Action] = []


func _init(p_label: String, p_run := Callable(), p_enabled := true) -> void:
	label = p_label
	run = p_run
	enabled = p_enabled


func get_task_name() -> String:
	return label if task_name.is_empty() else task_name


## A greyed-out line that just tells the player something.
static func info(text: String) -> Action:
	return Action.new(text, Callable(), false)


static func submenu(p_label: String, p_children: Array[Action]) -> Action:
	var action := Action.new(p_label)
	action.children = p_children
	return action
