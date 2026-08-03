extends SceneTree


func _initialize() -> void:
	_test_legacy_progress_arrays_are_returned_with_declared_types()
	_test_first_season_race_plan_can_make_an_operating_profit()
	_test_driver_form_confidence_and_contract_pressure()
	_test_rival_development_and_scouting_intel()
	_test_owner_expectations_and_special_events_span_the_calendar()
	print("Finance and living paddock regression tests passed")
	quit(0)


func _test_legacy_progress_arrays_are_returned_with_declared_types() -> void:
	var team := Team.new()
	var progress := team.series_progress[team.current_series_id] as Dictionary
	var legacy_completed: Array = ["spring_100", "riverside_200"]
	var legacy_unlocked: Array = ["coastal_150"]
	progress["completed_races"] = legacy_completed
	progress["unlocked_races"] = legacy_unlocked
	var completed: Array[String] = team.get_completed_races()
	var unlocked: Array[String] = team.get_unlocked_races()
	assert(completed == ["spring_100", "riverside_200"])
	assert(unlocked == ["coastal_150"])


func _test_first_season_race_plan_can_make_an_operating_profit() -> void:
	var team := Team.new()
	team.career_difficulty = "Club"
	team.season_number = 1
	team.driver_hired_for_season = true
	team.active_sponsor_contract = {"payment_per_race":1100}
	var forecast := FinanceManager.build_forecast(team)
	assert(int(forecast.race_income) > int(forecast.race_cost))
	assert(int(forecast.projected_net) > 0)
	assert(bool(forecast.sustainable))
	assert(int(forecast.series_distribution) > 0)
	assert(int(forecast.owner_support) > 0)


func _test_driver_form_confidence_and_contract_pressure() -> void:
	var driver := Driver.new()
	driver.initialize_detailed_ratings(60, 60, 55, 80)
	driver.contract_races_remaining = 8
	var strong := driver.apply_race_dynamics({"finish":2, "status":"Finished", "incident":false}, 8)
	assert(driver.form > 50)
	assert(int(strong.confidence_change) > 0)
	var confidence_before := driver.confidence
	driver.contract_races_remaining = 2
	var setback := driver.apply_race_dynamics({"finish":18, "status":"Retired", "incident":true}, 8, "Hold position")
	assert(driver.confidence < confidence_before)
	assert(bool(setback.contract_uncertain))
	assert(driver.get_effective_consistency() <= driver.consistency + 10)


func _test_rival_development_and_scouting_intel() -> void:
	var team := Team.new()
	var state := CareerExpansionManager.ensure_state(team)
	team.current_season_day += 28
	var summaries := CareerExpansionManager.process_day(team, 28)
	assert(not (state.ai_development.reports as Array).is_empty())
	assert(summaries.any(func(summary: String) -> bool: return summary.begins_with("Rival development:")))
	var report := state.ai_development.reports[0] as Dictionary
	team.scouting_hours_remaining = 12
	team.scouting_hours_week = team.current_race_week
	assert(CareerExpansionManager.scout_ai_team_development(team, str(report.team_id)))
	assert(bool((state.ai_development.intel as Dictionary)[str(report.team_id)]))
	assert(bool(report.revealed))
	assert(not (state.news_feed as Array).is_empty())


func _test_owner_expectations_and_special_events_span_the_calendar() -> void:
	var team := Team.new()
	var state := CareerExpansionManager.ensure_state(team)
	assert((state.board.targets as Array).any(func(value: Variant) -> bool: return int((value as Dictionary).deadline_year) > team.current_season_year))
	team.cars[0] = Car.new()
	var selected := {}
	for event in CareerExpansionManager.get_special_events(team):
		if str(event.type) == "Endurance":
			selected = event
			break
	assert(not selected.is_empty())
	assert(CareerExpansionManager.enter_special_event(team, str(selected.id)))
	var money_after_entry := team.money
	var elapsed := int(selected.day) - team.current_season_day
	team.current_season_day = int(selected.day)
	CareerExpansionManager.process_day(team, elapsed)
	assert(str(selected.status) == "Completed")
	assert(int(selected.payout) > 0)
	assert(team.money > money_after_entry - 50000)
