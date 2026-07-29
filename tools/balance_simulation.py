#!/usr/bin/env python3
"""Deterministic Monte Carlo economy smoke test for career balance."""

from __future__ import annotations

import argparse
import random
from statistics import mean

DIFFICULTIES = {
    "Rookie": (75_000, 1.25, 0.45, 0.75),
    "Club": (50_000, 1.00, 0.75, 1.00),
    "Pro": (35_000, 0.80, 1.10, 1.35),
}
PURSES = [500, 550, 600, 650, 700, 750, 800, 900, 1000, 1100, 1250, 1500]
WEEKEND_COSTS = [1095 + race * 70 for race in range(12)]
UPGRADES = {"Engine": (2_800, 0.9), "Suspension": (2_100, 0.65), "Body": (1_800, 0.5)}
DEPARTMENTS = {"Engineering": (8_000, 0.7), "Marketing": (6_000, 180), "Accounting": (7_000, 120)}


def payout(win: int, position: int) -> int:
    curve = [500, 300, 225, 175, 150, 125, 110, 100, 90, 85]
    base = curve[position - 1] if position <= 10 else 75
    return round(base * win / 500)


def simulate(difficulty: str, seasons: int, seed: int) -> None:
    start, sponsor, growth, repairs = DIFFICULTIES[difficulty]
    rng = random.Random(seed)
    bankruptcies = 0
    cash_by_race = [[] for _ in PURSES]
    finishes: list[int] = []
    purchase_races: list[int] = []
    roi = {name: [] for name in UPGRADES | DEPARTMENTS}
    for _ in range(seasons):
        cash, pace, bought = start - 6_500, 0.0, set()
        for race, purse in enumerate(PURSES):
            position = max(1, min(20, round(rng.gauss(10.5 + race * growth / 8 - pace, 3))))
            income = payout(purse, position) + round(650 * sponsor)
            cost = WEEKEND_COSTS[race] + round(rng.uniform(100, 500) * repairs)
            cash += income - cost
            finishes.append(position)
            for name, (price, benefit) in UPGRADES.items():
                if name not in bought and cash > price + 8_000:
                    cash -= price
                    pace += benefit
                    bought.add(name)
                    purchase_races.append(race + 1)
                    roi[name].append(((12 - race) * benefit * 85 - price) / price)
            cash_by_race[race].append(cash)
            if cash < 0:
                bankruptcies += 1
                break
        for name, (price, benefit) in DEPARTMENTS.items():
            roi[name].append((12 * benefit - price) / price)
    print(f"{difficulty}: {seasons} seasons (seed {seed})")
    print(f"Bankruptcy rate: {bankruptcies / seasons:.1%}")
    print("Average cash by race: " + ", ".join(f"R{i + 1} ${mean(v):,.0f}" for i, v in enumerate(cash_by_race) if v))
    print(f"Average finishing position: {mean(finishes):.2f}")
    print(f"Average upgrade purchase timing: race {mean(purchase_races):.2f}" if purchase_races else "Average upgrade purchase timing: none")
    print("Modeled ROI: " + ", ".join(f"{name} {mean(values):+.1%}" for name, values in roi.items() if values))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--difficulty", choices=DIFFICULTIES, default="Club")
    parser.add_argument("--seasons", type=int, default=500)
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()
    simulate(args.difficulty, max(1, args.seasons), args.seed)
