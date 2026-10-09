class_name Placer
extends Node3D
## Lets the player choose where a piece of furniture goes. A see-through copy
## of it follows the mouse across the floor, green where it can stand and red
## where it can't. Left click puts it there, R or a right click turns it a
## quarter, and Escape gives up. While it is up nothing else takes clicks.
##
## It only chooses the spot: the caller is handed the transform and sets the
## character to the work.

const SNAP := 0.1
const GOOD := Color(0.35, 0.8, 0.45, 0.55)
const BAD := Color(0.9, 0.3, 0.25, 0.55)
## How close to another thing's edge it may stand, in metres.
const GAP := 0.02

var _ghost: Node3D
var _stand_offset := Vector3.ZERO
var _on_placed: Callable
## The thing being moved, if it is already in the room: it doesn't block itself.
var _moving: Node3D = null
var _material := StandardMaterial3D.new()
var _hint: Label
var _layer: CanvasLayer


## Starts choosing a spot for a fitting (a row id of data/fittings.json).
## `on_placed` is called with the transform chosen. `moving` is the unit
## itself if it is being moved rather than put up.
static func begin(from: Node, fitting: StringName, on_placed: Callable, moving: Node3D = null) -> Placer:
	for old in from.get_tree().get_nodes_in_group(&"placer"):
		old.queue_free()
	var row: Dictionary = Game.data.fittings[fitting]
	var placer := Placer.new()
	placer._on_placed = on_placed
	placer._moving = moving
	var stand: Array = row["stand_offset"]
	placer._stand_offset = Vector3(stand[0], stand[1], stand[2])
	placer._ghost = (load(FittingUnit.MODEL_PATH % row["model"]) as PackedScene).instantiate()
	placer.add_child(placer._ghost)
	from.get_tree().current_scene.add_child(placer)
	if moving != null:
		placer._ghost.global_transform = moving.global_transform
	return placer


func _ready() -> void:
	add_to_group(&"placer")
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _material
	_layer = CanvasLayer.new()
	_hint = Ui.text("", 15, Ui.PAPER, 800)
	var pill := Ui.panel(_hint, Ui.box(Ui.INK, 16, 18, 10))
	pill.theme = Ui.theme()
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.position.y -= 180
	_layer.add_child(pill)
	add_child(_layer)
	_update()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var point: Variant = _floor_under(event.position)
		if point != null:
			_ghost.global_position = Vector3(snappedf(point.x, SNAP), 0.0, snappedf(point.z, SNAP))
			_update()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and problem() == "":
			place(_ghost.global_transform)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			turn()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			turn()
		elif event.keycode == KEY_ESCAPE:
			queue_free()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Whatever asked for a spot has gone (its box was unpacked some other way).
	if not _on_placed.is_valid():
		queue_free()


func turn() -> void:
	_ghost.rotate_y(PI / 2.0)
	_update()


## Settles on a spot and hands it to whoever asked.
func place(at: Transform3D) -> void:
	_on_placed.call(at)
	queue_free()


## Why it can't go where it is, or "" if it can.
func problem() -> String:
	return Placer.problem_at(get_tree(), _ghost, _stand_offset, _moving)


## Why `thing` can't stand where it is, or "" if it can. `stand_offset` is where
## it is used from. `ignore` is something it may overlap: itself, before a move.
static func problem_at(tree: SceneTree, thing: Node3D, stand_offset: Vector3, ignore: Node3D = null) -> String:
	var grid: FloorGrid = tree.get_first_node_in_group(&"floor_grid")
	var box := Bounds.of(thing)
	var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	# Furniture may back right up to the wall, which is a little outside where feet can go.
	if not grid.area.grow(grid.agent_radius + GAP).encloses(footprint):
		return "It has to stand inside the room"
	for obstacle: Node3D in tree.get_nodes_in_group(&"obstacle"):
		if obstacle == ignore or obstacle == thing or thing.is_ancestor_of(obstacle):
			continue
		var other := Bounds.of(obstacle)
		if footprint.grow(-GAP).intersects(Rect2(other.position.x, other.position.z, other.size.x, other.size.z)):
			return "Something is in the way"
	var stand := thing.global_transform * stand_offset
	if not grid.area.has_point(Vector2(stand.x, stand.z)):
		return "There would be nowhere to stand to use it"
	for obstacle: Node3D in tree.get_nodes_in_group(&"obstacle"):
		if obstacle == ignore or obstacle == thing or thing.is_ancestor_of(obstacle):
			continue
		var other := Bounds.of(obstacle)
		if Rect2(other.position.x, other.position.z, other.size.x, other.size.z).grow(grid.agent_radius * 0.5).has_point(Vector2(stand.x, stand.z)):
			return "There would be nowhere to stand to use it"
	return ""


func _update() -> void:
	var why := problem()
	_material.albedo_color = GOOD if why == "" else BAD
	_hint.text = "Click to stand it here  ·  R or right click to turn it  ·  Esc to cancel" if why == "" else why


## The point on the floor under a screen position, or null if there is none.
func _floor_under(screen_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
