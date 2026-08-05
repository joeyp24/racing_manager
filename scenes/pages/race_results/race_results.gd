extends Control

@onready var race_name_label: Label = %race_name_label
@onready var finishing_position_label: Label = %finishing_position_label
@onready var standings_label: Label = %standings_label
@onready var summary_label: Label = %summary_label
@onready var car_effects_label: Label = %car_effects_label
@onready var decisive_factors_label: Label = %decisive_factors_label
@onready var replay_label: Label = %replay_label
@onready var analysis_label: Label = %analysis_label
@onready var continue_button: Button = %continue_button
@onready var driver_portrait: DriverPortrait = %driver_portrait
@onready var personality_label: Label = %personality_label
@onready var reaction_label: Label = %reaction_label
@onready var incident_story_label: Label = %incident_story_label
@onready var rival_story_label: Label = %rival_story_label
@onready var details_toggle: CheckButton = %details_toggle
@onready var outcome_story_label: Label = %outcome_story_label
@onready var detailed_analysis_button: CheckButton = %detailed_analysis_button


func _ready() -> void:
	continue_button.pressed.connect(
		_on_continue_button_pressed
	)
	details_toggle.toggled.connect(_toggle_details)
	_toggle_details(false)
	detailed_analysis_button.toggled.connect(_on_detailed_analysis_toggled)

	show_race_result()


func show_race_result() -> void:
	var result: RaceResult = RaceManager.last_result

	if result == null:
		show_missing_result()
		return

	if result.race == null:
		show_missing_result()
		return

	race_name_label.text = result.race.race_name

	finishing_position_label.text = (
		"You Finished: %s"
		% format_position(result.finishing_position)
	)
	outcome_story_label.text = create_outcome_story(result)

	standings_label.text = create_standings_text(result)
	summary_label.text = create_financial_summary(result)
	car_effects_label.text = create_car_effects_text(result)
	decisive_factors_label.text = create_decisive_factors_text(result)
	replay_label.text = create_replay_text(result)
	analysis_label.text = create_post_race_analysis_text(result)
	driver_portrait.configure(result.player_driver, GameManager.team.primary_color, GameManager.team.secondary_color)
	personality_label.text = "%s  /  DRIVER REACTION" % result.driver_personality.to_upper()
	reaction_label.text = "“%s”" % result.driver_reaction
	incident_story_label.text = result.authored_incident
	rival_story_label.text = result.rival_summary + ("\n" + result.storyline_summary if not result.storyline_summary.is_empty() else "")


func _toggle_details(visible_now: bool) -> void:
	analysis_label.visible = visible_now
	replay_label.visible = visible_now
	decisive_factors_label.visible = visible_now
	car_effects_label.visible = visible_now
	details_toggle.text = "Hide detailed telemetry and replay" if visible_now else "Show detailed telemetry and replay"
	_on_detailed_analysis_toggled(false)


func create_outcome_story(result: RaceResult) -> String:
	var sentences: Array[String] = ["Finished %s." % format_position(result.finishing_position)]
	if result.positions_gained > 0:
		sentences.append("Gained %d position%s from the starting grid." % [result.positions_gained, "" if result.positions_gained == 1 else "s"])
	elif result.positions_gained < 0:
		sentences.append("Lost %d position%s from the starting grid." % [absi(result.positions_gained), "" if result.positions_gained == -1 else "s"])
	else:
		sentences.append("Finished where the car started.")
	if result.caution_position_gain > 0:
		sentences.append("Caution and pit timing gained %d position%s." % [result.caution_position_gain, "" if result.caution_position_gain == 1 else "s"])
	elif result.pit_stop_factor > 0.5:
		sentences.append("Efficient pit work protected track position.")
	if result.strategy_factor < -0.5:
		sentences.append("The strategy cost late-race pace as tyre and fuel targets tightened.")
	elif result.strategy_factor > 0.5:
		sentences.append("The chosen strategy created a measurable pace advantage.")
	if result.pit_stop_factor < -0.5:
		sentences.append("Slow pit service gave time back to the field.")
	elif result.incident_factor < -0.5:
		sentences.append("An incident was the largest avoidable loss.")
	return " ".join(sentences)


