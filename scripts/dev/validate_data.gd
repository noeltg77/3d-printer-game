extends SceneTree
## Loads every data table and reports problems.
## Run: godot --headless --path . --script res://scripts/dev/validate_data.gd


func _init() -> void:
	var data := GameData.load_all()
	print("printers: %d, filaments: %d, products: %d" % [data.printers.size(), data.filaments.size(), data.products.size()])
	for error in data.errors:
		printerr("DATA ERROR: ", error)
	if data.errors.is_empty():
		print("Data OK")
	quit(0 if data.errors.is_empty() else 1)
