extends SceneTree


func _initialize() -> void:
	_test_persistent_driver_market_and_contract_decisions()
	print("Offseason and driver transfer tests passed")
	quit(0)


func _test_persistent_driver_market_and_contract_decisions() -> void:
	var team := Team.new()
	team.money = 500000
	var expected_roster_size := 0
	for series in SeriesCatalog.SERIES:
		expected_roster_size += int(series.roster_size)
	assert(team.ai_driver_career.size() >= expected_roster_size)
	var player_driver := team.get_active_driver()
	assert(player_driver != null)
	player_driver.contract_races_remaining = 0
	var second_driver := team.get_driver_by_id("maya_torres")
	assert(second_driver != null)
	second_driver.contract_races_remaining = 0
	second_driver.team_name = team.team_name
	team.contracted_driver_ids.append(second_driver.driver_id)
	var second_state := team.ensure_ai_driver_state(second_driver)
	second_state["current_team_id"] = "player_team"
	team.ai_driver_career[second_driver.driver_id] = second_state
	var data := OffseasonManager.prepare(team, team.current_series_id, ["AI development test summary"])
	assert(str(data.status) == "Prepared")
	assert((data.rookies as Array).size() >= SeriesCatalog.SERIES.size())
	assert(not (data.player_contracts as Array).is_empty())
	assert(not (data.free_agent_ids as Array).is_empty())
	assert(not (data.rumors as Array).is_empty())
	assert(not (data.transactions as Array).is_empty())
	for series in SeriesCatalog.SERIES:
		for organization in team.get_ai_organizations_for_series(str(series.id)):
			assert(team.get_ai_lineup_for_team(str(organization.team_id)).size() == int(organization.driver_count))
	var contract := (data.player_contracts as Array)[0] as Dictionary
	assert(str(contract.status) == "Pending")
	assert(contract.has("team_fit") and contract.has("career_goal") and contract.has("rival_team_id"))
	var renewal := OffseasonManager.renew_player_driver(team, player_driver.driver_id)
	assert(bool(renewal.accepted))
	assert(player_driver.contract_races_remaining > 0)
	assert(OffseasonManager.release_player_driver(team, second_driver.driver_id))
	assert(not team.contracted_driver_ids.has(second_driver.driver_id))
	assert(str(team.get_ai_driver_state(second_driver.driver_id).current_team_id) != "player_team")
	var free_agent_id := str((team.offseason_data.free_agent_ids as Array)[0])
	var signing := OffseasonManager.sign_free_agent(team, free_agent_id)
	assert(bool(signing.accepted))
	assert(team.contracted_driver_ids.has(free_agent_id))
	var readiness := OffseasonManager.can_complete(team)
	assert(bool(readiness.ready))
	assert(OffseasonManager.complete(team))
	assert(team.season_history.size() == 1)
	assert(not team.transfer_history.is_empty())
	var save_path := "user://offseason_test.tres"
	assert(ResourceSaver.save(team, save_path) == OK)
	var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Team
	assert(reloaded != null)
	assert(reloaded.season_history.size() == 1)
	assert(reloaded.transfer_history.size() == team.transfer_history.size())
	assert(reloaded.ai_driver_career.size() == team.ai_driver_career.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
