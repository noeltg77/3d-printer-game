class_name Ui
extends RefCounted
## The game's UI design system, taken from the PlateOS mock-ups: colours, the
## two fonts, and builders for the recurring pieces (cards with a flat drop
## shadow, chunky buttons, pills, bars). Screens are assembled from these so
## everything matches.

const INK := Color("22313A")
const MUTED := Color("5A6A72")
const CREAM := Color("FBF8F3")
const PAPER := Color("FFF7EC")
const INSET := Color("F1EBE0")
const SOFT := Color("F4EFE6")
const TRACK := Color("E0D6C6")
const LINE := Color("EAE1D2")
const WHITE := Color.WHITE
const CLEAR := Color(0, 0, 0, 0)

const ORANGE := Color("E8792B")
const ORANGE_DARK := Color("B85A17")
const GREEN := Color("2F8F6B")
const GREEN_DARK := Color("1F6A4E")
const GREEN_SOFT := Color("DDF2E6")
const RED := Color("B5432F")
const RED_DARK := Color("8C2F1F")
const RED_SOFT := Color("F8DDD6")
const AMBER_DARK := Color("7A4A12")
const AMBER_SOFT := Color("F8E6CC")

const TASKBAR := Color("1E2A30")
const CHIP := Color("2C3B42")
const CHIP_TEXT := Color("C9D3D7")
const CHIP_MUTED := Color("8FA0A7")
const CASH := Color("9BE3B8")
## The soft shadow under cards that sit on the wallpaper or the 3D view.
const SHADE := Color(0.133, 0.192, 0.227, 0.18)

const HEADING := &"fredoka"
const BODY := &"nunito"

static var _fonts: Dictionary[String, Font] = {}
static var _theme: Theme = null


## One of the two variable fonts at a given weight.
static func font(family: StringName, weight: int) -> Font:
	var key := "%s:%d" % [family, weight]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = load("res://assets/fonts/%s.woff2" % family)
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = variation
	return _fonts[key]


## Body text (Nunito).
static func text(content: String, size := 14, colour := INK, weight := 700) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_override(&"font", font(BODY, weight))
	node.add_theme_font_size_override(&"font_size", size)
	node.add_theme_color_override(&"font_color", colour)
	return node


## Heading text (Fredoka).
static func title(content: String, size := 20, colour := INK, weight := 600) -> Label:
	var node := text(content, size, colour)
	node.add_theme_font_override(&"font", font(HEADING, weight))
	return node


## Makes a label wrap to the width it is given.
static func wrap(node: Label) -> Label:
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## Gives a control a fixed width, for lining rows up as columns.
static func width(node: Control, pixels: float) -> Control:
	node.custom_minimum_size.x = pixels
	if node is Label:
		node.clip_text = true
	return node


## Lets a control take the spare room in its row or column.
static func grow(node: Control, ratio := 1.0) -> Control:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = ratio
	return node


