class_name PrinterSound
extends Node3D
## The noise a printer makes: goes on a PrinterStation as a child. While it
## prints, its fan runs and its motors sing; when a print comes off well it
## beeps. Every printer is pitched a little differently and starts its loop
## at a different point, so a row of them is a workshop and not a chord.
## Only for the ears: nothing reads it.

const FAN := "printer/fan_loop"
## The motor loop for each kind of motion (a printer row's `motion`).
const MOTION := {"bed_slinger": "printer/motion_a", "core_xy": "printer/motion_b"}
const DONE := "printer/done"
const FAN_DB := -9.0
const MOTION_DB := -6.0
const DONE_DB := -8.0
## Seconds to come up to full when a print starts, and to die away after.
const SWELL := 0.6

var _fan: AudioStreamPlayer3D
var _motion: AudioStreamPlayer3D = null
var _done: AudioStreamPlayer3D
## 0 silent to 1 running flat out.
var _running := 0.0
var _pitch := 1.0
var _drift := 0.0
var _was := PrinterStation.Status.IDLE

@onready var _station: PrinterStation = get_parent()


func _ready() -> void:
	position = Vector3(0.0, 0.25, 0.0)
	_pitch = randf_range(0.9, 1.12) * clampf(sqrt(float(_station.spec.get("speed_multiplier", 1.0))), 0.9, 1.25)
	_drift = randf() * TAU
	_fan = _player(Sound.looped(FAN), FAN_DB)
	_fan.pitch_scale = randf_range(0.92, 1.1)
	# A resin printer has no motors darting about: only its fan is heard.
	if MOTION.has(_station.spec["motion"]):
		_motion = _player(Sound.looped(MOTION[_station.spec["motion"]]), MOTION_DB)
	_done = _player(Sound.stream(DONE), DONE_DB)
	_was = _station.status


func _process(delta: float) -> void:
	var printing := _station.status == PrinterStation.Status.PRINTING
	_running = move_toward(_running, 1.0 if printing else 0.0, delta / SWELL)
	_drift += delta
	_run(_fan, FAN_DB, 1.0)
	if _motion != null:
		_motion.pitch_scale = _pitch * (1.0 + 0.03 * sin(_drift * 0.7))
		_run(_motion, MOTION_DB, 1.0)
	# The beep is for a print to come and collect, heard in the room and not all night.
	if _was == PrinterStation.Status.PRINTING and _station.status == PrinterStation.Status.DONE and not Game.sleeping:
		_done.play()
	_was = _station.status


## Keeps one of the loops going at the level the printer is running at, and
## holds it still while the game is paused.
func _run(player: AudioStreamPlayer3D, full_db: float, share: float) -> void:
	if player.stream == null:
		return
	if _running <= 0.0:
		player.stop()
		return
	if not player.playing:
		player.play(randf() * player.stream.get_length())
	player.stream_paused = Engine.time_scale == 0.0
	player.volume_db = full_db + linear_to_db(maxf(_running * share, 0.001))


func _player(sound: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.bus = Sound.ROOM
	player.volume_db = volume_db
	player.unit_size = 4.5
	player.max_distance = 45.0
	player.panning_strength = 0.7
	add_child(player)
	return player
