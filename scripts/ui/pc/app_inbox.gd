extends VBoxContainer
## PC app: Inbox, where business clients write in. Enquiries waiting for an
## answer on the left, with what each wants, by when and for how much; the
## contracts taken on and how each is going on the right, with past jobs
## beneath. No mock-up existed for this one, so it follows the shop screens.

const BLUE := Color("2B7A9E")
const BLUE_DARK := Color("1D5A76")
const PAGE := Color("F2F6F8")
const TILE := Color("E1ECF1")
const SHADOW := Color("D6E2E8")
const LOCK_TEXT := Color("5A4A1C")
const LOCK_BG := Color("F4EBCF")
## How many past jobs are listed.
const SHOWN_PAST := 8

var screen: PcScreen


func refresh() -> void:
	Ui.clear(self)
	add_theme_constant_override(&"separation", 0)
	var banner := Ui.panel(Ui.hbox([
		Ui.title("inbox", 32, Ui.PAPER, 700),
		Ui.text("Businesses that want a batch made, and the ones you said yes to.", 15, Ui.PAPER),
	], 24), Ui.box(BLUE, 0, 32, 0))
	banner.custom_minimum_size.y = 84
	add_child(banner)

	var contracts := Game.contracts
	var enquiries := Ui.vbox([Ui.title("Enquiries", 20)], 12)
	if not Game.contracts_unlocked():
		enquiries.add_child(Ui.panel(Ui.wrap(Ui.text("Nobody has written yet. Businesses start asking for batches once you are running from a %s: they want to know you can make a lot of something." % String(
			Game.data.settings["tier_names"][int(Game.data.settings["contracts"]["unlock_tier"]) - 1]).to_lower(), 14, LOCK_TEXT, 800)), Ui.box(LOCK_BG, 14, 16, 12)))
	elif contracts.offers().is_empty():
		enquiries.add_child(_empty("Nothing waiting for an answer. Clients write when they have seen something of yours they like, so the more designs you own, the more of them will."))
	for contract in contracts.offers():
		enquiries.add_child(_offer_card(contract))

	var books := Ui.vbox([Ui.title("On the books", 20)], 12)
	if contracts.active().is_empty():
		books.add_child(_empty("No contracts running."))
	for contract in contracts.active():
		books.add_child(_active_card(contract))
	var past := contracts.finished()
	if not past.is_empty():
		books.add_child(Ui.title("Past jobs", 20))
		for contract in past.slice(0, SHOWN_PAST):
			books.add_child(_past_row(contract))

	var left := Ui.scroll(enquiries)
	var right := Ui.scroll(books)
	var page := Ui.panel(Ui.margin(Ui.hbox([left, right], 32), 40, 24, 40, 24), Ui.box(PAGE, 0, 0, 0))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page)


func _empty(words: String) -> Control:
	return Ui.panel(Ui.wrap(Ui.text(words, 14, Ui.MUTED)), Ui.outlined(Ui.CLEAR, SHADOW, 18, 18, 16))


func _offer_card(contract: Contracts.Contract) -> Control:
	var client: Dictionary = Game.data.clients[contract.client]
	var problem := Game.contracts.accept_problem(contract)
	var accept := Ui.button("Accept", func() -> void: Game.accept_contract(contract), BLUE, Ui.WHITE, 44, 14, BLUE_DARK, 15)
	accept.disabled = problem != ""
	accept.tooltip_text = problem
	var column := Ui.vbox([
		Ui.hbox([Ui.title(client["name"], 20), null,
			Ui.pill("Answer within %s" % GameClock.duration_label(contract.expires_at - Game.clock.minutes), BLUE_DARK, TILE)]),
		Ui.wrap(Ui.text(client["about"], 13, Ui.MUTED)),
		Ui.panel(Ui.wrap(Ui.text("\"%s\"" % contract.text, 14, Ui.INK, 700)), Ui.box(Ui.INSET, 14, 14, 12)),
		_spec(contract),
		_fact("Deadline", "%s after you accept, at the courier's collection" % GameClock.duration_label(contract.allowed_minutes)),
		_fact("If late", "%d%% comes off for each day" % roundi(contract.late_pct_per_day * 100.0)),
	], 10)
	if not Game.owns(contract.product):
		column.add_child(Ui.wrap(Ui.text("They supply the design. It is yours to print while the contract runs.", 13, BLUE_DARK, 800)))
	if problem != "":
		column.add_child(Ui.text(problem, 13, Ui.RED_DARK, 800))
	column.add_child(Ui.hbox([
		Ui.title(Money.format(Game.contracts.value(contract)), 24),
		Ui.text("%s each" % Money.format(contract.unit_price), 13, Ui.MUTED), null,
		Ui.button("Decline", func() -> void: Game.decline_contract(contract), Ui.SOFT, Ui.INK, 44, 14, Ui.CLEAR, 15),
		accept,
	], 10))
	return Ui.card(column, 22, 20, SHADOW)


