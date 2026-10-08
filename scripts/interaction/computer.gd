class_name Computer
extends Interactable
## The PC. The character sits down at it, which opens the business screens.

## The chair to sit on.
@export var seat_path: NodePath


func get_actions(agent: Agent) -> Array[Action]:
	if agent.seated:
		return [
			Action.new("Open the screen", func(_a: Agent) -> void: _screen().open()),
			Action.new("Stand up", func(a: Agent) -> void: await a.stand_up()),
		]
	return [Action.new("Use computer", _use)]


func _use(agent: Agent) -> void:
	await agent.walk_to(get_stand_point())
	await agent.sit(get_node(seat_path))
	_screen().open()


func _screen() -> PcScreen:
	return get_tree().get_first_node_in_group(&"pc_screen")
