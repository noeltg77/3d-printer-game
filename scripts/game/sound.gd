extends Node
## Autoload: everything heard. It plays the music and the UI's clicks, keeps
## the volume the player set for each, and puts the ears in the right place
## for sounds that come from things in the room (a printer running).
##
## The sounds are WAVs in assets/audio/, all made by tools/generators/audio.py.
## Name one by its path there without the extension: Sound.ui(&"click"),
## Sound.music(&"menu_theme"), Sound.looped("printer/fan_loop").

const DIR := "res://assets/audio/"
## The volumes a player can set, each a bus. Printers and the like are "Sfx".
const MUSIC := &"Music"
const SFX := &"Sfx"
## Things in the room play on this, which feeds Sfx through a limiter, so a
## factory of printers is no louder than the mix can take.
const ROOM := &"Room"
const ROOM_DB := -2.0
## How much quieter the room is when it is only a backdrop (the main menu).
const BACKDROP_DB := -18.0
const DEFAULT_LEVELS: Dictionary[StringName, float] = {MUSIC: 0.6, SFX: 0.8}
## How many UI sounds can overlap.
const VOICES := 6
## How high over the floor the ears are, as a share of the height of the
## camera's view: zooming in on a printer brings it closer.
const EAR_HEIGHT := 0.4

var _levels: Dictionary[StringName, float] = {}
var _streams: Dictionary[String, AudioStream] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music := AudioStreamPlayer.new()
var _music_name: StringName = &""
var _fade: Tween = null
var _ears := AudioListener3D.new()


func _ready() -> void:
	# Menus are open while the game is paused, and they still want their sounds.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [MUSIC, SFX, ROOM]:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, SFX if bus == ROOM else &"Master")
	var room := AudioServer.get_bus_index(ROOM)
	AudioServer.set_bus_volume_db(room, ROOM_DB)
	AudioServer.add_bus_effect(room, AudioEffectHardLimiter.new())
	var config := ConfigFile.new()
	config.load(Game.SETTINGS_FILE)
	for bus in DEFAULT_LEVELS:
		_levels[bus] = clampf(float(config.get_value("sound", String(bus).to_lower(), DEFAULT_LEVELS[bus])), 0.0, 1.0)
		_apply(bus)
	_music.bus = MUSIC
	add_child(_music)
	for index in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX
		add_child(voice)
		_voices.append(voice)
	add_child(_ears)


func _process(_delta: float) -> void:
	# The game looks down from a long way off, at an angle, so the camera is no
	# place to listen from. The ears go over the spot it is looking at.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_ears.clear_current()
		return
	var view := camera.global_transform
	var looking_at: Variant = Plane(Vector3.UP, 0.0).intersects_ray(view.origin, -view.basis.z)
	var spot: Vector3 = looking_at if looking_at != null else view.origin
	var height := camera.size * EAR_HEIGHT if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 2.0
	_ears.global_transform = Transform3D(view.basis, spot + Vector3.UP * height)
	if not _ears.is_current():
		_ears.make_current()


## A sound by name, or null if there is no such file.
func stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
		if _streams[sound] == null:
			push_warning("Sound: no sound called '%s'" % sound)
	return _streams[sound]


## A sound that goes round and round: its own copy, set to loop end to start.
func looped(sound: String) -> AudioStream:
	var key := sound + ":loop"
	if not _streams.has(key):
		var source := stream(sound) as AudioStreamWAV
		var loop: AudioStreamWAV = null
		if source != null:
			loop = source.duplicate()
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(round(source.get_length() * source.mix_rate))
		_streams[key] = loop
	return _streams[key]


## Plays one of the sounds in assets/audio/ui.
func ui(sound: StringName, pitch := 1.0) -> void:
	var found := stream("ui/%s" % sound)
	if found == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = found
	voice.pitch_scale = pitch
	voice.play()


## Fades to a piece of music in assets/audio/music, or to silence with &"".
## Asking for what is already playing changes nothing.
func music(track: StringName, fade_seconds := 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_ignore_time_scale(true)
	if _music.playing:
		_fade.tween_property(_music, "volume_db", -60.0, fade_seconds)
	_fade.tween_callback(func() -> void:
		_music.stop()
		if track != &"":
			_music.stream = looped("music/%s" % track)
			_music.volume_db = -30.0
			_music.play())
	if track != &"":
		_fade.tween_property(_music, "volume_db", 0.0, fade_seconds)


## A sound going round on its own player, for something that lasts a while
## and isn't anywhere in the room. Hand the player to fade_out to end it.
func start_loop(sound: String, volume_db := 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = SFX
	player.stream = looped(sound)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func fade_out(player: AudioStreamPlayer, seconds := 0.4) -> void:
	if not is_instance_valid(player):
		return
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(player, "volume_db", -60.0, seconds)
	fade.tween_callback(player.queue_free)


## Turns the room down to sit behind music and a menu, or back up for play.
func set_backdrop(on: bool) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(ROOM), ROOM_DB + (BACKDROP_DB if on else 0.0))


## How loud the player has music or sounds, 0 to 1.
func level(bus: StringName) -> float:
	return _levels.get(bus, 1.0)


## Sets how loud music or sounds are, 0 to 1, and remembers it.
func set_level(bus: StringName, value: float) -> void:
	_levels[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)
	var config := ConfigFile.new()
	config.load(Game.SETTINGS_FILE)
	config.set_value("sound", String(bus).to_lower(), _levels[bus])
	config.save(Game.SETTINGS_FILE)


## How loud a bus is at this moment, in dB: -200 or so when it is silent. For
## checking in a dev run that something is playing, since a screenshot can't:
## `call>get_node("/root/Sound").peak("Music")`.
func peak(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	return maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0))


func _apply(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, _levels[bus] <= 0.0)
	# Squared, so the steps sound even: half way up is about half as loud.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(_levels[bus] * _levels[bus], 0.0001)))
