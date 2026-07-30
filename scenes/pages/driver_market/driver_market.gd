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
	var contracted := team.get_contracted_drivers()

	if active_driver == null:
		current_driver_label.text = "Current driver: None — hire a driver for Season %d" % team.season_number
	else:
		current_driver_label.text = "Lead driver: %s · %d contracted\n%s" % [
			active_driver.driver_name,
			contracted.size(),
			create_driver_details(active_driver)
		]

	if team.is_series_season_complete() or not team.get_completed_races().is_empty():
		hiring_status_label.text = "Driver hiring is locked after the first race. Manage assignments on the Race Teams page."
	elif contracted.size() >= team.get_driver_roster_limit():
		hiring_status_label.text = "Driver roster full: %d / %d contracted. Manage assignments on the Race Teams page." % [
			contracted.size(),
			team.get_driver_roster_limit()
		]
	else:
		hiring_status_label.text = (
			"Pre-season hiring is open · %d / %d drivers contracted. You can hire more than one driver for your race teams."
			% [contracted.size(), team.get_driver_roster_limit()]
		)
		if not team.last_development_summary.is_empty():
			hiring_status_label.text += (
				"\nLast season's development:\n"
				+ "\n".join(team.last_development_summary)
			)

	for child in candidates_container.get_children():
		child.queue_free()

	for driver in team.get_contracted_drivers():
		if driver == null:
			continue
		create_candidate_row(driver)

	for driver in team.drivers:
		if driver == null:
			continue
		if team.contracted_driver_ids.has(driver.driver_id):
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
	var active := GameManager.team.get_active_driver()
	details.tooltip_text = _driver_comparison_tooltip(driver, active)
	var is_contracted := GameManager.team.contracted_driver_ids.has(driver.driver_id)
	var has_accepted_offer := bool((GameManager.team.contract_offers.get(driver.driver_id, {}) as Dictionary).get("accepted", false))
	hire_button.text = "Contracted" if is_contracted else ("Sign" if has_accepted_offer else "Negotiate")
	hire_button.custom_minimum_size = Vector2(100, 0)
	hire_button.disabled = (
		is_contracted
		or (has_accepted_offer and not GameManager.team.can_hire_driver(driver))
		or (not has_accepted_offer and not GameManager.team.can_negotiate_with_driver(driver))
		or GameManager.team.money < GameManager.team.get_discounted_cost(driver.signing_fee)
	)
	if hire_button.disabled:
		if is_contracted:
			hire_button.tooltip_text = "Disabled: this driver is already under contract."
		elif GameManager.team.money < GameManager.team.get_discounted_cost(driver.signing_fee):
			hire_button.tooltip_text = "Disabled: you need $%s more for the signing fee." % format_number(GameManager.team.get_discounted_cost(driver.signing_fee) - GameManager.team.money)
		elif GameManager.team.get_reputation_level() < GameManager.team.get_driver_required_level(driver):
			hire_button.tooltip_text = "Reach team level %d to negotiate with this driver." % GameManager.team.get_driver_required_level(driver)
		elif int(GameManager.team.recruiting_progress.get(driver.driver_id, 0)) < 50:
			hire_button.tooltip_text = "Recruit this driver to at least 50%% interest in Scouting."
		else:
			hire_button.tooltip_text = "Disabled: hiring is closed or the driver roster is full."
	hire_button.pressed.connect(_on_hire_pressed.bind(driver))

	row.add_child(details)
	row.add_child(hire_button)
	margin.add_child(row)
	panel.add_child(margin)
	candidates_container.add_child(panel)


func _driver_comparison_tooltip(driver: Driver, active: Driver) -> String:
	if active == null or active == driver:
		return "Skill drives pace; consistency reduces variance; aggression adds overtaking pace and risk."
	return "Compared with %s: Skill %+d  •  Consistency %+d  •  Aggression %+d  •  Salary %s$%s/race" % [active.driver_name, driver.skill - active.skill, driver.consistency - active.consistency, driver.aggression - active.aggression, "+" if driver.salary >= active.salary else "−", format_number(absi(driver.salary - active.salary))]


func create_driver_details(driver: Driver) -> String:
	var signing_cost := GameManager.team.get_discounted_cost(driver.signing_fee)
	var report := GameManager.team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var potential_display := str(driver.get_potential_overall()) if report.get("revealed_potential", false) or GameManager.team.contracted_driver_ids.has(driver.driver_id) else "???"
	return "Age %d | OVR %d | Potential OVR %s | Required level %d | Team seasons %d | Race pace %d | Qualifying %d | Tyre management %d | Salary $%s/race | Signing fee $%s" % [
		driver.age,
		driver.get_overall_rating(),
		potential_display,
		GameManager.team.get_driver_required_level(driver),
		driver.seasons_with_team,
		driver.race_pace,
		driver.qualifying_pace,
		driver.tyre_management,
		format_number(driver.salary),
		format_number(signing_cost)
	]


func _on_hire_pressed(driver: Driver) -> void:
	pending_driver = driver
	var accepted := bool((GameManager.team.contract_offers.get(driver.driver_id, {}) as Dictionary).get("accepted", false))
	if not accepted:
		var response := GameManager.team.negotiate_driver_contract(driver, driver.salary, driver.signing_fee, driver.contract_length)
		GameManager.save_game()
		confirmation_dialog.title = "Contract negotiation"
		confirmation_dialog.dialog_text = "%s\n\nProposed: $%s/race, $%s signing bonus, %d races." % [response.reason, format_number(driver.salary), format_number(driver.signing_fee), driver.contract_length]
		confirmation_dialog.get_ok_button().text = "Continue"
		confirmation_dialog.popup_centered()
		return
	confirmation_dialog.title = "Confirm driver contract"
	confirmation_dialog.dialog_text = (
		"Do you want to sign %s to your multi-team roster?\n\nSigning fee: $%s (charged now)\nSalary: $%s after every race"
		% [
			driver.driver_name,
			format_number(GameManager.team.get_discounted_cost(driver.signing_fee)),
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
