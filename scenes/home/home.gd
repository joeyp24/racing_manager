extends Control

@onready var page_container: Control = %page_container
@onready var home_button: Button = %home_button
@onready var garage_button: Button = %garage_button
@onready var drivers_button: Button = %drivers_button
@onready var engineering_button: Button = %engineering_button
@onready var driver_market_button: Button = %driver_market_button
@onready var race_teams_button: Button = %race_teams_button
@onready var championship_button: Button = %championship_button
@onready var world_series_button: Button = %world_series_button
@onready var staff_button: Button = %staff_button
@onready var finances_button: Button = %finances_button
@onready var race_calendar_button: Button = %race_calendar_button
@onready var shop_button: Button = %shop_button
@onready var dealership_button: Button = %dealership_button
@onready var sponsors_button: Button = %sponsors_button
@onready var reputation_button: Button = %reputation_button
@onready var hq_button: Button = %hq_button
@onready var scouting_button: Button = %scouting_button
@onready var career_hub_button: Button = %career_hub_button
@onready var identity_button: Button = %identity_button
@onready var glossary_button: Button = %glossary_button
@onready var schedule_metric: StatusMetric = %ScheduleMetric
@onready var finance_metric: StatusMetric = %FinanceMetric
@onready var championship_metric: StatusMetric = %ChampionshipMetric
@onready var reputation_metric: StatusMetric = %ReputationMetric
@onready var board_metric: StatusMetric = %BoardMetric
@onready var attention_metric: StatusMetric = %AttentionMetric
@onready var reputation_toast: PanelContainer = %ReputationToast
@onready var reputation_toast_title: Label = %reputation_toast_title
@onready var reputation_toast_body: Label = %reputation_toast_body
@onready var reputation_toast_progress: ProgressBar = %reputation_toast_progress
@onready var reputation_toast_timer: Timer = %ReputationToastTimer
@onready var team_name_label: Label = %team_name_label
@onready var season_label: Label = %season_label
@onready var fullscreen_button: Button = %fullscreen_button
@onready var settings_dialog: ConfirmationDialog = %settings_dialog
@onready var reset_confirmation: ConfirmationDialog = %reset_confirmation
@onready var command_bar: CommandBar = %CommandBar
@onready var decision_outcome_receipt: DecisionOutcomeReceipt = %DecisionOutcomeReceipt

var navigation_buttons: Array[Button] = []
var last_reputation_xp: int = -1
var last_reputation_level: int = -1


func _ready() -> void:
	GameManager.page_container = page_container
	navigation_buttons = [home_button, race_calendar_button, championship_button, world_series_button,
		garage_button, race_teams_button, drivers_button, engineering_button, staff_button, driver_market_button, shop_button,
		dealership_button, sponsors_button, reputation_button, finances_button, hq_button, identity_button,
		scouting_button, career_hub_button]

	home_button.pressed.connect(
		_on_home_button_pressed
	)

	garage_button.pressed.connect(
		_on_garage_button_pressed
	)

	drivers_button.pressed.connect(
		_on_drivers_button_pressed
	)
	engineering_button.pressed.connect(_on_engineering_button_pressed)
	driver_market_button.pressed.connect(_on_driver_market_button_pressed)
	race_teams_button.pressed.connect(_on_race_teams_button_pressed)

	championship_button.pressed.connect(
		_on_championship_button_pressed
	)
	world_series_button.pressed.connect(_on_world_series_button_pressed)
	staff_button.pressed.connect(_on_staff_button_pressed)
	finances_button.pressed.connect(_on_finances_button_pressed)

	race_calendar_button.pressed.connect(
		_on_race_calendar_button_pressed
	)

	shop_button.pressed.connect(_on_shop_button_pressed)
	dealership_button.pressed.connect(_on_dealership_button_pressed)
	sponsors_button.pressed.connect(_on_sponsors_button_pressed)
	reputation_button.pressed.connect(_on_reputation_button_pressed)
	hq_button.pressed.connect(_on_hq_button_pressed)
	identity_button.pressed.connect(_on_identity_button_pressed)
	glossary_button.pressed.connect(_on_glossary_button_pressed)
	scouting_button.pressed.connect(_on_scouting_button_pressed)
	career_hub_button.pressed.connect(_on_career_hub_button_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	schedule_metric.activated.connect(_on_race_calendar_button_pressed)
	finance_metric.activated.connect(_on_finances_button_pressed)
	championship_metric.activated.connect(_on_championship_button_pressed)
	reputation_metric.activated.connect(_on_reputation_button_pressed)
	board_metric.activated.connect(_on_career_hub_button_pressed)
	attention_metric.activated.connect(_on_career_hub_button_pressed)
	command_bar.action_requested.connect(_on_command_action_requested)
	decision_outcome_receipt.action_requested.connect(_on_outcome_action_requested)
	GameManager.page_changed.connect(_on_page_changed)
	GameManager.decision_outcome_reported.connect(_on_decision_outcome_reported)
	GameManager.fullscreen_changed.connect(_update_fullscreen_button)
	GameManager.race_weekend_lock_changed.connect(_on_race_weekend_lock_changed)
	reputation_toast_timer.timeout.connect(_hide_reputation_toast)
	_update_fullscreen_button(GameManager.is_fullscreen())

	if not GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.connect(
			_on_team_money_changed
		)
	if GameManager.team != null and not GameManager.team.changed.is_connected(update_team_display):
		GameManager.team.changed.connect(update_team_display)
	if GameManager.team != null:
		last_reputation_xp = GameManager.team.reputation
		last_reputation_level = GameManager.team.get_reputation_level()
	var pending_outcome := GameManager.consume_decision_outcome()
	if not pending_outcome.is_empty():
		_display_decision_outcome(pending_outcome)

	update_team_display()
	update_unlocked_navigation()

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)
	set_active_navigation(home_button)

	if (
		GameManager.team != null
		and not GameManager.team.driver_hired_for_season
	):
		GameManager.load_page(
			"res://scenes/pages/driver_market/driver_market.tscn"
		)
		set_active_navigation(driver_market_button)


