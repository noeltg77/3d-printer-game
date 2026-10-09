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
## A second unit of the same kind links to the first, stacked on it, for more slots.
##
## A print can be a batch: several copies of the design on the plate at once.
## `item` is the first and `extras` the rest. They are shrunk to fit the plate
## while they print, share one fate, and are collected together.
##
## The printer remembers its last job, so it can be set going again in one
## click. With `repeat` on, a print operator on the staff does that unasked.
##
## An auto-eject plate (an upgrade with an `auto_eject` block) clears a good
## print off the plate by itself: onto the conveyor if the building has one
## and there is shelf space, or else into the tray beside the printer, which
## somebody has to empty. Freed like that, a printer with `repeat` on starts
## its last job again with nobody near it.

enum Status { IDLE, PRINTING, DONE, FAILED }

const MODEL_PATH := "res://assets/models/printers/%s.glb"
## How far a core XY printer's bed rises from rest to meet the nozzle, before
## sinking again as the print grows.
const CORE_XY_LIFT := 0.14
## How far the gantry drops from its parked height to put the nozzle on the plate.
const GANTRY_DROP := 0.175
## Width of the plate a batch is laid out on, in metres, on a model that doesn't
## say how big its own is (with a `plate_corner` marker), and how much of each
## copy's share of it the copy may fill.
const PLATE_SIZE := 0.24
const BATCH_FILL := 0.88
## Where the auto-eject tray sits beside the printer, how small prints are
## drawn in it, and how many of them show.
const TRAY_OFFSET := Vector3(0.36, 0.0, 0.1)
const TRAY_SCALE := 0.38
const TRAY_SHOWN := 6
## Game seconds between a self-running printer's looks at what to do next.
const AUTO_SECONDS := 1.0

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
## The other copies on the plate, when the print is a batch.
var extras: Array[PrintedItem] = []
## True if staff should start the last job again whenever the printer is free.
var repeat := false
## What a ruined print left on the plate, while status is FAILED.
var scrap: FailedPrint = null
## Preset of the print on the plate.
var preset: StringName = &"standard"
## The state of this printer's wear parts.
var wear: PrinterWear
## The upgrades fitted to it.
var mods: PrinterMods

## Prints the auto-eject plate has thrown into the tray, oldest first.
var tray: Array[PrintedItem] = []
var _tray_floor: Node3D = null
var _auto_wait := 0.0
## The last job started: { product, preset, slots, copies }. Empty before the first.
var _last := {}
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
## The model of each multicolour unit fitted, the first at the bottom of the stack.
var _unit_models: Array[Node3D] = []
## How far the copies on the plate are shrunk so they all fit. 1 for a single print.
var _plate_scale := 1.0
var _plate: Node3D
## Width of this printer's plate, in metres. The head and bed move to suit.
var _plate_size := PLATE_SIZE
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
	var corner: Node3D = find_child("plate_corner", true, false)
	if corner != null:
		var reach := (corner.position - _plate.position).abs()
		_plate_size = 2.0 * minf(reach.x, reach.z)
	_bed = find_child("bed", true, false)
	_gantry = find_child("gantry", true, false)
	_toolhead = find_child("toolhead", true, false)
	_bed_rest = _bed.position
	_gantry_rest = _gantry.position
	_toolhead_rest = _toolhead.position
	_mount_tray()


func _process(delta: float) -> void:
	if _tray_floor != null and status != Status.PRINTING and status != Status.FAILED:
		_auto_wait -= delta
		if _auto_wait <= 0.0:
			_auto_wait = AUTO_SECONDS
			_run_itself()
	var bed_target := _bed_rest
	var gantry_target := _gantry_rest
	var toolhead_target := _toolhead_rest
	if status == Status.PRINTING:
		_time += delta
		# The item grows from the plate while the nozzle rides just above it.
		var ended := job.advance(delta)
		_grow(job.progress)
		var built := item.height * _plate_scale * job.progress
		var reach := _plate_size / PLATE_SIZE
		if spec["motion"] == "resin_lift":
			# The arm lifts the build plate clear as the print grows in the vat.
			gantry_target.y += built
		elif spec["motion"] == "core_xy":
			# The head stays up and darts about on its bar; the bed sinks as the print grows.
			toolhead_target.x += (sin(_time * 5.0) * 0.09 - 0.05) * reach
			bed_target.y += CORE_XY_LIFT - built
			gantry_target.z += (sin(_time * 3.7) * 0.07 + 0.03) * reach
		else:
			toolhead_target.x += (sin(_time * 5.0) * 0.09 - 0.05) * reach
			gantry_target.y += built - GANTRY_DROP
			bed_target.z += sin(_time * 3.1) * 0.05 * reach
		if ended:
			_end_print()
	var weight := 1.0 - exp(-10.0 * delta)
	_bed.position = _bed.position.lerp(bed_target, weight)
	_gantry.position = _gantry.position.lerp(gantry_target, weight)
	_toolhead.position = _toolhead.position.lerp(toolhead_target, weight)


