extends Control

@onready var team_name_label: Label = %team_name_label
@onready var next_race_label: Label = %next_race_label
@onready var standings_label: Label = %standings_label
@onready var money_label: Label = %money_label
@onready var cars_owned_label: Label = %cars_owned_label
@onready var garage_value_label: Label = %garage_value_label
@onready var reputation_label: Label = %reputation_label
@onready var reputation_hint: Label = %reputation_hint
@onready var sponsor_label: Label = %sponsor_label
@onready var readiness_container: VBoxContainer = %readiness_container
@onready var readiness_summary_label: Label = %readiness_summary_label
@onready var advance_race_button: Button = %advance_race_button
@onready var week_status_label: Label = %week_status_label
@onready var advance_preview: ConfirmationDialog = %advance_preview
@onready var first_hour_guide: PanelContainer = %FirstHourGuide
@onready var first_hour_progress_label: Label = %first_hour_progress_label
@onready var first_hour_title_label: Label = %first_hour_title_label
@onready var first_hour_body_label: Label = %first_hour_body_label
@onready var affordability_label: Label = %affordability_label
@onready var performance_gain_label: Label = %performance_gain_label
@onready var risk_label: Label = %risk_label
@onready var board_expectation_label: Label = %board_expectation_label

const READINESS_ROW_SCENE: PackedScene = preload("res://ui/components/readiness_row.tscn")


func _ready() -> void:
	if GameManager.team == null:
		push_error(
			"Dashboard cannot display because "
			+ "GameManager.team is null."
		)
		return

	if not GameManager.team.changed.is_connected(
		_on_team_changed
	):
		GameManager.team.changed.connect(
			_on_team_changed
		)
	advance_preview.confirmed.connect(_confirm_date_advance)
	advance_preview.custom_action.connect(_on_advance_preview_action)
	advance_preview.add_button("View Calendar", false, "calendar")
	advance_preview.add_button("Review Decisions", false, "decisions")

	update_dashboard()


func _exit_tree() -> void:
	if GameManager.team == null:
		return

	if GameManager.team.changed.is_connected(
		_on_team_changed
	):
		GameManager.team.changed.disconnect(
			_on_team_changed
		)


func _on_team_changed() -> void:
	update_dashboard()


func update_dashboard() -> void:
	var team: Team = GameManager.team

	if team == null:
		return

	team_name_label.text = "%s • Season %d race operations" % [team.team_name, team.season_number]

	money_label.text = (
		"$%s"
		% String.num_int64(team.money)
	)

	var standing := ReputationManager.ensure_state(team)
	reputation_label.text = "%s  •  LEVEL %d\n%d / %d XP" % [
		team.get_reputation_tier().to_upper(),
		team.get_reputation_level(),
		team.get_current_level_xp(),
		team.get_level_xp_span()
	]
	reputation_hint.text = "MOMENTUM %+d  •  SPORT %d  •  PRO %d  •  COMM %d" % [
		int(standing.momentum),
		int(standing.sporting_credibility),
		int(standing.professionalism),
		int(standing.commercial_appeal)
	]

	update_sponsor_summary(team)

	cars_owned_label.text = (
		"%d of %d bays occupied"
		% [
			get_cars_owned(team),
			team.cars.size()
		]
	)

	garage_value_label.text = (
		"$%s total value"
		% String.num_int64(
			get_garage_value(team)
		)
	)

	update_next_race()
	update_championship_summary()
	update_readiness(team)
	update_week_action(team)
	update_first_hour_guide(team)
	update_decision_brief(team)


func update_week_action(team: Team) -> void:
	if team.is_series_season_complete():
		advance_race_button.text = "VIEW FINAL STANDINGS  →"
		week_status_label.text = "Season complete"
	elif team.week_advance_required:
		advance_race_button.text = "ADVANCE TO NEXT RACE  →"
		week_status_label.text = "%s • Advance the calendar when your team is ready" % CalendarCatalog.format_day(team.current_season_day)
	else:
		advance_race_button.text = "CONTINUE RACE WEEKEND  →"
		week_status_label.text = "%s • Development uses calendar-day deadlines" % CalendarCatalog.format_day(team.current_season_day)


func update_first_hour_guide(team: Team) -> void:
	var step := FirstHourExperience.current_step(team, GameManager.active_race_weekend)
	first_hour_guide.visible = not FirstHourExperience.is_complete(team)
	if not first_hour_guide.visible:
		return
	first_hour_progress_label.text = "GUIDED OPENING  //  %s" % FirstHourExperience.progress_text(team, GameManager.active_race_weekend)
	first_hour_title_label.text = str(step.get("title", "Continue the guided opening"))
	first_hour_body_label.text = str(step.get("body", "Complete the next opening goal."))


