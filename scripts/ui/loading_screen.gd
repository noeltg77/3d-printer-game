class_name LoadingScreen
extends Control
## What covers the window while one scene is swapped for another: the game's
## name printing itself as the load goes, a bar, and a tip to read. Screens
## (the autoload) shows it and feeds it progress.

var _logo: PrintLogo
var _caption: Label
var _bar: ProgressBar
var _tip: Label
var _last_tip := -1


func _init() -> void:
	theme = Ui.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Ui.TASKBAR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_logo = PrintLogo.new(0.8)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caption = Ui.title("", 22, Ui.PAPER)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = Ui.bar(0.0, Ui.ORANGE, Ui.CHIP, 14)
	_bar.custom_minimum_size.x = 420
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip = Ui.text("", 15, Ui.CHIP_TEXT)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(560, 48)
	var column := Ui.vbox([_logo, _caption, _bar, Ui.margin(_tip, 0, 14, 0, 0)], 16)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(column)
	add_child(centre)


## Sets the screen up for a new load.
func start(caption: String) -> void:
	_caption.text = caption
	set_progress(0.0)
	var tips: Array = Game.data.settings.get("tips", [])
	if tips.is_empty():
		_tip.text = ""
		return
	var pick := randi() % tips.size()
	if pick == _last_tip:
		pick = (pick + 1) % tips.size()
	_last_tip = pick
	_tip.text = "Tip: %s" % tips[pick]


## How far along the load is, 0 to 1.
func set_progress(value: float) -> void:
	_bar.value = value
	_logo.progress = value
