extends SceneTree


func _initialize() -> void:
	_test_new_standings_entries_are_persisted()
	_test_multiple_player_entries_are_tracked_independently()
	print("Multi-team progression tests passed")
	quit(0)


func _test_new_standings_entries_are_persisted() -> void:
	var game_manager := root.get_node("GameManager")
	var race_manager := root.get_node("RaceManager")
	var previous_team: Team = game_manager.team
	var team := Team.new()
	game_manager.team = team
	team.set_series_standings(team.current_series_id, [])
	race_manager.ensure_championship_entry("player_one", "Player One", "Team 1", true, "team_1")
	assert(team.get_championship_standings().size() == 1)
	assert(str(team.get_championship_standings()[0].driver_id) == "player_one")
	race_manager.ensure_championship_entry("player_one", "Updated Name", "Team 1", true, "team_1")
	assert(team.get_championship_standings().size() == 1)
	assert(str(team.get_championship_standings()[0].driver_name) == "Updated Name")
	game_manager.team = previous_team


func _test_multiple_player_entries_are_tracked_independently() -> void:
	var game_manager := root.get_node("GameManager")
	var race_manager := root.get_node("RaceManager")
	var previous_team: Team = game_manager.team
	var team := Team.new()
	game_manager.team = team
	team.set_series_standings(team.current_series_id, [])
	race_manager.ensure_championship_entry("player_one", "Player One", "Team 1", true, "team_1")
	race_manager.ensure_championship_entry("player_two", "Player Two", "Team 2", true, "team_2")
	var race_standings: Array[Dictionary] = [
		{"driver_id":"player_two", "driver_name":"Player Two"},
		{"driver_id":"player_one", "driver_name":"Player One"}
	]
	race_manager.update_championship_standings(race_standings)
	var first := team.get_championship_entry_for_driver("player_one")
	var second := team.get_championship_entry_for_driver("player_two")
	assert(int(first.starts) == 1 and int(second.starts) == 1)
	assert(int(second.points) > int(first.points))
	assert(int(first.best_finish) == 2 and int(second.best_finish) == 1)
	game_manager.team = previous_team