func _exit_tree() -> void:
	if GameManager.fullscreen_changed.is_connected(_update_fullscreen_button):
		GameManager.fullscreen_changed.disconnect(_update_fullscreen_button)
	if GameManager.page_changed.is_connected(_on_page_changed):
		GameManager.page_changed.disconnect(_on_page_changed)
	if GameManager.race_weekend_lock_changed.is_connected(_on_race_weekend_lock_changed):
		GameManager.race_weekend_lock_changed.disconnect(_on_race_weekend_lock_changed)
	if GameManager.decision_outcome_reported.is_connected(_on_decision_outcome_reported):
		GameManager.decision_outcome_reported.disconnect(_on_decision_outcome_reported)
	if GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.disconnect(
			_on_team_money_changed
		)
	if GameManager.team != null and GameManager.team.changed.is_connected(update_team_display):
		GameManager.team.changed.disconnect(update_team_display)


func _on_fullscreen_button_pressed() -> void:
	GameManager.toggle_fullscreen()


func _on_settings_pressed() -> void:
	settings_dialog.popup_centered(Vector2i(420, 250))


func _on_reset_requested() -> void:
	settings_dialog.hide()
	reset_confirmation.popup_centered(Vector2i(460, 190))


func _update_fullscreen_button(is_now_fullscreen: bool) -> void:
	if is_now_fullscreen:
		fullscreen_button.text = "  ⛶  Exit Full Screen (F11)"
	else:
		fullscreen_button.text = "  ⛶  Full Screen (F11)"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.save_game()
		get_tree().quit()


func _on_home_button_pressed() -> void:
	set_active_navigation(home_button)
	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)


func _on_garage_button_pressed() -> void:
	set_active_navigation(garage_button)
	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)


func _on_drivers_button_pressed() -> void:
	set_active_navigation(drivers_button)
	GameManager.load_page(
		"res://scenes/pages/drivers/drivers.tscn"
	)


func _on_engineering_button_pressed() -> void:
	set_active_navigation(engineering_button)
	GameManager.load_page("res://scenes/pages/engineering/engineering.tscn")


func _on_driver_market_button_pressed() -> void:
	set_active_navigation(driver_market_button)
	GameManager.load_page("res://scenes/pages/driver_market/driver_market.tscn")


func _on_race_teams_button_pressed() -> void:
	set_active_navigation(race_teams_button)
	GameManager.load_page("res://scenes/pages/race_teams/race_teams.tscn")


func _on_championship_button_pressed() -> void:
	set_active_navigation(championship_button)
	GameManager.load_page(
		"res://scenes/pages/championship/championship.tscn"
	)


func _on_world_series_button_pressed() -> void:
	set_active_navigation(world_series_button)
	GameManager.load_page("res://scenes/pages/world_series/world_series.tscn")


func _on_staff_button_pressed() -> void:
	set_active_navigation(staff_button)
	GameManager.load_page("res://scenes/pages/staff/staff.tscn")


