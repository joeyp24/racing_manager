class_name RaceEntryState
extends RefCounted

var driver_id: String = ""
var driver_name: String = ""
var team_id: String = ""
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
var aggression: int = 50
var reliability: float = 75.0
var fuel_efficiency: float = 50.0
var tyre_preservation: float = 50.0
var attributes: Dictionary = {}

var tyre_compound: String = "Standard"
var tyre_condition: float = 100.0
var tyre_temperature: float = 80.0
var stint_laps: int = 0
var fuel_remaining: float = 100.0
var fuel_laps: float = 0.0
var fuel_target_laps: float = 0.0
var car_condition: float = 100.0
var mechanical_health: float = 100.0
var component_health: Dictionary = {
	"aerodynamics": 100.0,
	"suspension": 100.0,
	"engine": 100.0,
	"brakes": 100.0,
	"drivetrain": 100.0
}
var mechanical_warning_level: int = 0
var pit_stops: int = 0
var pending_pit_compound: String = ""
var pending_pit_service: Dictionary = {}
var last_pit_lap: int = -1
var setup_mode: String = "Balanced"
var setup_profile: Dictionary = {}
var brake_bias: String = "Neutral"
var retired_lap: int = 0
var incident_time_loss: float = 0.0
var traffic_time_loss: float = 0.0
var overtakes: int = 0
var overtaken: int = 0
var caution_position_gain: int = 0
var laps_down: int = 0
var strategy_skill: float = 50.0
var philosophy_id: String = "balanced"
var strategy_aggression: float = 0.0
var reliability_bias: float = 0.0
var qualifying_bias: float = 0.0
var youth_bias: float = 0.0
var development_bias: float = 0.0
var difficulty_scale: float = 1.0
var fuel_target_mode: String = "Balanced"
var racecraft_command: String = "Race"
var team_order: String = "Race freely"
var defend_target_id: String = ""

var pace_mode: String = "Balanced"
var pending_pace_mode: String = "Balanced"
var status: String = "Running"


func gap_to(other: RaceEntryState) -> float:
	return maxf(0.0, elapsed_time - other.elapsed_time)


func rating(field: String, fallback: int = 50) -> int:
	return int(attributes.get(field, fallback))
