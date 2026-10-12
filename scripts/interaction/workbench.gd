class_name Workbench
extends Interactable
## The workbench: printers stand on it. Orders are packed at the PackingStation.
##
## It owns every printer on the premises and every place one can stand. Those
## are its own `printer_spots` (which, in a print farm, reach onto the other
## benches in the room: plain furniture in the `spare_bench` group) and, once
## the player buys them, the places on printer racks and bought benches
## (FittingUnit, of kind "bench"). Whatever a printer stands on is its place's
## `holder`.
##
## A bench that came with the premises can be taken out for good once nothing
## stands on it, to make room for racks: this node then stays, unseen, to go
## on owning the printers. How many places the premises may have in all is its
## `max_printers`.

const FITTING_KIND := "bench"
## How far in front of a place the character stands to reach it.
const REACH := 0.78

## Where printers go, relative to this bench, in the order they fill. A longer
## bench sets more of them in its scene, and a print farm's also reach onto the
## other benches in the room.
@export var printer_spots: Array[Vector3] = [Vector3(-0.42, 0.9, 0.03), Vector3(0.42, 0.9, 0.03)]

## Every place a printer can stand, the premises' own first:
## { holder: what it is on, at: where on that, printer: what stands there or null }.
## A place on a bench that has been taken out stays in the list, so that the
## others keep their numbers, but with no holder.
var _spots: Array[Dictionary] = []
var _units: Array[FittingUnit] = []
## The benches that came with the premises and are still here, this one included.
var _benches: Array[Node3D] = []
## Names of the ones taken out.
var _removed: Array[String] = []


func _ready() -> void:
	super()
	add_to_group(&"workbench")
	_benches = [self]
	for spare: Node3D in get_tree().get_nodes_in_group(&"spare_bench"):
		_benches.append(spare)
		# A plain bench is clicked through a stand-in, which offers what this one does.
		var proxy := BenchProxy.new()
		proxy.host = self
		proxy.display_name = display_name
		proxy.name = "%sProxy" % spare.name
		spare.add_child(proxy)
		proxy.visual_path = proxy.get_path_to(spare)
	for at in printer_spots:
		# Each place belongs to whichever bench it is over.
		var place := global_transform * at
		var holder: Node3D = self
		for bench in _benches:
			if Vector2(bench.global_position.x - place.x, bench.global_position.z - place.z).length() \
					< Vector2(holder.global_position.x - place.x, holder.global_position.z - place.z).length():
				holder = bench
		_spots.append({"holder": holder, "at": holder.global_transform.affine_inverse() * place, "printer": null})


func get_actions(_agent: Agent) -> Array[Action]:
	var actions: Array[Action] = [Action.info("%d of %d printer places used. This place has room for %d." % [
		total_places() - free_spots(), total_places(), max_places()])]
	var benches: Array[Action] = []
	for bench in _benches:
		var places := _places_on(bench)
		var title := "The %s (%d place%s)" % [bench_name(bench), places.size(), "" if places.size() == 1 else "s"]
		if places.any(func(spot: Dictionary) -> bool: return spot["printer"] != null):
			benches.append(Action.info("%s: move or sell its printers first" % title))
		else:
			var remove := Action.new(title, _take_out.bind(bench))
			remove.task_name = "Take out the %s" % bench_name(bench)
			benches.append(remove)
	if not benches.is_empty():
		actions.append(Action.submenu("Take a bench out for good", benches))
	return actions


## How many places for printers there are now.
func total_places() -> int:
	return _spots.filter(func(spot: Dictionary) -> bool: return spot["holder"] != null).size()


## How many the premises has room for.
func max_places() -> int:
	return int(Game.premises_row().get("max_printers", total_places()))


func free_spots() -> int:
	return _spots.filter(func(spot: Dictionary) -> bool: return spot["holder"] != null and spot["printer"] == null).size()


## How many bought benches and racks there are, and this one.
func unit_count() -> int:
	return 1 + _units.size()


## "workbench", "back bench", "front bench east": what a bench is called.
func bench_name(bench: Node3D) -> String:
	return "workbench" if bench == self else String(bench.name).capitalize().to_lower()


## Stands a bought printer rack or bench in the room and takes on its places.
func add_unit(fitting: StringName, at: Transform3D) -> FittingUnit:
	var unit := FittingUnit.create(fitting, self)
	get_parent().add_child(unit)
	unit.global_transform = at
	_units.append(unit)
	for place: Array in Game.data.fittings[fitting]["printer_spots"]:
		_spots.append({"holder": unit, "at": Vector3(place[0], place[1], place[2]), "printer": null})
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## A rack has been stood somewhere else: its printers go with it.
func unit_moved(unit: FittingUnit) -> void:
	for spot in _spots:
		if spot["holder"] == unit and spot["printer"] != null:
			_seat(spot)


