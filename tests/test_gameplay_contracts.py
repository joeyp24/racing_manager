"""Fast source-level regression contracts, runnable without the Godot editor."""
from pathlib import Path
import re
ROOT = Path(__file__).parents[1]
def test_every_track_defines_identity():
    tracks = list((ROOT / "resources/races").glob("*.tres")); assert len(tracks) == 12
    for track in tracks:
        text = track.read_text()
        for field in ("power_demand", "handling_demand", "tyre_wear_factor", "fuel_consumption_factor", "overtaking_difficulty", "pit_lane_time_loss", "accident_factor", "mechanical_stress"):
            assert re.search(rf"^{field} = ", text, re.M), (track, field)
def test_live_simulation_is_seedable_and_clamps_resources():
    text = (ROOT / "resources/races/race_simulation.gd").read_text()
    assert "seed: int = -1" in text; assert "tyre_condition = maxf(0.0" in text
    assert "fuel_laps = maxf(0.0" in text; assert 'status == "Retired"' in text
def test_mechanical_setup_is_not_changed_live():
    text = (ROOT / "scenes/pages/live_race/live_race.gd").read_text()
    assert "set_player_setup" not in text; assert "set_player_brake_bias" in text


def test_car_performance_uses_part_points_and_explains_modifiers():
    part = (ROOT / "resources/car_part.gd").read_text()
    car = (ROOT / "resources/car.gd").read_text()
    team = (ROOT / "resources/team.gd").read_text()
    inspection = (ROOT / "scenes/pages/garage/car_inspection.gd").read_text()
    garage = (ROOT / "scenes/pages/garage/garage_bay.gd").read_text()
    assert "base_performance_points" in part
    assert "func get_base_performance_points()" in car
    assert "func calculate_part_performance" in team
    assert "func calculate_car_performance" in team
    for source in ("Engineering department", "Engineering staff", "Crew chief", "Wind tunnel", "Secret department"):
        assert source in team
    assert "format_performance_breakdown" in inspection
    assert "PERFORMANCE POINTS" in inspection and "PERFORMANCE POINTS" in garage
    assert "get_total_performance(" not in car
    assert "performance_bonus)" not in part
def test_save_is_versioned_verified_and_atomic():
    text = (ROOT / "scripts/save_manager.gd").read_text()
    assert "CURRENT_SAVE_FORMAT_VERSION" in text; assert "temporary_resource" in text
    assert "rename_absolute" in text; assert "BACKUP_EXTENSION" in text


