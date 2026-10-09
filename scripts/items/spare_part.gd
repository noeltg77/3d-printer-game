class_name SparePart
extends Node3D
## A box of spare parts of one kind, kept on the shelving until a printer needs
## one. Like a spool carries its grams, the box carries how many are left.

const MODEL := preload("res://assets/models/props/parts_box.glb")

## Part id from data/parts.json.
var part: StringName
var count := 1


static func create(p_part: StringName, p_count := 1) -> SparePart:
	var box := SparePart.new()
	box.part = p_part
	box.count = p_count
	box.name = "Spare_%s" % p_part
	box.add_child(MODEL.instantiate())
	return box


## "3 x Brass nozzle 0.4mm"
func describe() -> String:
	return "%d x %s" % [count, Game.data.parts[part]["name"]]


func save() -> Dictionary:
	return {"part": part, "count": count}


## Null if the part is no longer in the game.
static func restored(data: Dictionary) -> SparePart:
	if not Game.data.parts.has(data["part"]):
		return null
	return SparePart.create(StringName(data["part"]), int(data["count"]))
