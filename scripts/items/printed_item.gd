class_name PrintedItem
extends Node3D
## Something that came off a printer, tinted to match the filament it was printed in.

const MODEL_PATH := "res://assets/models/prints/%s.glb"

var product: StringName
var colour: StringName
## Preset it was printed at, and the strength (1 to 5) that gave it.
var preset: StringName = &"standard"
var durability := 3
## Finish, 1 to 5: the preset's quality, less anything that went wrong.
var quality := 3
## Id of the failure that spoiled it, or empty if it came out as intended.
var flaw: StringName = &""
## Finished height in metres, for the printer's build-up animation.
var height := 0.0


static func create(p_product: StringName, p_colour: StringName, p_preset: StringName = &"standard") -> PrintedItem:
	var item := PrintedItem.new()
	item.product = p_product
	item.colour = p_colour
	item.preset = p_preset
	item.durability = int(Game.data.presets[p_preset]["durability"])
	item.quality = int(Game.data.presets[p_preset]["quality"])
	item.name = "Print_%s" % p_product
	var model: Node3D = (load(MODEL_PATH % p_product) as PackedScene).instantiate()
	item.add_child(model)
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		mesh.set_instance_shader_parameter(&"tint", Palette.colour(p_colour))
		item.height = maxf(item.height, mesh.get_aabb().end.y)
	return item


## Marks the item as spoiled by a failure that left it usable but worse.
func spoil(failure: Dictionary) -> void:
	flaw = StringName(failure["id"])
	quality = maxi(quality - int(failure.get("quality_loss", 1)), 1)


func is_flawed() -> bool:
	return flaw != &""


## "Phone Stand" or "Phone Stand (corners warped)"
func describe() -> String:
	var title := Game.product_name(product)
	return "%s (%s)" % [title, String(Game.data.failures[flaw]["name"]).to_lower()] if is_flawed() else title
