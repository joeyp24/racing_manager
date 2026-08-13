extends SceneTree

var race_manager: Node
var game_manager: Node
var save_manager: Script


func _initialize() -> void:
	race_manager = get_root().get_node("RaceManager")
	game_manager = get_root().get_node("GameManager")
	save_manager = load("res://scripts/save_manager.gd") as Script
	_test_player_progression_survives_load_and_reaches_third_race()
	_test_world_series_only_simulate_events_due_by_date()
	print("Calendar system regression tests passed")
	quit(0)


func _test_player_progression_survives_load_and_reaches_third_race() -> void:
	var team := Team.new()
	var calendar := race_manager.call("get_calendar_for_series", team.current_series_id) as Array
	assert(calendar.size() >= 3)
	team.complete_race_for_series(team.current_series_id, calendar[0].race_id)
	team.complete_race_for_series(team.current_series_id, calendar[1].race_id)
	team.current_season_day = calendar[1].schedule_day
	team.week_advance_required = true
	team.save_format_version = 13
	var legacy_car := SeriesCatalog.create_car_templates(team.current_series_id)[0] as Car
	legacy_car.ensure_standard_parts()
	legacy_car.workshop_state = {}
	team.cars[0] = legacy_car
	var progress := team.series_progress[team.current_series_id] as Dictionary
	progress["unlocked_races"] = [calendar[0].race_id, calendar[1].race_id]
	save_manager.call("_repair_and_migrate", team)
	assert(legacy_car.is_initial_preparation_complete())
	assert(team.save_format_version == Team.CURRENT_SAVE_FORMAT_VERSION)
	game_manager.set("team", team)
	var next_race := race_manager.call("get_next_race", team) as Race
	assert(next_race != null)
	assert(next_race.race_id == calendar[2].race_id)
	var advance := race_manager.call("advance_to_date", next_race.schedule_day) as Dictionary
	assert(int(advance.days_advanced) > 0)
	assert(team.current_season_day == calendar[2].schedule_day)
	assert(not team.week_advance_required)


func _test_world_series_only_simulate_events_due_by_date() -> void:
	var team := Team.new()
	game_manager.set("team", team)
	var player_calendar := race_manager.call("get_calendar_for_series", team.current_series_id) as Array
	var first_day: int = int(player_calendar[0].schedule_day)
	var second_day: int = int(player_calendar[1].schedule_day)
	race_manager.call("simulate_other_series_through_date", first_day)
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
	race_manager.call("simulate_other_series_through_date", first_day)
	for series_id in counts_after_first:
		assert((team.get_world_series_data(series_id).get("completed_race_ids", []) as Array).size() == int(counts_after_first[series_id]))
	race_manager.call("simulate_other_series_through_date", second_day)
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
