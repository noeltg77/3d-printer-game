class_name StorageShelf
extends Interactable
## Shelving for finished prints and boxes of spare parts. Each sits in one of
## the model's item_slot_* markers, so spares take room that prints could use.
##
## The premises' own shelving is the one StorageShelf. Shelving units the
## player buys and stands about the room (FittingUnit) add their spaces to
## it: `units()` is this node and each of them, and whoever fetches or puts
## away goes to the unit the thing is on (`spot`).
##
## A printed storage bin (StorageBin) takes one space and holds several
## prints, so what is "on the shelf" is what is in the spaces and in the bins.
## A print goes in a bin that already holds its design, failing that any bin
## with room, failing that an empty space. A print of a bin design never goes
## inside another bin.
##
## Clicking the shelving opens the ShelfDialog, where it is all laid out and
## can be tidied by dragging.

const EASY_REACH_HEIGHT := 0.9
const FITTING_KIND := "shelf"

## Every space, this node's first and then each bought unit's in turn.
var _slots: Array[Node3D] = []
var _units: Array[FittingUnit] = []


func _ready() -> void:
	super()
	add_to_group(&"print_storage")
	_slots = _slots_of(self)


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("%d of %d spaces used" % [_slots.size() - free_slots(), _slots.size()])]
	var counted: Array[StringName] = []
	for item in _items():
		if not counted.has(item.product):
			counted.append(item.product)
			actions.append(Action.info("%d x %s" % [count_of(item.product), Game.product_name(item.product)]))
	for box in spares():
		actions.append(Action.info("Spares: %s" % box.describe()))
	for bin in bins():
		actions.append(Action.info(bin.describe()))
	# Flawed prints can still be sold, so binning one is the player's call.
	for item in _items():
		if item.is_flawed():
			var scrap := Action.new("Bin %s" % item.describe(), _bin.bind(item))
			scrap.task_name = "Bin a flawed %s" % Game.product_name(item.product)
			actions.append(scrap)
	# A print of a bin design can be put to use, and a bin that is empty can go back on sale.
	var storage: Array[Action] = []
	var offered: Array[StringName] = []
	for item in _loose():
		if Game.storage.is_bin(item.product) and not offered.has(item.product):
			offered.append(item.product)
			var use := Action.new("Use a %s for storage (holds %s)" % [Game.product_name(item.product), Game.storage.bin_summary(item.product)],
				_use_as_bin.bind(item.product))
			use.task_name = "Set up a %s as storage" % Game.product_name(item.product)
			storage.append(use)
	for bin in bins():
		if bin.items.is_empty():
			var stop := Action.new("Stop using an empty %s" % Game.product_name(bin.shell.product), _stop_using.bind(bin))
			stop.task_name = "Put a %s back on sale" % Game.product_name(bin.shell.product)
			storage.append(stop)
			break
	if not storage.is_empty():
		actions.append(Action.submenu("Storage bins", storage))
	return actions


## Shows what is on the shelving, to be tidied. Clicking any of it does this
## in place of the usual menu.
func wants_panel() -> bool:
	return true


func open_panel() -> void:
	ShelfDialog.show_for(self)


## A unit's spaces as they are laid out on it: top shelf first, left to right.
func unit_slots(unit: Interactable) -> Array[Node3D]:
	var found := _slots.filter(func(slot: Node3D) -> bool: return slot.get_meta(&"unit") == unit)
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x if is_equal_approx(a.position.y, b.position.y) else a.position.y > b.position.y)
	return found


func slot_count() -> int:
	return _slots.size()


## Moves something to an empty space: a print (off another space or out of a
## bin), a bin with all that is in it, or a box of spares. False if the space
## is taken.
func move_to_slot(thing: Node3D, slot: Node3D) -> bool:
	if slot.get_child_count() > 0 or not _slots.has(slot):
		return false
	if thing is PrintedItem and thing.get_parent() is StorageBin:
		(thing.get_parent() as StorageBin).remove(thing)
	else:
		thing.get_parent().remove_child(thing)
	Interactable.attach(thing, slot)
	Game.changed.emit()
	return true


## Moves prints into a storage bin, as many as it has room for. Returns how many went in.
func move_into_bin(items: Array[PrintedItem], bin: StorageBin) -> int:
	var moved := 0
	# A copy, since taking a print out of its bin changes that bin's own list.
	for item: PrintedItem in items.duplicate():
		if item.get_parent() == bin or bin.room_for(item.product) <= 0:
			continue
		take_item(item)
		bin.add(item)
		moved += 1
	if moved > 0:
		Game.changed.emit()
	return moved


## Puts a print of a bin design to use where it sits (or, if it is inside a
## bin, in the first empty space). False if it can't be.
func make_bin(item: PrintedItem) -> bool:
	if not Game.storage.is_bin(item.product):
		return false
	if item.get_parent() is StorageBin:
		var space := _empty_slot()
		if space == null:
			return false
		move_to_slot(item, space)
	var slot := item.get_parent() as Node3D
	Interactable.attach(StorageBin.create(item), slot)
	Game.changed.emit()
	return true


