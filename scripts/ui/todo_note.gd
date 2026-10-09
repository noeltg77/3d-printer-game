class_name TodoNote
extends Control
## The yellow sticky note of things to do, from Advice. Shown on the PC desktop
## and down the left of the garage view. The first thing on the list comes with
## a hint on how to do it, for players who have never owned a printer.

const NOTE := Color("FFE58A")
const NOTE_INK := Color("4A3B12")
const HINT_INK := Color("6B5820")
const WIDTH := 240.0
const TILT := -2.0
## Longer lists are cut off with a count of what is left.
const MAX_LINES := 6

var _shown := ""


func _init() -> void:
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Redraws the note if what there is to do has changed.
func refresh() -> void:
	var items := Advice.items(get_tree())
	var summary := JSON.stringify(items)
	if summary == _shown and get_child_count() > 0:
		return
	_shown = summary
	Ui.clear(self)
	var lines := Ui.vbox([Ui.title("To do:", 17, NOTE_INK, 500)], 4)
	if items.is_empty():
		lines.add_child(Ui.wrap(Ui.title("All caught up. Nice!", 17, NOTE_INK, 500)))
	for index in mini(items.size(), MAX_LINES):
		lines.add_child(Ui.wrap(Ui.title(items[index]["text"], 17, NOTE_INK, 500)))
		if index == 0:
			lines.add_child(Ui.margin(Ui.wrap(Ui.text(items[index]["hint"], 13, HINT_INK)), 0, 0, 0, 6))
	if items.size() > MAX_LINES:
		lines.add_child(Ui.text("and %d more" % (items.size() - MAX_LINES), 13, HINT_INK, 800))
	var note := Ui.panel(lines, Ui.box(NOTE, 6, 20, 18, Ui.SHADE, 6))
	note.custom_minimum_size.x = WIDTH
	note.rotation_degrees = TILT
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Containers straighten their children, so the tilted note sits loose in
	# this control, which reserves the space it needs.
	add_child(note)
	note.resized.connect(func() -> void: custom_minimum_size.y = note.size.y + 12.0)
