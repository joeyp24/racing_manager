class_name RaceResult
extends RefCounted

var race: Race = null
var player_car: Car = null
var player_driver: Driver = null

var finishing_position: int = 0
var field_size: int = 0

var championship_points_earned: int = 0
var total_championship_points: int = 0

var prize_money: int = 0
var entry_fee: int = 0
var driver_salary: int = 0
var crew_chief_salary: int = 0
var engineering_payroll: int = 0
var expired_staff_names: Array[String] = []
var repair_cost: int = 0
var net_earnings: int = 0
var commercial_revenue: int = 0
var series_distribution: int = 0
var gate_revenue: int = 0
var owner_race_support: int = 0
var manufacturer_race_support: int = 0
var sponsor_name: String = ""
var sponsor_race_payment: int = 0
var sponsor_objective_bonus: int = 0
var sponsor_objective_completed: bool = false
var sponsor_failure_penalty: int = 0
var pay_driver_income: int = 0
var reputation_earned: int = 0
var reputation_changes: Dictionary = {}
var fans_earned: int = 0
var cheating_penalty: int = 0
var penalties: Array[Dictionary] = []
var appeals: Array[Dictionary] = []
var weather_summary: String = "Dry"
var track_evolution_summary: String = ""
var replay_timeline: Array[Dictionary] = []
var strategy_timeline: Array[Dictionary] = []
var decisive_moments: Array[Dictionary] = []
var component_degradation: Dictionary = {}
var counterfactuals: Array[String] = []
var engineer_accuracy: float = 0.0
var engineer_call_count: int = 0
var traffic_time_lost: float = 0.0
var caution_position_gain: int = 0
var overtime_attempts: int = 0
var scheduled_laps: int = 0
var completed_laps: int = 0
var track_presentation: Dictionary = {}
var qualifying_format: String = "Standard"
var team_order_summary: String = "Race freely"

var mileage_added: int = 0
var condition_lost: int = 0

var strategy_id: String = "balanced"
var strategy_name: String = "Balanced"
var strategy_performance_modifier: float = 1.0
var strategy_variance_modifier: float = 1.0
var strategy_wear_modifier: float = 1.0

var starting_position: int = 0
var expected_finishing_position: int = 0
var positions_gained: int = 0
var practice_focus_name: String = ""
var qualifying_approach_name: String = ""
var qualifying_score: float = 0.0
var setup_bonus: float = 0.0
var strategy_effectiveness: float = 0.0
var weekend_summary: Array[String] = []

# Transparent post-race attribution. Positive values helped the player; negative
# values cost pace or track position. These are display values, not a second
# simulation, so the results screen can explain the formula that already ran.
var driver_factor: float = 0.0
var car_factor: float = 0.0
var setup_factor: float = 0.0
var strategy_factor: float = 0.0
var pit_stop_factor: float = 0.0
var incident_factor: float = 0.0
var pit_stop_summary: String = "No pit stops recorded"
var incident_summary: String = "No significant random incident recorded"

var standings: Array[Dictionary] = []
