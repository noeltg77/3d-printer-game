class_name Hud
extends CanvasLayer
## On-screen status: clock, speed controls and cash; what the character is
## doing and has queued; the object under the mouse; short messages.
## Placeholder styling until the UI pass in Phase 5.

const CONTROLS := "Left click: choose a task, or walk  |  Mouse wheel: zoom  |  Right drag: pan"
const SPEED_LABELS := {0: "Pause", 1: "1x", 2: "2x", 4: "4x"}
const TOAST_SECONDS := 4.0
const MAX_TOASTS := 4

@export var agent_path: NodePath

var _task: Label
var _hover: Label
var _clock: Label
var _cash: Label
var _orders: Label
var _toasts: VBoxContainer
var _speed_buttons: Dictionary[int, Button] = {}

@onready var _agent: Agent = get_node(agent_path)


func _ready() -> void:
	_task = _make_chip(Control.PRESET_TOP_LEFT, Vector2(16, 14))
	_hover = _make_chip(Control.PRESET_TOP_LEFT, Vector2.ZERO)
	_make_chip(Control.PRESET_BOTTOM_LEFT, Vector2(16, -14)).text = CONTROLS
	_set_text(_hover, "")
	_build_status_bar()
	_build_toasts()
	_agent.status_changed.connect(_refresh_task)
	_agent.said.connect(_show_toast)
	Game.notified.connect(_show_toast)
	Game.changed.connect(_refresh_status)
	_refresh_task()
	_refresh_status()


func _process(_delta: float) -> void:
	_clock.text = Game.clock.label()
	if _hover.get_parent().visible:
		_hover.get_parent().position = get_viewport().get_mouse_position() + Vector2(18, 20)


## Name of the object under the mouse, or "" for none.
func set_hover(text: String) -> void:
	_set_text(_hover, text)


func _refresh_task() -> void:
	var text := "Doing: %s" % _agent.current_label if _agent.is_busy() else _idle_hint()
	var queued := _agent.get_queued_labels()
	if not queued.is_empty():
		text += "\nNext: " + ", ".join(queued)
	_set_text(_task, text)


## What to suggest while the character has nothing to do, based on how far
## the business has got. A stand-in for proper onboarding in Phase 5.
func _idle_hint() -> String:
	var tree := get_tree()
	if not tree.get_nodes_in_group(&"delivery_box").is_empty():
		return "A delivery is waiting by the garage door. Click it to unpack."
	if tree.get_nodes_in_group(&"printer").is_empty():
		if Game.supplier.pending.is_empty():
			return "Click the PC and order a printer and some filament from the Supplier tab."
		return "Your order is on its way. Speed up time with the buttons top right."
	var listed := Game.market.listings.values().any(func(entry: Dictionary) -> bool: return entry["listed"])
	if not listed:
		return "Click the PC and list a design for sale on Craftsy."
	return "Idle. Click the printer, workbench or PC to give a task."


func _refresh_status() -> void:
	if not _agent.is_busy():
		_refresh_task()
	_cash.text = Money.text(Game.bank.cash)
	_cash.add_theme_color_override(&"font_color", Ui.BAD if Game.bank.cash < 0 else Color.WHITE)
	var open := Game.market.open_orders().size()
	_orders.text = "%d order%s to pack" % [open, "" if open == 1 else "s"]
	for speed in _speed_buttons:
		_speed_buttons[speed].button_pressed = speed == Game.speed


func _show_toast(text: String) -> void:
	var toast := Ui.label(text)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", Ui.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(toast)
	_toasts.add_child(panel)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	# Real time, so messages still clear while the game is paused or sped up.
	await get_tree().create_timer(TOAST_SECONDS, true, false, true).timeout
	if is_instance_valid(panel):
		panel.queue_free()


func _build_status_bar() -> void:
	_clock = Ui.label("", 18)
	_cash = Ui.label("", 18)
	_orders = Ui.label("", 16, Ui.MUTED)
	var speeds := Ui.row([], 4)
	for speed in Game.SPEEDS:
		var button := Ui.button(SPEED_LABELS[speed], Game.set_speed.bind(speed))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		_speed_buttons[speed] = button
		speeds.add_child(button)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", Ui.panel_style())
	panel.add_child(Ui.row([_clock, speeds, _cash, _orders], 18))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position += Vector2(-16, 14)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.position.y += 70


func _set_text(label: Label, text: String) -> void:
	label.text = text
	label.get_parent().visible = not text.is_empty()


## A label on a dark rounded panel, anchored to a corner of the screen.
func _make_chip(preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", Ui.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_LEFT else Control.GROW_DIRECTION_END
	panel.position += offset
	return label
