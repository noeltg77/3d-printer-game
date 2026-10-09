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
##
## A printer holds one spool, on its own mount. Fitting a multicolour unit (an
## upgrade with a `multicolour` block) puts the unit's model on the printer and
## gives it a slot per spool instead; a print then draws on one slot for each
## colour of the design, and wastes a little filament on every colour change.

enum Status { IDLE, PRINTING, DONE, FAILED }

const MODEL_PATH := "res://assets/models/printers/%s.glb"
## How far a core XY printer's bed rises from rest to meet the nozzle, before
## sinking again as the print grows.
const CORE_XY_LIFT := 0.14
## How far the gantry drops from its parked height to put the nozzle on the plate.
const GANTRY_DROP := 0.175

## Row from data/printers.json.
var spec: Dictionary
var status := Status.IDLE
## What is loaded, one entry per place a spool can go: the printer's own mount,
## or each slot of its multicolour unit. Null where there is nothing.
var spools: Array[Spool] = [null]
## The first spool loaded, or null. All there is on a printer with no unit.
var spool: Spool:
	get:
		for loaded in spools:
			if loaded != null:
				return loaded
		return null
var job: PrintJob = null
var item: PrintedItem = null
## What a ruined print left on the plate, while status is FAILED.
var scrap: FailedPrint = null
## Preset of the print on the plate.
var preset: StringName = &"standard"
## The state of this printer's wear parts.
var wear: PrinterWear
## The upgrades fitted to it.
var mods: PrinterMods

## The slots the current print draws on, one per colour, and the grams it was
## set to take from each (its share of the print and of the purged filament).
var _slots_used: Array[int] = []
var _grams_used: Array[float] = []
## Game minutes the current print takes from start to finish.
var _minutes := 0.0
var _time := 0.0
var _spool_mount: Node3D
## Where the spool in each entry of `spools` sits.
var _mounts: Array[Node3D] = []
var _unit_model: Node3D = null
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
	station.mods = PrinterMods.new(Game.data.upgrades)
	station.display_name = station.spec["name"]
	station.stand_offset = Vector3(0.0, 0.0, 0.72)
	station.add_child((load(MODEL_PATH % station.spec["model"]["asset"]) as PackedScene).instantiate())
	return station


func _ready() -> void:
	super()
	add_to_group(&"printer")
	_spool_mount = find_child("spool_mount", true, false)
	_mounts = [_spool_mount]
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
		if spec["motion"] == "core_xy":
			# The head stays up and darts about; the bed sinks as the print grows.
			bed_target.y += CORE_XY_LIFT - item.height * job.progress
			toolhead_target.x += sin(_time * 5.0) * 0.09 - 0.05
			toolhead_target.z += sin(_time * 3.7) * 0.07 + 0.03
		else:
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
	var actions: Array[Action] = []
	for slot in spools.size():
		if not has_unit():
			if spools[slot] != null:
				actions.append(Action.info("Loaded: %s" % spools[slot].describe()))
		else:
			actions.append(Action.info("%s: %s" % [slot_name(slot), spools[slot].describe() if spools[slot] != null else "empty"]))
	if free_slot() >= 0:
		actions.append(_load_menu())
	if spool != null:
		actions.append(_print_menu())
		actions.append(_unload_menu())
	actions.append(_parts_menu())
	actions.append(_upgrades_menu())
	return actions


func has_unit() -> bool:
	return not mods.unit().is_empty()


## "Slot 2", for the second entry of `spools`.
func slot_name(slot: int) -> String:
	return "Slot %d" % (slot + 1)


## The first place a spool could go, or -1 if they are all taken.
func free_slot() -> int:
	return spools.find(null)


## "Red PLA", or "Red + White PLA" for a print in several colours.
func printing_in() -> String:
	var names: PackedStringArray = []
	for colour in item.colours:
		names.append(Palette.display_name(colour))
	return "%s %s" % [" + ".join(names), Game.data.filaments[item.material]["name"]]


