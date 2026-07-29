extends Control

@onready var page_container: Control = %page_container
@onready var home_button: Button = %home_button
@onready var garage_button: Button = %garage_button
@onready var drivers_button: Button = %drivers_button
@onready var championship_button: Button = %championship_button
@onready var staff_button: Button = %staff_button
@onready var race_calendar_button: Button = %race_calendar_button
@onready var shop_button: Button = %shop_button
@onready var dealership_button: Button = %dealership_button
@onready var sponsors_button: Button = %sponsors_button
@onready var hq_button: Button = %hq_button
@onready var scouting_button: Button = %scouting_button
@onready var money_label: Label = %money_label


func _ready() -> void:
	GameManager.page_container = page_container

	home_button.pressed.connect(
		_on_home_button_pressed
	)

	garage_button.pressed.connect(
		_on_garage_button_pressed
	)

	drivers_button.pressed.connect(
		_on_drivers_button_pressed
	)

	championship_button.pressed.connect(
		_on_championship_button_pressed
	)
	staff_button.pressed.connect(_on_staff_button_pressed)

	race_calendar_button.pressed.connect(
		_on_race_calendar_button_pressed
	)

	shop_button.pressed.connect(_on_shop_button_pressed)
	dealership_button.pressed.connect(_on_dealership_button_pressed)
	sponsors_button.pressed.connect(_on_sponsors_button_pressed)
	hq_button.pressed.connect(_on_hq_button_pressed)
	scouting_button.pressed.connect(_on_scouting_button_pressed)

	if not GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.connect(
			_on_team_money_changed
		)

	update_team_display()
	update_unlocked_navigation()

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)

	if (
		GameManager.team != null
		and not GameManager.team.driver_hired_for_season
	):
		GameManager.load_page(
			"res://scenes/pages/drivers/drivers.tscn"
		)


func _exit_tree() -> void:
	if GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.disconnect(
			_on_team_money_changed
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.save_game()
		get_tree().quit()


func _on_home_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)


func _on_garage_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)


func _on_drivers_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/drivers/drivers.tscn"
	)


func _on_championship_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/championship/championship.tscn"
	)


func _on_staff_button_pressed() -> void:
	GameManager.load_page("res://scenes/pages/staff/staff.tscn")


func _on_race_calendar_button_pressed() -> void:
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_calendar/race_calendar.tscn"
	)


func _on_shop_button_pressed() -> void:
	GameManager.load_page("res://scenes/pages/shop/shop.tscn")


func _on_dealership_button_pressed() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = -1
	GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")


func _on_sponsors_button_pressed() -> void:
	GameManager.load_page("res://scenes/pages/sponsors/sponsors.tscn")


func _on_hq_button_pressed() -> void:
	GameManager.load_page("res://scenes/pages/departments/departments.tscn")


func _on_scouting_button_pressed() -> void:
	GameManager.load_page("res://scenes/pages/scouting/scouting.tscn")


func update_unlocked_navigation() -> void:
	scouting_button.visible = (
		GameManager.team != null
		and GameManager.team.get_department_level("scouting") > 0
	)


func _on_reset_game_button_pressed() -> void:
	GameManager.reset_game()


func _on_team_money_changed(
	new_amount: int
) -> void:
	update_money_label(new_amount)


func update_team_display() -> void:
	if GameManager.team == null:
		money_label.text = "Money: $0"
		return

	update_money_label(
		GameManager.team.money
	)


func update_money_label(amount: int) -> void:
	money_label.text = (
		"Money: $%s"
		% format_number(amount)
	)


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""

	while number_string.length() > 3:
		formatted_number = (
			","
			+ number_string.right(3)
			+ formatted_number
		)

		number_string = number_string.left(
			number_string.length() - 3
		)

	return number_string + formatted_number
