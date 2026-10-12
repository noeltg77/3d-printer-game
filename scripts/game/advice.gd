class_name Advice
extends RefCounted
## Works out what the player should probably do next from the state of the
## business. Feeds the to-do note on the PC desktop and in the garage.
##
## Each thing to do comes with a hint for someone who has never owned a
## printer: where to click, and in a few words why it matters.

const LOW_SPOOL_GRAMS := 150.0
const LOW_PACKAGING := 2


## Short to-do lines, most urgent first. Empty when there is nothing pressing.
static func todo(tree: SceneTree) -> PackedStringArray:
	var lines: PackedStringArray = []
	for item in items(tree):
		lines.append(item["text"])
	return lines


## Things to do, most urgent first, each as { text, hint }.
static func items(tree: SceneTree) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var market := Game.market
	var open_orders := Game.open_orders()
	var shops: Dictionary = Game.data.settings["supplier"]
	var boxes_waiting := not tree.get_nodes_in_group(&"delivery_box").is_empty()
	if tree.get_nodes_in_group(&"delivery_box").any(func(box: DeliveryBox) -> bool: return box.delivery.fitting == &""):
		_add(found, "Unpack the delivery", "Click the box by the door and choose Unpack. Everything inside gets put away for you.")

	var printers := tree.get_nodes_in_group(&"printer")
	var printer_coming := Game.supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.printer != &"")
	if printers.is_empty() and not printer_coming and not boxes_waiting:
		_add(found, "Buy a printer from %s" % shops["hardware_shop"],
			"Click the computer, then open %s. Nothing gets made without a printer." % shops["hardware_shop"])

	var rack: FilamentRack = tree.get_first_node_in_group(&"filament_rack")
	var spools: Array[Spool] = rack.spools() if rack != null else ([] as Array[Spool])
	for printer: PrinterStation in printers:
		if printer.status == PrinterStation.Status.DONE:
			_add(found, "Collect the finished print", "Click the printer and choose Collect. It can't start another until its plate is clear.")
		if printer.has_auto_eject() and printer.tray.size() >= printer.tray_capacity():
			_add(found, "Empty the tray on the %s" % printer.display_name, "Its auto-eject plate has nowhere left to throw prints, so it has stopped. Click the printer and choose Empty the tray.")
		if printer.status == PrinterStation.Status.FAILED:
			_add(found, "Sort out the failed print on the %s" % printer.display_name,
				"Click the printer and pick the fix. Prints fail now and then; it costs a little time and plastic.")
		if not printer.unit_linked():
			_add(found, "The %s's colour unit has nowhere to sit" % printer.display_name,
				"A printer on a rack has no room on top for its multicolour unit. Stand a colour unit rack (Printbay, Storage) right beside its rack, or move the one you have closer, and the unit goes in a bay by itself.")
		for slot in printer.wear.broken():
			var part := String(printer.wear.part(slot)["slot_name"]).to_lower()
			_add(found, "Fit a new %s to the %s" % [part, printer.display_name],
				"Parts wear out with use. Buy a spare at %s, then click the printer and open Parts." % shops["hardware_shop"])
		if printer.spool != null:
			spools.append_array(printer.spools.filter(func(loaded: Spool) -> bool: return loaded != null))
		elif rack != null and not rack.spools().is_empty():
			_add(found, "Load filament into the %s" % printer.display_name,
				"Filament is the plastic a printer melts to build things. Click the printer and choose Load filament.")
		if printer.status == PrinterStation.Status.IDLE and printer.spool != null and printer.wear.broken().is_empty() \
				and not Game.owned_designs.is_empty() and _nothing_to_sell(market):
			_add(found, "Print something to sell", "Click the printer and choose Print. Standard is a safe way to print most things.")
	var shelf: StorageShelf = tree.get_first_node_in_group(&"print_storage")
	for box in (shelf.spares() if shelf != null else ([] as Array[SparePart])):
		var kit: Dictionary = Game.data.upgrades.get(box.part, {})
		if kit.get("fixture", "") == MouldingMachine.FIXTURE:
			_add(found, "Install the moulding machine", "Click the marked bay on the factory floor and choose Install. Then order a mould for the design you want made by the hundred.")
		if kit.get("fixture", "") == Conveyor.FIXTURE:
			_add(found, "Fit the conveyor", "It carries prints from every printer with an auto-eject plate to the shelving. Click the control cabinet by the shelving and choose Fit.")
		if kit.has("multicolour"):
			_add(found, "Fit the %s" % kit["name"], "It lets one print be several colours. Unload the printer it is made for, then click that printer and open Upgrades. After that, load a spool for each colour.")
	var spools_coming := Game.supplier.pending.any(func(d: Supplier.Delivery) -> bool: return not d.spools.is_empty())
	if spools.is_empty() and not spools_coming and not boxes_waiting:
		_add(found, "Order filament from %s" % shops["filament_shop"],
			"Filament is the plastic a printer melts to build things. Click the computer, then open %s." % shops["filament_shop"])
	var has_dryer := not tree.get_nodes_in_group(&"dryer").is_empty()
	for spool in spools:
		if spool.is_wet():
			_add(found, "%s has got wet" % spool.title(), "Filament soaks up damp from the air and then prints badly. "
				+ ("Buy a dryer at %s, under Dryers." % shops["hardware_shop"] if not has_dryer
				else ("Click the dryer and choose Dry a spool." if rack.spools().has(spool) else "Unload it from the printer, then click the dryer and choose Dry a spool.")))
		if spool.grams < LOW_SPOOL_GRAMS:
			_add(found, "%s is nearly out" % spool.title(),
				"A print needs enough on the spool to finish. Order another from %s on the computer." % shops["filament_shop"])

	if not printers.is_empty() and not Game.anything_listed():
		_add(found, "List a design on %s" % market.config["name"],
			"Buyers can only order what is listed. Click the computer, open %s and press List it." % market.config["name"])

	var ready := 0
	var waiting := 0
	var unclaimed: Dictionary[StringName, int] = {}
	for order in open_orders:
		if not unclaimed.has(order.product):
			unclaimed[order.product] = Game.stock_of(order.product)
		if unclaimed[order.product] > 0:
			unclaimed[order.product] -= 1
			ready += 1
		else:
			waiting += 1
	if ready > 0:
		_add(found, "Pack %d order%s" % [ready, "" if ready == 1 else "s"],
			"Click the packing station and choose Pack order. The courier collects what is packed and that is when you get paid.")
	if waiting > 0:
		_add(found, "Print %d more for orders" % waiting, "Someone has ordered one you haven't made yet. Orders left too long are cancelled.")
	for product in Game.studio.designs:
		if Game.studio.needs_fix(product):
			_add(found, "Fix the fault in your %s design" % Game.product_name(product),
				"Every print of it will come out flawed until you do. Click the computer and open Design Lab.")
	var bench: Workbench = tree.get_first_node_in_group(&"workbench")
	for place: String in Game.data.premises:
		var row: Dictionary = Game.data.premises[place]
		if int(row["tier"]) == Game.tier + 1 and bench != null and bench.free_spots() == 0 and Game.bank.can_afford(int(row["move_cost_pence"])):
			_add(found, "You can afford a bigger space", "The bench is full. Click the computer and open Roomier to move, for more printers, shelving and new things to sell.")
	if not Game.contracts.offers().is_empty():
		_add(found, "Read the enquiry in your inbox", "A business wants a batch made. Click the computer and open Inbox to see what, by when and for how much. It won't wait for ever.")
	for contract in Game.contracts.active():
		if Game.contract_ready(contract) > 0:
			_add(found, "Send %d to %s" % [Game.contract_ready(contract), Game.client_name(contract)],
				"Click the packing station and choose Send to a client. The courier takes the crate, and the last one gets you paid.")
		elif Game.contracts.remaining(contract) > 0:
			_add(found, "Print %d x %s for %s" % [Game.contracts.remaining(contract), Game.product_name(contract.product), Game.client_name(contract)],
				"A contract has a deadline and a spec. Open Inbox on the computer to see what filament, colour and strength they want.")
	if Game.stock_unlocked() and Game.stock.rules.is_empty():
		_add(found, "Let the stockroom do the ordering", "With this many printers something is always running out. Click the computer, open Stockroom and switch on a rule for the filament, spares and boxes you use most.")
	for box: DeliveryBox in tree.get_nodes_in_group(&"delivery_box"):
		if box.delivery.fitting != &"":
			_add(found, "Put up the %s" % String(Game.data.fittings[box.delivery.fitting]["name"]).to_lower(),
				"Click its box by the door and choose Unpack. Then click the floor where you want it: green means it fits, and R turns it.")
	if shelf != null and shelf.bins().is_empty() and shelf.free_slots() <= 2:
		for item in shelf._loose():
			if Game.storage.is_bin(item.product):
				_add(found, "Use a storage bin for more room", "The shelving is nearly full. Click it, open Storage bins and put your printed bin to use: one space then holds several prints.")
				break
	for kind in low_packaging():
		_add(found, "%s are nearly out" % Game.packaging_plural(kind).capitalize(),
			"Your designs go out in them, one to an order. Buy a pack at %s, under Packaging, or pick something else on the listing." % shops["hardware_shop"])
	if shelf != null and not shelf.unfinished().is_empty() and tree.get_first_node_in_group(&"finishing_bench") != null and ready == 0:
		_add(found, "Give a print a better finish", "Click the finishing bench and choose Finish. A pass with the blowtorch tidies a print up, so buyers rate it higher and send fewer back.")
	return found


## The kinds of packaging the business's designs go out in that have nearly run out.
static func low_packaging() -> Array[StringName]:
	var low: Array[StringName] = []
	for product in Game.owned_designs:
		var kind := Game.packaging_of(product)
		if kind != &"" and Game.packaging_count(kind) <= LOW_PACKAGING and not low.has(kind):
			low.append(kind)
	return low


static func _add(found: Array[Dictionary], text: String, hint: String) -> void:
	found.append({"text": text, "hint": hint})


## True if there are no finished prints and no orders to print for either:
## the moment a newcomer needs telling to start a print.
static func _nothing_to_sell(market: Marketplace) -> bool:
	for product in Game.owned_designs:
		if Game.stock_of(product) > 0:
			return false
	return Game.open_orders().is_empty()
