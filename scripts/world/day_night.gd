class_name DayNight
extends Node
## Lights the premises by the game clock: a warm sun through the day, orange at
## dawn and dusk, then a blue night where the lamps do the work. Also owns the
## light that falls in through the window.
##
## Purely for looks. Nothing in the simulation depends on it.

## The look at points through the day, by hour. Each moment blends into the next,
## and the last wraps round to the first.
##   sun, ambient: [energy, colour]   backdrop: colour past the edge of the world
##   lamps: how bright the lamps are, times their energy in the scene
##   window: [energy, colour]
const MOMENTS: Array[Dictionary] = [
	{"hour": 0.0, "sun": [0.1, Color(0.55, 0.65, 1.0)], "ambient": [0.33, Color(0.62, 0.7, 1.0)],
		"backdrop": Color(0.07, 0.08, 0.16), "lamps": 1.5, "window": [0.35, Color(0.6, 0.72, 1.0)]},
	{"hour": 5.5, "sun": [0.1, Color(0.55, 0.65, 1.0)], "ambient": [0.33, Color(0.62, 0.7, 1.0)],
		"backdrop": Color(0.07, 0.08, 0.16), "lamps": 1.5, "window": [0.35, Color(0.6, 0.72, 1.0)]},
	{"hour": 7.0, "sun": [0.5, Color(1.0, 0.76, 0.56)], "ambient": [0.36, Color(1.0, 0.86, 0.8)],
		"backdrop": Color(0.4, 0.31, 0.37), "lamps": 1.1, "window": [1.3, Color(1.0, 0.74, 0.5)]},
	{"hour": 9.0, "sun": [0.9, Color(1.0, 0.94, 0.85)], "ambient": [0.45, Color(1.0, 0.9, 0.8)],
		"backdrop": Color(0.24, 0.25, 0.33), "lamps": 1.0, "window": [1.6, Color(1.0, 0.95, 0.85)]},
	{"hour": 16.5, "sun": [0.9, Color(1.0, 0.94, 0.85)], "ambient": [0.45, Color(1.0, 0.9, 0.8)],
		"backdrop": Color(0.24, 0.25, 0.33), "lamps": 1.0, "window": [1.6, Color(1.0, 0.95, 0.85)]},
	{"hour": 18.5, "sun": [0.42, Color(1.0, 0.62, 0.42)], "ambient": [0.36, Color(1.0, 0.8, 0.7)],
		"backdrop": Color(0.38, 0.25, 0.29), "lamps": 1.35, "window": [1.2, Color(1.0, 0.6, 0.36)]},
	{"hour": 20.5, "sun": [0.1, Color(0.55, 0.65, 1.0)], "ambient": [0.33, Color(0.62, 0.7, 1.0)],
		"backdrop": Color(0.07, 0.08, 0.16), "lamps": 1.5, "window": [0.35, Color(0.6, 0.72, 1.0)]},
]
const HOURS_IN_DAY := 24.0

@export var sun_path: NodePath
@export var environment_path: NodePath
## Lamps that brighten as it gets dark. Their energy in the scene is the daytime level.
@export var lamp_paths: Array[NodePath] = []
## Where the window is, and the spot on the floor its light falls on.
@export var window_position := Vector3(1.5, 1.9, -2.35)
@export var window_target := Vector3(1.1, 0.0, -0.5)

var _sun: DirectionalLight3D
var _environment: Environment
var _lamps: Array[Light3D] = []
var _lamp_day_energy: Array[float] = []
var _window := SpotLight3D.new()


func _ready() -> void:
	_sun = get_node(sun_path)
	_environment = (get_node(environment_path) as WorldEnvironment).environment
	for path in lamp_paths:
		var lamp: Light3D = get_node(path)
		_lamps.append(lamp)
		_lamp_day_energy.append(lamp.light_energy)
	_window.spot_range = 6.0
	_window.spot_angle = 34.0
	_window.spot_attenuation = 0.6
	add_child(_window)
	_window.look_at_from_position(window_position, window_target)
	_apply()


func _process(_delta: float) -> void:
	_apply()


## How dark it is at `hour`, from 0 in daylight to 1 at night. Lamps come on with it.
static func darkness(hour: float) -> float:
	var look := _look(hour)
	return clampf(inverse_lerp(1.0, 1.5, lerpf(look[0]["lamps"], look[1]["lamps"], look[2])), 0.0, 1.0)


## The two moments `hour` falls between, then how far it is from the first to the second.
static func _look(hour: float) -> Array:
	var from := MOMENTS[-1]
	var to := MOMENTS[0]
	for index in MOMENTS.size():
		if float(MOMENTS[index]["hour"]) <= hour:
			from = MOMENTS[index]
			to = MOMENTS[(index + 1) % MOMENTS.size()]
	var span := fposmod(float(to["hour"]) - float(from["hour"]), HOURS_IN_DAY)
	var blend := clampf((hour - float(from["hour"])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return [from, to, blend]


func _apply() -> void:
	var look := _look(Game.clock.minute_of_day / 60.0)
	var from: Dictionary = look[0]
	var to: Dictionary = look[1]
	var blend: float = look[2]
	_sun.light_energy = lerpf(from["sun"][0], to["sun"][0], blend)
	_sun.light_color = (from["sun"][1] as Color).lerp(to["sun"][1], blend)
	_environment.ambient_light_energy = lerpf(from["ambient"][0], to["ambient"][0], blend)
	_environment.ambient_light_color = (from["ambient"][1] as Color).lerp(to["ambient"][1], blend)
	_environment.background_color = (from["backdrop"] as Color).lerp(to["backdrop"], blend)
	_window.light_energy = lerpf(from["window"][0], to["window"][0], blend)
	_window.light_color = (from["window"][1] as Color).lerp(to["window"][1], blend)
	var lamps := lerpf(from["lamps"], to["lamps"], blend)
	for index in _lamps.size():
		_lamps[index].light_energy = _lamp_day_energy[index] * lamps
