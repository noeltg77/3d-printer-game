extends Node3D
## Goes on the garage shell. Hides whichever walls stand between the camera and
## the room, so the interior is always visible. Walls are the children named wall_*.

var _walls: Array[Node3D] = []
var _last_view := Vector3.ZERO


func _ready() -> void:
	_walls.assign(find_children("wall_*", "Node3D", false, false))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.global_basis.z == _last_view:
		return
	# Direction from the room towards the camera, flattened onto the floor.
	_last_view = camera.global_basis.z
	var towards_camera := Vector3(_last_view.x, 0.0, _last_view.z).normalized()
	for wall in _walls:
		var side := (wall.global_position - global_position).normalized()
		wall.visible = side.dot(towards_camera) < 0.1
