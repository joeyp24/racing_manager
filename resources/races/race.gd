class_name Race
extends Resource

@export var race_id: String = ""
@export var race_name: String = "Unnamed Race"
@export var track_name: String = "Unnamed Track"
@export var race_date: String = "March 1"

@export_range(1, 500, 1)
var lap_count: int = 50

@export_range(0, 1000000, 100)
var entry_fee: int = 1000

@export_range(0, 10000000, 100)
var first_place_prize: int = 5000

@export_range(0, 10000000, 100)
var second_place_prize: int = 2500

@export_range(0, 10000000, 100)
var third_place_prize: int = 1000

@export_range(1, 100, 1)
var difficulty: int = 25

@export_multiline var description: String = ""
