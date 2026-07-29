class_name Race
extends Resource

@export var race_id: String = ""
@export var race_name: String = "Unnamed Race"
@export var track_name: String = "Unnamed Track"
@export var race_date: String = "March 1"

@export_range(1, 500, 1)
var lap_count: int = 50

@export_range(0, 1000000, 100)
var entry_fee: int = 50

@export_range(0, 10000, 5) var driver_pit_pass: int = 40
@export_range(0, 10000, 5) var transponder_rental: int = 15
@export_range(0, 100000, 10) var travel_cost: int = 350
@export_range(0, 100000, 10) var preparation_cost: int = 250
@export_range(0, 100000, 10) var insurance_cost: int = 75
@export_range(0, 100000, 10) var facility_cost: int = 125

@export_range(0, 10000000, 100)
var first_place_prize: int = 5000

@export_range(0, 10000000, 100)
var second_place_prize: int = 2500

@export_range(0, 10000000, 100)
var third_place_prize: int = 1000

@export_range(1, 100, 1)
var difficulty: int = 25

@export_multiline var description: String = ""


func get_track_charges() -> int:
	return entry_fee + driver_pit_pass + transponder_rental


func get_operating_cost() -> int:
	return travel_cost + preparation_cost + insurance_cost + facility_cost


func get_weekend_cost() -> int:
	return get_track_charges() + get_operating_cost()
