#!/usr/bin/env python3
"""Deterministic multi-season economy and recovery model.

This is a balance instrument, not a substitute for human playtests. It models
conservative reserve behavior, incident costs, recovery after poor results,
upgrade timing, promotion readiness, and runaway wealth across whole careers.
"""

from __future__ import annotations

import argparse
import random
from dataclasses import dataclass
from statistics import mean, median

DIFFICULTIES = {
    "Rookie": {
        "starting_cash": 65_000, "sponsor": 1.20, "growth": 0.45,
        "repairs": 0.75, "weekend": 0.88, "prize": 1.15,
        "salary": 0.90, "market": 0.90, "reserve": 56_000,
    },
    "Club": {
        "starting_cash": 42_000, "sponsor": 1.00, "growth": 0.75,
        "repairs": 1.00, "weekend": 1.00, "prize": 1.00,
        "salary": 1.00, "market": 1.00, "reserve": 32_000,
    },
    "Pro": {
        "starting_cash": 34_000, "sponsor": 0.88, "growth": 1.10,
        "repairs": 1.25, "weekend": 1.05, "prize": 0.95,
        "salary": 1.05, "market": 1.04, "reserve": 23_000,
    },
}
PURSES = [500, 550, 600, 650, 700, 750, 800, 900, 1000, 1100, 1250, 1500]
WEEKEND_COSTS = [1095 + race * 70 for race in range(12)]
UPGRADES = {
    "Engine": (7_200, 1.25),
    "Suspension": (5_900, 0.90),
    "Body": (6_200, 0.75),
}
DEPARTMENTS = {
    "Engineering": (8_000, 500),
    "Marketing": (6_000, 360),
    "Accounting": (7_000, 300),
}
CHAMPIONSHIP_PAYOUTS = [50_000, 35_000, 25_000, 18_000, 14_000, 10_000, 7_500, 5_000]
SERIES_DISTRIBUTION = 1_320
EVENT_REVENUE = 220
FIRST_SEASON_OWNER_SUPPORT = 780
PROMOTION_CASH_REQUIREMENT = 70_500


@dataclass
class BalanceReport:
    difficulty: str
    careers: int
    career_seasons: int
    bankruptcy_rate: float
    average_cash_by_race: list[float]
    average_finish: float
    average_final_cash: float
    runaway_wealth_rate: float
    unavoidable_loss_rate: float
    bad_result_recovery_rate: float
    average_upgrade_race: float | None
    promotion_season_median: float | None
    promotion_ready_rate: float
    roi: dict[str, float]


def payout(win: int, position: int) -> int:
    curve = [500, 300, 225, 175, 150, 125, 110, 100, 90, 85]
    base = curve[position - 1] if position <= 10 else 75
    return round(base * win / 500)