func get_actions(_agent: Agent) -> Array[Action]:
	var actions := _tray_actions()
	actions.append_array(_status_actions())
	return actions


## Emptying the tray of an auto-eject plate, when there is anything in it.
func _tray_actions() -> Array[Action]:
	var actions: Array[Action] = []
	if tray.is_empty():
		return actions
	var label := "Empty the tray: %d print%s" % [tray.size(), "" if tray.size() == 1 else "s"]
	if not _shelf().has_space():
		actions.append(Action.info("%s (shelving is full)" % label))
		return actions
	var empty := Action.new(label, _empty_tray).for_duty(&"collect")
	empty.task_name = "Empty the tray on the %s" % display_name
	actions.append(empty)
	return actions


## What the printer offers for the state it is in.
func _status_actions() -> Array[Action]:
	match status:
		Status.PRINTING:
			var left := GameClock.duration_label((job.duration - job.elapsed) * GameClock.MINUTES_PER_SECOND)
			return [Action.info("Printing %s: %d%%, %s left" % [_batch_title(Game.product_name(item.product)), roundi(job.progress * 100.0), left])]
		Status.DONE:
			if _shelf().free_slots() >= copies():
				var wash := post_minutes()
				var label := "Collect %s" % _batch_title(item.describe())
				if wash > 0.0:
					label = "Wash, cure and collect %s (%s)" % [_batch_title(item.describe()), GameClock.duration_label(wash)]
				var collect := Action.new(label, _collect).for_duty(&"collect")
				collect.task_name = "Collect %s" % _batch_title(item.describe())
				return [collect]
			return [Action.info("Collect print (shelving is full)" if copies() == 1 else "Collect prints (the shelving needs %d free spaces)" % copies())]
		Status.FAILED:
			var failure := scrap.failure
			var fix := Action.new("%s (%s)" % [failure["fix"], GameClock.duration_label(failure["clear_minutes"])], _clear).for_duty(&"clear")
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
		actions.append_array(_again_actions())
		actions.append(_unload_menu())
	actions.append(_parts_menu())
	actions.append(_upgrades_menu())
	return actions


## How many copies are on the plate.
func copies() -> int:
	return 0 if item == null else 1 + extras.size()


## "Coasters (x4)", or "3 x Coasters (x4)" for a batch.
func _batch_title(title: String) -> String:
	return title if copies() <= 1 else "%d x %s" % [copies(), title]


## The most copies of a design this printer can print at once.
func max_copies(product: StringName) -> int:
	var toggle: Dictionary = Game.data.toggles["batch_plate"]
	return clampi(PrintRisk.copies(spec, Game.data.products[product], float(toggle["gap_mm"])), 1, int(toggle["max_copies"]))


## True if the printer clears its own plate: an auto-eject plate is fitted, or
## it is built that way (a belt printer).
func has_auto_eject() -> bool:
	return _tray_floor != null


## How many prints the auto-eject tray holds.
func tray_capacity() -> int:
	return int(mods.block("auto_eject").get("tray", spec.get("auto_eject_tray", 0)))


## Game minutes of finishing the print on the plate needs before it is fit to
## shelve: washing and curing, for resin. Nothing for filament.
func post_minutes() -> float:
	return float(Game.data.filaments[item.material].get("post_minutes", 0)) if item != null else 0.0


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


