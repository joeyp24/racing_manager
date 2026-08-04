extends SceneTree


func _initialize() -> void:
	_test_practice_runs_are_deterministic_and_setup_sensitive()
	_test_race_strategy_resources_and_caution_compression()
	_test_race_operations_strategy_and_damage()
	_test_venue_presentations_are_specific()
	_test_economy_difficulty_scaling()
	_test_ai_team_careers_persist_and_develop()
	print("Career simulation depth tests passed")
	quit(0)


func _test_practice_runs_are_deterministic_and_setup_sensitive() -> void:
	var race := _make_race()
	var driver := _make_driver()
	var ideal := PracticeRunSimulator.get_ideal_setup(race)
	var poor := PracticeRunSimulator.DEFAULT_SETUP.duplicate(true)
	for axis in poor:
		poor[axis] = -2 if int(ideal[axis]) >= 0 else 2
	assert(PracticeRunSimulator.setup_score(race, ideal) > PracticeRunSimulator.setup_score(race, poor))
	var first := PracticeRunSimulator.simulate_run(race, driver, 65.0, ideal, "Standard", 1, 2026)
	var repeat := PracticeRunSimulator.simulate_run(race, driver, 65.0, ideal, "Standard", 1, 2026)
	assert(is_equal_approx(float(first.lap_time), float(repeat.lap_time)))
	assert(str(first.feedback) == str(repeat.feedback))
	assert(float(first.feedback_quality) >= 15.0 and float(first.feedback_quality) <= 98.0)


func _test_race_strategy_resources_and_caution_compression() -> void:
	var race := _make_race()
	race.lap_count = 8
	race.accident_factor = 0.0
	race.mechanical_stress = 0.0
	var simulation := RaceSimulation.new()
	var ai: Array[Dictionary] = [
		{"driver_id":"ai_1", "driver_name":"A Driver", "team_name":"A Team", "skill":60, "consistency":60, "aggression":65, "strategy_rating":72},
		{"driver_id":"ai_2", "driver_name":"B Driver", "team_name":"B Team", "skill":58, "consistency":55, "aggression":55, "strategy_rating":45}
	]
	var scores: Array[float] = [62.0, 59.0]
	simulation.setup(race, _make_driver(), "Player Team", 61.0, 2, ai, scores, "Standard", [], 2026, {"reliability":68.0, "fuel":52.0, "tyres":58.0}, "Balanced", PracticeRunSimulator.get_ideal_setup(race))
	simulation.entries[2].elapsed_time += 12.0
	var caution_state := {"lap":-1}
	simulation.caution_started.connect(func(lap: int) -> void: caution_state.lap = lap)
	simulation._trigger_caution()
	assert(int(caution_state.lap) == 0)
	simulation.simulate_lap()
	assert(simulation.caution_count == 1)
	assert(simulation.entries[simulation.entries.size() - 1].gap_to(simulation.entries[0]) <= float(simulation.entries.size() - 1) * 0.29)
	while not simulation.is_complete:
		simulation.simulate_lap()
	for entry in simulation.entries:
		assert(entry.fuel_laps >= 0.0)
		assert(entry.tyre_condition >= 0.0 and entry.tyre_condition <= 100.0)
		assert(entry.mechanical_health >= 0.0 and entry.mechanical_health <= 100.0)
	var ai_pit_stops := 0
	for entry in simulation.entries:
		if not entry.is_player:
			ai_pit_stops += entry.pit_stops
	assert(ai_pit_stops > 0)
	var standings := simulation.as_final_standings()
	assert(standings.size() == 3)
	assert((standings[0] as Dictionary).has("overtakes"))
	assert((standings[0] as Dictionary).has("mechanical_health"))


func _test_economy_difficulty_scaling() -> void:
	var team := Team.new()
	var race := _make_race()
	team.career_difficulty = "Rookie"
	var rookie_cost := team.get_effective_weekend_cost(race)
	var rookie_sponsor := team.get_effective_sponsor_value(1000)
	team.career_difficulty = "Club"
	var club_cost := team.get_effective_weekend_cost(race)
	var club_sponsor := team.get_effective_sponsor_value(1000)
	team.career_difficulty = "Pro"
	var pro_cost := team.get_effective_weekend_cost(race)
	var pro_sponsor := team.get_effective_sponsor_value(1000)
	assert(rookie_cost < club_cost and club_cost < pro_cost)
	assert(rookie_sponsor > club_sponsor and club_sponsor > pro_sponsor)


