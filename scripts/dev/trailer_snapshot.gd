extends Showcase
## Dev tool for the trailer: fits out a premises the way the main menu's
## showcase does, lets it run for a while, then writes every model in the
## room to JSON (which .glb, where, how its moving parts are posed and what
## colour its tinted meshes are) for tools/trailer/build_trailer.py to rebuild
## in Blender. Takes a screenshot beside it for reference, then quits.
##
##   godot --path . res://scenes/dev/trailer_snapshot.tscn -- --place=workshop --run=40 --out=tools/trailer/worlds/workshop.json
##
## --place     premises id (garage, small_unit, workshop, factory)
## --run       game seconds to let it run before the snapshot (at 4x speed)
## --minute    minute of the day to start at (default 540, nine o'clock)
## --printers  how many printers to fit (default as many as there is room for)
## --empty     fit nothing: the bare premises, as a new game starts
## --pc        also save the PC's apps (comma separated ids) as <out>_<app>.png

var _place := &"workshop"
var _run := 30.0
var _minute := 540.0
var _printers := -1
var _empty := false
var _out := "tools/trailer/worlds/workshop.json"
var _apps: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--place="):
			_place = StringName(value)
		elif arg.begins_with("--run="):
			_run = value.to_float()
		elif arg.begins_with("--minute="):
			_minute = value.to_float()
		elif arg.begins_with("--printers="):
			_printers = value.to_int()
		elif arg == "--empty":
			_empty = true
		elif arg.begins_with("--pc="):
			_apps = value.split(",")
		elif arg.begins_with("--out="):
			_out = value
	super._ready()


func _process(_delta: float) -> void:
	pass


func _stage() -> void:
	Game.begin_showcase(_place, CASH_PENCE)
	Game.clock.minutes = _minute
	_room = (load(Game.premises_row()["scene"]) as PackedScene).instantiate()
	for control in CONTROLS:
		if control == "PcScreen" and not _apps.is_empty():
			continue
		var node := _room.get_node_or_null(control)
		if node != null:
			_room.remove_child(node)
			node.free()
	var theirs: Camera3D = _room.get_node(^"Camera")
	_home = theirs.transform
	camera.far = theirs.far
	camera.size = theirs.size
	_room.remove_child(theirs)
	theirs.free()
	add_child(_room)
	camera.transform = _home
	camera.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _empty:
		_fill()
		_fill_more()
		var owner: Agent = get_tree().get_first_node_in_group(&"player")
		var mind := Worker.new()
		mind.name = "Worker"
		mind.own_duties = OWNER_DUTIES
		owner.add_child(mind)
	Game.changed.emit()
	reveal(0.0)
	Game.set_speed(4)
	await get_tree().create_timer(_run).timeout
	await RenderingServer.frame_post_draw
	_write()
	get_viewport().get_texture().get_image().save_png(_out.get_basename() + ".png")
	var pc := get_tree().get_first_node_in_group(&"pc_screen")
	for app in _apps:
		pc.call(&"open")
		pc.call(&"show_app", app)
		await get_tree().create_timer(1.5, true, false, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out.get_basename(), app])
	get_tree().quit()


## Beyond the showcase: more printers where there is room, and the factory's
## automation fitted.
func _fill_more() -> void:
	var bench: Workbench = get_tree().get_first_node_in_group(&"workbench")
	var models := _pick_printers()
	var colours: Array = Game.data.filaments[&"pla"]["colours"]
	var designs := _pick_designs(RandomNumberGenerator.new())
	var preset := StringName(Game.data.settings["default_preset"])
	var wanted := bench.free_spots() if _printers < 0 else maxi(_printers - (bench.total_places() - bench.free_spots()), 0)
	for index in mini(wanted, bench.free_spots()):
		var station := bench.install_printer(models[(index * 3 + 1) % models.size()])
		if station == null:
			break
		station.load_spool(Spool.create(StringName(colours[(index * 5 + 2) % colours.size()])))
		station.repeat = true
		for attempt in designs.size():
			var product := designs[(index + attempt) % designs.size()]
			if station.print_problem(product, preset) == "":
				station.start_print(product, preset)
				station.job.elapsed = station.job.duration * randf_range(0.1, 0.9)
				break
	for group in [&"conveyor", &"moulder"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.has_method(&"install"):
				node.call(&"install")


func _write() -> void:
	var cam := get_viewport().get_camera_3d()
	var objects: Array = []
	var loose: Array = []
	var lights: Array = []
	for node in _room.find_children("*", "Node3D", true, false):
		var inst := node as Node3D
		if inst.scene_file_path.ends_with(".glb"):
			if inst.is_visible_in_tree():
				objects.append(_describe(inst))
		elif inst is OmniLight3D and inst.is_visible_in_tree():
			var lamp := inst as OmniLight3D
			lights.append({"name": str(_room.get_path_to(lamp)), "position": [lamp.global_position.x, lamp.global_position.y, lamp.global_position.z],
				"colour": [lamp.light_color.r, lamp.light_color.g, lamp.light_color.b], "energy": lamp.light_energy, "range": lamp.omni_range})
		elif inst is MeshInstance3D and inst.is_visible_in_tree() and _glb_of(inst) == null:
			loose.append(str(_room.get_path_to(inst)))
	var data := {
		"place": _place,
		"minute": Game.clock.minute_of_day,
		"camera": {"transform": _xform(cam.global_transform), "size": cam.size},
		"objects": objects,
		"lights": lights,
		"loose_meshes": loose,
	}
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Wrote %s: %d models, %d loose meshes" % [_out, objects.size(), loose.size()])


func _describe(inst: Node3D) -> Dictionary:
	var parts := {}
	var hidden: Array = []
	var tints := {}
	for child in inst.find_children("*", "Node3D", true, false):
		if child.owner != inst:
			continue
		var path := str(inst.get_path_to(child))
		parts[path] = _xform(child.transform)
		if not (child as Node3D).visible:
			hidden.append(path)
		if child is MeshInstance3D:
			var tint: Variant = (child as MeshInstance3D).get_instance_shader_parameter(&"tint")
			if tint is Color:
				tints[path] = [tint.r, tint.g, tint.b]
	var owner_kind := ""
	var walk := inst.get_parent()
	while walk != null and walk != _room:
		if walk.get_script() != null:
			owner_kind = (walk.get_script() as Script).get_global_name()
			break
		walk = walk.get_parent()
	return {
		"scene": inst.scene_file_path,
		"name": str(_room.get_path_to(inst)),
		"kind": owner_kind,
		"transform": _xform(inst.global_transform),
		"parts": parts,
		"hidden": hidden,
		"tints": tints,
	}


func _glb_of(node: Node) -> Node:
	var walk := node.get_parent()
	while walk != null:
		if walk is Node3D and (walk as Node3D).scene_file_path.ends_with(".glb"):
			return walk
		walk = walk.get_parent()
	return null


## Basis columns then origin, in Godot's axes.
func _xform(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