def simulate(difficulty: str, careers: int, seed: int, career_seasons: int = 3) -> BalanceReport:
    settings = DIFFICULTIES[difficulty]
    rng = random.Random(seed)
    bankruptcies = 0
    cash_by_race = [[] for _ in range(len(PURSES) * career_seasons)]
    final_cash: list[int] = []
    finishes: list[int] = []
    first_upgrade_races: list[int] = []
    promotion_seasons: list[int] = []
    operating_losses = 0
    race_starts = 0
    bad_results = 0
    recovered_bad_results = 0
    roi = {name: [] for name in UPGRADES | DEPARTMENTS}

    for _ in range(careers):
        cash = settings["starting_cash"] - round(6_500 * settings["market"])
        pace = 0.0
        reputation = 0
        bought: set[str] = set()
        pending_recoveries: list[dict[str, int | bool]] = []
        global_race = 0
        bankrupt = False
        promotion_recorded = False

        for season in range(career_seasons):
            season_finishes: list[int] = []
            for race, purse in enumerate(PURSES):
                global_race += 1
                position = max(
                    1,
                    min(20, round(rng.gauss(10.5 + (race + season * 2) * settings["growth"] / 8 - pace, 3))),
                )
                pre_race_cash = cash
                incident_cost = round(rng.triangular(100, 900, 280) * settings["repairs"])
                if rng.random() < 0.05 * settings["repairs"]:
                    incident_cost += round(rng.uniform(800, 2_500) * settings["repairs"])
                commercial_growth = 1.0 + float(season) * (0.20 if difficulty == "Rookie" else (0.16 if difficulty == "Club" else 0.13))
                income = (
                    round(payout(purse, position) * settings["prize"])
                    + round(650 * settings["sponsor"] * commercial_growth)
                    + SERIES_DISTRIBUTION
                    + round(EVENT_REVENUE * settings["sponsor"] * commercial_growth)
                    + (FIRST_SEASON_OWNER_SUPPORT if season == 0 else (420 if season == 1 else 0))
                )
                cost = (
                    round(WEEKEND_COSTS[race] * settings["weekend"])
                    + incident_cost
                    + round(700 * settings["salary"])
                )
                operating_change = income - cost
                if operating_change < 0:
                    operating_losses += 1
                cash += operating_change
                race_starts += 1
                finishes.append(position)
                season_finishes.append(position)
                reputation += max(1, 21 - position)

                unresolved_recoveries: list[dict[str, int | bool]] = []
                for recovery in pending_recoveries:
                    if cash >= int(recovery["target"]):
                        recovered_bad_results += 1
                        continue
                    recovery["remaining"] = int(recovery["remaining"]) - 1
                    if int(recovery["remaining"]) > 0:
                        unresolved_recoveries.append(recovery)
                pending_recoveries = unresolved_recoveries

                if position >= 15 and operating_change < 0:
                    bad_results += 1
                    pending_recoveries.append({"target": pre_race_cash, "remaining": 3})

                for name, (price, benefit) in UPGRADES.items():
                    market_price = round(price * settings["market"])
                    if name not in bought and cash >= market_price + settings["reserve"]:
                        cash -= market_price
                        pace += benefit
                        bought.add(name)
                        if len(bought) == 1:
                            first_upgrade_races.append(global_race)
                        retained_value = round(market_price * 0.60)
                        roi[name].append(((36 - global_race) * benefit * 85 + retained_value - market_price) / market_price)

                cash_by_race[global_race - 1].append(cash)
                if cash < 0:
                    bankruptcies += 1
                    bankrupt = True
                    break

            pending_recoveries.clear()
            if bankrupt:
                break

            championship_position = max(1, min(20, round(mean(season_finishes))))
            if championship_position <= len(CHAMPIONSHIP_PAYOUTS):
                cash += CHAMPIONSHIP_PAYOUTS[championship_position - 1]
            reputation_level = 1 + reputation // 100
            if not promotion_recorded and reputation_level >= 2 and cash >= PROMOTION_CASH_REQUIREMENT:
                promotion_seasons.append(season + 1)
                promotion_recorded = True

        final_cash.append(cash)
        for name, (price, benefit) in DEPARTMENTS.items():
            roi[name].append((24 * benefit - price) / price)

    populated_cash = [mean(values) for values in cash_by_race if values]
    return BalanceReport(
        difficulty=difficulty,
        careers=careers,
        career_seasons=career_seasons,
        bankruptcy_rate=bankruptcies / careers,
        average_cash_by_race=populated_cash,
        average_finish=mean(finishes),
        average_final_cash=mean(final_cash),
        runaway_wealth_rate=sum(value > 150_000 for value in final_cash) / careers,
        unavoidable_loss_rate=operating_losses / max(1, race_starts),
        bad_result_recovery_rate=recovered_bad_results / max(1, bad_results),
        average_upgrade_race=mean(first_upgrade_races) if first_upgrade_races else None,
        promotion_season_median=median(promotion_seasons) if promotion_seasons else None,
        promotion_ready_rate=len(promotion_seasons) / careers,
        roi={name: mean(values) for name, values in roi.items() if values},
    )


def print_report(report: BalanceReport) -> None:
    print(f"{report.difficulty}: {report.careers} careers x {report.career_seasons} seasons")
    print(f"Bankruptcy rate: {report.bankruptcy_rate:.1%}")
    print(f"Unavoidable operating-loss frequency: {report.unavoidable_loss_rate:.1%}")
    print(f"Recovery within three races after a bad result: {report.bad_result_recovery_rate:.1%}")
    print(f"Average finishing position: {report.average_finish:.2f}")
    print(f"Average final cash: ${report.average_final_cash:,.0f}")
    print(f"Runaway-wealth rate (>$150k): {report.runaway_wealth_rate:.1%}")
    print(
        f"Average meaningful-upgrade timing: race {report.average_upgrade_race:.2f}"
        if report.average_upgrade_race is not None
        else "Average meaningful-upgrade timing: none"
    )
    print(
        f"Promotion readiness: {report.promotion_ready_rate:.1%} by season {report.promotion_season_median:g} (median)"
        if report.promotion_season_median is not None
        else "Promotion readiness: no careers reached the modeled cash and reputation gate"
    )
    sample_points = [11, 23, len(report.average_cash_by_race) - 1]
    print(
        "Average cash checkpoints: "
        + ", ".join(
            f"R{index + 1} ${report.average_cash_by_race[index]:,.0f}"
            for index in sample_points
            if 0 <= index < len(report.average_cash_by_race)
        )
    )
    print("Modeled ROI: " + ", ".join(f"{name} {value:+.1%}" for name, value in report.roi.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--difficulty", choices=DIFFICULTIES, default="Club")
    parser.add_argument("--seasons", type=int, default=500, help="Number of independent careers")
    parser.add_argument("--career-seasons", type=int, default=3)
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()
    print_report(simulate(args.difficulty, max(1, args.seasons), args.seed, max(1, args.career_seasons)))
