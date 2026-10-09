class_name Moulding
extends RefCounted
## Injection moulding: the endgame's way of making one thing by the thousand.
##
## A design has to have a mould made first, which costs a great deal and takes
## days. With the mould in, the machine turns plastic pellets into copies at a
## fraction of a printer's time and cost, in whatever colour of pellet is
## poured in. What it makes piles up in its output bin, counted by design and
## colour, until it is crated for a client or carried to the shelving.
##
## Only designs in one colour can be moulded. `rules` is the `moulding` block
## of data/game.json.

var products: Dictionary
var rules: Dictionary
## Design -> game minute its mould is, or will be, ready.
var moulds: Dictionary[StringName, float] = {}
## What is in the output bin: "product:colour" -> how many.
var output: Dictionary[String, int] = {}
## The batch being made: { product, colour, count, made, minutes }, or {} if idle.
var run := {}


func _init(p_products: Dictionary, p_rules: Dictionary) -> void:
	products = p_products
	rules = p_rules


static func key(product: StringName, colour: StringName) -> String:
	return "%s:%s" % [product, colour]


static func product_of(output_key: String) -> StringName:
	return StringName(output_key.get_slice(":", 0))


static func colour_of(output_key: String) -> StringName:
	return StringName(output_key.get_slice(":", 1))


## Why a design can't have a mould made, or "" if it can.
func mould_problem(product: StringName) -> String:
	if moulds.has(product):
		return "You have its mould already"
	if int(products[product].get("colour_count", 1)) > 1:
		return "Only designs in one colour can be moulded"
	return ""


## Pence a toolmaker charges for a design's mould: a multiple of what one sells
## for, and never less than the least any mould costs.
func mould_fee(product: StringName) -> int:
	return maxi(roundi(float(products[product]["base_price_pence"]) * float(rules["mould_fee_multiple"])), int(rules["mould_fee_min_pence"]))


## Orders a mould, to arrive after the toolmaker's lead time. Paying is the caller's job.
func order_mould(product: StringName, minute: float) -> void:
	moulds[product] = minute + float(rules["mould_days"]) * GameClock.DAY


func mould_ready(product: StringName, minute: float) -> bool:
	return moulds.has(product) and minute >= moulds[product]


## How many items are in the output bin altogether.
func stored() -> int:
	var total := 0
	for count: int in output.values():
		total += count
	return total


## Pence of pellets a batch uses.
func run_cost(product: StringName, count: int) -> int:
	return roundi(float(products[product]["filament_grams"]) * count / 1000.0 * float(rules["pellet_pence_per_kg"]))


## Game minutes a batch takes.
func run_minutes(count: int) -> float:
	return count * float(rules["minutes_per_item"])


## Why a batch of a design can't be started, or "" if it can.
func run_problem(product: StringName, minute: float, count: int) -> String:
	if not run.is_empty():
		return "The machine is already running"
	if not moulds.has(product):
		return "No mould for it"
	if not mould_ready(product, minute):
		return "Its mould isn't ready yet"
	if stored() + count > int(rules["output_capacity"]):
		return "The output bin is too full"
	return ""


## Starts a batch. Paying for the pellets is the caller's job.
func start(product: StringName, colour: StringName, count: int) -> void:
	run = {"product": product, "colour": colour, "count": count, "made": 0, "minutes": 0.0}


## Runs the machine for a span of game minutes. Returns how many items it made
## in that time. The batch is over, and `run` empty again, when the last is out.
func advance(game_minutes: float) -> int:
	if run.is_empty():
		return 0
	run["minutes"] = float(run["minutes"]) + game_minutes
	var due := mini(floori(float(run["minutes"]) / float(rules["minutes_per_item"])), int(run["count"]))
	var made := due - int(run["made"])
	if made > 0:
		var output_key := key(run["product"], run["colour"])
		output[output_key] = int(output.get(output_key, 0)) + made
		run["made"] = due
	if due >= int(run["count"]):
		run = {}
	return made


## Takes up to `count` of one kind out of the output bin. Returns how many came out.
func take(output_key: String, count: int) -> int:
	var taken := mini(count, int(output.get(output_key, 0)))
	if taken <= 0:
		return 0
	output[output_key] -= taken
	if output[output_key] <= 0:
		output.erase(output_key)
	return taken


## What a client checks a moulded item against (Contracts.wants). A moulded
## part is as good as a printed one in any material, so it names none.
func facts(output_key: String) -> Dictionary:
	return {"product": product_of(output_key), "material": "", "colour": colour_of(output_key), "quality": int(rules["quality"]),
		"durability": int(rules["durability"]), "flawed": false, "plain": false, "moulded": true}


func save() -> Dictionary:
	return {"moulds": moulds, "output": output, "run": run}


## Puts back the moulds, the output bin and any batch part way through,
## leaving out designs the game no longer has.
func restore(saved: Dictionary) -> void:
	moulds.clear()
	output.clear()
	run = {}
	for product: String in saved["moulds"]:
		if products.has(product):
			moulds[StringName(product)] = float(saved["moulds"][product])
	for output_key: String in saved["output"]:
		if products.has(String(product_of(output_key))):
			output[output_key] = int(saved["output"][output_key])
	var batch: Dictionary = saved.get("run", {})
	if not batch.is_empty() and products.has(batch["product"]):
		run = {"product": StringName(batch["product"]), "colour": StringName(batch["colour"]), "count": int(batch["count"]),
			"made": int(batch["made"]), "minutes": float(batch["minutes"])}
