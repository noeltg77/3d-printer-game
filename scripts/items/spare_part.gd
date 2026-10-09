class_name SparePart
extends Node3D
## The spare parts or upgrade kits of one kind, kept on the shelving until a
## printer needs one. Each kind has its own model (`model` in its data row).
## Like a spool carries its grams, it carries how many are left.

## Id from data/parts.json or data/upgrades.json.
var part: StringName
var count := 1


static func create(p_part: StringName, p_count := 1) -> SparePart:
	var box := SparePart.new()
	box.part = p_part
	box.count = p_count
	box.name = "Spare_%s" % p_part
	box.add_child((load(GameData.part_model(Game.data.kit(p_part))) as PackedScene).instantiate())
	return box


## "3 x Brass nozzle 0.4mm"
func describe() -> String:
	return "%d x %s" % [count, Game.data.kit(part)["name"]]


func save() -> Dictionary:
	return {"part": part, "count": count}


## Null if the part is no longer in the game.
static func restored(data: Dictionary) -> SparePart:
	if Game.data.kit(data["part"]).is_empty():
		return null
	return SparePart.create(StringName(data["part"]), int(data["count"]))
