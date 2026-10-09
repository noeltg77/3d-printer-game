class_name Stockroom
extends RefCounted
## Reorder rules for the things the business uses up: spools of filament, spare
## parts and mailer boxes. Each rule says how low a stock may fall before more
## is ordered, and how much to order. Given what is in stock and on its way,
## it says what is due; placing the order is the caller's job.
##
## Stock is named by key: "spool:<material>:<colour>", "part:<id>" or
## "packaging". Spools and parts are counted singly and ordered by the spool or
## the pack; mailer boxes are counted singly and ordered by the pack.

const SPOOL := "spool:"
const PART := "part:"
const PACKAGING := "packaging"
## What a stock with no rule of its own shows in the app: off, and modest.
const DEFAULT_RULE := {"on": false, "point": 1, "quantity": 1}

var data: GameData
## Key -> { on, point, quantity }. `point` is the stock at or below which more
## is ordered, counting what is already on its way; `quantity` how much.
var rules: Dictionary[String, Dictionary] = {}


func _init(p_data: GameData) -> void:
	data = p_data


static func spool_key(material: String, colour: String) -> String:
	return SPOOL + FilamentRules.spool_key(material, colour)


static func part_key(part: String) -> String:
	return PART + part


static func is_spool(key: String) -> bool:
	return key.begins_with(SPOOL)


## The rule for a stock, or the default one if none has been set.
func rule(key: String) -> Dictionary:
	return rules.get(key, DEFAULT_RULE)


func set_rule(key: String, on: bool, point: int, quantity: int) -> void:
	rules[key] = {"on": on, "point": maxi(point, 0), "quantity": maxi(quantity, 1)}


## True if anything is set to reorder itself.
func any_on() -> bool:
	return rules.values().any(func(entry: Dictionary) -> bool: return entry["on"])


## True if the game still has the thing a key names.
func knows(key: String) -> bool:
	if key == PACKAGING:
		return true
	if key.begins_with(PART):
		return data.parts.has(key.trim_prefix(PART))
	if not key.begins_with(SPOOL):
		return false
	var spool := key.trim_prefix(SPOOL)
	var material := FilamentRules.material_of(spool)
	return data.filaments.has(material) and data.filaments[material]["colours"].has(FilamentRules.colour_of(spool))


## What to order now. `levels` is key -> { have, coming }: what is in stock and
## what is already ordered. Returns key -> quantity for every rule that is on
## and whose stock, with what is coming, has fallen to its reorder point.
func due(levels: Dictionary) -> Dictionary[String, int]:
	var found: Dictionary[String, int] = {}
	for key in rules:
		var entry := rules[key]
		var level: Dictionary = levels.get(key, {})
		if entry["on"] and int(level.get("have", 0)) + int(level.get("coming", 0)) <= int(entry["point"]):
			found[key] = int(entry["quantity"])
	return found


## Adds `quantity` of a stock to a supplier basket (see Supplier) and returns it.
static func add_to_basket(basket: Dictionary, key: String, quantity: int) -> Dictionary:
	var added := basket.duplicate(true)
	if key == PACKAGING:
		added["packaging"] = int(added.get("packaging", 0)) + quantity
		return added
	var kind := "spools" if is_spool(key) else "parts"
	var id := key.trim_prefix(SPOOL if is_spool(key) else PART)
	if not added.has(kind):
		added[kind] = {}
	added[kind][id] = int(added[kind].get(id, 0)) + quantity
	return added


## The part of a basket that comes from the filament shop (`spools` true) or
## from the hardware shop.
static func shop_part(basket: Dictionary, spools: bool) -> Dictionary:
	var part := {}
	for kind: String in basket:
		if (kind == "spools") == spools:
			part[kind] = basket[kind]
	return part


func save() -> Dictionary:
	return {"rules": rules}


## Puts back saved rules, leaving out those for things the game no longer has.
func restore(saved: Dictionary) -> void:
	rules.clear()
	for key: String in saved.get("rules", {}):
		if knows(key):
			var entry: Dictionary = saved["rules"][key]
			set_rule(key, bool(entry["on"]), int(entry["point"]), int(entry["quantity"]))
