extends Resource
class_name Driver

@export var driver_id: String = ""
@export var driver_name: String = "Unnamed Driver"

@export_range(1, 100) var skill: int = 50
@export_range(1, 100) var consistency: int = 50
@export_range(1, 100) var aggression: int = 50

@export_range(16, 70) var age: int = 25
@export_range(1, 100) var potential: int = 80
@export var seasons_with_team: int = 0
@export var development_points: int = 0
@export var season_starts: int = 0
@export var last_season_development: String = "No change"

@export var salary: int = 1500
@export var signing_fee: int = 2500
@export var archetype: String = "Balanced club racer"
@export var assigned_bay: int = -1

@export var team_name: String = ""
@export var is_player_driver: bool = false

@export var career_starts: int = 0
@export var career_wins: int = 0
@export var career_podiums: int = 0
@export var career_points: int = 0


func get_development_rate() -> String:
	if age >= 34:
		return "Declining"

	var current_ability: int = (skill + consistency + aggression) / 3
	var growth_room: int = potential - current_ability

	if age <= 23 and growth_room >= 15:
		return "Rapid"
	if age <= 29 and growth_room >= 6:
		return "Steady"
	return "Limited"
