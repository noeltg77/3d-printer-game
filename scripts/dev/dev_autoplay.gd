extends Node
## Dev autoload: plays the game from the command line by picking menu actions,
## so a change can be checked end to end without clicking. Goes through the same
## get_actions() menus the player uses. Does nothing unless asked (after `--`):
##   --autoplay="Finisher 3>Load filament>Red;Finisher 3>Start print;wait>20;PC>Use computer"
##       Steps separated by `;`. Each is an object's display name then the menu
##       labels to pick (matched by prefix), `wait>seconds`, or `click>x,y` for
##       a real left click at a screen position. A step starts once the
##       character has finished the one before.
##   --time-scale=4   run the whole game faster


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time-scale="):
			Engine.time_scale = arg.trim_prefix("--time-scale=").to_float()
		elif arg.begins_with("--autoplay="):
			_play(arg.trim_prefix("--autoplay=").split(";", false))


func _play(steps: PackedStringArray) -> void:
	await get_tree().create_timer(0.5).timeout
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	for step in steps:
		if agent.is_busy():
			await agent.became_idle
		var parts := step.split(">")
		if parts[0] == "wait":
			await get_tree().create_timer(parts[1].to_float()).timeout
			continue
		if parts[0] == "click":
			await _click(Vector2(parts[1].get_slice(",", 0).to_float(), parts[1].get_slice(",", 1).to_float()))
			continue
		var action := _find_action(agent, parts)
		if action == null or not action.enabled:
			push_error("Autoplay: can't do '%s'" % step)
			continue
		print("Autoplay: %s" % step)
		agent.enqueue(action)
	if agent.is_busy():
		await agent.became_idle
	print("Autoplay: finished")


## Moves the mouse to a screen position and left clicks, as real input.
func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await get_tree().create_timer(0.3).timeout
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = at
		button.global_position = at
		Input.parse_input_event(button)
		await get_tree().process_frame
	print("Autoplay: click %s" % at)


func _find_action(agent: Agent, parts: PackedStringArray) -> Action:
	var actions: Array[Action] = []
	for node: Interactable in get_tree().get_nodes_in_group(&"interactable"):
		if node.display_name == parts[0]:
			actions = node.get_actions(agent)
	var found: Action = null
	for label in parts.slice(1):
		found = null
		for candidate in actions:
			if candidate.label.begins_with(label):
				found = candidate
		if found == null:
			return null
		actions = found.children
	return found
