class_name Interactable
extends Node3D
## Base for anything the player can click. Subclasses override get_actions() to
## offer tasks. Builds its own click collider from the meshes it finds.

const HIGHLIGHT := preload("res://assets/materials/highlight.tres")
const RAY_LENGTH := 200.0
## How many overlapping objects to look through under the cursor.
const MAX_STACKED := 6

@export var display_name := ""
## Where the character stands to use this, relative to this node. Height is ignored.
@export var stand_offset := Vector3(0.0, 0.0, 0.7)
## Node whose meshes are clicked and highlighted. This node if empty.
@export var visual_path: NodePath

## Size of the click box, used to choose between overlapping objects.
var click_volume := 0.0

var _body: StaticBody3D = null
## The meshes lit up by the highlight, so each is put back even if it has
## since been carried off somewhere else.
var _highlit: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group(&"interactable")
	# Deferred so the scene is fully placed before measuring.
	_build_collider.call_deferred()


## Tasks to offer in the menu right now, for `agent`.
func get_actions(_agent: Agent) -> Array[Action]:
	return []


## The icon in assets/ui/icons shown on this object's action card.
func card_icon() -> String:
	return "box"


func get_stand_point() -> Vector3:
	var point := global_transform * stand_offset
	return Vector3(point.x, 0.0, point.z)


func set_highlighted(on: bool) -> void:
	for mesh in _highlit:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_highlit.clear()
	if not on:
		return
	_highlit.assign(_visual().find_children("*", "MeshInstance3D", true, false))
	if _visual() is MeshInstance3D:
		_highlit.append(_visual())
	for mesh in _highlit:
		mesh.material_overlay = HIGHLIGHT


## The thing under a point on the screen as `camera` sees it, or null.
static func under(camera: Camera3D, screen_position: Vector2) -> Interactable:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Of everything under the cursor, pick the smallest: a printer on a bench
	# sits inside the bench's box and would otherwise never be clickable.
	var best: Interactable = null
	var excluded: Array[RID] = []
	for attempt in MAX_STACKED:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		excluded.append(hit["rid"])
		var found: Interactable = hit["collider"].get_meta(&"interactable", null)
		if found != null and (best == null or found.click_volume < best.click_volume):
			best = found
	return best


## Stops this being clickable, e.g. while it is being carried.
func remove_collider() -> void:
	if _body != null:
		_body.queue_free()
		_body = null


## Moves `item` under `parent`, sitting exactly on it.
static func attach(item: Node3D, parent: Node3D) -> void:
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	parent.add_child(item)
	item.transform = Transform3D.IDENTITY


func _visual() -> Node3D:
	return self if visual_path.is_empty() else get_node(visual_path)


func _build_collider() -> void:
	var box := Bounds.of(_visual())
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.1)
	click_volume = shape.size.x * shape.size.y * shape.size.z
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body = StaticBody3D.new()
	_body.add_child(collision)
	_body.set_meta(&"interactable", self)
	# Placed in world space so this node's own rotation doesn't skew the box.
	_body.top_level = true
	add_child(_body)
	_body.global_transform = Transform3D(Basis.IDENTITY, box.get_center())