func _load_menu() -> Action:
	var rack := _rack()
	var kinds: Array[Action] = []
	for kind in rack.kinds():
		var filament: Dictionary = Game.data.filaments[kind["material"]]
		var title := "%s %s" % [Palette.display_name(kind["colour"]), filament["name"]]
		var problem := FilamentRules.problem(mods.apply(spec), filament)
		var label := "%s (%d g)" % [title, roundi(rack.most_grams(kind["material"], kind["colour"]))]
		var action := Action.new(label if problem == "" else "%s: %s" % [title, problem.to_lower()],
			_load.bind(kind["material"], kind["colour"]), problem == "")
		action.task_name = "Load %s" % title.to_lower()
		kinds.append(action)
	if kinds.is_empty():
		return Action.info("Load filament (the rack is empty: order some at the PC)")
	return Action.submenu("Load filament", kinds)


func _unload_menu() -> Action:
	if not has_unit():
		return Action.new("Unload filament", _unload.bind(spools.find(spool)))
	var lines: Array[Action] = []
	for slot in spools.size():
		if spools[slot] != null:
			var action := Action.new("%s: %s" % [slot_name(slot), spools[slot].describe()], _unload.bind(slot))
			action.task_name = "Unload %s" % spools[slot].title().to_lower()
			lines.append(action)
	return Action.submenu("Unload filament", lines)


func _print_menu() -> Action:
	if Game.owned_designs.is_empty():
		return Action.info("Print (no designs owned: buy one at the PC)")
	var action := Action.new("Print...", _open_print_dialog)
	action.immediate = true
	return action


## Each part's health, with the task of swapping it for a spare. Any spare
## that goes in the same slot will do, so a better part can replace a basic one.
func _parts_menu() -> Action:
	var lines: Array[Action] = []
	for slot in wear.slots():
		var part := wear.part(slot)
		var state := "%s: %s" % [part["slot_name"], health_label(slot)]
		var offered := 0
		for box in _shelf().spares():
			var spare: Dictionary = Game.data.parts.get(box.part, {})
			if spare.get("slot", "") != String(slot):
				continue
			offered += 1
			var same := box.part == wear.fitted[slot]
			var action := Action.new("%s. Fit %s (%s)" % [state, "a new one" if same else "the %s" % String(spare["name"]).to_lower(),
				GameClock.duration_label(spare["replace_minutes"])], _replace.bind(slot, box.part))
			action.task_name = "Fit a new %s to the %s" % [String(part["slot_name"]).to_lower(), display_name]
			lines.append(action)
		if offered == 0:
			lines.append(Action.info("%s. No spare on the shelf" % state))
	return Action.submenu("Parts", lines)


## What is fitted, and the task of fitting each kit on the shelving that will go on.
func _upgrades_menu() -> Action:
	var lines: Array[Action] = []
	for upgrade in mods.fitted:
		lines.append(Action.info("Fitted: %s" % Game.data.upgrades[upgrade]["name"]))
	for box in _shelf().spares():
		if not Game.data.upgrades.has(box.part):
			continue
		var row: Dictionary = Game.data.upgrades[box.part]
		var problem := upgrade_problem(box.part)
		var label := "Fit %s (%s)" % [_kit_name(row), GameClock.duration_label(row["install_minutes"])]
		var action := Action.new(label if problem == "" else "%s: %s" % [row["name"], problem.to_lower()], _fit_upgrade.bind(box.part), problem == "")
		action.task_name = "Fit the %s to the %s" % [_kit_name(row), display_name]
		lines.append(action)
	if lines.is_empty():
		return Action.info("Upgrades (none fitted: buy kits at the PC)")
	return Action.submenu("Upgrades", lines)


## A kit's name as it reads mid-sentence: "auto bed levelling kit", but a
## multicolour unit keeps the capitals of its brand, "Zippy ColourHub Lite".
func _kit_name(row: Dictionary) -> String:
	return row["name"] if row.has("multicolour") else String(row["name"]).to_lower()