func update_decision_brief(team: Team) -> void:
	var forecast := FinanceManager.build_forecast(team)
	if forecast.is_empty():
		affordability_label.text = "WHAT CAN I AFFORD?\nNo forecast is available yet."
	else:
		var reserve_gap := team.money - int(forecast.get("minimum_reserve", 0))
		affordability_label.text = "WHAT CAN I AFFORD?\n%s$%s beyond the recommended reserve; expected race net %s$%s." % [
			"+" if reserve_gap >= 0 else "-",
			String.num_int64(absi(reserve_gap)),
			"+" if int(forecast.get("race_net", 0)) >= 0 else "-",
			String.num_int64(absi(int(forecast.get("race_net", 0)))),
		]
	var car := RaceReadiness.get_recommended_car(team, team.current_series_id)
	if car == null:
		performance_gain_label.text = "WHERE CAN I GAIN PERFORMANCE?\nBuy an eligible car to establish a baseline."
	elif car.condition < 85:
		performance_gain_label.text = "WHERE CAN I GAIN PERFORMANCE?\nRepair %s first: condition is only %d%%." % [car.name, car.condition]
	else:
		var weakest := "Engine"
		var weakest_points := 999
		for part_type in CarPart.PART_TYPES:
			var part := car.get_part(part_type)
			var points := part.base_performance_points if part != null else 0
			if points < weakest_points:
				weakest = part_type
				weakest_points = points
		performance_gain_label.text = "WHERE CAN I GAIN PERFORMANCE?\nThe %s package is the weakest area at %d base PP." % [weakest.to_lower(), weakest_points]
	var risk_message := "Balanced strategy preserves flexibility."
	if car != null and car.condition < 70:
		risk_message = "Avoid aggressive running until the car is repaired."
	elif not forecast.is_empty() and int(forecast.get("season_end_cash", team.money)) < 0:
		risk_message = "Protect cash: use conservative strategy and delay upgrades."
	elif car != null and car.condition >= 90 and int(forecast.get("upgrade_budget", 0)) > 5000:
		risk_message = "The car and reserve can support a measured aggressive attempt."
	risk_label.text = "WHAT RISK SHOULD I TAKE?\n%s" % risk_message
	var expectation := "Finish races and preserve a $10,000 season-end reserve."
	var board := team.career_state.get("board", {}) as Dictionary
	for value in board.get("targets", []):
		var target := value as Dictionary
		if str(target.get("status", "Active")) == "Active":
			expectation = str(target.get("label", expectation))
			break
	board_expectation_label.text = "WHAT DOES THE BOARD EXPECT?\n%s" % expectation


func update_sponsor_summary(team: Team) -> void:
	SponsorManager.ensure_state(team)
	var contracts := team.get_active_sponsor_contracts()
	var race_team := team.get_active_race_team()
	if contracts.is_empty():
		sponsor_label.text = "%s • No active partners" % (race_team.team_name if race_team != null else "Race Team")
		return

	var contract := contracts[0]
	sponsor_label.text = (
		"%s • %d partner%s\n$%s per race • Lead objective %d/%d%s • %d races left"
		% [
			race_team.team_name if race_team != null else "Race Team",
			contracts.size(),
			"s" if contracts.size() != 1 else "",
			String.num_int64(race_team.get_sponsor_income_per_race() if race_team != null else 0),
			int(contract.objective_progress),
			int(contract.objective_target),
			" complete" if bool(contract.objective_completed) else "",
			int(contract.races_remaining)
		]
	)


func update_next_race() -> void:
	if GameManager.team.is_series_season_complete():
		next_race_label.text = (
			"Season %d Complete — Start a new season from Standings"
			% GameManager.team.season_number
		)
		return

	if GameManager.team.get_unlocked_races().is_empty():
		next_race_label.text = (
			"Next Race: Season Complete"
		)
		return

	var race := RaceManager.get_next_race(GameManager.team)
	if race == null:
		next_race_label.text = "Next Race: No event available"
		return
	next_race_label.text = "Next Race: %s • %s" % [race.race_name, race.race_date]


