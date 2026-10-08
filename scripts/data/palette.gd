class_name Palette
extends RefCounted
## The shared colour palette (data/palette.json) for code that needs a colour
## by name, e.g. tinting a printed item to match its filament.

const SOURCE := "res://data/palette.json"
const DISPLAY_NAMES := {&"ink": "Black", &"sky": "Sky blue"}

static var _colours: Dictionary[StringName, Color] = {}


static func colour(colour_name: StringName) -> Color:
	if _colours.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		for entry: Dictionary in data["colours"]:
			_colours[StringName(entry["name"])] = Color.html(entry["hex"])
	return _colours.get(colour_name, Color.MAGENTA)


## Name to show the player, e.g. "ink" is sold as "Black".
static func display_name(colour_name: StringName) -> String:
	return DISPLAY_NAMES.get(colour_name, String(colour_name).capitalize())