## Why a kit can't go on this printer right now, or "" if it can.
func upgrade_problem(upgrade: StringName) -> String:
	var problem := mods.problem(upgrade, spec)
	if problem == "" and Game.data.upgrades[upgrade].has("multicolour") and spool != null:
		return "Unload the filament first"
	return problem


## "84%", "24%, worn" or "worn out"
func health_label(slot: StringName) -> String:
	if wear.is_broken(slot):
		return "worn out"
	var percent := maxi(roundi(wear.health[slot] * 100.0), 1)
	return "%d%%, worn" % percent if wear.is_worn(slot) else "%d%%" % percent


## The task of printing a design at a preset, as set up in the print dialog.
## `slots` are the spools to print it from, one per colour; left empty, the
## printer picks (default_slots).
func print_action(product: StringName, p_preset: StringName, slots: Array[int] = []) -> Action:
	return Action.new("Print %s" % Game.product_name(product), _start.bind(product, p_preset, slots),
		print_problem(product, p_preset, slots) == "")


## The slots to print a design from when the player hasn't said: a spool for
## each of its colours if the unit has them loaded in one filament the design
## and the printer can take, or else one spool for the lot.
func default_slots(product: StringName) -> Array[int]:
	var usable: Array[String] = []
	for loaded in spools:
		var suits := loaded != null and FilamentRules.suits(Game.data.products[product], Game.data.filaments[loaded.material]) \
			and FilamentRules.problem(mods.apply(spec), Game.data.filaments[loaded.material]) == ""
		usable.append(String(loaded.material) if suits else "")
	var picked := Multicolour.pick_slots(usable, Multicolour.colours_of(Game.data.products[product]))
	# With nothing suitable, offer what is there, so the player is told why not.
	if picked.is_empty() and spool != null:
		picked.append(spools.find(spool))
	return picked


## How a design would print here from the spools in `slots`, one per colour (or
## the default ones): { slots, material, swaps, purged, grams, minutes }. `grams`
## is what each slot gives up, `purged` the part of that wasted on colour
## changes. {} if any of the slots has no spool in it.
func print_plan(product: StringName, p_preset: StringName, slots: Array[int] = []) -> Dictionary:
	if slots.is_empty():
		slots = default_slots(product)
	if slots.is_empty() or slots.any(func(slot: int) -> bool: return slot < 0 or slot >= spools.size() or spools[slot] == null):
		return {}
	var row: Dictionary = Game.data.products[product]
	var rules: Dictionary = Game.data.settings["multicolour"]
	var material := spools[slots[0]].material
	var changes := Multicolour.swaps(row, slots.size())
	var lightness: Array[float] = []
	for slot in slots:
		lightness.append(Palette.colour(spools[slot].colour).get_luminance())
	var purged := Multicolour.purge_grams(mods.unit(), changes, lightness, rules)
	return {
		"slots": slots, "material": material, "swaps": changes, "purged": purged,
		"grams": Multicolour.grams_by_colour(Game.print_grams(product, p_preset), slots.size(), purged, rules),
		"minutes": _base_minutes(product, p_preset, float(Game.data.filaments[material]["speed_multiplier"]))
			+ Multicolour.swap_minutes(mods.unit(), changes),
	}


