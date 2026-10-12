class_name ColourTaste
extends RefCounted
## Which colours buyers like a design best in, and what selling it in them
## does for demand (the `colour_taste` settings).
##
## Every design has a few favourite colours, out of those its filaments come
## in: the ones its category is known for (red, green and white at Christmas)
## and then whichever the design itself happens to suit, so no one spool is
## right for everything. A row's own `popular_colours` overrides that. A
## design whose filaments come in too few colours to choose between has none.
##
## A listing shows what has been going out, so its demand follows the last
## few sent: more when they were in a favourite colour, a little less when not.

var _settings: Dictionary
var _filaments: Dictionary
## Product id -> its favourite colours, worked out once.
var _found: Dictionary[StringName, Array] = {}


func _init(settings: Dictionary, filaments: Dictionary) -> void:
	_settings = settings
	_filaments = filaments


## The colours buyers like a design best in, best known first. Empty if it
## makes no difference what colour it is.
func favourites(row: Dictionary) -> Array[StringName]:
	var id := StringName(row["id"])
	if not _found.has(id):
		_found[id] = _work_out(row)
	var colours: Array[StringName] = []
	colours.assign(_found[id])
	return colours


## True if a print in these colours is one buyers like: any of them a
## favourite. Always true for a design with no favourites.
func likes(row: Dictionary, colours: Array) -> bool:
	var wanted := favourites(row)
	return wanted.is_empty() or colours.any(func(colour: Variant) -> bool: return wanted.has(StringName(colour)))


## How a listing's demand scales, from whether each of the last few sent was
## in a favourite colour (true) or not. 1.0 before anything has been sent.
func demand(recent: Array) -> float:
	if recent.is_empty():
		return 1.0
	var liked := recent.count(true)
	return lerpf(float(_settings["other_demand"]), float(_settings["liked_demand"]), float(liked) / recent.size())


## How many of the last sent a listing's demand looks back over.
func window() -> int:
	return int(_settings["window"])


func _work_out(row: Dictionary) -> Array:
	# The colours of the filaments the design names. Others of the same
	# family will print it too, but buyers picture it in the plain kind.
	var choices: Array[StringName] = []
	for allowed: String in row["allowed_filaments"]:
		for filament: Dictionary in _filaments.values():
			if filament["id"] == allowed or (not _filaments.has(allowed) and filament["family"] == allowed):
				for colour: String in filament["colours"]:
					if not choices.has(StringName(colour)):
						choices.append(StringName(colour))
	var picked: Array[StringName] = []
	for colour: String in row.get("popular_colours", []):
		picked.append(StringName(colour))
	if not picked.is_empty():
		return picked
	var count := mini(int(_settings["favourites"]), choices.size() / 2)
	if count <= 0:
		return picked
	# A steady shuffle that is the design's own, so the same design always
	# suits the same colours and two designs seldom agree.
	var order := func(a: StringName, b: StringName) -> bool:
		return ("%s:%s" % [row["id"], a]).hash() < ("%s:%s" % [row["id"], b]).hash()
	var themed: Array[StringName] = []
	for colour: String in _settings["categories"].get(row["category"], []):
		if choices.has(StringName(colour)):
			themed.append(StringName(colour))
	themed.sort_custom(order)
	choices.sort_custom(order)
	for colour in themed + choices:
		if picked.size() < count and not picked.has(colour):
			picked.append(colour)
	return picked
