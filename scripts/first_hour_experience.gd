class_name FirstHourExperience
extends RefCounted

const STEP_ORDER: Array[String] = [
	"identity",
	"driver",
	"car",
	"sponsor",
	"practice",
	"strategy",
	"race",
	"service",
]

const STEP_DATA: Dictionary = {
	"identity": {
		"title": "Name your race team",
		"body": "Choose the identity that will follow your team through every season.",
		"action": "dashboard",
		"action_label": "Complete team setup",
	},
	"driver": {
		"title": "Choose your first driver",
		"body": "Compare the entry-level candidates and sign one sustainable season contract.",
		"action": "driver_market",
		"action_label": "Choose a driver",
	},
	"car": {
		"title": "Buy a basic race car",
		"body": "Start with an affordable Local Short Track car. It will be assigned to your first race team automatically.",
		"action": "dealership",
		"action_label": "Choose a car",
	},
	"sponsor": {
		"title": "Sign your first sponsor",
		"body": "Secure dependable race income before committing money to the opening weekend.",
		"action": "sponsors",
		"action_label": "Review sponsor offers",
	},
	"practice": {
		"title": "Complete the practice programme",
		"body": "Enter the first event and use three short runs to learn how setup choices change the car.",
		"action": "continue_weekend",
		"action_label": "Continue race weekend",
	},
	"strategy": {
		"title": "Commit to a race strategy",
		"body": "Balance expected pace against tyre wear, incident exposure, and financial risk.",
		"action": "continue_weekend",
		"action_label": "Choose race strategy",
	},
	"race": {
		"title": "Finish your first race",
		"body": "Run the event to the checkered flag and respond to the pit wall when conditions change.",
		"action": "continue_weekend",
		"action_label": "Continue race",
	},
	"service": {
		"title": "Service or improve the car",
		"body": "Use the post-race report to repair damage or purchase a meaningful first upgrade.",
		"action": "garage",
		"action_label": "Open the garage",
	},
}


static func ensure_state(team: Team) -> Dictionary:
	if team == null:
		return {}
	if team.career_state == null:
		team.career_state = {}
	var state := team.career_state.get("first_hour", {}) as Dictionary
	if not state.has("started_at"):
		state["started_at"] = int(Time.get_unix_time_from_system())
	if not state.has("completed_steps"):
		state["completed_steps"] = []
	if not state.has("milestones"):
		state["milestones"] = {}
	if not state.has("strategy_committed"):
		state["strategy_committed"] = false
	if not state.has("complete"):
		state["complete"] = false
	team.career_state["first_hour"] = state
	return state


static func refresh(team: Team, active_weekend: Dictionary = {}) -> Dictionary:
	var state := ensure_state(team)
	if state.is_empty():
		return state
	_complete_if(team, state, "identity", team.tutorial_completed and team.team_name.strip_edges().length() >= 2)
	_complete_if(team, state, "driver", team.driver_hired_for_season and not team.get_contracted_drivers().is_empty())
	_complete_if(team, state, "car", _has_car(team))
	_complete_if(team, state, "sponsor", not team.get_active_sponsor_contracts().is_empty())
	var practice_runs := active_weekend.get("practice_runs", []) as Array
	_complete_if(team, state, "practice", practice_runs.size() >= PracticeRunSimulator.RUN_LIMIT or not team.get_completed_races().is_empty())
	_complete_if(team, state, "strategy", bool(state.get("strategy_committed", false)) or not team.get_completed_races().is_empty())
	_complete_if(team, state, "race", not team.get_completed_races().is_empty())
	_complete_if(team, state, "service", _has_post_race_service(team))
	var completed := state.get("completed_steps", []) as Array
	state["complete"] = completed.size() >= STEP_ORDER.size()
	team.career_state["first_hour"] = state
	return state


static func mark_strategy_committed(team: Team) -> void:
	var state := ensure_state(team)
	state["strategy_committed"] = true
	team.career_state["first_hour"] = state
	refresh(team)


static func current_step(team: Team, active_weekend: Dictionary = {}) -> Dictionary:
	var state := refresh(team, active_weekend)
	var completed := state.get("completed_steps", []) as Array
	for step_id in STEP_ORDER:
		if not completed.has(step_id):
			var data := (STEP_DATA[step_id] as Dictionary).duplicate(true)
			data["id"] = step_id
			data["number"] = completed.size() + 1
			data["total"] = STEP_ORDER.size()
			return data
	return {
		"id": "complete",
		"title": "Your race team is operational",
		"body": "The full management suite is now available. Keep the next race affordable, improve the car, and meet the board's expectations.",
		"action": "dashboard",
		"action_label": "Review race week",
		"number": STEP_ORDER.size(),
		"total": STEP_ORDER.size(),
	}


static func is_complete(team: Team) -> bool:
	return bool(refresh(team).get("complete", false)) if team != null else false


static func progress_text(team: Team, active_weekend: Dictionary = {}) -> String:
	var state := refresh(team, active_weekend)
	return "%d OF %d OPENING GOALS COMPLETE" % [
		(state.get("completed_steps", []) as Array).size(),
		STEP_ORDER.size(),
	]


static func _complete_if(team: Team, state: Dictionary, step_id: String, condition: bool) -> void:
	if not condition:
		return
	var completed := state.get("completed_steps", []) as Array
	if completed.has(step_id):
		return
	completed.append(step_id)
	state["completed_steps"] = completed
	var milestones := state.get("milestones", {}) as Dictionary
	milestones[step_id] = {
		"elapsed_seconds": maxi(0, int(Time.get_unix_time_from_system()) - int(state.get("started_at", 0))),
		"cash": team.money,
		"races_completed": team.get_completed_races().size(),
	}
	state["milestones"] = milestones


static func _has_car(team: Team) -> bool:
	for value in team.cars:
		if value is Car:
			return true
	return false


static func _has_post_race_service(team: Team) -> bool:
	if team.get_completed_races().is_empty():
		return false
	for value in team.finance_history:
		var entry := value as Dictionary
		if int(entry.get("race", 0)) < 2:
			continue
		var category := str(entry.get("category", ""))
		var description := str(entry.get("description", ""))
		if category in ["Repairs", "Workshop"] or (category == "Parts" and description.begins_with("Installed ")):
			return true
	return false
