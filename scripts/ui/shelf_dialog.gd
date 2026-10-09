class_name ShelfDialog
extends CanvasLayer
## What is on the shelving, laid out a space to a tile, opened by clicking any
## of it. A storage bin's tile lists what is in it. Things are tidied by
## dragging: a print onto a bin or an empty space, a line in a bin (all of
## that design that fit) onto another bin, a bin or a box of spares onto an
## empty space. Tidying happens at once; the game keeps running behind.

const SHADOW := Color("E4DACA")
const BACKDROP := Color(0.118, 0.165, 0.188, 0.55)
const TILE := Color("F4EEE2")
const BIN_BG := Color("E3F0E6")
const COLUMNS := 6
const TILE_SIZE := Vector2(168, 132)

var _shelf: StorageShelf = null
var _holder: CenterContainer
var _scroll: ScrollContainer = null


## Opens the dialog for a shelf, making it the first time.
static func show_for(shelf: StorageShelf) -> void:
	var dialog: ShelfDialog = shelf.get_tree().get_first_node_in_group(&"shelf_dialog")
	if dialog == null:
		dialog = ShelfDialog.new()
		shelf.get_tree().current_scene.add_child(dialog)
	dialog.open(shelf)


func _ready() -> void:
	add_to_group(&"shelf_dialog")
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	Ui.clickable(backdrop, close)
	backdrop.mouse_default_cursor_shape = Control.CURSOR_ARROW
	add_child(backdrop)
	_holder = CenterContainer.new()
	_holder.theme = Ui.theme()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	Game.changed.connect(_rebuild)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(shelf: StorageShelf) -> void:
	_shelf = shelf
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func _rebuild() -> void:
	if not visible or not is_instance_valid(_shelf):
		return
	var scrolled := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	Ui.clear(_holder)
	var sections := Ui.vbox([], 18)
	var all := _shelf.units()
	for index in all.size():
		sections.add_child(_unit_section(all[index], index))
	_scroll = Ui.scroll(sections)
	_scroll.custom_minimum_size = Vector2(COLUMNS * (TILE_SIZE.x + 10) + 16, 520)
	var total := _shelf.slot_count()
	var close_button := Ui.button("Done", close, Ui.INK, Ui.PAPER, 40, 16)
	var card := Ui.card(Ui.vbox([
		Ui.hbox([Ui.title("Shelving", 26), Ui.pill("%d of %d spaces used" % [total - _shelf.free_slots(), total], Ui.INK, TILE, 13), null, close_button], 14),
		Ui.wrap(Ui.text("Drag a print onto a storage bin or an empty space to tidy up. Dragging a line inside a bin moves every one of that design that fits. New prints go in a bin that already holds the same thing, then any bin with room, then an empty space.", 13, Ui.MUTED)),
		_scroll,
	], 14), 24, 24, SHADOW)
	_holder.add_child(card)
	_restore_scroll.call_deferred(scrolled)


func _restore_scroll(at: int) -> void:
	if at > 0 and is_instance_valid(_scroll):
		await get_tree().process_frame
		if is_instance_valid(_scroll):
			_scroll.scroll_vertical = at


func _unit_section(unit: Interactable, index: int) -> Control:
	var slots := _shelf.unit_slots(unit)
	var used := slots.filter(func(slot: Node3D) -> bool: return slot.get_child_count() > 0).size()
	var heading := Ui.hbox([
		Ui.title("The shelving that was here" if index == 0 else "Shelving unit %d" % (index + 1), 18),
		Ui.text("%d of %d used" % [used, slots.size()], 13, Ui.MUTED), null,
	], 12)
	if unit is FittingUnit:
		heading.add_child(Ui.button("Stand it somewhere else", func() -> void:
			close()
			(unit as FittingUnit).choose_spot(), Ui.WHITE, Ui.INK, 32, 12, SHADOW, 13))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for slot in slots:
		grid.add_child(_tile(slot))
	return Ui.vbox([heading, grid], 8)


