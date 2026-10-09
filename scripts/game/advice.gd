class_name Advice
extends RefCounted
## Works out what the player should probably do next from the state of the
## business. Feeds the sticky note on the PC desktop and the HUD's idle hint.

const LOW_SPOOL_GRAMS := 150.0
const LOW_PACKAGING := 2


## Short to-do lines, most urgent first. Empty when there is nothing pressing.
static func todo(tree: SceneTree) -> PackedStringArray:
	var lines: PackedStringArray = []
	var market := Game.market
	if not tree.get_nodes_in_group(&"delivery_box").is_empty():
		lines.append("Unpack the delivery")

	var printers := tree.get_nodes_in_group(&"printer")
	var printer_coming := Game.supplier.pending.any(func(d: Supplier.Delivery) -> bool: return d.printer != &"")
	if printers.is_empty() and not printer_coming and tree.get_nodes_in_group(&"delivery_box").is_empty():
		lines.append("Buy a printer from %s" % Game.data.settings["supplier"]["hardware_shop"])

	var rack: FilamentRack = tree.get_first_node_in_group(&"filament_rack")
	var spools: Array[Spool] = rack.spools() if rack != null else ([] as Array[Spool])
	for printer: PrinterStation in printers:
		if printer.status == PrinterStation.Status.DONE:
			lines.append("Collect the finished print")
		if printer.spool != null:
			spools.append(printer.spool)
	var spools_coming := Game.supplier.pending.any(func(d: Supplier.Delivery) -> bool: return not d.spools.is_empty())
	if spools.is_empty() and not spools_coming and tree.get_nodes_in_group(&"delivery_box").is_empty():
		lines.append("Order filament from %s" % Game.data.settings["supplier"]["filament_shop"])
	for spool in spools:
		if spool.grams < LOW_SPOOL_GRAMS:
			lines.append("%s %s is nearly out" % [Palette.display_name(spool.colour), String(spool.material).to_upper()])

	if not printers.is_empty() and not market.listings.values().any(func(entry: Dictionary) -> bool: return entry["listed"]):
		lines.append("List a design on %s" % market.config["name"])

	var ready := 0
	var waiting := 0
	var unclaimed: Dictionary[StringName, int] = {}
	for order in market.open_orders():
		if not unclaimed.has(order.product):
			unclaimed[order.product] = Game.stock_of(order.product)
		if unclaimed[order.product] > 0:
			unclaimed[order.product] -= 1
			ready += 1
		else:
			waiting += 1
	if ready > 0:
		lines.append("Pack %d order%s" % [ready, "" if ready == 1 else "s"])
	if waiting > 0:
		lines.append("Print %d more for orders" % waiting)
	if Game.packaging <= LOW_PACKAGING:
		lines.append("Mailer boxes are nearly out")
	return lines
