class_name Computer
extends Interactable
## The PC. The character sits down at it, which opens the business screens.

## The chair to sit on.
@export var seat_path: NodePath


func _ready() -> void:
	super()
	add_to_group(&"computer")


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


## The task of sitting at the PC to design the next version of an own design.
## Disabled, with the reason in its label, if it can't be done.
func design_action(product: StringName) -> Action:
	var problem := Game.design_problem(product)
	var title := "Design your own %s" % Game.product_name(product) if not Game.studio.has(product) else "Improve your %s to V%d" % [
		Game.product_name(product), Game.studio.version(product) + 1]
	return Action.new(title if problem == "" else "%s: %s" % [title, problem], _design.bind(product), problem == "")


## The task of sitting at the PC to fix a fault a test print found in a design.
func fix_action(product: StringName) -> Action:
	return Action.new("Fix your %s design" % Game.product_name(product), _fix.bind(product), Game.studio.needs_fix(product))


func _design(agent: Agent, product: StringName) -> void:
	if Game.design_problem(product) != "":
		agent.say("Can't work on that design right now")
		return
	await _work_at_desk(agent, Game.studio.minutes_for(product))
	Game.finish_design(product)


func _fix(agent: Agent, product: StringName) -> void:
	if not Game.studio.needs_fix(product):
		agent.say("That design doesn't need fixing")
		return
	await _work_at_desk(agent, Game.studio.fix_minutes())
	Game.finish_design_fix(product)


## Sits the character at the PC, if not there already, to work for a while.
func _work_at_desk(agent: Agent, game_minutes: float) -> void:
	if not agent.seated:
		await agent.walk_to(get_stand_point())
		await agent.sit(get_node(seat_path))
	await agent.work(game_minutes)


func _screen() -> PcScreen:
	return get_tree().get_first_node_in_group(&"pc_screen")
