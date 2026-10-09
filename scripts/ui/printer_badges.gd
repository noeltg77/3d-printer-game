class_name PrinterBadges
extends Control
## Small status badges that float over each printer in the garage view: how far
## a print has got, or that the printer is waiting for the player. Saves opening
## a printer's menu just to see how it is doing.

## How far above a printer's base its badge sits, in metres.
const LIFT := 0.92
const BAR_WIDTH := 64.0

## Printer -> { badge, state, bar }.
var _badges: Dictionary[PrinterStation, Dictionary] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for printer: PrinterStation in _badges.keys():
		if not is_instance_valid(printer):
			(_badges[printer]["badge"] as Control).queue_free()
			_badges.erase(printer)
	if camera == null:
		return
	for printer: PrinterStation in get_tree().get_nodes_in_group(&"printer"):
		var state := _state(printer)
		if not _badges.has(printer) or _badges[printer]["state"] != state:
			_rebuild(printer, state)
		var entry := _badges[printer]
		var badge: Control = entry["badge"]
		badge.visible = state != ""
		if entry["bar"] != null and printer.job != null:
			(entry["bar"] as ProgressBar).value = printer.job.progress
			(entry["label"] as Label).text = "%d%%" % roundi(printer.job.progress * 100.0)
		var point := camera.unproject_position(printer.global_position + Vector3.UP * LIFT)
		badge.position = (point - Vector2(badge.size.x / 2.0, badge.size.y)).round()


## What the badge should say, as a key that changes when the badge must.
func _state(printer: PrinterStation) -> String:
	match printer.status:
		PrinterStation.Status.PRINTING:
			return "printing"
		PrinterStation.Status.DONE:
			return "flawed" if printer.item.is_flawed() else "done"
		PrinterStation.Status.FAILED:
			return "failed"
	for slot in printer.wear.broken():
		return "part:%s" % String(printer.wear.part(slot)["slot_name"]).to_lower()
	return ""


func _rebuild(printer: PrinterStation, state: String) -> void:
	if _badges.has(printer):
		(_badges[printer]["badge"] as Control).queue_free()
	var bar: ProgressBar = null
	var label: Label = null
	var badge: Control
	if state == "printing":
		bar = Ui.bar(0.0, Ui.CASH, Ui.CHIP, 8)
		bar.custom_minimum_size.x = BAR_WIDTH
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label = Ui.text("", 13, Ui.PAPER, 800)
		badge = Ui.panel(Ui.hbox([bar, Ui.width(label, 34)], 8), Ui.box(Ui.TASKBAR, 12, 10, 5))
	elif state == "done":
		badge = Ui.pill("Ready to collect", Ui.WHITE, Ui.GREEN, 13)
	elif state == "flawed":
		badge = Ui.pill("Ready, but flawed", Ui.AMBER_DARK, Ui.AMBER_SOFT, 13)
	elif state == "failed":
		badge = Ui.pill("Print failed", Ui.WHITE, Ui.RED, 13)
	elif state.begins_with("part:"):
		badge = Ui.pill("Needs a new %s" % state.trim_prefix("part:"), Ui.AMBER_DARK, Ui.AMBER_SOFT, 13)
	else:
		badge = Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_badges[printer] = {"badge": badge, "state": state, "bar": bar, "label": label}