## Why a design can't be printed here right now, or "" if it can.
func print_problem(product: StringName, p_preset: StringName, slots: Array[int] = []) -> String:
	if spool == null:
		return "No filament loaded"
	if status != Status.IDLE:
		return "The printer is busy"
	for slot in wear.broken():
		return "The %s is worn out. Fit a new one first" % String(wear.part(slot)["slot_name"]).to_lower()
	var row: Dictionary = Game.data.products[product]
	if not PrintRisk.fits(spec, row):
		return "Too big for this printer"
	var plan := print_plan(product, p_preset, slots)
	if plan.is_empty():
		return "Pick a loaded spool for each colour"
	var used: Array[int] = plan["slots"]
	if used.size() != 1 and used.size() != Multicolour.colours_of(row):
		return "Pick a spool for each of its %d colours" % Multicolour.colours_of(row)
	var filament: Dictionary = Game.data.filaments[plan["material"]]
	if not FilamentRules.suits(row, filament):
		return "This design can't be printed in %s" % filament["name"]
	if FilamentRules.problem(mods.apply(spec), filament) != "":
		return FilamentRules.problem(mods.apply(spec), filament)
	for index in used.size():
		var loaded := spools[used[index]]
		if used.find(used[index]) != index:
			return "Each colour needs a spool of its own"
		if loaded.material != plan["material"]:
			return "Every colour has to be the same kind of filament"
		if loaded.grams < float(plan["grams"][index]):
			return "Not enough filament on the spool" if used.size() == 1 else "Not enough %s left" % loaded.title()
	return ""


## Game minutes this printer takes to print a design at a preset, in the
## filament that is loaded (some print slower than others), colour changes included.
func print_minutes(product: StringName, p_preset: StringName, slots: Array[int] = []) -> float:
	var plan := print_plan(product, p_preset, slots)
	return float(plan["minutes"]) if not plan.is_empty() else _base_minutes(product, p_preset, 1.0)


func _base_minutes(product: StringName, p_preset: StringName, filament_speed: float) -> float:
	return (float(Game.data.products[product]["print_minutes"]) * float(Game.data.presets[p_preset]["time_multiplier"])
		* mods.time_multiplier() / float(spec["speed_multiplier"]) / filament_speed)


## Puts a spool in a slot: the first free one unless told which.
func load_spool(p_spool: Spool, slot := -1) -> void:
	if slot < 0:
		slot = free_slot()
	spools[slot] = p_spool
	p_spool.sheltered = bool(mods.unit().get("keeps_dry", false))
	Interactable.attach(p_spool, _mounts[slot])
	Game.changed.emit()


func unload_spool(slot: int) -> Spool:
	var removed := spools[slot]
	spools[slot] = null
	removed.sheltered = false
	Game.changed.emit()
	return removed


func start_print(product: StringName, p_preset: StringName, slots: Array[int] = []) -> void:
	var plan := print_plan(product, p_preset, slots)
	preset = p_preset
	_slots_used.assign(plan["slots"])
	_grams_used.assign(plan["grams"])
	_minutes = plan["minutes"]
	var colours: Array[StringName] = []
	var moisture := 0.0
	for index in _slots_used.size():
		var loaded := spools[_slots_used[index]]
		loaded.grams -= _grams_used[index]
		colours.append(loaded.colour)
		moisture = maxf(moisture, loaded.moisture)
	var material: StringName = plan["material"]
	item = PrintedItem.create(product, colours, preset, material)
	Interactable.attach(item, _plate)
	item.scale.y = 0.02
	job = PrintJob.new(GameClock.to_seconds(_minutes))
	var fate := Game.roll_print(spec, preset, material, product, wear, mods, moisture, int(plan["swaps"]))
	if not fate.is_empty():
		job.fail(fate["failure"], fate["at"])
	# A part that runs out before anything else goes wrong stops the print there.
	var breakdown := wear.breaks_during(_minutes / 60.0, Game.data.presets[preset], Game.data.filaments[material])
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
	var minutes_run := _minutes * job.progress
	Game.charge_electricity(spec["power_watts"], minutes_run, title)
	wear.apply(minutes_run / 60.0, Game.data.presets[preset], Game.data.filaments[item.material])
	for slot: String in job.failure.get("damages", {}):
		wear.damage(StringName(slot), float(job.failure["damages"][slot]))
	if not job.ruined:
		# The first print of an own design is its test, and a faulty design spoils every print.
		var news := Game.studio.printed(item.product)
		if Game.studio.is_faulty(item.product) and job.failure.is_empty():
			job.failure = Game.data.failures["design_fault"]
		elif news == "sound":
			Game.notify("The test print passed: your %s design is sound" % title, &"good")
	if job.ruined:
		# Filament the print never got to is still on the spools.
		for index in _slots_used.size():
			spools[_slots_used[index]].grams += _grams_used[index] * (1.0 - job.progress)
		scrap = FailedPrint.create(item, job.failure)
		Interactable.attach(scrap, _plate)
		item = null
		status = Status.FAILED
		Game.notify("%s: %s. %s" % [display_name, job.failure["name"], job.failure["player_text"]], &"bad")
	elif not job.failure.is_empty():
		item.spoil(job.failure)
		status = Status.DONE
		Game.notify("%s finished %s, but: %s. %s" % [
			display_name, title, String(job.failure["name"]).to_lower(), job.failure["player_text"]], &"bad")
	else:
		status = Status.DONE
		Game.notify("%s finished printing: %s" % [display_name, title], &"good")
	Game.changed.emit()


