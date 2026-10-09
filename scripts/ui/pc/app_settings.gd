extends VBoxContainer
## PC app: Settings. The currency that money is shown in (choosing one calls
## Game.set_currency, which redraws the HUD and whatever is open on the PC), and
## the saved game: when it was last saved, saving now and starting again.

const SLATE := Color("5C6B73")
const SHADOW := Color("DDE1E3")
const CHOSEN_SHADOW := Color("0F171B")
## An amount to show each currency's format with: over a thousand, with pence.
const SAMPLE_PENCE := 123456

var screen: PcScreen

## True while "Start a new game" is waiting for the player to confirm.
var _confirming := false


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("settings", 32, Ui.PAPER, 700),
		Ui.text("How PlateOS shows things to you.", 15, Ui.PAPER),
	], 24), Ui.box(SLATE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var options := Ui.hbox([], 16)
	var chosen := Money.currency
	for code: String in Money.currencies():
		options.add_child(_option(code, code == chosen))
	# Restore the player's choice: building the samples switched currency.
	Money.set_currency(chosen)

	var card := Ui.card(Ui.vbox([
		Ui.title("Currency", 22),
		Ui.wrap(Ui.text("Pick the money you think in. Prices, your balance and every total switch straight away. "
			+ "The business itself runs in pounds underneath, so changing this never alters what anything costs or what you have earned.", 14, Ui.MUTED)),
		options,
		Ui.wrap(Ui.text("The price you see is the price you pay: every amount is converted the same way, so a price tag always matches your bank statement.", 13, Ui.MUTED)),
	], 16), 22, 24, SHADOW)
	card.custom_minimum_size.x = 760
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var page := Ui.margin(Ui.scroll(Ui.vbox([card, _save_card()], 20)), 32, 24, 32, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


## When the game was last saved, with buttons to save now and to start again.
func _save_card() -> Control:
	var rows := Ui.vbox([Ui.title("Saved game", 22)], 16)
	if Game.save_path == "":
		rows.add_child(Ui.wrap(Ui.text("Saving is switched off for this run.", 14, Ui.MUTED)))
	else:
		var saved := GameClock.new()
		saved.minutes = Game.saved_at
		rows.add_child(Ui.wrap(Ui.text("The game saves itself each time you finish a job and when you close it, and carries on from there next time. "
			+ "Jobs still waiting in the queue aren't kept.", 14, Ui.MUTED)))
		rows.add_child(Ui.text("Last saved: %s" % saved.label() if Game.saved_at >= 0.0 else "Not saved yet", 15, Ui.INK, 800))
		if _confirming:
			rows.add_child(Ui.panel(Ui.vbox([
				Ui.wrap(Ui.text("Start again from nothing? Your printers, stock, cash and reviews will all be gone for good.", 14, Ui.RED_DARK, 800)),
				Ui.hbox([
					Ui.button("Yes, start again", _start_again, Ui.RED, Ui.WHITE, 44, 14, Ui.RED_DARK, 15),
					Ui.button("Keep my business", _confirm.bind(false), Ui.SOFT, Ui.INK, 44, 14, Ui.CLEAR, 15),
				], 12),
			], 12), Ui.box(Ui.RED_SOFT, 16, 16, 14)))
		else:
			rows.add_child(Ui.hbox([
				Ui.button("Save now", _save_now, SLATE, Ui.WHITE, 44, 14, CHOSEN_SHADOW, 15),
				Ui.button("Start a new game", _confirm.bind(true), Ui.SOFT, Ui.INK, 44, 14, Ui.CLEAR, 15),
			], 12))
	var card := Ui.card(rows, 22, 24, SHADOW)
	card.custom_minimum_size.x = 760
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return card


func _save_now() -> void:
	var world: WorldSave = get_tree().get_first_node_in_group(&"world_save")
	var saved := world.save_now()
	Game.notify("Game saved" if saved else "The game couldn't be saved", &"good" if saved else &"bad")
	screen.refresh()


func _confirm(asking: bool) -> void:
	_confirming = asking
	screen.refresh()


func _start_again() -> void:
	Game.delete_save()
	Game.new_game()
	get_tree().reload_current_scene()


## One currency as a big button: symbol, name and a sample amount in its format.
func _option(code: String, chosen: bool) -> Control:
	var spec: Dictionary = Money.currencies()[code]
	Money.set_currency(code)
	var sample := Money.format(SAMPLE_PENCE)
	var ink := Ui.PAPER if chosen else Ui.INK
	var column := Ui.vbox([
		Ui.title(spec["symbol"], 40, ink, 700),
		Ui.text("%s (%s)" % [spec["name"], code], 15, ink, 800),
		Ui.text(sample, 13, Color(ink, 0.75)),
		Ui.pill("In use", Ui.INK, Ui.PAPER) if chosen else Ui.pill("Use this", Ui.PAPER, Ui.INK),
	], 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in column.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_top = 14
	column.offset_right = -20
	column.offset_bottom = -18

	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 168)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fill := Ui.INK if chosen else Ui.SOFT
	button.add_theme_stylebox_override(&"normal", Ui.box(fill, 20, 0, 0, CHOSEN_SHADOW if chosen else Ui.TRACK, 4))
	button.add_theme_stylebox_override(&"hover", Ui.box(fill if chosen else Ui.INSET, 20, 0, 0, CHOSEN_SHADOW if chosen else Ui.TRACK, 4))
	button.add_theme_stylebox_override(&"pressed", Ui.box(fill if chosen else Ui.TRACK, 20, 0, 0))
	button.add_child(column)
	button.pressed.connect(Game.set_currency.bind(code))
	return button
