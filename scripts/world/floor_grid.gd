class_name FloorGrid
extends Node3D
## Walkable floor as a grid. Anything in the "obstacle" group blocks the cells
## under it (plus the character's radius), and paths are found with A* then
## straightened. No baking step: call rebuild() after moving furniture.

## Walkable area on the floor: x and z of one corner, then width and depth.
@export var area := Rect2(-2.75, -2.25, 5.5, 4.5)
@export var cell_size := 0.2
## Clearance kept around obstacles.
@export var agent_radius := 0.25

var _grid := AStarGrid2D.new()


func _ready() -> void:
	add_to_group(&"floor_grid")
	# Deferred so every obstacle in the scene is in place first.
	rebuild.call_deferred()


func rebuild() -> void:
	_grid.region = Rect2i(Vector2i.ZERO, Vector2i((area.size / cell_size).ceil()))
	_grid.cell_size = Vector2.ONE * cell_size
	_grid.offset = area.position + Vector2.ONE * cell_size / 2.0
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for obstacle in get_tree().get_nodes_in_group(&"obstacle"):
		var box := Bounds.of(obstacle)
		var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(agent_radius)
		var first := _cell_at(footprint.position)
		var last := _cell_at(footprint.end)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if footprint.has_point(_grid.get_point_position(cell)):
					_grid.set_point_solid(cell)


## Points to walk through from `from` to `to`, ending at the nearest reachable
## spot if `to` itself is blocked.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := _nearest_free_cell(from)
	var end := _nearest_free_cell(to)
	var cells := _grid.get_id_path(start, end)
	var points: PackedVector2Array = []
	for cell in cells:
		points.append(_grid.get_point_position(cell))
	if points.is_empty():
		return []
	# Finish on the exact spot asked for when it is walkable.
	if _cell_at(Vector2(to.x, to.z)) == end:
		points[-1] = Vector2(to.x, to.z)
	var path: PackedVector3Array = []
	for point in _straighten(points):
		path.append(Vector3(point.x, 0.0, point.y))
	return path


func _straighten(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = [points[0]]
	var index := 0
	while index < points.size() - 1:
		# Skip ahead to the furthest point that can be walked to in a straight line.
		var next := points.size() - 1
		while next > index + 1 and not _is_clear(points[index], points[next]):
			next -= 1
		result.append(points[next])
		index = next
	return result


func _is_clear(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / (cell_size / 2.0))
	for step in steps + 1:
		if _grid.is_point_solid(_cell_at(from.lerp(to, float(step) / maxi(steps, 1)))):
			return false
	return true


func _cell_at(point: Vector2) -> Vector2i:
	var cell := Vector2i(((point - area.position) / cell_size).floor())
	return cell.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)


func _nearest_free_cell(point: Vector3) -> Vector2i:
	var target := Vector2(point.x, point.z)
	var centre := _cell_at(target)
	if not _grid.is_point_solid(centre):
		return centre
	var best := centre
	var best_distance := INF
	for ring in range(1, 12):
		for x in range(centre.x - ring, centre.x + ring + 1):
			for y in range(centre.y - ring, centre.y + ring + 1):
				var cell := Vector2i(x, y)
				if not _grid.is_in_boundsv(cell) or _grid.is_point_solid(cell):
					continue
				var distance := _grid.get_point_position(cell).distance_to(target)
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best_distance < INF:
			break
	return best
