"""Regression targets for the deterministic career economy model."""

import importlib.util
from pathlib import Path
import sys


ROOT = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location("balance_simulation", ROOT / "tools/balance_simulation.py")
assert SPEC and SPEC.loader
BALANCE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = BALANCE
SPEC.loader.exec_module(BALANCE)


def test_club_careers_have_tension_without_systemic_bankruptcy():
    report = BALANCE.simulate("Club", 500, 2026, 3)
    assert report.bankruptcy_rate <= 0.05
    assert 0.10 <= report.unavoidable_loss_rate <= 0.45
    assert report.runaway_wealth_rate <= 0.10
    assert report.average_upgrade_race is not None


def test_difficulty_changes_financial_pressure_monotonically():
    reports = [BALANCE.simulate(name, 300, 2026, 3) for name in ("Rookie", "Club", "Pro")]
    assert reports[0].bankruptcy_rate <= reports[1].bankruptcy_rate <= reports[2].bankruptcy_rate
    assert reports[0].unavoidable_loss_rate < reports[1].unavoidable_loss_rate < reports[2].unavoidable_loss_rate
    assert reports[0].average_final_cash > reports[1].average_final_cash > reports[2].average_final_cash
