class_name Machinery
extends Node3D
## Keeps the premises' machines: the filament recycler and the wash and cure
## stations, which are fittings bought and stood about the room like shelving
## (data/fittings.json, kinds "recycler" and "wash"). Each is its own
## FittingUnit and does its own work; this node is the host they are added to,
## counted by and saved through.

var _units: Array[FittingUnit] = []
## What was in a machine when the business moved, fitting id -> its state,
## kept until that machine is stood up again.
var _stowed: Dictionary = {}


func _ready() -> void:
	add_to_group(&"machinery")


## Stands a bought machine in the room.
func add_unit(fitting: StringName, at: Transform3D) -> FittingUnit:
	var unit := FittingUnit.create(fitting, self)
	get_parent().add_child(unit)
	unit.global_transform = at
	_units.append(unit)
	if _stowed.has(String(fitting)):
		unit.call(&"restore_state", _stowed[String(fitting)])
		_stowed.erase(String(fitting))
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## How many machines of a kind stand in the room.
func count_of(kind: String) -> int:
	return _units.filter(func(unit: FittingUnit) -> bool: return unit.spec()["kind"] == kind).size()


## True while a machine has anything in it: it can't be sold or scrapped until it is empty.
func unit_in_use(unit: FittingUnit) -> bool:
	return unit.call(&"busy")


## Lets go of a machine, for it to be sold or scrapped.
func remove_unit(unit: FittingUnit) -> void:
	_units.erase(unit)
	unit.call(&"retire")
	Game.changed.emit()


func save() -> Dictionary:
	return {"units": _units.map(func(unit: FittingUnit) -> Dictionary: return unit.save()), "stowed": _stowed}


func restore(data: Dictionary) -> void:
	_stowed = data.get("stowed", {})
	for entry: Dictionary in data.get("units", []):
		if Game.data.fittings.has(entry.get("fitting", "")):
			add_unit(StringName(entry["fitting"]), FittingUnit.saved_transform(entry)).call(&"restore_state", entry.get("state", {}))