func _on_finances_button_pressed() -> void:
	set_active_navigation(finances_button)
	GameManager.load_page("res://scenes/pages/finances/finances.tscn")


func _on_race_calendar_button_pressed() -> void:
	set_active_navigation(race_calendar_button)
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_calendar/race_calendar.tscn"
	)


func _on_shop_button_pressed() -> void:
	set_active_navigation(shop_button)
	GameManager.load_page("res://scenes/pages/shop/shop.tscn")


func _on_dealership_button_pressed() -> void:
	set_active_navigation(dealership_button)
	GameManager.selected_car = null
	GameManager.selected_bay = -1
	GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")


func _on_sponsors_button_pressed() -> void:
	set_active_navigation(sponsors_button)
	GameManager.load_page("res://scenes/pages/sponsors/sponsors.tscn")


func _on_reputation_button_pressed() -> void:
	set_active_navigation(reputation_button)
	GameManager.load_page("res://scenes/pages/reputation/reputation.tscn")


func _on_hq_button_pressed() -> void:
	set_active_navigation(hq_button)
	GameManager.load_page("res://scenes/pages/departments/departments.tscn")


func _on_identity_button_pressed() -> void:
	set_active_navigation(identity_button)
	GameManager.load_page("res://scenes/pages/team_identity/team_identity.tscn")


func _on_glossary_button_pressed() -> void:
	set_active_navigation(null)
	GameManager.load_page("res://scenes/pages/glossary/glossary.tscn")


func _on_scouting_button_pressed() -> void:
	if scouting_button.disabled:
		return
	set_active_navigation(scouting_button)
	GameManager.load_page("res://scenes/pages/scouting/scouting.tscn")


func _on_career_hub_button_pressed() -> void:
	set_active_navigation(career_hub_button)
	GameManager.load_page("res://scenes/pages/career_hub/career_hub.tscn")


func update_unlocked_navigation() -> void:
	var team := GameManager.team
	var weekend_locked := GameManager.is_race_weekend_locked()
	var opening_locked := team != null and not FirstHourExperience.is_complete(team)
	var allowed: Array[Button] = [home_button]
	if team != null:
		var step_id := str(FirstHourExperience.current_step(team, GameManager.active_race_weekend).get("id", ""))
		allowed.append(driver_market_button)
		if step_id != "driver":
			allowed.append(dealership_button)
			allowed.append(shop_button)
			allowed.append(garage_button)
		if step_id in ["sponsor", "practice", "strategy", "race", "service", "complete"]:
			allowed.append(sponsors_button)
		if step_id in ["practice", "strategy", "race", "service", "complete"]:
			allowed.append(race_calendar_button)
	for button in navigation_buttons:
		button.disabled = weekend_locked or (opening_locked and not allowed.has(button))
		if weekend_locked:
			button.tooltip_text = "Finish the committed race weekend before returning to team management."
		elif opening_locked and not allowed.has(button):
			button.tooltip_text = "Unlocked after the guided opening and first post-race service."
	var scouting_unlocked := team != null and team.get_department_level("scouting") > 0 and not opening_locked and not weekend_locked
	scouting_button.disabled = not scouting_unlocked
	scouting_button.text = "Scouting" if scouting_unlocked else "Scouting  ·  LOCKED"
	if not opening_locked and not weekend_locked:
		scouting_button.tooltip_text = "Build the Scouting department at HQ to unlock." if not scouting_unlocked else "Find emerging driver talent."
	_update_navigation_badges(team)


func _on_reset_game_button_pressed() -> void:
	GameManager.reset_game()


func _on_team_money_changed(_new_amount: int) -> void:
	update_team_display()


func update_team_display() -> void:
	if GameManager.team == null:
		schedule_metric.display("CALENDAR", "NO CAREER", "Create or load a team")
		finance_metric.display("FINANCE", "$0", "No forecast")
		championship_metric.display("CHAMPIONSHIP", "—", "No standings")
		reputation_metric.display("REPUTATION", "UNRANKED", "0 XP")
		board_metric.display("BOARD", "—", "No review")
		attention_metric.display("DECISIONS", "CLEAR", "No pending items", &"SuccessLabel")
		command_bar.display(NextActionModel.derive(null))
		_update_navigation_badges(null)
		return

	var team: Team = GameManager.team
	var reputation_gain := team.reputation - last_reputation_xp if last_reputation_xp >= 0 else 0
	var previous_level := last_reputation_level
	if reputation_gain > 0:
		_show_reputation_gain(reputation_gain, previous_level, team)
	last_reputation_xp = team.reputation
	last_reputation_level = team.get_reputation_level()
	team_name_label.text = team.team_name.to_upper()
	season_label.text = "SEASON %d • TEAM HQ" % team.season_number
	_update_status_cockpit(team)
	command_bar.display(NextActionModel.derive(team))
	update_unlocked_navigation()


