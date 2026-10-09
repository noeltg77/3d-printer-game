class_name PcScreen
extends CanvasLayer
## The in-game computer, "PlateOS": a full-screen desktop with app icons and
## status widgets, apps that open in a browser-style window, and a taskbar.
## Opened by the Computer interactable once the character is sitting down.
##
## While it is open the character is held in the chair, so tasks started from
## an app (packing an order) queue up and begin when the PC is closed.
## Each app is a control with `screen` set to this node and a refresh() method.

const CHROME := Color("E9E2D6")
const CHROME_LINE := Color("D6CCBC")

## Apps in desktop order. Those without a script show as not installed yet.
const APPS: Array[Dictionary] = [
	{"id": "spoolhouse", "name": "Spoolhouse", "colour": "E8792B", "dark": "B85A17", "url": "spoolhouse.shop/filament",
		"script": preload("res://scripts/ui/pc/app_spoolhouse.gd")},
	{"id": "printbay", "name": "Printbay", "colour": "3A6FD8", "dark": "26509F", "url": "printbay.co/printers",
		"script": preload("res://scripts/ui/pc/app_printbay.gd")},
	{"id": "craftsy", "name": "Craftsy", "colour": "C9415F", "dark": "962E46", "url": "craftsy.com/your-shop",
		"market": "craftsy", "script": preload("res://scripts/ui/pc/app_craftsy.gd")},
	{"id": "biddle", "name": "Biddle", "colour": "2F7FD1", "dark": "1F5A99", "url": "biddle.co.uk/seller-hub",
		"market": "biddle", "script": preload("res://scripts/ui/pc/app_craftsy.gd")},
	{"id": "design_lab", "name": "Design Lab", "colour": "7A5BC4", "dark": "573F92", "url": "designlab.app/catalogue",
		"script": preload("res://scripts/ui/pc/app_design_lab.gd")},
	{"id": "pennybank", "name": "PennyBank", "colour": "2F8F6B", "dark": "1F6A4E", "url": "pennybank.com/account",
		"script": preload("res://scripts/ui/pc/app_pennybank.gd")},
	{"id": "roomier", "name": "Roomier", "colour": "2B8C8C", "dark": "1D6464", "url": "roomier.co.uk/units-to-let",
		"script": preload("res://scripts/ui/pc/app_roomier.gd")},
	{"id": "stockroom", "name": "Stockroom", "colour": "4A6A8A", "dark": "34506B", "url": "plateos://stockroom",
		"script": preload("res://scripts/ui/pc/app_stockroom.gd")},
	{"id": "inbox", "name": "Inbox", "colour": "2B7A9E", "dark": "1D5A76", "url": "plateos://inbox",
		"script": preload("res://scripts/ui/pc/app_inbox.gd")},
	{"id": "stats", "name": "Stats", "colour": "D9A23A", "dark": "A87A22"},
	{"id": "settings", "name": "Settings", "colour": "5C6B73", "dark": "3E4A50", "url": "plateos://settings",
		"script": preload("res://scripts/ui/pc/app_settings.gd")},
]

var _body: Control
## The desktop or app currently shown: whatever refresh() should redraw.
var _view: Control = null
var _current := ""
var _refresh_queued := false


