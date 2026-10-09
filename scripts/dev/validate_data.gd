extends SceneTree
## Loads every data table and reports problems, including products with no model to print.
## Run: godot --headless --path . --script res://scripts/dev/validate_data.gd

## Where PrintedItem looks for a model. Repeated here because that script needs the Game
## autoload, which is not there when a script is run on its own.
const MODEL_PATH := "res://assets/models/prints/%s.glb"


func _init() -> void:
	var data := GameData.load_all()
	print("printers: %d, filaments: %d, products: %d, presets: %d, failures: %d" % [
		data.printers.size(), data.filaments.size(), data.products.size(), data.presets.size(), data.failures.size()])
	var errors := data.errors.duplicate()
	for product: String in data.products:
		if not ResourceLoader.exists(MODEL_PATH % product):
			errors.append("product %s: no model at %s" % [product, MODEL_PATH % product])
	for error in errors:
		printerr("DATA ERROR: ", error)
	if errors.is_empty():
		print("Data OK")
	quit(0 if errors.is_empty() else 1)
