extends PanelContainer

@export var bay_index: int = 0

@onready var accent_bar: ColorRect = %accent_bar
@onready var bay_label: Label = %bay_label
@onready var assignment_label: Label = %assignment_label
@onready var status_label: Label = %status_label
@onready var occupied_content: VBoxContainer = %occupied_content
@onready var empty_content: VBoxContainer = %empty_content
@onready var car_name_label: Label = %car_name_label
@onready var car_identity_label: Label = %car_identity_label
@onready var performance_value: Label = %performance_value
@onready var condition_value: Label = %condition_value
@onready var preparation_value: Label = %preparation_value
@onready var condition_bar: ProgressBar = %condition_bar
@onready var workshop_label: Label = %workshop_label
@onready var action_button: Button = %action_button
@onready var empty_action_button: Button = %empty_action_button


func _ready() -> void:
	action_button.pressed.connect(inspect_car)
	empty_action_button.pressed.connect(open_dealership)
	update_display()


func get_car() -> Car:
	if GameManager.team == null:
		return null
	return GameManager.team.get_car(bay_index)


func inspect_car() -> void:
	var car := get_car()
	if car == null:
		return
	GameManager.selected_car = car
	GameManager.selected_bay = bay_index
	GameManager.load_page("res://scenes/pages/garage/car_inspection.tscn")


func open_dealership() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = bay_index
	GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")


func update_display() -> void:
	bay_label.text = "BAY %02d" % (bay_index + 1)
	var current_car := get_car()
	occupied_content.visible = current_car != null
	empty_content.visible = current_car == null
	if current_car != null:
		display_car(current_car)
	else:
		display_empty_bay()


func display_car(current_car: Car) -> void:
	current_car.ensure_standard_parts()
	current_car.ensure_workshop_state()
	accent_bar.color = GameManager.team.primary_color
	car_name_label.text = current_car.name
	car_identity_label.text = "%d %s %s  ·  %s" % [
		current_car.year,
		current_car.manufacturer,
		current_car.model,
		SeriesCatalog.get_series(current_car.series_id).get("name", current_car.series_id),
	]
	car_identity_label.text += "\n%s" % current_car.get_identity_summary().to_upper()
	performance_value.text = str(current_car.get_total_performance_points(GameManager.team))
	condition_value.text = "%d%%" % current_car.condition
	condition_bar.value = current_car.condition
	condition_bar.modulate = Color("59df94") if current_car.condition >= 75 else (Color("f2b84b") if current_car.condition >= 45 else Color("ff615b"))
	var next_race := RaceManager.get_next_race(GameManager.team)
	preparation_value.text = str(current_car.get_preparation_score(next_race)) if next_race != null and next_race.series_id == current_car.series_id else "—"
	assignment_label.text = _assignment_text()
	_set_status(current_car)
	workshop_label.text = _workshop_text(current_car)
	action_button.text = "INSPECT & MANAGE  →"
	action_button.tooltip_text = "Open the detailed inspection, installed parts, value, and car actions for %s." % current_car.name
	tooltip_text = "%s · %s · %s" % [assignment_label.text, status_label.text, workshop_label.text]


func display_empty_bay() -> void:
	accent_bar.color = Color("31364b")
	assignment_label.text = "AVAILABLE SPACE"
	status_label.text = "EMPTY"
	status_label.theme_type_variation = &"MutedLabel"
	empty_action_button.tooltip_text = "Open the dealership with Bay %d selected for delivery." % (bay_index + 1)
	tooltip_text = "Empty garage bay %d" % (bay_index + 1)


func _assignment_text() -> String:
	for race_team in GameManager.team.race_teams:
		if race_team == null:
			continue
		if race_team.car_bay == bay_index:
			return "PRIMARY  ·  %s" % race_team.team_name.to_upper()
	for race_team in GameManager.team.race_teams:
		if race_team != null and race_team.backup_car_bay == bay_index:
			return "BACKUP  ·  %s" % race_team.team_name.to_upper()
	return "ROTATION CAR"


func _set_status(car: Car) -> void:
	if not car.workshop_jobs.is_empty() and car.has_active_workshop_job(GameManager.team.current_season_day):
		status_label.text = "IN WORKSHOP"
		status_label.theme_type_variation = &"WarningLabel"
	elif not car.workshop_jobs.is_empty():
		status_label.text = "WORK QUEUED"
		status_label.theme_type_variation = &"InfoLabel"
	elif not car.is_initial_preparation_complete():
		status_label.text = "PREP REQUIRED"
		status_label.theme_type_variation = &"WarningLabel"
	elif car.is_race_available(GameManager.team.current_season_day):
		status_label.text = "RACE READY"
		status_label.theme_type_variation = &"SuccessLabel"
	else:
		status_label.text = "ATTENTION"
		status_label.theme_type_variation = &"DangerLabel"


func _workshop_text(car: Car) -> String:
	if not car.workshop_jobs.is_empty():
		var jobs := car.workshop_jobs.duplicate()
		jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("start_day", 0)) < int(b.get("start_day", 0)))
		var next_job := jobs[0] as Dictionary
		var start_day := int(next_job.get("start_day", GameManager.team.current_season_day))
		var completion_day := int(next_job.get("completion_day", start_day))
		if start_day > GameManager.team.current_season_day:
			return "QUEUED  ·  %s starts %s" % [next_job.get("label", "Workshop job"), CalendarCatalog.format_day(start_day)]
		return "WORKSHOP  ·  %s ready %s" % [next_job.get("label", "Workshop job"), CalendarCatalog.format_day(completion_day)]
	if not car.is_initial_preparation_complete():
		return "ACTION NEEDED  ·  Schedule inspection, setup, and shakedown"
	if car.condition < 75 or car.get_damage_points() > 0.5:
		return "RECOMMENDED  ·  Review service and component repairs"
	return "WORKSHOP  ·  No work scheduled"