def test_date_progression_is_centralized_and_previewed():
    team = (ROOT / "resources/team.gd").read_text()
    dashboard = (ROOT / "scenes/pages/dashboard/dashboard.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    assert "@export var current_season_year" in team
    assert "func advance_to_date(" in team
    assert "func build_event_queue(" in race_manager
    assert "func group_events_by_date(" in race_manager
    assert "GameManager.team.week_advance_required = true" in race_manager
    assert "ADVANCE TO NEXT RACE" in dashboard
    assert "RaceManager.advance_to_date(target_day)" in dashboard
    assert "Advance Preview" in (ROOT / "scenes/pages/dashboard/dashboard.tscn").read_text()


def test_yearly_calendar_advances_by_date_and_catches_up_world_series():
    calendar = (ROOT / "resources/calendar_catalog.gd").read_text()
    race = (ROOT / "resources/races/race.gd").read_text()
    team = (ROOT / "resources/team.gd").read_text()
    manager = (ROOT / "autoload/race_manager.gd").read_text()
    dashboard = (ROOT / "scenes/pages/dashboard/dashboard.gd").read_text()
    assert "SEASON_START_DAY := 32" in calendar
    assert "SEASON_END_DAY := 334" in calendar
    assert '"schedule_day":schedule_day' in calendar
    assert "@export var schedule_day" in race
    assert "@export var current_season_day" in team
    assert "while completed_rounds < calendar.size() and calendar[completed_rounds].schedule_day <= target_day" in manager
    assert "simulate_other_series_through_date(target_day)" in manager


def test_development_uses_elapsed_calendar_days():
    team = (ROOT / "resources/team.gd").read_text()
    engineering = (ROOT / "scenes/pages/engineering/engineering.gd").read_text()
    assert '"start_day": current_season_day' in team
    assert '"completion_day": mini(' in team
    assert '"started_week"' not in team
    assert "CalendarCatalog.format_day" in engineering


def test_engineering_and_roster_have_dedicated_pages():
    engineering = (ROOT / "scenes/pages/engineering/engineering.gd").read_text()
    drivers = (ROOT / "scenes/pages/drivers/drivers.gd").read_text()
    home = (ROOT / "scenes/home/home.gd").read_text()
    assert "queue_part_project" in engineering
    assert "get_contracted_drivers" in drivers
    assert "hire_driver" not in drivers
    assert "engineering/engineering.tscn" in home
    assert "driver_market/driver_market.tscn" in home


def test_driver_profiles_have_deep_ratings_and_individual_potential_caps():
    resource = (ROOT / "resources/driver.gd").read_text()
    page = (ROOT / "scenes/pages/drivers/drivers.gd").read_text()
    for rating in ("race_pace", "qualifying_pace", "tyre_management", "racecraft", "wet_weather", "starts_restarts", "consistency", "car_feedback", "fitness", "composure"):
        assert f'"{rating}"' in resource
        assert f"var {rating}_potential" in resource
    assert "func get_overall_rating()" in resource
    assert "float(total) / RATING_FIELDS.size()" in resource
    assert "hometown" in resource and "racing_background" in resource and "biography" in resource
    assert "POTENTIAL OVR" in page and "FASTEST LAPS" in page
    development = (ROOT / "autoload/race_manager.gd").read_text()
    assert 'driver.get(attribute + "_potential")' in development


def test_series_ladder_has_progression_cars_and_full_rosters():
    catalog = (ROOT / "resources/series_catalog.gd").read_text()
    team = (ROOT / "resources/team.gd").read_text()
    dealership = (ROOT / "scenes/pages/dealership/dealership.gd").read_text()
    assert catalog.count('"roster_size":') == 8
    for series_id in ("local_short_track", "regional_short_track", "national_short_track", "continental_east_west", "continental_national", "national_truck", "national_grand", "premier_cup"):
        assert series_id in catalog
    assert "hq_level >= int(series.hq_level)" in team
    assert "index != current_index + 1" in team
    assert "func ensure_series_rosters()" in team
    assert "SeriesCatalog.create_car_templates(series_id)" in dealership


def test_series_progress_is_the_single_live_source():
    team = (ROOT / "resources/team.gd").read_text()
    save = (ROOT / "scripts/save_manager.gd").read_text()
    manager = (ROOT / "autoload/race_manager.gd").read_text()
    for method in ("complete_race_for_series", "unlock_race_for_series", "set_series_standings", "is_series_season_complete"):
        assert f"func {method}" in team
    assert "save_format_version < 4" in save
    assert 'series_progress.erase("local_short_track")' in save
    assert "GameManager.team.completed_races" not in manager
    assert "GameManager.team.championship_standings" not in manager


def test_every_configured_field_size_drives_the_grid():
    catalog = (ROOT / "resources/series_catalog.gd").read_text()
    roster = (ROOT / "resources/ai_roster_catalog.gd").read_text()
    manager = (ROOT / "autoload/race_manager.gd").read_text()
    sizes = [int(value) for value in re.findall(r'"maximum_field_size":(\d+)', catalog)]
    assert sorted(set(sizes)) == [20, 24, 30, 36, 38, 40]
    assert "get_maximum_field_size(race.series_id) - maxi(1, player_entry_count)" in manager
    assert '"driver_id":"%s_ai_%02d"' in roster
    assert "car_performance_range" in roster


def test_points_calendars_and_promotion_are_series_driven():
    points = (ROOT / "resources/points_system_catalog.gd").read_text()
    calendar = (ROOT / "resources/calendar_catalog.gd").read_text()
    championship = (ROOT / "scenes/pages/championship/championship.gd").read_text()
    for system in ('"short_track"', '"national"', '"cup"'):
        assert system in points
    assert "fastest_lap" in points and "stage_wins" in points and "standings_before" in points
    assert "travel_region" in calendar and "track_type_distribution" in calendar
    assert "season_round" in calendar and "LOCAL_IDS" in calendar
    assert "Three-race reserve" in championship and "ConfirmationDialog" in championship
    assert "Repeat current series" in championship


def test_other_series_are_simulated_saved_and_browsable():
    team = (ROOT / "resources/team.gd").read_text()
    manager = (ROOT / "autoload/race_manager.gd").read_text()
    world_page = (ROOT / "scenes/pages/world_series/world_series.gd").read_text()
    home = (ROOT / "scenes/home/home.gd").read_text()
    assert "@export var world_series_data" in team
    assert "func ensure_world_series_data()" in team
    assert "simulate_other_series_through_date" in manager
    assert 'var standings := _as_dictionary_array(series_data.get("standings", []))' in manager
    assert "func _as_dictionary_array(value: Variant) -> Array[Dictionary]:" in manager
    assert "calculate_championship_points(series_id" in manager
    for statistic in ('"points"', '"wins"', '"podiums"', '"starts"', '"best_finish"', '"average_finish_total"'):
        assert statistic in manager
    assert "SeriesCatalog.SERIES" in world_page
    assert 'data.get("results"' in world_page
    assert "world_series/world_series.tscn" in home


def test_series_have_distinct_multi_car_teams_and_a_team_directory():
    catalog = (ROOT / "resources/team_catalog.gd").read_text()
    roster = (ROOT / "resources/ai_roster_catalog.gd").read_text()
    page = (ROOT / "scenes/pages/race_teams/race_teams.gd").read_text()
    scene = (ROOT / "scenes/pages/race_teams/race_teams.tscn").read_text()
    manager = (ROOT / "autoload/race_manager.gd").read_text()
    for series_id in ("local_short_track", "regional_short_track", "national_short_track", "continental_east_west", "continental_national", "national_truck", "national_grand", "premier_cup"):
        assert f'"{series_id}": [' in catalog
    assert "RATING_OFFSETS" in catalog
    assert '"driver_count"' in catalog
    assert "TeamCatalog.get_teams(series_id)" in roster
    assert '"team_id":str(team.team_id)' in roster
    assert '"team_car_number":team_car_index+1' in roster
    assert '"team_id":race_entry.team_id' in manager
    for section in ('add_section("TEAM RATINGS")', 'add_section("HISTORY")', 'add_section("DRIVERS")', 'add_section("SEASON STATS")', 'add_section("RACE RESULTS")'):
        assert section in page
    assert 'text = "Team Directory"' in scene
    assert 'text = "My Race Operations"' in scene


def test_team_sizes_vary_and_scouting_covers_every_series():
    catalog = (ROOT / "resources/team_catalog.gd").read_text()
    scouting = (ROOT / "scenes/pages/scouting/scouting.gd").read_text()
    assert "TEAM_CAR_COUNTS" in catalog
    assert "configured_field_size == field_size" in catalog
    for count in (1, 2, 3, 4):
        assert re.search(rf"\b{count}\b", catalog.split("TEAM_CAR_COUNTS", 1)[1])
    assert "for series in SeriesCatalog.SERIES" in scouting
    assert 'series_filter.add_item("All series")' in scouting
    assert "driver.get_rating_rows()" in scouting
    assert "_recent_results" in scouting
    assert 'row.get("driver_id"' in scouting


def test_reputation_is_xp_and_gates_series_and_driver_access():
    team = (ROOT / "resources/team.gd").read_text()
    series = (ROOT / "resources/series_catalog.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    assert "const XP_PER_LEVEL" in team
    assert "func get_reputation_level()" in team
    assert "get_reputation_level() >= get_required_level_for_series(series_id)" in team
    assert "func get_driver_required_level(driver: Driver)" in team
    assert "func can_negotiate_with_driver(driver: Driver)" in team
    assert series.count('"required_level":') == 8
    assert "add_reputation_xp(result.reputation_earned)" in race_manager


def test_weekly_scouting_hours_power_reports_and_recruiting():
    team = (ROOT / "resources/team.gd").read_text()
    scouting = (ROOT / "scenes/pages/scouting/scouting.gd").read_text()
    market = (ROOT / "scenes/pages/driver_market/driver_market.gd").read_text()
    assert "SCOUTING_HOURS_PER_LEVEL" in team
    assert "func get_weekly_scouting_hours()" in team
    assert "func spend_scouting_hours(driver: Driver, action: String)" in team
    assert 'recruiting_progress[driver.driver_id]' in team
    assert "func negotiate_driver_contract" in team
    assert "scouting_hours_remaining" in scouting and '"???"' in scouting
    assert "can_negotiate_with_driver" in market and "Potential OVR %s" in market
