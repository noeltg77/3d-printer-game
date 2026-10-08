extends Node3D
## Dev scene: one character per animation so they can all be checked at a glance.
## Left to right: idle, walk, carry (walking), reach (looping), sit.

const BOX := preload("res://assets/models/props/box_closed_01.glb")


func _ready() -> void:
	var carrier: CharacterRig = $Carry
	carrier.get_carry_socket().add_child(BOX.instantiate())
	_loop_reach($Reach)


func _loop_reach(rig: CharacterRig) -> void:
	while true:
		rig.reach()
		await get_tree().create_timer(CharacterRig.REACH_TIME + 0.4).timeout
