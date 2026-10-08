class_name Spool
extends Node3D
## A spool of filament as a physical item that can sit in a rack slot, be
## carried, or be mounted on a printer.

const MODEL_PATH := "res://assets/models/filament/spool_%s.glb"

## Palette colour name of the filament.
var colour: StringName


static func create(p_colour: StringName) -> Spool:
	var spool := Spool.new()
	spool.colour = p_colour
	spool.name = "Spool_%s" % p_colour
	spool.add_child((load(MODEL_PATH % p_colour) as PackedScene).instantiate())
	return spool