## What has to be made: how many of what, in which filament and colour, and how well.
func _spec(contract: Contracts.Contract) -> Control:
	var filament: Dictionary = Game.data.filaments[contract.material]
	var colour := "any colour" if contract.colour == &"" else Palette.display_name(contract.colour).to_lower()
	if int(Game.data.products[contract.product].get("colour_count", 1)) > 1:
		colour = "full colour, your choice of colours"
	# The presets that are good enough, by name.
	var presets: PackedStringArray = []
	for preset: Dictionary in Game.data.presets.values():
		if int(preset["quality"]) >= contract.min_quality and int(preset["durability"]) >= contract.min_durability:
			presets.append(preset["name"])
	return Ui.vbox([
		_fact("They want", "%d x %s" % [contract.quantity, Game.product_name(contract.product)]),
		_fact("Printed in", "%s, %s" % [filament["name"], colour]),
		_fact("Good enough", "%s, and no flawed ones" % (" or ".join(presets) if not presets.is_empty() else "better than any preset you have")),
	], 10)


func _fact(label: String, value: String) -> Control:
	return Ui.hbox([Ui.width(Ui.text(label, 13, Ui.MUTED, 800), 96), Ui.grow(Ui.wrap(Ui.text(value, 14, Ui.INK, 800)))], 10)


func _active_card(contract: Contracts.Contract) -> Control:
	var contracts := Game.contracts
	var now := Game.clock.minutes
	var ready := Game.contract_ready(contract)
	var to_print := maxi(contracts.remaining(contract) - ready, 0)
	var progress: PackedStringArray = ["%d with them" % contract.delivered]
	if contract.packed > 0:
		progress.append("%d crated for the courier" % contract.packed)
	if ready > 0:
		progress.append("%d ready on the shelf" % ready)
	if to_print > 0:
		progress.append("%d still to print" % to_print)
	var due := GameClock.new()
	due.minutes = contract.due_at
	var late := contracts.days_late(contract, now)
	var deadline := Ui.pill("Due in %s" % GameClock.duration_label(contract.due_at - now), BLUE_DARK, TILE)
	if late > 0:
		deadline = Ui.pill("%d day%s late" % [late, "" if late == 1 else "s"], Ui.RED_DARK, Ui.RED_SOFT)
	var column := Ui.vbox([
		Ui.hbox([Ui.title(Game.client_name(contract), 20), null, deadline]),
		_spec(contract),
		_fact("Deadline", due.label()),
		Ui.bar(float(contract.delivered + contract.packed) / contract.quantity, Ui.GREEN, TILE, 12),
		Ui.wrap(Ui.text(" · ".join(progress), 13, Ui.MUTED, 800)),
	], 10)
	if late > 0:
		column.add_child(Ui.wrap(Ui.text("%s is coming off the price so far. Much later and they will cancel." % Money.format(contracts.penalty(contract, now)), 13, Ui.RED_DARK, 800)))
	elif ready > 0:
		column.add_child(Ui.wrap(Ui.text("Send what is ready from the workbench: Send to a client.", 13, Ui.GREEN_DARK, 800)))
	column.add_child(Ui.hbox([
		Ui.title(Money.format(contracts.value(contract) - contracts.penalty(contract, now)), 22),
		Ui.text("when the last one arrives", 13, Ui.MUTED),
	], 10))
	return Ui.card(column, 22, 20, SHADOW)


func _past_row(contract: Contracts.Contract) -> Control:
	var done := contract.status == Contracts.Status.DONE
	return Ui.panel(Ui.hbox([
		Ui.grow(Ui.vbox([
			Ui.text(Game.client_name(contract), 15, Ui.INK, 800),
			Ui.text("%d x %s" % [contract.quantity, Game.product_name(contract.product)], 13, Ui.MUTED),
		], 0)),
		Ui.pill("Delivered" if done else "Cancelled", Ui.GREEN_DARK if done else Ui.RED_DARK, Ui.GREEN_SOFT if done else Ui.RED_SOFT),
		Ui.width(Ui.text(Money.format(contract.paid), 15, Ui.INK, 800), 80),
	], 12), Ui.box(Ui.WHITE, 14, 16, 10, SHADOW, 3))
