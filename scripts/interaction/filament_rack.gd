class_name FilamentRack
extends Interactable
## Spool storage. Spools live in the model's spool_slot_* markers.

var _slots: Array[Node3D] = []


func _ready() -> void:
	super()
	add_to_group(&"filament_rack")
	_slots.assign(find_children("spool_slot_*", "Node3D", true, false))


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("%d of %d slots used" % [spools().size(), _slots.size()])]
	# A spool nobody wants (wet, the wrong colour, nearly gone) only takes up a
	# slot, so each one opens onto binning it.
	for spool in spools():
		var bin := Action.new("Bin it", _bin.bind(spool))
		bin.task_name = "Bin the %s" % spool.title().to_lower()
		actions.append(Action.submenu(spool.describe(), [bin]))
	return actions


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
	var best: Spool = null
	for spool in spools():
		if spool.material == material and spool.colour == colour and (best == null or spool.grams > best.grams):
			best = spool
	if best != null:
		best.get_parent().remove_child(best)
	return best


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
	await agent.go_to(self)
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
	return {"spools": stored}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data["spools"]:
		var index := int(entry["slot"])
		if index < _slots.size() and _slots[index].get_child_count() == 0:
			Interactable.attach(Spool.restored(entry), _slots[index])
