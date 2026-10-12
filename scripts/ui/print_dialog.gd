class_name PrintDialog
extends CanvasLayer
## The print set-up card, opened from a printer's "Print..." action. The player
## picks a design and a preset; a risk meter shows the chance of the print
## failing and how strong the result will be. "Start print" queues the job for
## the character. The game keeps running while it is open.
##
## On a printer with a multicolour unit the player also picks which spool
## prints each colour, and whether a design made for several colours is printed
## in all of them or just one. Where more than one of a design fits on the
## plate, the player can also print several copies at once.

const SHADOW := Color("E4DACA")
const BACKDROP := Color(0.118, 0.165, 0.188, 0.55)
const AMBER := Color("D9A23A")
## Chance of failure that fills the risk meter completely.
const METER_FULL := 0.3
const BAND_COLOURS := {"Low": Ui.GREEN, "Medium": AMBER, "High": Ui.RED, "Very high": Ui.RED_DARK}
const SCALE := 5

var _printer: PrinterStation = null
var _product: StringName
var _preset: StringName
## The slots picked to print from, one per colour. Empty leaves it to the printer.
var _slots: Array[int] = []
## How many copies to print at once.
var _copies := 1
var _holder: CenterContainer
var _backdrop: ColorRect


func _ready() -> void:
	add_to_group(&"print_dialog")
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	Ui.clickable(backdrop, close)
	backdrop.mouse_default_cursor_shape = Control.CURSOR_ARROW
	add_child(backdrop)
	_backdrop = backdrop
	_holder = CenterContainer.new()
	_holder.theme = Ui.theme()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	Game.changed.connect(_rebuild)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(printer: PrinterStation) -> void:
	_printer = printer
	_slots = []
	_copies = 1
	_preset = StringName(Game.data.settings["default_preset"])
	_product = Game.printable_designs()[0]
	# Start on something that can actually be printed, if anything can.
	for product in Game.printable_designs():
		if printer.print_problem(product, _preset) == "":
			_product = product
			break
	visible = true
	_rebuild()
	_backdrop.modulate.a = 0.0
	Ui.tween(_backdrop).tween_property(_backdrop, "modulate:a", 1.0, 0.15)
	Ui.pop_in(_holder, _holder.size / 2.0, 0.94)


func close() -> void:
	visible = false
	_printer = null


## Picks a design and preset and starts the print, as the buttons would.
## `slots` are the spools to use, one per colour, counting from 0; empty leaves
## the choice to the printer. `copies` is how many to print at once.
func choose(product: String, preset: String, slots: Array = [], copies := 1) -> void:
	_product = StringName(product)
	_preset = StringName(preset)
	_slots.assign(slots)
	_copies = copies
	_confirm()


## The slots the print will use: the player's pick while it still holds, or the printer's.
func _used_slots() -> Array[int]:
	if _slots.any(func(slot: int) -> bool: return slot < 0 or slot >= _printer.spools.size() or _printer.spools[slot] == null):
		_slots = []
	return _slots if not _slots.is_empty() else _printer.default_slots(_product)


