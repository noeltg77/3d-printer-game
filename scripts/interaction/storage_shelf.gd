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
	var actions: Array[Action] = [Action.info("%d of %d spaces used" % [_items().size(), _slots.size()])]
	var counted: Array[StringName] = []
	for item in _items():
		if not counted.has(item.product):
			counted.append(item.product)
			actions.append(Action.info("%d x %s" % [count_of(item.product), Game.product_name(item.product)]))
	# Flawed prints can still be sold, so binning one is the player's call.
	for item in _items():
		if item.is_flawed():
			var bin := Action.new("Bin %s" % item.describe(), _bin.bind(item))
			bin.task_name = "Bin a flawed %s" % Game.product_name(item.product)
			actions.append(bin)
	return actions


func has_space() -> bool:
	return _items().size() < _slots.size()


func count_of(product: StringName) -> int:
	return _items().filter(func(item: PrintedItem) -> bool: return item.product == product).size()


## Puts an item in the first empty space. False if the shelf is full.
func store(item: Node3D) -> bool:
	for slot in _slots:
		if slot.get_child_count() == 0:
			Interactable.attach(item, slot)
			Game.changed.emit()
			return true
	return false


## Removes one item of a design from the shelf and returns it, or null if there
## is none. Good ones go first; a flawed one only when nothing else is left.
func take(product: StringName) -> PrintedItem:
	var found: PrintedItem = null
	for item in _items():
		if item.product == product and (found == null or (found.is_flawed() and not item.is_flawed())):
			found = item
	if found != null:
		found.get_parent().remove_child(found)
		Game.changed.emit()
	return found


func _bin(agent: Agent, item: PrintedItem) -> void:
	if not is_instance_valid(item) or not _items().has(item):
		agent.say("That print has already gone")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void:
		item.get_parent().remove_child(item)
		agent.carry(item)
		Game.changed.emit())
	await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
	await agent.reach(func() -> void: agent.release().queue_free())


func _items() -> Array[PrintedItem]:
	var items: Array[PrintedItem] = []
	for slot in _slots:
		if slot.get_child_count() > 0:
			items.append(slot.get_child(0) as PrintedItem)
	return items
