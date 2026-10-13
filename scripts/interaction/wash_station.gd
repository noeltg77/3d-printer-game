class_name WashStation
extends FittingUnit
## A wash and cure station for resin prints: a fitting of kind "wash", stood
## wherever the player likes. A plate of prints carried over from a resin
## printer sits in a tub for the first half of its time and under the lamp for
## the second, by itself, and then waits to be collected and shelved. It takes
## as many plates at once as its row's `plates`. The times are in ResinFinish.

const KIND := "wash"

## One entry per bay: null while it is free, else { first, left, total } where
## `first` is the print standing in it, the rest of its plate riding inside.
var _bays: Array = []
## Plates on their way over, whose places are kept.
var _expected := 0
var _wash_slots: Array[Node3D] = []
var _cure_slots: Array[Node3D] = []


## A station with a free bay, or null if there is none.
static func with_room(tree: SceneTree) -> WashStation:
	for station: WashStation in tree.get_nodes_in_group(&"wash_station"):
		if station.has_room():
			return station
	return null


func _ready() -> void:
	super()
	add_to_group(&"wash_station")
	_wash_slots.assign(find_children("wash_slot_*", "Node3D", true, false))
	_cure_slots.assign(find_children("cure_slot_*", "Node3D", true, false))
	_bays.resize(mini(int(spec()["plates"]), _wash_slots.size()))


func _process(delta: float) -> void:
	var minutes := delta * GameClock.MINUTES_PER_SECOND
	for bay in _bays.size():
		if _bays[bay] == null or float(_bays[bay]["left"]) <= 0.0:
			continue
		var plate: Dictionary = _bays[bay]
		var before := ResinFinish.stage(plate["left"], plate["total"])
		plate["left"] = float(plate["left"]) - minutes
		var now := ResinFinish.stage(plate["left"], plate["total"])
		if now == before:
			continue
		_place(bay)
		if now == ResinFinish.READY:
			Game.charge_electricity(float(spec()["power_watts"]), plate["total"], "Wash and cure station")
			Game.notify("Washed and cured: %s. Ready to collect." % _title(plate), &"good")
		Game.changed.emit()


func card_icon() -> String:
	return "stockroom"


func has_room() -> bool:
	return _bays.count(null) > _expected


## Keeps a bay for a plate that is being carried over.
func expect() -> void:
	_expected += 1


## Stands a plate of prints in a free bay and sets it going. `first` is one
## print with the rest of the plate inside it, as it was carried.
func put_in(first: PrintedItem) -> void:
	_expected = maxi(_expected - 1, 0)
	var bay := _bays.find(null)
	if bay < 0:
		return
	var total := ResinFinish.machine_minutes(Game.data.filaments[first.material], spec())
	_bays[bay] = {"first": first, "left": total, "total": total}
	_place(bay)
	Game.changed.emit()


## True if a plate in it is done and waiting to be collected.
func has_ready() -> bool:
	return _bays.any(func(plate: Variant) -> bool: return plate != null and float(plate["left"]) <= 0.0)


## True while there is anything in it.
func busy() -> bool:
	return _bays.any(func(plate: Variant) -> bool: return plate != null) or _expected > 0


## Takes it out of the running, as it is sold or scrapped.
func retire() -> void:
	remove_from_group(&"wash_station")
	set_process(false)


func _use_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = []
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	for bay in _bays.size():
		if _bays[bay] == null:
			continue
		var plate: Dictionary = _bays[bay]
		var stage := ResinFinish.stage(plate["left"], plate["total"])
		if stage != ResinFinish.READY:
			actions.append(Action.info("%s %s: %s left" % [stage, _title(plate), GameClock.duration_label(float(plate["left"]))]).with_progress(
				1.0 - float(plate["left"]) / float(plate["total"])))
		elif shelf.room_for((plate["first"] as PrintedItem).product) >= _copies(plate):
			var collect := Action.new("Collect %s" % _title(plate), _collect.bind(bay)).for_duty(&"collect")
			collect.task_name = "Collect %s from the wash and cure station" % _title(plate)
			actions.append(collect)
		else:
			actions.append(Action.info("Collect %s (not enough room on the shelving)" % _title(plate)))
	if actions.is_empty():
		actions.append(Action.info("Empty. Click a resin printer with a finished print to bring it over."))
	return actions


func _collect(agent: Agent, bay: int) -> void:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	if bay >= _bays.size() or _bays[bay] == null or float(_bays[bay]["left"]) > 0.0:
		agent.say("Nothing ready to collect")
		return
	if shelf.room_for((_bays[bay]["first"] as PrintedItem).product) < _copies(_bays[bay]):
		agent.say("Not enough room on the shelving")
		return
	await agent.go_to(self)
	if bay >= _bays.size() or _bays[bay] == null:
		return
	await agent.reach(func() -> void:
		var first: PrintedItem = _bays[bay]["first"]
		_bays[bay] = null
		first.get_parent().remove_child(first)
		agent.carry(first)
		Game.changed.emit())
	await PrinterStation.shelve_prints(agent, shelf)


## Stands a bay's plate where its stage says: in the tub, then under the lamp.
func _place(bay: int) -> void:
	var plate: Dictionary = _bays[bay]
	var washing := ResinFinish.stage(plate["left"], plate["total"]) == ResinFinish.WASHING
	Interactable.attach(plate["first"], _wash_slots[bay] if washing else _cure_slots[bay])


func _copies(plate: Dictionary) -> int:
	var count := 1
	for child in (plate["first"] as PrintedItem).get_children():
		count += 1 if child is PrintedItem else 0
	return count


## "Mini figure", or "3 x Mini figure" for a plate of several.
func _title(plate: Dictionary) -> String:
	var title := (plate["first"] as PrintedItem).describe()
	return title if _copies(plate) == 1 else "%d x %s" % [_copies(plate), title]


func save() -> Dictionary:
	var data := super()
	var loads: Array[Dictionary] = []
	for bay in _bays.size():
		if _bays[bay] != null:
			loads.append({"bay": bay, "item": (_bays[bay]["first"] as PrintedItem).save(), "copies": _copies(_bays[bay]),
				"left": _bays[bay]["left"], "total": _bays[bay]["total"]})
	data["state"] = {"loads": loads}
	return data


## Puts back what was in it. A plate goes in whichever bay is free if its own
## isn't here, and a print of a design the game no longer has is dropped.
func restore_state(state: Dictionary) -> void:
	for entry: Dictionary in state.get("loads", []):
		var first := PrintedItem.restored(entry["item"])
		var bay := int(entry["bay"])
		if bay >= _bays.size() or _bays[bay] != null:
			bay = _bays.find(null)
		if first == null or bay < 0:
			continue
		for copy in int(entry.get("copies", 1)) - 1:
			var extra := PrintedItem.restored(entry["item"])
			Interactable.attach(extra, first)
			extra.visible = false
		_bays[bay] = {"first": first, "left": float(entry["left"]), "total": maxf(float(entry["total"]), 0.01)}
		_place(bay)