func update_championship_summary() -> void:
	var standings: Array[Dictionary] = (
		GameManager.team
		.get_sorted_championship_standings()
	)

	if standings.is_empty():
		standings_label.text = (
			"Championship: No races completed"
		)
		return

	var leader: Dictionary = standings[0]

	var player_position: int = 0
	var player_points: int = 0

	for index in range(standings.size()):
		var entry: Dictionary = standings[index]

		if bool(entry.get("is_player", false)):
			player_position = index + 1
			player_points = int(
				entry.get("points", 0)
			)
			break

	var leader_points: int = int(
		leader.get("points", 0)
	)

	var leader_name: String = str(
		leader.get("name", "Unknown Team")
	)

	var gap: int = (
		leader_points
		- player_points
	)

	if player_position <= 0:
		standings_label.text = (
			"Championship: Team not found"
		)
		return

	if player_position == 1:
		standings_label.text = (
			"Championship: 1st of %d"
			+ "  |  %d pts"
			+ "  |  Championship Leader"
		) % [
			standings.size(),
			player_points
		]
		return

	standings_label.text = (
		"Championship: %s of %d"
		+ "  |  %d pts"
		+ "  |  Leader: %s"
		+ "  |  Gap: %d pts"
	) % [
		get_ordinal(player_position),
		standings.size(),
		player_points,
		leader_name,
		gap
	]


func get_cars_owned(team: Team) -> int:
	var total := 0

	for car in team.cars:
		if car != null:
			total += 1

	return total


func get_garage_value(team: Team) -> int:
	var total := 0

	for car in team.cars:
		if car != null:
			total += car.value

	return total


func update_readiness(team: Team) -> void:
	for child in readiness_container.get_children():
		child.queue_free()
	var race := RaceManager.get_next_race(team)
	if team.week_advance_required:
		readiness_summary_label.text = "WEEK COMPLETE • ADVANCE TO CONTINUE"
		return
	if race == null:
		readiness_summary_label.text = "No active event"
		return
	var checks := RaceReadiness.evaluate(team, race)
	var overall := RaceReadiness.get_overall_status(checks)
	readiness_summary_label.text = {
		RaceReadiness.READY: "ALL SYSTEMS READY",
		RaceReadiness.SUBOPTIMAL: "ENTRY POSSIBLE • REVIEW WARNINGS",
		RaceReadiness.BLOCKED: "ACTION REQUIRED BEFORE ENTRY"
	}.get(overall, "REVIEW REQUIRED")
	readiness_summary_label.modulate = {
		RaceReadiness.READY: Color("43d68a"),
		RaceReadiness.SUBOPTIMAL: Color("ffb547"),
		RaceReadiness.BLOCKED: Color("ff667a")
	}.get(overall, Color.WHITE)
	for check in checks:
		var row := READINESS_ROW_SCENE.instantiate() as ReadinessRow
		readiness_container.add_child(row)
		row.setup(check)
		row.action_requested.connect(_on_readiness_action_requested)


func _on_prepare_race_pressed() -> void:
	if not FirstHourExperience.is_complete(GameManager.team):
		var action := str(FirstHourExperience.current_step(GameManager.team, GameManager.active_race_weekend).get("action", "dashboard"))
		if action == "driver_market":
			GameManager.load_page("res://scenes/pages/driver_market/driver_market.tscn")
			return
		if action == "dealership":
			GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")
			return
		if action == "sponsors":
			GameManager.load_page("res://scenes/pages/sponsors/sponsors.tscn")
			return
		if action == "garage":
			GameManager.load_page("res://scenes/pages/garage/garage.tscn")
			return
	if GameManager.team.is_series_season_complete():
		GameManager.load_page("res://scenes/pages/championship/championship.tscn")
		return
	if GameManager.team.week_advance_required:
		var next_race := RaceManager.get_next_race(GameManager.team)
		var next_day := next_race.schedule_day if next_race != null else CalendarCatalog.SEASON_END_DAY
		_show_advance_preview(next_day)
		return
	GameManager.selected_race = RaceManager.get_next_race(GameManager.team)
	GameManager.selected_car = null
	if GameManager.selected_race == null:
		GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")
		return
	GameManager.load_page("res://scenes/pages/race_entry/race_entry.tscn")


