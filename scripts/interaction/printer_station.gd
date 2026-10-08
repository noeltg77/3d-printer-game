class_name PrinterStation
extends Interactable
## A printer in the world: holds a spool, runs a PrintJob and animates the
## model's bed, gantry and toolhead while it prints. Offers the load, print,
## collect and unload tasks. Written for the open frame (bed slinger) model.
##
## Phase 2 fake print: fixed product, fixed time, never fails.

enum Status { IDLE, PRINTING, DONE }

@export var print_seconds := 20.0
@export var product: StringName = &"desk_organiser"
## How far the gantry drops from its parked height to put the nozzle on the plate.
@export var gantry_drop := 0.175

var status := Status.IDLE
var spool: Spool = null
var job: PrintJob = null
var item: PrintedItem = null

var _time := 0.0
@onready var _spool_mount: Node3D = find_child("spool_mount", true, false)
@onready var _plate: Node3D = find_child("plate", true, false)
@onready var _bed: Node3D = find_child("bed", true, false)
@onready var _gantry: Node3D = find_child("gantry", true, false)
@onready var _toolhead: Node3D = find_child("toolhead", true, false)
@onready var _bed_rest := _bed.position
@onready var _gantry_rest := _gantry.position
@onready var _toolhead_rest := _toolhead.position


func _process(delta: float) -> void:
	var bed_target := _bed_rest
	var gantry_target := _gantry_rest
	var toolhead_target := _toolhead_rest
	if status == Status.PRINTING:
		_time += delta
		if job.advance(delta):
			status = Status.DONE
		# The item grows from the plate while the nozzle rides just above it.
		item.scale.y = maxf(job.progress, 0.02)
		gantry_target.y += item.height * job.progress - gantry_drop
		toolhead_target.x += sin(_time * 5.0) * 0.09 - 0.05
		bed_target.z += sin(_time * 3.1) * 0.05
	var weight := 1.0 - exp(-10.0 * delta)
	_bed.position = _bed.position.lerp(bed_target, weight)
	_gantry.position = _gantry.position.lerp(gantry_target, weight)
	_toolhead.position = _toolhead.position.lerp(toolhead_target, weight)


func get_actions(_agent: Agent) -> Array[Action]:
	match status:
		Status.PRINTING:
			return [Action.info("Printing... %d%%" % roundi(job.progress * 100.0))]
		Status.DONE:
			if _shelf().has_space():
				return [Action.new("Collect print", _collect)]
			return [Action.info("Collect print (shelf is full)")]
	if spool == null:
		var colours: Array[Action] = []
		for colour in _rack().available_colours():
			var action := Action.new(Palette.display_name(colour), _load.bind(colour))
			action.task_name = "Load %s filament" % action.label.to_lower()
			colours.append(action)
		if colours.is_empty():
			return [Action.info("Load filament (rack is empty)")]
		return [Action.submenu("Load filament", colours)]
	return [
		Action.new("Start print (%s)" % Palette.display_name(spool.colour), _start),
		Action.new("Unload filament", _unload),
	]


func load_spool(p_spool: Spool) -> void:
	spool = p_spool
	Interactable.attach(spool, _spool_mount)


func unload_spool() -> Spool:
	var removed := spool
	spool = null
	return removed


func start_print() -> void:
	item = PrintedItem.create(product, spool.colour)
	Interactable.attach(item, _plate)
	item.scale.y = 0.02
	job = PrintJob.new(print_seconds)
	status = Status.PRINTING


func take_item() -> PrintedItem:
	var taken := item
	item = null
	job = null
	status = Status.IDLE
	return taken


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
	var rack := _rack()
	await agent.go_to(rack)
	await agent.reach(func() -> void: rack.store(agent.release() as Spool))


func _start(agent: Agent) -> void:
	if spool == null or status != Status.IDLE:
		agent.say("The printer isn't ready to print")
		return
	await agent.go_to(self)
	await agent.reach(start_print)


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