## Puts a print of a bin design straight on the shelving as a storage bin.
## False if there is no empty space for it.
func store_as_bin(item: PrintedItem) -> bool:
	var slot := _empty_slot()
	if slot == null or not Game.storage.is_bin(item.product):
		return false
	Interactable.attach(StorageBin.create(item), slot)
	Game.changed.emit()
	return true


## Takes an empty storage bin out of use, leaving the print it is in its space.
func unmake_bin(bin: StorageBin) -> bool:
	if not bin.items.is_empty():
		return false
	var slot := bin.get_parent() as Node3D
	var shell := bin.empty_shell()
	slot.remove_child(bin)
	bin.queue_free()
	Interactable.attach(shell, slot)
	Game.changed.emit()
	return true


## This node and each shelving unit that adds to it.
func units() -> Array[Interactable]:
	var all: Array[Interactable] = [self]
	all.append_array(_units)
	return all


## How many units there are in all, counting this one.
func unit_count() -> int:
	return 1 + _units.size()


## Stands a bought shelving unit in the room and takes on its spaces.
func add_unit(fitting: StringName, at: Transform3D) -> FittingUnit:
	var unit := FittingUnit.create(fitting, self)
	get_parent().add_child(unit)
	unit.global_transform = at
	_units.append(unit)
	_slots.append_array(_slots_of(unit))
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## Where to go to fetch or put away. `what` is a print being carried (the unit
## with room for it), a design's id (the unit holding one), a part's or kit's
## id (the unit with its box), or nothing (the first unit with an empty space).
func spot(what: Variant = null) -> Interactable:
	var slot: Node3D = null
	if what is PrintedItem:
		slot = _home_for(what)
	elif what is StringName or what is String:
		var id := StringName(what)
		if Game.data.products.has(id):
			var found := _best(id)
			slot = _slot_of(found) if found != null else null
		else:
			var box := _spare_box(id)
			slot = box.get_parent() if box != null else null
	if slot == null:
		for candidate in _slots:
			if candidate.get_child_count() == 0:
				slot = candidate
				break
	return slot.get_meta(&"unit") if slot != null else self


## The unit a print is on.
func spot_of(item: PrintedItem) -> Interactable:
	return _slot_of(item).get_meta(&"unit")


## Spaces with nothing in them at all.
func free_slots() -> int:
	return _slots.filter(func(slot: Node3D) -> bool: return slot.get_child_count() == 0).size()


func has_space() -> bool:
	return free_slots() > 0


## How many more prints of a design could be put away: one to each empty
## space, and as many as fit in each storage bin.
func room_for(product: StringName) -> int:
	var room := free_slots()
	for bin in bins():
		room += bin.room_for(product)
	return room


func count_of(product: StringName) -> int:
	return _items().filter(func(item: PrintedItem) -> bool: return item.product == product).size()


## Puts something away: a print in a storage bin if one has room, else in the
## first empty space; anything else in the first empty space. False if there
## is nowhere for it.
func store(item: Node3D) -> bool:
	var slot := _home_for(item)
	if slot == null:
		return false
	if slot.get_child_count() > 0:
		(slot.get_child(0) as StorageBin).add(item as PrintedItem)
	else:
		Interactable.attach(item, slot)
	Game.changed.emit()
	return true


## Removes one item of a design from the shelf and returns it, or null if there
## is none. Good ones go first: a flawed one only when nothing else is left,
## one printed in a single colour only when there is none in full colour, and
## one that has been finished before one that hasn't.
func take(product: StringName) -> PrintedItem:
	var found := _best(product)
	return take_item(found) if found != null else null


## The finished prints the client of a contract would take.
func items_for(contract: Contracts.Contract) -> Array[PrintedItem]:
	return _items().filter(func(item: PrintedItem) -> bool: return Game.contracts.wants(contract, item.facts()))


## Takes a particular print off the shelf, or out of the bin it is in.
func take_item(item: PrintedItem) -> PrintedItem:
	var holder := item.get_parent()
	if holder is StorageBin:
		(holder as StorageBin).remove(item)
	else:
		holder.remove_child(item)
	Game.changed.emit()
	return item


## The prints that have not been over the finishing bench yet.
func unfinished() -> Array[PrintedItem]:
	return _items().filter(func(item: PrintedItem) -> bool: return not item.finished)


## Takes an unfinished print of a design off the shelf, or null if there is none.
func take_unfinished(product: StringName) -> PrintedItem:
	for item in unfinished():
		if item.product == product:
			return take_item(item)
	return null


## Every storage bin in use.
func bins() -> Array[StorageBin]:
	var found: Array[StorageBin] = []
	for slot in _slots:
		if slot.get_child_count() > 0 and slot.get_child(0) is StorageBin:
			found.append(slot.get_child(0))
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
	await agent.go_to(_slot_of(item).get_meta(&"unit"))
	if not is_instance_valid(item) or not _items().has(item):
		return
	await agent.reach(func() -> void: agent.carry(take_item(item)))
	await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
	await agent.reach(func() -> void: agent.release().queue_free())


