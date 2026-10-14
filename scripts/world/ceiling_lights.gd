class_name CeilingLights
extends Node3D
## Strip lights hung in rows across the whole floor, so every corner of the
## premises is lit, by day and by night. The rows are laid out from the floor
## the character can walk on (the scene's FloorGrid), about `spacing` apart,
## each fitting hanging from the ceiling with a light just under it.
##
## They stay on at the same brightness whatever the hour. The lamps that
## DayNight brightens after dark (over the bench, on the desk) add to them.
## After dark the fittings' diffusers (their `glow_*` meshes) glow softly too,
## as far as DayNight.darkness says it is dark.
##
## Purely for looks. Nothing in the simulation depends on it.

const MODEL := preload("res://assets/models/props/ceiling_light.glb")
## How far below the ceiling the light hangs: the fitting's cables and housing.
const DROP := 0.16

## Height of the ceiling the fittings hang from, in metres.
@export var ceiling := 2.6
## About how far apart the fittings are, in metres, both ways.
@export var spacing := 2.6
@export var energy := 0.85
@export var colour := Color(1.0, 0.93, 0.8)
## How far each light reaches, as a multiple of the spacing, so neighbours overlap.
const REACH := 1.65
## How brightly a diffuser glows at full dark: enough to read as lit, not a bloom.
const GLOW := 0.6
const GLOW_COLOUR := Color(1.0, 0.95, 0.85)

## One material shared by every diffuser, so the glow is set once a frame.
var _glow: StandardMaterial3D = null


func _ready() -> void:
	add_to_group(&"ceiling_lights")
	# The floor grid has to have measured the room first.
	_hang.call_deferred()


## Where each fitting hangs, as points on the floor: a grid evenly spread over `area`.
static func layout(area: Rect2, gap: float) -> Array[Vector2]:
	var columns := maxi(ceili(area.size.x / gap), 1)
	var rows := maxi(ceili(area.size.y / gap), 1)
	var points: Array[Vector2] = []
	for row in rows:
		for column in columns:
			points.append(area.position + Vector2((column + 0.5) * area.size.x / columns, (row + 0.5) * area.size.y / rows))
	return points


func _process(_delta: float) -> void:
	if _glow != null:
		_glow.emission_energy_multiplier = GLOW * DayNight.darkness(Game.clock.minute_of_day / 60.0)


func _hang() -> void:
	var grid: FloorGrid = get_tree().get_first_node_in_group(&"floor_grid")
	if grid == null:
		return
	for point in CeilingLights.layout(grid.area, spacing):
		var fitting: Node3D = MODEL.instantiate()
		add_child(fitting)
		for diffuser: MeshInstance3D in fitting.find_children("glow_*", "MeshInstance3D", true, false):
			if _glow == null:
				_glow = diffuser.get_active_material(0).duplicate()
				_glow.emission_enabled = true
				_glow.emission = GLOW_COLOUR
			diffuser.material_override = _glow
		fitting.global_position = Vector3(point.x, ceiling, point.y)
		var light := OmniLight3D.new()
		light.light_color = colour
		light.light_energy = energy
		light.omni_range = spacing * REACH
		light.omni_attenuation = 0.8
		add_child(light)
		light.global_position = Vector3(point.x, ceiling - DROP - 0.05, point.y)
