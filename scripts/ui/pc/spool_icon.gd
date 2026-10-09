class_name SpoolIcon
extends Control
## Flat front-on drawing of a filament spool in a given colour, as used on the
## shop cards and in the basket.

const RIM := Color("3B3F44")

var colour := Color.WHITE
## Colour of the card behind, showing through the hub.
var backdrop := Ui.SOFT


static func create(p_colour: Color, size: int, p_backdrop := Ui.SOFT) -> SpoolIcon:
	var icon := SpoolIcon.new()
	icon.colour = p_colour
	icon.backdrop = p_backdrop
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	# Proportions from the mock-up, which draws the spool 96 px across.
	var centre := size / 2.0
	var unit := minf(size.x, size.y) / 96.0
	draw_circle(centre, 44.0 * unit, RIM, true, -1.0, true)
	draw_circle(centre, 38.0 * unit, colour, true, -1.0, true)
	draw_circle(centre, 30.0 * unit, Color(0, 0, 0, 0.12), false, 2.0 * unit, true)
	draw_circle(centre, 22.0 * unit, Color(1, 1, 1, 0.18), false, 2.0 * unit, true)
	draw_circle(centre, 14.0 * unit, RIM, true, -1.0, true)
	draw_circle(centre, 7.0 * unit, backdrop, true, -1.0, true)
