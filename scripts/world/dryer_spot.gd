class_name DryerSpot
extends Node3D
## Where the premises' filament dryer stands. Empty until one is bought and
## unpacked; a better one unpacked later takes the old one's place.

var dryer: FilamentDryer = null


func _ready() -> void:
	add_to_group(&"dryer_spot")


## Id of the dryer here, or empty.
func dryer_id() -> StringName:
	return StringName(dryer.spec["id"]) if dryer != null else &""


## Why a dryer can't be set up here right now, or "" if it can.
func problem() -> String:
	if dryer != null and not dryer.spools().is_empty():
		return "Empty the dryer you have first"
	return ""


## Stands a dryer here, replacing any that was.
func install(dryer_id_to_fit: StringName) -> FilamentDryer:
	if dryer != null:
		dryer.queue_free()
	dryer = FilamentDryer.create(dryer_id_to_fit)
	add_child(dryer)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return dryer


func save() -> Dictionary:
	return dryer.save() if dryer != null else {}


func restore(data: Dictionary) -> void:
	if Game.data.dryers.has(data.get("id", "")):
		install(StringName(data["id"])).restore(data)
