class_name StorageShelf
extends Interactable
## Shelving for finished prints and boxes of spare parts. Each sits in one of
## the model's item_slot_* markers, so spares take room that prints could use.

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
	var actions: Array[Action] = [Action.info("%d of %d spaces used" % [_slots.size() - free_slots(), _slots.size()])]
	var counted: Array[StringName] = []
	for item in _items():
		if not counted.has(item.product):
			counted.append(item.product)
			actions.append(Action.info("%d x %s" % [count_of(item.product), Game.product_name(item.product)]))
	for box in spares():
		actions.append(Action.info("Spares: %s" % box.describe()))
	# Flawed prints can still be sold, so binning one is the player's call.
	for item in _items():
		if item.is_flawed():
			var bin := Action.new("Bin %s" % item.describe(), _bin.bind(item))
			bin.task_name = "Bin a flawed %s" % Game.product_name(item.product)
			actions.append(bin)
	return actions


func free_slots() -> int:
	return _slots.filter(func(slot: Node3D) -> bool: return slot.get_child_count() == 0).size()


func has_space() -> bool:
	return free_slots() > 0


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
## is none. Good ones go first: a flawed one only when nothing else is left, and
## one printed in a single colour only when there is none in full colour.
func take(product: StringName) -> PrintedItem:
	var found: PrintedItem = null
	for item in _items():
		if item.product == product and (found == null or _rank(item) < _rank(found)):
			found = item
	if found != null:
		found.get_parent().remove_child(found)
		Game.changed.emit()
	return found


## Every box of spare parts on the shelf.
func spares() -> Array[SparePart]:
	var found: Array[SparePart] = []
	for slot in _slots:
		if slot.get_child_count() > 0 and slot.get_child(0) is SparePart:
			found.append(slot.get_child(0))
	return found


## How many spares of a part are on the shelf.
func spare_count(part: StringName) -> int:
	var box := _spare_box(part)
	return box.count if box != null else 0


## True if there is room for these part ids: a kind already on the shelf goes in
## its box, and each new kind needs a space of its own.
func can_store_parts(parts: Array) -> bool:
	var new_kinds: Array[StringName] = []
	for part in parts:
		if _spare_box(StringName(part)) == null and not new_kinds.has(StringName(part)):
			new_kinds.append(StringName(part))
	return new_kinds.size() <= free_slots()


## Adds spares to the shelf, topping up the box of that part if there is one.
## False if a new box was needed and the shelf is full.
func store_parts(part: StringName, count: int) -> bool:
	var box := _spare_box(part)
	if box != null:
		box.count += count
		Game.changed.emit()
		return true
	return store(SparePart.create(part, count))


## Takes one spare of a part off the shelf, or null if there is none. The box
## goes with the last one.
func take_spare(part: StringName) -> SparePart:
	var box := _spare_box(part)
	if box == null:
		return null
	box.count -= 1
	if box.count <= 0:
		box.get_parent().remove_child(box)
		box.queue_free()
	Game.changed.emit()
	return SparePart.create(part)


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


## How far down the queue to be sold an item is: 0 for one as it should be.
func _rank(item: PrintedItem) -> int:
	return (2 if item.is_flawed() else 0) + (1 if item.is_plain() else 0)


func _spare_box(part: StringName) -> SparePart:
	for box in spares():
		if box.part == part:
			return box
	return null


func _items() -> Array[PrintedItem]:
	var items: Array[PrintedItem] = []
	for slot in _slots:
		if slot.get_child_count() > 0 and slot.get_child(0) is PrintedItem:
			items.append(slot.get_child(0))
	return items


func save() -> Dictionary:
	var stored: Array[Dictionary] = []
	for slot in _slots:
		if slot.get_child_count() == 0:
			continue
		var thing := slot.get_child(0)
		var entry: Dictionary = thing.call(&"save")
		entry["slot"] = slot.name
		entry["kind"] = "spare" if thing is SparePart else "print"
		stored.append(entry)
	return {"slots": stored}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data["slots"]:
		var slot: Node3D = find_child(entry["slot"], true, false)
		var thing: Node3D = SparePart.restored(entry) if entry["kind"] == "spare" else PrintedItem.restored(entry)
		if slot != null and thing != null and slot.get_child_count() == 0:
			Interactable.attach(thing, slot)
