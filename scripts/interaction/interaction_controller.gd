extends Node
## Turns mouse input into tasks for the character: hover highlights an object,
## and a left click on it pops out its ActionCard, where choosing an action
## queues it. An object with only one thing to do just does it, with no card.
## A left click on bare floor walks there instead.

const RAY_LENGTH := 200.0
## How many overlapping objects to look through under the cursor.
const MAX_STACKED := 6

@export var agent_path: NodePath
@export var hud_path: NodePath

var _hovered: Interactable = null
var _card := ActionCard.new()

@onready var _agent: Agent = get_node(agent_path)
@onready var _hud: Hud = get_node(hud_path)


func _ready() -> void:
	_card.chosen.connect(_run)
	add_child(_card)
	Game.changed.connect(_show_hover)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_pick(event.position))
	elif event is InputEventMouseButton and event.pressed:
		# Any click off the card puts it away; a click on the floor does no more than that.
		var putting_away := _card.is_open()
		_card.close()
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var target := _pick(event.position)
		if target != null and target.has_method(&"wants_panel") and target.call(&"wants_panel"):
			target.call(&"open_panel")
		elif target != null:
			_click(target, event.position)
		elif not putting_away:
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
	_show_hover()


## Names the object under the mouse, and says what a click will do when
## there is only the one thing to do with it.
func _show_hover() -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_hovered) or _card.is_open():
		_hud.set_hover("")
		return
	var only := ActionCard.sole_action(_hovered.get_actions(_agent))
	_hud.set_hover(_hovered.display_name, "" if only == null else "Click: %s" % only.label)


func _walk_to_click(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var floor_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if floor_point != null:
		_agent.stroll_to(floor_point)


## A click on an object: straight to work if there is only one thing to do
## with it, otherwise its card of choices.
func _click(target: Interactable, screen_position: Vector2) -> void:
	var only := ActionCard.sole_action(target.get_actions(_agent))
	if only != null:
		_run(only)
		_card.flash(only.get_task_name(), screen_position)
		return
	_card.open(target, _agent, screen_position)
	_show_hover()


func _run(action: Action) -> void:
	if action.immediate:
		action.run.call(_agent)
	else:
		_agent.enqueue(action)
