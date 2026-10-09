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


static func create(p_colour: StringName, p_grams := 1000.0) -> Spool:
	var spool := Spool.new()
	spool.colour = p_colour
	spool.grams = p_grams
	spool.name = "Spool_%s" % p_colour
	spool.add_child((load(MODEL_PATH % p_colour) as PackedScene).instantiate())
	return spool


func is_empty() -> bool:
	return grams < EMPTY_GRAMS


## "Red PLA, 880 g"
func describe() -> String:
	return "%s %s, %d g" % [Palette.display_name(colour), String(material).to_upper(), roundi(grams)]


func save() -> Dictionary:
	return {"colour": colour, "material": material, "grams": grams}


static func restored(data: Dictionary) -> Spool:
	var spool := Spool.create(StringName(data["colour"]), float(data["grams"]))
	spool.material = StringName(data["material"])
	return spool
