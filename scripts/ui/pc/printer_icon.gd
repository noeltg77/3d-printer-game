class_name PrinterIcon
extends Control
## Flat isometric block drawing of a printer for the shop cards, shaded with
## the three `shop_colours` from data/printers.json.

var top := Color.WHITE
var left := Color.GRAY
var right := Color.LIGHT_GRAY


static func create(colours: Dictionary, size: int) -> PrinterIcon:
	var icon := PrinterIcon.new()
	icon.top = Color.html(colours["top"])
	icon.left = Color.html(colours["left"])
	icon.right = Color.html(colours["right"])
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	# Points from the mock-up, which draws the printer in a 120 px square.
	var unit := minf(size.x, size.y) / 120.0
	_shape([20, 30, 60, 14, 100, 30, 60, 46], top, unit)
	_shape([20, 30, 60, 46, 60, 106, 20, 90], left, unit)
	_shape([100, 30, 60, 46, 60, 106, 100, 90], right, unit)
	_shape([66, 56, 94, 44, 94, 82, 66, 94], Color(0.141, 0.188, 0.227, 0.55), unit)
	_shape([70, 80, 90, 72, 90, 78, 70, 86], Ui.ORANGE, unit)


func _shape(coordinates: Array, colour: Color, unit: float) -> void:
	var points: PackedVector2Array = []
	for index in range(0, coordinates.size(), 2):
		points.append(Vector2(coordinates[index], coordinates[index + 1]) * unit)
	draw_colored_polygon(points, colour)
