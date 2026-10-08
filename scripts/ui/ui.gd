class_name Ui
extends RefCounted
## Small helpers for building UI in code, so screens stay short and consistent.
## Placeholder look until the UI pass in Phase 5.

const MUTED := Color(1, 1, 1, 0.6)
const GOOD := Color(0.62, 0.86, 0.55)
const BAD := Color(0.95, 0.55, 0.5)


static func label(text: String, font_size := 16, colour := Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", colour)
	return node


static func button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = not enabled
	node.pressed.connect(on_pressed)
	return node


## Lays children out left to right. A null child becomes a stretchy gap.
static func row(children: Array, separation := 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	for child: Control in children:
		node.add_child(child if child != null else spacer())
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## A label that takes a fixed share of a row, for lining rows up as columns.
static func cell(text: String, width: int, colour := Color.WHITE) -> Label:
	var node := label(text, 16, colour)
	node.custom_minimum_size.x = width
	node.clip_text = true
	return node


## Muted explanatory text that wraps to the width it is given.
static func note(text: String) -> Label:
	var node := label(text, 16, MUTED)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func heading(text: String) -> Label:
	return label(text, 20)


## Removes and frees every child of a container, ready to rebuild it.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## A dark rounded panel style.
static func panel_style(alpha := 0.82) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.17, alpha)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	return style
