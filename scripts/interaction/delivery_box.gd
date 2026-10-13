class_name DeliveryBox
extends Interactable
## A supplier delivery sitting by the door until the character unpacks it:
## spools go to the rack, mailer boxes into stock, spare parts onto the
## shelving, a printer onto the bench, a dryer onto its spot. A flat packed
## fitting (shelving, a rack) is put up wherever the player chooses.

const SUPPLIES_MODEL := preload("res://assets/models/props/box_closed_01.glb")
const PRINTER_MODEL := preload("res://assets/models/props/box_closed_02.glb")

## Game minutes it takes to put a flat pack together.
const ASSEMBLY_MINUTES := 15.0

var delivery: Supplier.Delivery
## True once the player has said where a fitting goes and the job is queued.
var _spot_chosen := false


static func create(p_delivery: Supplier.Delivery) -> DeliveryBox:
	var box := DeliveryBox.new()
	box.delivery = p_delivery
	box.display_name = "Delivery: %s" % p_delivery.describe()
	box.stand_offset = Vector3(0.65, 0.0, 0.0)
	if p_delivery.fitting != &"":
		box.display_name = "Delivery: %s" % Game.data.fittings[p_delivery.fitting]["name"]
	if not p_delivery.printer_state.is_empty():
		box.display_name = "Boxed up: %s" % Game.data.printers[p_delivery.printer]["name"]
	box.add_child((PRINTER_MODEL if p_delivery.printer != &"" or p_delivery.dryer != &"" or p_delivery.fitting != &"" else SUPPLIES_MODEL).instantiate())
	return box


func _ready() -> void:
	super()
	add_to_group(&"delivery_box")
	add_to_group(&"obstacle")


func get_actions(_agent: Agent) -> Array[Action]:
	if delivery.fitting != &"":
		if _spot_chosen:
			return [Action.info("Waiting to be put up")]
		var choose := Action.new("Unpack and choose where it goes...", _choose_spot)
		choose.immediate = true
		return [choose]
	var action := Action.new("Unpack", _unpack)
	action.task_name = "Unpack %s" % delivery.describe().to_lower()
	return [action]


func _choose_spot(_agent: Agent) -> void:
	Placer.begin(self, delivery.fitting, place_at)


## Sets the character to putting the fitting up at `at`. In a dev run:
## on>delivery_box>place_at(Transform3D(Basis(), Vector3(1.0, 0, 0.5)))
func place_at(at: Transform3D) -> void:
	if _spot_chosen:
		return
	_spot_chosen = true
	var agent: Agent = get_tree().get_first_node_in_group(&"player")
	var action := Action.new("Put up the %s" % String(Game.data.fittings[delivery.fitting]["name"]).to_lower(), _put_up.bind(at))
	agent.enqueue(action)


func _put_up(agent: Agent, at: Transform3D) -> void:
	var row: Dictionary = Game.data.fittings[delivery.fitting]
	var host := Game.fitting_host(row["kind"])
	# The spot was free when it was chosen, which may be a while ago.
	if Placer.problem_for(get_tree(), delivery.fitting, at) != "":
		_spot_chosen = false
		agent.say("Something is in the way there now. Choose another spot.")
		return
	await agent.go_to(self)
	await agent.reach(_pick_up.bind(agent))
	var stand: Array = row["stand_offset"]
	var front := at * Vector3(stand[0], stand[1], stand[2])
	await agent.walk_to(Vector3(front.x, 0.0, front.z))
	await agent.face(at.origin)
	await agent.work(ASSEMBLY_MINUTES)
	agent.release()
	host.call(&"add_unit", delivery.fitting, at)
	queue_free()


func _unpack(agent: Agent) -> void:
	var shelf: StorageShelf = get_tree().get_first_node_in_group(&"print_storage")
	if delivery.printer != &"" and (get_tree().get_first_node_in_group(&"workbench") as Workbench).free_spots() <= 0:
		agent.say("There is nowhere to stand the printer. Put up a rack or a bench first.")
		return
	if not shelf.can_store_parts(delivery.parts.keys()):
		agent.say("No shelf space for the spare parts")
		return
	var spot: DryerSpot = get_tree().get_first_node_in_group(&"dryer_spot")
	if delivery.dryer != &"" and spot.problem() != "":
		agent.say(spot.problem())
		return
	await agent.go_to(self)
	await agent.reach(_pick_up.bind(agent))
	if delivery.printer != &"":
		var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
		var place := bench.next_place()
		if not place.is_empty():
			await agent.walk_to(place["stand"])
			await agent.face(place["face"])
		await agent.reach(func() -> void:
			var station := bench.install_printer(delivery.printer)
			# One that was boxed up off the bench comes out as it went in.
			if station != null and not delivery.printer_state.is_empty():
				station.restore(delivery.printer_state)
				bench.relink())
	if delivery.dryer != &"":
		var front := spot.global_transform * Vector3(0.0, 0.0, 0.6)
		await agent.walk_to(Vector3(front.x, 0.0, front.z))
		await agent.reach(func() -> void: spot.install(delivery.dryer))
	if not delivery.spools.is_empty():
		var rack: FilamentRack = get_tree().get_first_node_in_group(&"filament_rack")
		await agent.go_to(rack.spot())
		await agent.reach(func() -> void:
			for key in delivery.spools:
				var material := FilamentRules.material_of(key)
				rack.store(Spool.create(StringName(FilamentRules.colour_of(key)),
					float(Game.data.filaments[material]["spool_grams"]), StringName(material)))
			Game.changed.emit())
	if not delivery.packaging.is_empty():
		# Boxes and bags are kept at the packing station.
		var station: PackingStation = get_tree().get_first_node_in_group(&"packing_station")
		if station != null:
			await agent.go_to(station)
		await agent.reach(func() -> void:
			for kind in delivery.packaging:
				Game.add_packaging(kind, delivery.packaging[kind]))
	if not delivery.parts.is_empty():
		await agent.go_to(shelf.spot())
		await agent.reach(func() -> void:
			for part in delivery.parts:
				shelf.store_parts(part, delivery.parts[part]))
	agent.release()
	queue_free()


func _pick_up(agent: Agent) -> void:
	remove_collider()
	remove_from_group(&"obstacle")
	remove_from_group(&"delivery_box")
	agent.carry(self)
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
