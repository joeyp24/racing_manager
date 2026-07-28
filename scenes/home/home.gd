extends Control

@onready var page_container: Control = %page_container
@onready var home_button: Button = %home_button
@onready var garage_button: Button = %garage_button
@onready var drivers_button: Button = %drivers_button
@onready var championship_button: Button = %championship_button
@onready var race_calendar_button: Button = %race_calendar_button
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

	race_calendar_button.pressed.connect(
		_on_race_calendar_button_pressed
	)

	if not GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.connect(
			_on_team_money_changed
		)

	update_team_display()

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
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


func _on_race_calendar_button_pressed() -> void:
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_calendar/race_calendar.tscn"
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