# Tasks. Each checks it still makes sense when its turn comes, because the
# world may have changed while it sat in the queue.

func _load(agent: Agent, material: StringName, colour: StringName) -> void:
	var rack := _rack()
	if free_slot() < 0 or not rack.has(material, colour) or FilamentRules.problem(mods.apply(spec), Game.data.filaments[material]) != "":
		agent.say("Can't load that filament right now")
		return
	await agent.go_to(rack)
	await agent.reach(func() -> void: agent.carry(rack.take(material, colour)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: load_spool(agent.release() as Spool))


func _unload(agent: Agent, slot: int) -> void:
	if slot < 0 or slot >= spools.size() or spools[slot] == null or status == Status.PRINTING:
		agent.say("Can't unload the printer right now")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void: agent.carry(unload_spool(slot)))
	var removed := agent.carried as Spool
	if removed.is_empty():
		await agent.walk_to(get_tree().get_first_node_in_group(&"bin").global_position)
		await agent.reach(func() -> void: agent.release().queue_free())
		agent.say("Binned an empty spool")
		return
	var rack := _rack()
	await agent.go_to(rack)
	await agent.reach(func() -> void: rack.store(agent.release() as Spool))


func _start(agent: Agent, product: StringName, p_preset: StringName, slots: Array[int]) -> void:
	if print_problem(product, p_preset, slots) != "":
		agent.say("The printer isn't ready to print that")
		return
	await agent.go_to(self)
	await agent.reach(start_print.bind(product, p_preset, slots))


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


func _replace(agent: Agent, slot: StringName, part: StringName) -> void:
	var shelf := _shelf()
	var slot_name := String(wear.part(slot)["slot_name"]).to_lower()
	if status == Status.PRINTING or shelf.spare_count(part) == 0:
		agent.say("Can't change the %s right now" % slot_name)
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void: agent.carry(shelf.take_spare(part)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.work(float(Game.data.parts[part]["replace_minutes"]))
	await agent.reach(func() -> void:
		agent.release().queue_free()
		wear.replace(slot, part)
		Game.changed.emit())
	agent.say("Fitted a new %s" % slot_name)


func _fit_upgrade(agent: Agent, upgrade: StringName) -> void:
	var shelf := _shelf()
	if status == Status.PRINTING or shelf.spare_count(upgrade) == 0 or upgrade_problem(upgrade) != "":
		agent.say("Can't fit that to the %s right now" % display_name)
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void: agent.carry(shelf.take_spare(upgrade)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.work(float(Game.data.upgrades[upgrade]["install_minutes"]))
	await agent.reach(func() -> void:
		agent.release().queue_free()
		mods.fit(upgrade)
		wear.upgrade_multiplier = mods.wear_multiplier()
		_mount_unit()
		Game.changed.emit())
	agent.say("Fitted the %s" % _kit_name(Game.data.upgrades[upgrade]))


## Sets up the multicolour unit among the upgrades, if there is one and it
## isn't up already: its model on the printer, a slot for each spool in place of
## the printer's own mount, and its wear parts alongside the printer's.
func _mount_unit() -> void:
	var unit := mods.unit()
	if unit.is_empty() or _unit_model != null:
		return
	_unit_model = (load(GameData.UNIT_MODEL % unit["model"]) as PackedScene).instantiate()
	var mount: Node3D = find_child("unit_mount", true, false)
	(mount if mount != null else _spool_mount).add_child(_unit_model)
	_mounts.assign(_unit_model.find_children("spool_slot_*", "Node3D", true, false))
	_mounts.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name).naturalnocasecmp_to(b.name) < 0)
	_mounts.resize(mini(int(unit["slots"]), _mounts.size()))
	spools.clear()
	spools.resize(_mounts.size())
	for part_id: String in unit["parts"]:
		var slot := StringName(Game.data.parts[part_id]["slot"])
		if not wear.fitted.has(slot):
			wear.replace(slot, StringName(part_id))
	# The unit is part of what gets clicked.
	remove_collider()
	_build_collider.call_deferred()


