class_name Workbench
extends Interactable
## The workbench: printers stand on it. Orders are packed at the PackingStation.
##
## It owns every printer on the premises and every place one can stand. Those
## are its own `printer_spots` and, once the player buys them, the shelves of
## printer racks (FittingUnit, of kind "bench"): a rack only adds places, on
## its model's `printer_spot_*` markers, and the printers on it are still
## this bench's.

const FITTING_KIND := "bench"

## Where printers go, relative to this bench, in the order they fill. A longer
## bench sets more of them in its scene, and a print farm's also reach onto the
## other benches in the room, which are plain furniture: this one bench owns
## every printer.
@export var printer_spots: Array[Vector3] = [Vector3(-0.42, 0.9, 0.03), Vector3(0.42, 0.9, 0.03)]

## Every place a printer can stand, the bench's own first:
## { holder: the bench or a rack, at: where on it, printer: what stands there or null }.
var _spots: Array[Dictionary] = []
var _units: Array[FittingUnit] = []


func _ready() -> void:
	super()
	add_to_group(&"workbench")
	for at in printer_spots:
		_spots.append({"holder": self, "at": at, "printer": null})


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.info("%d of %d printer spaces used" % [_spots.size() - free_spots(), _spots.size()])]


func free_spots() -> int:
	return _spots.filter(func(spot: Dictionary) -> bool: return spot["printer"] == null).size()


## How many benches and racks there are in all, counting this one.
func unit_count() -> int:
	return 1 + _units.size()


## Stands a bought printer rack in the room and takes on its shelves.
func add_unit(fitting: StringName, at: Transform3D) -> FittingUnit:
	var unit := FittingUnit.create(fitting, self)
	get_parent().add_child(unit)
	unit.global_transform = at
	_units.append(unit)
	var markers := unit.find_children("printer_spot_*", "Node3D", true, false)
	markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	for marker: Node3D in markers:
		_spots.append({"holder": unit, "at": unit.global_transform.affine_inverse() * marker.global_position, "printer": null})
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## A rack has been stood somewhere else: its printers go with it.
func unit_moved(unit: FittingUnit) -> void:
	for spot in _spots:
		if spot["holder"] == unit and spot["printer"] != null:
			_seat(spot)


## Where the next printer would go: this bench or a rack, to walk to.
func spot() -> Interactable:
	for candidate in _spots:
		if candidate["printer"] == null:
			return candidate["holder"]
	return self


## Sets up a new printer on the next free spot. Null if there is none.
func install_printer(printer_id: StringName, at_spot := -1) -> PrinterStation:
	var index := at_spot if at_spot >= 0 and at_spot < _spots.size() and _spots[at_spot]["printer"] == null else -1
	if index < 0:
		for candidate in _spots.size():
			if _spots[candidate]["printer"] == null:
				index = candidate
				break
	if index < 0:
		return null
	var station := PrinterStation.create(printer_id)
	# A sibling rather than a child, so the bench and printer highlight separately.
	get_parent().add_child(station)
	_spots[index]["printer"] = station
	_seat(_spots[index])
	Game.changed.emit()
	return station


## Takes a printer off its spot for good, leaving the spot free. The caller frees the printer.
func remove_printer(station: PrinterStation) -> void:
	for spot in _spots:
		if spot["printer"] == station:
			spot["printer"] = null
	Game.changed.emit()


func _seat(spot: Dictionary) -> void:
	var holder: Node3D = spot["holder"]
	(spot["printer"] as PrinterStation).global_transform = holder.global_transform * Transform3D(Basis.IDENTITY, spot["at"])


func save() -> Dictionary:
	var printers: Array[Dictionary] = []
	for index in _spots.size():
		if _spots[index]["printer"] != null:
			var entry: Dictionary = (_spots[index]["printer"] as PrinterStation).save()
			entry["spot"] = index
			printers.append(entry)
	return {"printers": printers, "units": _units.map(func(unit: FittingUnit) -> Dictionary: return unit.save())}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data.get("units", []):
		if Game.data.fittings.has(entry.get("fitting", "")):
			add_unit(StringName(entry["fitting"]), FittingUnit.saved_transform(entry))
	for entry: Dictionary in data["printers"]:
		if Game.data.printers.has(entry["id"]):
			# A printer whose rack isn't here (after a move, say) takes the next free spot.
			var station := install_printer(StringName(entry["id"]), int(entry.get("spot", -1)))
			if station != null:
				station.restore(entry)