## Starting the last job again, and, with a print operator on the staff, the
## switch that has them do it whenever the printer is free.
func _again_actions() -> Array[Action]:
	var actions: Array[Action] = []
	if _last.is_empty() or not Game.printable_designs().has(_last["product"]):
		return actions
	var count: int = _last["copies"]
	var title := Game.product_name(_last["product"])
	var label := "Print %s again" % (title if count == 1 else "%d x %s" % [count, title])
	var problem := print_problem(_last["product"], _last["preset"], _last["slots"], count)
	var again := Action.new(label if problem == "" else "%s: %s" % [label, problem.to_lower()],
		_start.bind(_last["product"], _last["preset"], _last["slots"], count), problem == "")
	again.task_name = "Print %s on the %s" % [title, display_name]
	if repeat:
		again.for_duty(&"reprint")
	actions.append(again)
	# Someone has to do the restarting: a print operator, or the printer's own auto-eject plate.
	if Game.staff.has_duty("reprint") or has_auto_eject():
		var switch := Action.new("Keep this job going: %s" % ("on" if repeat else "off"), func(_agent: Agent) -> void:
			repeat = not repeat
			Game.changed.emit())
		switch.immediate = true
		actions.append(switch)
	return actions


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
	if Game.printable_designs().is_empty():
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
		var units := mods.unit_count() if Game.data.upgrades[upgrade].has("multicolour") else 1
		lines.append(Action.info("Fitted: %s" % Game.data.upgrades[upgrade]["name"] + ("" if units == 1 else " x %d, linked" % units)))
	for box in _shelf().spares():
		# A kit for the building (the conveyor) isn't a printer's to fit.
		if not Game.data.upgrades.has(box.part) or Game.data.upgrades[box.part].has("fixture"):
			continue
		var row: Dictionary = Game.data.upgrades[box.part]
		var problem := upgrade_problem(box.part)
		var label := "%s %s (%s)" % ["Link another" if mods.has(box.part) else "Fit", _kit_name(row), GameClock.duration_label(row["install_minutes"])]
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
	# The first unit takes the place of the printer's own spool mount. One linked later only adds slots.
	if problem == "" and Game.data.upgrades[upgrade].has("multicolour") and not has_unit() and spool != null:
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
## printer picks (default_slots). `count` is how many copies to print at once.
func print_action(product: StringName, p_preset: StringName, slots: Array[int] = [], count := 1) -> Action:
	var title := Game.product_name(product)
	return Action.new("Print %s" % (title if count == 1 else "%d x %s" % [count, title]), _start.bind(product, p_preset, slots, count),
		print_problem(product, p_preset, slots, count) == "")


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
##
## `count` copies at once take that many times the filament and, past the
## first, a little less than that many times as long. The colour changes are
## the same however many there are, which is what makes a batch waste less.
func print_plan(product: StringName, p_preset: StringName, slots: Array[int] = [], count := 1) -> Dictionary:
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
		"grams": Multicolour.grams_by_colour(Game.print_grams(product, p_preset) * count, slots.size(), purged, rules),
		"minutes": _base_minutes(product, p_preset, float(Game.data.filaments[material]["speed_multiplier"])) * count
			* (float(Game.data.toggles["batch_plate"]["time_multiplier"]) if count > 1 else 1.0)
			+ Multicolour.swap_minutes(mods.unit(), changes),
	}


## Why a design can't be printed here right now, or "" if it can.
func print_problem(product: StringName, p_preset: StringName, slots: Array[int] = [], count := 1) -> String:
	if spool == null:
		return "No filament loaded"
	if status != Status.IDLE:
		return "The printer is busy"
	for slot in wear.broken():
		return "The %s is worn out. Fit a new one first" % String(wear.part(slot)["slot_name"]).to_lower()
	var row: Dictionary = Game.data.products[product]
	if not PrintRisk.fits(spec, row):
		return "Too big for this printer"
	if count > max_copies(product):
		return "Only %d fit on the plate at once" % max_copies(product)
	var plan := print_plan(product, p_preset, slots, count)
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
func print_minutes(product: StringName, p_preset: StringName, slots: Array[int] = [], count := 1) -> float:
	var plan := print_plan(product, p_preset, slots, count)
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


