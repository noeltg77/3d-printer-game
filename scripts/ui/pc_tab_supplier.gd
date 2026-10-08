extends VBoxContainer
## PC tab: the supplier shop. Build a basket of printers, PLA spools and mailer
## boxes, then place the order; it arrives by the garage door after a lead time.

## { printers: { id: qty }, spools: { colour: qty }, packaging: packs }
var _basket := {"printers": {}, "spools": {}, "packaging": 0}


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 10)
	var config: Dictionary = Game.data.settings["supplier"]
	add_child(Ui.note("%s: orders are left inside the garage door. Filament and boxes take %s, printers %s." % [
		config["name"], GameClock.duration_label(config["filament_lead_minutes"]),
		GameClock.duration_label(config["printer_lead_minutes"])]))

	# The basket total and order button stay at the top so they are never scrolled away.
	var problem := Game.supplier_problem(_basket)
	var total := Game.supplier.price_of(_basket)
	add_child(Ui.row([
		Ui.label("Basket: %s" % Money.text(total), 20),
		Ui.label("" if total == 0 else problem, 16, Ui.BAD),
		null,
		Ui.button("Clear", _clear, total > 0),
		Ui.button("Place order", _place, problem == ""),
	]))
	add_child(HSeparator.new())

	add_child(Ui.heading("Printers"))
	for printer_id: String in Game.data.printers:
		var printer: Dictionary = Game.data.printers[printer_id]
		if int(printer["unlock_tier"]) > 1:
			continue
		add_child(_line("%s %s" % [printer["brand"], printer["name"]], printer["description"],
			int(printer["price_cents"]), _basket["printers"], printer_id))

	add_child(Ui.heading("PLA filament, 1 kg spools"))
	var colours := GridContainer.new()
	colours.columns = 2
	colours.add_theme_constant_override(&"h_separation", 40)
	for colour: String in Game.data.filaments["pla"]["colours"]:
		colours.add_child(_line(Palette.display_name(colour), "", Game.supplier.spool_price(), _basket["spools"], colour))
	add_child(colours)

	add_child(Ui.heading("Packaging"))
	add_child(_line("%s, pack of %d" % [config["packaging_name"], config["packaging_pack_size"]],
		"One is used for every order you pack. You have %d." % Game.packaging,
		int(config["packaging_pack_cents"]), _basket, "packaging"))



## One buyable thing: name, note, price and a quantity stepper writing to store[key].
func _line(title: String, note: String, price: int, store: Dictionary, key: String) -> Control:
	var quantity := int(store.get(key, 0))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Ui.label(title))
	if note != "":
		text.add_child(Ui.label(note, 14, Ui.MUTED))
	return Ui.row([
		text,
		Ui.cell(Money.text(price), 70, Ui.MUTED),
		Ui.button("-", _change.bind(store, key, -1), quantity > 0),
		Ui.cell(str(quantity), 24),
		Ui.button("+", _change.bind(store, key, 1)),
	])


func _change(store: Dictionary, key: String, by: int) -> void:
	store[key] = maxi(int(store.get(key, 0)) + by, 0)
	refresh.call_deferred()


func _clear() -> void:
	_basket = {"printers": {}, "spools": {}, "packaging": 0}
	refresh.call_deferred()


func _place() -> void:
	if Game.place_supplier_order(_basket):
		Game.notify("Order placed with %s" % Game.data.settings["supplier"]["name"])
		_clear()
