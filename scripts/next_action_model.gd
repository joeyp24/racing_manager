class_name NextActionModel
extends RefCounted


static func derive(team: Team, current_page: String = "") -> Dictionary:
	if team == null:
		return _action("Set up your race team", "No career is loaded.", "Create or load a career to continue.", "Dashboard", "dashboard")
	if RaceManager.last_result != null:
		return _action("Review the race result", "The checkered flag has fallen.", "Understand what gained and cost positions before servicing the car.", "Open race report", "race_results", RaceReadiness.READY)
	if GameManager.is_race_weekend_locked():
		var opening_step := FirstHourExperience.current_step(team, GameManager.active_race_weekend)
		return _action(
			str(opening_step.get("title", "Continue race weekend")),
			"The entry fee is committed and this weekend must be completed before returning to team management.",
			str(opening_step.get("body", "Complete the active session.")),
			"CONTINUE RACE WEEKEND",
			"continue_weekend",
			RaceReadiness.READY
		)
	if not FirstHourExperience.is_complete(team):
		var step := FirstHourExperience.current_step(team)
		var step_id := str(step.get("id", ""))
		if step_id in ["practice", "strategy", "race"]:
			var first_race := RaceManager.get_next_race(team)
			return _action(
				"Enter your first race weekend",
				"Your driver, car, and sponsor are ready for the guided opening event.",
				"Practice, choose a strategy, and finish the race without leaving the weekend.",
				"CONTINUE RACE WEEKEND",
				"race_entry",
				RaceReadiness.READY,
				[],
				first_race
			)
		return _action(
			str(step.get("title", "Continue team setup")),
			str(step.get("body", "Complete the next opening goal.")),
			FirstHourExperience.progress_text(team),
			str(step.get("action_label", "Continue")),
			str(step.get("action", "dashboard")),
			RaceReadiness.READY
		)
	if team.is_series_season_complete():
		return _action("Review standings and begin Season %d" % (team.season_number + 1), "Season %d is complete." % team.season_number, "Starting a season resets the calendar and seasonal contracts.", "Championship", "championship", RaceReadiness.READY)

	var race := RaceManager.get_next_race(team)
	if race == null:
		return _action("Review the race calendar", "There is no available event on the schedule.", "See completed and locked events.", "Calendar", "calendar")

	var checks := RaceReadiness.evaluate(team, race)
	var blocker := _highest_priority_check(checks)
	var race_name := race.race_name
	if blocker.is_empty():
		return _action("Enter %s" % race_name, "All required systems are ready.", "Entry costs $%s and opens race preparation." % _money(race.entry_fee), "Prepare race →", "race_entry", RaceReadiness.READY, checks, race)

	var status := str(blocker.get("status", RaceReadiness.SUBOPTIMAL))
	var action_id := str(blocker.get("action", "calendar"))
	var title := "Prepare for %s" % race_name
	if status == RaceReadiness.BLOCKED:
		match action_id:
			"drivers": title = "Contract a driver for the season"
			"garage":
				if _has_a_car(team):
					title = "Repair an eligible car"
				else:
					title = "Purchase your first car"
					action_id = "dealership"
					blocker["action_label"] = "Open Marketplace →"
			"staff": title = "Hire a Crew Chief"
			"finances": title = "Raise funds for the $%s entry fee" % _money(race.entry_fee)
	return _action(title, str(blocker.get("explanation", "Review race readiness.")), "Entry: $%s · Destination: %s" % [_money(race.entry_fee), _destination_name(action_id)], str(blocker.get("action_label", "Review")), action_id, status, checks, race)


static func _highest_priority_check(checks: Array[Dictionary]) -> Dictionary:
	for check in checks:
		if str(check.get("status", "")) == RaceReadiness.BLOCKED:
			return check
	for check in checks:
		if str(check.get("status", "")) == RaceReadiness.SUBOPTIMAL:
			return check
	return {}


static func _action(title: String, reason: String, consequence: String, label: String, action: String, status: String = RaceReadiness.BLOCKED, checks: Array[Dictionary] = [], race: Race = null) -> Dictionary:
	return {"title": title, "reason": reason, "consequence": consequence, "action_label": label, "action": action, "status": status, "checks": checks, "race": race}


static func _destination_name(action: String) -> String:
	return {"drivers": "Drivers", "garage": "Garage", "dealership": "Marketplace", "staff": "Staff", "finances": "Finances", "sponsors": "Sponsors", "race_entry": "Race Entry", "calendar": "Calendar", "championship": "Championship", "continue_weekend": "Race Weekend", "race_results": "Race Results"}.get(action, "Dashboard")


static func _has_a_car(team: Team) -> bool:
	for car in team.cars:
		if car != null:
			return true
	return false


static func _money(amount: int) -> String:
	var value := str(amount)
	var output := ""
	while value.length() > 3:
		output = "," + value.right(3) + output
		value = value.left(value.length() - 3)
	return value + output
