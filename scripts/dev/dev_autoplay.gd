extends Node
## Dev autoload: plays the game from the command line by picking menu actions,
## so a change can be checked end to end without clicking. Goes through the same
## get_actions() menus the player uses. Does nothing unless asked (after `--`):
##   --autoplay="Finisher 3>Load filament>Red;Finisher 3>Start print;wait>20;PC>Use computer"
##       Steps separated by `;`. Each is an object's display name then the menu
##       labels to pick (matched by prefix), `wait>seconds`, `click>x,y` for
##       a real left click at a screen position, or `call>expression` to run
##       an expression on the Game autoload (what the PC screens would do),
##       e.g. call>buy_design("phone_stand"), or `on>group>expression` to
##       run one on the first node in a group, e.g.
##       on>print_dialog>choose("cable_management_clips_x12","draft"). `shot>file.png` saves a
##       screenshot at that point and `quit` exits. A step starts once the
##       character has finished the one before.
##   --time-scale=8   run the whole game faster


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time-scale="):
			Game.set_speed(arg.trim_prefix("--time-scale=").to_float())
		elif arg.begins_with("--autoplay="):
			_play(arg.trim_prefix("--autoplay=").split(";", false))


func _play(steps: PackedStringArray) -> void:
	await get_tree().create_timer(0.5).timeout
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	for step in steps:
		# The scene may have been reloaded by the last step (starting a new game).
		if not is_instance_valid(agent):
			agent = get_tree().get_first_node_in_group(&"player")
		# A character held at the PC has jobs queued but won't start them, so
		# there is nothing to wait for.
		if agent.is_busy() and not agent.held:
			await agent.became_idle
		var parts := step.split(">")
		if parts[0] == "wait":
			await get_tree().create_timer(parts[1].to_float()).timeout
			continue
		if parts[0] == "shot":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(parts[1])
			print("Autoplay: saved %s" % parts[1])
			continue
		if parts[0] == "quit":
			get_tree().quit()
			return
		if parts[0] == "call":
			var expression := Expression.new()
			var result: Variant = null
			if expression.parse(parts[1]) == OK:
				result = expression.execute([], Game)
			print("Autoplay: %s -> %s" % [parts[1], result])
			continue
		if parts[0] == "click":
			await _click(Vector2(parts[1].get_slice(",", 0).to_float(), parts[1].get_slice(",", 1).to_float()))
			continue
		if parts[0] == "on":
			var expression := Expression.new()
			var target := get_tree().get_first_node_in_group(parts[1])
			var result: Variant = null
			if target != null and expression.parse(parts[2]) == OK:
				result = expression.execute([], target)
			print("Autoplay: %s.%s -> %s" % [parts[1], parts[2], result])
			continue
		var action := _find_action(agent, parts)
		if action == null or not action.enabled:
			push_error("Autoplay: can't do '%s'" % step)
			continue
		print("Autoplay: %s" % step)
		if action.immediate:
			action.run.call(agent)
		else:
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
