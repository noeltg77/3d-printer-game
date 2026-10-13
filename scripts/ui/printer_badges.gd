class_name PrinterBadges
extends Control
## A small round token at the near corner of each printer's base, saying how it
## is doing: a ring that fills as it prints, a tick when the print is ready, a
## cross when it failed, a spanner when a part has gone. It hangs off the front
## of the bench or shelf the printer stands on, so it never covers a printer,
## its own or the one racked above. Pointing at a printer opens its token out
## into words.

const RADIUS := 13.0
## How far below the corner of the base the token's centre hangs, in pixels.
const DROP := 5.0
const TEXT_SIZE := 13

## Printer's instance id -> { at, box }: the world box round a printer and
## where it stood when measured, so it is only measured again once moved.
var _boxes: Dictionary[int, Dictionary] = {}
var _icons: Dictionary[String, Texture2D] = {}
## Where the tokens opened out into words were last drawn.
var _worded: Array[Rect2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for icon_name: String in ["tick", "close", "wrench"]:
		_icons[icon_name] = load("res://assets/ui/icons/%s.svg" % icon_name)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for id: int in _boxes.keys():
		if not is_instance_id_valid(id):
			_boxes.erase(id)
	_worded.clear()
	var opened: Array[PrinterStation] = []
	for printer: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		if _state(printer) == "":
			continue
		if printer.is_highlighted():
			opened.append(printer)
		else:
			_draw_token(_spot(camera, printer), printer)
	# The one being pointed at goes on last, so its words lie over its neighbours' tokens.
	for printer in opened:
		var at := _spot(camera, printer)
		_draw_words(at, printer)
		_draw_token(at, printer)


## True if a token's words are showing anywhere under `rect`. The label by
## the mouse asks, so that it can keep off them.
func words_under(rect: Rect2) -> bool:
	return _worded.any(func(words: Rect2) -> bool: return words.grow(4.0).intersects(rect))


## What the token should say.
func _state(printer: PrinterStation) -> String:
	match printer.status:
		PrinterStation.Status.PRINTING:
			return "printing"
		PrinterStation.Status.DONE:
			return "flawed" if printer.item.is_flawed() else "done"
		PrinterStation.Status.FAILED:
			return "failed"
	for slot in printer.wear.broken():
		return "part:%s" % String(printer.wear.part(slot)["slot_name"]).to_lower()
	return ""


## Where on screen a printer's token is centred: just under the corner of its
## base that is nearest the camera, which looks from the south-east.
func _spot(camera: Camera3D, printer: PrinterStation) -> Vector2:
	var id := printer.get_instance_id()
	if not _boxes.has(id) or not (_boxes[id]["at"] as Vector3).is_equal_approx(printer.global_position):
		_boxes[id] = {"at": printer.global_position, "box": Bounds.of(printer)}
	var box: AABB = _boxes[id]["box"]
	var corner := Vector3(box.end.x, printer.global_position.y, box.end.z)
	return (camera.unproject_position(corner) + Vector2(0, DROP)).round()


func _draw_token(at: Vector2, printer: PrinterStation) -> void:
	var state := _state(printer)
	draw_circle(at, RADIUS + 2.0, Ui.WHITE, true, -1.0, true)
	match state:
		"printing":
			draw_circle(at, RADIUS, Ui.TASKBAR, true, -1.0, true)
			draw_arc(at, RADIUS - 4.5, 0.0, TAU, 40, Ui.CHIP, 4.0, true)
			if printer.job != null and printer.job.progress > 0.0:
				draw_arc(at, RADIUS - 4.5, -PI / 2.0, -PI / 2.0 + TAU * printer.job.progress, 40, Ui.CASH, 4.0, true)
		"done":
			draw_circle(at, RADIUS, Ui.GREEN, true, -1.0, true)
			_draw_icon("tick", at, Ui.WHITE)
		"flawed":
			draw_circle(at, RADIUS, Ui.AMBER_SOFT, true, -1.0, true)
			_draw_icon("tick", at, Ui.AMBER_DARK)
		"failed":
			draw_circle(at, RADIUS, Ui.RED, true, -1.0, true)
			_draw_icon("close", at, Ui.WHITE)
		_:
			draw_circle(at, RADIUS, Ui.AMBER_SOFT, true, -1.0, true)
			_draw_icon("wrench", at, Ui.AMBER_DARK)


## The token opened out: a pill of words running off to its right.
func _draw_words(at: Vector2, printer: PrinterStation) -> void:
	var state := _state(printer)
	var words := ""
	var ink := Ui.WHITE
	var fill := Ui.TASKBAR
	match state:
		"printing":
			words = "Printing · %d%%" % roundi(printer.job.progress * 100.0) if printer.job != null else "Printing"
			ink = Ui.PAPER
		"done":
			words = "Ready to collect"
			fill = Ui.GREEN
		"flawed":
			words = "Ready, but flawed"
			ink = Ui.AMBER_DARK
			fill = Ui.AMBER_SOFT
		"failed":
			words = "Print failed"
			fill = Ui.RED
		_:
			words = "Needs a new %s" % state.trim_prefix("part:")
			ink = Ui.AMBER_DARK
			fill = Ui.AMBER_SOFT
	var font := Ui.font(Ui.BODY, 800)
	var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var tall := (RADIUS + 2.0) * 2.0
	var rect := Rect2(at.x - tall / 2.0, at.y - tall / 2.0, tall + 6.0 + wide + 12.0, tall)
	_worded.append(rect)
	draw_style_box(Ui.box(Ui.WHITE, int(tall / 2.0), 0, 0), rect)
	draw_style_box(Ui.box(fill, int(tall / 2.0), 0, 0), rect.grow(-2.0))
	draw_string(font, Vector2(at.x + RADIUS + 6.0, at.y + 5.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, ink)


func _draw_icon(icon_name: String, at: Vector2, colour: Color) -> void:
	var side := RADIUS * 1.25
	draw_texture_rect(_icons[icon_name], Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false, colour)