func _on_detailed_analysis_toggled(show_details: bool) -> void:
	analysis_label.visible = show_details
	replay_label.visible = show_details
	detailed_analysis_button.text = "Hide detailed telemetry and race replay" if show_details else "Show detailed telemetry and race replay"


func create_post_race_analysis_text(result: RaceResult) -> String:
	var lines: Array[String] = ["POST-RACE STRATEGY ANALYSIS"]
	var distance_text := "%d scheduled / %d completed laps" % [result.scheduled_laps, result.completed_laps]
	if result.overtime_attempts > 0:
		distance_text += "  |  %d overtime attempt%s" % [result.overtime_attempts, "" if result.overtime_attempts == 1 else "s"]
	lines.append(distance_text)
	lines.append("Track presentation: %s  |  %s" % [str(result.track_presentation.get("banking_summary", result.race.track_type)), str(result.track_presentation.get("camera_style", "Track camera"))])
	lines.append("\nPLANNED VS ACTUAL")
	var strategy_count := 0
	for event_value in result.strategy_timeline:
		var event := event_value as Dictionary
		if str(event.get("type", "")) not in ["plan", "call", "stop", "caution_call"]:
			continue
		lines.append("Lap %d  |  %s  |  %s" % [int(event.get("lap", 0)), str(event.get("title", "Decision")), str(event.get("detail", ""))])
		strategy_count += 1
		if strategy_count >= 8:
			break
	if strategy_count == 0:
		lines.append("No pit calls were recorded.")
	lines.append("\nDECISIVE MOMENTS")
	var moment_count := 0
	for moment_value in result.decisive_moments:
		var moment := moment_value as Dictionary
		if str(moment.get("type", "")) not in ["pass", "damage", "caution", "caution_outcome", "overtime"]:
			continue
		lines.append("Lap %d  |  %s  |  %s" % [int(moment.get("lap", 0)), str(moment.get("title", "Moment")), str(moment.get("detail", ""))])
		moment_count += 1
		if moment_count >= 8:
			break
	if moment_count == 0:
		lines.append("No single pass or caution swing dominated the result.")
	lines.append("\nTIME & POSITION ACCOUNTING")
	lines.append("Traffic loss: %.1fs  |  Caution gain: %+d positions" % [result.traffic_time_lost, result.caution_position_gain])
	lines.append("Engineer calls: %d  |  Model accuracy after review: %d%%" % [result.engineer_call_count, roundi(result.engineer_accuracy * 100.0)])
	lines.append("\nCOMPONENT DEGRADATION")
	for component in Car.DAMAGE_COMPONENTS:
		var data := result.component_degradation.get(component, {}) as Dictionary
		if data.is_empty():
			continue
		var change := float(data.get("change", float(data.get("finish", 100.0)) - float(data.get("start", 100.0))))
		lines.append("%s  %.0f%% -> %.0f%%  (%+.1f)" % [component.capitalize(), float(data.get("start", 100.0)), float(data.get("finish", 100.0)), change])
	lines.append("\nWHAT COULD HAVE CHANGED THE RESULT")
	for counterfactual in result.counterfactuals:
		lines.append("- %s" % counterfactual)
	return "\n".join(lines)


func create_replay_text(result: RaceResult) -> String:
	var lines: Array[String] = [
		"RACE REPLAY & TIMELINE",
		"%s · %s · %s" % [result.qualifying_format, result.weather_summary, result.track_evolution_summary],
		"Team order: %s" % result.team_order_summary
	]
	for snapshot_value in result.replay_timeline:
		var snapshot := snapshot_value as Dictionary
		var player_position := 0
		for position_value in snapshot.get("positions", []):
			var position := position_value as Dictionary
			if str(position.get("driver_id", "")) == result.player_driver.driver_id:
				player_position = int(position.get("position", 0))
		lines.append("Lap %d · %s · %s · grip %d%% · player P%d" % [int(snapshot.get("lap", 0)), snapshot.get("flag", "Green"), snapshot.get("weather", "Dry"), roundi(float(snapshot.get("grip", 1.0)) * 100.0), player_position])
	if result.penalties.is_empty():
		lines.append("Stewarding: No post-race penalties.")
	else:
		for penalty in result.penalties:
			lines.append("Stewarding: %s · %s" % [penalty.get("reason", "Investigation"), penalty.get("penalty", "Penalty")])
	return "\n".join(lines)


