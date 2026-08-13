extends PanelContainer

@export var bay_index: int = 0

@onready var car_name_label: Label = %car_name_label
@onready var car_details_label: Label = %car_details_label
@onready var action_button: Button = %action_button


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	update_display()


func get_car():
	return GameManager.team.get_car(bay_index)


func _on_action_button_pressed() -> void:
	if get_car() != null:
		inspect_car()
	else:
		open_dealership()


func inspect_car() -> void:
	GameManager.selected_car = get_car()
	GameManager.selected_bay = bay_index

	GameManager.load_page(
		"res://scenes/pages/garage/car_inspection.tscn"
	)


func open_dealership() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = bay_index

	GameManager.load_page(
		"res://scenes/pages/dealership/dealership.tscn"
	)


func update_display() -> void:
	var current_car = get_car()

	if current_car != null:
		display_car(current_car)
	else:
		display_empty_bay()


func display_car(current_car: Car) -> void:
	car_name_label.text = current_car.name
	current_car.ensure_workshop_state()
	var availability := "AVAILABLE" if current_car.is_race_available(GameManager.team.current_season_day) else "UNAVAILABLE"
	var job_summary := "No scheduled work"
	if not current_car.workshop_jobs.is_empty():
		var next_job := current_car.workshop_jobs[0]
		job_summary = "%s until %s" % [next_job.get("label", "Workshop job"), CalendarCatalog.format_day(int(next_job.get("completion_day", GameManager.team.current_season_day)))]
	car_details_label.text = (
		"%d PERFORMANCE POINTS\n%d %s %s\nCondition: %d%%  ·  %s\n%s"
		% [
			current_car.get_total_performance_points(GameManager.team),
			current_car.year,
			current_car.manufacturer,
			current_car.model,
			current_car.condition,
			availability,
			job_summary,
		]
	)
	car_details_label.add_theme_font_size_override("font_size", 18)

	action_button.text = "Inspect Car"
	action_button.disabled = false


func display_empty_bay() -> void:
	car_name_label.text = "No Car"
	car_details_label.text = "Empty Garage Bay"
	action_button.text = "Visit Dealership"
	action_button.disabled = false
