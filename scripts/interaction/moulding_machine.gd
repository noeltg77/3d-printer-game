class_name MouldingMachine
extends Interactable
## The injection moulding bay. This script goes on the floor marking where the
## machine stands, which is all there is until the machine (an upgrade with
## `fixture` "moulder") has been bought and installed from here.
##
## Installed, its menu orders moulds, starts batches, and moves what it has
## made: into a crate for a client, or onto the shelving to be sold like
## anything else. The rules are in Moulding (scripts/sim); this is the machine
## on the floor.

const FIXTURE := "moulder"
## The most one trip to the shelving carries.
const ARMFUL := 12

## The machine, which goes up on the marking when it is installed.
@export var machine_scene: PackedScene

var installed := false
var moulding: Moulding

var _machine: Node3D = null


func _ready() -> void:
	super()
	add_to_group(&"moulder")
	moulding = Moulding.new(Game.data.products, Game.data.settings["moulding"])


func _process(delta: float) -> void:
	if not installed or moulding.run.is_empty():
		return
	var batch := moulding.run.duplicate()
	var made := moulding.advance(delta * GameClock.MINUTES_PER_SECOND)
	if made > 0:
		Game.stats["moulded_items"] += made
		Game.changed.emit()
	if moulding.run.is_empty():
		var minutes := moulding.run_minutes(int(batch["count"]))
		Game.charge_electricity(float(Game.data.settings["moulding"]["power_watts"]), minutes, "Moulding")
		Game.notify("The moulding machine has finished %d x %s" % [int(batch["count"]), Game.product_name(batch["product"])], &"good")


func get_actions(_agent: Agent) -> Array[Action]:
	if not installed:
		return _install_actions()
	var rules: Dictionary = Game.data.settings["moulding"]
	var actions: Array[Action] = []
	if moulding.run.is_empty():
		actions.append(Action.info("Moulding machine: idle"))
	else:
		var batch := moulding.run
		var left := (int(batch["count"]) - int(batch["made"])) * float(rules["minutes_per_item"])
		actions.append(Action.info("Moulding %s: %d of %d, %s left" % [Game.product_name(batch["product"]), int(batch["made"]), int(batch["count"]), GameClock.duration_label(left)]))
	actions.append(Action.info("Output bin: %d of %d" % [moulding.stored(), int(rules["output_capacity"])]))
	actions.append(_run_menu())
	actions.append(_mould_menu())
	for output_key in moulding.output:
		actions.append(_shelve_action(output_key))
	for contract in Game.contracts.active():
		for output_key in moulding.output:
			if Game.contracts.wants(contract, moulding.facts(output_key)) and Game.contracts.remaining(contract) > 0:
				actions.append(_crate_action(contract, output_key))
	return actions


## Id of the upgrade that is the machine, or empty if the game has none.
static func kit_id() -> StringName:
	for upgrade: Dictionary in Game.data.upgrades.values():
		if upgrade.get("fixture", "") == FIXTURE:
			return StringName(upgrade["id"])
	return &""


func install() -> void:
	if installed:
		return
	installed = true
	_machine = machine_scene.instantiate()
	add_child(_machine)
	add_to_group(&"obstacle")
	(get_tree().get_first_node_in_group(&"floor_grid") as FloorGrid).rebuild()
	remove_collider()
	_build_collider.call_deferred()
	Game.changed.emit()


## "Red Cable management clips (x12)" for a kind in the output bin.
func output_name(output_key: String) -> String:
	return "%s %s" % [Palette.display_name(Moulding.colour_of(output_key)), Game.product_name(Moulding.product_of(output_key))]


func _install_actions() -> Array[Action]:
	var kit := kit_id()
	if kit == &"" or _shelf().spare_count(kit) == 0:
		return [Action.info("Room for a moulding machine (buy one at the PC)")]
	var row: Dictionary = Game.data.upgrades[kit]
	var fit := Action.new("Install the %s (%s)" % [String(row["name"]).to_lower(), GameClock.duration_label(row["install_minutes"])], _install)
	fit.task_name = "Install the moulding machine"
	return [fit]


