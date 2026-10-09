class_name Hud
extends CanvasLayer
## On-screen status while in the garage: what the character is doing and has
## queued, the to-do note beneath it, the speed, cash and clock chips, the name of the object under the
## mouse, and short messages. Styled to match the PlateOS taskbar.

const CONTROLS := "Left click: choose a task, or walk   ·   Mouse wheel: zoom   ·   Right drag: pan"
const TOAST_SECONDS := 4.0
const MAX_TOASTS := 4
## Toasts wider than this wrap onto more lines.
const TOAST_WIDTH := 760.0
const TOAST_COLOURS := {
	&"": [Ui.CREAM, Ui.INK],
	&"good": [Ui.GREEN_SOFT, Ui.GREEN_DARK],
	&"bad": [Ui.RED_SOFT, Ui.RED_DARK],
}

@export var agent_path: NodePath

var _task: Label
var _queue: Label
var _task_panel: PanelContainer
var _todo: TodoNote
var _hover: PanelContainer
var _orders: Label
var _toasts: VBoxContainer

@onready var _agent: Agent = get_node(agent_path)


func _ready() -> void:
	_task = Ui.text("", 15, Ui.PAPER, 800)
	_queue = Ui.text("", 13, Ui.CHIP_TEXT)
	_task_panel = Ui.panel(Ui.vbox([_task, _queue], 2), Ui.box(Ui.TASKBAR, 16, 16, 12))
	_task_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_todo = TodoNote.new()
	_todo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_place(Ui.vbox([_task_panel, Ui.margin(_todo, 6, 0, 0, 0)], 18), Control.PRESET_TOP_LEFT, Vector2(16, 16))

	_orders = Ui.text("", 14, Ui.CHIP_TEXT, 800)
	_orders.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var status := Ui.panel(Ui.hbox([_orders, StatusBar.new()], 14), Ui.box(Ui.TASKBAR, 18, 12, 10))
	status.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(status, Control.PRESET_TOP_RIGHT, Vector2(-16, 16))

	_place(Ui.panel(Ui.text(CONTROLS, 13, Ui.CHIP_TEXT), Ui.box(Color(Ui.TASKBAR, 0.85), 14, 14, 8)),
		Control.PRESET_BOTTOM_LEFT, Vector2(16, -16))

	var badges := PrinterBadges.new()
	badges.theme = Ui.theme()
	add_child(badges)
	move_child(badges, 0)

	_hover = Ui.panel(Ui.text("", 14, Ui.INK, 800), Ui.box(Ui.CREAM, 12, 12, 7, Ui.SHADE, 4))
	_hover.visible = false
	_place(_hover, Control.PRESET_TOP_LEFT, Vector2.ZERO)

	# Messages sit on their own layer so they still show over the PC screen.
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 5
	add_child(toast_layer)
	_toasts = Ui.vbox([], 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.theme = Ui.theme()
	toast_layer.add_child(_toasts)
	# Bottom centre, clear of the PC's banners and the taskbar.
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.position.y -= 84

	_agent.status_changed.connect(_refresh)
	_agent.said.connect(_show_toast)
	Game.notified.connect(_show_toast)
	Game.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	Ui.release()


func _process(_delta: float) -> void:
	if _hover.visible:
		_hover.position = get_viewport().get_mouse_position() + Vector2(18, 20)


## Name of the object under the mouse, or "" for none.
func set_hover(text: String) -> void:
	(_hover.get_child(0) as Label).text = text
	_hover.visible = not text.is_empty()
	_hover.reset_size()


func _refresh() -> void:
	# The scene may be on its way out (a move to other premises) while signals still arrive.
	if not is_inside_tree():
		return
	if _agent.is_busy() and _agent.current_label != "":
		_task.text = "Doing: %s" % _agent.current_label
	else:
		_task.text = "Ready. Click something to give a task."
	_todo.refresh()
	var queued := _agent.get_queued_labels()
	_queue.text = "Next: " + ", ".join(queued)
	_queue.visible = not queued.is_empty()
	_task_panel.reset_size()
	var open := Game.open_orders().size()
	_orders.text = "%d order%s to pack" % [open, "" if open == 1 else "s"]


## Shows a message for a few seconds. `tone` tints it: &"good", &"bad" or plain.
func _show_toast(text: String, tone: StringName = &"") -> void:
	if not is_inside_tree():
		return
	var colours: Array = TOAST_COLOURS.get(tone, TOAST_COLOURS[&""])
	var label := Ui.text(text, 15, colours[1], 800)
	if label.get_minimum_size().x > TOAST_WIDTH:
		Ui.wrap(label)
		label.custom_minimum_size.x = TOAST_WIDTH
	var toast := Ui.panel(label, Ui.box(colours[0], 16, 18, 10, Ui.SHADE, 5))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(toast)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	# Real time, so messages still clear while the game is paused or sped up.
	await get_tree().create_timer(TOAST_SECONDS, true, false, true).timeout
	if is_instance_valid(toast):
		toast.queue_free()


## Adds a panel anchored to a corner of the screen, nudged by `offset`.
func _place(panel: Control, preset: Control.LayoutPreset, offset: Vector2) -> void:
	panel.theme = Ui.theme()
	if panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_LEFT else Control.GROW_DIRECTION_END
	panel.position += offset
