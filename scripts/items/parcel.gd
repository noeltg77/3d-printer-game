class_name Parcel
extends Node3D
## A packed order, boxed up and waiting for the courier. Or a crate of items
## for a contract, which has no order: it names the contract and how many are in it.

const MODEL := preload("res://assets/models/props/parcel.glb")
## A crate is the same box, drawn bigger.
const CRATE_SCALE := 1.35

var order: Marketplace.Order
## Id of the contract a crate is for, or 0 for an ordinary parcel, and the items in it.
var contract := 0
var count := 0


static func create(p_order: Marketplace.Order) -> Parcel:
	var parcel := Parcel.new()
	parcel.order = p_order
	parcel.name = "Parcel_%d" % p_order.id
	parcel.add_child(MODEL.instantiate())
	return parcel


static func create_crate(p_contract: int, p_count: int) -> Parcel:
	var parcel := Parcel.new()
	parcel.contract = p_contract
	parcel.count = p_count
	parcel.name = "Crate_%d" % p_contract
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * CRATE_SCALE
	parcel.add_child(model)
	return parcel
