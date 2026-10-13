class_name VolumeControls
extends VBoxContainer
## The player's two volumes, music and sounds, each a row of steps to click.
## Goes wherever settings are shown: the main menu, the pause menu and the
## PC's Settings app. It sets them through Sound, which remembers them.

const STEPS := 5
const ROWS := [["Music", Sound.MUSIC], ["Sounds", Sound.SFX]]


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_build()


func _build() -> void:
	Ui.clear(self)
	for row: Array in ROWS:
		var steps := Ui.steps(int(round(Sound.level(row[1]) * STEPS)), STEPS, Ui.ORANGE, _pick.bind(row[1]))
		add_child(Ui.hbox([Ui.width(Ui.text(row[0], 15, Ui.INK, 800), 84), steps], 12))


func _pick(step: int, bus: StringName) -> void:
	Sound.set_level(bus, float(step) / STEPS)
	_build()
