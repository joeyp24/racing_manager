class_name Race
extends Resource

@export var race_id: String = ""
@export var series_id: String = "local_short_track"
@export var season_round: int = 1
@export var race_name: String = "Unnamed Race"
@export var track_name: String = "Unnamed Track"
@export var race_date: String = "March 1"
@export var travel_region: String = "Southeast"

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
@export_range(0.0, 1.0) var power_demand: float = 0.50
@export_range(0.0, 1.0) var handling_demand: float = 0.50
@export_range(0.5, 2.0) var tyre_wear_factor: float = 1.0
@export_range(0.5, 2.0) var fuel_consumption_factor: float = 1.0
@export_range(0.0, 1.0) var overtaking_difficulty: float = 0.50
@export_range(4.0, 30.0) var pit_lane_time_loss: float = 8.0
@export_range(0.0, 2.0) var accident_factor: float = 1.0
@export_range(0.0, 2.0) var mechanical_stress: float = 1.0
@export_enum("Top Speed", "Balanced", "High Grip") var preferred_setup: String = "Balanced"
@export_enum("Short Track", "Speedway", "Road Course", "Street Course") var track_type: String = "Speedway"
@export_enum("Dry", "Mixed", "Wet") var weather: String = "Dry"
@export_range(0.0, 1.0) var heat_factor: float = 0.35

@export_multiline var description: String = ""


func get_track_charges() -> int:
	return entry_fee + driver_pit_pass + transponder_rental


func get_operating_cost() -> int:
	return travel_cost + preparation_cost + insurance_cost + facility_cost


func get_weekend_cost() -> int:
	return get_track_charges() + get_operating_cost()


func get_driver_attribute_weights() -> Dictionary:
	var weights := {"race_pace":0.30, "qualifying_pace":0.08, "tyre_management":0.12, "racecraft":0.12, "wet_weather":0.02, "starts_restarts":0.08, "consistency":0.10, "car_feedback":0.05, "fitness":0.07, "composure":0.06}
	if track_type == "Short Track":
		weights.merge({"racecraft":0.20, "starts_restarts":0.16, "race_pace":0.22}, true)
	elif track_type in ["Road Course", "Street Course"]:
		weights.merge({"qualifying_pace":0.13, "tyre_management":0.18, "car_feedback":0.08, "race_pace":0.24}, true)
	if weather == "Wet":
		weights.merge({"wet_weather":0.28, "race_pace":0.20, "composure":0.10}, true)
	return weights
