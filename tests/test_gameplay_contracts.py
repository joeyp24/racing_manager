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
