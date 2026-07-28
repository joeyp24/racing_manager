extends Control

@onready var driver_name_label: Label = %driver_name_label
@onready var team_name_label: Label = %team_name_label
@onready var skill_value: Label = %skill_value
@onready var consistency_value: Label = %consistency_value
@onready var aggression_value: Label = %aggression_value
@onready var salary_value: Label = %salary_value
@onready var starts_value: Label = %starts_value
@onready var wins_value: Label = %wins_value
@onready var podiums_value: Label = %podiums_value
@onready var points_value: Label = %points_value


func _ready() -> void:
	if GameManager.team == null:
		push_error(
			"Drivers page cannot display because no team is loaded."
		)
		return

	display_driver(GameManager.team.get_active_driver())


func display_driver(driver: Driver) -> void:
	if driver == null:
		driver_name_label.text = "No active driver"
		team_name_label.text = "Team unavailable"
		return

	driver_name_label.text = driver.driver_name
	team_name_label.text = driver.team_name
	skill_value.text = str(driver.skill)
	consistency_value.text = str(driver.consistency)
	aggression_value.text = str(driver.aggression)
	salary_value.text = "$%s" % format_number(driver.salary)
	starts_value.text = str(driver.career_starts)
	wins_value.text = str(driver.career_wins)
	podiums_value.text = str(driver.career_podiums)
	points_value.text = str(driver.career_points)


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""

	while number_string.length() > 3:
		formatted_number = (
			"," + number_string.right(3) + formatted_number
		)
		number_string = number_string.left(
			number_string.length() - 3
		)

	return number_string + formatted_number
