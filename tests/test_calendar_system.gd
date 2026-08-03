extends SceneTree


func _initialize() -> void:
	_test_player_progression_survives_load_and_reaches_third_race()
	_test_world_series_only_simulate_events_due_by_date()
	print("Calendar system regression tests passed")
	quit(0)


func _test_player_progression_survives_load_and_reaches_third_race() -> void:
	var team := Team.new()
	var calendar := RaceManager.get_calendar_for_series(team.current_series_id)
	assert(calendar.size() >= 3)
	team.complete_race_for_series(team.current_series_id, calendar[0].race_id)
	team.complete_race_for_series(team.current_series_id, calendar[1].race_id)
	team.current_season_day = calendar[1].schedule_day
	team.week_advance_required = true
	team.save_format_version = 13
	var progress := team.series_progress[team.current_series_id] as Dictionary
	progress["unlocked_races"] = [calendar[0].race_id, calendar[1].race_id]
	SaveManager._repair_and_migrate(team)
	GameManager.team = team
	var next_race := RaceManager.get_next_race(team)
	assert(next_race != null)
	assert(next_race.race_id == calendar[2].race_id)
	var advance := RaceManager.advance_to_date(next_race.schedule_day)
	assert(int(advance.days_advanced) > 0)
	assert(team.current_season_day == calendar[2].schedule_day)
	assert(not team.week_advance_required)


func _test_world_series_only_simulate_events_due_by_date() -> void:
	var team := Team.new()
	GameManager.team = team
	var player_calendar := RaceManager.get_calendar_for_series(team.current_series_id)
	var first_day := player_calendar[0].schedule_day
	var second_day := player_calendar[1].schedule_day
	RaceManager.simulate_other_series_through_date(first_day)
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		if series_id == team.current_series_id:
			continue
		var completed: Array = team.get_world_series_data(series_id).get("completed_race_ids", [])
		assert(completed.size() == _events_due_by(series_id, first_day))
		assert(completed.size() < int(series.season_length))
	var counts_after_first := {}
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		if series_id != team.current_series_id:
			counts_after_first[series_id] = (team.get_world_series_data(series_id).get("completed_race_ids", []) as Array).size()
	RaceManager.simulate_other_series_through_date(first_day)
	for series_id in counts_after_first:
		assert((team.get_world_series_data(series_id).get("completed_race_ids", []) as Array).size() == int(counts_after_first[series_id]))
	RaceManager.simulate_other_series_through_date(second_day)
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		if series_id != team.current_series_id:
			assert((team.get_world_series_data(series_id).get("completed_race_ids", []) as Array).size() == _events_due_by(series_id, second_day))


func _events_due_by(series_id: String, target_day: int) -> int:
	var count := 0
	for event in CalendarCatalog.get_events(series_id):
		if int(event.schedule_day) <= target_day:
			count += 1
	return count
