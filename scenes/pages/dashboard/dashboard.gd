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


func update_week_action(team: Team) -> void:
	if team.is_series_season_complete():
		advance_race_button.text = "VIEW FINAL STANDINGS  →"
		week_status_label.text = "Season complete"
	elif team.week_advance_required:
		advance_race_button.text = "ADVANCE TO NEXT RACE  →"
		week_status_label.text = "%s • Advance the calendar when your team is ready" % CalendarCatalog.format_day(team.current_season_day)
	else:
		advance_race_button.text = "PREPARE FOR RACE  →"
		week_status_label.text = "%s • Development uses calendar-day deadlines" % CalendarCatalog.format_day(team.current_season_day)


func update_sponsor_summary(team: Team) -> void:
	SponsorManager.ensure_state(team)
	if team.active_sponsor_contract.is_empty():
		sponsor_label.text = "No active contract • Visit Sponsors to review offers"
		return

	var contract := team.active_sponsor_contract
	sponsor_label.text = (
		"%s\n$%s per race  •  Objective %d/%d%s  •  %d races left"
		% [
			str(contract.sponsor_name),
			String.num_int64(int(contract.payment_per_race)),
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
	advance_preview.dialog_text = "\n".join(lines)
	advance_preview.set_meta("target_day", target_day)
	advance_preview.popup_centered(Vector2i(620, 430))


func _confirm_date_advance() -> void:
	var target_day := int(advance_preview.get_meta("target_day", GameManager.team.current_season_day))
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
