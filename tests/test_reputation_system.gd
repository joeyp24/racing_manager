extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legacy_xp_migration_preserves_progress()
	_test_progressive_levels_get_longer()
	_test_race_rewards_compare_results_with_expectations()
	_test_series_importance_and_retirements_affect_standing()
	_test_driver_reputation_is_negotiation_leverage()
	_test_reputation_drives_weekly_merchandise_sales()
	await _test_reputation_screen_renders()
	print("Reputation system tests passed")
	quit(0)


func _test_legacy_xp_migration_preserves_progress() -> void:
	var team := Team.new()
	team.reputation = 350
	team.reputation_state = {}
	ReputationManager.migrate_legacy_xp(team)
	assert(team.get_reputation_level() == 4)
	assert(team.get_current_level_xp() == 80)
	assert(team.get_reputation_tier() == "Local Name")


func _test_progressive_levels_get_longer() -> void:
	assert(ReputationManager.get_level_span(1) == 100)
	assert(ReputationManager.get_level_span(4) == 160)
	assert(ReputationManager.get_level_span(18) > ReputationManager.get_level_span(4))


func _test_race_rewards_compare_results_with_expectations() -> void:
	var overperforming_team := Team.new()
	var underperforming_team := Team.new()
	var overperformance := _make_result("local_short_track", 8, 18, "Finished")
	var underperformance := _make_result("local_short_track", 8, 4, "Finished")
	ReputationManager.apply_race_result(overperforming_team, overperformance)
	ReputationManager.apply_race_result(underperforming_team, underperformance)
	assert(
		int(overperformance.reputation_changes.sporting_credibility)
		> int(underperformance.reputation_changes.sporting_credibility)
	)
	assert(overperformance.reputation_earned > underperformance.reputation_earned)
	assert(
		str(overperformance.reputation_changes.reason)
		== "Finished P8 against a P18 expectation at Reputation Test"
	)


func _test_series_importance_and_retirements_affect_standing() -> void:
	var local_team := Team.new()
	var premier_team := Team.new()
	var local_result := _make_result("local_short_track", 5, 10, "Finished")
	var premier_result := _make_result("premier_cup", 5, 10, "Finished")
	ReputationManager.apply_race_result(local_team, local_result)
	ReputationManager.apply_race_result(premier_team, premier_result)
	assert(premier_result.reputation_earned > local_result.reputation_earned)

	var retirement_team := Team.new()
	var professionalism_before := ReputationManager.get_dimension(
		retirement_team,
		"professionalism"
	)
	var retirement := _make_result("local_short_track", 12, 10, "Retired")
	ReputationManager.apply_race_result(retirement_team, retirement)
	assert(
		ReputationManager.get_dimension(retirement_team, "professionalism")
		== professionalism_before - 3
	)


func _test_driver_reputation_is_negotiation_leverage() -> void:
	var team := Team.new()
	var driver := Driver.new()
	driver.driver_id = "elite_prospect"
	driver.series_id = "premier_cup"
	driver.salary = 1000
	driver.signing_fee = 5000
	driver.initialize_detailed_ratings(88, 88, 86, 90)
	team.recruiting_progress[driver.driver_id] = 50
	assert(team.can_negotiate_with_driver(driver))
	var terms := team.get_driver_negotiation_terms(driver)
	assert(int(terms.level_gap) > 0)
	assert(float(terms.salary_multiplier) > 1.0)
	var response := team.negotiate_driver_contract(driver, 1, 1, 12)
	assert(not bool(response.accepted))
	assert(int(team.contract_offers[driver.driver_id].counter_salary) > driver.salary)
	var counter := team.contract_offers[driver.driver_id] as Dictionary
	response = team.negotiate_driver_contract(
		driver,
		int(counter.counter_salary),
		int(counter.counter_signing_fee),
		12
	)
	assert(bool(response.accepted))


func _test_reputation_drives_weekly_merchandise_sales() -> void:
	var low_standing_team := Team.new()
	var high_standing_team := Team.new()
	CareerExpansionManager.ensure_state(low_standing_team)
	CareerExpansionManager.ensure_state(high_standing_team)
	high_standing_team.reputation = ReputationManager.get_level_start_xp(15)
	high_standing_team.fans = 2000
	var high_state := ReputationManager.ensure_state(high_standing_team)
	high_state.commercial_appeal = 85
	high_state.momentum = 25
	assert(
		CareerExpansionManager.calculate_weekly_merchandise_demand(high_standing_team)
		> CareerExpansionManager.calculate_weekly_merchandise_demand(low_standing_team)
	)

	var merchandise := high_standing_team.career_state.merchandise as Dictionary
	merchandise.stock = 1000
	merchandise.last_sales_day = high_standing_team.current_season_day
	var starting_money := high_standing_team.money
	high_standing_team.current_season_day += 7
	var summaries := CareerExpansionManager.process_day(high_standing_team, 7)
	assert(int(merchandise.last_weekly_units) > 0)
	assert(int(merchandise.last_weekly_revenue) > 0)
	assert(high_standing_team.money > starting_money)
	assert(not summaries.is_empty())
	merchandise.last_sales_day = 300
	high_standing_team.current_season_day = CalendarCatalog.SEASON_START_DAY
	CareerExpansionManager.start_new_season(high_standing_team)
	assert(int(merchandise.last_sales_day) == CalendarCatalog.SEASON_START_DAY)


func _test_reputation_screen_renders() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.reputation = ReputationManager.get_level_start_xp(6)
	CareerExpansionManager.ensure_state(game_manager.team)
	var packed := load("res://scenes/pages/reputation/reputation.tscn") as PackedScene
	assert(packed != null)
	var page := packed.instantiate() as Control
	root.add_child(page)
	await process_frame
	var tier_label := page.get_node("%tier_label") as Label
	var merchandise_label := page.get_node("%merchandise_label") as Label
	var trend := page.get_node("%season_trend") as Control
	assert("REGIONAL CONTENDER" in tier_label.text)
	assert("Projected weekly demand" in merchandise_label.text)
	assert(trend != null)
	page.queue_free()
	await process_frame


func _make_result(
	series_id: String,
	finishing_position: int,
	expected_position: int,
	status: String
) -> RaceResult:
	var race := Race.new()
	race.race_name = "Reputation Test"
	race.series_id = series_id
	var result := RaceResult.new()
	result.race = race
	result.finishing_position = finishing_position
	result.expected_finishing_position = expected_position
	result.starting_position = expected_position
	result.field_size = 20
	result.fans_earned = 30
	for position in finishing_position:
		result.standings.append({
			"driver_name": "Driver %d" % (position + 1),
			"status": status if position == finishing_position - 1 else "Finished"
		})
	return result