func _rack() -> FilamentRack:
	return get_tree().get_first_node_in_group(&"filament_rack")


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")


func save() -> Dictionary:
	var state := {"id": spec["id"], "status": status, "preset": preset, "grams": _grams_used, "slots": _slots_used,
		"minutes": _minutes, "wear": wear.save(), "mods": mods.save()}
	# One entry per slot, null where it is empty.
	state["spools"] = spools.map(func(loaded: Spool) -> Variant: return loaded.save() if loaded != null else null)
	if job != null:
		state["job"] = job.save()
	if item != null:
		state["item"] = item.save()
	if scrap != null:
		state["scrap"] = {"failure": scrap.failure, "item": scrap.item.save()}
	return state


## Puts a newly installed printer back as it was saved, mid-print included.
## A print of a design the game no longer has is dropped, leaving it idle.
func restore(state: Dictionary) -> void:
	if state.has("mods"):
		mods.restore(state["mods"])
		wear.upgrade_multiplier = mods.wear_multiplier()
		_mount_unit()
	wear.restore(state["wear"])
	# Saves from before multicolour units hold the one spool, and one figure for its grams.
	var saved_spools: Array = state.get("spools", [state.get("spool")])
	for slot in mini(saved_spools.size(), spools.size()):
		if saved_spools[slot] is Dictionary:
			load_spool(Spool.restored(saved_spools[slot]), slot)
	preset = StringName(state["preset"]) if Game.data.presets.has(state["preset"]) else preset
	_slots_used.clear()
	_grams_used.clear()
	for slot: Variant in state.get("slots", [0]):
		_slots_used.append(int(slot))
	for grams: Variant in (state["grams"] if state["grams"] is Array else [state["grams"]]):
		_grams_used.append(float(grams))
	var saved_status := int(state["status"]) as Status
	var on_plate: PrintedItem = PrintedItem.restored(state["scrap"]["item"] if state.has("scrap") else state.get("item", {"product": "", "preset": ""}))
	var spools_gone := _slots_used.size() != _grams_used.size() or _slots_used.any(
		func(slot: int) -> bool: return slot < 0 or slot >= spools.size() or spools[slot] == null)
	if saved_status == Status.IDLE or on_plate == null or not state.has("job") or spools_gone:
		return
	_minutes = float(state.get("minutes", 0.0))
	if _minutes <= 0.0:
		_minutes = print_minutes(on_plate.product, preset, _slots_used)
	job = PrintJob.restored(state["job"])
	Interactable.attach(on_plate, _plate)
	on_plate.scale.y = maxf(job.progress, 0.02)
	if saved_status == Status.FAILED:
		scrap = FailedPrint.create(on_plate, state["scrap"]["failure"])
		Interactable.attach(scrap, _plate)
	else:
		item = on_plate
	status = saved_status