## Where to stand to put a printer on the next free place, and what to face. {} if there is none.
func next_place() -> Dictionary:
	for spot in _spots:
		if spot["holder"] != null and spot["printer"] == null:
			return _approach(spot)
	return {}


## Each thing with a free place on it, other than the one `station` is on:
## { holder, title } for the printer's "Move it" menu.
func other_places(station: PrinterStation) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Array[Node3D] = []
	var own: Node3D = null
	for spot in _spots:
		if spot["printer"] == station:
			own = spot["holder"]
	for spot in _spots:
		var holder: Node3D = spot["holder"]
		if holder == null or holder == own or spot["printer"] != null or seen.has(holder):
			continue
		seen.append(holder)
		found.append({"holder": holder, "title": String((holder as FittingUnit).display_name).to_lower() if holder is FittingUnit else bench_name(holder)})
	return found


## Moves a printer to the first free place on `holder`. Returns where to stand
## to do it, as next_place() does, or {} if there is no room there.
func move_printer(station: PrinterStation, holder: Node3D, seat_now := true) -> Dictionary:
	for target in _spots:
		if target["holder"] == holder and target["printer"] == null:
			if seat_now:
				for spot in _spots:
					if spot["printer"] == station:
						spot["printer"] = null
				target["printer"] = station
				_seat(target)
				Game.changed.emit()
			return _approach(target)
	return {}


## Sets up a new printer on the next free spot. Null if there is none.
func install_printer(printer_id: StringName, at_spot := -1) -> PrinterStation:
	var index := at_spot if at_spot >= 0 and at_spot < _spots.size() and _usable(at_spot) else -1
	if index < 0:
		for candidate in _spots.size():
			if _usable(candidate):
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


## Takes one of the premises' own benches out, with its places. False if a printer is on it.
func remove_bench(bench: Node3D) -> bool:
	if not _benches.has(bench) or _places_on(bench).any(func(spot: Dictionary) -> bool: return spot["printer"] != null):
		return false
	for spot in _places_on(bench):
		spot["holder"] = null
	_benches.erase(bench)
	_removed.append(String(bench.name))
	bench.remove_from_group(&"obstacle")
	if bench == self:
		# Still the owner of every printer, so it only goes out of sight.
		for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			mesh.visible = false
		remove_collider()
	else:
		bench.queue_free()
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return true


func _take_out(agent: Agent, bench: Node3D) -> void:
	if not is_instance_valid(bench) or not _benches.has(bench) or _places_on(bench).any(func(spot: Dictionary) -> bool: return spot["printer"] != null):
		agent.say("That bench can't come out right now")
		return
	var title := bench_name(bench)
	var front := bench.global_transform * Vector3(0.0, 0.0, REACH)
	await agent.walk_to(Vector3(front.x, 0.0, front.z))
	await agent.face(bench.global_position)
	await agent.work(float(Game.data.settings["resale"]["scrap_minutes"]))
	remove_bench(bench)
	agent.say("The %s is out. There is floor there now for a rack." % title)


func _usable(index: int) -> bool:
	return _spots[index]["holder"] != null and _spots[index]["printer"] == null


func _places_on(holder: Node3D) -> Array[Dictionary]:
	return _spots.filter(func(spot: Dictionary) -> bool: return spot["holder"] == holder)


func _approach(spot: Dictionary) -> Dictionary:
	var holder: Node3D = spot["holder"]
	var at: Vector3 = spot["at"]
	var stand := holder.global_transform * Vector3(at.x, 0.0, at.z + REACH)
	return {"stand": Vector3(stand.x, 0.0, stand.z), "face": holder.global_transform * at}


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
	return {"printers": printers, "removed": _removed,
		"units": _units.map(func(unit: FittingUnit) -> Dictionary: return unit.save())}


func restore(data: Dictionary) -> void:
	for gone: String in data.get("removed", []):
		for bench in _benches.duplicate():
			if String(bench.name) == gone:
				remove_bench(bench)
	for entry: Dictionary in data.get("units", []):
		if Game.data.fittings.has(entry.get("fitting", "")):
			add_unit(StringName(entry["fitting"]), FittingUnit.saved_transform(entry))
	for entry: Dictionary in data["printers"]:
		if Game.data.printers.has(entry["id"]):
			# A printer whose rack isn't here (after a move, say) takes the next free spot.
			var station := install_printer(StringName(entry["id"]), int(entry.get("spot", -1)))
			if station != null:
				station.restore(entry)
