extends SceneTree
## Builds assets/palette/palette.png from data/palette.json.
## Run: godot --headless --path . --script res://scripts/dev/build_palette.gd

const SOURCE := "res://data/palette.json"
const TARGET := "res://assets/palette/palette.png"


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var colours: Array = data["colours"]
	var columns: int = data["columns"]
	var cell: int = data["cell_px"]
	var rows := ceili(float(colours.size()) / columns)

	var image := Image.create(columns * cell, rows * cell, false, Image.FORMAT_RGB8)
	for i in colours.size():
		var rect := Rect2i(i % columns * cell, i / columns * cell, cell, cell)
		image.fill_rect(rect, Color.html(colours[i]["hex"]))

	var err := image.save_png(TARGET)
	if err == OK:
		print("Wrote %s (%d colours, %dx%d)" % [TARGET, colours.size(), image.get_width(), image.get_height()])
	else:
		push_error("Failed to write %s: %s" % [TARGET, error_string(err)])
	quit(0 if err == OK else 1)
