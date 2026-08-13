extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	var race_manager := root.get_node("RaceManager")
	var team := Team.new()
	team.money = 100000
	team.driver_hired_for_season = true
	var templates := SeriesCatalog.create_car_templates(team.current_series_id)
	assert(templates.size() == 3)
	var short_car := templates[0] as Car
	var speedway_car := templates[1] as Car
	var balanced_car := templates[2] as Car
	for car in [short_car, speedway_car, balanced_car]:
		car.ensure_standard_parts()
	assert(short_car.specialization_id == "short_track")
	assert(speedway_car.specialization_id == "speedway")
	assert(balanced_car.specialization_id == "balanced")
	assert(short_car.chassis_trait_id != speedway_car.chassis_trait_id)
	assert(not short_car.get_identity_summary().is_empty())

	var short_race := _make_race("specialization_short", "Short Track", team.current_season_day + 24)
	var speedway_race := _make_race("specialization_speedway", "Speedway", team.current_season_day + 38)
	assert(short_car.get_track_specialization_bonus(short_race) > speedway_car.get_track_specialization_bonus(short_race))
	assert(speedway_car.get_track_specialization_bonus(speedway_race) > short_car.get_track_specialization_bonus(speedway_race))
	assert(short_car.get_wear_multiplier(short_race) < 1.0)

	var first_quote := team.get_workshop_job_quote(short_car, "race_preparation", "", short_race)
	assert(int(first_quote.duration) == 7)
	short_car.apply_workshop_job(first_quote, team.current_season_day + 7)
	assert(short_car.get_preparation_score(short_race) == 100)
	assert(short_car.has_saved_setup("Short Track"))
	var repeat_quote := team.get_workshop_job_quote(short_car, "race_preparation", "", _make_race("repeat_short", "Short Track", team.current_season_day + 50))
	assert(int(repeat_quote.duration) == 4)

	team.cars[0] = short_car
	team.cars[1] = speedway_car
	team.cars[2] = balanced_car
	var driver := team.get_active_driver()
	assert(driver != null)
	if not team.contracted_driver_ids.has(driver.driver_id):
		team.contracted_driver_ids.append(driver.driver_id)
	var race_team := team.get_active_race_team()
	_setup_race_team(race_team, driver)
	assert(team.assign_car_to_race(short_race, race_team, 0))
	assert(team.get_race_car_assignment(short_race.race_id, race_team.team_id) == 0)
	var recommended := team.get_recommended_car_for_race(short_race, race_team)
	assert(recommended == short_car)

	team.current_season_day = short_race.schedule_day - 4
	var money_before_change := team.money
	var late_quote := team.get_assignment_change_quote(short_race, race_team, 1)
	assert(bool(late_quote.late_change))
	assert(int(late_quote.cost) > 0)
	assert(bool(late_quote.loses_completed_setup))
	assert(team.assign_car_to_race(short_race, race_team, 1))
	assert(team.money == money_before_change - int(late_quote.cost))
	assert(short_car.get_preparation_score(short_race) < 100)

	short_car.record_race_use(short_race, short_race.schedule_day, driver.driver_id)
	assert(short_car.get_driver_familiarity_starts(driver.driver_id) == 1)
	assert(short_car.get_driver_familiarity_bonus(driver.driver_id) > 0.0)

	game_manager.team = team
	game_manager.selected_race = short_race
	race_manager.random_number_generator.seed = 4242
	short_car.specialization_id = "short_track"
	var specialist_score: float = race_manager.calculate_player_score(short_car, driver, "balanced", short_race)
	race_manager.random_number_generator.seed = 4242
	short_car.specialization_id = "speedway"
	var mismatched_score: float = race_manager.calculate_player_score(short_car, driver, "balanced", short_race)
	assert(specialist_score > mismatched_score)
	short_car.specialization_id = "short_track"

	team.current_season_day = CalendarCatalog.SEASON_START_DAY
	team.fleet_race_assignments.clear()
	var calendar := race_manager.get_calendar_for_series(team.current_series_id) as Array[Race]
	assert(not calendar.is_empty())
	var next_race := calendar[0] as Race
	game_manager.selected_race = next_race
	assert(team.assign_car_to_race(next_race, race_team, 1))

	var host := Control.new()
	host.size = Vector2(1152.0, 648.0)
	root.add_child(host)
	var planner := (load("res://scenes/pages/garage/fleet_planner.tscn") as PackedScene).instantiate() as Control
	host.add_child(planner)
	await process_frame
	await process_frame
	assert((planner.get_node("%team_selector") as OptionButton).item_count >= 1)
	assert((planner.get_node("%event_container") as VBoxContainer).get_child_count() == 5)
	assert((planner.get_node("%plan_value") as Label).text.begins_with("1 /"))
	var planner_text := _collect_text(planner)
	assert("RECOMMENDED" in planner_text)
	assert("PACE" in planner_text)
	assert("DRIVER/CAR STARTS" in planner_text)
	planner.queue_free()
	await process_frame

	var entry := (load("res://scenes/pages/race_entry/race_entry.tscn") as PackedScene).instantiate() as Control
	host.add_child(entry)
	await process_frame
	await process_frame
	assert(int(entry.call("_get_planned_primary_bay", race_team)) == 1)
	assert(game_manager.selected_car == speedway_car)
	entry.queue_free()
	await process_frame

	var garage := (load("res://scenes/pages/garage/garage.tscn") as PackedScene).instantiate() as Control
	host.add_child(garage)
	await process_frame
	await process_frame
	assert(garage.get_node("%planner_button") as Button != null)
	var first_bay := (garage.get_node("%garage_content") as GridContainer).get_child(0)
	assert("SPECIALIST" in (first_bay.get_node("%car_identity_label") as Label).text.to_upper())

	host.queue_free()
	await process_frame
	game_manager.team = null
	game_manager.selected_race = null
	print("Car specialization and assignment planning tests passed")
	quit(0)


func _make_race(race_id: String, track_type: String, schedule_day: int) -> Race:
	var race := Race.new()
	race.race_id = race_id
	race.race_name = race_id.replace("_", " ").capitalize()
	race.series_id = "local_short_track"
	race.track_type = track_type
	race.schedule_day = schedule_day
	race.preparation_cost = 400
	return race


func _setup_race_team(race_team: RaceTeam, driver: Driver) -> void:
	race_team.driver_id = driver.driver_id
	race_team.car_bay = 0
	race_team.backup_car_bay = 2


func _collect_text(node: Node) -> String:
	var pieces: Array[String] = []
	if node is Label:
		pieces.append((node as Label).text)
	elif node is Button:
		pieces.append((node as Button).text)
	for child in node.get_children():
		pieces.append(_collect_text(child))
	return "\n".join(pieces)
