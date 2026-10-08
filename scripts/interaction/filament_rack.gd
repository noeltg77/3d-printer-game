class_name FilamentRack
extends Interactable
## Spool storage. Spools live in the model's spool_slot_* markers.

var _slots: Array[Node3D] = []


func _ready() -> void:
	super()
	add_to_group(&"filament_rack")
	_slots.assign(find_children("spool_slot_*", "Node3D", true, false))


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("%d of %d slots used" % [_spools().size(), _slots.size()])]
	for spool in _spools():
		actions.append(Action.info(spool.describe()))
	return actions


## Colours with at least one spool on the rack, in rack order.
func available_colours() -> Array[StringName]:
	var found: Array[StringName] = []
	for spool in _spools():
		if not found.has(spool.colour):
			found.append(spool.colour)
	return found


func has_colour(colour: StringName) -> bool:
	return _spools().any(func(spool: Spool) -> bool: return spool.colour == colour)


## Grams on the fullest spool of a colour, the one take() would hand over.
func most_grams(colour: StringName) -> float:
	var best := 0.0
	for spool in _spools():
		if spool.colour == colour:
			best = maxf(best, spool.grams)
	return best


func free_slots() -> int:
	return _slots.size() - _spools().size()


## Removes the fullest spool of `colour` from the rack and returns it, or null if there is none.
func take(colour: StringName) -> Spool:
	var best: Spool = null
	for spool in _spools():
		if spool.colour == colour and (best == null or spool.grams > best.grams):
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


func _spools() -> Array[Spool]:
	var spools: Array[Spool] = []
	for slot in _slots:
		if slot.get_child_count() > 0:
			spools.append(slot.get_child(0) as Spool)
	return spools
