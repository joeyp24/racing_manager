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
    simulation = (ROOT / "resources/races/race_simulation.gd").read_text()
    assert "set_player_setup" not in text
    assert "set_player_brake_bias" not in text
    assert "set_player_brake_bias" in simulation


def test_car_specialization_and_fleet_planning_are_persistent_and_race_effective():
    car = (ROOT / "resources/car.gd").read_text()
    team = (ROOT / "resources/team.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    planner = (ROOT / "scenes/pages/garage/fleet_planner.gd").read_text()
    assert "@export var specialization_id" in car
    assert "@export var chassis_trait_id" in car
    assert "@export var saved_setups" in car
    assert "@export var driver_car_familiarity" in car
    assert "@export var fleet_race_assignments" in team
    assert "func assign_car_to_race(" in team
    assert "func get_car_race_forecast(" in team
    assert "get_identity_pace_bonus" in race_manager
    assert "get_wear_multiplier" in race_manager
    assert "HORIZON_EVENTS: int = 5" in planner
    assert "QUEUE SETUP" in planner


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
    assert "PERFORMANCE POINTS" in inspection
    assert 'performance_value.text = str(current_car.get_total_performance_points(GameManager.team))' in garage
    assert "get_total_performance(" not in car
    assert "performance_bonus)" not in part


def test_pp_calculator_is_typed_and_shop_previews_whole_car_delta():
    calculator = (ROOT / "resources/performance_point_calculator.gd").read_text()
    context = (ROOT / "resources/performance_point_context.gd").read_text()
    modifier = (ROOT / "resources/performance_point_modifier.gd").read_text()
    part_result = (ROOT / "resources/part_performance_result.gd").read_text()
    shop = (ROOT / "scenes/pages/shop/shop.gd").read_text()
    assert "class_name PerformancePointCalculator" in calculator
    assert "class_name PerformancePointContext" in context
    assert "enum Scope" in modifier and "enum Operation" in modifier
    assert "target_part_types" in modifier and "Duplicate Performance Point modifier" in calculator
    assert "var displayed_points: int" in part_result
    assert "result.displayed_points = roundi(result.effective_points)" in calculator
    assert "preview_result.displayed_points - current_result.displayed_points" in shop
    assert "find_installed_part" not in shop


def test_live_car_creation_does_not_use_legacy_performance():
    series = (ROOT / "resources/series_catalog.gd").read_text()
    dealership = (ROOT / "scenes/pages/dealership/dealership.gd").read_text()
    car = (ROOT / "resources/car.gd").read_text()
    assert "create_factory_parts" in series
    assert ".performance" not in series and ".performance" not in dealership
    assert "legacy_performance" in car


def test_player_pp_consumers_use_the_authoritative_car_result():
    car = (ROOT / "resources/car.gd").read_text()
    assert "team.calculate_car_performance(self).displayed_points" in car
    consumers = [
        "resources/races/race_readiness.gd",
        "scenes/pages/race_entry/race_entry.gd",
        "scenes/pages/race_weekend/race_weekend.gd",
    ]
    for relative_path in consumers:
        assert "get_total_performance_points" in (ROOT / relative_path).read_text(), relative_path
    inspection = (ROOT / "scenes/pages/garage/car_inspection.gd").read_text()
    garage = (ROOT / "scenes/pages/garage/garage_bay.gd").read_text()
    assert "calculate_car_performance(car)" in inspection
    assert "get_total_performance_points" in garage
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
    assert 'completed_race_ids.has(race.race_id)' in manager
    assert 'if int(race.schedule_day) > target_day' in manager
    assert "simulate_other_series_through_date(desired_day)" in manager


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
    assert "get_reputation_level() >= get_required_level_for_series(series_id)" in team
    assert "hq_level >= int(series.hq_level)" not in team
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
    assert "Open Offseason Hub" in championship
    assert "RaceManager.prepare_offseason(series_id)" in championship


def test_offseason_driver_market_is_persistent_and_worldwide():
    team = (ROOT / "resources/team.gd").read_text()
    manager = (ROOT / "resources/offseason_manager.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    page = (ROOT / "scenes/pages/offseason/offseason.gd").read_text()
    for field in ("ai_driver_career", "offseason_data", "transfer_history", "season_history"):
        assert f"@export var {field}" in team
    for feature in ("renew_player_driver", "release_player_driver", "sign_free_agent", "_create_rookie"):
        assert f"func {feature}" in manager
    assert "prepare_offseason" in race_manager and "complete_offseason" in race_manager
    assert "_record_ai_race_histories" in race_manager
    assert "RUMOR" in (ROOT / "scenes/pages/offseason/offseason.tscn").read_text()
    assert "OffseasonManager.can_complete" in page


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


def test_reputation_is_progressive_prestige_with_soft_driver_leverage():
    team = (ROOT / "resources/team.gd").read_text()
    series = (ROOT / "resources/series_catalog.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    reputation = (ROOT / "resources/reputation_manager.gd").read_text()
    assert "const XP_PER_LEVEL" in team
    assert "func get_reputation_level()" in team
    assert "func get_level_xp_span()" in team
    assert "get_reputation_level() >= get_required_level_for_series(series_id)" in team
    assert "func get_driver_required_level(driver: Driver)" in team
    assert "func can_negotiate_with_driver(driver: Driver)" in team
    assert "func get_driver_negotiation_terms(driver: Driver)" in team
    assert series.count('"required_level":') == 8
    assert "ReputationManager.apply_race_result" in race_manager
    assert "LEVEL_THRESHOLDS" in reputation
    assert "expectation_delta" in reputation
    weekend = (ROOT / "scenes/pages/race_weekend/race_weekend.gd").read_text()
    assert "var prestige_bonus := minf(" in weekend
    assert "float(GameManager.team.reputation) * 0.015" not in weekend


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
    assert "Scouting is optional" in market and "Potential OVR %s" in market


def test_finance_and_living_paddock_systems_are_integrated():
    team = (ROOT / "resources/team.gd").read_text()
    finance = (ROOT / "resources/finance_manager.gd").read_text()
    driver = (ROOT / "resources/driver.gd").read_text()
    career = (ROOT / "resources/career_expansion_manager.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    race_simulation = (ROOT / "resources/races/race_simulation.gd").read_text()
    career_hub = (ROOT / "scenes/pages/career_hub/career_hub.gd").read_text()
    calendar = (ROOT / "scenes/pages/race_calendar/race_calendar.gd").read_text()
    assert "const CURRENT_SAVE_FORMAT_VERSION: int = 20" in team
    assert "return _string_array" in team
    assert "class_name FinanceManager" in finance
    assert "owner_support" in finance and "series_distribution" in finance
    assert "func apply_race_dynamics" in driver and "get_race_state_modifier" in driver
    assert "func get_rivalry_modifiers" in career
    assert "func _process_ai_development" in career and "scout_ai_team_development" in career
    assert "news_feed" in career and "deadline_year" in career
    assert "func get_special_events" in career and "enter_special_event" in career
    assert '"type":"special_event"' in race_manager
    assert '"best_lap_time": entry.best_lap_time' in race_simulation
    assert '"AI DEVELOPMENT RACE"' in career_hub and '"WEEKLY PADDOCK FEED"' in career_hub
    assert "create_special_event" in calendar


def test_oval_racing_live_automation_and_career_briefing_are_integrated():
    race = (ROOT / "resources" / "races" / "race.gd").read_text()
    simulation = (ROOT / "resources" / "races" / "race_simulation.gd").read_text()
    weekend = (ROOT / "resources" / "career_expansion_manager.gd").read_text()
    live_race = (ROOT / "scenes" / "pages" / "live_race" / "live_race.gd").read_text()
    live_scene = (ROOT / "scenes" / "pages" / "live_race" / "live_race.tscn").read_text()
    career_hub = (ROOT / "scenes" / "pages" / "career_hub" / "career_hub.gd").read_text()
    home = (ROOT / "scenes" / "home" / "home.gd").read_text()
    assert "func is_oval()" in race
    assert 'forecast["rain_chance"] = 0' in simulation
    assert 'signal caution_started(lap: int)' in simulation
    assert 'entry.tyre_compound = "Standard"' in simulation
    assert 'simulation.crew_controller_label' in live_race
    assert 'is handling the caution cycle' in live_race
    assert 'caution_overlay' not in live_scene
    assert "live_track_map.gd" in live_scene
    assert '"WEEKLY BRIEFING"' in career_hub
    assert "WHY THIS CHANGED" in career_hub
    for story_id in ("sponsor_brand_conflict", "driver_resource_dispute", "regulation_controversy", "technical_failure_warning", "rival_accusation", "championship_pressure"):
        assert story_id in weekend
    assert "_show_reputation_gain" in home


def test_race_operations_analysis_and_team_philosophies_are_integrated():
    simulation = (ROOT / "resources/races/race_simulation.gd").read_text()
    track_catalog = (ROOT / "resources/track_presentation_catalog.gd").read_text()
    team_catalog = (ROOT / "resources/team_catalog.gd").read_text()
    team = (ROOT / "resources/team.gd").read_text()
    car = (ROOT / "resources/car.gd").read_text()
    live_race = (ROOT / "scenes/pages/live_race/live_race.gd").read_text()
    results = (ROOT / "scenes/pages/race_results/race_results.gd").read_text()
    inspection = (ROOT / "scenes/pages/garage/car_inspection.gd").read_text()
    assert "class_name TrackPresentationCatalog" in track_catalog
    assert '"corners": corners' in track_catalog and '"camera_style"' in track_catalog
    assert "func _generate_engineer_advice" in simulation
    assert '"was_accurate":not wrong' in simulation
    for service_id in ("four_tyres_fuel", "two_tyres_fuel", "fuel_only", "quick_repairs"):
        assert service_id in simulation
    assert "func predict_player_pit_loss" in simulation
    assert "func request_player_wave_around" in simulation
    assert "overtime_attempts" in simulation
    assert "DAMAGE_COMPONENTS" in car and "component_health" in simulation
    assert "Plan Workshop Repairs" in inspection
    assert "create_post_race_analysis_text" in results
    assert "WHAT COULD HAVE CHANGED THE RESULT" in results
    assert "const PHILOSOPHIES" in team_catalog
    assert "philosophy_id" in team and "regulation_preference" in team
    assert "crew_chief_feed" in live_race
    assert "get_player_entries" in simulation
    assert "set_crew_chief_automation" in simulation


def test_multi_team_commercial_and_standings_state_is_persistent():
    team = (ROOT / "resources/team.gd").read_text()
    race_team = (ROOT / "resources/race_team.gd").read_text()
    sponsor_manager = (ROOT / "resources/sponsor_manager.gd").read_text()
    race_manager = (ROOT / "autoload/race_manager.gd").read_text()
    driver = (ROOT / "resources/driver.gd").read_text()
    assert "@export var active_race_team_id" in team
    assert "@export var sponsor_contracts" in race_team
    assert "@export var crew_chief_id" in race_team
    assert "@export var engineer_ids" in race_team
    assert "func assign_staff_to_race_team" in team
    assert "get_sponsor_capacity" in team
    assert "for race_team in team.race_teams" in sponsor_manager
    assert "set_series_standings(GameManager.team.current_series_id, standings)" in race_manager
    assert 'championship_entry["starts"]' in race_manager
    assert "@export var is_pay_driver" in driver
    assert "sponsorship_contribution_per_race" in driver


def test_live_race_analysis_setup_and_venue_geometry_are_integrated():
    simulation = (ROOT / "resources/races/race_simulation.gd").read_text()
    live_scene = (ROOT / "scenes/pages/live_race/live_race.tscn").read_text()
    live_ui = (ROOT / "scenes/pages/live_race/live_race.gd").read_text()
    practice = (ROOT / "resources/practice_run_simulator.gd").read_text()
    tracks = (ROOT / "resources/track_presentation_catalog.gd").read_text()
    assert "telemetry_history" in simulation
    for removed_tab in ('name="Stints"', 'name="Lap Times"', 'name="Tyre & Fuel"', 'name="Passing"', 'name="Cautions"', 'name="Comparisons"'):
        assert removed_tab not in live_scene
    assert 'name="TeamCard"' in live_scene and 'name="CrewCard"' in live_scene
    assert "_refresh_team_summary" in live_ui
    for setup_axis in ("gearing", "front_springs", "rear_springs", "downforce", "left_tyre_pressure", "right_tyre_pressure", "camber", "toe", "track_bar"):
        assert f'"{setup_axis}"' in practice
    assert '"sectors"' in tracks
    assert '"passing_zones"' in tracks
    assert '"caution_locations"' in tracks
    assert '"pit_entry"' in tracks and '"pit_exit"' in tracks


def test_personality_brand_and_readable_live_layout_are_integrated():
	personality = (ROOT / "resources/personality_catalog.gd").read_text(encoding="utf-8")
	driver = (ROOT / "resources/driver.gd").read_text(encoding="utf-8")
	teams = (ROOT / "resources/team_catalog.gd").read_text(encoding="utf-8")
	live_scene = (ROOT / "scenes/pages/live_race/live_race.tscn").read_text(encoding="utf-8")
	results = (ROOT / "scenes/pages/race_results/race_results.gd").read_text(encoding="utf-8")
	project = (ROOT / "project.godot").read_text(encoding="utf-8")
	assert "class_name PersonalityCatalog" in personality
	for voice in ("veteran", "firebrand", "analyst", "loyalist", "showman", "ice_cold", "underdog"):
		assert f'"{voice}"' in personality
	assert "memorable_moments" in driver and "last_reaction" in driver
	assert "TEAM_PALETTES" in teams and "TEAM_MOTTOS" in teams
	assert 'name="TimingColumn"' in live_scene and 'name="BroadcastScroll"' in live_scene
	assert "driver_reaction" in results and "rival_summary" in results
	assert 'config/icon="res://ui/brand/racing_manager_icon.png"' in project
	assert (ROOT / "ui/brand/racing_manager_icon.png").exists()
def test_committed_weekend_cannot_be_abandoned_through_navigation():
    game_manager = (ROOT / "scripts/game_manager.gd").read_text(encoding="utf-8")
    race_entry = (ROOT / "scenes/pages/race_entry/race_entry.gd").read_text(encoding="utf-8")
    team = (ROOT / "resources/team.gd").read_text(encoding="utf-8")
    assert "func is_race_weekend_locked()" in game_manager
    assert "scene_path = required_path" in game_manager
    assert "get_active_race_weekend_path" in game_manager
    assert "GameManager.begin_race_weekend" in race_entry
    assert "@export var active_race_weekend_state" in team
    assert "_restore_active_race_weekend" in game_manager


def test_guided_opening_and_race_week_decisions_are_integrated():
    guide = (ROOT / "scripts/first_hour_experience.gd").read_text(encoding="utf-8")
    dashboard = (ROOT / "scenes/pages/dashboard/dashboard.gd").read_text(encoding="utf-8")
    dashboard_scene = (ROOT / "scenes/pages/dashboard/dashboard.tscn").read_text(encoding="utf-8")
    readiness = (ROOT / "resources/races/race_readiness.gd").read_text(encoding="utf-8")
    for step in ("identity", "driver", "car", "sponsor", "practice", "strategy", "race", "service"):
        assert f'"{step}"' in guide
    for question in ("WHAT CAN I AFFORD?", "WHERE CAN I GAIN PERFORMANCE?", "WHAT RISK SHOULD I TAKE?", "WHAT DOES THE BOARD EXPECT?"):
        assert question in dashboard
    assert "CONTINUE RACE WEEKEND" in dashboard
    assert 'name="FirstHourGuide"' in dashboard_scene
    assert "Opening-race assistance" in readiness


def test_results_lead_with_a_story_and_gate_deep_telemetry():
    results = (ROOT / "scenes/pages/race_results/race_results.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/pages/race_results/race_results.tscn").read_text(encoding="utf-8")
    assert "func create_outcome_story" in results
    assert "Caution and pit timing gained" in results
    assert "Slow pit service gave time back" in results
    assert "details_container.visible = visible_now" in results
    assert scene.count('name="details_toggle"') == 1
    assert 'name="detailed_analysis_button"' not in scene
    assert 'name="next_action_button"' in scene