func create_decisive_factors_text(result: RaceResult) -> String:
	var factors := [
		["Driver", result.driver_factor, "skill, consistency and aggression versus a 50-rated baseline"],
		["Car", result.car_factor, "effective performance and condition versus a club-racing baseline"],
		["Setup", result.setup_factor, result.practice_focus_name + " practice programme"],
		["Strategy", result.strategy_factor, result.strategy_name + " plan and live decisions"],
		["Pit stops", result.pit_stop_factor, result.pit_stop_summary],
		["Random incidents", result.incident_factor, result.incident_summary],
	]
	var strongest_name := "race execution"
	var strongest_value := 0.0
	var lines: Array[String] = ["WHY THE RACE ENDED THIS WAY", "Positive pace points helped; negative points cost performance."]
	for factor in factors:
		var value := float(factor[1])
		lines.append("%s  %+.1f  —  %s" % [factor[0], value, factor[2]])
		if absf(value) > absf(strongest_value):
			strongest_name = str(factor[0]).to_lower()
			strongest_value = value
	lines.append("\nDECISIVE FACTOR  %s was the largest %s." % [strongest_name.capitalize(), "advantage" if strongest_value >= 0.0 else "disadvantage"])
	lines.append("RECOMMENDED NEXT ACTION  %s" % _get_result_recommendation(result))
	return "\n".join(lines)


func _get_result_recommendation(result: RaceResult) -> String:
	if result.player_car.condition < 70:
		return "Inspect and repair the car before entering another event."
	if result.car_factor < 0.0:
		return "Compare upgrades in the Marketplace to recover the car deficit."
	if result.driver_factor < 0.0:
		return "Review driver attributes before the next season's contract window."
	if result.strategy_factor < 0.0:
		return "Use a balanced plan next race to reduce strategic risk."
	return "Review the next event and preserve this competitive package."


func create_standings_text(
	result: RaceResult
) -> String:
	var standings_text: String = "Final Standings\n\n"

	for index in range(result.standings.size()):
		var entry: Dictionary = result.standings[index]
		var position: int = index + 1

		var driver_name: String = str(
			entry.get(
				"driver_name",
				"Unknown Driver"
			)
		)

		var team_name: String = str(
			entry.get(
				"team_name",
				"Unknown Team"
			)
		)

		if bool(entry.get("is_player", false)):
			standings_text += (
				"%d. %s — %s (Your Driver)  •  %d passes  •  %d stops  •  systems %d%%\n"
				% [
					position,
					driver_name,
					team_name,
					int(entry.get("overtakes", 0)),
					int(entry.get("pit_stops", 0)),
					roundi(float(entry.get("mechanical_health", 100.0)))
				]
			)
		else:
			standings_text += (
				"%d. %s — %s\n"
				% [
					position,
					driver_name,
					team_name
				]
			)

	return standings_text


