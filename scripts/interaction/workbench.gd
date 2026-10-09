class_name Workbench
extends Interactable
## The workbench: printers stand on it. Orders are packed at the PackingStation.

## Where printers go, relative to this bench, in the order they fill. A longer
## bench sets more of them in its scene, and a print farm's also reach onto the
## other benches in the room, which are plain furniture: this one bench owns
## every printer.
@export var printer_spots: Array[Vector3] = [Vector3(-0.42, 0.9, 0.03), Vector3(0.42, 0.9, 0.03)]

var _printers: Array[PrinterStation] = []


func _ready() -> void:
	super()
	add_to_group(&"workbench")


func get_actions(_agent: Agent) -> Array[Action]:
	return [Action.info("%d of %d printer spaces used" % [_printers.size(), printer_spots.size()])]


func free_spots() -> int:
	return printer_spots.size() - _printers.size()


## Sets up a new printer on the next free spot. Null if the bench is full.
func install_printer(printer_id: StringName) -> PrinterStation:
	if free_spots() <= 0:
		return null
	var station := PrinterStation.create(printer_id)
	# A sibling rather than a child, so the bench and printer highlight separately.
	get_parent().add_child(station)
	station.global_transform = global_transform * Transform3D(Basis.IDENTITY, printer_spots[_printers.size()])
	_printers.append(station)
	Game.changed.emit()
	return station


func save() -> Dictionary:
	return {"printers": _printers.map(func(station: PrinterStation) -> Dictionary: return station.save())}


func restore(data: Dictionary) -> void:
	for entry: Dictionary in data["printers"]:
		if Game.data.printers.has(entry["id"]):
			var station := install_printer(StringName(entry["id"]))
			if station != null:
				station.restore(entry)
