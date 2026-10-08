class_name Workbench
extends Interactable
## The workbench. A stand-in task for now; post-processing and packing happen
## here from Phase 3.


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.new("Tidy the bench", _tidy)]


func _tidy(agent: Agent) -> void:
	await agent.go_to(self)
	for i in 3:
		await agent.reach()
