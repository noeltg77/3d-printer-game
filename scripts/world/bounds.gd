class_name Bounds
extends RefCounted
## Helpers for measuring models.


## World-space box around every mesh under `node`. Zero-sized if there are none.
static func of(node: Node, aabb := AABB()) -> AABB:
	if node is MeshInstance3D:
		var mesh_aabb: AABB = node.global_transform * node.get_aabb()
		aabb = mesh_aabb if aabb.size == Vector3.ZERO else aabb.merge(mesh_aabb)
	for child in node.get_children():
		aabb = of(child, aabb)
	return aabb
