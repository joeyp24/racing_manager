extends SceneTree


func _initialize() -> void:
	_test_feature_state_and_persistence()
	_test_career_actions_and_progression()
	_test_dynamic_race_environment_and_commands()
	print("Career-wide expansion tests passed")
	quit(0)


func _test_feature_state_and_persistence() -> void:
	var team := Team.new()
	var state := CareerExpansionManager.ensure_state(team)
	for key in [
		"inbox", "board", "rivalries", "story_arcs", "awards", "hall_of_fame",
		"academy", "scouting_network", "relationships", "injuries", "staff_dynamics", "contract_terms",
		"rd", "car_design", "manufacturing", "regulations", "manufacturer", "preseason",
		"stewarding", "facilities", "logistics", "resource_allocations", "sponsor_activations",
		"merchandise", "finance_forecast", "calendar_variations", "records", "world_entrants",
		"alliances", "international", "tutorial", "accessibility", "branding", "stats"
	]:
		assert(state.has(key))
	CareerExpansionManager.add_inbox_item(team, "Board", "Test decision", "Choose a response.", [
		{"label":"Invest", "cost":1000, "effects":{"confidence":3, "fans":10}}
	])
	var money_before := team.money
	var confidence_before := int(state.board.confidence)
	assert(CareerExpansionManager.resolve_inbox(team, str((state.inbox[0] as Dictionary).id), 0))
	assert(team.money == money_before - 1000)
	assert(int(state.board.confidence) == confidence_before + 3)
	var save_path := "user://career_expansion_test.tres"
	assert(ResourceSaver.save(team, save_path) == OK)
	var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Team
	assert(reloaded != null)
	assert(bool((reloaded.career_state.inbox[0] as Dictionary).resolved))
	assert(reloaded.save_format_version == Team.CURRENT_SAVE_FORMAT_VERSION)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _test_career_actions_and_progression() -> void:
	var team := Team.new()
	team.money = 200000
	var state := CareerExpansionManager.ensure_state(team)
	var prospect := state.academy.prospects[0] as Dictionary
	assert(CareerExpansionManager.recruit_academy_prospect(team, str(prospect.id)))
	assert((state.academy.enrolled as Array).size() == 1)
	assert(CareerExpansionManager.assign_scouting_region(team, "Europe"))
	assert(CareerExpansionManager.upgrade_scouting_region(team, "Europe"))
	assert(CareerExpansionManager.start_rd_project(team, "engine_efficiency"))
	assert(CareerExpansionManager.start_facility_upgrade(team, "design_office"))
	var summaries := CareerExpansionManager.process_day(team, 60)
	assert(not summaries.is_empty())
	assert((state.rd.completed as Array).has("engine_efficiency"))
	assert(CareerExpansionManager.get_facility_level(team, "design_office") == 1)
	assert(CareerExpansionManager.set_car_design(team, "Endurance", 22, 26, 52))
	assert(float(CareerExpansionManager.get_car_design_modifiers(team).reliability) > 0.0)
	CareerExpansionManager.process_season_end(team, 5)
	assert(int(state.season_processed) == team.current_season_year)
	assert((state.calendar_variations as Dictionary).has(str(team.current_season_year + 1)))
	assert(not (state.regulations.next as Dictionary).is_empty())
	assert(not (state.alliances as Array).is_empty())


func _test_dynamic_race_environment_and_commands() -> void:
	var race := Race.new()
	race.race_id = "career_expansion_race"
	race.race_name = "Career Expansion Test"
	race.series_id = "local_short_track"
	race.lap_count = 8
	race.accident_factor = 0.0
	race.mechanical_stress = 0.0
	race.fuel_consumption_factor = 0.8
	race.tyre_wear_factor = 1.0
	var driver := Driver.new()
	driver.driver_id = "expansion_driver"
	driver.driver_name = "Expansion Driver"
	driver.initialize_detailed_ratings(65, 65, 60, 80)
	var simulation := RaceSimulation.new()
	var ai: Array[Dictionary] = [{"driver_id":"ai", "driver_name":"AI Driver", "team_name":"AI Team", "skill":60, "consistency":60, "aggression":55}]
	var scores: Array[float] = [60.0]
	simulation.setup(race, driver, "Player Team", 64.0, 1, ai, scores, "Medium", [], 2042)
	simulation.configure_environment({"weather":"Wet", "rain_chance":90, "temperature":17})
	simulation.set_player_fuel_target("Save")
	simulation.set_player_racecraft_command("Defend")
	simulation.set_team_order("Hold position", "Player Team")
	assert(simulation.request_player_pit_stop("Wet"))
	while not simulation.is_complete:
		simulation.simulate_lap()
	var player := simulation.get_player_entry()
	assert(player != null)
	assert(player.tyre_compound == "Wet")
	assert(player.fuel_target_mode == "Save")
	assert(player.team_order == "Hold position")
	assert(not simulation.replay_timeline.is_empty())
	assert(not simulation.weather_timeline.is_empty())
	assert((simulation.as_final_standings()[0] as Dictionary).has("racecraft_command"))
