class_name FilamentRack
extends Interactable
## Spool storage. Spools live in the model's spool_slot_* markers.
##
## The premises' own rack is the one FilamentRack. Racks the player buys and
## stands about the room (FittingUnit) add their slots to it: `units()` is
## this node and each of them, and whoever fetches or puts away a spool goes
## to the unit it is on (`spot`).

const FITTING_KIND := "rack"

## Every slot, this node's first and then each bought rack's in turn.
var _slots: Array[Node3D] = []
var _units: Array[FittingUnit] = []


func _ready() -> void:
	super()
	add_to_group(&"filament_rack")
	_slots = _slots_of(self)


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("%d of %d slots used" % [spools().size(), _slots.size()])]
	# A spool nobody wants (wet, the wrong colour, nearly gone) only takes up a
	# slot, so each one opens onto binning it.
	for spool in spools():
		var bin := Action.new("Bin it", _bin.bind(spool))
		bin.task_name = "Bin the %s" % spool.title().to_lower()
		actions.append(Action.submenu(spool.describe(), [bin]))
	return actions


## This node and each bought rack that adds to it.
func units() -> Array[Interactable]:
	var all: Array[Interactable] = [self]
	all.append_array(_units)
	return all


## How many racks there are in all, counting this one.
func unit_count() -> int:
	return 1 + _units.size()


## Stands a bought rack in the room and takes on its slots.
func add_unit(fitting: StringName, at: Transform3D) -> FittingUnit:
	var unit := FittingUnit.create(fitting, self)
	get_parent().add_child(unit)
	unit.global_transform = at
	_units.append(unit)
	_slots.append_array(_slots_of(unit))
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## True if anything is on a bought unit.
func unit_in_use(unit: FittingUnit) -> bool:
	return _slots.any(func(slot: Node3D) -> bool: return slot.get_meta(&"unit") == unit and slot.get_child_count() > 0)


## Gives up a bought rack's slots, for it to be sold or scrapped. It has to be empty.
func remove_unit(unit: FittingUnit) -> void:
	_slots = _slots.filter(func(slot: Node3D) -> bool: return slot.get_meta(&"unit") != unit)
	_units.erase(unit)
	Game.changed.emit()


## Where to go for a spool: the rack holding the fullest of a kind, or with
## no kind given, the first with an empty slot.
func spot(material: StringName = &"", colour: StringName = &"") -> Interactable:
	var slot: Node3D = null
	if material != &"":
		var spool := _fullest(material, colour)
		slot = spool.get_parent() if spool != null else null
	else:
		for candidate in _slots:
			if candidate.get_child_count() == 0:
				slot = candidate
				break
	return slot.get_meta(&"unit") if slot != null else self


## The rack a spool is on.
func spot_of(spool: Spool) -> Interactable:
	return spool.get_parent().get_meta(&"unit", self)


## Each kind of filament on the rack, in rack order, as { material, colour }.
func kinds() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for spool in spools():
		var kind := {"material": spool.material, "colour": spool.colour}
		if not found.has(kind):
			found.append(kind)
	return found


func has(material: StringName, colour: StringName) -> bool:
	return spools().any(func(spool: Spool) -> bool: return spool.material == material and spool.colour == colour)


## Grams on the fullest spool of a kind, the one take() would hand over.
func most_grams(material: StringName, colour: StringName) -> float:
	var best := 0.0
	for spool in spools():
		if spool.material == material and spool.colour == colour:
			best = maxf(best, spool.grams)
	return best


func free_slots() -> int:
	return _slots.size() - spools().size()


## Removes the fullest spool of a kind from the rack and returns it, or null if there is none.
func take(material: StringName, colour: StringName) -> Spool:
	var best := _fullest(material, colour)
	if best != null:
		best.get_parent().remove_child(best)
	return best


func _fullest(material: StringName, colour: StringName) -> Spool:
	var best: Spool = null
	for spool in spools():
		if spool.material == material and spool.colour == colour and (best == null or spool.grams > best.grams):
			best = spool
	return best


func _slots_of(unit: Interactable) -> Array[Node3D]:
	var found: Array[Node3D] = []
	found.assign(unit.find_children("spool_slot_*", "Node3D", true, false))
	for slot in found:
		slot.set_meta(&"unit", unit)
	return found


## Puts a spool in the first empty slot. False if the rack is full.
func store(spool: Spool) -> bool:
	for slot in _slots:
		if slot.get_child_count() == 0:
			Interactable.attach(spool, slot)
			return true
	return false


## Every spool on the rack, in slot order.
func spools() -> Array[Spool]:
	var found: Array[Spool] = []
	for slot in _slots:
		if slot.get_child_count() > 0:
			found.append(slot.get_child(0) as Spool)
	return found


func _bin(agent: Agent, spool: Spool) -> void:
	if not is_instance_valid(spool) or not spools().has(spool):
		agent.say("That spool has already gone")
		return
	await agent.go_to(spot_of(spool))
	if not is_instance_valid(spool) or not spools().has(spool):
		agent.say("That spool has already gone")
		return
	var title := spool.title()
	await agent.reach(func() -> void:
		spool.get_parent().remove_child(spool)
		agent.carry(spool)
		Game.changed.emit())
	await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
	await agent.reach(func() -> void: agent.release().queue_free())
	agent.say("Binned the %s" % title)


func save() -> Dictionary:
	var stored: Array[Dictionary] = []
	for index in _slots.size():
		if _slots[index].get_child_count() > 0:
			var entry := (_slots[index].get_child(0) as Spool).save()
			entry["slot"] = index
			stored.append(entry)
	return {"spools": stored, "units": _units.map(func(unit: FittingUnit) -> Dictionary: return unit.save())}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data.get("units", []):
		if Game.data.fittings.has(entry.get("fitting", "")):
			add_unit(StringName(entry["fitting"]), FittingUnit.saved_transform(entry))
	for entry: Dictionary in data["spools"]:
		var index := int(entry["slot"])
		if index < _slots.size() and _slots[index].get_child_count() == 0:
			Interactable.attach(Spool.restored(entry), _slots[index])
		else:
			# Its rack isn't here (after a move, say): it goes wherever there is room.
			store(Spool.restored(entry))
