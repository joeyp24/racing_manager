extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_new_car_programme_and_calendar_completion()
	_test_preparation_repairs_parts_and_parallel_capacity()
	await _test_workshop_and_backup_entry_interfaces()
	print("Fleet workshop progression tests passed")
	quit(0)


func _create_two_car_team() -> Dictionary:
	var team := Team.new()
	team.money = 100000
	var templates := SeriesCatalog.create_car_templates("local_short_track")
	assert(templates.size() >= 2)
	var primary := templates[0] as Car
	var rotation_car := templates[1] as Car
	primary.ensure_standard_parts()
	rotation_car.ensure_standard_parts()
	rotation_car.initialize_unprepared()
	team.cars[0] = primary
	team.cars[1] = rotation_car
	return {"team": team, "primary": primary, "rotation": rotation_car}


func _test_new_car_programme_and_calendar_completion() -> void:
	var fixture := _create_two_car_team()
	var team := fixture.team as Team
	var primary := fixture.primary as Car
	var rotation_car := fixture.rotation as Car
	assert(primary.is_initial_preparation_complete())
	assert(not rotation_car.is_initial_preparation_complete())
	assert(primary.is_race_available(team.current_season_day))
	assert(RaceReadiness.get_recommended_car(team, team.current_series_id) == primary)
	assert(team.get_fleet_weekly_upkeep() == Team.FLEET_WEEKLY_STORAGE_COST)
	assert(team.queue_initial_preparation(rotation_car))
	assert(rotation_car.workshop_jobs.size() == 3)
	var first_completion := int(rotation_car.workshop_jobs[0].completion_day)
	var final_completion := int(rotation_car.workshop_jobs[2].completion_day)
	assert(first_completion > team.current_season_day)
	assert(final_completion > first_completion)
	assert(primary.is_race_available(team.current_season_day))
	assert(not rotation_car.is_race_available(team.current_season_day))
	team.complete_workshop_jobs(final_completion - 1)
	assert(not rotation_car.is_initial_preparation_complete())
	team.complete_workshop_jobs(final_completion)
	assert(rotation_car.is_initial_preparation_complete())
	assert(rotation_car.workshop_jobs.is_empty())
	assert(rotation_car.is_race_available(final_completion))


func _test_preparation_repairs_parts_and_parallel_capacity() -> void:
	var fixture := _create_two_car_team()
	var team := fixture.team as Team
	var primary := fixture.primary as Car
	var rotation_car := fixture.rotation as Car
	assert(team.queue_initial_preparation(rotation_car))
	team.complete_workshop_jobs(rotation_car.get_latest_workshop_day())
	var race := Race.new()
	race.race_id = "fleet_test_100"
	race.race_name = "Fleet Test 100"
	race.series_id = "local_short_track"
	race.track_type = "Short Track"
	race.schedule_day = team.current_season_day + 30
	assert(rotation_car.get_preparation_score(race) < 100)
	assert(team.queue_workshop_job(rotation_car, "race_preparation", "", race))
	assert(not rotation_car.is_race_available(team.current_season_day))
	team.complete_workshop_jobs(rotation_car.get_latest_workshop_day())
	assert(rotation_car.get_preparation_score(race) == 100)
	assert(rotation_car.get_preparation_bonus(race) > 0.0)
	rotation_car.record_race_use(race, race.schedule_day)
	assert(rotation_car.get_preparation_score(race) < 100)

	rotation_car.damage_state["engine"] = 40.0
	assert(team.queue_workshop_job(rotation_car, "patch", "engine"))
	assert(not team.queue_workshop_job(rotation_car, "rebuild", "engine"))
	team.complete_workshop_jobs(rotation_car.get_latest_workshop_day())
	assert(rotation_car.get_component_health("engine") >= 72.0)
	assert(rotation_car.get_scrutineering_risk() > 0.0)

	var upgrade := PartCatalog.create_standard_part("Engine", 20)
	upgrade.part_name = "Fleet Test Engine"
	upgrade.tier = "Sport"
	team.parts_inventory.append(upgrade)
	assert(team.queue_part_install(rotation_car, upgrade))
	assert(not team.parts_inventory.has(upgrade))
	assert(rotation_car.get_part("Engine") != upgrade)
	team.complete_workshop_jobs(rotation_car.get_latest_workshop_day())
	assert(rotation_car.get_part("Engine") == upgrade)

	var mechanic := StaffMember.new()
	mechanic.staff_id = "fleet_test_mechanic"
	mechanic.role = "Mechanic"
	mechanic.hired = true
	team.staff.append(mechanic)
	assert(team.get_workshop_slot_count() == 2)
	assert(team.queue_workshop_job(primary, "routine_service"))
	assert(team.queue_workshop_job(rotation_car, "routine_service"))
	assert(int(primary.workshop_jobs[0].slot) != int(rotation_car.workshop_jobs[0].slot))
	assert(team.get_backup_transport_cost(race) > 0)


func _test_workshop_and_backup_entry_interfaces() -> void:
	var fixture := _create_two_car_team()
	var team := fixture.team as Team
	var primary := fixture.primary as Car
	var rotation_car := fixture.rotation as Car
	rotation_car.workshop_state = {}
	rotation_car.ensure_workshop_state(true)
	primary.damage_state["engine"] = 20.0
	team.driver_hired_for_season = true
	var driver := team.get_active_driver()
	assert(driver != null)
	if not team.contracted_driver_ids.has(driver.driver_id):
		team.contracted_driver_ids.append(driver.driver_id)
	var race_team := team.get_active_race_team()
	race_team.driver_id = driver.driver_id
	race_team.car_bay = 0
	race_team.backup_car_bay = 1

	var game_manager := root.get_node("GameManager")
	var race_manager := root.get_node("RaceManager")
	game_manager.team = team
	var calendar := race_manager.get_calendar_for_series(team.current_series_id) as Array
	assert(not calendar.is_empty())
	game_manager.selected_race = calendar[0] as Race
	game_manager.selected_car = primary

	var workshop_packed := load("res://scenes/pages/garage/fleet_workshop.tscn") as PackedScene
	var workshop_page := workshop_packed.instantiate() as Control
	root.add_child(workshop_page)
	await process_frame
	assert((workshop_page.get_node("%fleet_container") as VBoxContainer).get_child_count() == 2)
	assert("workshop slot" in (workshop_page.get_node("%calendar_label") as Label).text)
	workshop_page.queue_free()
	await process_frame

	var entry_packed := load("res://scenes/pages/race_entry/race_entry.tscn") as PackedScene
	var entry_page := entry_packed.instantiate() as Control
	root.add_child(entry_page)
	await process_frame
	var entries := entry_page.get_node("%cars_container") as VBoxContainer
	var option := entries.get_child(0).get_child(0) as CheckBox
	assert(not option.disabled)
	assert(option.button_pressed)
	assert(game_manager.selected_car == rotation_car)
	assert(int(entry_page.call("_get_total_entry_cost")) > team.get_effective_weekend_cost(game_manager.selected_race))
	entry_page.queue_free()
	await process_frame
