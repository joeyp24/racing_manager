extends Control

@onready var current_driver_label: Label = %current_driver_label
@onready var hiring_status_label: Label = %hiring_status_label
@onready var candidates_container: VBoxContainer = %candidates_container
@onready var confirmation_dialog: ConfirmationDialog = %confirmation_dialog
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

var pending_driver: Driver = null


func _ready() -> void:
	comparison_drawer.action_requested.connect(_on_comparison_action)
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
		var career_state := team.get_ai_driver_state(driver.driver_id)
		if bool(career_state.get("retired", false)):
			continue
		var current_team_id := str(career_state.get("current_team_id", ""))
		if not current_team_id.is_empty() and current_team_id != "player_team":
			continue
		create_candidate_row(driver)


func create_candidate_row(driver: Driver) -> void:
	PersonalityCatalog.assign_identity(driver)
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	var row := HBoxContainer.new()
	var details := Label.new()
	var hire_button := Button.new()

	panel.custom_minimum_size = Vector2(0, 108)
	panel.theme_type_variation = &"CardPanel"
	margin.add_theme_constant_override("margin_left", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_top", UITokens.CARD_PADDING_VERTICAL)
	margin.add_theme_constant_override("margin_right", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_bottom", UITokens.CARD_PADDING_VERTICAL)
	row.add_theme_constant_override("separation", UITokens.SPACE_LG)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = "%s — %s\n%s  /  %s\n%s\nDevelopment: %s | Last Season: %s\nCareer: %d starts | %d wins | %d podiums | %d points" % [
		driver.driver_name,
		driver.archetype,
		driver.get_personality_name().to_upper(),
		driver.personality_tagline,
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
	hire_button.text = "Review"
	hire_button.custom_minimum_size = Vector2(96, UITokens.CONTROL_HEIGHT)
	hire_button.tooltip_text = "Compare performance, contract cost, and season forecast. Scouting is optional and reveals more information."
	hire_button.pressed.connect(_show_driver_comparison.bind(driver))

	var portrait := DriverPortrait.new()
	portrait.custom_minimum_size = Vector2(78, 78)
	portrait.configure(driver, GameManager.team.primary_color, GameManager.team.secondary_color)
	row.add_child(portrait)
	row.add_child(details)
	row.add_child(hire_button)
	margin.add_child(row)
	panel.add_child(margin)
	candidates_container.add_child(panel)


func _driver_comparison_tooltip(driver: Driver, active: Driver) -> String:
	if active == null or active == driver:
		return "Skill drives pace; consistency reduces variance; aggression adds overtaking pace and risk."
	var salary_delta := GameManager.team.get_effective_salary(driver.salary) - GameManager.team.get_effective_salary(active.salary)
	return "Compared with %s: Skill %+d  •  Consistency %+d  •  Aggression %+d  •  Salary %s$%s/race" % [active.driver_name, driver.skill - active.skill, driver.consistency - active.consistency, driver.aggression - active.aggression, "+" if salary_delta >= 0 else "−", format_number(absi(salary_delta))]


func create_driver_details(driver: Driver) -> String:
	var signing_cost := GameManager.team.get_discounted_cost(driver.signing_fee)
	var prestige_terms := GameManager.team.get_driver_negotiation_terms(driver)
	var salary_change := roundi((float(prestige_terms.salary_multiplier) - 1.0) * 100.0)
	var report := GameManager.team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var potential_display := str(driver.get_potential_overall()) if report.get("revealed_potential", false) or GameManager.team.contracted_driver_ids.has(driver.driver_id) else "???"
	var commercial_terms := " | PAY DRIVER +$%s/race" % format_number(GameManager.team.get_effective_sponsor_value(driver.sponsorship_contribution_per_race)) if driver.is_pay_driver else ""
	return ("Age %d | OVR %d | Potential OVR %s | Recommended prestige L%d | Terms %+d%% | Team seasons %d | Race pace %d | Qualifying %d | Tyre management %d | Salary $%s/race | Signing fee $%s" % [
		driver.age,
		driver.get_overall_rating(),
		potential_display,
		GameManager.team.get_driver_required_level(driver),
		salary_change,
		driver.seasons_with_team,
		driver.race_pace,
		driver.qualifying_pace,
		driver.tyre_management,
		format_number(GameManager.team.get_effective_salary(driver.salary)),
		format_number(signing_cost)
	]) + commercial_terms


func _show_driver_comparison(driver: Driver) -> void:
	var team: Team = GameManager.team
	var active := team.get_active_driver()
	var signing_cost := team.get_discounted_cost(driver.signing_fee)
	var commercial_signing := team.get_effective_sponsor_value(driver.sponsorship_signing_bonus) if driver.is_pay_driver else 0
	var salary := team.get_effective_salary(driver.salary)
	var enters_immediately := not team.driver_hired_for_season and team.get_completed_races().is_empty()
	var commercial_income := team.get_effective_sponsor_value(driver.sponsorship_contribution_per_race) if driver.is_pay_driver and enters_immediately else 0
	var report := team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var potential_known := bool(report.get("revealed_potential", false)) or team.contracted_driver_ids.has(driver.driver_id)
	var accepted := bool((team.contract_offers.get(driver.driver_id, {}) as Dictionary).get("accepted", false))
	var contracted := team.contracted_driver_ids.has(driver.driver_id)
	var eligible := not contracted and (team.can_hire_driver(driver) if accepted else team.can_negotiate_with_driver(driver))
	var disabled_reason := ""
	if contracted:
		disabled_reason = "This driver is already under contract."
	elif accepted and not team.can_hire_driver(driver):
		disabled_reason = "Hiring is closed or the driver roster is full."
	elif accepted and team.money < signing_cost:
		disabled_reason = "The full signing fee must be available before commercial backing is received."
	elif not eligible:
		disabled_reason = "This driver is not currently available for negotiation."
	var current_name := active.driver_name if active != null else "Open seat"
	var metrics: Array = [
		_driver_metric("Overall", active.get_overall_rating() if active != null else 0, driver.get_overall_rating(), active != null),
		_driver_metric("Race pace", active.race_pace if active != null else 0, driver.race_pace, active != null),
		_driver_metric("Qualifying", active.qualifying_pace if active != null else 0, driver.qualifying_pace, active != null),
		_driver_metric("Tyre management", active.tyre_management if active != null else 0, driver.tyre_management, active != null),
		_driver_metric("Consistency", active.consistency if active != null else 0, driver.consistency, active != null),
		DecisionComparisonModel.metric(
			"Potential",
			str(active.get_potential_overall()) if active != null else "--",
			str(driver.get_potential_overall()) if potential_known else "Unknown",
			"Scouting required" if not potential_known else "",
			DecisionComparisonModel.NEUTRAL,
			"Potential remains hidden until scouting reveals it."
		),
	]
	var recommendation := "This candidate fills the required seat and gives the team a baseline for the season."
	if active != null:
		var overall_delta := driver.get_overall_rating() - active.get_overall_rating()
		recommendation = (
			"A clear performance upgrade over %s, with the contract cost shown below." % active.driver_name
			if overall_delta >= 5 else
			"A lateral roster option; use specialty strengths and contract cost as the deciding factors."
			if overall_delta >= -3 else
			"A development or depth signing rather than an immediate performance upgrade."
		)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "DRIVER DECISION",
		"title": driver.driver_name,
		"subtitle": "Compared with %s. Hiring adds a roster member; it does not automatically replace the active assignment." % current_name,
		"current_title": current_name.to_upper(),
		"candidate_title": "CANDIDATE",
		"metrics": metrics,
		"upfront_cost": signing_cost - commercial_signing,
		"recurring_per_race": salary - commercial_income,
		"action_enabled": eligible and (not accepted or team.money >= signing_cost),
		"disabled_reason": disabled_reason,
		"action_label": "Sign contract" if accepted else "Open negotiation",
		"recommendation": recommendation,
		"risk": "Commercial backing offsets part of this contract, but the full signing fee is still required at signing." if driver.is_pay_driver else "",
		"context": {"kind": "driver", "candidate": driver},
	})
	comparison_drawer.display(model)


func _driver_metric(label_text: String, current_value: int, candidate_value: int, has_current: bool) -> Dictionary:
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(
		label_text,
		str(current_value) if has_current else "--",
		str(candidate_value),
		"%+d" % delta if has_current else "New",
		_comparison_impact(delta) if has_current else DecisionComparisonModel.IMPROVES
	)


func _comparison_impact(delta: int) -> int:
	if delta > 0:
		return DecisionComparisonModel.IMPROVES
	if delta < 0:
		return DecisionComparisonModel.WORSENS
	return DecisionComparisonModel.NEUTRAL


func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) == "driver":
		_on_hire_pressed(context.get("candidate") as Driver)


