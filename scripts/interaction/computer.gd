class_name Computer
extends Interactable
## The PC. For now the character just sits down at it; the business screens
## open from here in Phase 3.

## The chair to sit on.
@export var seat_path: NodePath


func get_actions(agent: Agent) -> Array[Action]:
	if agent.seated:
		return [Action.new("Stand up", func(a: Agent) -> void: await a.stand_up())]
	return [Action.new("Use computer", _use)]


func _use(agent: Agent) -> void:
	await agent.walk_to(get_stand_point())
	await agent.sit(get_node(seat_path))