## The designs a mould could be ordered for, each with its price and how long it takes.
func _mould_menu() -> Action:
	var rules: Dictionary = Game.data.settings["moulding"]
	var lines: Array[Action] = []
	for product in Game.printable_designs():
		if moulding.moulds.has(product):
			var ready := moulding.mould_ready(product, Game.clock.minutes)
			lines.append(Action.info("%s: %s" % [Game.product_name(product), "mould in the rack" if ready
				else "mould arrives in %s" % GameClock.duration_label(moulding.moulds[product] - Game.clock.minutes)]))
			continue
		var fee := moulding.mould_fee(product)
		var problem := moulding.mould_problem(product)
		if problem == "" and not Game.bank.can_afford(fee):
			problem = "Not enough cash"
		var label := "%s: %s, takes %s" % [Game.product_name(product), Money.format(fee), GameClock.duration_label(float(rules["mould_days"]) * GameClock.DAY)]
		var order := Action.new(label if problem == "" else "%s: %s" % [Game.product_name(product), problem.to_lower()], _order_mould.bind(product), problem == "")
		order.immediate = true
		lines.append(order)
	if lines.is_empty():
		return Action.info("Order a mould (no designs to make one for)")
	return Action.submenu("Order a mould", lines)


## A batch of each design with a mould, in each colour of pellet.
func _run_menu() -> Action:
	var rules: Dictionary = Game.data.settings["moulding"]
	var count := int(rules["batch"])
	var designs: Array[Action] = []
	for product in moulding.moulds:
		if not Game.data.products.has(product):
			continue
		var problem := moulding.run_problem(product, Game.clock.minutes, count)
		var cost := moulding.run_cost(product, count)
		if problem == "" and not Game.bank.can_afford(cost):
			problem = "Not enough cash for the pellets"
		var title := "%d x %s" % [count, Game.product_name(product)]
		if problem != "":
			designs.append(Action.info("%s: %s" % [title, problem.to_lower()]))
			continue
		var colours: Array[Action] = []
		for colour: String in rules["colours"]:
			var start := Action.new(Palette.display_name(colour), _run.bind(product, StringName(colour), count))
			start.task_name = "Mould %s" % title
			colours.append(start)
		designs.append(Action.submenu("%s: %s of pellets, %s" % [title, Money.format(cost), GameClock.duration_label(moulding.run_minutes(count))], colours))
	if designs.is_empty():
		return Action.info("Run a batch (order a mould first)")
	return Action.submenu("Run a batch", designs)


func _shelve_action(output_key: String) -> Action:
	var count := mini(mini(int(moulding.output[output_key]), _shelf().free_slots()), ARMFUL)
	var title := output_name(output_key)
	if count <= 0:
		return Action.info("Take %s to the shelving (it is full)" % title)
	var action := Action.new("Take %d x %s to the shelving" % [count, title], _shelve.bind(output_key))
	action.task_name = "Shelve %s" % title
	return action


func _crate_action(contract: Contracts.Contract, output_key: String) -> Action:
	var count := mini(int(moulding.output[output_key]), Game.contracts.remaining(contract))
	var label := "Crate %d x %s for %s" % [count, output_name(output_key), Game.client_name(contract)]
	if Game.packaging <= 0:
		return Action.info("%s (no mailer boxes)" % label)
	var action := Action.new(label, _crate.bind(contract.id, output_key)).for_duty(&"send")
	action.task_name = "Crate up %d for %s" % [count, Game.client_name(contract)]
	return action


# Tasks.

func _install(agent: Agent) -> void:
	var shelf := _shelf()
	var kit := kit_id()
	if installed or kit == &"" or shelf.spare_count(kit) == 0:
		agent.say("Can't install the machine right now")
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void: agent.carry(shelf.take_spare(kit)))
	if agent.carried == null:
		return
	await agent.go_to(self)
	await agent.work(float(Game.data.upgrades[kit]["install_minutes"]))
	await agent.reach(func() -> void:
		agent.release().queue_free()
		install())
	agent.say("The moulding machine is in")


