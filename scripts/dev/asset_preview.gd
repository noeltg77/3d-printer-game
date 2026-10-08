extends Node3D
## Dev scene: lines up every generated model under an isometric camera and warm
## lighting, to check assets look right in engine with the shared palette.
##
## Optional user args (after `--`):
##   --shot=<png path>   save a screenshot and quit

const MODELS_DIR := "res://assets/models"
const GAP := 0.3
const ISO_ROTATION := Vector3(-35.264, 45.0, 0.0)

var _bounds := AABB()


func _ready() -> void:
	_build_environment()
	_place_models()
	_build_camera()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_save_screenshot(arg.trim_prefix("--shot="))


func _place_models() -> void:
	var cursor := 0.0
	for path in _find_models(MODELS_DIR):
		var model: Node3D = (load(path) as PackedScene).instantiate()
		add_child(model)
		var aabb := _model_aabb(model)
		model.position.x = cursor - aabb.position.x
		cursor += aabb.size.x + GAP
		aabb.position.x += model.position.x
		_bounds = aabb if _bounds.size == Vector3.ZERO else _bounds.merge(aabb)


func _find_models(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for dir_name in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_models(dir_path.path_join(dir_name)))
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "glb":
			found.append(dir_path.path_join(file_name))
	return found


func _model_aabb(node: Node, aabb := AABB()) -> AABB:
	if node is MeshInstance3D:
		var mesh_aabb: AABB = node.global_transform * node.get_aabb()
		aabb = mesh_aabb if aabb.size == Vector3.ZERO else aabb.merge(mesh_aabb)
	for child in node.get_children():
		aabb = _model_aabb(child, aabb)
	return aabb


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(_bounds.size.length() * 1.2, 1.0)
	camera.rotation_degrees = ISO_ROTATION
	camera.far = 60.0
	add_child(camera)
	camera.position = _bounds.get_center() + camera.basis.z * 20.0
	camera.make_current()


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#E3D2B8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#FFE9D0")
	environment.ambient_light_energy = 0.55
	environment.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFF1DE")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50.0, 50.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#F4E9D8")
	plane.material = material
	ground.mesh = plane
	add_child(ground)


func _save_screenshot(path: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("Saved %s" % path if err == OK else "Screenshot failed: %s" % error_string(err))
	get_tree().quit(0 if err == OK else 1)
