@tool
extends EditorScenePostImport
## Default post-import script for every .glb (set in project.godot importer_defaults).
## Swaps the generator's placeholder "palette_flat" material for the shared one,
## so all assets draw with a single material and palette texture.

const PALETTE_MATERIAL_NAME := "palette_flat"
const PALETTE_MATERIAL := preload("res://assets/materials/palette_flat.tres")


func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene


func _apply(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material != null and material.resource_name == PALETTE_MATERIAL_NAME:
				node.mesh.surface_set_material(i, PALETTE_MATERIAL)
	for child in node.get_children():
		_apply(child)
