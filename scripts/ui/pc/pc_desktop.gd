class_name PcDesktop
extends Control
## The PlateOS desktop: landscape wallpaper, a grid of app icons on the left,
## and on the right a live card for each printer, the next delivery and a
## sticky note of things to do.

const WEEKDAYS: PackedStringArray = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const NOTE := Color("FFE58A")
const NOTE_INK := Color("4A3B12")
const DELIVERY_TINT := Color("FBE3CC")
const NOTE_WIDTH := 240.0

var screen: PcScreen

var _widgets: VBoxContainer
## App id -> the count bubble on its icon.
var _badges: Dictionary[String, PanelContainer] = {}
var _built := false


func refresh() -> void:
	if not _built:
		_build()
	Ui.clear(_widgets)
	_widgets.add_child(_garage_card())
	var delivery := _delivery_card()
	if delivery != null:
		_widgets.add_child(delivery)
	_widgets.add_child(_sticky_note())
	_set_badge("craftsy", Game.market.open_orders().size())


func _build() -> void:
	_built = true
	var wallpaper := TextureRect.new()
	wallpaper.texture = load("res://assets/ui/wallpaper.svg")
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wallpaper)

	var icons := GridContainer.new()
	icons.columns = 2
	icons.add_theme_constant_override(&"h_separation", 16)
	icons.add_theme_constant_override(&"v_separation", 20)
	for entry in PcScreen.APPS:
		icons.add_child(_app_icon(entry))
	icons.position = Vector2(32, 32)
	add_child(icons)

	_widgets = Ui.vbox([], 16)
	_widgets.custom_minimum_size.x = 380
	add_child(_widgets)
	_widgets.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_widgets.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_widgets.position += Vector2(-32, 32)


