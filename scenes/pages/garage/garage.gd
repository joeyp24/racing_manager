extends Control

@onready var workshop_button: Button = %workshop_button
@onready var dealership_button: Button = %dealership_button
@onready var fleet_summary_label: Label = %fleet_summary_label
@onready var owned_value: Label = %owned_value
@onready var owned_context: Label = %owned_context
@onready var available_value: Label = %available_value
@onready var available_context: Label = %available_context
@onready var workshop_value: Label = %workshop_value
@onready var workshop_context: Label = %workshop_context
@onready var upkeep_value: Label = %upkeep_value
@onready var upkeep_context: Label = %upkeep_context
@onready var next_event_label: Label = %next_event_label
@onready var garage_content: GridContainer = %garage_content


func _ready() -> void:
	workshop_button.pressed.connect(_open_workshop)
	dealership_button.pressed.connect(_open_dealership)
	_refresh_summary()
	_update_responsive_grid()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_responsive_grid()


func _refresh_summary() -> void:
	var team := GameManager.team
	if team == null:
		return
	var active_jobs := 0
	var active_cars := 0
	var available_cars := 0
	for car_value in team.cars:
		var car := car_value as Car
		if car == null:
			continue
		active_jobs += car.workshop_jobs.size()
		if car.has_active_workshop_job(team.current_season_day):
			active_cars += 1
		if car.is_race_available(team.current_season_day):
			available_cars += 1
	var owned := team.get_owned_car_count()
	var open_bays := Team.GARAGE_SIZE - owned
	owned_value.text = "%d / %d" % [owned, Team.GARAGE_SIZE]
	owned_context.text = "%d bay%s open" % [open_bays, "" if open_bays == 1 else "s"] if open_bays > 0 else "Garage at capacity"
	available_value.text = str(available_cars)
	available_context.text = "%d need%s attention" % [owned - available_cars, "s" if owned - available_cars == 1 else ""] if owned > available_cars else "Every owned car is available"
	workshop_value.text = str(active_jobs)
	workshop_context.text = "%d car%s active today" % [active_cars, "" if active_cars == 1 else "s"] if active_jobs > 0 else "No scheduled jobs"
	upkeep_value.text = "$%s" % String.num_int64(team.get_fleet_weekly_upkeep())
	upkeep_context.text = "Weekly additional-car cost"
	dealership_button.disabled = open_bays <= 0
	dealership_button.text = "GARAGE FULL" if dealership_button.disabled else "VISIT DEALERSHIP"
	var next_race := RaceManager.get_next_race(team)
	if next_race != null:
		next_event_label.text = "NEXT EVENT  ·  %s  ·  %s" % [next_race.race_name, CalendarCatalog.format_day(next_race.schedule_day)]
		fleet_summary_label.text = "%d available today. Prepare the rotation for %s, or inspect a car for parts and condition details." % [available_cars, next_race.race_name]
	else:
		next_event_label.text = "NEXT EVENT  ·  No event scheduled"
		fleet_summary_label.text = "%d available today. Inspect a car for parts and condition details, or plan workshop work." % available_cars


func _update_responsive_grid() -> void:
	garage_content.columns = 1 if size.x < 820.0 else 2


func _open_workshop() -> void:
	GameManager.load_page("res://scenes/pages/garage/fleet_workshop.tscn")


func _open_dealership() -> void:
	if GameManager.team == null:
		return
	for bay in GameManager.team.cars.size():
		if GameManager.team.get_car(bay) == null:
			GameManager.selected_car = null
			GameManager.selected_bay = bay
			GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")
			return
