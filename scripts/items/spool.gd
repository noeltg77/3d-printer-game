class_name Spool
extends Node3D
## A spool of filament as a physical item that can sit in a rack slot, be
## carried, or be mounted on a printer. Resin is one too: a filament whose
## `container` is "bottle" comes in a bottle, and is otherwise handled the same.

const MODEL_PATH := "res://assets/models/filament/spool_%s.glb"
const BOTTLE_PATH := "res://assets/models/filament/bottle_%s.glb"
## Below this a spool counts as empty and gets binned rather than racked.
const EMPTY_GRAMS := 1.0

## Filament id from data/filaments.json.
var material: StringName = &"pla"
## Palette colour name of the filament.
var colour: StringName
var grams := 1000.0
## How damp it is, 0 (dry) to 1 (soaked). Rises in the open air (Moisture).
var moisture := 0.0
## True while it is somewhere moisture can't get at it, such as in a dryer.
var sheltered := false


static func create(p_colour: StringName, p_grams := 1000.0, p_material: StringName = &"pla") -> Spool:
	var spool := Spool.new()
	spool.colour = p_colour
	spool.material = p_material
	spool.grams = p_grams
	spool.name = "Spool_%s" % p_colour
	var bottled: bool = Game.data.filaments[p_material].get("container", "spool") == "bottle"
	spool.add_child((load((BOTTLE_PATH if bottled else MODEL_PATH) % p_colour) as PackedScene).instantiate())
	return spool


func _process(delta: float) -> void:
	if not sheltered:
		moisture = Moisture.after(moisture, delta * GameClock.MINUTES_PER_SECOND, Game.data.filaments[material], Game.data.settings["moisture"])


func is_wet() -> bool:
	return Moisture.is_wet(moisture, Game.data.settings["moisture"])


func is_empty() -> bool:
	return grams < EMPTY_GRAMS


## "Red PLA" or "Pink Silk PLA"
func title() -> String:
	return "%s %s" % [Palette.display_name(colour), Game.data.filaments[material]["name"]]


## "Red PLA, 880 g" or "Red PLA, 880 g, wet"
func describe() -> String:
	var state := Moisture.label(moisture, Game.data.settings["moisture"])
	return "%s, %d g" % [title(), roundi(grams)] + ("" if state == "dry" else ", %s" % state)


func save() -> Dictionary:
	return {"colour": colour, "material": material, "grams": grams, "moisture": moisture}


static func restored(data: Dictionary) -> Spool:
	var saved_material := StringName(data["material"]) if Game.data.filaments.has(data["material"]) else &"pla"
	var spool := Spool.create(StringName(data["colour"]), float(data["grams"]), saved_material)
	spool.moisture = clampf(float(data.get("moisture", 0.0)), 0.0, 1.0)
	return spool
