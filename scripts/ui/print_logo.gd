class_name PrintLogo
extends Control
## The game's name, which prints itself: the letters appear from the bottom up
## a layer at a time, under a nozzle going to and fro. Set `progress` from
## 0 to 1 (a loading bar can drive it), or call play() to run it through.

const TOP := "Print Shop"
const BOTTOM := "Tycoon"
## Sweeps of the nozzle a second, there and back.
const SWEEPS := 1.6

## A run of play() has finished.
signal printed

## How much of the name is printed, 0 to 1.
var progress := 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_lay_out()

var _scale := 1.0
var _clip := Control.new()
var _text: VBoxContainer
var _nozzle := Control.new()
var _head := 0.0
## Seconds a run of play() takes, or 0 when it isn't running.
var _seconds := 0.0
var _last_msec := 0


## `scale` 1 is the size on the main menu: letters 96 pixels tall.
func _init(scale := 1.0) -> void:
	_scale = scale
	_head = 34.0 * scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _line(TOP, Ui.PAPER)
	var bottom := _line(BOTTOM, Ui.ORANGE)
	_text = Ui.vbox([top, bottom], int(-26.0 * scale))
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_text)
	add_child(_clip)
	_nozzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nozzle.draw.connect(_draw_nozzle)
	add_child(_nozzle)


func _ready() -> void:
	# Measured here: a label doesn't know its size until it is in the tree.
	var text_size := _text.get_combined_minimum_size()
	_text.size = text_size
	custom_minimum_size = text_size + Vector2(0.0, _head + 14.0 * _scale)
	_lay_out()


func _process(_delta: float) -> void:
	if progress < 1.0:
		_nozzle.queue_redraw()
	if _seconds <= 0.0:
		return
	# In real time, but a long frame (a scene loading behind) doesn't skip ahead.
	var now := Time.get_ticks_msec()
	var step := minf((now - _last_msec) / 1000.0, 0.04)
	_last_msec = now
	progress += step / _seconds
	if progress >= 1.0:
		_seconds = 0.0
		printed.emit()


## Prints the name from nothing over `seconds` of real time. `printed` is
## emitted when it is done.
func play(seconds: float) -> void:
	progress = 0.0
	_seconds = seconds
	_last_msec = Time.get_ticks_msec()


func _line(content: String, colour: Color) -> Label:
	var label := Ui.title(content, int(96.0 * _scale), colour, 700)
	label.add_theme_color_override(&"font_shadow_color", Color(Ui.TASKBAR, 0.9))
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", int(7.0 * _scale))
	label.add_theme_constant_override(&"line_spacing", 0)
	return label


## Height of the letters still to come, from the top of the name.
func _unprinted() -> float:
	return _text.size.y * (1.0 - progress)


func _lay_out() -> void:
	if _text == null:
		return
	var hidden := _unprinted()
	_clip.position = Vector2(0.0, _head + hidden)
	# A little over, so the shadow under the last line isn't cut off.
	_clip.size = Vector2(_text.size.x, _text.size.y - hidden + 12.0 * _scale)
	_text.position = Vector2(0.0, -hidden)
	_nozzle.size = custom_minimum_size
	_nozzle.queue_redraw()


func _draw_nozzle() -> void:
	var width := _text.size.x
	var bed_y := _head + _text.size.y + 6.0 * _scale
	_nozzle.draw_rect(Rect2(0.0, bed_y, width, 5.0 * _scale), Color(Ui.PAPER, 0.28 * (1.0 - progress) + 0.0))
	if progress >= 1.0:
		return
	var sweep := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * SWEEPS * TAU)
	var at := Vector2(width * sweep, _head + _unprinted())
	# The layer going down, as far as the nozzle has got.
	_nozzle.draw_rect(Rect2(0.0, at.y - 2.0 * _scale, at.x, 4.0 * _scale), Ui.ORANGE)
	var unit := 9.0 * _scale
	_nozzle.draw_colored_polygon(PackedVector2Array([
		at, at + Vector2(-unit, -unit * 1.3), at + Vector2(unit, -unit * 1.3)]), Ui.AMBER_SOFT)
	_nozzle.draw_rect(Rect2(at.x - unit * 1.6, at.y - unit * 3.4, unit * 3.2, unit * 2.1), Ui.CHIP_TEXT)
	_nozzle.draw_rect(Rect2(at.x - unit * 1.6, at.y - unit * 3.4, unit * 3.2, unit * 0.6), Ui.CHIP_MUTED)