## Not a task: the toolmaker is paid and gets on with it.
func _order_mould(_agent: Agent, product: StringName) -> void:
	if moulding.mould_problem(product) != "":
		return
	if not Game.bank.spend(moulding.mould_fee(product), "Mould: %s" % Game.product_name(product), Game.clock.minutes):
		return
	moulding.order_mould(product, Game.clock.minutes)
	Game.notify("Mould ordered for the %s. It will be here in %s." % [Game.product_name(product),
		GameClock.duration_label(float(Game.data.settings["moulding"]["mould_days"]) * GameClock.DAY)])
	Game.changed.emit()


func _run(agent: Agent, product: StringName, colour: StringName, count: int) -> void:
	if moulding.run_problem(product, Game.clock.minutes, count) != "" or not Game.bank.can_afford(moulding.run_cost(product, count)):
		agent.say("The machine can't run that right now")
		return
	await agent.go_to(self)
	await agent.work(float(Game.data.settings["moulding"]["setup_minutes"]))
	if moulding.run_problem(product, Game.clock.minutes, count) != "":
		return
	if Game.bank.spend(moulding.run_cost(product, count), "Pellets: %s" % Game.product_name(product), Game.clock.minutes):
		moulding.start(product, colour, count)
		Game.changed.emit()


func _shelve(agent: Agent, output_key: String) -> void:
	var shelf := _shelf()
	if not moulding.output.has(output_key) or not shelf.has_space():
		agent.say("Nothing to take to the shelving")
		return
	await agent.go_to(self)
	await agent.reach(func() -> void:
		var items: Array[PrintedItem] = []
		for index in moulding.take(output_key, mini(shelf.free_slots(), ARMFUL)):
			items.append(_item(output_key))
		if items.is_empty():
			return
		# The rest ride along out of sight, inside the first.
		agent.carry(items[0])
		for item: PrintedItem in items.slice(1):
			Interactable.attach(item, items[0])
			item.visible = false
		Game.changed.emit())
	if agent.carried == null:
		return
	await agent.go_to(shelf)
	await agent.reach(func() -> void:
		var first := agent.release()
		for child in first.get_children():
			var item := child as PrintedItem
			if item != null:
				item.visible = true
				shelf.store(item)
		shelf.store(first))


func _crate(agent: Agent, contract_id: int, output_key: String) -> void:
	var contract := Game.contracts.by_id(contract_id)
	if contract == null or contract.status != Contracts.Status.ACTIVE or Game.packaging <= 0 or not moulding.output.has(output_key) \
			or not Game.contracts.wants(contract, moulding.facts(output_key)):
		agent.say("Nothing to crate for that client right now")
		return
	await agent.go_to(self)
	var count := moulding.take(output_key, Game.contracts.remaining(contract))
	if count <= 0:
		return
	await agent.work(float(Game.data.settings["moulding"]["setup_minutes"]))
	Game.packaging -= 1
	Game.contracts.pack(contract, count)
	Game.changed.emit()
	await agent.reach(func() -> void: agent.carry(Parcel.create_crate(contract.id, count)))
	var outbox: Outbox = get_tree().get_first_node_in_group(&"outbox")
	await agent.go_to(outbox)
	await agent.reach(func() -> void: outbox.add(agent.release() as Parcel))


## One moulded item, as a thing that can go on a shelf and be sold.
func _item(output_key: String) -> PrintedItem:
	var rules: Dictionary = Game.data.settings["moulding"]
	var colours: Array[StringName] = [Moulding.colour_of(output_key)]
	var item := PrintedItem.create(Moulding.product_of(output_key), colours, StringName(rules["sold_as_preset"]), StringName(rules["sold_as_filament"]))
	item.quality = int(rules["quality"])
	item.durability = int(rules["durability"])
	return item


func _shelf() -> StorageShelf:
	return get_tree().get_first_node_in_group(&"print_storage")


func save() -> Dictionary:
	return {"installed": installed, "moulding": moulding.save()}


func restore(data: Dictionary) -> void:
	if bool(data.get("installed", false)):
		install()
	moulding.restore(data["moulding"])
