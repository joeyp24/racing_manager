extends SceneTree

var race_manager: Node

func _initialize() -> void:
	race_manager = get_root().get_node("RaceManager")
	_test_opening_milestones_advance_in_order()
	_test_committed_weekend_routes_to_required_stage()
	print("First-hour experience tests passed")
	quit(0)


func _test_opening_milestones_advance_in_order() -> void:
	var team := Team.new()
	team.tutorial_completed = true
	team.team_name = "Opening Test"
	assert(str(FirstHourExperience.current_step(team).id) == "driver")

	var driver := team.drivers[0] as Driver
	team.contracted_driver_ids.append(driver.driver_id)
	team.driver_hired_for_season = true
	driver.is_player_driver = true
	team.get_active_race_team().driver_id = driver.driver_id
	assert(str(FirstHourExperience.current_step(team).id) == "car")

	var car := SeriesCatalog.create_car_templates(team.current_series_id)[0] as Car
	team.cars[0] = car
	team.get_active_race_team().car_bay = 0
	assert(str(FirstHourExperience.current_step(team).id) == "sponsor")

	SponsorManager.ensure_state(team)
	assert(not SponsorManager.sign_offer(team, 0).is_empty())
	assert(str(FirstHourExperience.current_step(team).id) == "practice")

	var weekend := {"practice_runs": [{}, {}, {}]}
	assert(str(FirstHourExperience.current_step(team, weekend).id) == "strategy")
	FirstHourExperience.mark_strategy_committed(team)
	assert(str(FirstHourExperience.current_step(team, weekend).id) == "race")

	var race := race_manager.call("get_next_race", team) as Race
	team.complete_race_for_series(team.current_series_id, race.race_id)
	assert(str(FirstHourExperience.current_step(team).id) == "service")
	team.record_finance("Repairs", -250, "Opening-race repair")
	assert(FirstHourExperience.is_complete(team))
	assert((team.career_state.first_hour.milestones as Dictionary).size() == 8)


func _test_committed_weekend_routes_to_required_stage() -> void:
	var game_manager := get_root().get_node("GameManager")
	game_manager.call("begin_race_weekend", {"entry_fee_total": 1000})
	assert(game_manager.call("is_race_weekend_locked"))
	assert(str(game_manager.call("get_active_race_weekend_path")).ends_with("race_weekend.tscn"))
	game_manager.call("set_race_weekend_stage", "live_race")
	assert(str(game_manager.call("get_active_race_weekend_path")).ends_with("live_race.tscn"))
	game_manager.call("finish_race_weekend")
	assert(not game_manager.call("is_race_weekend_locked"))
