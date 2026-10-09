extends VBoxContainer
## PC app: Roomier, where the business finds somewhere bigger. A card for each
## place in data/premises.json with what it holds and costs. "Move in" pays and
## takes everything along to the new premises.

const TEAL := Color("2B8C8C")
const TEAL_DARK := Color("1D6464")
const SHADOW := Color("D5E4E2")
const TILE := Color("E3F0EE")

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("roomier", 32, Ui.PAPER, 700),
		Ui.text("Units to let for businesses that have run out of bench.", 15, Ui.PAPER),
	], 24), Ui.box(TEAL, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var cards := Ui.hbox([], 20)
	for place: String in Game.data.premises:
		cards.add_child(_card(StringName(place)))
	cards.add_child(_later_card())
	var page := Ui.margin(Ui.vbox([
		Ui.wrap(Ui.text("Moving takes your printers, filament, stock and anything waiting by the door with you. Bigger places open up more to buy in the shops.", 14, Ui.MUTED)),
		cards,
	], 20), 32, 24, 32, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _card(place: StringName) -> Control:
	var row: Dictionary = Game.data.premises[place]
	var here := place == Game.premises
	var problem := Game.move_problem(place)
	var rent := int(row["rent_pence_per_day"])
	var column := Ui.vbox([
		Ui.hbox([Ui.icon_tile("roomier", 52, 28, TILE, TEAL_DARK), null,
			Ui.pill("You are here", Ui.GREEN_DARK, Ui.GREEN_SOFT) if here else Ui.pill(Game.data.settings["tier_names"][int(row["tier"]) - 1], TEAL_DARK, TILE)]),
		Ui.title(row["name"], 22),
		Ui.wrap(Ui.text(row["description"], 13, Ui.MUTED)),
		Ui.vbox([
			_fact("Printers", str(int(row["printer_spots"]))),
			_fact("Shelf spaces", str(int(row["shelf_slots"]))),
			_fact("Filament rack", "%d spools" % int(row["rack_slots"])),
			_fact("Staff", str(int(row["staff"])) if int(row["staff"]) > 0 else "Just you"),
			_fact("Rent", "%s a day" % Money.format(rent) if rent > 0 else "None"),
		], 6),
		null,
	], 12)
	if here:
		column.add_child(Ui.text("Your business runs from here.", 14, Ui.INK, 800))
	elif int(row["tier"]) < Game.tier:
		column.add_child(Ui.text("You have outgrown this one.", 14, Ui.MUTED, 800))
	else:
		if problem != "":
			column.add_child(Ui.text(problem, 13, Ui.RED_DARK, 800))
		var move := Ui.button("Move in", _move.bind(place), TEAL, Ui.WHITE, 46, 14, TEAL_DARK, 15)
		move.disabled = problem != ""
		column.add_child(Ui.hbox([Ui.title(Money.format(int(row["move_cost_pence"])), 22), Ui.text("to move", 13, Ui.MUTED), null, move], 8))
	var card := Ui.card(column, 22, 20, SHADOW)
	card.custom_minimum_size = Vector2(340, 420)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return card


## An honest placeholder for the tiers that aren't built yet.
func _later_card() -> Control:
	var card := Ui.panel(Ui.vbox([
		Ui.title("Bigger still", 20, Ui.MUTED),
		Ui.wrap(Ui.text("Factory units aren't on the market yet.", 13, Ui.MUTED)),
	], 8), Ui.outlined(Ui.CLEAR, SHADOW, 22, 20, 20))
	card.custom_minimum_size.x = 260
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return card


func _fact(label: String, value: String) -> Control:
	return Ui.hbox([Ui.text(label, 13, Ui.MUTED), null, Ui.text(value, 14, Ui.INK, 800)])


func _move(place: StringName) -> void:
	(get_tree().get_first_node_in_group(&"world_save") as WorldSave).move(place)