func _update_status_cockpit(team: Team) -> void:
	var next_race := RaceManager.get_next_race(team)
	if next_race == null:
		schedule_metric.display("CALENDAR  ·  %s" % CalendarCatalog.format_day(team.current_season_day), "SEASON COMPLETE" if team.is_series_season_complete() else "NO EVENT", "Open the calendar")
	else:
		var days_until := maxi(0, next_race.schedule_day - team.current_season_day)
		var timing := "TODAY" if days_until == 0 else "IN %d DAYS" % days_until
		schedule_metric.display("CALENDAR  ·  %s" % CalendarCatalog.format_day(team.current_season_day), next_race.race_name.to_upper(), "%s  ·  %s" % [timing, next_race.race_date])

	var forecast := FinanceManager.build_forecast(team)
	var season_end_cash := int(forecast.get("season_end_cash", team.money))
	var finance_variation: StringName = &"SuccessLabel" if season_end_cash >= 0 else &"DangerLabel"
	finance_metric.display("AVAILABLE CASH", _money(team.money), "SEASON END  %s" % _signed_money(season_end_cash), finance_variation)

	championship_metric.display("CHAMPIONSHIP", get_championship_position(team), "%d OF %d RACES" % [team.get_completed_races().size(), int(SeriesCatalog.get_series(team.current_series_id).get("season_length", 12))])
	reputation_metric.display("REPUTATION", "%s  ·  L%d" % [team.get_reputation_tier().to_upper(), team.get_reputation_level()], "%d XP TO NEXT" % team.get_xp_to_next_level())
	reputation_metric.set_progress(team.get_current_level_xp(), team.get_level_xp_span())

	var state := CareerExpansionManager.ensure_state(team)
	var board := state.get("board", {}) as Dictionary
	var confidence := int(board.get("confidence", 0))
	board_metric.display("BOARD CONFIDENCE", "%d%%" % confidence, "JOB SECURITY  %d%%" % int(board.get("job_security", 0)), _score_variation(confidence))

	var decisions := _decision_summary(team, state)
	var open_count := int(decisions.open)
	var due_soon := int(decisions.due_soon)
	var unread := int(decisions.unread)
	var attention_variation: StringName = &"SuccessLabel" if open_count == 0 else (&"DangerLabel" if due_soon > 0 else &"WarningLabel")
	attention_metric.display("DECISIONS", "CLEAR" if open_count == 0 else "%d OPEN" % open_count, "%d DUE SOON  ·  %d UNREAD" % [due_soon, unread], attention_variation)


func _decision_summary(team: Team, state: Dictionary) -> Dictionary:
	var open_count := 0
	var due_soon := 0
	for value in state.get("inbox", []):
		var item := value as Dictionary
		var requires_action := not bool(item.get("resolved", false)) and not (item.get("choices", []) as Array).is_empty()
		if not requires_action:
			continue
		open_count += 1
		if int(item.get("deadline", CalendarCatalog.SEASON_END_DAY)) <= team.current_season_day + 7:
			due_soon += 1
	return {"open": open_count, "due_soon": due_soon, "unread": CareerExpansionManager.get_unread_count(team)}


func _score_variation(score: int) -> StringName:
	if score < 40:
		return &"DangerLabel"
	if score < 65:
		return &"WarningLabel"
	return &"SuccessLabel"


func _update_navigation_badges(team: Team) -> void:
	if team == null:
		career_hub_button.text = "Career HQ"
		driver_market_button.text = "Driver Market"
		sponsors_button.text = "Sponsors"
		return
	var unread := CareerExpansionManager.get_unread_count(team)
	career_hub_button.text = "Career HQ" if unread == 0 else "Career HQ  ·  %d" % unread
	driver_market_button.text = "Driver Market" if team.driver_hired_for_season else "Driver Market  ·  REQUIRED"
	sponsors_button.text = "Sponsors" if not team.active_sponsor_contract.is_empty() else "Sponsors  ·  REQUIRED"


