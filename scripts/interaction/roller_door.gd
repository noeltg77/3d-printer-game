class_name RollerDoor
extends Interactable
## The garage door. Rolls up into its housing by squashing towards its top
## edge, which is where the model's pivot is. Set visual_path to the door mesh.

const ROLL_TIME := 1.2
const ROLLED_SCALE := 0.06

var is_open := false


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.new("Close door" if is_open else "Open door", _toggle)]


func _toggle(agent: Agent) -> void:
	await agent.go_to(self)
	await agent.reach()
	is_open = not is_open
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_visual(), "scale:y", ROLLED_SCALE if is_open else 1.0, ROLL_TIME)
	await tween.finished
