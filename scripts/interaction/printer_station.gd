class_name PrinterStation
extends Interactable
## A printer in the world: holds a spool, runs a PrintJob and animates the
## model's bed, gantry and toolhead while it prints. Offers the load, print,
## collect and unload tasks. Animation is written for the open frame model.
##
## A print's fate is rolled as it starts (Game.roll_print). One that is ruined
## stops part way and leaves a FailedPrint on the plate, which has to be cleared
## before the printer can be used again; one that is only spoiled finishes as a
## flawed item.
##
## Every print wears the printer's parts (PrinterWear). Worn parts make failures
## more likely, and one that runs out mid-print stops it: the printer then can't
## print until the character fits a spare from the shelving.

enum Status { IDLE, PRINTING, DONE, FAILED }

const MODEL_PATH := "res://assets/models/printers/printer_%s.glb"
## How far the gantry drops from its parked height to put the nozzle on the plate.
const GANTRY_DROP := 0.175

## Row from data/printers.json.
var spec: Dictionary
var status := Status.IDLE
var spool: Spool = null
var job: PrintJob = null
var item: PrintedItem = null
## What a ruined print left on the plate, while status is FAILED.
var scrap: FailedPrint = null
## Preset of the print on the plate.
var preset: StringName = &"standard"
## The state of this printer's wear parts.
var wear: PrinterWear

## Filament the current print was set to use.
var _grams := 0.0
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
	station.wear = PrinterWear.new(Game.data.parts, station.spec, float(Game.data.settings["wear_rate"]))
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
		# The item grows from the plate while the nozzle rides just above it.
		var ended := job.advance(delta)
		item.scale.y = maxf(job.progress, 0.02)
		gantry_target.y += item.height * job.progress - GANTRY_DROP
		toolhead_target.x += sin(_time * 5.0) * 0.09 - 0.05
		bed_target.z += sin(_time * 3.1) * 0.05
		if ended:
			_end_print()
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
				return [Action.new("Collect %s" % item.describe(), _collect)]
			return [Action.info("Collect print (shelving is full)")]
		Status.FAILED:
			var failure := scrap.failure
			var fix := Action.new("%s (%s)" % [failure["fix"], GameClock.duration_label(failure["clear_minutes"])], _clear)
			fix.task_name = "Sort out the %s" % display_name
			return [Action.info("%s: %s" % [failure["name"], Game.product_name(scrap.product)]), fix]
	if spool == null:
		return [_load_menu(), _parts_menu()]
	return [Action.info("Loaded: %s" % spool.describe()), _print_menu(), Action.new("Unload filament", _unload), _parts_menu()]


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
	if Game.owned_designs.is_empty():
		return Action.info("Print (no designs owned: buy one at the PC)")
	var action := Action.new("Print...", _open_print_dialog)
	action.immediate = true
	return action


## Each part's health, with the task of swapping it for a spare.
func _parts_menu() -> Action:
	var shelf := _shelf()
	var lines: Array[Action] = []
	for slot in wear.slots():
		var part := wear.part(slot)
		var label := "%s: %s" % [part["slot_name"], health_label(slot)]
		var spares := shelf.spare_count(wear.fitted[slot])
		if spares > 0:
			label += ". Fit a new one (%s)" % GameClock.duration_label(part["replace_minutes"])
		else:
			label += ". No spare on the shelf"
		var action := Action.new(label, _replace.bind(slot), spares > 0)
		action.task_name = "Fit a new %s to the %s" % [String(part["slot_name"]).to_lower(), display_name]
		lines.append(action)
	return Action.submenu("Parts", lines)


## "84%", "24%, worn" or "worn out"
func health_label(slot: StringName) -> String:
	if wear.is_broken(slot):
		return "worn out"
	var percent := maxi(roundi(wear.health[slot] * 100.0), 1)
	return "%d%%, worn" % percent if wear.is_worn(slot) else "%d%%" % percent


## The task of printing a design at a preset, as set up in the print dialog.
func print_action(product: StringName, p_preset: StringName) -> Action:
	return Action.new("Print %s" % Game.product_name(product), _start.bind(product, p_preset),
		print_problem(product, p_preset) == "")


## Why a design can't be printed here right now, or "" if it can.
func print_problem(product: StringName, p_preset: StringName) -> String:
	if spool == null:
		return "No filament loaded"
	if status != Status.IDLE:
		return "The printer is busy"
	for slot in wear.broken():
		return "The %s is worn out. Fit a new one first" % String(wear.part(slot)["slot_name"]).to_lower()
	if not Game.data.products[product]["allowed_filaments"].has(String(spool.material)):
		return "This design can't be printed in %s" % String(spool.material).to_upper()
	if spool.grams < Game.print_grams(product, p_preset):
		return "Not enough filament on the spool"
	return ""


## Game minutes this printer takes to print a design at a preset.
func print_minutes(product: StringName, p_preset: StringName) -> float:
	return (float(Game.data.products[product]["print_minutes"]) * float(Game.data.presets[p_preset]["time_multiplier"])
		/ float(spec["speed_multiplier"]))


