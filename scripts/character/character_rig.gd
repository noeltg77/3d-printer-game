class_name CharacterRig
extends Node3D
## Procedural animation for the segmented character model (tools/generators/character.py).
## Each frame it works out a target rotation for every joint from the current pose
## and eases towards it, so changing pose blends smoothly with no animation clips.
##
## The model faces +Z. A limb hangs down its -Y axis, so a negative X rotation
## swings it forwards and a positive one swings it back.

## Emitted at the top of a reach, the moment to pick up or put down an item.
signal reach_peaked

enum Pose { IDLE, WALK, SIT }

const JOINT_NAMES: Array[StringName] = [
	&"body", &"head",
	&"arm_l", &"arm_r", &"forearm_l", &"forearm_r",
	&"leg_l", &"leg_r", &"shin_l", &"shin_r",
]
const BLEND_SPEED := 12.0
## Stride phase in radians per second. One full stride is TAU.
const WALK_RATE := 9.0
const REACH_TIME := 0.7
## How far the hips drop onto a 0.4 m seat.
const SIT_DROP := 0.13

@export var pose := Pose.IDLE
## Arms hold an item in front of the chest. Attach it to `carry_socket`.
@export var carrying := false
## Replaces the Model child at startup, for colour variants.
@export var model_override: PackedScene

var _joints: Dictionary[StringName, Node3D] = {}
var _body_rest := Vector3.ZERO
var _body_offset := Vector3.ZERO
var _time := 0.0
var _reach_left := 0.0
var _reach_peak_sent := true


func _ready() -> void:
	if model_override != null:
		$Model.free()
		var model := model_override.instantiate()
		model.name = "Model"
		add_child(model)
	for joint_name in JOINT_NAMES:
		_joints[joint_name] = $Model.find_child(joint_name, true, false)
	_body_rest = _joints[&"body"].position
	# Start each character at a different point so a group doesn't move in sync.
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	var target := _pose_target()
	if _reach_left > 0.0:
		_reach_left -= delta
		_apply_reach(target)
	var weight := 1.0 - exp(-BLEND_SPEED * delta)
	for joint_name in _joints:
		var joint := _joints[joint_name]
		joint.rotation = joint.rotation.lerp(target.get(joint_name, Vector3.ZERO), weight)
	var body := _joints[&"body"]
	body.position = body.position.lerp(_body_rest + _body_offset, weight)


## Plays a one-shot reach forwards with both arms, over whatever pose is active.
func reach() -> void:
	_reach_left = REACH_TIME
	_reach_peak_sent = false


## Node to parent a carried item to.
func get_carry_socket() -> Node3D:
	return $Model.find_child("carry_socket", true, false)


func _pose_target() -> Dictionary[StringName, Vector3]:
	var target: Dictionary[StringName, Vector3] = {}
	_body_offset = Vector3.ZERO
	match pose:
		Pose.IDLE:
			var breath := sin(_time * 2.0)
			_body_offset.y = breath * 0.006
			target[&"head"] = Vector3(breath * 0.02, sin(_time * 0.7) * 0.15, 0.0)
			target[&"arm_l"] = Vector3(0.0, 0.0, 0.07 + breath * 0.02)
			target[&"arm_r"] = Vector3(0.0, 0.0, -0.07 - breath * 0.02)
		Pose.WALK:
			var phase := _time * WALK_RATE
			var swing := sin(phase)
			_body_offset.y = absf(cos(phase)) * 0.025
			target[&"body"] = Vector3(0.06, 0.0, swing * 0.03)
			target[&"head"] = Vector3(-0.04, 0.0, -swing * 0.03)
			target[&"leg_l"] = Vector3(-swing * 0.65, 0.0, 0.0)
			target[&"leg_r"] = Vector3(swing * 0.65, 0.0, 0.0)
			# The knee bends while its leg is travelling forwards.
			target[&"shin_l"] = Vector3(maxf(cos(phase), 0.0) * 0.9, 0.0, 0.0)
			target[&"shin_r"] = Vector3(maxf(-cos(phase), 0.0) * 0.9, 0.0, 0.0)
			target[&"arm_l"] = Vector3(swing * 0.5, 0.0, 0.05)
			target[&"arm_r"] = Vector3(-swing * 0.5, 0.0, -0.05)
			target[&"forearm_l"] = Vector3(-0.25, 0.0, 0.0)
			target[&"forearm_r"] = Vector3(-0.25, 0.0, 0.0)
		Pose.SIT:
			var tap := sin(_time * 13.0) * 0.07
			_body_offset.y = -SIT_DROP
			target[&"head"] = Vector3(0.08, sin(_time * 0.5) * 0.08, 0.0)
			target[&"leg_l"] = Vector3(-1.4, 0.0, 0.0)
			target[&"leg_r"] = Vector3(-1.4, 0.0, 0.0)
			target[&"shin_l"] = Vector3(1.4, 0.0, 0.0)
			target[&"shin_r"] = Vector3(1.4, 0.0, 0.0)
			target[&"arm_l"] = Vector3(-0.9, 0.0, 0.0)
			target[&"arm_r"] = Vector3(-0.9, 0.0, 0.0)
			target[&"forearm_l"] = Vector3(-0.85 + tap, 0.0, 0.0)
			target[&"forearm_r"] = Vector3(-0.85 - tap, 0.0, 0.0)
	if carrying and pose != Pose.SIT:
		target[&"arm_l"] = Vector3(-0.45, 0.0, 0.0)
		target[&"arm_r"] = Vector3(-0.45, 0.0, 0.0)
		target[&"forearm_l"] = Vector3(-1.05, 0.0, 0.0)
		target[&"forearm_r"] = Vector3(-1.05, 0.0, 0.0)
	return target


func _apply_reach(target: Dictionary[StringName, Vector3]) -> void:
	# Rises to 1 at the midpoint and falls back to 0.
	var lift := sin((1.0 - maxf(_reach_left, 0.0) / REACH_TIME) * PI)
	for side: String in ["l", "r"]:
		var arm := StringName("arm_" + side)
		var forearm := StringName("forearm_" + side)
		target[arm] = target.get(arm, Vector3.ZERO).lerp(Vector3(-1.45, 0.0, 0.0), lift)
		target[forearm] = target.get(forearm, Vector3.ZERO).lerp(Vector3(-0.2, 0.0, 0.0), lift)
	target[&"body"] = target.get(&"body", Vector3.ZERO) + Vector3(0.18 * lift, 0.0, 0.0)
	if not _reach_peak_sent and _reach_left <= REACH_TIME / 2.0:
		_reach_peak_sent = true
		reach_peaked.emit()
