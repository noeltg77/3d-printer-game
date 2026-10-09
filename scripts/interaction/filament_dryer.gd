class_name FilamentDryer
extends Interactable
## A filament dryer: spools put in it lose their moisture over a few hours
## instead of gaining it. Stands on the premises' dryer spot (DryerSpot), which
## creates it when one is unpacked. Spools sit in the model's spool_slot_* markers.

## Row from data/dryers.json.
var spec: Dictionary

var _slots: Array[Node3D] = []
## Game minutes it has spent heating since electricity was last charged.
var _minutes_on := 0.0


static func create(dryer_id: StringName) -> FilamentDryer:
	var dryer := FilamentDryer.new()
	dryer.spec = Game.data.dryers[dryer_id]
	dryer.display_name = "Filament dryer"
	dryer.stand_offset = Vector3(0.0, 0.0, 0.6)
	dryer.add_child((load(GameData.DRYER_MODEL % dryer.spec["model"]) as PackedScene).instantiate())
	return dryer


func _ready() -> void:
	super()
	add_to_group(&"dryer")
	add_to_group(&"obstacle")
	_slots.assign(find_children("spool_slot_*", "Node3D", true, false))
	_slots.resize(mini(_slots.size(), int(spec["capacity"])))


func _process(delta: float) -> void:
	var minutes := delta * GameClock.MINUTES_PER_SECOND
	for spool in spools():
		if spool.moisture <= 0.0:
			continue
		_minutes_on += minutes
		spool.moisture = Moisture.dried(spool.moisture, minutes, spec, Game.data.filaments[spool.material])
		if spool.moisture <= 0.0:
			Game.charge_electricity(spec["power_watts"], _minutes_on, "Filament dryer")
			_minutes_on = 0.0
			Game.notify("The dryer has finished: %s is dry" % spool.title(), &"good")


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info(spec["name"])]
	for spool in spools():
		var filament: Dictionary = Game.data.filaments[spool.material]
		var left := Moisture.hours_to_dry(spool.moisture, spec, filament) * 60.0
		actions.append(Action.info("%s: %s" % [spool.title(), "dry" if left <= 0.0 else "%s to go" % GameClock.duration_label(left)]))
		var out := Action.new("Put %s back on the rack" % spool.title(), _take_out.bind(spool))
		out.task_name = "Take %s out of the dryer" % spool.title()
		actions.append(out)
	actions.append(_dry_menu())
	return actions


## Spools in the dryer, in slot order.
func spools() -> Array[Spool]:
	var found: Array[Spool] = []
	for slot in _slots:
		if slot.get_child_count() > 0:
			found.append(slot.get_child(0) as Spool)
	return found


func has_room() -> bool:
	return spools().size() < _slots.size()


## Why a spool can't go in, or "" if it can.
func problem(spool: Spool) -> String:
	if not has_room():
		return "the dryer is full"
	if not Moisture.can_dry(spec, Game.data.filaments[spool.material]):
		return "this dryer doesn't get hot enough for it"
	return ""


## Puts a spool in the first free slot. False if there is no room.
func put_in(spool: Spool) -> bool:
	for slot in _slots:
		if slot.get_child_count() == 0:
			Interactable.attach(spool, slot)
			spool.sheltered = true
			return true
	return false


func take_out(spool: Spool) -> Spool:
	spool.get_parent().remove_child(spool)
	spool.sheltered = false
	return spool


func save() -> Dictionary:
	var stored: Array[Dictionary] = []
	for index in _slots.size():
		if _slots[index].get_child_count() > 0:
			var entry := (_slots[index].get_child(0) as Spool).save()
			entry["slot"] = index
			stored.append(entry)
	return {"id": spec["id"], "spools": stored, "minutes_on": _minutes_on}


func restore(data: Dictionary) -> void:
	_minutes_on = float(data.get("minutes_on", 0.0))
	for entry: Dictionary in data["spools"]:
		var index := int(entry["slot"])
		if index < _slots.size() and _slots[index].get_child_count() == 0:
			var spool := Spool.restored(entry)
			Interactable.attach(spool, _slots[index])
			spool.sheltered = true


## The damp spools on the rack, each with the task of putting it in to dry.
func _dry_menu() -> Action:
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	var choices: Array[Action] = []
	for spool in rack.spools():
		if spool.moisture <= 0.0:
			continue
		var filament: Dictionary = Game.data.filaments[spool.material]
		var why_not := problem(spool)
		var label := "%s (%s, %s)" % [spool.title(), Moisture.label(spool.moisture, Game.data.settings["moisture"]),
			GameClock.duration_label(Moisture.hours_to_dry(spool.moisture, spec, filament) * 60.0)]
		var action := Action.new(label if why_not == "" else "%s: %s" % [spool.title(), why_not], _put_in.bind(spool), why_not == "")
		action.task_name = "Dry the %s" % spool.title()
		choices.append(action)
	if choices.is_empty():
		return Action.info("Dry a spool (nothing on the rack is damp)")
	return Action.submenu("Dry a spool", choices)


func _put_in(agent: Agent, spool: Spool) -> void:
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	if not is_instance_valid(spool) or not rack.spools().has(spool) or problem(spool) != "":
		agent.say("Can't dry that spool right now")
		return
	await agent.go_to(rack)
	await agent.reach(func() -> void:
		spool.get_parent().remove_child(spool)
		agent.carry(spool))
	await agent.go_to(self)
	await agent.reach(func() -> void: put_in(agent.release() as Spool))


func _take_out(agent: Agent, spool: Spool) -> void:
	var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
	if not is_instance_valid(spool) or not spools().has(spool) or rack.free_slots() == 0:
		agent.say("Can't put that spool back right now")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: agent.carry(take_out(spool)))
	await agent.go_to(rack)
	await agent.reach(func() -> void: rack.store(agent.release() as Spool))
