class_name PcScreen
extends CanvasLayer
## The in-game computer: a window of tabs for the business screens. Opened by
## the Computer interactable once the character is sitting at the PC.
## Each tab is a control with a refresh() method that redraws it from Game.

const TABS := {
	"Craftsy": preload("res://scripts/ui/pc_tab_market.gd"),
	"Designs": preload("res://scripts/ui/pc_tab_designs.gd"),
	"Supplier": preload("res://scripts/ui/pc_tab_supplier.gd"),
	"Bank": preload("res://scripts/ui/pc_tab_bank.gd"),
}

var _tabs: TabContainer
var _refresh_queued := false


func _ready() -> void:
	add_to_group(&"pc_screen")
	layer = 2
	visible = false

	# Dims the game and swallows clicks so nothing behind the window reacts.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for title: String in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = title
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var tab: Control = TABS[title].new()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(tab)
		_tabs.add_child(scroll)
	_tabs.tab_changed.connect(func(_index: int) -> void: refresh())

	var header := Ui.row([Ui.heading("Workshop PC"), null, Ui.button("Close", close)])
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	column.add_child(header)
	column.add_child(_tabs)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override(&"panel", Ui.panel_style(0.97))
	window.add_child(column)
	dim.add_child(window)
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.offset_left = 110
	window.offset_right = -110
	window.offset_top = 50
	window.offset_bottom = -50

	Game.changed.connect(refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


## Redraws the tab on show. Hidden tabs redraw when switched to.
## Deferred, because a refresh is often triggered by a button the redraw removes.
func refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_redraw.call_deferred()


func _redraw() -> void:
	_refresh_queued = false
	_tabs.get_current_tab_control().get_child(0).refresh()
