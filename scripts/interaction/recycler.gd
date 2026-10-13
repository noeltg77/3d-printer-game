class_name Recycler
extends FittingUnit
## The filament recycler: a fitting of kind "recycler", stood wherever the
## player likes. The ends of spools on the rack, and failed prints, are
## shredded into its hopper. Once there is a spool's worth of one family of
## filament it winds a new spool in any colour that filament comes in, which
## takes a few hours and a little pigment, and waits on the machine to be put
## on the rack. The rules and the figures are in Recycling.

const KIND := "recycler"
const EMPTY_SPOOL := "res://assets/models/filament/spool_empty.glb"

var recycling: Recycling
## The new spool, standing on the winder until it is taken off.
var _output: Spool = null
## The bare spool shown turning while one is wound.
var _winding: Node3D = null
## Game minutes it has run since electricity was last charged.
var _minutes_on := 0.0
var _winder: Node3D


## The recycler that can melt down a filament, or null if there is none.
static func taking(tree: SceneTree, material: StringName) -> Recycler:
	for machine: Recycler in tree.get_nodes_in_group(&"recycler"):
		if machine.family_of(material) != "":
			return machine
	return null


func _ready() -> void:
	super()
	add_to_group(&"recycler")
	recycling = Recycling.new(spec())
	_winder = find_child("spool_out", true, false)


func _process(delta: float) -> void:
	if recycling.job.is_empty():
		return
	var minutes := delta * GameClock.MINUTES_PER_SECOND
	_minutes_on += minutes
	if _winding != null:
		_winding.rotate_y(delta * 2.0)
	if recycling.advance(minutes):
		Game.charge_electricity(float(spec()["power_watts"]), _minutes_on, "Recycler")
		_minutes_on = 0.0
		_show()
		Game.notify("The recycler has wound a new spool: %s" % _output.title(), &"good")
		Game.changed.emit()


func card_icon() -> String:
	return "spoolhouse"


## The family a filament is recycled as here, or "" if this machine can't take it.
func family_of(material: StringName) -> String:
	return Recycling.family_of(spec(), Game.data.filaments[material])


## The spools on the rack with too little left to be much use, that it can take.
func leftovers() -> Array[Spool]:
	return _rack().spools().filter(func(spool: Spool) -> bool:
		return family_of(spool.material) != "" and Recycling.is_leftover(spool.grams, Game.data.settings["recycling"]))


## The task of fetching spools from the rack and shredding them.
func shred_action(spools: Array[Spool], label: String) -> Action:
	var action := Action.new(label, _shred.bind(spools))
	action.task_name = "Shred %s" % (spools[0].title().to_lower() if spools.size() == 1 else "%d leftover spools" % spools.size())
	return action


## Shreds grams of a filament into the hopper: a failed print's worth, say.
func feed(material: StringName, grams: float) -> void:
	recycling.feed(Game.data.filaments[material], grams)
	Game.changed.emit()


## True if a finished spool is waiting on it.
func has_output() -> bool:
	return _output != null


## True if the hopper holds enough of something for a spool, and it is free to wind one.
func can_make() -> bool:
	return recycling.hopper.keys().any(func(family: String) -> bool: return recycling.problem(family) == "")


## True while there is anything in it or on it.
func busy() -> bool:
	return recycling.in_use() or _output != null


## Takes it out of the running, as it is sold or scrapped.
func retire() -> void:
	remove_from_group(&"recycler")
	set_process(false)


