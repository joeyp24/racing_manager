class_name RaceEntryState
extends RefCounted

var driver_id: String = ""
var driver_name: String = ""
var team_name: String = ""
var is_player: bool = false

var position: int = 0
var starting_position: int = 0
var completed_laps: int = 0
var elapsed_time: float = 0.0
var last_lap_time: float = 0.0
var best_lap_time: float = 0.0
var base_pace: float = 0.0
var consistency: int = 50

var tyre_compound: String = "Medium"
var tyre_condition: float = 100.0
var fuel_remaining: float = 100.0
var car_condition: float = 100.0
var pit_stops: int = 0

var pace_mode: String = "Balanced"
var pending_pace_mode: String = "Balanced"
var status: String = "Running"


func gap_to(other: RaceEntryState) -> float:
	return maxf(0.0, elapsed_time - other.elapsed_time)
