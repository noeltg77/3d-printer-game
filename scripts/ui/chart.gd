class_name Chart
extends Control
## A small chart of money over a run of days, drawn in the PlateOS style: soft
## grid lines, rounded bars, amounts down the side through Money.format. Make
## one with Chart.bars() or Chart.line(). Hovering a day shows its figures.

const GUTTER_LEFT := 86.0
const GUTTER_BOTTOM := 26.0
const TOP := 10.0
const GRID_LINES := 4
const LABEL_SIZE := 12

enum Kind { BARS, LINE }

var _kind := Kind.BARS
## One per day, oldest first. Each: { label, tip } and, for bars, `values` (one
## pence amount per series); for a line, `value`.
var _points: Array[Dictionary] = []
var _colours: Array[Color] = []


## Bars side by side for each day: `points` each have `values`, one amount per
## colour in `colours`, none below zero.
static func bars(points: Array[Dictionary], colours: Array[Color], height := 220.0) -> Chart:
	return _make(Kind.BARS, points, colours, height)


## One line through each day's `value`, which may dip below zero.
static func line(points: Array[Dictionary], colour: Color, height := 220.0) -> Chart:
	return _make(Kind.LINE, points, [colour], height)


static func _make(kind: Kind, points: Array[Dictionary], colours: Array[Color], height: float) -> Chart:
	var chart := Chart.new()
	chart._kind = kind
	chart._points = points
	chart._colours = colours
	chart.custom_minimum_size.y = height
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return chart


func _draw() -> void:
	var font := Ui.font(Ui.BODY, 700)
	var plot := Rect2(GUTTER_LEFT, TOP, size.x - GUTTER_LEFT - 8.0, size.y - TOP - GUTTER_BOTTOM)
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return
	var low := 0.0
	var high := 0.0
	for point in _points:
		for value: float in _values(point):
			low = minf(low, value)
			high = maxf(high, value)
	var step := _nice((high - low) / GRID_LINES)
	high = ceilf(high / step) * step
	low = floorf(low / step) * step
	if high == low:
		high = low + step
	var y_of := func(value: float) -> float: return plot.end.y - (value - low) / (high - low) * plot.size.y

	var value := low
	while value <= high + 0.5:
		var y: float = y_of.call(value)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Ui.INK if value == 0.0 and low < 0.0 else Ui.LINE, 1.0)
		draw_string(font, Vector2(0, y + 4.0), Money.format(int(value)), HORIZONTAL_ALIGNMENT_RIGHT, GUTTER_LEFT - 10.0, LABEL_SIZE, Ui.MUTED)
		value += step

	var count := _points.size()
	if count == 0:
		return
	var slot := plot.size.x / count
	# Day labels thin out so they never run into each other.
	var every := maxi(1, ceili(46.0 / slot))
	for index in count:
		if (count - 1 - index) % every == 0:
			draw_string(font, Vector2(plot.position.x + slot * index, size.y - 6.0), String(_points[index]["label"]),
				HORIZONTAL_ALIGNMENT_CENTER, slot, LABEL_SIZE, Ui.MUTED)

	if _kind == Kind.BARS:
		var series := _colours.size()
		var wide := clampf(slot * 0.7 / series, 2.0, 22.0)
		for index in count:
			var values := _values(_points[index])
			var left := plot.position.x + slot * (index + 0.5) - wide * series / 2.0
			for each in series:
				var top: float = y_of.call(values[each])
				var base: float = y_of.call(0.0)
				if base - top >= 1.0:
					draw_style_box(Ui.box(_colours[each], int(minf(4.0, wide / 2.0)), 0, 0),
						Rect2(left + wide * each + 1.0, top, wide - 2.0, base - top))
	else:
		var path := PackedVector2Array()
		for index in count:
			path.append(Vector2(plot.position.x + slot * (index + 0.5), y_of.call(float(_points[index]["value"]))))
		# A soft fill between the line and nought, then the line and a dot a day.
		var base: float = y_of.call(0.0)
		var fill := Color(_colours[0], 0.14)
		for index in count - 1:
			var from := path[index]
			var to := path[index + 1]
			if (from.y - base) * (to.y - base) < 0.0:
				# The line crosses nought here: a triangle either side of the crossing.
				var crossing := Vector2(lerpf(from.x, to.x, (base - from.y) / (to.y - from.y)), base)
				draw_colored_polygon(PackedVector2Array([from, crossing, Vector2(from.x, base)]), fill)
				draw_colored_polygon(PackedVector2Array([crossing, to, Vector2(to.x, base)]), fill)
			elif not (is_equal_approx(from.y, base) and is_equal_approx(to.y, base)):
				draw_colored_polygon(PackedVector2Array([from, to, Vector2(to.x, base), Vector2(from.x, base)]), fill)
		if count > 1:
			draw_polyline(path, _colours[0], 3.0, true)
		for at in path:
			draw_circle(at, 4.5 if count <= 16 else 3.0, _colours[0])


func _get_tooltip(at_position: Vector2) -> String:
	if _points.is_empty() or at_position.x < GUTTER_LEFT:
		return ""
	var slot := (size.x - GUTTER_LEFT - 8.0) / _points.size()
	var index := clampi(int((at_position.x - GUTTER_LEFT) / slot), 0, _points.size() - 1)
	return _points[index].get("tip", "")


func _values(point: Dictionary) -> Array:
	return point["values"] if _kind == Kind.BARS else [point["value"]]


## The next round amount up from `raw` pence: 1, 2 or 5 times a power of ten,
## and never less than a pound, so the grid lines land on tidy figures.
static func _nice(raw: float) -> float:
	var step := 100.0
	while true:
		for multiple: float in [1.0, 2.0, 5.0]:
			if step * multiple >= raw:
				return step * multiple
		step *= 10.0
	return step