func create_financial_summary(result: RaceResult) -> String:
	return (
		"Financial Summary\n\n"
		+ "Weekend Operations: -$%s\n"
		+ "Prize Money: +$%s\n"
		+ "Driver Salary: -$%s\n"
		+ "Crew Chief Salary: -$%s\n"
		+ "Engineering Payroll: -$%s\n"
		+ "Repair Costs: -$%s\n"
		+ "Series Distribution: +$%s\n"
		+ "Event & Hospitality Share: +$%s\n"
		+ "First-Season Owner Support: +$%s\n"
		+ "Manufacturer Support: +$%s\n"
		+ "Sponsor Race Payment: +$%s\n"
		+ "Sponsor Objective Bonus: +$%s\n"
		+ "Sponsor Failure Penalty: -$%s\n"
		+ "Rules Penalty: -$%s\n"
		+ "Net Earnings: %s\n\n"
		+ "Championship Points: +%d\n"
		+ "Season Total: %d\n"
		+ "Prestige XP: +%d\n"
		+ "Team Standing: Sporting %+d  |  Professionalism %+d  |  Commercial %+d\n"
		+ "Fans: +%d%s"
	) % [
		format_number(result.entry_fee),
		format_number(result.prize_money),
		format_number(result.driver_salary),
		format_number(result.crew_chief_salary),
		format_number(result.engineering_payroll),
		format_number(result.repair_cost),
		format_number(result.series_distribution),
		format_number(result.gate_revenue),
		format_number(result.owner_race_support),
		format_number(result.manufacturer_race_support),
		format_number(result.sponsor_race_payment),
		format_number(result.sponsor_objective_bonus),
		format_number(result.sponsor_failure_penalty),
		format_number(result.cheating_penalty),
		format_money_change(result.net_earnings),
		result.championship_points_earned,
		result.total_championship_points,
		result.reputation_earned,
		int(result.reputation_changes.get("sporting_credibility", 0)),
		int(result.reputation_changes.get("professionalism", 0)),
		int(result.reputation_changes.get("commercial_appeal", 0)),
		result.fans_earned,
		("\n%s objective completed!" % result.sponsor_name if result.sponsor_objective_completed else "")
		+ ("\nContracts expired: %s" % ", ".join(result.expired_staff_names) if not result.expired_staff_names.is_empty() else "")
	]


func create_car_effects_text(result: RaceResult) -> String:
	var current_condition: int = result.player_car.condition
	var current_mileage: int = result.player_car.mileage

	return (
		"Weekend Breakdown\n\n"
		+ "Practice: %s (setup +%.1f)\n"
		+ "Qualifying: %s • Started P%d\n"
		+ "Finish: P%d • Positions gained: %+d\n"
		+ "Strategy effect: %+.1f pace points\n"
		+ "%s\n\n"
		+ "Car Effects\n"
		+ "Strategy: %s\n"
		+ "Performance: %s | Variance: %s | Wear: %s\n"
		+ "Mileage Added: +%s\n"
		+ "Condition Lost: -%d%%\n"
		+ "Current Mileage: %s\n"
		+ "Current Condition: %d%%"
	) % [
		result.practice_focus_name,
		result.setup_bonus,
		result.qualifying_approach_name,
		result.starting_position,
		result.finishing_position,
		result.positions_gained,
		result.strategy_effectiveness,
		create_decision_summary(result),
		result.strategy_name,
		format_modifier(result.strategy_performance_modifier),
		format_modifier(result.strategy_variance_modifier),
		format_modifier(result.strategy_wear_modifier),
		format_number(result.mileage_added),
		result.condition_lost,
		format_number(current_mileage),
		current_condition
	]


func create_decision_summary(result: RaceResult) -> String:
	if result.weekend_summary.is_empty():
		return "No live strategy decisions recorded."
	var lines: Array[String] = ["Key decisions:"]
	for summary in result.weekend_summary:
		lines.append("• %s" % summary)
	return "\n".join(lines)


func format_modifier(modifier: float) -> String:
	var percent := roundi((modifier - 1.0) * 100.0)
	if percent > 0:
		return "+%d%%" % percent
	return "%d%%" % percent


func format_position(position: int) -> String:
	var last_two_digits: int = position % 100

	if last_two_digits >= 11 and last_two_digits <= 13:
		return "%dth" % position

	match position % 10:
		1:
			return "%dst" % position
		2:
			return "%dnd" % position
		3:
			return "%drd" % position
		_:
			return "%dth" % position


func format_money_change(amount: int) -> String:
	if amount > 0:
		return "+$%s" % format_number(amount)

	if amount < 0:
		return "-$%s" % format_number(abs(amount))

	return "$0"


func show_missing_result() -> void:
	race_name_label.text = "No Race Result"
	finishing_position_label.text = ""
	outcome_story_label.text = ""
	standings_label.text = ""
	summary_label.text = (
		"No race result is currently available."
	)
	car_effects_label.text = ""
	decisive_factors_label.text = ""
	replay_label.text = ""
	analysis_label.text = ""


func _on_continue_button_pressed() -> void:
	RaceManager.clear_last_result()

	GameManager.selected_car = null
	GameManager.selected_race = null

	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
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