func start_print(product: StringName, p_preset: StringName, slots: Array[int] = [], count := 1) -> void:
	var plan := print_plan(product, p_preset, slots, count)
	preset = p_preset
	_last = {"product": product, "preset": p_preset, "slots": (plan["slots"] as Array[int]).duplicate(), "copies": count}
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
	extras.clear()
	for copy in count - 1:
		extras.append(PrintedItem.create(product, colours, preset, material))
	_lay_out()
	_grow(0.0)
	job = PrintJob.new(GameClock.to_seconds(_minutes))
	var fate := Game.roll_print(spec, preset, material, product, wear, mods, moisture, int(plan["swaps"]))
	if not fate.is_empty():
		job.fail(fate["failure"], fate["at"])
	# A part that runs out before anything else goes wrong stops the print there.
	var breakdown := wear.breaks_during(_minutes / 60.0, Game.data.presets[preset], Game.data.filaments[material])
	if not breakdown.is_empty() and breakdown["at"] < job.stop_at:
		job.fail(_breakdown(breakdown["slot"]), breakdown["at"])
	status = Status.PRINTING


## Hands over everything on the plate, leaving the printer free.
func take_items() -> Array[PrintedItem]:
	var taken := _on_plate()
	item = null
	extras.clear()
	job = null
	status = Status.IDLE
	return taken


## Every copy on the plate, the first one first.
func _on_plate() -> Array[PrintedItem]:
	var found: Array[PrintedItem] = [item]
	found.append_array(extras)
	return found


## Puts the copies on the plate. One sits in the middle at full size; a batch
## goes in a grid, shrunk as far as it takes for them all to fit.
func _lay_out() -> void:
	var on_plate := _on_plate()
	var count := on_plate.size()
	var columns := 1
	_plate_scale = 1.0
	if count > 1:
		var size := item.footprint.max(Vector2.ONE * 0.01)
		var best := 0.0
		for across in range(1, count + 1):
			var deep := ceili(float(count) / across)
			var fit := minf(_plate_size / across / size.x, _plate_size / deep / size.y) * BATCH_FILL
			if fit > best:
				best = fit
				columns = across
		_plate_scale = minf(best, 1.0)
	var rows := ceili(float(count) / columns)
	for index in count:
		Interactable.attach(on_plate[index], _plate)
		on_plate[index].position = Vector3(((index % columns) - (columns - 1) / 2.0) * _plate_size / columns, 0.0,
			(floori(float(index) / columns) - (rows - 1) / 2.0) * _plate_size / rows) if count > 1 else Vector3.ZERO


## Shows every copy at the height the print has reached (0 to 1).
func _grow(progress: float) -> void:
	for copy in _on_plate():
		copy.scale = Vector3(_plate_scale, _plate_scale * maxf(progress, 0.02), _plate_scale)


## The power has gone: a print in progress stops where it is and is lost.
func power_cut() -> void:
	if status == Status.PRINTING and not job.is_finished():
		job.fail(Game.data.failures["power_cut"], job.progress)


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
	var title := _batch_title(Game.product_name(item.product))
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
		# A batch fails as one: the mess is shown around the first copy.
		for copy in extras:
			copy.queue_free()
		extras.clear()
		scrap = FailedPrint.create(item, job.failure)
		Interactable.attach(scrap, _plate)
		item = null
		status = Status.FAILED
		Game.notify("%s: %s. %s" % [display_name, job.failure["name"], job.failure["player_text"]], &"bad")
	elif not job.failure.is_empty():
		for copy in _on_plate():
			copy.spoil(job.failure)
		status = Status.DONE
		Game.notify("%s finished %s, but: %s. %s" % [
			display_name, title, String(job.failure["name"]).to_lower(), job.failure["player_text"]], &"bad")
	else:
		status = Status.DONE
		# A printer that clears its own plate would otherwise announce every print it makes.
		if not has_auto_eject():
			Game.notify("%s finished printing: %s" % [display_name, title], &"good")
	_eject()
	Game.changed.emit()


