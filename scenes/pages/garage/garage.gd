extends Control

@onready var workshop_button: Button = %workshop_button
@onready var fleet_summary_label: Label = %fleet_summary_label


func _ready() -> void:
	workshop_button.pressed.connect(_open_workshop)
	var team := GameManager.team
	if team == null:
		return
	var active_jobs := 0
	var available_cars := 0
	for car_value in team.cars:
		var car := car_value as Car
		if car == null:
			continue
		active_jobs += car.workshop_jobs.size()
		if car.is_race_available(team.current_season_day):
			available_cars += 1
	fleet_summary_label.text = "%d cars  ·  %d available today  ·  %d workshop jobs  ·  $%s weekly additional-car upkeep" % [
		team.get_owned_car_count(), available_cars, active_jobs, String.num_int64(team.get_fleet_weekly_upkeep())
	]


func _open_workshop() -> void:
	GameManager.load_page("res://scenes/pages/garage/fleet_workshop.tscn")
