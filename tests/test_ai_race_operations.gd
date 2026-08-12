extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_crew_chiefs_manage_every_player_entry()
	await _test_race_flow_progress_states()
	print("AI race operations tests passed")
	quit(0)


func _test_crew_chiefs_manage_every_player_entry() -> void:
	var race := Race.new()
	race.race_id = "automated_multi_team"
	race.race_name = "Automated Multi-Team Test"
	race.series_id = "local_short_track"
	race.lap_count = 12
	race.fuel_consumption_factor = 1.0
	race.tyre_wear_factor = 1.0
	race.accident_factor = 0.0
	race.mechanical_stress = 0.0
	var primary := _driver("primary", "Primary Driver", 68)
	var simulation := RaceSimulation.new()
	var rivals: Array[Dictionary] = [
		{"driver_id":"rival", "driver_name":"Rival Driver", "team_name":"Rival Team", "consistency":60, "aggression":55, "strategy_rating":60},
	]
	var rival_scores: Array[float] = [61.0]
	var additional: Array = [{
		"driver_id":"second",
		"driver_name":"Second Driver",
		"team_id":"team_two",
		"team_name":"Team Two",
		"consistency":64,
		"aggression":62,
		"strategy_skill":72.0,
		"attributes":_driver("second", "Second Driver", 66).get_attribute_dictionary(),
		"score":65.0,
		"starting_position":3,
	}]
	simulation.setup(
		race,
		primary,
		"Team One",
		67.0,
		1,
		rivals,
		rival_scores,
		"Standard",
		additional,
		404,
		{"strategy_skill":74.0, "fuel":62.0, "tyres":64.0, "team_id":"team_one"}
	)
	simulation.set_crew_chief_automation(true)
	var player_entries := simulation.get_player_entries()
	assert(player_entries.size() == 2)
	assert(simulation.crew_chief_calls.size() == 2)
	for entry in player_entries:
		entry.tyre_condition = 12.0
		entry.fuel_laps = 0.5
	simulation.simulate_lap()
	for entry in player_entries:
		assert(entry.pit_stops == 1, "%s did not receive an automated pit call" % entry.driver_name)
		assert(entry.tyre_condition > 90.0)
		assert(entry.fuel_laps > 0.5)
	var boxed_drivers: Array[String] = []
	for call in simulation.crew_chief_calls:
		if str(call.get("title", "")) == "Box this lap":
			boxed_drivers.append(str(call.get("driver_id", "")))
	assert(boxed_drivers.has("primary"))
	assert(boxed_drivers.has("second"))
	assert(simulation.strategy_timeline.any(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "crew_call"))


func _test_race_flow_progress_states() -> void:
	var packed := load("res://ui/components/race_flow_progress.tscn") as PackedScene
	var progress := packed.instantiate() as RaceFlowProgress
	root.add_child(progress)
	await process_frame
	progress.set_stage(3, "AI crew control active")
	assert("✓" in progress.stage_labels[0].text)
	assert("●" in progress.stage_labels[3].text)
	assert("○" in progress.stage_labels[4].text)
	assert(progress.context_label.text == "AI crew control active")
	progress.free()


func _driver(id: String, display_name: String, rating: int) -> Driver:
	var driver := Driver.new()
	driver.driver_id = id
	driver.driver_name = display_name
	driver.initialize_detailed_ratings(rating, rating, rating, 82)
	return driver