func _tile(slot: Node3D) -> Control:
	var thing: Node = slot.get_child(0) if slot.get_child_count() > 0 else null
	var tile: PanelContainer
	if thing == null:
		var empty := Ui.text("Empty", 13, Ui.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile = Ui.panel(empty, Ui.outlined(Ui.WHITE, SHADOW, 14, 10, 10))
		tile.set_drag_forwarding(Callable(), _can_drop_on_space, _drop_on_space.bind(slot))
	elif thing is StorageBin:
		tile = _bin_tile(thing)
	elif thing is SparePart:
		var part := thing as SparePart
		var row: Dictionary = Game.data.kit(String(part.part))
		tile = Ui.panel(Ui.vbox([
			ModelPicture.create(GameData.part_model(row), 56),
			_name(row.get("name", "Spare part")),
			Ui.text("Spares: %d" % part.count, 12, Ui.MUTED),
		], 4), Ui.box(TILE, 14, 10, 10))
		tile.set_drag_forwarding(_drag_thing.bind(thing, row.get("name", "Spare part")), Callable(), Callable())
	else:
		tile = _print_tile(thing as PrintedItem)
	tile.custom_minimum_size = TILE_SIZE
	return tile


func _print_tile(item: PrintedItem) -> PanelContainer:
	var column := Ui.vbox([ModelPicture.of_product(item.product, 56), _name(Game.product_name(item.product))], 4)
	var notes: PackedStringArray = []
	if item.finished:
		notes.append("finished")
	if item.is_flawed():
		notes.append("flawed")
	if item.is_plain():
		notes.append("one colour")
	if not notes.is_empty():
		column.add_child(Ui.text(", ".join(notes).capitalize(), 12, Ui.RED_DARK if item.is_flawed() else Ui.GREEN_DARK, 800))
	if Game.storage.is_bin(item.product):
		column.add_child(Ui.button("Use for storage", func() -> void: _shelf.make_bin(item), Ui.GREEN, Ui.WHITE, 28, 10, Ui.GREEN_DARK, 12))
	var tile := Ui.panel(column, Ui.box(TILE, 14, 10, 10))
	tile.tooltip_text = item.describe()
	tile.set_drag_forwarding(_drag_thing.bind(item, Game.product_name(item.product)), Callable(), Callable())
	return tile


func _bin_tile(bin: StorageBin) -> PanelContainer:
	var column := Ui.vbox([
		Ui.hbox([ModelPicture.of_product(bin.shell.product, 36), _name(Game.product_name(bin.shell.product))], 6),
		Ui.bar(1.0 - float(bin.free_units()) / maxf(bin.units(), 1.0), Ui.GREEN, Ui.WHITE, 8),
	], 6)
	var tile := Ui.panel(column, Ui.box(BIN_BG, 14, 10, 10))
	var counts: Dictionary[StringName, int] = {}
	for item in bin.items:
		counts[item.product] = int(counts.get(item.product, 0)) + 1
	for product in counts:
		var line := Ui.panel(Ui.hbox([
			ModelPicture.of_product(product, 26),
			_name("%d x %s" % [counts[product], Game.product_name(product)], 12),
		], 6), Ui.box(Ui.WHITE, 8, 6, 3))
		line.tooltip_text = "%d x %s. Drag to move them." % [counts[product], Game.product_name(product)]
		var group: Array[PrintedItem] = bin.items.filter(func(item: PrintedItem) -> bool: return item.product == product)
		line.set_drag_forwarding(_drag_group.bind(group, "%d x %s" % [counts[product], Game.product_name(product)]),
			_can_drop_on_bin.bind(bin), _drop_on_bin.bind(bin))
		column.add_child(line)
	if bin.items.is_empty():
		column.add_child(Ui.text("Nothing in it yet", 12, Ui.MUTED))
		column.add_child(Ui.button("Stop using it", func() -> void: _shelf.unmake_bin(bin), Ui.WHITE, Ui.INK, 28, 10, SHADOW, 12))
	else:
		var smallest: Dictionary = Game.data.settings["storage_bins"]["sizes"][0]
		column.add_child(Ui.text("Room for %d %s" % [bin.free_units() / int(smallest["cost"]), String(smallest["name"]).to_lower()], 12, Ui.MUTED))
	tile.tooltip_text = "%s. Holds %s." % [bin.describe(), Game.storage.bin_summary(bin.shell.product)]
	tile.set_drag_forwarding(_drag_thing.bind(bin, Game.product_name(bin.shell.product)), _can_drop_on_bin.bind(bin), _drop_on_bin.bind(bin))
	return tile


func _name(content: String, size := 13) -> Label:
	var label := Ui.text(content, size, Ui.INK, 800)
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 60
	return label


# Dragging. What is carried is { things: the nodes being moved }.

func _drag_thing(_at: Vector2, thing: Node3D, title: String) -> Variant:
	return _carry([thing], title)


func _drag_group(_at: Vector2, group: Array[PrintedItem], title: String) -> Variant:
	var things: Array[Node3D] = []
	things.assign(group)
	return _carry(things, title)


func _carry(things: Array[Node3D], title: String) -> Dictionary:
	var preview := Ui.panel(Ui.text(title, 13, Ui.PAPER, 800), Ui.box(Ui.INK, 10, 12, 6))
	preview.theme = Ui.theme()
	_holder.set_drag_preview(preview)
	return {"things": things}


func _can_drop_on_space(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("things")


func _drop_on_space(_at: Vector2, data: Variant, slot: Node3D) -> void:
	var things: Array = data["things"]
	if is_instance_valid(things[0]):
		_shelf.move_to_slot(things[0], slot)


func _can_drop_on_bin(_at: Vector2, data: Variant, bin: StorageBin) -> bool:
	if not (data is Dictionary and data.has("things")) or not is_instance_valid(bin):
		return false
	var first: Node3D = data["things"][0]
	return first is PrintedItem and first.get_parent() != bin and bin.room_for((first as PrintedItem).product) > 0


func _drop_on_bin(_at: Vector2, data: Variant, bin: StorageBin) -> void:
	var items: Array[PrintedItem] = []
	for thing: Node3D in data["things"]:
		if is_instance_valid(thing) and thing is PrintedItem:
			items.append(thing)
	_shelf.move_into_bin(items, bin)
