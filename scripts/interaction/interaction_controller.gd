extends Node
## Turns mouse input into tasks for the character: hover highlights an object,
## left click opens its action menu, and choosing an action queues it.
## A left click on bare floor walks there instead.

const RAY_LENGTH := 200.0
const HEADER_ID := 100000
## How many overlapping objects to look through under the cursor.
const MAX_STACKED := 6

@export var agent_path: NodePath
@export var hud_path: NodePath

var _hovered: Interactable = null
var _menu := PopupMenu.new()
## Menu item id -> the Action it runs.
var _menu_actions: Array[Action] = []

@onready var _agent: Agent = get_node(agent_path)
@onready var _hud: Hud = get_node(hud_path)


func _ready() -> void:
	_menu.id_pressed.connect(_on_action_chosen)
	_style(_menu)
	add_child(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_pick(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _pick(event.position)
		if target != null and target.has_method(&"wants_panel") and target.call(&"wants_panel"):
			target.call(&"open_panel")
		elif target != null:
			_open_menu(target, event.position)
		else:
			_walk_to_click(event.position)


func _pick(screen_position: Vector2) -> Interactable:
	var camera := get_viewport().get_camera_3d()
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


func _set_hovered(target: Interactable) -> void:
	# The hovered object may have been removed since (a delivery box unpacked).
	if not is_instance_valid(_hovered):
		_hovered = null
	if target == _hovered:
		return
	if _hovered != null:
		_hovered.set_highlighted(false)
	_hovered = target
	if _hovered != null:
		_hovered.set_highlighted(true)
	_hud.set_hover(_hovered.display_name if _hovered != null else "")


func _walk_to_click(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var floor_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if floor_point != null:
		_agent.stroll_to(floor_point)


func _open_menu(target: Interactable, screen_position: Vector2) -> void:
	_menu.clear(true)
	_menu_actions.clear()
	_menu.add_item(target.display_name, HEADER_ID)
	_menu.set_item_disabled(0, true)
	_menu.add_separator()
	_add_actions(_menu, target.get_actions(_agent))
	_menu.popup(Rect2i(Vector2i(screen_position), Vector2i.ZERO))


func _add_actions(menu: PopupMenu, actions: Array[Action]) -> void:
	for action in actions:
		if not action.children.is_empty():
			var submenu := PopupMenu.new()
			_style(submenu)
			submenu.id_pressed.connect(_on_action_chosen)
			menu.add_submenu_node_item(action.label, submenu)
			_add_actions(submenu, action.children)
		else:
			var id := _menu_actions.size()
			_menu_actions.append(action)
			menu.add_item(action.label, id)
			menu.set_item_disabled(menu.get_item_index(id), not action.enabled)


## Gives a menu the shared look. The window must be transparent for the
## rounded corners of the panel to show.
func _style(menu: PopupMenu) -> void:
	menu.theme = Ui.theme()
	menu.transparent_bg = true


func _on_action_chosen(id: int) -> void:
	var action := _menu_actions[id]
	if action.immediate:
		action.run.call(_agent)
	else:
		_agent.enqueue(action)
