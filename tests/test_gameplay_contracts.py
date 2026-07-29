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
