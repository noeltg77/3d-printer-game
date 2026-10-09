extends SceneTree
## Loads every data table and reports problems, including products with no model to print.
## Run: godot --headless --path . --script res://scripts/dev/validate_data.gd


func _init() -> void:
	var data := GameData.load_all()
	print("printers: %d, filaments: %d, products: %d" % [data.printers.size(), data.filaments.size(), data.products.size()])
	var errors := data.errors.duplicate()
	for product: String in data.products:
		if not ResourceLoader.exists(PrintedItem.MODEL_PATH % product):
			errors.append("product %s: no model at %s" % [product, PrintedItem.MODEL_PATH % product])
	for error in errors:
		printerr("DATA ERROR: ", error)
	if errors.is_empty():
		print("Data OK")
	quit(0 if errors.is_empty() else 1)
