class_name Parcel
extends Node3D
## A packed order, wrapped up and waiting for the courier. Or a crate of items
## for a contract, which has no order: it names the contract and how many are in it.
##
## The model is the packaging it went in (data/packaging.json). Its flaps are
## separate meshes named for the edge they hinge on (`flap_xp`, `flap_xn`,
## `flap_yp`, `flap_yn`, by the generator's axes), so it can be laid open on
## the packing station and closed up.

## What a parcel looks like when its packaging has no model of its own.
const MODEL := preload("res://assets/models/props/parcel.glb")
## A crate is the same box, drawn bigger.
const CRATE_SCALE := 1.35
## How far a flap folds back when the packaging is open.
const FLAP_OPEN := deg_to_rad(125.0)
## Which way each flap turns to open, about its own hinge.
const FLAP_TURNS := {
	"flap_xp": Vector3(0, 0, -1), "flap_xn": Vector3(0, 0, 1),
	"flap_yp": Vector3(-1, 0, 0), "flap_yn": Vector3(1, 0, 0),
}

var order: Marketplace.Order
## Id of the contract a crate is for, or 0 for an ordinary parcel, and the items in it.
var contract := 0
var count := 0
## What a printer sold second hand fetches, in pence, and what it was. 0 for anything else.
var resale := 0
var resale_title := ""
## How tall it stands, in metres.
var height := 0.14

var _flaps: Array[Node3D] = []


## A parcel for an order, in `kind` of packaging: by default what the order was packed in.
static func create(p_order: Marketplace.Order, kind: StringName = &"") -> Parcel:
	var parcel := Parcel.new()
	parcel.order = p_order
	parcel.name = "Parcel_%d" % p_order.id
	parcel._build(String(kind) if kind != &"" else String(p_order.shipping.get("packaging", "")))
	return parcel


static func create_crate(p_contract: int, p_count: int) -> Parcel:
	var parcel := Parcel.new()
	parcel.contract = p_contract
	parcel.count = p_count
	parcel.name = "Crate_%d" % p_contract
	parcel._build("medium_cardboard_box").scale = Vector3.ONE * CRATE_SCALE
	return parcel


## A printer boxed up for whoever bought it second hand.
static func create_resale(title: String, pence: int) -> Parcel:
	var parcel := Parcel.new()
	parcel.resale = pence
	parcel.resale_title = title
	parcel.name = "Resale_%s" % title.to_snake_case()
	parcel.add_child(DeliveryBox.PRINTER_MODEL.instantiate())
	parcel.height = 0.35
	return parcel


func _build(kind: String) -> Node3D:
	var row: Dictionary = Game.data.packaging.get(kind, {})
	var path := GameData.PACKAGING_MODEL % row.get("model", "")
	var model: Node3D = (load(path) as PackedScene if ResourceLoader.exists(path) else MODEL).instantiate()
	add_child(model)
	if not row.is_empty():
		height = float(row["look"]["size"][2])
	for flap: Node3D in model.find_children("flap_*", "Node3D", true, false):
		_flaps.append(flap)
	return model


## Folds the flaps back: 1.0 wide open, 0.0 shut.
func set_open(amount: float) -> void:
	for flap in _flaps:
		flap.rotation = (FLAP_TURNS.get(String(flap.name), Vector3.ZERO) as Vector3) * FLAP_OPEN * amount


## Shuts the flaps over `seconds`.
func close(seconds: float) -> void:
	if _flaps.is_empty():
		return
	var tween := create_tween()
	tween.tween_method(set_open, 1.0, 0.0, seconds)
	await tween.finished