## Turns a print of a bin design, where it sits, into a storage bin.
func _use_as_bin(agent: Agent, product: StringName) -> void:
	var shell: PrintedItem = null
	for item in _loose():
		if item.product == product:
			shell = item
			break
	if shell == null or not Game.storage.is_bin(product):
		agent.say("There isn't one on the shelf to use")
		return
	var slot := shell.get_parent() as Node3D
	await agent.go_to(slot.get_meta(&"unit"))
	await agent.reach(func() -> void:
		if shell.get_parent() == slot:
			make_bin(shell))
	agent.say("That's somewhere to keep %s" % Game.storage.bin_summary(product))


## Takes an empty storage bin out of use, leaving the print it is on the shelf.
func _stop_using(agent: Agent, bin: StorageBin) -> void:
	if not is_instance_valid(bin) or not bins().has(bin) or not bin.items.is_empty():
		agent.say("That bin has things in it")
		return
	var slot := bin.get_parent() as Node3D
	await agent.go_to(slot.get_meta(&"unit"))
	await agent.reach(func() -> void:
		if is_instance_valid(bin):
			unmake_bin(bin))


## How far down the queue to be sold an item is: 0 for one as it should be.
func _rank(item: PrintedItem) -> int:
	return (4 if item.is_flawed() else 0) + (2 if item.is_plain() else 0) + (0 if item.finished else 1)


## The print of a design that would be taken first, or null.
func _best(product: StringName) -> PrintedItem:
	var found: PrintedItem = null
	for item in _items():
		if item.product == product and (found == null or _rank(item) < _rank(found)):
			found = item
	return found


## The space something would be put away in. For a print: one holding a bin
## that already has its design in and room for another, else any bin with
## room, else an empty one. Null if there is nowhere.
func _home_for(item: Node3D) -> Node3D:
	if item is PrintedItem:
		var product := (item as PrintedItem).product
		var roomy: Node3D = null
		for bin in bins():
			if bin.room_for(product) <= 0:
				continue
			if bin.items.any(func(inside: PrintedItem) -> bool: return inside.product == product):
				return bin.get_parent()
			if roomy == null:
				roomy = bin.get_parent()
		if roomy != null:
			return roomy
	return _empty_slot()


func _empty_slot() -> Node3D:
	for slot in _slots:
		if slot.get_child_count() == 0:
			return slot
	return null


## The space a print is in, whether loose or in a bin there.
func _slot_of(item: PrintedItem) -> Node3D:
	var holder := item.get_parent()
	return (holder.get_parent() if holder is StorageBin else holder) as Node3D


func _spare_box(part: StringName) -> SparePart:
	for box in spares():
		if box.part == part:
			return box
	return null


## The prints sitting in spaces of their own.
func _loose() -> Array[PrintedItem]:
	var items: Array[PrintedItem] = []
	for slot in _slots:
		if slot.get_child_count() > 0 and slot.get_child(0) is PrintedItem:
			items.append(slot.get_child(0))
	return items


## Every print on the shelving: those in spaces of their own, then those in bins.
func _items() -> Array[PrintedItem]:
	var items := _loose()
	for bin in bins():
		items.append_array(bin.items)
	return items


## The spaces on a unit, the easy-to-reach shelves first, leaving the top and
## bottom for last. Each remembers the unit it is on.
func _slots_of(unit: Interactable) -> Array[Node3D]:
	var found: Array[Node3D] = []
	found.assign(unit.find_children("item_slot_*", "Node3D", true, false))
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return absf(a.position.y - EASY_REACH_HEIGHT) < absf(b.position.y - EASY_REACH_HEIGHT))
	for slot in found:
		slot.set_meta(&"unit", unit)
	return found


func save() -> Dictionary:
	var stored: Array[Dictionary] = []
	for slot in _slots:
		if slot.get_child_count() == 0:
			continue
		var thing := slot.get_child(0)
		var entry: Dictionary = thing.call(&"save")
		entry["slot"] = slot.name
		entry["unit"] = units().find(slot.get_meta(&"unit"))
		entry["kind"] = "spare" if thing is SparePart else ("bin" if thing is StorageBin else "print")
		stored.append(entry)
	return {"slots": stored, "units": _units.map(func(unit: FittingUnit) -> Dictionary: return unit.save())}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data.get("units", []):
		if Game.data.fittings.has(entry.get("fitting", "")):
			add_unit(StringName(entry["fitting"]), FittingUnit.saved_transform(entry))
	var homeless: Array[Node3D] = []
	for entry: Dictionary in data["slots"]:
		var thing: Node3D
		match entry["kind"]:
			"spare":
				thing = SparePart.restored(entry)
			"bin":
				thing = StorageBin.restored(entry)
			_:
				thing = PrintedItem.restored(entry)
		if thing == null:
			continue
		var unit_index := int(entry.get("unit", 0))
		var slot: Node3D = units()[unit_index].find_child(entry["slot"], true, false) if unit_index < unit_count() else null
		if slot != null and slot.get_child_count() == 0:
			Interactable.attach(thing, slot)
		else:
			homeless.append(thing)
	# What stood on shelving that isn't here (after a move, say) goes wherever there is room.
	for thing in homeless:
		if not store(thing):
			thing.queue_free()
