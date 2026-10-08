class_name Parcel
extends Node3D
## A packed order, boxed up and waiting for the courier.

const MODEL := preload("res://assets/models/props/parcel.glb")

var order: Marketplace.Order


static func create(p_order: Marketplace.Order) -> Parcel:
	var parcel := Parcel.new()
	parcel.order = p_order
	parcel.name = "Parcel_%d" % p_order.id
	parcel.add_child(MODEL.instantiate())
	return parcel
