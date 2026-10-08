extends Camera3D
## Fixed-angle isometric camera. Mouse wheel zooms, right or middle drag pans.
## The angle and starting position come from the node's transform in the scene.

@export var min_size := 3.0
@export var max_size := 9.0
@export var zoom_step := 0.88
## How far the view can be dragged from its starting point, in metres.
@export var pan_limit := 3.0

var _target_size := 0.0
var _home := Vector3.ZERO
var _pan := Vector2.ZERO


func _ready() -> void:
	_target_size = size
	_home = position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_size = maxf(_target_size * zoom_step, min_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_size = minf(_target_size / zoom_step, max_size)
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		# One pixel of drag moves the view by one pixel's worth of world.
		var metres_per_pixel := size / get_viewport().get_visible_rect().size.y
		_pan += Vector2(-event.relative.x, event.relative.y) * metres_per_pixel
		_pan = _pan.limit_length(pan_limit)


func _process(delta: float) -> void:
	size = lerpf(size, _target_size, 1.0 - exp(-12.0 * delta))
	position = _home + basis.x * _pan.x + basis.y * _pan.y