func _app_icon(entry: Dictionary) -> Control:
	var installed := entry.has("script")
	var tile := Ui.icon_tile(entry["id"], 72, 40, Color.html(entry["colour"]), Ui.PAPER, 22, Color.html(entry["dark"]))
	var label := Ui.title(PcScreen.app_name(entry), 15, Ui.PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := Ui.vbox([tile, label], 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 10
	column.offset_bottom = -10

	var button := Button.new()
	button.custom_minimum_size = Vector2(108, 126)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override(&"normal", Ui.box(Color(Ui.CREAM, 0.18), 18, 0, 0))
	button.add_theme_stylebox_override(&"hover", Ui.box(Color(Ui.CREAM, 0.34), 18, 0, 0))
	button.add_theme_stylebox_override(&"pressed", Ui.box(Color(Ui.CREAM, 0.42), 18, 0, 0))
	button.add_theme_stylebox_override(&"disabled", Ui.box(Color(Ui.CREAM, 0.1), 18, 0, 0))
	button.add_child(column)
	if installed:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: screen.show_app(entry["id"]))
	else:
		button.disabled = true
		button.tooltip_text = "Not installed yet"
		column.modulate.a = 0.45

	# Count bubble on the top right corner of the icon, hidden until needed.
	var badge := Ui.panel(Ui.text("", 14, Color.html(entry["colour"]), 800), Ui.box(Ui.PAPER, 13, 8, 2, Color(0, 0, 0, 0.15), 2))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.position = Vector2(70, 2)
	button.add_child(badge)
	_badges[entry["id"]] = badge
	return button


func _set_badge(id: String, count: int) -> void:
	var badge := _badges[id]
	badge.visible = count > 0
	(badge.get_child(0) as Label).text = str(count)


func _garage_card() -> Control:
	var clock := Game.clock
	var rows := Ui.vbox([], 12)
	var printers := get_tree().get_nodes_in_group(&"printer")
	for index in printers.size():
		rows.add_child(_printer_row(index + 1, printers[index]))
	if printers.is_empty():
		var hint := Ui.wrap(Ui.text("No printer yet. Order one from %s." % Game.data.settings["supplier"]["hardware_shop"], 13, Ui.MUTED))
		rows.add_child(Ui.panel(hint, Ui.box(Ui.INSET, 14, 14, 12)))
	var header := Ui.hbox([
		Ui.title("The garage", 20), null,
		Ui.text("Day %d · %s" % [clock.day, WEEKDAYS[(clock.day - 1) % 7]], 13, Ui.MUTED),
	])
	return Ui.panel(Ui.vbox([header, rows], 16), Ui.box(Ui.CREAM, 22, 20, 20, Ui.SHADE, 6))


func _printer_row(number: int, printer: PrinterStation) -> Control:
	var status := "Idle"
	var colour := Ui.MUTED
	var detail := "No filament loaded" if printer.spool == null else "Loaded: %s" % printer.spool.describe()
	var column := Ui.vbox([], 2)
	match printer.status:
		PrinterStation.Status.PRINTING:
			status = "Printing"
			colour = Ui.GREEN
			detail = "%s · %s %s" % [Game.product_name(printer.item.product),
				String(printer.spool.material).to_upper(), Palette.display_name(printer.spool.colour)]
		PrinterStation.Status.DONE:
			status = "Needs you"
			colour = Ui.RED
			detail = "%s is finished. Collect it to free the printer." % printer.item.describe()
		PrinterStation.Status.FAILED:
			status = "Failed"
			colour = Ui.RED
			detail = "%s: %s. %s." % [Game.product_name(printer.scrap.product), printer.scrap.failure["name"], printer.scrap.failure["fix"]]
	column.add_child(Ui.hbox([
		Ui.text("Printer %d · %s" % [number, printer.display_name], 14, Ui.INK, 800), null,
		Ui.text(status, 14, colour, 800),
	]))
	column.add_child(Ui.wrap(Ui.text(detail, 13, Ui.MUTED)))
	if printer.status == PrinterStation.Status.PRINTING:
		var job := printer.job
		var left := GameClock.duration_label((job.duration - job.elapsed) * GameClock.MINUTES_PER_SECOND)
		column.add_child(Ui.margin(Ui.bar(job.progress, Ui.GREEN, Ui.TRACK, 12), 0, 8, 0, 4))
		column.add_child(Ui.hbox([
			Ui.text("%d%%" % roundi(job.progress * 100.0), 12, Ui.MUTED), null,
			Ui.text("%s left" % left, 12, Ui.MUTED),
		]))
	return Ui.panel(column, Ui.box(Ui.INSET, 14, 14, 12))


## The next delivery on its way, or one already waiting. Null if neither.
func _delivery_card() -> Control:
	var heading := ""
	var detail := ""
	var waiting := get_tree().get_nodes_in_group(&"delivery_box")
	if not waiting.is_empty():
		heading = "Delivery waiting by the door"
		detail = "%d box%s to unpack" % [waiting.size(), "" if waiting.size() == 1 else "es"]
	elif not Game.supplier.pending.is_empty():
		var next: Supplier.Delivery = Game.supplier.pending[0]
		var when := GameClock.new()
		when.minutes = next.arrive_at
		var day := "today" if when.day == Game.clock.day else "on day %d" % when.day
		var minute := int(when.minute_of_day)
		heading = "Delivery %s at %02d:%02d" % [day, minute / 60, minute % 60]
		detail = "%s from %s" % [next.describe(), next.shop]
	else:
		return null
	var text := Ui.vbox([Ui.text(heading, 14, Ui.INK, 800), Ui.wrap(Ui.text(detail, 13, Ui.MUTED))], 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tile := Ui.icon_tile("box", 44, 24, DELIVERY_TINT, Ui.ORANGE_DARK)
	return Ui.panel(Ui.hbox([tile, text], 14), Ui.box(Ui.CREAM, 22, 20, 16, Ui.SHADE, 6))


func _sticky_note() -> Control:
	var lines := Advice.todo(get_tree())
	var content := "To do:\n" + ("\n".join(lines) if not lines.is_empty() else "All caught up. Nice!")
	var label := Ui.wrap(Ui.title(content, 17, NOTE_INK, 500))
	label.add_theme_constant_override(&"line_spacing", 4)
	var note := Ui.panel(label, Ui.box(NOTE, 6, 20, 18, Ui.SHADE, 6))
	note.custom_minimum_size.x = NOTE_WIDTH
	note.rotation_degrees = -2.0
	# Containers straighten their children, so the tilted note sits in a plain
	# holder that reserves the space it needs.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(NOTE_WIDTH, 0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	holder.add_child(note)
	note.resized.connect(func() -> void: holder.custom_minimum_size.y = note.size.y + 12.0)
	return Ui.margin(holder, 0, 8, 12, 0)