func load_spool(p_spool: Spool) -> void:
	spool = p_spool
	Interactable.attach(spool, _spool_mount)


func unload_spool() -> Spool:
	var removed := spool
	spool = null
	return removed


func start_print(product: StringName, p_preset: StringName) -> void:
	preset = p_preset
	_grams = Game.print_grams(product, preset)
	spool.grams -= _grams
	item = PrintedItem.create(product, spool.colour, preset)
	Interactable.attach(item, _plate)
	item.scale.y = 0.02
	job = PrintJob.new(GameClock.to_seconds(print_minutes(product, preset)))
	var fate := Game.roll_print(spec, preset, spool.material, product, wear)
	if not fate.is_empty():
		job.fail(fate["failure"], fate["at"])
	# A part that runs out before anything else goes wrong stops the print there.
	var breakdown := wear.breaks_during(print_minutes(product, preset) / 60.0, Game.data.presets[preset], Game.data.filaments[spool.material])
	if not breakdown.is_empty() and breakdown["at"] < job.stop_at:
		job.fail(_breakdown(breakdown["slot"]), breakdown["at"])
	status = Status.PRINTING


func take_item() -> PrintedItem:
	var taken := item
	item = null
	job = null
	status = Status.IDLE
	return taken


## Hands over the ruined print, leaving the printer ready to use again.
func take_scrap() -> FailedPrint:
	var taken := scrap
	scrap = null
	job = null
	status = Status.IDLE
	Game.changed.emit()
	return taken


## The failure for a part giving out: the `breakdown` row, worded for the part.
func _breakdown(slot: StringName) -> Dictionary:
	var part := wear.part(slot)
	var failure: Dictionary = Game.data.failures["breakdown"].duplicate()
	failure["name"] = String(failure["name"]).format({"part": part["slot_name"]})
	failure["player_text"] = String(failure["player_text"]).format({"text": part["break_text"]})
	failure["damages"] = {String(slot): 1.0}
	return failure


func _end_print() -> void:
	var title := Game.product_name(item.product)
	var minutes_run := print_minutes(item.product, preset) * job.progress
	Game.charge_electricity(spec["power_watts"], minutes_run, title)
	wear.apply(minutes_run / 60.0, Game.data.presets[preset], Game.data.filaments[spool.material])
	for slot: String in job.failure.get("damages", {}):
		wear.damage(StringName(slot), float(job.failure["damages"][slot]))
	if job.ruined:
		# Filament the print never got to is still on the spool.
		spool.grams += _grams * (1.0 - job.progress)
		scrap = FailedPrint.create(item, job.failure)
		Interactable.attach(scrap, _plate)
		item = null
		status = Status.FAILED
		Game.notify("%s: %s. %s" % [display_name, job.failure["name"], job.failure["player_text"]])
	elif not job.failure.is_empty():
		item.spoil(job.failure)
		status = Status.DONE
		Game.notify("%s finished %s, but: %s. %s" % [
			display_name, title, String(job.failure["name"]).to_lower(), job.failure["player_text"]])
	else:
		status = Status.DONE
		Game.notify("%s finished printing: %s" % [display_name, title])
	Game.changed.emit()


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


func _start(agent: Agent, product: StringName, p_preset: StringName) -> void:
	if print_problem(product, p_preset) != "":
		agent.say("The printer isn't ready to print that")
		return
	await agent.go_to(self)
	await agent.reach(start_print.bind(product, p_preset))


## Not a task: opens the print set-up card, which queues the print itself.
func _open_print_dialog(_agent: Agent) -> void:
	(get_tree().get_first_node_in_group(&"print_dialog") as PrintDialog).open(self)


func _collect(agent: Agent) -> void:
	var shelf := _shelf()
	if status != Status.DONE or not shelf.has_space():
		agent.say("Nothing to collect")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: agent.carry(take_item()))
	await agent.go_to(shelf)
	await agent.reach(func() -> void: shelf.store(agent.release()))


func _clear(agent: Agent) -> void:
	if status != Status.FAILED:
		agent.say("Nothing to sort out on the %s" % display_name)
		return
	await agent.go_to(self)
	await agent.work(float(scrap.failure["clear_minutes"]))
	await agent.reach(func() -> void: agent.carry(take_scrap()))
	await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
	await agent.reach(func() -> void: agent.release().queue_free())
	agent.say("Binned the failed print")


func _replace(agent: Agent, slot: StringName) -> void:
	var shelf := _shelf()
	if status == Status.PRINTING or shelf.spare_count(wear.fitted[slot]) == 0:
		agent.say("Can't change the %s right now" % String(wear.part(slot)["slot_name"]).to_lower())
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void: agent.carry(shelf.take_spare(wear.fitted[slot])))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.work(float(wear.part(slot)["replace_minutes"]))
	await agent.reach(func() -> void:
		var spare := agent.release() as SparePart
		wear.replace(slot, spare.part)
		spare.queue_free()
		Game.changed.emit())
	agent.say("Fitted a new %s" % String(wear.part(slot)["slot_name"]).to_lower())


func _rack() -> FilamentRack:
	return get_tree().get_first_node_in_group(&"filament_rack")


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")
