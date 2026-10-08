class_name FilamentRack
extends Interactable
## Spool storage. Spools live in the model's spool_slot_* markers.
## Starts part filled with random colours as a stand-in until stock is real (Phase 3).

@export var colours: PackedStringArray = ["red", "orange", "yellow", "lime", "green", "teal", "sky", "blue", "purple", "pink", "white", "ink"]
@export_range(0.0, 1.0) var fill := 0.8
@export var random_seed := 1

var _slots: Array[Node3D] = []


func _ready() -> void:
	super()
	add_to_group(&"filament_rack")
	_slots.assign(find_children("spool_slot_*", "Node3D", true, false))
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for slot in _slots:
		if rng.randf() <= fill:
			slot.add_child(Spool.create(colours[rng.randi() % colours.size()]))


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.info("%d of %d slots used" % [_spools().size(), _slots.size()])]


## Colours with at least one spool on the rack, in palette order.
func available_colours() -> Array[StringName]:
	var found: Array[StringName] = []
	for colour in colours:
		if has_colour(colour):
			found.append(StringName(colour))
	return found


func has_colour(colour: StringName) -> bool:
	return _spools().any(func(spool: Spool) -> bool: return spool.colour == colour)


func has_space() -> bool:
	return _spools().size() < _slots.size()


## Removes a spool of `colour` from the rack and returns it, or null if there is none.
func take(colour: StringName) -> Spool:
	for spool in _spools():
		if spool.colour == colour:
			spool.get_parent().remove_child(spool)
			return spool
	return null


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