func _ready() -> void:
	add_to_group(&"pc_screen")
	layer = 2
	visible = false

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	var root := Ui.vbox([_body, _build_taskbar()], 0)
	root.theme = Ui.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# An opaque backdrop also stops clicks reaching the game behind.
	var backdrop := ColorRect.new()
	backdrop.color = Ui.CREAM
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(root)

	# The desktop shows live progress, so it redraws on a real-time tick as
	# well as when the game announces a change.
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.ignore_time_scale = true
	tick.autostart = true
	tick.timeout.connect(func() -> void:
		if _current == "":
			refresh())
	add_child(tick)
	Game.changed.connect(refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _current == "":
			close()
		else:
			show_desktop()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_agent().held = true
	show_desktop()


func close() -> void:
	visible = false
	_agent().held = false


func show_desktop() -> void:
	_show("")


func show_app(id: String) -> void:
	_show(id)


## Redraws the current view. Deferred, because a refresh is often triggered by
## a button the redraw removes.
func refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_redraw.call_deferred()


## The name to show for an app. Shops and the marketplace take theirs from data.
static func app_name(entry: Dictionary) -> String:
	var settings: Dictionary = Game.data.settings
	match entry["id"]:
		"spoolhouse":
			return settings["supplier"]["filament_shop"]
		"printbay":
			return settings["supplier"]["hardware_shop"]
		"pennybank":
			return settings["bank_name"]
	if entry.has("market"):
		return Game.markets[StringName(entry["market"])].config["name"]
	return entry["name"]


static func app(id: String) -> Dictionary:
	for entry in APPS:
		if entry["id"] == id:
			return entry
	return {}


func _redraw() -> void:
	_refresh_queued = false
	if visible and _view != null:
		_view.refresh()


func _show(id: String) -> void:
	_current = id
	Ui.clear(_body)
	var content: Control
	if id == "":
		_view = PcDesktop.new()
		content = _view
	else:
		_view = app(id)["script"].new()
		_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content = Ui.vbox([_build_chrome(id), _view], 0)
	_view.set(&"screen", self)
	if id != "":
		_view.set(&"app", app(id))
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(content)
	_view.refresh()


## The browser-style bar above an app: home, a tab per app, address and close.
func _build_chrome(current: String) -> Control:
	var home := Ui.button("", show_desktop, Ui.CREAM, Ui.INK, 36, 10)
	home.custom_minimum_size.x = 36
	home.tooltip_text = "Back to the desktop"
	home.add_child(_inset(Ui.icon("home", 20, Ui.INK), 8))

	var tabs := Ui.hbox([], 6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_END
	for entry in APPS:
		if not entry.has("script"):
			continue
		var active: bool = entry["id"] == current
		var style := Ui.box(Ui.CREAM if active else Ui.CLEAR, 12, 18, 0)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Ui.CREAM if active else Color(Ui.CREAM, 0.5)
		var tab := Button.new()
		tab.text = "      %s" % app_name(entry)
		tab.custom_minimum_size.y = 42
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_stylebox_override(&"normal", style)
		tab.add_theme_stylebox_override(&"pressed", style)
		tab.add_theme_stylebox_override(&"hover", hover)
		tab.add_theme_font_override(&"font", Ui.font(Ui.BODY, 800 if active else 700))
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			tab.add_theme_color_override(state, Ui.INK if active else Ui.MUTED)
		tab.pressed.connect(show_app.bind(entry["id"]))
		# The coloured dot that identifies the app.
		var dot := Panel.new()
		dot.add_theme_stylebox_override(&"panel", Ui.box(Color.html(entry["colour"]), 6, 0, 0))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(12, 12)
		dot.position = Vector2(18, 15)
		tab.add_child(dot)
		tabs.add_child(tab)

	var address := Ui.panel(Ui.text(app(current)["url"], 14, Ui.MUTED), Ui.box(Ui.SOFT, 17, 16, 0))
	address.custom_minimum_size.y = 34
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	address.get_child(0).size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var close_app := Ui.button("", show_desktop, Ui.CLEAR, Ui.INK, 36, 10)
	close_app.custom_minimum_size.x = 36
	close_app.tooltip_text = "Close"
	close_app.add_child(_inset(Ui.icon("close", 18, Ui.INK), 9))

	var style := Ui.box(CHROME, 0, 14, 0)
	style.border_width_bottom = 1
	style.border_color = CHROME_LINE
	var bar := Ui.panel(Ui.hbox([home, tabs, address, close_app], 8), style)
	bar.custom_minimum_size.y = 52
	return bar


func _build_taskbar() -> Control:
	var start := Ui.button("PlateOS", show_desktop, Ui.ORANGE, Ui.PAPER, 44, 14, Ui.CLEAR, 17, true)
	start.tooltip_text = "Show the desktop"
	var leave := Ui.button("Leave the desk", close, Ui.CHIP, Ui.CHIP_TEXT, 44, 14, Ui.CLEAR, 15)
	var bar := Ui.panel(Ui.hbox([start, leave, null, StatusBar.new()], 12), Ui.box(Ui.TASKBAR, 0, 16, 10))
	bar.custom_minimum_size.y = 64
	return bar


## Fills the parent, less a border, so an icon sits centred on its button.
func _inset(node: Control, border: int) -> Control:
	node.custom_minimum_size = Vector2.ZERO
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = border
	node.offset_top = border
	node.offset_right = -border
	node.offset_bottom = -border
	return node


func _agent() -> Agent:
	return get_tree().get_first_node_in_group(&"player")
