class_name Computer
extends Interactable
## The PC. The character sits down at it, which opens the business screens.

## The chair to sit on.
@export var seat_path: NodePath


func _ready() -> void:
	super()
	add_to_group(&"computer")


func card_icon() -> String:
	return "home"


func get_actions(agent: Agent) -> Array[Action]:
	if agent.seated:
		var seated: Array[Action] = [
			Action.new("Open the screen", func(_a: Agent) -> void: _screen().open()),
			Action.new("Stand up", func(a: Agent) -> void: await a.stand_up()),
		]
		if Game.research.current != &"":
			seated.insert(1, study_action(Game.research.current))
		return seated
	var actions: Array[Action] = [Action.new("Use computer", _use)]
	# A course part way through can be picked up again without opening the screen.
	if Game.research.current != &"":
		actions.append(study_action(Game.research.current))
	return actions


func _use(agent: Agent) -> void:
	await agent.walk_to(get_stand_point())
	await agent.sit(get_node(seat_path))
	_screen().open()


## The task of sitting at the PC to study a course: paying its fee if that is
## still owed, then working through it until it is learned or the character
## is given something else to do. What was studied is kept.
func study_action(course: StringName) -> Action:
	var row: Dictionary = Game.data.courses[course]
	var problem := Game.study_problem(course)
	var title := "%s %s" % ["Carry on studying" if Game.research.is_started(course) else "Study", row["name"]]
	var action := Action.new(title if problem == "" else "%s: %s" % [title, problem.to_lower()], _study.bind(course), problem == "")
	action.task_name = "Study %s" % row["name"]
	return action


func _study(agent: Agent, course: StringName) -> void:
	if not Game.start_course(course):
		agent.say("Can't study that right now")
		return
	if not agent.seated:
		await agent.walk_to(get_stand_point())
		await agent.sit(get_node(seat_path))
	var title: String = Game.data.courses[course]["name"]
	var at := Game.clock.minutes
	# Until it is learned, another job is lined up, the screen is opened, the
	# day is ended or a save is waiting on everyone finishing what they are at.
	var saving := false
	while not Game.research.is_learned(course) and not agent.has_queued() and not agent.held and not Game.sleeping:
		saving = _world_save() != null and _world_save().wants_quiet()
		if saving:
			break
		agent.relabel("Studying %s: %d%%" % [title, floori(Game.research.fraction(course) * 100.0)])
		await agent.reach()
		Game.study(course, Game.clock.minutes - at)
		at = Game.clock.minutes
	if saving:
		_resume_after_save(agent, course)


## Sits back down to a course once the save that interrupted it is done.
func _resume_after_save(agent: Agent, course: StringName) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	if is_instance_valid(agent) and agent.seated and not agent.is_busy() and not agent.held and Game.research.current == course:
		agent.enqueue(study_action(course))


func _world_save() -> WorldSave:
	return get_tree().get_first_node_in_group(&"world_save")


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
