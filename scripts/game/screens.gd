extends CanvasLayer
## Autoload: the screens that belong to no one scene. It swaps scenes behind
## the loading screen (Screens.go), and keeps the pause menu that Escape opens
## while a game is being played. Being an autoload it hears Escape last, after
## any card, dialog or PC app that wanted it.

const MENU := "res://scenes/menu/main_menu.tscn"
## Real seconds the loading screen stays up at the least, so it reads as a
## screen and not a flicker.
const MIN_SECONDS := 1.2
const FADE_SECONDS := 0.3

## True from the start of a swap until the new scene is showing.
var busy := false
## The menu's opening has been played once this session.
var seen_splash := false

var _loading: LoadingScreen
var _pause: PauseMenu


func _ready() -> void:
	layer = 20
	_pause = PauseMenu.new()
	add_child(_pause)
	_loading = LoadingScreen.new()
	_loading.visible = false
	add_child(_loading)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not busy and in_game():
		_pause.toggle()
		get_viewport().set_input_as_handled()


## True while a saved game's scene is the one running.
func in_game() -> bool:
	return get_tree().get_first_node_in_group(&"world_save") != null


## True while the pause menu or the loading screen is over the game.
func covering() -> bool:
	return _pause.visible or _loading.visible


func open_pause_menu() -> void:
	if not busy and in_game():
		_pause.open()


## Swaps to another scene behind the loading screen. `before` is called once
## the window is covered and the old scene has stopped saving: the place to
## point the Game at a different save.
func go(scene: String, caption := "Loading", before := Callable()) -> void:
	if busy:
		return
	busy = true
	_pause.close(false)
	_loading.start(caption)
	_loading.modulate.a = 0.0
	_loading.visible = true
	await _fade(1.0)
	for world: WorldSave in get_tree().get_nodes_in_group(&"world_save"):
		world.retire()
	if before.is_valid():
		before.call()
	ResourceLoader.load_threaded_request(scene)
	var began := Time.get_ticks_msec()
	var progress: Array = []
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while true:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene, progress)
		var timed := (Time.get_ticks_msec() - began) / (MIN_SECONDS * 1000.0)
		var loaded: float = progress[0] if not progress.is_empty() else 0.0
		_loading.set_progress(minf(loaded, timed))
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and timed >= 1.0:
			break
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))
	else:
		get_tree().change_scene_to_file(scene)
	# The new scene restores its save a frame after it is ready.
	for frame in 4:
		await get_tree().process_frame
	await _fade(0.0)
	_loading.visible = false
	busy = false


func _fade(to: float) -> void:
	var fade := Ui.tween(self)
	fade.tween_property(_loading, "modulate:a", to, FADE_SECONDS)
	await fade.finished
