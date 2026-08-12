extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	var previous_team: Team = game_manager.team
	var team := _build_four_entry_team()
	game_manager.team = team
	SponsorManager.ensure_state(team)

	var packed := load("res://scenes/pages/race_teams/race_teams.tscn") as PackedScene
	var page := packed.instantiate() as Control
	root.add_child(page)
	await process_frame
	page.call("show_operations")
	await process_frame

	var content := page.get_node("%Content") as HSplitContainer
	var operations_scroll := page.get_node("%OperationsScroll") as ScrollContainer
	var operations_board := page.get_node("%OperationsBoard") as VBoxContainer
	assert(not content.visible)
	assert(operations_scroll.visible)
	var grid := operations_board.get_node("OperationsGrid") as GridContainer
	assert(grid.columns == 2)
	assert(grid.get_child_count() == 4)
	assert(operations_scroll.size.y <= page.size.y)

	var second_card := grid.get_node("TeamCard_team_2") as PanelContainer
	var driver_select := second_card.find_child("DriverSelect_team_2", true, false) as OptionButton
	assert(driver_select != null)
	var first_driver_index := _find_option(driver_select, team.race_teams[0].driver_id)
	assert(first_driver_index > 0)
	assert(driver_select.is_item_disabled(first_driver_index))
	assert("Assigned to Team 1" in driver_select.get_item_text(first_driver_index))

	var third_card := grid.get_node("TeamCard_team_3") as PanelContainer
	var readiness := third_card.find_child("Readiness_team_3", true, false) as Label
	assert(readiness != null)
	assert("DRIVER" in readiness.text and "CAR" in readiness.text)
	assert(team.race_teams[0].sponsor_offers.size() == 6)
	assert(team.race_teams[1].sponsor_offers.size() == 6)
	assert(str(team.race_teams[0].sponsor_offers[0].sponsor_name) != str(team.race_teams[1].sponsor_offers[0].sponsor_name))

	page.call("_show_expansion_comparison")
	await process_frame
	var drawer := page.get_node("%DecisionComparisonDrawer") as DecisionComparisonDrawer
	assert(drawer.visible)
	assert(drawer.primary_button.disabled)
	assert("maximum" in drawer.primary_button.tooltip_text.to_lower())

	page.free()
	game_manager.team = previous_team
	print("Multi-team operations center tests passed")
	quit(0)


func _build_four_entry_team() -> Team:
	var team := Team.new()
	team.money = 250000
	team.ensure_race_teams()
	team.race_teams[0].team_name = "Team 1"
	var first_driver := team.get_active_driver()
	team.race_teams[0].driver_id = first_driver.driver_id
	var second_driver := Driver.new()
	second_driver.driver_id = "operations_driver_2"
	second_driver.driver_name = "Second Driver"
	team.drivers.append(second_driver)
	team.contracted_driver_ids.append(second_driver.driver_id)
	team.cars[0] = Car.new()
	team.cars[0].name = "Car One"
	team.cars[1] = Car.new()
	team.cars[1].name = "Car Two"
	team.race_teams[0].car_bay = 0

	for index in range(1, 4):
		var race_team := RaceTeam.new()
		race_team.team_id = "team_%d" % (index + 1)
		race_team.team_name = "Team %d" % (index + 1)
		team.race_teams.append(race_team)
	team.race_teams[1].driver_id = second_driver.driver_id
	team.race_teams[1].car_bay = 1

	var first_chief := StaffMember.new()
	first_chief.staff_id = "operations_chief_1"
	first_chief.staff_name = "Chief One"
	first_chief.role = "Crew Chief"
	first_chief.hired = true
	team.staff.append(first_chief)
	team.assign_staff_to_race_team(first_chief, team.race_teams[0])
	return team


func _find_option(select: OptionButton, metadata: Variant) -> int:
	for index in select.item_count:
		if select.get_item_metadata(index) == metadata:
			return index
	return -1
