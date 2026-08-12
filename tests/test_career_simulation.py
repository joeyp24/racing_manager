"""Contracts for the deterministic long-career simulation harness."""

import importlib.util
import json
from pathlib import Path
import sys


ROOT = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location(
    "career_simulation", ROOT / "tools/career_simulation.py"
)
assert SPEC and SPEC.loader
SIMULATION = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SIMULATION
SPEC.loader.exec_module(SIMULATION)


def test_long_career_simulation_is_seeded_and_repeatable():
    first = SIMULATION.simulate("Club", careers=6, seasons=10, seed=4242)
    repeat = SIMULATION.simulate("Club", careers=6, seasons=10, seed=4242)
    different = SIMULATION.simulate("Club", careers=6, seasons=10, seed=4243)

    assert first.to_dict() == repeat.to_dict()
    assert first.summary != different.summary
    assert len(first.seasons) == 10


def test_report_covers_the_long_career_balance_risks():
    report = SIMULATION.simulate("Club", careers=8, seasons=12, seed=2026)
    expected_metrics = {
        "career_failure_rate",
        "insolvency_rate",
        "board_dismissal_rate",
        "median_final_cash",
        "runaway_wealth_rate",
        "promotion_rate",
        "academy_seat_conversion_rate",
        "average_regulation_performance_loss",
        "ai_financial_distress_rate",
        "champion_concentration",
        "longest_championship_streak",
        "manufacturer_top_share",
        "sponsor_top_share",
        "average_independent_share",
        "average_annual_payroll",
        "average_annual_facility_upkeep",
        "average_final_driver_rating",
        "ai_average_annual_development",
    }
    assert expected_metrics <= report.summary.keys()
    assert all("ai_movements" in row for row in report.seasons)
    assert all("average_regulation_reset" in row for row in report.seasons)


def test_threshold_failures_are_machine_readable():
    report = SIMULATION.simulate(
        "Club",
        careers=4,
        seasons=5,
        seed=99,
        thresholds={
            "career_failure_rate": {"max": -1, "reason": "forced failure"},
            "promotion_rate": {"min": 2, "reason": "forced failure"},
        },
    )
    assert {violation["metric"] for violation in report.violations} == {
        "career_failure_rate",
        "promotion_rate",
    }
    encoded = json.dumps(report.to_dict())
    assert "forced failure" in encoded


def test_default_club_thresholds_guard_against_systemic_failures():
    thresholds = SIMULATION.load_thresholds(
        ROOT / "tools/career_simulation_thresholds.json", "Club"
    )
    report = SIMULATION.simulate(
        "Club", careers=32, seasons=20, seed=2026, thresholds=thresholds
    )
    assert report.violations == []
    assert report.summary["academy_seat_conversion_rate"] > 0
    assert report.summary["unique_champions"] > len(SIMULATION.SERIES)


def test_reports_can_be_written_as_json_and_csv(tmp_path):
    report = SIMULATION.simulate("Club", careers=3, seasons=4, seed=7)
    json_path = tmp_path / "career-report.json"
    csv_path = tmp_path / "career-report.csv"
    SIMULATION.write_json(report, json_path)
    SIMULATION.write_csv(report, csv_path)

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert payload["config"]["seed"] == 7
    assert payload["seasons"][0]["season"] == 1
    csv_text = csv_path.read_text(encoding="utf-8")
    assert "season,active_careers,survival_rate" in csv_text
    assert len(csv_text.splitlines()) == 5
