extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	var team := Team.new()
	team.money = 100000
	var templates := SeriesCatalog.create_car_templates(team.current_series_id)
	assert(templates.size() >= 3)
	var ready_car := templates[0] as Car
	var workshop_car := templates[1] as Car
	var unprepared_car := templates[2] as Car
	for car in [ready_car, workshop_car, unprepared_car]:
		car.ensure_standard_parts()
	unprepared_car.initialize_unprepared()
	workshop_car.condition = 64
	team.cars[0] = ready_car
	team.cars[1] = workshop_car
	team.cars[2] = unprepared_car
	team.get_active_race_team().car_bay = 0
	team.get_active_race_team().backup_car_bay = 2
	assert(team.queue_workshop_job(workshop_car, "routine_service"))
	game_manager.team = team

	var host := Control.new()
	host.size = Vector2(1152.0, 648.0)
	root.add_child(host)
	var garage := (load("res://scenes/pages/garage/garage.tscn") as PackedScene).instantiate() as Control
	host.add_child(garage)
	await process_frame
	await process_frame

	assert((garage.get_node("%owned_value") as Label).text == "3 / 6")
	assert((garage.get_node("%available_value") as Label).text == "1")
	assert((garage.get_node("%workshop_value") as Label).text == "1")
	assert("weekly" in (garage.get_node("%upkeep_context") as Label).text.to_lower())
	assert("NEXT EVENT" in (garage.get_node("%next_event_label") as Label).text)
	var grid := garage.get_node("%garage_content") as GridContainer
	assert(grid.columns == 2)
	assert(grid.get_child_count() == Team.GARAGE_SIZE)
	var ready_bay := grid.get_child(0)
	var workshop_bay := grid.get_child(1)
	var unprepared_bay := grid.get_child(2)
	var empty_bay := grid.get_child(3)
	assert((ready_bay.get_node("%status_label") as Label).text == "RACE READY")
	assert("PRIMARY" in (ready_bay.get_node("%assignment_label") as Label).text)
	assert((workshop_bay.get_node("%status_label") as Label).text == "IN WORKSHOP")
	assert("ready" in (workshop_bay.get_node("%workshop_label") as Label).text.to_lower())
	assert((unprepared_bay.get_node("%status_label") as Label).text == "PREP REQUIRED")
	assert("BACKUP" in (unprepared_bay.get_node("%assignment_label") as Label).text)
	assert((empty_bay.get_node("%empty_content") as VBoxContainer).visible)
	assert((empty_bay.get_node("%empty_action_button") as Button).text == "SHOP FOR A CAR  →")
	assert((ready_bay.get_node("%action_button") as Button).text == "INSPECT & MANAGE  →")
	assert(ready_bay.global_position.x + ready_bay.size.x <= 1152.0)
	assert(workshop_bay.global_position.x + workshop_bay.size.x <= 1152.0)

	host.size = Vector2(760.0, 648.0)
	await process_frame
	await process_frame
	assert(grid.columns == 1)
	assert(garage.get_node("%dealership_button") as Button != null)
	assert(garage.get_node("%workshop_button") as Button != null)

	host.queue_free()
	await process_frame
	game_manager.team = null
	print("Garage overview interaction and layout tests passed")
	quit(0)
