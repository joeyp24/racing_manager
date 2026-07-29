extends Resource
class_name RaceTeam

@export var team_id: String = ""
@export var team_name: String = "Race Team"
@export var car_bay: int = -1
@export var driver_id: String = ""
@export var active: bool = true
@export_enum("Lead", "Second", "Equal", "Prospect") var driver_role: String = "Equal"
@export var shared_setup: bool = true
@export var team_orders: String = "Race freely"
@export var mentorship_driver_id: String = ""


func is_ready(team: Team) -> bool:
	return active and team.get_car(car_bay) != null and team.get_driver_by_id(driver_id) != null
