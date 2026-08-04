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
	game_manager.set("active_race_weekend", {
		"strategy_id":"balanced", "starting_position":2, "simulation_seed":404,
		"forecast":{"weather":"Dry", "temperature":25.0, "rain_chance":0}
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
	assert(live_race.pit_service_selector.item_count == 5)
	assert(not live_race.simulation.latest_engineer_advice.is_empty())
	assert(live_race.track_map.profile.get("venue_id", "") == "pine_ridge")
	var controls_card := live_race.get_node("Root/Main/PitWall/ControlsCard") as Control
	var engineer_card := live_race.get_node("Root/Main/RaceData/EngineerCard") as Control
	if controls_card.global_position.y + controls_card.size.y > 648.0 or engineer_card.global_position.y + engineer_card.size.y > 648.0:
		push_error("Live race panels overflow the 1152x648 viewport: controls pos %s size %s, engineer pos %s size %s" % [controls_card.global_position, controls_card.size, engineer_card.global_position, engineer_card.size])
		quit(1)
		return
	live_race.simulation._trigger_caution()
	await process_frame
	assert(live_race.caution_overlay.visible)
	assert(not live_race.caution_prediction_label.text.is_empty())
	live_race._stay_out_under_caution()
	assert(not live_race.caution_overlay.visible)
	viewport_host.queue_free()
	await process_frame

	var result_scene: Variant = (load("res://scenes/pages/race_results/race_results.tscn") as PackedScene).instantiate()
	var sample_result := RaceResult.new()
	sample_result.race = race
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
	result_scene.free()
	race_manager.set("last_result", null)
	game_manager.call("clear_selected_data")
	game_manager.set("team", null)
	print("Race operations UI tests passed")
	quit(0)
