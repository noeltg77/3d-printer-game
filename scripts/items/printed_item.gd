class_name PrintedItem
extends Node3D
## Something that came off a printer, tinted to match the filament it was printed in.

const MODEL_PATH := "res://assets/models/prints/%s.glb"

var product: StringName
var colour: StringName
## Finished height in metres, for the printer's build-up animation.
var height := 0.0


static func create(p_product: StringName, p_colour: StringName) -> PrintedItem:
	var item := PrintedItem.new()
	item.product = p_product
	item.colour = p_colour
	item.name = "Print_%s" % p_product
	var model: Node3D = (load(MODEL_PATH % p_product) as PackedScene).instantiate()
	item.add_child(model)
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		mesh.set_instance_shader_parameter(&"tint", Palette.colour(p_colour))
		item.height = maxf(item.height, mesh.get_aabb().end.y)
	return item