## A rounded box. `drop` adds the flat offset shadow from the mock-ups, drawn
## as a thick bottom edge in the `shadow` colour.
static func box(bg: Color, radius := 14, pad_x := 12, pad_y := 12, shadow := CLEAR, drop := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y + drop
	style.border_width_bottom = drop
	style.border_color = shadow
	style.anti_aliasing_size = 0.6
	return style


## A box with an outline all round instead of a drop shadow.
static func outlined(bg: Color, line: Color, radius := 14, pad_x := 12, pad_y := 12, thickness := 2) -> StyleBoxFlat:
	var style := box(bg, radius, pad_x, pad_y)
	style.set_border_width_all(thickness)
	style.border_color = line
	return style


static func panel(content: Control, style: StyleBox) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override(&"panel", style)
	if content != null:
		node.add_child(content)
	return node


## The standard white card with a flat shadow.
static func card(content: Control, radius := 20, pad := 16, shadow := LINE, bg := WHITE) -> PanelContainer:
	return panel(content, box(bg, radius, pad, pad, shadow, 4))


## Children stacked top to bottom. A null child becomes a stretchy gap.
static func vbox(children: Array, separation := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	for child: Control in children:
		node.add_child(child if child != null else spacer())
	return node


## Children laid out left to right. A null child becomes a stretchy gap.
static func hbox(children: Array, separation := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	for child: Control in children:
		node.add_child(child if child != null else spacer())
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Padding round a control: left, top, right, bottom.
static func margin(content: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var node := MarginContainer.new()
	node.add_theme_constant_override(&"margin_left", left)
	node.add_theme_constant_override(&"margin_top", top)
	node.add_theme_constant_override(&"margin_right", right)
	node.add_theme_constant_override(&"margin_bottom", bottom)
	node.add_child(content)
	return node


## A chunky button. Give `shadow` a colour for the raised look.
static func button(label: String, on_pressed: Callable, bg := INK, fg := PAPER, height := 40,
		radius := 12, shadow := CLEAR, font_size := 14, heading := false) -> Button:
	var node := Button.new()
	node.text = label
	node.custom_minimum_size.y = height
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var drop := 3 if shadow.a > 0.0 else 0
	var pad := 16 if label.length() > 2 else 10
	node.add_theme_stylebox_override(&"normal", box(bg, radius, pad, 0, shadow, drop))
	node.add_theme_stylebox_override(&"hover", box(bg.lightened(0.1), radius, pad, 0, shadow, drop))
	node.add_theme_stylebox_override(&"pressed", box(bg.darkened(0.1), radius, pad, 0, shadow, drop))
	node.add_theme_stylebox_override(&"disabled", box(Color(bg, 0.3) if bg.a > 0.0 else bg, radius, pad, 0))
	node.add_theme_font_override(&"font", font(HEADING, 600) if heading else font(BODY, 800))
	node.add_theme_font_size_override(&"font_size", font_size)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(state, fg)
	node.add_theme_color_override(&"font_disabled_color", Color(fg, 0.75) if bg.a > 0.0 else Color(fg, 0.4))
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	return node


## A small rounded label, for statuses and tags.
static func pill(content: String, fg: Color, bg: Color, size := 12) -> PanelContainer:
	var node := panel(text(content, size, fg, 800), box(bg, 8, 9, 3))
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return node


## Makes any control act as a button: a left click on it calls `on_pressed`.
static func clickable(node: Control, on_pressed: Callable) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_pressed.call())
	return node


## A score out of `total` as a row of dots, `value` of them filled in.
static func pips(value: int, total: int, colour: Color, track := TRACK, dot := 12) -> HBoxContainer:
	var row := hbox([], 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for index in total:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(dot, dot)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override(&"panel", box(colour if index < value else track, dot / 2, 0, 0))
		row.add_child(pip)
	return row


## A rounded progress or stat bar. `value` is 0 to 1.
static func bar(value: float, colour: Color, track := TRACK, height := 10) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.max_value = 1.0
	node.value = clampf(value, 0.0, 1.0)
	node.custom_minimum_size.y = height
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.add_theme_stylebox_override(&"background", box(track, height / 2, 0, 0))
	node.add_theme_stylebox_override(&"fill", box(colour, height / 2, 0, 0))
	return node


## One of the line icons in assets/ui/icons, tinted.
static func icon(icon_name: String, size: int, colour := PAPER) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/ui/icons/%s.svg" % icon_name)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(size, size)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.modulate = colour
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A coloured rounded square with an icon in the middle.
static func icon_tile(icon_name: String, tile: int, icon_size: int, bg: Color, fg := PAPER, radius := 14,
		shadow := CLEAR) -> PanelContainer:
	var node := panel(icon(icon_name, icon_size, fg), box(bg, radius, 0, 0, shadow, 4 if shadow.a > 0.0 else 0))
	node.custom_minimum_size = Vector2(tile, tile + (4 if shadow.a > 0.0 else 0))
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A vertical scroller for content that may outgrow its space.
static func scroll(content: Control) -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(content)
	return node


## A tween that runs in real time, so UI moves the same whether the game is
## paused, sped up or running through the night.
static func tween(node: Node) -> Tween:
	return node.create_tween().set_ignore_time_scale(true)


## Pops a control into view: it grows the last little way from `pivot` (in its
## own coordinates) with a slight overshoot, fading in as it comes.
static func pop_in(node: Control, pivot: Vector2, from := 0.88, seconds := 0.2) -> void:
	node.pivot_offset = pivot
	node.scale = Vector2.ONE * from
	node.modulate.a = 0.0
	var pop := tween(node).set_parallel()
	pop.tween_property(node, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(node, "modulate:a", 1.0, seconds * 0.6)


## Drops the cached fonts and theme. Call once as the game shuts down so they
## are released before the engine checks for leaks.
static func release() -> void:
	_fonts.clear()
	_theme = null


## Removes and frees every child of a container, ready to rebuild it.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Shared theme: default font and the styling for popup menus, text boxes and
## scroll bars. Set it on the top control of each screen.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font(BODY, 700)
	_theme.default_font_size = 14
	_theme.set_color(&"font_color", &"Label", INK)

	_theme.set_stylebox(&"panel", &"PopupMenu", box(CREAM, 16, 8, 8, SHADE, 5))
	_theme.set_stylebox(&"hover", &"PopupMenu", box(INSET, 10, 8, 4))
	_theme.set_stylebox(&"separator", &"PopupMenu", box(TRACK, 1, 0, 1))
	_theme.set_font(&"font", &"PopupMenu", font(BODY, 800))
	_theme.set_font_size(&"font_size", &"PopupMenu", 15)
	_theme.set_color(&"font_color", &"PopupMenu", INK)
	_theme.set_color(&"font_hover_color", &"PopupMenu", INK)
	_theme.set_color(&"font_disabled_color", &"PopupMenu", MUTED)
	_theme.set_constant(&"v_separation", &"PopupMenu", 10)
	_theme.set_constant(&"item_start_padding", &"PopupMenu", 10)
	_theme.set_constant(&"item_end_padding", &"PopupMenu", 10)

	_theme.set_stylebox(&"normal", &"LineEdit", box(PAPER, 22, 20, 0))
	_theme.set_stylebox(&"focus", &"LineEdit", outlined(PAPER, INK, 22, 18, 0))
	_theme.set_font(&"font", &"LineEdit", font(BODY, 700))
	_theme.set_font_size(&"font_size", &"LineEdit", 15)
	_theme.set_color(&"font_color", &"LineEdit", INK)
	_theme.set_color(&"font_placeholder_color", &"LineEdit", MUTED)
	_theme.set_color(&"caret_color", &"LineEdit", INK)

	_theme.set_stylebox(&"scroll", &"VScrollBar", box(CLEAR, 4, 4, 0))
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		_theme.set_stylebox(state, &"VScrollBar", box(TRACK, 4, 4, 0))
	return _theme