func _use_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = []
	var full := recycling.spool_grams()
	for family: String in recycling.hopper:
		actions.append(Action.info("%s in the hopper: %d g of the %d g a spool takes" % [
			Game.data.filaments[family]["name"], roundi(recycling.grams_of(family)), roundi(full)]).with_progress(recycling.grams_of(family) / full))
	if not recycling.job.is_empty():
		var job := recycling.job
		actions.append(Action.info("Winding %s %s: %s left" % [Palette.display_name(job["colour"]), Game.data.filaments[job["material"]]["name"],
			GameClock.duration_label(float(job["left"]))]).with_progress(recycling.progress()))
	if _output != null:
		if _rack().free_slots() > 0:
			var off := Action.new("Put the new %s on the rack" % _output.title(), _take_off)
			off.task_name = "Rack the recycled %s" % _output.title().to_lower()
			actions.append(off)
		else:
			actions.append(Action.info("New %s (the rack is full)" % _output.title()))
	if not busy():
		actions.append(Action.info("Empty. It takes the ends of spools and failed prints."))
	var ends := leftovers()
	if ends.is_empty():
		actions.append(Action.info("Shred the leftovers (no spool on the rack is under %d g)" % int(Game.data.settings["recycling"]["leftover_grams"])))
	else:
		actions.append(shred_action(ends, "Shred the leftovers: %d spool%s" % [ends.size(), "" if ends.size() == 1 else "s"]))
	var any: Array[Action] = []
	for spool in _rack().spools():
		if family_of(spool.material) != "":
			any.append(shred_action([spool], spool.describe()))
	if not any.is_empty():
		actions.append(Action.submenu("Shred a spool", any).tuck())
	for family: String in recycling.hopper:
		var filament: Dictionary = Game.data.filaments[family]
		var why_not := recycling.problem(family)
		if why_not != "":
			if recycling.grams_of(family) >= full:
				actions.append(Action.info("Make a %s spool (%s)" % [filament["name"], why_not]))
			continue
		var colours: Array[Action] = []
		for colour: String in filament["colours"]:
			var make := Action.new(Palette.display_name(colour), _make.bind(family, StringName(colour)))
			make.task_name = "Make a %s %s spool" % [Palette.display_name(colour).to_lower(), filament["name"]]
			colours.append(make)
		actions.append(Action.submenu("Make a %s spool (%s of pigment)" % [filament["name"], Money.format(int(spec()["pigment_pence"]))], colours))
	return actions


func _shred(agent: Agent, spools: Array[Spool]) -> void:
	var rack := _rack()
	var done := 0
	for spool in spools:
		if not is_instance_valid(spool) or not rack.spools().has(spool):
			continue
		await agent.go_to(rack.spot_of(spool))
		if not is_instance_valid(spool) or not rack.spools().has(spool):
			continue
		await agent.reach(func() -> void:
			spool.get_parent().remove_child(spool)
			agent.carry(spool)
			Game.changed.emit())
		await agent.go_to(self)
		await agent.work(float(spec()["shred_minutes"]))
		await agent.reach(func() -> void:
			var shredded := agent.release() as Spool
			feed(shredded.material, shredded.grams)
			shredded.queue_free())
		done += 1
	agent.say("Nothing there to shred" if done == 0 else "Shredded %d spool%s" % [done, "" if done == 1 else "s"])


func _make(agent: Agent, family: String, colour: StringName) -> void:
	var pigment := int(spec()["pigment_pence"])
	if recycling.problem(family) != "" or not Game.bank.can_afford(pigment):
		agent.say("Can't make that spool right now" if recycling.problem(family) != "" else "Not enough cash for the pigment")
		return
	await agent.go_to(self)
	await agent.work(float(spec()["setup_minutes"]))
	await agent.reach(func() -> void:
		if recycling.start(family, colour):
			Game.bank.spend(pigment, "Pigment for recycled filament", Game.clock.minutes, Bank.SUPPLIES)
			_show()
			Game.changed.emit())


func _take_off(agent: Agent) -> void:
	var rack := _rack()
	if _output == null or rack.free_slots() == 0:
		agent.say("No spool to take" if _output == null else "The rack is full")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void:
		var spool := _output
		_output = null
		recycling.take()
		spool.get_parent().remove_child(spool)
		agent.carry(spool)
		Game.changed.emit())
	await agent.go_to(rack.spot())
	await agent.reach(func() -> void: rack.store(agent.release() as Spool))


## Puts on the winder what the machine's state says is there: a bare spool
## turning, the finished one, or nothing.
func _show() -> void:
	if _winding != null:
		_winding.queue_free()
		_winding = null
	if not recycling.job.is_empty():
		_winding = (load(EMPTY_SPOOL) as PackedScene).instantiate()
		_winder.add_child(_winding)
	if not recycling.ready.is_empty() and _output == null:
		var made := recycling.ready
		_output = Spool.create(StringName(made["colour"]), recycling.spool_grams(), StringName(made["material"]))
		_output.recycled = true
		Interactable.attach(_output, _winder)


func _rack() -> FilamentRack:
	return get_tree().get_first_node_in_group(&"filament_rack")


func save() -> Dictionary:
	var data := super()
	data["state"] = recycling.save()
	data["state"]["minutes_on"] = _minutes_on
	return data


func restore_state(state: Dictionary) -> void:
	recycling.restore(state, Game.data.filaments)
	_minutes_on = float(state.get("minutes_on", 0.0))
	_show()
