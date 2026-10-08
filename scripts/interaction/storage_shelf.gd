class_name StorageShelf
extends Interactable
## Shelving for finished prints. Items sit in the model's item_slot_* markers.

const EASY_REACH_HEIGHT := 0.9

var _slots: Array[Node3D] = []


func _ready() -> void:
	super()
	add_to_group(&"print_storage")
	_slots.assign(find_children("item_slot_*", "Node3D", true, false))
	# Fill the easy-to-reach shelves first, leaving the top and bottom for last.
	_slots.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return absf(a.position.y - EASY_REACH_HEIGHT) < absf(b.position.y - EASY_REACH_HEIGHT))


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.info("%d of %d spaces used" % [count(), _slots.size()])]


func count() -> int:
	return _slots.filter(func(slot: Node3D) -> bool: return slot.get_child_count() > 0).size()


func has_space() -> bool:
	return count() < _slots.size()


## Puts an item in the first empty space. False if the shelf is full.
func store(item: Node3D) -> bool:
	for slot in _slots:
		if slot.get_child_count() == 0:
			Interactable.attach(item, slot)
			return true
	return false
