extends Resource
class_name Driver

@export var driver_id: String = ""
@export var driver_name: String = "Unnamed Driver"

@export_range(1, 100) var skill: int = 50
@export_range(1, 100) var consistency: int = 50
@export_range(1, 100) var aggression: int = 50

@export var salary: int = 1500
@export var assigned_bay: int = -1

@export var team_name: String = ""
@export var is_player_driver: bool = false

@export var career_starts: int = 0
@export var career_wins: int = 0
@export var career_podiums: int = 0
@export var career_points: int = 0
