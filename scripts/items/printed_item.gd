class_name PrintedItem
extends Node3D
## Something that came off a printer, tinted to match the filament it was printed in.
##
## A design made for several colours has a model in several meshes: the main one,
## and one named `colour_2`, `colour_3` and so on for each further colour. Each
## takes the colour of the spool that printed it. Printed in fewer colours than
## the design has, the spare parts take the last colour and the item is "plain".

const MODEL_PATH := "res://assets/models/prints/%s.glb"
## Start of the name of a mesh printed in a colour after the first.
const PART_PREFIX := "colour_"

var product: StringName
## Palette colour of each part, in the design's order. Never empty.
var colours: Array[StringName] = [&"white"]
## The main colour.
var colour: StringName:
	get:
		return colours[0]
## Filament id it was printed in.
var material: StringName = &"pla"
## Preset it was printed at, and the strength (1 to 5) that gave it.
var preset: StringName = &"standard"
var durability := 3
## Finish, 1 to 5: the preset's quality, less anything that went wrong.
var quality := 3
## Id of the failure that spoiled it, or empty if it came out as intended.
var flaw: StringName = &""
## Finished height in metres, for the printer's build-up animation.
var height := 0.0
## How much of the plate it covers, in metres: across and front to back.
var footprint := Vector2.ZERO


static func create(p_product: StringName, p_colours: Array[StringName], p_preset: StringName = &"standard",
		p_material: StringName = &"pla") -> PrintedItem:
	var item := PrintedItem.new()
	item.material = p_material
	item.product = p_product
	item.colours = p_colours.duplicate()
	item.preset = p_preset
	item.durability = int(Game.data.presets[p_preset]["durability"])
	item.quality = int(Game.data.presets[p_preset]["quality"])
	item.name = "Print_%s" % p_product
	var model: Node3D = (load(MODEL_PATH % p_product) as PackedScene).instantiate()
	item.add_child(model)
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		mesh.set_instance_shader_parameter(&"tint", Palette.colour(item.colours[mini(part_of(mesh.name), item.colours.size() - 1)]))
		var box := mesh.transform * mesh.get_aabb()
		item.height = maxf(item.height, box.end.y)
		item.footprint = item.footprint.max(Vector2(maxf(-box.position.x, box.end.x), maxf(-box.position.z, box.end.z)) * 2.0)
	return item


## Which of a design's colours a mesh is printed in, counting from 0, by its name.
static func part_of(mesh_name: String) -> int:
	if not mesh_name.begins_with(PART_PREFIX):
		return 0
	return maxi(mesh_name.trim_prefix(PART_PREFIX).get_slice("_", 0).to_int() - 1, 0)


## Marks the item as spoiled by a failure that left it usable but worse.
func spoil(failure: Dictionary) -> void:
	flaw = StringName(failure["id"])
	quality = maxi(quality - int(failure.get("quality_loss", 1)), 1)


func is_flawed() -> bool:
	return flaw != &""


## True if it was printed in fewer colours than its design is made for.
func is_plain() -> bool:
	return colours.size() < Multicolour.colours_of(Game.data.products[product])


## "Phone Stand", "Phone Stand (corners warped)" or "Desk Nameplate (one colour)"
func describe() -> String:
	var notes: PackedStringArray = []
	if is_plain():
		notes.append(Game.data.toggles["multicolour"]["off_name"].to_lower())
	if is_flawed():
		notes.append(String(Game.data.failures[flaw]["name"]).to_lower())
	var title := Game.product_name(product)
	return title if notes.is_empty() else "%s (%s)" % [title, ", ".join(notes)]


func save() -> Dictionary:
	return {"product": product, "colours": colours, "material": material, "preset": preset, "durability": durability,
		"quality": quality, "flaw": flaw}


## Null if the design or preset is no longer in the game.
static func restored(data: Dictionary) -> PrintedItem:
	if not Game.data.products.has(data["product"]) or not Game.data.presets.has(data["preset"]):
		return null
	var saved_material := String(data.get("material", "pla"))
	# Saves from before multicolour hold the one colour.
	var saved_colours: Array[StringName] = []
	for saved: String in data.get("colours", [data.get("colour", "white")]):
		saved_colours.append(StringName(saved))
	var item := PrintedItem.create(StringName(data["product"]), saved_colours, StringName(data["preset"]),
		StringName(saved_material) if Game.data.filaments.has(saved_material) else &"pla")
	item.durability = int(data["durability"])
	item.quality = int(data["quality"])
	if Game.data.failures.has(data["flaw"]):
		item.flaw = StringName(data["flaw"])
	return item
