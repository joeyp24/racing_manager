extends SceneTree


func _initialize() -> void:
	var game_manager := get_root().get_node("GameManager")
	var race_manager := get_root().get_node("RaceManager")
	var team := Team.new()
	team.team_name = "UI Test Team"
	team.driver_hired_for_season = true
	var car := Car.new()
	car.name = "Operations Test Car"
	car.ensure_standard_parts()
	team.cars[0] = car
	var driver := team.get_active_driver()
	assert(driver != null)
	driver.team_name = team.team_name
	team.get_active_race_team().car_bay = 0
	var second_driver := Driver.new()
	second_driver.driver_id = "operations_second_driver"
	second_driver.driver_name = "Second Operations Driver"
	second_driver.series_id = team.current_series_id
	second_driver.initialize_detailed_ratings(64, 66, 62, 80)
	team.drivers.append(second_driver)
	team.contracted_driver_ids.append(second_driver.driver_id)
	var second_car := Car.new()
	second_car.name = "Second Operations Car"
	second_car.series_id = team.current_series_id
	second_car.ensure_standard_parts()
	team.cars[1] = second_car
	game_manager.set("team", team)
	game_manager.set("selected_car", car)
	var race := Race.new()
	race.race_id = "operations_ui"
	race.race_name = "Operations UI Test"
	race.track_name = "Pine Ridge Raceway"
	race.track_type = "Short Track"
	race.lap_count = 20
	race.accident_factor = 0.0
	race.mechanical_stress = 0.0
	game_manager.set("selected_race", race)
	var readiness := RaceReadiness.evaluate(team, race, car)
	assert(RaceReadiness.get_overall_status(readiness) != RaceReadiness.BLOCKED)
	assert(str(readiness[2].title) == "ROOKIE RACE CREW")
	var entry_host := Control.new()
	entry_host.size = Vector2(1152.0, 648.0)
	get_root().add_child(entry_host)
	var race_entry: Variant = (load("res://scenes/pages/race_entry/race_entry.tscn") as PackedScene).instantiate()
	entry_host.add_child(race_entry)
	await process_frame
	await process_frame
	assert(not race_entry.confirm_button.disabled)
	assert("VOLUNTEER CREW" in race_entry.crew_label.text)
	entry_host.queue_free()
	await process_frame
	team.complete_race_for_series(team.current_series_id, race.race_id)
	var post_opening_readiness := RaceReadiness.evaluate(team, race, car)
	assert(RaceReadiness.get_overall_status(post_opening_readiness) == RaceReadiness.BLOCKED)
	assert(str(post_opening_readiness[2].title) == "RACE CREW")
	game_manager.set("active_race_weekend", {
		"strategy_id":"balanced", "starting_position":2, "simulation_seed":404,
		"uses_volunteer_crew":true,
		"forecast":{"weather":"Dry", "temperature":25.0, "rain_chance":0},
		"entries":[
			{"team_id":"team_one", "team_name":"Operations Team One", "driver_id":driver.driver_id, "car_bay":0},
			{"team_id":"team_two", "team_name":"Operations Team Two", "driver_id":second_driver.driver_id, "car_bay":1},
		]
	})
	var packed := load("res://scenes/pages/live_race/live_race.tscn") as PackedScene
	var live_race: Variant = packed.instantiate()
	var viewport_host := Control.new()
	viewport_host.size = Vector2(1152.0, 648.0)
	get_root().add_child(viewport_host)
	viewport_host.add_child(live_race)
	await process_frame
	await process_frame
	assert(live_race.simulation != null)
	assert(live_race.simulation.automated_player_crew)
	assert(live_race.simulation.crew_controller_label == "Volunteer crew")
	assert(live_race.simulation.get_player_entries().size() == 2)
	assert(live_race.simulation.crew_chief_calls.size() == 2)
	assert(driver.driver_name in live_race.team_summary.text)
	assert("Second Operations Driver" in live_race.team_summary.text)
	assert(live_race.get_node_or_null("%pace_selector") == null)
	assert(live_race.get_node_or_null("%pit_service_selector") == null)
	assert(live_race.get_node_or_null("%caution_overlay") == null)
	assert(not live_race.simulation.latest_engineer_advice.is_empty())
	assert(live_race.track_map.profile.get("venue_id", "") == "pine_ridge")
	var tower_card := live_race.get_node("Margin/Root/Main/TimingColumn/TowerCard") as Control
	var broadcast_scroll := live_race.get_node("Margin/Root/Main/BroadcastScroll") as Control
	if tower_card.size.y < 250.0 or tower_card.global_position.y + tower_card.size.y > 648.0 or broadcast_scroll.global_position.y + broadcast_scroll.size.y > 648.0:
		push_error("Live broadcast does not fit the 1152x648 viewport: tower pos %s size %s, broadcast pos %s size %s" % [tower_card.global_position, tower_card.size, broadcast_scroll.global_position, broadcast_scroll.size])
		quit(1)
		return
	assert(live_race.timing_tower.size.y >= 240.0)
	assert("LIVE STANDINGS" in str((tower_card.get_node("Tower/TitleRow/Title") as Label).text))
	live_race.simulation._trigger_caution()
	await process_frame
	assert("Volunteer crew" in live_race.message_label.text)
	for entry in live_race.simulation.get_player_entries():
		entry.tyre_condition = 10.0
		entry.fuel_laps = 0.5
	live_race._advance_one_lap()
	for entry in live_race.simulation.get_player_entries():
		assert(entry.pit_stops == 1)
	viewport_host.queue_free()
	await process_frame

	var result_scene: Variant = (load("res://scenes/pages/race_results/race_results.tscn") as PackedScene).instantiate()
	var sample_result := RaceResult.new()
	sample_result.race = race
	sample_result.player_car = car
	sample_result.player_driver = driver
	sample_result.finishing_position = 2
	sample_result.starting_position = 4
	sample_result.positions_gained = 2
	sample_result.driver_personality = "analyst"
	sample_result.driver_reaction = "The crew made the race easy to execute."
	sample_result.standings = [
		{"driver_name":"Rival Driver", "team_name":"Rival Team", "is_player":false},
		{"driver_name":driver.driver_name, "team_name":"Operations Team One", "is_player":true, "overtakes":3, "pit_stops":1, "mechanical_health":92.0},
		{"driver_name":second_driver.driver_name, "team_name":"Operations Team Two", "is_player":true, "overtakes":1, "pit_stops":1, "mechanical_health":88.0},
	]
	sample_result.scheduled_laps = 20
	sample_result.completed_laps = 22
	sample_result.overtime_attempts = 1
	sample_result.strategy_timeline = [{"lap":0,"type":"plan","title":"Plan","detail":"Stop on lap 10"},{"lap":9,"type":"stop","title":"Stop","detail":"Four tyres + fuel"}]
	sample_result.decisive_moments = [{"lap":15,"type":"pass","title":"Pass","detail":"Pass for P2"}]
	sample_result.component_degradation = {"engine":{"start":100.0,"finish":86.0,"loss":14.0}}
	sample_result.counterfactuals = ["Clear air could have changed the finish."]
	var analysis := str(result_scene.create_post_race_analysis_text(sample_result))
	assert("PLANNED VS ACTUAL" in analysis)
	assert("COMPONENT DEGRADATION" in analysis)
	assert("WHAT COULD HAVE CHANGED" in analysis)
	race_manager.set("last_result", sample_result)
	var debrief_host := Control.new()
	debrief_host.size = Vector2(1152.0, 648.0)
	get_root().add_child(debrief_host)
	debrief_host.add_child(result_scene)
	await process_frame
	await process_frame
	assert((result_scene.race_flow as RaceFlowProgress).current_stage == 4)
	assert("Second Operations Driver" in result_scene.standings_label.text)
	assert(not result_scene.details_container.visible)
	result_scene.details_toggle.button_pressed = true
	assert(result_scene.details_container.visible)
	var actions := result_scene.get_node("Margin/results_container/Actions") as Control
	if actions.global_position.y + actions.size.y > 648.0:
		push_error("Race debrief actions overflow the 1152x648 viewport")
		quit(1)
		return
	debrief_host.queue_free()
	await process_frame
	race_manager.set("last_result", null)
	game_manager.call("clear_selected_data")
	game_manager.set("team", null)
	print("Race operations UI tests passed")
	quit(0)