func _test_race_operations_strategy_and_damage() -> void:
	var race := _make_race()
	race.lap_count = 12
	race.accident_factor = 0.0
	race.mechanical_stress = 0.0
	var simulation := RaceSimulation.new()
	var ai: Array[Dictionary] = [
		{"driver_id":"ai_ops", "driver_name":"Ops Rival", "team_name":"Rival", "skill":60, "consistency":60, "aggression":60, "strategy_rating":65, "philosophy_id":"aggressive_development", "strategy_aggression":0.20}
	]
	var scores: Array[float] = [60.0]
	simulation.setup(race, _make_driver(), "Player Team", 61.0, 1, ai, scores, "Standard", [], 77, {"reliability":70.0, "fuel":55.0, "tyres":55.0, "engineer_quality":46.0, "component_health":{"aerodynamics":100.0,"suspension":100.0,"engine":100.0,"brakes":100.0,"drivetrain":100.0}})
	var player := simulation.get_player_entry()
	assert(not simulation.latest_engineer_advice.is_empty())
	assert(simulation.latest_engineer_advice.has("was_accurate"))
	assert(int(simulation.latest_engineer_advice.staff_quality) == 46)
	player.tyre_condition = 35.0
	var fuel_only: Dictionary = simulation.get_pit_service_options().fuel_only
	var fuel_prediction: Dictionary = simulation.predict_player_pit_loss(fuel_only)
	assert(float(fuel_prediction.time_loss) > 0.0)
	simulation._perform_pit_stop(player, fuel_only)
	assert(is_equal_approx(player.tyre_condition, 35.0))
	player.component_health["suspension"] = 42.0
	var before_repair := float(player.component_health.suspension)
	simulation._perform_pit_stop(player, simulation.get_pit_service_options().quick_repairs)
	assert(float(player.component_health.suspension) > before_repair)
	assert(player.tyre_condition == 100.0)
	assert(simulation.strategy_timeline.any(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "stop"))
	simulation.current_lap = 11
	simulation._trigger_caution()
	assert(simulation.overtime_attempts == 1)
	assert(simulation.get_total_laps() == 13)
	player.laps_down = 1
	var wave: Dictionary = simulation.request_player_wave_around()
	assert(bool(wave.success) and bool(wave.gained_lap) and player.laps_down == 0)


func _test_venue_presentations_are_specific() -> void:
	var first := _make_race()
	first.track_name = "Pine Ridge Raceway"
	var second := _make_race()
	second.track_name = "Copper Valley Raceway"
	var first_profile: Dictionary = TrackPresentationCatalog.get_profile(first)
	var second_profile: Dictionary = TrackPresentationCatalog.get_profile(second)
	assert(first_profile.venue_id != second_profile.venue_id)
	assert(first_profile.points != second_profile.points)
	assert((first_profile.corners as Array).size() >= 4)
	assert(float(first_profile.pit_entry) != float(first_profile.pit_exit))
	assert(not str(first_profile.camera_style).is_empty())
	var passing_zones := 0
	for corner_value in first_profile.corners:
		if bool((corner_value as Dictionary).passing):
			passing_zones += 1
	assert(passing_zones >= 1)


func _test_ai_team_careers_persist_and_develop() -> void:
	var team := Team.new()
	var expected_count := 0
	for series in SeriesCatalog.SERIES:
		expected_count += TeamCatalog.get_teams(str(series.id)).size()
	assert(team.ai_team_career.size() == expected_count)
	var first_id := str(team.ai_team_career.keys()[0])
	var starting_state := team.get_ai_team_state(first_id).duplicate(true)
	assert(starting_state.has("philosophy_id"))
	assert(starting_state.has("regulation_preference"))
	var summaries := team.process_ai_team_season()
	var updated_state := team.get_ai_team_state(first_id)
	assert(int(updated_state.seasons) == int(starting_state.seasons) + 1)
	assert(not summaries.is_empty())
	var save_path := "user://ai_team_career_test.tres"
	assert(ResourceSaver.save(team, save_path) == OK)
	var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Team
	assert(reloaded != null)
	assert(int(reloaded.get_ai_team_state(first_id).seasons) == int(updated_state.seasons))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var movements := 0
	for state_value in team.ai_team_career.values():
		var state := state_value as Dictionary
		if not str(state.get("movement", "")).is_empty():
			movements += 1
	assert(movements >= 2)


func _make_race() -> Race:
	var race := Race.new()
	race.race_id = "depth_test"
	race.series_id = "local_short_track"
	race.race_name = "Simulation Depth Test"
	race.lap_count = 25
	race.entry_fee = 500
	race.travel_cost = 350
	race.preparation_cost = 250
	race.insurance_cost = 75
	race.facility_cost = 125
	race.power_demand = 0.62
	race.handling_demand = 0.78
	race.tyre_wear_factor = 1.18
	race.fuel_consumption_factor = 1.04
	race.overtaking_difficulty = 0.42
	race.mechanical_stress = 1.15
	race.track_type = "Short Track"
	return race


func _make_driver() -> Driver:
	var driver := Driver.new()
	driver.driver_id = "player_test"
	driver.driver_name = "Test Driver"
	driver.initialize_detailed_ratings(64, 62, 61, 82)
	return driver
