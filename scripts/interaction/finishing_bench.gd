class_name FinishingBench
extends Interactable
## The finishing bench: a print off the shelf is gone over with the blowtorch,
## which takes off the wisps and whitened marks and leaves it a better finish
## (the `finishing` rules in data/game.json). It goes back on the shelf after.
##
## The model's `work_spot` marker is where the print sits, and its `torch`
## object, with a `flame` beneath it, is picked up off its stand and played
## over the print while the work is done.

## Where the torch is held, from the work spot, and how far it wanders.
const TORCH_HOLD := Vector3(0.17, 0.17, 0.02)
const TORCH_SWAY := 0.035
const TORCH_SECONDS := 0.25
const FLAME_LIGHT := Color("FF9A3C")

var _work_spot: Node3D = null
var _torch: Node3D = null
var _flame: Node3D = null
var _light: OmniLight3D = null
var _torch_rest := Vector3.ZERO
var _lit := false
var _time := 0.0


func _ready() -> void:
	super()
	add_to_group(&"finishing_bench")
	_work_spot = find_child("work_spot", true, false)
	_torch = find_child("torch", true, false)
	_flame = find_child("flame", true, false)
	_torch_rest = _torch.position
	_flame.visible = false
	# The flame shows at its own brightness, whatever the light in the room.
	var glow := (preload("res://assets/materials/palette_flat.tres") as StandardMaterial3D).duplicate() as StandardMaterial3D
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in _flame.find_children("*", "MeshInstance3D", true, false) + ([_flame] if _flame is MeshInstance3D else []):
		mesh.material_override = glow
	_light = OmniLight3D.new()
	_light.light_color = FLAME_LIGHT
	_light.omni_range = 1.2
	_light.visible = false
	_flame.add_sibling(_light)
	_light.position = _flame.position


func _process(delta: float) -> void:
	if not _lit:
		return
	_time += delta
	# The flame gutters and the hand moves it back and forth over the print.
	var flicker := 0.85 + 0.15 * sin(_time * 31.0) + 0.1 * sin(_time * 47.0)
	_flame.scale = Vector3(1.0, flicker, 1.0)
	_light.light_energy = 0.8 * flicker
	_torch.position = _hold_point() + Vector3(sin(_time * 4.0), 0.0, cos(_time * 2.7)) * TORCH_SWAY


func get_actions(_agent: Agent) -> Array[Action]:
	var shelf := _shelf()
	var waiting: Dictionary[StringName, int] = {}
	for item in shelf.unfinished():
		waiting[item.product] = int(waiting.get(item.product, 0)) + 1
	if waiting.is_empty():
		return [Action.info("Finish a print (nothing on the shelf needs it)")]
	var actions: Array[Action] = []
	var total := 0
	for product in waiting:
		total += waiting[product]
		var action := Action.new("Finish %s (%d waiting)" % [Game.product_name(product), waiting[product]], _finish.bind(product)).for_duty(&"finish")
		action.task_name = "Finish a %s" % Game.product_name(product)
		actions.append(action)
	if total > 1:
		var every := Action.new("Finish everything on the shelf (%d)" % total, _finish_all)
		every.task_name = "Finish everything on the shelf"
		actions.append(every)
	return actions


func _finish_all(agent: Agent) -> void:
	while not _shelf().unfinished().is_empty():
		await _finish(agent, _shelf().unfinished()[0].product)


## Fetches one unfinished print of a design, torches it and puts it back.
func _finish(agent: Agent, product: StringName) -> void:
	var shelf := _shelf()
	if shelf.unfinished().filter(func(item: PrintedItem) -> bool: return item.product == product).is_empty():
		agent.say("Nothing left to finish")
		return
	var waiting := shelf.unfinished().filter(func(candidate: PrintedItem) -> bool: return candidate.product == product)
	await agent.go_to(shelf.spot(product) if waiting.is_empty() else shelf.spot_of(waiting[0]))
	await agent.reach(func() -> void: agent.carry(shelf.take_unfinished(product)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	var item := agent.carried as PrintedItem
	await agent.reach(func() -> void: Interactable.attach(agent.release(), _work_spot))
	await _move_torch(_hold_point())
	_set_lit(true)
	await agent.work(float(Game.data.settings["finishing"]["minutes"]))
	_set_lit(false)
	item.finish()
	await _move_torch(_torch_rest)
	await agent.reach(func() -> void: agent.carry(item))
	await agent.go_to(shelf.spot(item))
	await agent.reach(func() -> void:
		if not shelf.store(agent.release()):
			# Its space was taken while it was away: it has to go somewhere.
			Game.notify("No room on the shelving for the finished %s, so it was binned" % Game.product_name(product), &"bad")
			item.queue_free())


func _set_lit(on: bool) -> void:
	_lit = on
	_flame.visible = on
	_light.visible = on
	_flame.scale = Vector3.ONE


func _move_torch(to: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(_torch, "position", to, TORCH_SECONDS)
	await tween.finished


## Where the torch is held over the work spot, in the torch's parent's space.
func _hold_point() -> Vector3:
	var parent := _torch.get_parent() as Node3D
	return parent.to_local(_work_spot.global_transform * TORCH_HOLD)


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")
