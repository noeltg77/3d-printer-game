@tool
extends EditorScenePostImport
## Default post-import script for every .glb (set in project.godot importer_defaults).
## Swaps the generators' placeholder materials for the shared ones by name, so
## all assets draw with the same few materials.

const SHARED_MATERIALS := {
	"palette_flat": preload("res://assets/materials/palette_flat.tres"),
	"tint_flat": preload("res://assets/materials/tint_flat.tres"),
}


func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene


func _apply(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material != null and SHARED_MATERIALS.has(material.resource_name):
				node.mesh.surface_set_material(i, SHARED_MATERIALS[material.resource_name])
	for child in node.get_children():
		_apply(child)
