extends SceneTree


func _initialize() -> void:
	_test_decision_comparison_and_safe_advance()
	print("Career decision-center model tests passed")
	quit(0)


func _test_decision_comparison_and_safe_advance() -> void:
	var team := Team.new()
	team.money = 50000
	team.ensure_race_teams()
	for index in range(1, 4):
		var race_team := RaceTeam.new()
		race_team.team_id = "team_%d" % (index + 1)
		race_team.team_name = "Race Team %d" % (index + 1)
		team.race_teams.append(race_team)
	CareerExpansionManager.add_inbox_item(team, "Board", "Urgent plan", "Choose before the next checkpoint.", [
		{"label":"Approve", "cost":2500, "effects":{"confidence":4, "fans":25}},
	], {
		"deadline": team.current_season_day + 2,
		"priority": "High",
		"race_team_id": "team_2",
		"action_path": "res://scenes/pages/reputation/reputation.tscn",
	})
	CareerExpansionManager.add_inbox_item(team, "Media", "Later interview", "This can wait.", [
		{"label":"Attend", "cost":0, "effects":{"fans":10}},
	], {"deadline": team.current_season_day + 12})
	var state := CareerExpansionManager.ensure_state(team)
	var urgent := CareerExpansionManager.get_pending_decisions(team).front() as Dictionary
	assert(str(urgent.subject) == "Urgent plan")
	assert(str(urgent.race_team_id) == "team_2")
	assert(str(urgent.action_path).ends_with("reputation/reputation.tscn"))
	var model := CareerDecisionModel.build_inbox_choice(team, urgent, 0)
	assert(bool(model.action_enabled))
	assert(str(model.context.kind) == "career_inbox_choice")
	assert((model.metrics as Array).size() == 2)
	assert(str((model.finance as Dictionary).upfront) == "-$2,500")

	state.sponsor_activations.append({
		"event":"Partner appearance",
		"deadline":team.current_season_day + 3,
		"completed":false,
		"declined":false,
	})
	state.rd.projects.append({"node_id":"engine_efficiency", "days_remaining":4})
	state.construction.append({"facility_id":"design_office", "days_remaining":5})
	var target_day := team.current_season_day + 5
	var impacts := CareerExpansionManager.get_time_advance_impacts(team, target_day)
	assert(bool(impacts.blocked))
	assert((impacts.expiring_decisions as Array).size() == 1)
	assert((impacts.expiring_activations as Array).size() == 1)
	assert((impacts.completions as Array).size() == 2)
	assert((impacts.entry_readiness as Array).size() == 4)
	var advance_model := CareerDecisionModel.build_time_advance(team, target_day, {
		"days":5,
		"events":[],
		"other_races":0,
	}, impacts)
	assert(not bool(advance_model.action_enabled))
	assert(str(advance_model.disabled_reason).contains("unresolved decision"))

	assert(CareerExpansionManager.resolve_inbox(team, str(urgent.id), 0))
	(state.sponsor_activations[0] as Dictionary).declined = true
	impacts = CareerExpansionManager.get_time_advance_impacts(team, target_day)
	assert(not bool(impacts.blocked))
	assert((impacts.entry_readiness as Array).size() == 4)
