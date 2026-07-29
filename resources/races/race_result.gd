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
var sponsor_name: String = ""
var sponsor_race_payment: int = 0
var sponsor_objective_bonus: int = 0
var sponsor_objective_completed: bool = false
var reputation_earned: int = 0
var fans_earned: int = 0
var cheating_penalty: int = 0

var mileage_added: int = 0
var condition_lost: int = 0

var standings: Array[Dictionary] = []
