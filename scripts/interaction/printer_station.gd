class_name PrinterStation
extends Interactable
## A printer in the world: holds a spool, runs a PrintJob and animates the
## model's bed, gantry and toolhead while it prints. Offers the load, print,
## collect and unload tasks. Animation is written for the open frame model.
##
## Prints never fail yet; that arrives in Phase 4.

enum Status { IDLE, PRINTING, DONE }

const MODEL_PATH := "res://assets/models/printers/printer_%s.glb"
## How far the gantry drops from its parked height to put the nozzle on the plate.
const GANTRY_DROP := 0.175

## Row from data/printers.json.
var spec: Dictionary
var status := Status.IDLE
var spool: Spool = null
var job: PrintJob = null
var item: PrintedItem = null

var _time := 0.0
var _spool_mount: Node3D
var _plate: Node3D
var _bed: Node3D
var _gantry: Node3D
var _toolhead: Node3D
var _bed_rest: Vector3
var _gantry_rest: Vector3
var _toolhead_rest: Vector3


## Builds a printer of the given type from data/printers.json.
static func create(printer_id: StringName) -> PrinterStation:
	var station := PrinterStation.new()
	station.spec = Game.data.printers[printer_id]
	station.display_name = station.spec["name"]
	station.stand_offset = Vector3(0.0, 0.0, 0.72)
	station.add_child((load(MODEL_PATH % station.spec["model"]["variant"]) as PackedScene).instantiate())
	return station


func _ready() -> void:
	super()
	add_to_group(&"printer")
	_spool_mount = find_child("spool_mount", true, false)
	_plate = find_child("plate", true, false)
	_bed = find_child("bed", true, false)
	_gantry = find_child("gantry", true, false)
	_toolhead = find_child("toolhead", true, false)
	_bed_rest = _bed.position
	_gantry_rest = _gantry.position
	_toolhead_rest = _toolhead.position


func _process(delta: float) -> void:
	var bed_target := _bed_rest
	var gantry_target := _gantry_rest
	var toolhead_target := _toolhead_rest
	if status == Status.PRINTING:
		_time += delta
		if job.advance(delta):
			_finish_print()
		# The item grows from the plate while the nozzle rides just above it.
		item.scale.y = maxf(job.progress, 0.02)
		gantry_target.y += item.height * job.progress - GANTRY_DROP
		toolhead_target.x += sin(_time * 5.0) * 0.09 - 0.05
		bed_target.z += sin(_time * 3.1) * 0.05
	var weight := 1.0 - exp(-10.0 * delta)
	_bed.position = _bed.position.lerp(bed_target, weight)
	_gantry.position = _gantry.position.lerp(gantry_target, weight)
	_toolhead.position = _toolhead.position.lerp(toolhead_target, weight)


func get_actions(_agent: Agent) -> Array[Action]:
	match status:
		Status.PRINTING:
			var left := GameClock.duration_label((job.duration - job.elapsed) * GameClock.MINUTES_PER_SECOND)
			return [Action.info("Printing %s: %d%%, %s left" % [Game.product_name(item.product), roundi(job.progress * 100.0), left])]
		Status.DONE:
			if _shelf().has_space():
				return [Action.new("Collect %s" % Game.product_name(item.product), _collect)]
			return [Action.info("Collect print (shelving is full)")]
	if spool == null:
		return [_load_menu()]
	return [Action.info("Loaded: %s" % spool.describe()), _print_menu(), Action.new("Unload filament", _unload)]


func _load_menu() -> Action:
	var rack := _rack()
	var colours: Array[Action] = []
	for colour in rack.available_colours():
		var label := "%s (%d g)" % [Palette.display_name(colour), roundi(rack.most_grams(colour))]
		var action := Action.new(label, _load.bind(colour))
		action.task_name = "Load %s filament" % Palette.display_name(colour).to_lower()
		colours.append(action)
	if colours.is_empty():
		return Action.info("Load filament (the rack is empty: order some at the PC)")
	return Action.submenu("Load filament", colours)


func _print_menu() -> Action:
	var designs: Array[Action] = []
	for product in Game.owned_designs:
		var row: Dictionary = Game.data.products[product]
		var label := "%s (%d g, %s)" % [row["name"], row["filament_grams"], GameClock.duration_label(print_minutes(product))]
		var enough := spool.grams >= float(row["filament_grams"])
		var action := Action.new(label if enough else label + ": not enough filament", _start.bind(product), enough)
		action.task_name = "Print %s" % row["name"]
		designs.append(action)
	if designs.is_empty():
		return Action.info("Print (no designs owned: buy one at the PC)")
	return Action.submenu("Print", designs)


## Game minutes this printer takes to print a design.
func print_minutes(product: StringName) -> float:
	return float(Game.data.products[product]["print_minutes"]) / float(spec["speed_multiplier"])


func load_spool(p_spool: Spool) -> void:
	spool = p_spool
	Interactable.attach(spool, _spool_mount)


func unload_spool() -> Spool:
	var removed := spool
	spool = null
	return removed


func start_print(product: StringName) -> void:
	spool.grams -= float(Game.data.products[product]["filament_grams"])
	item = PrintedItem.create(product, spool.colour)
	Interactable.attach(item, _plate)
	item.scale.y = 0.02
	job = PrintJob.new(GameClock.to_seconds(print_minutes(product)))
	status = Status.PRINTING


func take_item() -> PrintedItem:
	var taken := item
	item = null
	job = null
	status = Status.IDLE
	return taken


func _finish_print() -> void:
	status = Status.DONE
	Game.charge_electricity(spec["power_watts"], print_minutes(item.product), Game.product_name(item.product))
	Game.notify("%s finished printing: %s" % [display_name, Game.product_name(item.product)])


# Tasks. Each checks it still makes sense when its turn comes, because the
# world may have changed while it sat in the queue.

func _load(agent: Agent, colour: StringName) -> void:
	var rack := _rack()
	if spool != null or not rack.has_colour(colour):
		agent.say("Can't load %s filament right now" % Palette.display_name(colour).to_lower())
		return
	await agent.go_to(rack)
	await agent.reach(func() -> void: agent.carry(rack.take(colour)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: load_spool(agent.release() as Spool))


func _unload(agent: Agent) -> void:
	if spool == null or status == Status.PRINTING:
		agent.say("Can't unload the printer right now")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: agent.carry(unload_spool()))
	var removed := agent.carried as Spool
	if removed.is_empty():
		await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
		await agent.reach(func() -> void: agent.release().queue_free())
		agent.say("Binned an empty spool")
		return
	var rack := _rack()
	await agent.go_to(rack)
	await agent.reach(func() -> void: rack.store(agent.release() as Spool))


func _start(agent: Agent, product: StringName) -> void:
	if spool == null or status != Status.IDLE or spool.grams < float(Game.data.products[product]["filament_grams"]):
		agent.say("The printer isn't ready to print that")
		return
	await agent.go_to(self)
	await agent.reach(start_print.bind(product))


func _collect(agent: Agent) -> void:
	var shelf := _shelf()
	if status != Status.DONE or not shelf.has_space():
		agent.say("Nothing to collect")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: agent.carry(take_item()))
	await agent.go_to(shelf)
	await agent.reach(func() -> void: shelf.store(agent.release()))


func _rack() -> FilamentRack:
	return get_tree().get_first_node_in_group(&"filament_rack")


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")
