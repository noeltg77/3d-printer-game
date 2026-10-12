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
## The bays of the colour unit racks, where the multicolour unit of a printer
## on a rack sits: { holder: the unit rack, node: where in it, printer: whose unit is there or null }.
var _bays: Array[Dictionary] = []


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
			var sell := Action.new("Sell %s for %s" % [title.to_lower(), Money.format(bench_value())], _take_out.bind(bench, true))
			sell.task_name = "Take out the %s to sell" % bench_name(bench)
			var scrap := Action.new("Scrap %s" % title.to_lower(), _take_out.bind(bench, false))
			scrap.task_name = "Scrap the %s" % bench_name(bench)
			benches.append_array([sell, scrap])
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
	for place: Array in Game.data.fittings[fitting].get("printer_spots", []):
		_spots.append({"holder": unit, "at": Vector3(place[0], place[1], place[2]), "printer": null})
	for place: Array in Game.data.fittings[fitting].get("unit_bays", []):
		var bay := Node3D.new()
		unit.add_child(bay)
		bay.position = Vector3(place[0], place[1], place[2])
		_bays.append({"holder": unit, "node": bay, "printer": null})
	relink()
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild.call_deferred()
	Game.changed.emit()
	return unit


## True if a printer stands on a bought rack or bench, or a unit sits in a colour unit rack.
func unit_in_use(unit: FittingUnit) -> bool:
	return _places_on(unit).any(func(spot: Dictionary) -> bool: return spot["printer"] != null) \
		or _bays.any(func(bay: Dictionary) -> bool: return bay["holder"] == unit and bay["printer"] != null)


## Gives up a bought rack's places, for it to be sold or scrapped. It has to be empty.
func remove_unit(unit: FittingUnit) -> void:
	_spots = _spots.filter(func(spot: Dictionary) -> bool: return spot["holder"] != unit)
	_bays = _bays.filter(func(bay: Dictionary) -> bool: return bay["holder"] != unit)
	_units.erase(unit)
	relink()
	Game.changed.emit()


## A rack has been stood somewhere else: its printers go with it.
func unit_moved(unit: FittingUnit) -> void:
	for spot in _spots:
		if spot["holder"] == unit and spot["printer"] != null:
			_seat(spot)
	relink()


## True if a printer stands somewhere with no room on top of it for a
## multicolour unit: on a printer rack. Its unit has to sit in a colour unit rack beside it.
func needs_bay(station: PrinterStation) -> bool:
	for spot in _spots:
		if spot["printer"] == station:
			return spot["holder"] is FittingUnit and bool(Game.data.fittings[(spot["holder"] as FittingUnit).fitting].get("units_beside", false))
	return false


## True if a printer could have a multicolour unit where it stands: on a
## bench, or on a rack with a bay for it in reach.
func can_take_unit(station: PrinterStation) -> bool:
	return not needs_bay(station) or _bay_of(station) != null or _free_bay_near(station) != null


## Works out afresh which unit sits in which bay, after anything has been
## moved, fitted or taken away. A unit keeps its bay while it is in reach;
## one with no bay in reach goes back on its printer, which can't then print.
func relink() -> void:
	for bay in _bays:
		var station: PrinterStation = bay["printer"] if is_instance_valid(bay["printer"]) else null
		if station == null or not station.has_unit() or not needs_bay(station) or not _in_reach(bay, station):
			bay["printer"] = null
	for spot in _spots:
		var station: PrinterStation = spot["printer"]
		if station == null or not is_instance_valid(station):
			continue
		var bay: Variant = _bay_of(station)
		if bay == null and station.has_unit() and needs_bay(station):
			bay = _free_bay_near(station)
			if bay != null:
				bay["printer"] = station
		station.set_unit_bay(bay["node"] if bay != null else null)


func _bay_of(station: PrinterStation) -> Variant:
	for bay in _bays:
		if bay["printer"] == station:
			return bay
	return null


## The nearest empty bay close enough to feed a printer, or null.
func _free_bay_near(station: PrinterStation) -> Variant:
	var best: Variant = null
	for bay in _bays:
		if bay["printer"] == null and _in_reach(bay, station) and (best == null or _gap(bay, station) < _gap(best, station)):
			best = bay
	return best


func _gap(bay: Dictionary, station: PrinterStation) -> float:
	var from: Vector3 = (bay["holder"] as Node3D).global_position
	return Vector2(from.x - station.global_position.x, from.z - station.global_position.z).length()


func _in_reach(bay: Dictionary, station: PrinterStation) -> bool:
	return Game.storage.in_reach(_gap(bay, station))


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
				relink()
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
	relink()
	Game.changed.emit()
	return station


## Takes a printer off its spot for good, leaving the spot free. The caller frees the printer.
func remove_printer(station: PrinterStation) -> void:
	for spot in _spots:
		if spot["printer"] == station:
			spot["printer"] = null
	relink()
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


## What one of the premises' own benches fetches second hand, in pence.
func bench_value() -> int:
	return roundi(float(Game.data.fittings["workbench_unit"]["price_pence"]) * float(Game.data.settings["resale"]["fitting_share"]))


func _take_out(agent: Agent, bench: Node3D, sell: bool) -> void:
	if not is_instance_valid(bench) or not _benches.has(bench) or _places_on(bench).any(func(spot: Dictionary) -> bool: return spot["printer"] != null):
		agent.say("That bench can't come out right now")
		return
	var title := bench_name(bench)
	var front := bench.global_transform * Vector3(0.0, 0.0, REACH)
	await agent.walk_to(Vector3(front.x, 0.0, front.z))
	await agent.face(bench.global_position)
	await agent.work(float(Game.data.settings["resale"]["scrap_minutes"]))
	remove_bench(bench)
	var tree := get_tree()
	var flat_pack := Node3D.new()
	flat_pack.add_child(DeliveryBox.PRINTER_MODEL.instantiate())
	agent.carry(flat_pack)
	if sell:
		var pence := bench_value()
		await agent.go_to(tree.get_first_node_in_group(&"packing_station") as PackingStation)
		await agent.work(float(Game.data.settings["resale"]["pack_minutes"]))
		agent.release().queue_free()
		await agent.reach(func() -> void: agent.carry(Parcel.create_resale(title.capitalize(), pence)))
		var outbox: Outbox = tree.get_first_node_in_group(&"outbox")
		await agent.go_to(outbox)
		await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))
		Game.notify("The %s is boxed up for its buyer. You are paid %s when the courier collects it." % [title, Money.format(pence)])
	else:
		await agent.walk_to(tree.get_first_node_in_group(&"bin").global_position)
		await agent.reach(func() -> void: agent.release().queue_free())
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
	relink()