## What a printer with an auto-eject plate does when left alone: clears a
## finished print off the plate, and starts the last job again if told to.
func _run_itself() -> void:
	_eject()
	if status != Status.IDLE or not repeat or _last.is_empty() or not Game.printable_designs().has(_last["product"]):
		return
	if print_problem(_last["product"], _last["preset"], _last["slots"], _last["copies"]) == "":
		start_print(_last["product"], _last["preset"], _last["slots"], _last["copies"])
		Game.changed.emit()


## Clears a finished print off the plate if there is an auto-eject plate and
## somewhere for it to go: the conveyor, or room in the tray. Otherwise it
## stays where it is, to be collected by hand.
func _eject() -> void:
	if status != Status.DONE or not has_auto_eject():
		return
	var count := copies()
	var conveyor: Conveyor = get_tree().get_first_node_in_group(&"conveyor")
	if conveyor != null and conveyor.can_take(count):
		conveyor.send(take_items(), _plate.global_position)
	elif tray.size() + count <= tray_capacity():
		for copy in take_items():
			_into_tray(copy)
	else:
		return
	Game.changed.emit()


func _into_tray(copy: PrintedItem) -> void:
	tray.append(copy)
	Interactable.attach(copy, _tray_floor)
	_arrange_tray()


## Piles what is in the tray, shrunk to fit, with only the top few drawn.
func _arrange_tray() -> void:
	for index in tray.size():
		var copy := tray[index]
		copy.visible = index < TRAY_SHOWN
		copy.scale = Vector3.ONE * TRAY_SCALE
		copy.position = Vector3((index % 2 - 0.5) * 0.09, floori(index / 2.0) * 0.025, (index % 3 - 1) * 0.06)


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


func _start(agent: Agent, product: StringName, p_preset: StringName, slots: Array[int], count: int) -> void:
	if print_problem(product, p_preset, slots, count) != "":
		agent.say("The printer isn't ready to print that")
		return
	await agent.go_to(self)
	await agent.reach(start_print.bind(product, p_preset, slots, count))


## Not a task: opens the print set-up card, which queues the print itself.
func _open_print_dialog(_agent: Agent) -> void:
	(get_tree().get_first_node_in_group(&"print_dialog") as PrintDialog).open(self)


func _collect(agent: Agent) -> void:
	var shelf := _shelf()
	if status != Status.DONE or shelf.free_slots() < copies():
		agent.say("Nothing to collect" if status != Status.DONE else "Not enough room on the shelving")
		return
	await agent.go_to(self)
	if post_minutes() > 0.0:
		await agent.work(post_minutes())
	await agent.reach(func() -> void: _pick_up(agent, take_items()))
	await _shelve(agent, shelf)


func _empty_tray(agent: Agent) -> void:
	var shelf := _shelf()
	if tray.is_empty() or not shelf.has_space():
		agent.say("Nothing to take from the tray" if tray.is_empty() else "Not enough room on the shelving")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void:
		# As many as there is shelf space for; the rest stay in the tray.
		var taken: Array[PrintedItem] = []
		for index in mini(tray.size(), shelf.free_slots()):
			taken.append(tray.pop_front())
		for copy in taken:
			copy.scale = Vector3.ONE
			copy.visible = true
		_arrange_tray()
		_pick_up(agent, taken)
		Game.changed.emit())
	await _shelve(agent, shelf)


## Gives the character several prints to carry as one: the first in hand and
## the rest riding along out of sight, inside it.
func _pick_up(agent: Agent, items: Array[PrintedItem]) -> void:
	if items.is_empty():
		return
	agent.carry(items[0])
	for copy: PrintedItem in items.slice(1):
		Interactable.attach(copy, items[0])
		copy.visible = false


## Takes what _pick_up handed over to the shelving and puts each print away.
func _shelve(agent: Agent, shelf: StorageShelf) -> void:
	if agent.carried == null:
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void:
		var first := agent.release()
		for child in first.get_children():
			var copy := child as PrintedItem
			if copy != null:
				copy.visible = true
				shelf.store(copy)
		shelf.store(first))


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
		_mount_tray()
		Game.changed.emit())
	agent.say("Fitted the %s" % _kit_name(Game.data.upgrades[upgrade]))


