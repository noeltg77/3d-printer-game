extends SceneTree
## Loads every data table and reports problems, including products with no model to print.
## Run: godot --headless --path . --script res://scripts/dev/validate_data.gd

## Where PrintedItem looks for a model. Repeated here because that script needs the Game
## autoload, which is not there when a script is run on its own.
const MODEL_PATH := "res://assets/models/prints/%s.glb"
## Start of the name of a mesh printed in a colour after the first (PrintedItem.PART_PREFIX).
const PART_PREFIX := "colour_"


func _init() -> void:
	var data := GameData.load_all()
	print("printers: %d, filaments: %d, products: %d, presets: %d, failures: %d, parts: %d, upgrades: %d, clients: %d" % [
		data.printers.size(), data.filaments.size(), data.products.size(), data.presets.size(), data.failures.size(),
		data.parts.size(), data.upgrades.size(), data.clients.size()])
	var errors := data.errors.duplicate()
	for product: String in data.products:
		if not ResourceLoader.exists(MODEL_PATH % product):
			errors.append("product %s: no model at %s" % [product, MODEL_PATH % product])
			continue
		# A design in several colours needs a mesh for each of them, and no more.
		var wanted := int(data.products[product].get("colour_count", 1))
		if wanted > 1:
			var found := _colours_in(MODEL_PATH % product)
			if found != wanted:
				errors.append("product %s: made for %d colours but its model has %d" % [product, wanted, found])
	for error in errors:
		printerr("DATA ERROR: ", error)
	if errors.is_empty():
		print("Data OK")
	quit(0 if errors.is_empty() else 1)


## How many colours a model is built in: its main mesh, plus every `colour_<n>`
## mesh, which must run from 2 upwards with none missing. -1 if they don't.
func _colours_in(path: String) -> int:
	var model: Node = (load(path) as PackedScene).instantiate()
	var numbers := {1: true}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := String(mesh.name)
		if mesh_name.begins_with(PART_PREFIX):
			numbers[mesh_name.trim_prefix(PART_PREFIX).get_slice("_", 0).to_int()] = true
	model.free()
	for number in range(1, numbers.size() + 1):
		if not numbers.has(number):
			return -1
	return numbers.size()