func _show_reputation_gain(amount: int, previous_level: int, team: Team) -> void:
	var level_up := previous_level > 0 and team.get_reputation_level() > previous_level
	reputation_toast_title.text = "LEVEL UP · REPUTATION +%d" % amount if level_up else "REPUTATION +%d" % amount
	reputation_toast_body.text = "%s · Level %d\n%d XP to the next level" % [team.get_reputation_tier(), team.get_reputation_level(), team.get_xp_to_next_level()]
	reputation_toast_progress.max_value = team.get_level_xp_span()
	reputation_toast_progress.value = team.get_current_level_xp()
	reputation_toast.visible = true
	reputation_toast_timer.start()


func _hide_reputation_toast() -> void:
	reputation_toast.visible = false


func _on_decision_outcome_reported(outcome: Dictionary) -> void:
	GameManager.consume_decision_outcome()
	_display_decision_outcome(outcome)


func _display_decision_outcome(outcome: Dictionary) -> void:
	update_team_display()
	var accessibility := GameManager.team.career_state.get("accessibility", {}) as Dictionary if GameManager.team != null else {}
	decision_outcome_receipt.display(outcome, bool(accessibility.get("reduced_motion", false)))


func _on_outcome_action_requested(scene_path: String) -> void:
	GameManager.load_page(scene_path)


func _on_command_action_requested(action: String) -> void:
	var paths := {
		"dashboard": "res://scenes/pages/dashboard/dashboard.tscn",
		"calendar": "res://scenes/pages/race_calendar/race_calendar.tscn",
		"championship": "res://scenes/pages/championship/championship.tscn",
		"offseason": "res://scenes/pages/offseason/offseason.tscn",
		"drivers": "res://scenes/pages/drivers/drivers.tscn",
		"driver_market": "res://scenes/pages/driver_market/driver_market.tscn",
		"engineering": "res://scenes/pages/engineering/engineering.tscn",
		"garage": "res://scenes/pages/garage/garage.tscn",
		"dealership": "res://scenes/pages/dealership/dealership.tscn",
		"staff": "res://scenes/pages/staff/staff.tscn",
		"finances": "res://scenes/pages/finances/finances.tscn",
		"sponsors": "res://scenes/pages/sponsors/sponsors.tscn",
		"reputation": "res://scenes/pages/reputation/reputation.tscn",
		"race_entry": "res://scenes/pages/race_entry/race_entry.tscn",
		"race_results": "res://scenes/pages/race_results/race_results.tscn",
	}
	if action == "continue_weekend":
		GameManager.load_page(GameManager.get_active_race_weekend_path())
		return
	if not paths.has(action):
		return
	if action == "race_entry":
		GameManager.selected_race = RaceManager.get_next_race(GameManager.team)
	GameManager.load_page(str(paths[action]))


func _on_page_changed(scene_path: String) -> void:
	var destinations := {
		"dashboard": home_button, "race_calendar": race_calendar_button,
		"race_entry": race_calendar_button, "race_weekend": race_calendar_button,
		"live_race": race_calendar_button, "race_results": race_calendar_button,
		"championship": championship_button, "offseason": championship_button, "garage": garage_button,
		"drivers": drivers_button, "driver_market": driver_market_button,
		"engineering": engineering_button, "race_teams": race_teams_button,
		"staff": staff_button, "finances": finances_button, "shop": shop_button,
		"dealership": shop_button, "sponsors": sponsors_button, "reputation": reputation_button,
		"departments": hq_button, "team_identity": identity_button,
		"scouting": scouting_button,
		"career_hub": career_hub_button,
		"world_series": world_series_button,
	}
	var page_id := scene_path.get_file().get_basename()
	set_active_navigation(destinations.get(page_id, null) as Button)
	command_bar.display(NextActionModel.derive(GameManager.team, scene_path))
	update_unlocked_navigation()


func _on_race_weekend_lock_changed(_locked: bool) -> void:
	update_unlocked_navigation()
	command_bar.display(NextActionModel.derive(GameManager.team))


func set_active_navigation(active_button: Button) -> void:
	for button in navigation_buttons:
		button.set_pressed_no_signal(button == active_button)


func get_championship_position(team: Team) -> String:
	var standings := team.get_sorted_championship_standings()
	for index in range(standings.size()):
		if bool(standings[index].get("is_player", false)):
			return "P%d • %d PTS" % [index + 1, int(standings[index].get("points", 0))]
	return "NOT RANKED"


func _money(amount: int) -> String:
	return "%s$%s" % ["-" if amount < 0 else "", format_number(absi(amount))]


func _signed_money(amount: int) -> String:
	return "%s$%s" % ["+" if amount >= 0 else "-", format_number(absi(amount))]


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