## Puts the auto-eject tray beside the printer, if the upgrades include the
## plate and it isn't there already.
func _mount_tray() -> void:
	if _tray_floor != null or (mods.block("auto_eject").is_empty() and not spec.get("auto_eject", false)):
		return
	var model: Node3D = (load(GameData.TRAY_MODEL) as PackedScene).instantiate()
	add_child(model)
	model.position = TRAY_OFFSET
	_tray_floor = model.find_child("tray", true, false)
	remove_collider()
	_build_collider.call_deferred()


## Sets up the multicolour units among the upgrades that aren't up already.
## The first goes on the printer's `unit_mount` and takes over from the
## printer's own spool mount, which has to be empty; each one linked after it
## stacks on the `link_mount` of the one below and adds its slots. The units'
## wear parts go in alongside the printer's.
func _mount_unit() -> void:
	var unit := mods.unit()
	if unit.is_empty() or _unit_models.size() >= mods.unit_count():
		return
	while _unit_models.size() < mods.unit_count():
		var model: Node3D = (load(GameData.UNIT_MODEL % unit["model"]) as PackedScene).instantiate()
		var mount: Node3D = find_child("unit_mount", true, false) if _unit_models.is_empty() \
			else _unit_models[-1].find_child("link_mount", true, false)
		(mount if mount != null else _spool_mount).add_child(model)
		var slots: Array[Node3D] = []
		slots.assign(model.find_children("spool_slot_*", "Node3D", true, false))
		slots.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name).naturalnocasecmp_to(b.name) < 0)
		slots.resize(mini(int(unit["slots"]), slots.size()))
		if _unit_models.is_empty():
			_mounts.clear()
			spools.clear()
		_mounts.append_array(slots)
		spools.resize(_mounts.size())
		_unit_models.append(model)
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
		"minutes": _minutes, "wear": wear.save(), "mods": mods.save(), "repeat": repeat, "last": _last}
	# One entry per slot, null where it is empty.
	state["spools"] = spools.map(func(loaded: Spool) -> Variant: return loaded.save() if loaded != null else null)
	if job != null:
		state["job"] = job.save()
	if item != null:
		state["item"] = item.save()
		state["copies"] = copies()
	if scrap != null:
		state["scrap"] = {"failure": scrap.failure, "item": scrap.item.save()}
	if not tray.is_empty():
		state["tray"] = tray.map(func(copy: PrintedItem) -> Dictionary: return copy.save())
	return state


## Puts a newly installed printer back as it was saved, mid-print included.
## A print of a design the game no longer has is dropped, leaving it idle.
func restore(state: Dictionary) -> void:
	if state.has("mods"):
		mods.restore(state["mods"])
		wear.upgrade_multiplier = mods.wear_multiplier()
		_mount_unit()
		_mount_tray()
	wear.restore(state["wear"])
	if _tray_floor != null:
		for entry: Dictionary in state.get("tray", []):
			var thrown := PrintedItem.restored(entry)
			if thrown != null:
				_into_tray(thrown)
	# Saves from before multicolour units hold the one spool, and one figure for its grams.
	var saved_spools: Array = state.get("spools", [state.get("spool")])
	for slot in mini(saved_spools.size(), spools.size()):
		if saved_spools[slot] is Dictionary:
			load_spool(Spool.restored(saved_spools[slot]), slot)
	preset = StringName(state["preset"]) if Game.data.presets.has(state["preset"]) else preset
	repeat = bool(state.get("repeat", false))
	var last: Dictionary = state.get("last", {})
	if Game.data.products.has(last.get("product", "")) and Game.data.presets.has(last.get("preset", "")):
		var last_slots: Array[int] = []
		for slot: Variant in last["slots"]:
			last_slots.append(int(slot))
		_last = {"product": StringName(last["product"]), "preset": StringName(last["preset"]), "slots": last_slots, "copies": int(last["copies"])}
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
	if saved_status == Status.FAILED:
		Interactable.attach(on_plate, _plate)
		on_plate.scale.y = maxf(job.progress, 0.02)
		scrap = FailedPrint.create(on_plate, state["scrap"]["failure"])
		Interactable.attach(scrap, _plate)
	else:
		item = on_plate
		for copy in int(state.get("copies", 1)) - 1:
			extras.append(PrintedItem.restored(state["item"]))
		_lay_out()
		_grow(job.progress)
	status = saved_status