func _on_hire_pressed(driver: Driver) -> void:
	pending_driver = driver
	var accepted := bool((GameManager.team.contract_offers.get(driver.driver_id, {}) as Dictionary).get("accepted", false))
	if not accepted:
		var existing_offer := GameManager.team.contract_offers.get(driver.driver_id, {}) as Dictionary
		var salary_offer := int(existing_offer.get("counter_salary", driver.salary))
		var signing_offer := int(existing_offer.get("counter_signing_fee", driver.signing_fee))
		var response := GameManager.team.negotiate_driver_contract(driver, salary_offer, signing_offer, driver.contract_length)
		GameManager.save_game()
		confirmation_dialog.title = "Contract negotiation"
		confirmation_dialog.dialog_text = "%s\n\nProposed: $%s/race, $%s signing bonus, %d races." % [response.reason, format_number(GameManager.team.get_effective_salary(salary_offer)), format_number(GameManager.team.get_discounted_cost(signing_offer)), driver.contract_length]
		confirmation_dialog.get_ok_button().text = "Continue"
		confirmation_dialog.popup_centered()
		return
	confirmation_dialog.title = "Confirm driver contract"
	confirmation_dialog.dialog_text = (
		"Do you want to sign %s to your multi-team roster?\n\nSigning fee: $%s (charged now)\nSalary: $%s after every race%s"
		% [
			driver.driver_name,
			format_number(GameManager.team.get_discounted_cost(driver.signing_fee)),
			format_number(GameManager.team.get_effective_salary(driver.salary)),
			"\nCommercial backing: +$%s per entered race and +$%s on signing" % [format_number(GameManager.team.get_effective_sponsor_value(driver.sponsorship_contribution_per_race)), format_number(GameManager.team.get_effective_sponsor_value(driver.sponsorship_signing_bonus))] if driver.is_pay_driver else ""
		]
	)
	confirmation_dialog.get_ok_button().text = "Confirm Hire"
	confirmation_dialog.popup_centered()


func _on_hire_confirmed() -> void:
	if pending_driver == null:
		return

	if GameManager.team.hire_driver(pending_driver):
		PersonalityCatalog.reaction(pending_driver, "signed", {"season":GameManager.team.current_season_year, "event":"initial_signing", "team":GameManager.team.team_name})
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
