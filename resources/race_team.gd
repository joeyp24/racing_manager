extends Resource
class_name RaceTeam

@export var team_id: String = ""
@export var team_name: String = "Race Team"
@export var car_bay: int = -1
@export var backup_car_bay: int = -1
@export var driver_id: String = ""
@export var active: bool = true
@export_enum("Lead", "Second", "Equal", "Prospect") var driver_role: String = "Equal"
@export var shared_setup: bool = true
@export var team_orders: String = "Race freely"
@export var mentorship_driver_id: String = ""
@export var sponsor_contracts: Array[Dictionary] = []
@export var sponsor_offers: Array[Dictionary] = []
@export var sponsor_offer_season: int = 0
@export var sponsor_offer_series_id: String = ""
@export var crew_chief_id: String = ""
@export var engineer_ids: Array[String] = []


func is_ready(team: Team) -> bool:
	return active and team.get_car(car_bay) != null and team.get_driver_by_id(driver_id) != null


func get_operations_gaps(team: Team) -> Array[String]:
	var gaps: Array[String] = []
	if team.get_driver_by_id(driver_id) == null:
		gaps.append("driver")
	if team.get_car(car_bay) == null:
		gaps.append("car")
	if team.get_staff_by_id(crew_chief_id) == null:
		gaps.append("crew chief")
	if engineer_ids.is_empty():
		gaps.append("engineer")
	if sponsor_contracts.is_empty():
		gaps.append("sponsor")
	return gaps


func get_operations_readiness(team: Team) -> int:
	return 5 - get_operations_gaps(team).size()


func get_sponsor_income_per_race() -> int:
	var total := 0
	for contract in sponsor_contracts:
		total += int(contract.get("payment_per_race", 0))
	return total