func _show_advance_preview(target_day: int) -> void:
	var preview := RaceManager.get_advance_preview(target_day)
	var impacts := CareerExpansionManager.get_time_advance_impacts(GameManager.team, target_day)
	var lines: Array[String] = ["Advance from %s to %s?" % [CalendarCatalog.format_day(int(preview.from_day)), CalendarCatalog.format_day(target_day)], "", "During these %d days:" % int(preview.days)]
	if int(preview.other_races) > 0:
		lines.append("• %d races will run across %d other series" % [preview.other_races, preview.other_series])
	var grouped := preview.events_by_date as Dictionary
	var days := grouped.keys()
	days.sort()
	for day in days:
		var noteworthy: Array[String] = []
		for event in grouped[day]:
			if event.type != "other_race":
				noteworthy.append(str(event.title))
		if not noteworthy.is_empty():
			lines.append("• %s — %s" % [CalendarCatalog.format_day(int(day)), ", ".join(noteworthy)])
	if preview.events.is_empty():
		lines.append("• No scheduled events")
	var expiring_decisions := impacts.get("expiring_decisions", []) as Array
	var expiring_activations := impacts.get("expiring_activations", []) as Array
	var completions := impacts.get("completions", []) as Array
	var entry_readiness := impacts.get("entry_readiness", []) as Array
	if not completions.is_empty():
		lines.append("")
		lines.append("Projects completing:")
		for completion in completions:
			lines.append("- %s" % str(completion))
	if not expiring_decisions.is_empty() or not expiring_activations.is_empty():
		lines.append("")
		lines.append("Action required before advancing:")
		for item in expiring_decisions:
			lines.append("- Decision: %s" % str((item as Dictionary).get("subject", "Untitled decision")))
		for activation in expiring_activations:
			lines.append("- Sponsor: %s" % str((activation as Dictionary).get("event", "Activation opportunity")))
	if not entry_readiness.is_empty():
		lines.append("")
		lines.append("Race-team readiness:")
		for readiness in entry_readiness:
			var entry := readiness as Dictionary
			var status := "Ready" if bool(entry.get("race_ready", false)) else "Needs %s" % ", ".join(entry.get("gaps", []) as Array)
			lines.append("- %s - %s" % [str(entry.get("team_name", "Race team")), status])
	advance_preview.dialog_text = "\n".join(lines)
	advance_preview.set_meta("target_day", target_day)
	advance_preview.set_meta("blocked", bool(impacts.get("blocked", false)))
	advance_preview.get_ok_button().disabled = bool(impacts.get("blocked", false))
	advance_preview.get_ok_button().tooltip_text = "Review expiring decisions and sponsor actions first." if bool(impacts.get("blocked", false)) else "Advance the organization calendar."
	advance_preview.popup_centered(Vector2i(620, 430))


func _confirm_date_advance() -> void:
	var target_day := int(advance_preview.get_meta("target_day", GameManager.team.current_season_day))
	var impacts := CareerExpansionManager.get_time_advance_impacts(GameManager.team, target_day)
	if bool(impacts.get("blocked", false)):
		advance_preview.hide()
		GameManager.report_decision_outcome({
			"status": "warning",
			"title": "Calendar advance paused",
			"message": "Resolve expiring decisions and sponsor activations before moving forward.",
			"action_label": "Review decisions",
			"action_path": "res://scenes/pages/career_hub/career_hub.tscn",
		})
		return
	var result := RaceManager.advance_to_date(target_day)
	var days := int(result.days_advanced) if result.has("days_advanced") else 0
	advance_preview.hide()
	week_status_label.text = "%s • %d days advanced" % [CalendarCatalog.format_day(GameManager.team.current_season_day), days]
	GameManager.save_game()
	update_dashboard()


func _on_advance_preview_action(action: StringName) -> void:
	if action == &"calendar":
		advance_preview.hide()
		GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")
	elif action == &"decisions":
		advance_preview.hide()
		GameManager.load_page("res://scenes/pages/career_hub/career_hub.tscn")


func _on_readiness_action_requested(action: String) -> void:
	var pages := {
		"drivers": "res://scenes/pages/driver_market/driver_market.tscn",
		"garage": "res://scenes/pages/garage/garage.tscn",
		"staff": "res://scenes/pages/staff/staff.tscn",
		"finances": "res://scenes/pages/finances/finances.tscn",
		"sponsors": "res://scenes/pages/sponsors/sponsors.tscn"
	}
	var path := str(pages.get(action, ""))
	if not path.is_empty():
		GameManager.load_page(path)

func get_ordinal(number: int) -> String:
	var final_two_digits: int = number % 100

	if (
		final_two_digits >= 11
		and final_two_digits <= 13
	):
		return "%dth" % number

	match number % 10:
		1:
			return "%dst" % number
		2:
			return "%dnd" % number
		3:
			return "%drd" % number
		_:
			return "%dth" % number
