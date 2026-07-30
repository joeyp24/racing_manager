#!/usr/bin/env python3
"""Deterministic Monte Carlo economy smoke test for career balance."""

from __future__ import annotations

import argparse
import random
from statistics import mean

DIFFICULTIES = {
    "Rookie": {
        "starting_cash": 75_000, "sponsor": 1.20, "growth": 0.45,
        "repairs": 0.75, "weekend": 0.88, "prize": 1.15,
        "salary": 0.90, "market": 0.90,
    },
    "Club": {
        "starting_cash": 50_000, "sponsor": 1.00, "growth": 0.75,
        "repairs": 1.00, "weekend": 1.00, "prize": 1.00,
        "salary": 1.00, "market": 1.00,
    },
    "Pro": {
        "starting_cash": 42_000, "sponsor": 0.88, "growth": 1.10,
        "repairs": 1.25, "weekend": 1.05, "prize": 0.95,
        "salary": 1.05, "market": 1.04,
    },
}
PURSES = [500, 550, 600, 650, 700, 750, 800, 900, 1000, 1100, 1250, 1500]
WEEKEND_COSTS = [1095 + race * 70 for race in range(12)]
UPGRADES = {"Engine": (2_800, 0.9), "Suspension": (2_100, 0.65), "Body": (1_800, 0.5)}
DEPARTMENTS = {"Engineering": (8_000, 500), "Marketing": (6_000, 360), "Accounting": (7_000, 300)}


def payout(win: int, position: int) -> int:
    curve = [500, 300, 225, 175, 150, 125, 110, 100, 90, 85]
    base = curve[position - 1] if position <= 10 else 75
    return round(base * win / 500)


def simulate(difficulty: str, seasons: int, seed: int) -> None:
    settings = DIFFICULTIES[difficulty]
    rng = random.Random(seed)
    bankruptcies = 0
    cash_by_race = [[] for _ in PURSES]
    final_cash: list[int] = []
    finishes: list[int] = []
    purchase_races: list[int] = []
    roi = {name: [] for name in UPGRADES | DEPARTMENTS}
    for _ in range(seasons):
        cash, pace, bought = settings["starting_cash"] - round(6_500 * settings["market"]), 0.0, set()
        for race, purse in enumerate(PURSES):
            position = max(1, min(20, round(rng.gauss(10.5 + race * settings["growth"] / 8 - pace, 3))))
            income = round(payout(purse, position) * settings["prize"]) + round(650 * settings["sponsor"])
            cost = (
                round(WEEKEND_COSTS[race] * settings["weekend"])
                + round(rng.uniform(100, 500) * settings["repairs"])
                + round(700 * settings["salary"])
            )
            cash += income - cost
            finishes.append(position)
            for name, (price, benefit) in UPGRADES.items():
                market_price = round(price * settings["market"])
                if name not in bought and cash > market_price + 8_000:
                    cash -= market_price
                    pace += benefit
                    bought.add(name)
                    purchase_races.append(race + 1)
                    retained_value = round(market_price * 0.60)
                    roi[name].append(((24 - race) * benefit * 85 + retained_value - market_price) / market_price)
            cash_by_race[race].append(cash)
            if cash < 0:
                bankruptcies += 1
                break
        final_cash.append(cash)
        for name, (price, benefit) in DEPARTMENTS.items():
            roi[name].append((24 * benefit - price) / price)
    print(f"{difficulty}: {seasons} seasons (seed {seed})")
    print(f"Bankruptcy rate: {bankruptcies / seasons:.1%}")
    print("Average cash by race: " + ", ".join(f"R{i + 1} ${mean(v):,.0f}" for i, v in enumerate(cash_by_race) if v))
    print(f"Average finishing position: {mean(finishes):.2f}")
    print(f"Average final cash: ${mean(final_cash):,.0f}")
    print(f"Runaway-wealth rate (>$150k): {sum(value > 150_000 for value in final_cash) / seasons:.1%}")
    print(f"Average upgrade purchase timing: race {mean(purchase_races):.2f}" if purchase_races else "Average upgrade purchase timing: none")
    print("Two-season modeled ROI: " + ", ".join(f"{name} {mean(values):+.1%}" for name, values in roi.items() if values))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--difficulty", choices=DIFFICULTIES, default="Club")
    parser.add_argument("--seasons", type=int, default=500)
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()
    simulate(args.difficulty, max(1, args.seasons), args.seed)
