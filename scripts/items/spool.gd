class_name Spool
extends Node3D
## A spool of filament as a physical item that can sit in a rack slot, be
## carried, or be mounted on a printer.

const MODEL_PATH := "res://assets/models/filament/spool_%s.glb"
## Below this a spool counts as empty and gets binned rather than racked.
const EMPTY_GRAMS := 1.0

## Filament id from data/filaments.json.
var material: StringName = &"pla"
## Palette colour name of the filament.
var colour: StringName
var grams := 1000.0


static func create(p_colour: StringName, p_grams := 1000.0, p_material: StringName = &"pla") -> Spool:
	var spool := Spool.new()
	spool.colour = p_colour
	spool.material = p_material
	spool.grams = p_grams
	spool.name = "Spool_%s" % p_colour
	spool.add_child((load(MODEL_PATH % p_colour) as PackedScene).instantiate())
	return spool


func is_empty() -> bool:
	return grams < EMPTY_GRAMS


## "Red PLA" or "Pink Silk PLA"
func title() -> String:
	return "%s %s" % [Palette.display_name(colour), Game.data.filaments[material]["name"]]


## "Red PLA, 880 g"
func describe() -> String:
	return "%s, %d g" % [title(), roundi(grams)]


func save() -> Dictionary:
	return {"colour": colour, "material": material, "grams": grams}


static func restored(data: Dictionary) -> Spool:
	var saved_material := StringName(data["material"]) if Game.data.filaments.has(data["material"]) else &"pla"
	return Spool.create(StringName(data["colour"]), float(data["grams"]), saved_material)
