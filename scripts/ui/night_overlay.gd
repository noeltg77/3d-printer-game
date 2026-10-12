class_name NightOverlay
extends CanvasLayer
## Covers the screen while the night is skipped (Game.sleeping): the room dims,
## a card shows the hours running by, and the player can wake early. Sits over
## the PC screen and under the messages, so news from the night still shows.

const DIM := Color(0.07, 0.08, 0.16, 0.72)

var _root: Control
var _time: Label
var _back_at: Label


func _ready() -> void:
	layer = 4
	_root = Control.new()
	_root.theme = Ui.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nothing behind can be clicked until morning.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_time = Ui.title("", 56)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_at = Ui.text("", 14, Ui.MUTED)
	_back_at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading := Ui.title("Closed for the night", 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wake := Ui.button("Wake up now", Game.wake, Ui.ORANGE, Ui.WHITE, 46, 18, Ui.ORANGE_DARK, 15)
	wake.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card := Ui.card(Ui.vbox([heading, _time, _back_at, wake], 12), 24, 28, Ui.SHADE)
	card.custom_minimum_size.x = 420
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(card)
	_root.add_child(centre)

	Game.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if _root.visible:
		_time.text = WorkDay.time_label(Game.clock.minute_of_day)


func _refresh() -> void:
	_root.visible = Game.sleeping
	_back_at.text = "The printers carry on and orders keep coming in.\nBack at %s." % WorkDay.time_label(Game.work_day.start_minute)
