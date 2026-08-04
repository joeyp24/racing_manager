#!/usr/bin/env python3
"""Run Godot checks while preserving script errors as a failing exit status."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKS = (
    ("project import and parse", ("--headless", "--path", ".", "--import")),
    (
        "calendar system regression tests",
        ("--headless", "--path", ".", "--script", "tests/test_calendar_system.gd"),
    ),
    (
        "Performance Points behavioral tests",
        ("--headless", "--path", ".", "--script", "tests/test_performance_points.gd"),
    ),
    (
        "career simulation depth tests",
        ("--headless", "--path", ".", "--script", "tests/test_simulation_depth.gd"),
    ),
    (
        "race operations UI tests",
        ("--headless", "--path", ".", "--script", "tests/test_race_operations_ui.gd"),
    ),
    (
        "sponsorship system tests",
        ("--headless", "--path", ".", "--script", "tests/test_sponsorship_system.gd"),
    ),
    (
        "reputation system tests",
        ("--headless", "--path", ".", "--script", "tests/test_reputation_system.gd"),
    ),
    (
        "offseason and driver transfer tests",
        ("--headless", "--path", ".", "--script", "tests/test_offseason.gd"),
    ),
    (
        "career-wide expansion tests",
        ("--headless", "--path", ".", "--script", "tests/test_career_expansion.gd"),
    ),
    (
        "finance and living paddock regression tests",
        ("--headless", "--path", ".", "--script", "tests/test_finance_and_living_paddock.gd"),
    ),
    (
        "Career HQ interaction smoke tests",
        ("--headless", "--path", ".", "--script", "tests/test_career_hub.gd"),
    ),
    (
        "car inspection interaction smoke tests",
        ("--headless", "--path", ".", "--script", "tests/test_car_inspection.gd"),
    ),
    (
        "UI scene smoke tests",
        ("--headless", "--path", ".", "--script", "tests/test_ui_scenes.gd"),
    ),
)


def run_check(godot: str, name: str, arguments: tuple[str, ...]) -> bool:
    print(f"Running Godot {name}...")
    completed = subprocess.run(
        (godot, *arguments),
        cwd=ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(completed.stdout, end="")
    has_parse_error = "Parse Error:" in completed.stdout
    has_script_error = "SCRIPT ERROR:" in completed.stdout
    if completed.returncode != 0 or has_parse_error or has_script_error:
        reason = (
            f"exit code {completed.returncode}"
            if completed.returncode != 0
            else "parse or script error output"
        )
        print(f"Godot {name} failed ({reason}).", file=sys.stderr)
        return False
    print(f"Godot {name} passed.")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot", help="Godot executable or path")
    args = parser.parse_args()
    return 0 if all(run_check(args.godot, name, command) for name, command in CHECKS) else 1


if __name__ == "__main__":
    sys.exit(main())
