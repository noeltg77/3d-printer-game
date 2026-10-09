class_name FailedPrint
extends Node3D
## What a ruined print leaves on the plate: the part-built item and, depending
## on the failure's `visual`, a mess around it. Carried to the bin as one thing.

const MESS_PATH := "res://assets/models/fails/%s.glb"
## How far a print that came loose is knocked over and shoved aside.
const TOPPLE := Vector3(0.0, 0.0, deg_to_rad(82.0))
const SHOVE := Vector3(0.05, 0.02, 0.03)
## How far the nest of a spaghetti failure sinks over the part beneath it.
const NEST_SINK := 0.015

## Row from data/failures.json.
var failure: Dictionary
var product: StringName
## The part-built print inside the mess.
var item: PrintedItem


## Wraps `item`, which is on the plate squashed to the height it reached.
static func create(item: PrintedItem, p_failure: Dictionary) -> FailedPrint:
	var scrap := FailedPrint.new()
	scrap.failure = p_failure
	scrap.product = item.product
	scrap.item = item
	scrap.name = "FailedPrint"
	var built := item.height * item.scale.y
	Interactable.attach(item, scrap)
	item.scale.y = built / item.height
	match p_failure.get("visual", ""):
		"noodles":
			item.visible = false
			scrap._add_mess("noodles", item.colour, 0.0)
		"spaghetti":
			scrap._add_mess("spaghetti", item.colour, maxf(built - NEST_SINK, 0.0))
		"toppled":
			item.rotation = TOPPLE
			item.position = SHOVE
	return scrap


func _add_mess(model: String, colour: StringName, height: float) -> void:
	var mess: Node3D = (load(MESS_PATH % model) as PackedScene).instantiate()
	add_child(mess)
	mess.position.y = height
	for mesh: MeshInstance3D in mess.find_children("*", "MeshInstance3D", true, false):
		mesh.set_instance_shader_parameter(&"tint", Palette.colour(colour))
