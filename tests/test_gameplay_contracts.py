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
def test_save_is_versioned_verified_and_atomic():
    text = (ROOT / "scripts/save_manager.gd").read_text()
    assert "CURRENT_SAVE_FORMAT_VERSION" in text; assert "temporary_resource" in text
    assert "rename_absolute" in text; assert "BACKUP_EXTENSION" in text


def test_race_week_progression_is_dashboard_owned():
    team = (ROOT / "resources/team.gd").read_text()
    dashboard = (ROOT / "scenes/pages/dashboard/dashboard.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    assert "@export var current_race_week" in team
    assert "func advance_to_next_race_week()" in team
    assert "GameManager.team.week_advance_required = true" in race_manager
    assert "ADVANCE TO NEXT RACE WEEK" in dashboard
    assert "advance_to_next_race_week()" in dashboard


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
    assert "simulate_other_series_through_round" in manager
    assert "calculate_championship_points(series_id" in manager
    for statistic in ('"points"', '"wins"', '"podiums"', '"starts"', '"best_finish"', '"average_finish_total"'):
        assert statistic in manager
    assert "SeriesCatalog.SERIES" in world_page
    assert 'data.get("results"' in world_page
    assert "world_series/world_series.tscn" in home
