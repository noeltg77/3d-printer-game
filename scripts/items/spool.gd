class_name Spool
extends Node3D
## A spool of filament as a physical item that can sit in a rack slot, be
## carried, or be mounted on a printer. Resin is one too: a filament whose
## `container` is "bottle" comes in a bottle, and is otherwise handled the same.
## So is a big reel (`bulk`): five times the filament, in one slot of the rack.

const MODEL_PATH := "res://assets/models/filament/spool_%s.glb"
const BOTTLE_PATH := "res://assets/models/filament/bottle_%s.glb"
const REEL_PATH := "res://assets/models/filament/reel_%s.glb"
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
## True for a big reel, which is too wide for a multicolour unit or a small dryer.
var bulk := false
## True if it was wound in the recycler from scrap: it prints a little less surely.
var recycled := false


static func create(p_colour: StringName, p_grams := 1000.0, p_material: StringName = &"pla", p_bulk := false) -> Spool:
	var spool := Spool.new()
	spool.colour = p_colour
	spool.material = p_material
	spool.grams = p_grams
	spool.bulk = p_bulk
	spool.name = "Spool_%s" % p_colour
	var bottled: bool = Game.data.filaments[p_material].get("container", "spool") == "bottle"
	spool.add_child((load((BOTTLE_PATH if bottled else (REEL_PATH if p_bulk else MODEL_PATH)) % p_colour) as PackedScene).instantiate())
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


## "5 kg reel" for a big reel, and nothing for a spool.
func size_label() -> String:
	return "%s reel" % FilamentRules.weight_label(float(Game.data.filaments[material]["bulk_grams"])) if bulk else ""


## "Red PLA, 880 g" or "Red PLA, 5 kg reel, 4880 g, recycled, wet"
func describe() -> String:
	var words: PackedStringArray = [title()]
	if bulk:
		words.append(size_label())
	words.append("%d g" % roundi(grams))
	if recycled:
		words.append("recycled")
	var state := Moisture.label(moisture, Game.data.settings["moisture"])
	if state != "dry":
		words.append(state)
	return ", ".join(words)


func save() -> Dictionary:
	return {"colour": colour, "material": material, "grams": grams, "moisture": moisture, "bulk": bulk, "recycled": recycled}


static func restored(data: Dictionary) -> Spool:
	var saved_material := StringName(data["material"]) if Game.data.filaments.has(data["material"]) else &"pla"
	var big := bool(data.get("bulk", false)) and FilamentRules.has_bulk(Game.data.filaments[saved_material])
	var spool := Spool.create(StringName(data["colour"]), float(data["grams"]), saved_material, big)
	spool.moisture = clampf(float(data.get("moisture", 0.0)), 0.0, 1.0)
	spool.recycled = bool(data.get("recycled", false))
	return spool
