class_name PrintDialog
extends CanvasLayer
## The print set-up card, opened from a printer's "Print..." action. The player
## picks a design and a preset; a risk meter shows the chance of the print
## failing and how strong the result will be. "Start print" queues the job for
## the character. The game keeps running while it is open.

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
var _holder: CenterContainer


func _ready() -> void:
	add_to_group(&"print_dialog")
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	Ui.clickable(backdrop, close)
	backdrop.mouse_default_cursor_shape = Control.CURSOR_ARROW
	add_child(backdrop)
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
	_preset = StringName(Game.data.settings["default_preset"])
	_product = Game.owned_designs[0]
	# Start on something that can actually be printed, if anything can.
	for product in Game.owned_designs:
		if printer.print_problem(product, _preset) == "":
			_product = product
			break
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	_printer = null


## Picks a design and preset and starts the print, as the buttons would.
func choose(product: String, preset: String) -> void:
	_product = StringName(product)
	_preset = StringName(preset)
	_confirm()


func _rebuild() -> void:
	if not visible:
		return
	# The printer may have gone, or been set going from the queue, since opening.
	if not is_instance_valid(_printer) or _printer.spool == null:
		close()
		return
	Ui.clear(_holder)
	var spool := _printer.spool
	var close_button := Ui.button("Cancel", close, Ui.SOFT, Ui.INK, 40, 12, Ui.CLEAR, 14)
	var header := Ui.hbox([
		Ui.title("Print on the %s" % _printer.display_name, 26), null,
		Ui.pill("Loaded: %s" % spool.describe(), Ui.GREEN_DARK, Ui.GREEN_SOFT, 13),
	], 16)

	var designs := Ui.vbox([], 8)
	for product in Game.owned_designs:
		designs.add_child(_design_row(product))
	var left := Ui.vbox([Ui.text("Design", 13, Ui.MUTED, 800), Ui.scroll(designs)], 8)
	left.custom_minimum_size = Vector2(300, 330)
	(left.get_child(1) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

	var presets := Ui.hbox([], 12)
	for preset_id: String in Game.data.presets:
		presets.add_child(_preset_card(StringName(preset_id)))
	var right := Ui.vbox([Ui.text("How to print it", 13, Ui.MUTED, 800), presets, _meter()], 8)
	right.custom_minimum_size.x = 600

	var problem := _printer.print_problem(_product, _preset)
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
	if not printable:
		note += " · can't print now"
	var row := Ui.panel(Ui.vbox([
		Ui.text(Game.product_name(product), 15, fg, 800),
		Ui.text(note, 13, Ui.CHIP_TEXT if chosen else Ui.MUTED),
	], 0), Ui.box(Ui.INK if chosen else Ui.WHITE, 14, 14, 10, Ui.CLEAR if chosen else SHADOW, 0 if chosen else 3))
	return Ui.clickable(row, _pick.bind(product, _preset))


func _preset_card(preset_id: StringName) -> Control:
	var preset: Dictionary = Game.data.presets[preset_id]
	var chosen := preset_id == _preset
	var card := Ui.panel(Ui.vbox([
		Ui.title(preset["name"], 19),
		Ui.wrap(Ui.text(preset["description"], 13, Ui.MUTED)),
		null,
		Ui.text("%s · %d g" % [GameClock.duration_label(_printer.print_minutes(_product, preset_id)),
			roundi(Game.print_grams(_product, preset_id))], 14, Ui.INK, 800),
	], 6), Ui.outlined(Ui.PAPER if chosen else Ui.WHITE, Ui.ORANGE if chosen else SHADOW, 16, 14, 12, 3))
	card.custom_minimum_size.y = 150
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = preset["settings_hint"]
	return Ui.clickable(card, _pick.bind(_product, preset_id))


## The risk meter: chance of failure as a bar, strength and finish as dots.
func _meter() -> Control:
	var preset: Dictionary = Game.data.presets[_preset]
	var chance := Game.fail_chance(_printer.spec, _preset, _printer.spool.material, _product, _printer.wear, _printer.mods)
	var band := PrintRisk.band(chance)
	var colour: Color = BAND_COLOURS[band]
	var durability := int(preset["durability"])
	var breaks := roundi(Game.damage_chance(durability) * 100.0)
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
	var filament: Dictionary = Game.data.filaments[_printer.spool.material]
	var nozzle: Dictionary = _printer.wear.part(&"nozzle") if _printer.wear.fitted.has(&"nozzle") else {}
	if not nozzle.is_empty() and FilamentRules.wears_nozzle(filament, nozzle):
		rows.add_child(Ui.wrap(Ui.text("%s is gritty: it wears this %s %d times faster. A hardened nozzle shrugs it off." % [
			filament["name"], String(nozzle["name"]).to_lower(), roundi(float(nozzle["abrasive_wear_multiplier"]))], 13, Ui.RED_DARK, 800)))
	var helping: PackedStringArray = []
	for upgrade in _printer.mods.fitted:
		if not Game.data.upgrades[upgrade]["failure_multipliers"].is_empty():
			helping.append(String(Game.data.upgrades[upgrade]["name"]).to_lower())
	if not helping.is_empty():
		rows.add_child(Ui.text("Upgrades are cutting the risk: %s." % ", ".join(helping), 13, Ui.GREEN_DARK, 800))
	return Ui.panel(rows, Ui.box(Ui.INSET, 16, 16, 14))


## "Uses 25 g of Red PLA and about £0.43 to make."
func _summary() -> String:
	var spool := _printer.spool
	var grams := Game.print_grams(_product, _preset)
	var filament: Dictionary = Game.data.filaments[spool.material]
	var kwh := float(_printer.spec["power_watts"]) / 1000.0 * _printer.print_minutes(_product, _preset) / 60.0
	var cost := roundi(grams / 1000.0 * float(filament["price_pence_per_kg"]) + kwh * float(Game.data.settings["electricity_pence_per_kwh"]))
	var summary := "Uses %d g of %s, about %s in filament and power." % [roundi(grams), spool.title(), Money.format(cost)]
	var premium := roundi((float(filament["value_multiplier"]) - 1.0) * 100.0)
	return summary if premium <= 0 else "%s Sells for %d%% more in %s." % [summary, premium, filament["name"]]


func _pick(product: StringName, preset: StringName) -> void:
	_product = product
	_preset = preset
	_rebuild.call_deferred()


func _confirm() -> void:
	if _printer == null:
		return
	var action := _printer.print_action(_product, _preset)
	if action.enabled:
		(get_tree().get_first_node_in_group(&"player") as Agent).enqueue(action)
	close()
