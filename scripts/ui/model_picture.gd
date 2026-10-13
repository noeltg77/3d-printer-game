class_name ModelPicture
extends TextureRect
## A picture of one of the game's 3D models, for a card or a row in a shop.
##
## The model is rendered once, from the angle the game is seen from, the first
## time a picture of it comes on screen. After that every picture of the same
## thing shares the texture, so screens that rebuild themselves cost nothing.

## Pixels rendered for each one the picture is across, so it stays sharp.
const RENDER_SCALE := 2
## How many may be rendering at once. A long catalogue fills in a few a frame.
const MAX_AT_ONCE := 4
## The game camera's angle, and the sun's (see the premises scenes).
const VIEW := Basis(Vector3(0.7071, 0, -0.7071), Vector3(-0.4082, 0.8165, -0.4082), Vector3(0.5774, 0.5774, 0.5774))
const SUN := Basis(Vector3(0.848, 0, -0.5299), Vector3(-0.3999, 0.6561, -0.64), Vector3(0.3477, 0.7547, 0.5564))
## Room left round the model, as a share of its size.
const MARGIN := 1.12
## Colours a design is shown in. Each design always gets the same ones.
const SHOW_COLOURS: Array[StringName] = [&"orange", &"sky", &"yellow", &"green", &"red", &"teal", &"pink", &"purple"]

static var _cache: Dictionary[String, Texture2D] = {}
static var _busy := 0

var _scene := ""
var _tints: Array[StringName] = []
var _rendering := false


## A picture of the model at `scene`, `pixels` across. Meshes in the tint
## material take `tints`, by part, as a printed item's do.
static func create(scene: String, pixels: int, tints: Array[StringName] = []) -> ModelPicture:
	var picture := ModelPicture.new()
	picture._scene = scene
	picture._tints = tints
	picture.custom_minimum_size = Vector2(pixels, pixels)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = _cache.get(picture._key())
	# Nothing to draw with no screen, as in a headless run.
	picture.set_process(picture.texture == null and ResourceLoader.exists(scene) and DisplayServer.get_name() != "headless")
	return picture


static func of_printer(spec: Dictionary, pixels: int) -> ModelPicture:
	return create(PrinterStation.MODEL_PATH % spec["model"]["asset"], pixels)


static func of_spool(colour: StringName, pixels: int, bulk := false) -> ModelPicture:
	return create((Spool.REEL_PATH if bulk else Spool.MODEL_PATH) % colour, pixels)


## The picture on a cream tile, for the start of a row in a shop's list.
static func tile(scene: String, pixels: int, colour: Color) -> PanelContainer:
	var node := Ui.panel(create(scene, pixels - 8), Ui.box(colour, 14, 4, 4))
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A design as it would come off the printer, each of its colours a different one.
static func of_product(product: StringName, pixels: int) -> ModelPicture:
	var tints: Array[StringName] = []
	var first := absi(hash(product))
	for part in Multicolour.colours_of(Game.data.products[product]):
		tints.append(SHOW_COLOURS[(first + part * 3) % SHOW_COLOURS.size()])
	return create(PrintedItem.MODEL_PATH % product, pixels, tints)


func _process(_delta: float) -> void:
	if _busy >= MAX_AT_ONCE or not is_visible_in_tree() or not get_global_rect().intersects(get_viewport_rect()):
		return
	set_process(false)
	texture = _cache.get(_key())
	if texture == null:
		_render()


func _notification(what: int) -> void:
	# Freed part way through a render: the wait below never comes back.
	if what == NOTIFICATION_PREDELETE and _rendering:
		_busy -= 1


func _key() -> String:
	return "%s|%s|%d" % [_scene, ",".join(_tints), int(custom_minimum_size.x)]


func _render() -> void:
	_rendering = true
	_busy += 1
	var viewport := SubViewport.new()
	viewport.size = Vector2i(custom_minimum_size) * RENDER_SCALE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 0.9, 0.8)
	environment.ambient_light_energy = 0.6
	var sun := DirectionalLight3D.new()
	sun.basis = SUN
	sun.light_color = Color(1, 0.94, 0.85)
	var model: Node3D = (load(_scene) as PackedScene).instantiate()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.environment = environment
	for node: Node3D in [sun, model, camera]:
		viewport.add_child(node)

	# Frame the model: its box, measured across and up as the camera sees it.
	var box := AABB()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for index in meshes.size():
		var mesh: MeshInstance3D = meshes[index]
		if not _tints.is_empty():
			mesh.set_instance_shader_parameter(&"tint", Palette.colour(_tints[mini(PrintedItem.part_of(mesh.name), _tints.size() - 1)]))
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if index == 0 else box.merge(part)
	var centre := box.get_center()
	var reach := 0.01
	for corner in 8:
		var seen := (box.get_endpoint(corner) - centre) * VIEW
		reach = maxf(reach, maxf(absf(seen.x), absf(seen.y)))
	camera.size = reach * 2.0 * MARGIN
	camera.transform = Transform3D(VIEW, centre + VIEW.z * 20.0)
	camera.far = 60.0

	await RenderingServer.frame_post_draw
	texture = ImageTexture.create_from_image(viewport.get_texture().get_image())
	_cache[_key()] = texture
	viewport.queue_free()
	_rendering = false
	_busy -= 1
