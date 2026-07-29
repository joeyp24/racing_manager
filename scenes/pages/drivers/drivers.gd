extends Control

@onready var current_driver_label: Label = %current_driver_label
@onready var hiring_status_label: Label = %hiring_status_label
@onready var candidates_container: VBoxContainer = %candidates_container
@onready var confirmation_dialog: ConfirmationDialog = %confirmation_dialog

var pending_driver: Driver = null


func _ready() -> void:
	if GameManager.team == null:
		return

	confirmation_dialog.confirmed.connect(_on_hire_confirmed)
	display_market()

	if not GameManager.team.driver_hired_for_season:
		confirmation_dialog.title = "A driver is required"
		confirmation_dialog.dialog_text = (
			"Season %d is ready. Compare the roster and hire one driver before entering a race."
			% GameManager.team.season_number
		)
		confirmation_dialog.get_ok_button().text = "View candidates"
		confirmation_dialog.popup_centered()


func display_market() -> void:
	var team: Team = GameManager.team
	var active_driver: Driver = team.get_active_driver()

	if active_driver == null:
		current_driver_label.text = "Current driver: None — hire a driver for Season %d" % team.season_number
	else:
		current_driver_label.text = "Current driver: %s\n%s" % [
			active_driver.driver_name,
			create_driver_details(active_driver)
		]

	if team.driver_hired_for_season:
		hiring_status_label.text = "Driver signed for Season %d. Changes are locked once a contract is signed." % team.season_number
	else:
		hiring_status_label.text = (
			"Pre-season hiring is open. Signing fees are charged immediately."
		)
		if not team.last_development_summary.is_empty():
			hiring_status_label.text += (
				"\nLast season's development:\n"
				+ "\n".join(team.last_development_summary)
			)

	for child in candidates_container.get_children():
		child.queue_free()

	for driver in team.drivers:
		if driver == null:
			continue
		create_candidate_row(driver)


func create_candidate_row(driver: Driver) -> void:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	var row := HBoxContainer.new()
	var details := Label.new()
	var hire_button := Button.new()

	panel.custom_minimum_size = Vector2(0, 116)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_theme_constant_override("separation", 18)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = "%s — %s\n%s\nDevelopment: %s | Last Season: %s\nCareer: %d starts | %d wins | %d podiums | %d points" % [
		driver.driver_name,
		driver.archetype,
		create_driver_details(driver),
		driver.get_development_rate(),
		driver.last_season_development,
		driver.career_starts,
		driver.career_wins,
		driver.career_podiums,
		driver.career_points
	]
	hire_button.text = "Hire"
	hire_button.custom_minimum_size = Vector2(100, 0)
	hire_button.disabled = (
		not GameManager.team.can_hire_driver()
		or GameManager.team.money < GameManager.team.get_discounted_cost(driver.signing_fee)
	)
	hire_button.pressed.connect(_on_hire_pressed.bind(driver))

	row.add_child(details)
	row.add_child(hire_button)
	margin.add_child(row)
	panel.add_child(margin)
	candidates_container.add_child(panel)


func create_driver_details(driver: Driver) -> String:
	var signing_cost := GameManager.team.get_discounted_cost(driver.signing_fee)
	return "Age %d | Potential %d | Team seasons %d | Skill %d | Consistency %d | Aggression %d | Salary $%s/race | Signing fee $%s" % [
		driver.age,
		driver.potential,
		driver.seasons_with_team,
		driver.skill,
		driver.consistency,
		driver.aggression,
		format_number(driver.salary),
		format_number(signing_cost)
	]


func _on_hire_pressed(driver: Driver) -> void:
	pending_driver = driver
	var current_driver: Driver = GameManager.team.get_active_driver()
	var replacement_text := "sign"
	if current_driver != null and current_driver != driver:
		replacement_text = "replace %s with" % current_driver.driver_name

	confirmation_dialog.title = "Confirm driver contract"
	confirmation_dialog.dialog_text = (
		"Do you want to %s %s?\n\nSigning fee: $%s (charged now)\nSalary: $%s after every race"
		% [
			replacement_text,
			driver.driver_name,
			format_number(driver.signing_fee),
			format_number(driver.salary)
		]
	)
	confirmation_dialog.get_ok_button().text = "Confirm Hire"
	confirmation_dialog.popup_centered()


func _on_hire_confirmed() -> void:
	if pending_driver == null:
		return

	if GameManager.team.hire_driver(pending_driver):
		GameManager.refresh_team_money()
		GameManager.save_game()
	pending_driver = null
	display_market()


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""
	while number_string.length() > 3:
		formatted_number = "," + number_string.right(3) + formatted_number
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted_number
