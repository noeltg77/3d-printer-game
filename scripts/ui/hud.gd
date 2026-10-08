class_name Hud
extends CanvasLayer
## Minimal on-screen text: what the character is doing and has queued, the name
## of the object under the mouse, short messages, and the controls.
## Placeholder styling until the UI pass in Phase 5.

const CONTROLS := "Left click: choose a task, or walk  |  Mouse wheel: zoom  |  Right drag: pan"
const TOAST_SECONDS := 3.0

@export var agent_path: NodePath

var _task: Label
var _hover: Label
var _toast: Label
var _toast_timer: SceneTreeTimer = null

@onready var _agent: Agent = get_node(agent_path)


func _ready() -> void:
	_task = _make_chip(Control.PRESET_TOP_LEFT, Vector2(16, 14))
	_toast = _make_chip(Control.PRESET_CENTER_TOP, Vector2(0, 14))
	_hover = _make_chip(Control.PRESET_TOP_LEFT, Vector2.ZERO)
	_make_chip(Control.PRESET_BOTTOM_LEFT, Vector2(16, -14)).text = CONTROLS
	_set_text(_toast, "")
	_set_text(_hover, "")
	_agent.status_changed.connect(_refresh_task)
	_agent.said.connect(_show_toast)
	_refresh_task()


func _process(_delta: float) -> void:
	if _hover.get_parent().visible:
		_hover.get_parent().position = get_viewport().get_mouse_position() + Vector2(18, 20)


## Name of the object under the mouse, or "" for none.
func set_hover(text: String) -> void:
	_set_text(_hover, text)


func _refresh_task() -> void:
	var text := "Doing: %s" % _agent.current_label if _agent.is_busy() else "Idle. Click something to give a task."
	var queued := _agent.get_queued_labels()
	if not queued.is_empty():
		text += "\nNext: " + ", ".join(queued)
	_set_text(_task, text)


func _show_toast(text: String) -> void:
	_set_text(_toast, text)
	var timer := get_tree().create_timer(TOAST_SECONDS)
	_toast_timer = timer
	await timer.timeout
	# A newer message may have replaced this one while waiting.
	if _toast_timer == timer:
		_set_text(_toast, "")


func _set_text(label: Label, text: String) -> void:
	label.text = text
	label.get_parent().visible = not text.is_empty()


## A label on a dark rounded panel, anchored to a corner of the screen.
func _make_chip(preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.17, 0.82)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_TOP else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_LEFT else Control.GROW_DIRECTION_END
	panel.position += offset
	return label
