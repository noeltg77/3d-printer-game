class_name StatusBar
extends HBoxContainer
## The speed control, cash and clock chips, as on the PlateOS taskbar. Used on
## the PC's taskbar and on the in-game HUD so both read the same. Once the
## working day is over it also offers to end the day and skip the night.

const SPEED_LABELS := {0: "||", 1: "1x", 2: "2x", 4: "4x"}
const ACTIVE := Color("F3EDE2")

var _speed_buttons: Dictionary[int, Button] = {}
var _cash: Label
var _day: Label
var _time: Label
var _end_day: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)

	var speeds := Ui.hbox([], 6)
	for speed in Game.SPEEDS:
		var button := Ui.button(SPEED_LABELS[speed], Game.set_speed.bind(speed), Ui.CLEAR, Ui.CHIP_TEXT, 36, 10)
		button.custom_minimum_size.x = 44
		button.tooltip_text = "Pause" if speed == 0 else "Speed %dx" % speed
		_speed_buttons[speed] = button
		speeds.add_child(button)
	add_child(Ui.panel(speeds, Ui.box(Ui.CHIP, 14, 4, 4)))

	_cash = Ui.text("", 17, Ui.CASH, 800)
	add_child(_chip(_cash))
	_day = Ui.text("", 15, ACTIVE, 800)
	_time = Ui.text("", 15, Ui.CHIP_MUTED, 800)
	add_child(_chip(Ui.hbox([_day, _time], 10)))

	# Only there once the working day is over.
	_end_day = Ui.button("End the day", _end_the_day, Ui.ORANGE, Ui.WHITE, 44, 14, Ui.ORANGE_DARK, 15)
	_end_day.tooltip_text = "Skip the night. Printers carry on and orders keep coming in."
	_end_day.visible = false
	add_child(_end_day)

	var menu := Ui.button("Menu", Screens.open_pause_menu, Ui.CHIP, Ui.CHIP_TEXT, 44, 14, Ui.CLEAR, 14)
	menu.tooltip_text = "Save, load or leave (Esc)"
	add_child(menu)

	Game.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	var clock := Game.clock
	_end_day.visible = Game.day_over() and not Game.sleeping
	var minute := int(clock.minute_of_day)
	_day.text = "Day %d" % clock.day
	_time.text = "%02d:%02d" % [minute / 60, minute % 60]


func _refresh() -> void:
	_cash.text = Money.format(Game.bank.cash)
	_cash.add_theme_color_override(&"font_color", Color("FF9C8A") if Game.bank.cash < 0 else Ui.CASH)
	for speed in _speed_buttons:
		var active := speed == Game.speed
		var button := _speed_buttons[speed]
		button.add_theme_stylebox_override(&"normal", Ui.box(ACTIVE if active else Ui.CLEAR, 10, 10, 0))
		button.add_theme_stylebox_override(&"hover", Ui.box(ACTIVE if active else Color(1, 1, 1, 0.08), 10, 10, 0))
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(state, Ui.TASKBAR if active else Ui.CHIP_TEXT)


func _chip(content: Control) -> PanelContainer:
	var chip := Ui.panel(content, Ui.box(Ui.CHIP, 14, 16, 0))
	chip.custom_minimum_size.y = 44
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


func _end_the_day() -> void:
	var problem := Game.end_day_problem()
	if problem != "":
		Game.notify(problem, &"bad")
	else:
		Game.end_day()