func _rebuild() -> void:
	if not visible:
		return
	# The printer may have gone, or been set going from the queue, since opening.
	if not is_instance_valid(_printer) or _printer.spool == null:
		close()
		return
	Ui.clear(_holder)
	var loaded := _printer.spools.filter(func(spool: Spool) -> bool: return spool != null)
	var close_button := Ui.button("Cancel", close, Ui.SOFT, Ui.INK, 40, 12, Ui.CLEAR, 14)
	var header := Ui.hbox([
		Ui.title("Print on the %s" % _printer.display_name, 26), null,
		Ui.pill("%d of %d slots loaded" % [loaded.size(), _printer.spools.size()] if _printer.has_unit()
			else "Loaded: %s" % _printer.spool.describe(), Ui.GREEN_DARK, Ui.GREEN_SOFT, 13),
	], 16)

	var designs := Ui.vbox([], 8)
	for product in Game.printable_designs():
		designs.add_child(_design_row(product))
	var left := Ui.vbox([Ui.text("Design", 13, Ui.MUTED, 800), Ui.scroll(designs)], 8)
	left.custom_minimum_size = Vector2(300, 330)
	(left.get_child(1) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

	var presets := Ui.hbox([], 12)
	for preset_id: String in Game.data.presets:
		presets.add_child(_preset_card(StringName(preset_id)))
	_copies = clampi(_copies, 1, _printer.max_copies(_product))
	var right := Ui.vbox([Ui.hbox([Ui.text("How to print it", 13, Ui.MUTED, 800), null, _copies_picker()], 8), presets], 8)
	if _printer.has_unit() or Multicolour.colours_of(Game.data.products[_product]) > 1:
		right.add_child(_colours())
	if not Game.popular_colours(_product).is_empty():
		right.add_child(_taste())
	right.add_child(_meter())
	right.custom_minimum_size.x = 600

	var problem := _printer.print_problem(_product, _preset, _used_slots(), _copies)
	var start := Ui.button("Start print", _confirm, Ui.ORANGE, Ui.WHITE, 48, 14, Ui.ORANGE_DARK, 16)
	start.disabled = problem != ""
	var footer := Ui.hbox([
		Ui.text(problem if problem != "" else _summary(), 14, Ui.RED_DARK if problem != "" else Ui.MUTED, 800),
		null, close_button, start,
	], 12)
	_holder.add_child(Ui.panel(Ui.vbox([header, Ui.hbox([left, right], 24), footer], 20),
		Ui.box(Ui.CREAM, 24, 28, 24, Ui.SHADE, 8)))


func _design_row(product: StringName) -> Control:
	var chosen := product == _product
	var printable := _printer.print_problem(product, _preset) == ""
	var fg := Ui.PAPER if chosen else Ui.INK
	var note := "%d g · %s" % [roundi(Game.print_grams(product, _preset)),
		GameClock.duration_label(_printer.print_minutes(product, _preset))]
	if Game.contracts.needs(product):
		note += " · for a contract"
	if not PrintRisk.fits(_printer.spec, Game.data.products[product]):
		note += " · too big for this printer"
	elif not printable:
		note += " · can't print now"
	var words := Ui.vbox([
		Ui.text(Game.product_name(product), 15, fg, 800),
		Ui.text(note, 13, Ui.CHIP_TEXT if chosen else Ui.MUTED),
	], 0)
	var liked := Ui.swatches(Game.popular_colours(product).map(Palette.colour), 12)
	liked.tooltip_text = "Buyers like it best in %s" % Game.popular_colours_label(product)
	var row := Ui.panel(Ui.hbox([Ui.grow(words), liked], 8), Ui.box(Ui.INK if chosen else Ui.WHITE, 14, 14, 10, Ui.CLEAR if chosen else SHADOW, 0 if chosen else 3))
	return Ui.clickable(row, _pick.bind(product, _preset))


func _preset_card(preset_id: StringName) -> Control:
	var preset: Dictionary = Game.data.presets[preset_id]
	var chosen := preset_id == _preset
	var card := Ui.panel(Ui.vbox([
		Ui.title(preset["name"], 19),
		Ui.wrap(Ui.text(preset["description"], 13, Ui.MUTED)),
		null,
		Ui.text("%s · %d g" % [GameClock.duration_label(_printer.print_minutes(_product, preset_id, _used_slots(), _copies)),
			roundi(Game.print_grams(_product, preset_id) * _copies)], 14, Ui.INK, 800),
	], 6), Ui.outlined(Ui.PAPER if chosen else Ui.WHITE, Ui.ORANGE if chosen else SHADOW, 16, 14, 12, 3))
	card.custom_minimum_size.y = 150
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = preset["settings_hint"]
	return Ui.clickable(card, _pick.bind(_product, preset_id))


## How many copies to print at once, where the plate has room for more than one.
func _copies_picker() -> Control:
	var most := _printer.max_copies(_product)
	if most <= 1:
		return Ui.spacer()
	var toggle: Dictionary = Game.data.toggles["batch_plate"]
	var fewer := Ui.button("-", _set_copies.bind(_copies - 1), Ui.SOFT, Ui.INK, 28, 10, Ui.CLEAR, 14)
	fewer.disabled = _copies <= 1
	var more := Ui.button("+", _set_copies.bind(_copies + 1), Ui.SOFT, Ui.INK, 28, 10, Ui.CLEAR, 14)
	more.disabled = _copies >= most
	var picker := Ui.hbox([
		Ui.text(toggle["name"], 13, Ui.MUTED, 800), fewer,
		Ui.text("%d of up to %d" % [_copies, most], 13, Ui.INK, 800), more,
	], 8)
	picker.tooltip_text = toggle["description"]
	return picker


func _set_copies(copies: int) -> void:
	_copies = copies
	_rebuild.call_deferred()


## Which spool prints each colour, and for a design made for several, whether
## to print them all. Without a unit it only says what the player is missing.
func _colours() -> Control:
	var wanted := Multicolour.colours_of(Game.data.products[_product])
	var toggle: Dictionary = Game.data.toggles["multicolour"]
	var used := _used_slots()
	var rows := Ui.vbox([], 10)
	if not _printer.has_unit():
		rows.add_child(Ui.wrap(Ui.text("This design is made for %d colours. Without a multicolour unit on the printer it comes out in one: it sells for %d%% less and buyers like it less." % [
			wanted, roundi((1.0 - float(toggle["off_price_multiplier"])) * 100.0)], 13, Ui.MUTED)))
		return Ui.panel(rows, Ui.box(Ui.INSET, 16, 16, 14))
	if wanted > 1:
		var full := used.size() == wanted
		var can_be_full := _full_colour_slots().size() == wanted
		var full_button := Ui.button(toggle["name"], _set_full_colour.bind(true), Ui.INK if full else Ui.WHITE, Ui.PAPER if full else Ui.INK, 36, 12, Ui.CLEAR, 14)
		full_button.disabled = not can_be_full
		var note: String = toggle["description"] if full else toggle["off_description"]
		if not can_be_full:
			note = "Load %d spools of one kind of filament into the unit to print this in full colour. In one colour it sells for less." % wanted
		rows.add_child(Ui.hbox([
			full_button,
			Ui.button(toggle["off_name"], _set_full_colour.bind(false), Ui.WHITE if full else Ui.INK, Ui.INK if full else Ui.PAPER, 36, 12, Ui.CLEAR, 14),
			Ui.grow(Ui.wrap(Ui.text(note, 13, Ui.MUTED))),
		], 10))
	for index in used.size():
		# The chips wrap, because two linked units hold more spools than fit on a line.
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override(&"h_separation", 8)
		chips.add_theme_constant_override(&"v_separation", 6)
		for slot in _printer.spools.size():
			var spool := _printer.spools[slot]
			if spool == null:
				continue
			var chosen := used[index] == slot
			var chip := Ui.panel(Ui.hbox([
				SpoolIcon.create(Palette.colour(spool.colour), 24, Ui.PAPER if chosen else Ui.WHITE),
				Ui.text(Palette.display_name(spool.colour), 13, Ui.INK, 800),
			], 6), Ui.outlined(Ui.PAPER if chosen else Ui.WHITE, Ui.ORANGE if chosen else SHADOW, 12, 10, 6, 3))
			chip.tooltip_text = "%s: %s" % [_printer.slot_name(slot), spool.describe()]
			chips.add_child(Ui.clickable(chip, _pick_slot.bind(index, slot)))
		rows.add_child(Ui.hbox([Ui.width(Ui.text("Colour %d" % (index + 1) if used.size() > 1 else "Colour", 14, Ui.INK, 800), 76), Ui.grow(chips)], 8))
	return Ui.panel(rows, Ui.box(Ui.INSET, 16, 16, 14))


## The slots a full colour print of the design would use by default, or fewer
## if the unit doesn't hold enough spools for it.
func _full_colour_slots() -> Array[int]:
	return _printer.default_slots(_product)


func _set_full_colour(full: bool) -> void:
	var used := _used_slots()
	_slots = _full_colour_slots() if full else ([used[0]] as Array[int])
	_rebuild.call_deferred()


## Gives a colour of the design to a slot. If another colour had it, they swap.
func _pick_slot(index: int, slot: int) -> void:
	var used := _used_slots().duplicate()
	var other := used.find(slot)
	if other >= 0:
		used[other] = used[index]
	used[index] = slot
	_slots = used
	_rebuild.call_deferred()


## The risk meter: chance of failure as a bar, strength and finish as dots.
## The colours buyers like the chosen design best in, and whether what it is
## about to be printed in is one of them.
func _taste() -> Control:
	var printing: Array[StringName] = []
	for slot in _used_slots():
		if _printer.spools[slot] != null:
			printing.append(_printer.spools[slot].colour)
	var liked := Game.taste.likes(Game.data.products[_product], printing)
	var verdict := Ui.pill("A favourite: sells faster" if liked else "Not a favourite: sells slower",
		Ui.GREEN_DARK if liked else Ui.AMBER_DARK, Ui.GREEN_SOFT if liked else Ui.AMBER_SOFT, 13)
	var line := Ui.hbox([
		Ui.swatches(Game.popular_colours(_product).map(Palette.colour), 16),
		Ui.grow(Ui.text("Buyers like it best in %s" % Game.popular_colours_label(_product), 13, Ui.INK, 800)),
		verdict,
	], 10)
	line.tooltip_text = "A listing shows what you have been sending. Sent in a colour buyers like, a design gets up to %d%% more orders; in others, %d%% fewer." % [
		roundi((float(Game.data.settings["colour_taste"]["liked_demand"]) - 1.0) * 100.0),
		roundi((1.0 - float(Game.data.settings["colour_taste"]["other_demand"])) * 100.0)]
	return Ui.panel(line, Ui.box(Ui.INSET, 12, 12, 8))


func _meter() -> Control:
	var preset: Dictionary = Game.data.presets[_preset]
	var plan := _printer.print_plan(_product, _preset, _used_slots(), _copies)
	var material: StringName = plan["material"]
	var used: Array[Spool] = []
	var moisture := 0.0
	for slot: int in plan["slots"]:
		used.append(_printer.spools[slot])
		moisture = maxf(moisture, _printer.spools[slot].moisture)
	var chance := Game.fail_chance(_printer.spec, _preset, material, _product, _printer.wear, _printer.mods,
		moisture, int(plan["swaps"]))
	var band := PrintRisk.band(chance)
	var colour: Color = BAND_COLOURS[band]
	var durability := int(preset["durability"])
	var breaks := roundi(Game.damage_chance(durability, _product) * 100.0)
	var post := Ui.text("About %d in 100 break in the post" % breaks if breaks > 0 else "Almost never breaks in the post", 13, Ui.MUTED)
	post.mouse_filter = Control.MOUSE_FILTER_STOP
	post.tooltip_text = Game.data.durability_labels[str(durability)]
	var rows := Ui.vbox([
		Ui.hbox([
			Ui.width(Ui.text("Risk of failure", 14, Ui.INK, 800), 120),
			Ui.bar(chance / METER_FULL, colour, Ui.TRACK, 14),
			Ui.width(Ui.text("%s · about %d in 100" % [band, maxi(roundi(chance * 100.0), 1)], 13, colour.darkened(0.25), 800), 170),
		], 12),
		Ui.hbox([
			Ui.width(Ui.text("Strength", 14, Ui.INK, 800), 120),
			Ui.pips(durability, SCALE, Ui.ORANGE),
			post,
		], 12),
		Ui.hbox([
			Ui.width(Ui.text("Finish", 14, Ui.INK, 800), 120),
			Ui.pips(int(preset["quality"]), SCALE, Ui.GREEN),
		], 12),
	], 12)
	var worn: PackedStringArray = []
	for slot in _printer.wear.slots():
		if _printer.wear.is_worn(slot):
			worn.append(String(_printer.wear.part(slot)["slot_name"]).to_lower())
	if not worn.is_empty():
		rows.add_child(Ui.text("Worn parts are adding to the risk: %s." % ", ".join(worn), 13, Ui.RED_DARK, 800))
	var filament: Dictionary = Game.data.filaments[material]
	var nozzle: Dictionary = _printer.wear.part(&"nozzle") if _printer.wear.fitted.has(&"nozzle") else {}
	if not nozzle.is_empty() and FilamentRules.wears_nozzle(filament, nozzle):
		rows.add_child(Ui.wrap(Ui.text("%s is gritty: it wears this %s %d times faster. A hardened nozzle shrugs it off." % [
			filament["name"], String(nozzle["name"]).to_lower(), roundi(float(nozzle["abrasive_wear_multiplier"]))], 13, Ui.RED_DARK, 800)))
	if used.any(func(spool: Spool) -> bool: return spool.is_wet()):
		rows.add_child(Ui.wrap(Ui.text("%s wet, which is adding to the risk and makes prints stringy. A spell in a filament dryer sorts it out." % (
			"This spool is" if used.size() == 1 else "One of these spools is"), 13, Ui.RED_DARK, 800)))
	var unit := _printer.mods.unit()
	if int(plan["swaps"]) > 0:
		var shared := "" if _copies == 1 else " That is the same for one copy or %d, so only %d g each." % [_copies, roundi(float(plan["purged"]) / _copies)]
		rows.add_child(Ui.wrap(Ui.text("The unit changes colour %d times: %d g of filament is purged and thrown away, and it adds %s.%s Colours close in shade waste less than dark next to light." % [
			int(plan["swaps"]), roundi(float(plan["purged"])), GameClock.duration_label(Multicolour.swap_minutes(unit, int(plan["swaps"]))), shared], 13, Ui.MUTED)))
	if _copies > 1:
		rows.add_child(Ui.text("All %d are on one plate: if the print fails, they all do." % _copies, 13, Ui.MUTED))
	if Multicolour.flags(unit, filament, 0, Game.data.settings["multicolour"]).has(&"tpu_in_multicolour"):
		rows.add_child(Ui.wrap(Ui.text("%s is soft and bendy, and this unit isn't built for it: it is far more likely to jam." % filament["name"], 13, Ui.RED_DARK, 800)))
	var helping: PackedStringArray = []
	for upgrade in _printer.mods.fitted:
		if not Game.data.upgrades[upgrade]["failure_multipliers"].is_empty():
			helping.append(String(Game.data.upgrades[upgrade]["name"]).to_lower())
	if not helping.is_empty():
		rows.add_child(Ui.text("Upgrades are cutting the risk: %s." % ", ".join(helping), 13, Ui.GREEN_DARK, 800))
	return Ui.panel(rows, Ui.box(Ui.INSET, 16, 16, 14))


## "Uses 25 g of Red PLA, about £0.43 in filament and power."
func _summary() -> String:
	var plan := _printer.print_plan(_product, _preset, _used_slots(), _copies)
	var slots: Array[int] = plan["slots"]
	var grams := 0.0
	for each: float in plan["grams"]:
		grams += each
	var filament: Dictionary = Game.data.filaments[plan["material"]]
	var kwh := float(_printer.spec["power_watts"]) / 1000.0 * float(plan["minutes"]) / 60.0
	var cost := roundi(grams / 1000.0 * float(filament["price_pence_per_kg"]) + kwh * float(Game.data.settings["electricity_pence_per_kwh"]))
	var what := _printer.spools[slots[0]].title() if slots.size() == 1 else "%s from %d spools" % [filament["name"], slots.size()]
	var summary := "Uses %d g of %s, about %s in filament and power." % [roundi(grams), what, Money.format(cost)]
	var premium := roundi((float(filament["value_multiplier"]) - 1.0) * 100.0)
	if premium > 0:
		summary = "%s Sells for %d%% more in %s." % [summary, premium, filament["name"]]
	if slots.size() < Multicolour.colours_of(Game.data.products[_product]):
		summary = "%s Sells for %d%% less in one colour." % [summary, roundi((1.0 - float(Game.data.toggles["multicolour"]["off_price_multiplier"])) * 100.0)]
	return summary


func _pick(product: StringName, preset: StringName) -> void:
	# A different design starts again from the printer's own choice of spools, and one copy.
	if product != _product:
		_slots = []
		_copies = 1
	_product = product
	_preset = preset
	_rebuild.call_deferred()


func _confirm() -> void:
	if _printer == null:
		return
	var action := _printer.print_action(_product, _preset, _used_slots(), _copies)
	if action.enabled:
		(get_tree().get_first_node_in_group(&"player") as Agent).enqueue(action)
	close()
