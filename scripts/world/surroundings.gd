class_name Surroundings
extends Node3D
## Goes on the outdoor model round a premises (tools/generators/outdoors.py) and
## brings it to life: street lamps and windows that come on as it gets dark,
## traffic on the road, and a van that pulls up when the courier calls.
##
## Purely for looks. Nothing in the simulation depends on it.

const LAMP_COLOUR := Color(1.0, 0.82, 0.55)
const WINDOW_COLOUR := Color(1.0, 0.76, 0.42)
const LAMP_ENERGY := 3.5
const LAMP_RANGE := 9.0
## How dark it has to be before lights go on, on DayNight's scale.
const LIGHTS_ON := 0.45
## How long a light takes to come on or go off, in seconds.
const SWITCH_TIME := 1.5
## Hours households go to bed and get up between. Each building picks its own.
const BEDTIME := Vector2(21.5, 24.5)
const WAKING := Vector2(5.5, 7.0)
## Metres over which a van slows to a stop, and how long it waits at the kerb.
const BRAKING := 5.0
const KERB_WAIT := 6.0

## Cars that drive past, picked at random.
@export var vehicles: Array[PackedScene] = []
## What pulls up when the courier calls.
@export var courier_van: PackedScene
## Metres a second.
@export var traffic_speed := 5.0
## Shortest and longest wait between vehicles in a lane by day, in seconds.
## Nights are quieter.
@export var traffic_gap := Vector2(5.0, 16.0)


## One side of the road, and whatever is driving along it.
class Lane:
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	var wait := 0.0
	var vehicle: Node3D
	var travelled := 0.0
	## Distance along the lane the vehicle stops at, or a negative number to drive straight through.
	var stop := -1.0
	var parked := 0.0
	## How far a stopping vehicle moves over to reach the kerb.
	var pull_in := Vector3.ZERO


## A building's windows, and the hours someone is up to light them.
class Household:
	var material: StandardMaterial3D
	var wakes := 0.0
	var sleeps := 0.0


var _lanes: Array[Lane] = []
var _households: Array[Household] = []
var _lamps: Array[OmniLight3D] = []
var _lamp_material: StandardMaterial3D
var _kerb_stop: Node3D
var _courier_due := false


func _ready() -> void:
	_kerb_stop = find_child("kerb_stop", true, false)
	for glow: MeshInstance3D in find_children("glow_*", "MeshInstance3D", true, false):
		if glow.name.begins_with("glow_windows"):
			var household := Household.new()
			household.material = _glowing(glow, WINDOW_COLOUR)
			household.wakes = randf_range(WAKING.x, WAKING.y)
			household.sleeps = randf_range(BEDTIME.x, BEDTIME.y)
			_households.append(household)
		else:
			_lamp_material = _glowing(glow, LAMP_COLOUR, _lamp_material)
	for marker: Node3D in find_children("lamp_*", "Node3D", true, false):
		var lamp := OmniLight3D.new()
		lamp.light_color = LAMP_COLOUR
		lamp.omni_range = LAMP_RANGE
		marker.add_child(lamp)
		_lamps.append(lamp)
	var number := 1
	while find_child("lane_%d_start" % number, true, false) != null:
		var lane := Lane.new()
		lane.start = (find_child("lane_%d_start" % number, true, false) as Node3D).position
		lane.end = (find_child("lane_%d_end" % number, true, false) as Node3D).position
		lane.wait = randf_range(0.0, traffic_gap.y)
		_lanes.append(lane)
		number += 1
	Game.courier_arrived.connect(_on_courier_arrived)
	_light(1.0)


func _process(delta: float) -> void:
	_light(clampf(delta / SWITCH_TIME, 0.0, 1.0))
	for lane in _lanes:
		if lane.vehicle == null:
			lane.wait -= delta
			if lane.wait <= 0.0:
				_send(lane)
		else:
			_drive(lane, delta)


func _on_courier_arrived() -> void:
	_courier_due = true


## Moves every light `step` of the way (0 to 1) towards where it should be now.
func _light(step: float) -> void:
	var hour := Game.clock.minute_of_day / 60.0
	var dark := DayNight.darkness(hour) > LIGHTS_ON
	var lamps := 1.0 if dark else 0.0
	if _lamp_material != null:
		_lamp_material.emission_energy_multiplier = lerpf(_lamp_material.emission_energy_multiplier, lamps * 2.0, step)
	for lamp in _lamps:
		lamp.light_energy = lerpf(lamp.light_energy, lamps * LAMP_ENERGY, step)
		lamp.visible = lamp.light_energy > 0.01
	for household in _households:
		# Bedtime can be past midnight, so the small hours count as late the night before.
		var up := (hour >= household.wakes and hour < household.sleeps) or hour + 24.0 < household.sleeps
		var glow := 1.4 if dark and up else 0.0
		household.material.emission_energy_multiplier = lerpf(household.material.emission_energy_multiplier, glow, step)


## Gives a mesh a copy of its material that can glow, or `shared` if there is one already.
func _glowing(mesh: MeshInstance3D, colour: Color, shared: StandardMaterial3D = null) -> StandardMaterial3D:
	var material := shared
	if material == null:
		material = mesh.get_active_material(0).duplicate()
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 0.0
	mesh.material_override = material
	return material


func _send(lane: Lane) -> void:
	var heading := lane.start.direction_to(lane.end)
	var scene: PackedScene = null
	lane.stop = -1.0
	lane.pull_in = Vector3.ZERO
	# The courier comes down the near side, which is the first lane.
	if lane == _lanes[0] and _courier_due and courier_van != null and _kerb_stop != null:
		_courier_due = false
		scene = courier_van
		var to_kerb := _kerb_stop.position - lane.start
		lane.stop = to_kerb.dot(heading)
		lane.pull_in = to_kerb - heading * lane.stop
		lane.parked = KERB_WAIT
	elif not vehicles.is_empty():
		scene = vehicles.pick_random()
	if scene == null:
		lane.wait = traffic_gap.y
		return
	lane.vehicle = scene.instantiate()
	lane.travelled = 0.0
	add_child(lane.vehicle)
	for glow: MeshInstance3D in lane.vehicle.find_children("glow_*", "MeshInstance3D", true, false):
		_lamp_material = _glowing(glow, LAMP_COLOUR, _lamp_material)
	lane.vehicle.basis = Basis.looking_at(heading, Vector3.UP, true)
	_drive(lane, 0.0)


func _drive(lane: Lane, delta: float) -> void:
	var speed := traffic_speed
	var at_kerb := 0.0
	if lane.stop >= 0.0:
		var to_go := absf(lane.stop - lane.travelled)
		at_kerb = 1.0 - smoothstep(0.0, BRAKING * 2.0, to_go)
		# Slows into the stop, waits, then picks up speed again.
		speed *= clampf(to_go / BRAKING, 0.1, 1.0)
		if lane.parked > 0.0 and to_go < 0.05:
			speed = 0.0
			lane.parked -= delta
	lane.travelled += speed * delta
	lane.vehicle.position = lane.start.move_toward(lane.end, lane.travelled) + lane.pull_in * at_kerb
	if lane.travelled >= lane.start.distance_to(lane.end):
		lane.vehicle.queue_free()
		lane.vehicle = null
		# Fewer cars about after dark.
		var quiet := 1.0 + 3.0 * DayNight.darkness(Game.clock.minute_of_day / 60.0)
		lane.wait = randf_range(traffic_gap.x, traffic_gap.y) * quiet
