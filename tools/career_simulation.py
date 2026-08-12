#!/usr/bin/env python3
"""Deterministic long-career balance and ecosystem simulation.

This headless balance instrument exercises the interactions that are difficult to
observe in short playtests: finances, board pressure, academy throughput, series
movement, AI development, regulation resets, manufacturer concentration, and
championship parity. It is intentionally fast enough to run in CI and produces
JSON and CSV reports for comparing balance changes between commits.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path
from statistics import mean, median
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_THRESHOLDS = ROOT / "tools/career_simulation_thresholds.json"


@dataclass(frozen=True)
class Difficulty:
    starting_cash: int
    sponsor_multiplier: float
    development_pressure: float
    repair_multiplier: float
    weekend_multiplier: float
    prize_multiplier: float
    salary_multiplier: float
    reserve_multiplier: float


DIFFICULTIES = {
    "Rookie": Difficulty(65_000, 1.20, 0.45, 0.75, 0.88, 1.15, 0.90, 0.85),
    "Club": Difficulty(42_000, 1.00, 0.75, 1.00, 1.00, 1.00, 1.00, 1.00),
    "Pro": Difficulty(34_000, 0.88, 1.10, 1.25, 1.05, 0.95, 1.05, 1.10),
}


@dataclass(frozen=True)
class Series:
    series_id: str
    name: str
    car_price: int
    estimated_race_cost: int
    season_length: int
    field_size: int
    base_rating: float
    entry_cost: int
    hq_level: int
    sponsor_multiplier: float
    payouts: tuple[int, ...]


# Mirrors the progression and cost scale in resources/series_catalog.gd. Keeping
# the simulation data explicit makes report inputs stable and reviewable.
SERIES = (
    Series("local_short_track", "Local Short Track", 12_000, 1_200, 12, 20, 48, 0, 1, 1.0, (50_000, 35_000, 25_000, 18_000, 14_000, 10_000, 7_500, 5_000)),
    Series("regional_short_track", "Regional Short Track", 28_000, 2_500, 14, 24, 55, 35_000, 2, 1.2, (125_000, 80_000, 50_000, 30_000, 20_000)),
    Series("national_short_track", "National Short Track", 60_000, 5_000, 16, 30, 62, 80_000, 3, 1.5, (250_000, 150_000, 90_000, 50_000, 30_000)),
    Series("continental_east_west", "Continental East/West", 110_000, 9_000, 16, 24, 68, 150_000, 4, 1.9, (400_000, 240_000, 140_000, 80_000, 50_000)),
    Series("continental_national", "Continental National", 190_000, 15_000, 20, 30, 74, 275_000, 5, 2.4, (700_000, 400_000, 240_000, 140_000, 80_000)),
    Series("national_truck", "National Truck", 350_000, 26_000, 23, 36, 80, 500_000, 6, 3.2, (1_200_000, 700_000, 400_000, 220_000, 120_000)),
    Series("national_grand", "National Grand", 650_000, 45_000, 28, 38, 87, 900_000, 7, 4.2, (2_200_000, 1_300_000, 750_000, 400_000, 225_000)),
    Series("premier_cup", "Premier Cup", 1_200_000, 75_000, 36, 40, 94, 1_750_000, 8, 5.5, (5_000_000, 3_000_000, 1_750_000, 1_000_000, 600_000)),
)

HQ_UPGRADE_COSTS = (25_000, 60_000, 125_000, 250_000, 450_000, 800_000, 1_400_000)
FACILITIES = {
    "design_office": (12_000, 260),
    "quality_lab": (14_000, 280),
    "driver_academy": (10_000, 220),
    "simulator": (14_000, 300),
    "medical_centre": (9_000, 190),
    "marketing_suite": (8_000, 180),
}
MANUFACTURERS = ("Independent", "Orion", "Apex", "Falcon", "Titan")
SPONSORS = (
    "Apex Tools",
    "Brightline",
    "Cobalt Energy",
    "Evergreen Foods",
    "Frontier Telecom",
    "Northstar Bank",
    "Redline Oil",
    "Summit Logistics",
    "Victory Performance",
    "Waypoint Travel",
)


@dataclass
class Prospect:
    overall: float
    potential: float
    seasons: int = 0


@dataclass
class TeamState:
    team_id: str
    series_index: int
    rating: float
    engineering: float
    staff: float
    strategy: float
    budget: float
    manufacturer: str
    sponsor: str
    development_multiplier: float
    last_position: int = 0
    financial_status: str = "Stable"
    championships: int = 0
    movement_count: int = 0

    def strength(self) -> float:
        return (
            self.rating * 0.55
            + self.engineering * 0.20
            + self.staff * 0.12
            + self.strategy * 0.13
        )


@dataclass
class PlayerState:
    cash: float
    rating: float = 48.0
    driver_rating: float = 56.0
    series_index: int = 0
    hq_level: int = 1
    board_confidence: float = 72.0
    job_security: float = 78.0
    recovery_funding_used: bool = False
    facilities: dict[str, int] = field(default_factory=lambda: {name: 0 for name in FACILITIES})
    academy: list[Prospect] = field(default_factory=list)
    academy_recruits: int = 0
    academy_promotions: int = 0
    promotions: int = 0
    regulation_loss: float = 0.0
    failed: bool = False
    failure_reason: str = ""
    manufacturer: str = "Independent"
    sponsor: str = "Brightline"


@dataclass
class CareerOutcome:
    failed: bool
    failure_reason: str
    final_cash: float
    final_board_confidence: float
    highest_series_index: int
    promotions: int
    academy_recruits: int
    academy_promotions: int
    regulation_loss: float
    final_driver_rating: float
    average_facility_level: float


@dataclass
class SimulationReport:
    config: dict[str, Any]
    summary: dict[str, Any]
    seasons: list[dict[str, Any]]
    thresholds: dict[str, Any]
    violations: list[dict[str, Any]]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    position = (len(ordered) - 1) * percentile
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(ordered[lower])
    return float(ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower))


def _initial_ai_teams(rng: random.Random) -> list[TeamState]:
    teams: list[TeamState] = []
    for series_index, series in enumerate(SERIES):
        # Ten organizations per tier are enough to expose dynasties, financial
        # pressure, and promotion churn without making CI runs expensive.
        for slot in range(10):
            rating = series.base_rating + rng.uniform(-4.5, 4.5)
            manufacturer = "Independent" if rng.random() < 0.35 else rng.choice(MANUFACTURERS[1:])
            teams.append(
                TeamState(
                    team_id=f"s{series_index}_team_{slot:02d}",
                    series_index=series_index,
                    rating=rating,
                    engineering=rating + rng.uniform(-5.0, 5.0),
                    staff=rating + rng.uniform(-6.0, 6.0),
                    strategy=rating + rng.uniform(-6.0, 6.0),
                    budget=series.car_price * 2 + series.estimated_race_cost * series.season_length,
                    manufacturer=manufacturer,
                    sponsor=rng.choice(SPONSORS),
                    development_multiplier=rng.uniform(0.88, 1.14),
                )
            )
    return teams


def _regulation_reset(teams: list[TeamState], player: PlayerState, rng: random.Random) -> int:
    reset = rng.randint(2, 10)
    for team in teams:
        resilience = (team.engineering - 45.0) / 140.0
        loss = reset * rng.uniform(0.35, 0.82) * (1.0 - max(0.0, resilience))
        team.rating = max(30.0, team.rating - loss)
    player_resilience = player.facilities["design_office"] * 0.08
    player_loss = reset * rng.uniform(0.42, 0.88) * (1.0 - player_resilience)
    player.rating = max(SERIES[player.series_index].base_rating - 8.0, player.rating - player_loss)
    player.regulation_loss += player_loss
    return reset


def _rank_series(
    teams: list[TeamState],
    player: PlayerState,
    rng: random.Random,
) -> tuple[dict[int, list[TeamState]], dict[int, str], int]:
    rankings: dict[int, list[TeamState]] = {}
    champions: dict[int, str] = {}
    player_position = SERIES[player.series_index].field_size
    for series_index in range(len(SERIES)):
        field = [team for team in teams if team.series_index == series_index]
        scored = [(team.strength() + rng.gauss(0.0, 4.5), team) for team in field]
        if series_index == player.series_index:
            facility_bonus = (
                player.facilities["design_office"] * 0.8
                + player.facilities["quality_lab"] * 0.55
                + player.facilities["simulator"] * 0.45
            )
            manufacturer_bonus = 0.0 if player.manufacturer == "Independent" else 1.2
            player_score = player.rating * 0.68 + player.driver_rating * 0.32 + facility_bonus + manufacturer_bonus + rng.gauss(0.0, 4.5)
            player_position = 1 + sum(score > player_score for score, _team in scored)
            if not scored or player_score > max(score for score, _team in scored):
                champions[series_index] = "player"
            else:
                champions[series_index] = max(scored, key=lambda item: item[0])[1].team_id
        elif scored:
            champions[series_index] = max(scored, key=lambda item: item[0])[1].team_id
        field.sort(key=lambda team: next(score for score, candidate in scored if candidate is team), reverse=True)
        for position, team in enumerate(field, start=1):
            team.last_position = position
        rankings[series_index] = field
    return rankings, champions, player_position


def _develop_ai(
    rankings: dict[int, list[TeamState]],
    difficulty: Difficulty,
    rng: random.Random,
) -> tuple[int, int]:
    distressed = 0
    replaced = 0
    for series_index, ranked in rankings.items():
        series = SERIES[series_index]
        season_cost = series.estimated_race_cost * series.season_length
        for position, team in enumerate(ranked, start=1):
            commercial = 1.35 - (position - 1) * (0.65 / max(1, len(ranked) - 1))
            revenue = season_cost * commercial + series.car_price * 0.16
            expenses = season_cost * (0.82 + team.staff / 500.0)
            team.budget += revenue - expenses
            reserve = season_cost * 0.55
            investment_cap = series.car_price * 0.20 * team.development_multiplier
            investment = min(max(0.0, team.budget - reserve), investment_cap)
            team.budget -= investment
            investment_rate = investment / max(1.0, investment_cap)
            development_quality = (team.engineering * 0.55 + team.staff * 0.25 + team.strategy * 0.20) / 100.0
            pressure = 0.45 if position > len(ranked) / 2 else 0.18
            gain = development_quality * investment_rate * 4.6 * team.development_multiplier
            gain -= pressure * difficulty.development_pressure
            if team.manufacturer != "Independent":
                gain += 0.18
            team.rating = min(100.0, max(30.0, team.rating + gain))
            if investment_rate > 0.72:
                team.engineering = min(100.0, team.engineering + 0.7)
            if position <= max(1, len(ranked) // 3):
                team.strategy = min(100.0, team.strategy + 0.45)
            if team.budget < season_cost / 2:
                distressed += 1
                team.financial_status = "Under pressure" if team.budget < 0 else "Limited"
            else:
                team.financial_status = "Stable"
            if team.budget < -season_cost * 0.35:
                replaced += 1
                team.budget = series.car_price + season_cost * 0.65
                team.rating = max(series.base_rating - 7.0, 30.0)
                team.engineering = max(series.base_rating - 5.0, 35.0)
                team.staff = max(series.base_rating - 7.0, 35.0)
                team.strategy = max(series.base_rating - 7.0, 35.0)
                team.manufacturer = "Independent"
    return distressed, replaced


def _move_ai_teams(rankings: dict[int, list[TeamState]]) -> int:
    moved: set[str] = set()
    movements = 0
    for upper_index in range(len(SERIES) - 1, 0, -1):
        lower = next((team for team in rankings[upper_index - 1] if team.team_id not in moved), None)
        upper = next((team for team in reversed(rankings[upper_index]) if team.team_id not in moved), None)
        if lower is None or upper is None:
            continue
        lower.series_index = upper_index
        upper.series_index = upper_index - 1
        lower.movement_count += 1
        upper.movement_count += 1
        moved.update((lower.team_id, upper.team_id))
        movements += 2
    return movements


def _evolve_manufacturers(teams: list[TeamState], rankings: dict[int, list[TeamState]], rng: random.Random) -> int:
    allied = 0
    for ranked in rankings.values():
        if not ranked:
            continue
        for team in ranked[:3]:
            if team.manufacturer == "Independent" and rng.random() < 0.30:
                team.manufacturer = rng.choice(MANUFACTURERS[1:])
        for team in ranked[-3:]:
            if team.manufacturer != "Independent" and rng.random() < 0.16:
                team.manufacturer = "Independent"
        if len(ranked) >= 2 and rng.random() < 0.55:
            candidates = sorted(ranked, key=lambda team: (team.engineering, team.team_id))[:4]
            first, second = rng.sample(candidates, 2)
            partner = first.manufacturer if first.manufacturer != "Independent" else rng.choice(MANUFACTURERS[1:])
            first.manufacturer = partner
            second.manufacturer = partner
            first.engineering = min(100.0, first.engineering + 1.0)
            second.engineering = min(100.0, second.engineering + 1.0)
            allied += 2
    return allied


def _evolve_sponsors(
    rankings: dict[int, list[TeamState]], player: PlayerState, finishing_position: int, rng: random.Random
) -> int:
    changes = 0
    premium_sponsors = SPONSORS[:4]
    for ranked in rankings.values():
        for position, team in enumerate(ranked, start=1):
            change_chance = 0.28 if position <= 3 or position > max(3, len(ranked) - 3) else 0.10
            if rng.random() < change_chance:
                available = premium_sponsors if position <= 3 else SPONSORS
                new_sponsor = rng.choice(available)
                changes += int(new_sponsor != team.sponsor)
                team.sponsor = new_sponsor
    if rng.random() < (0.30 if finishing_position <= 5 else 0.12):
        available = premium_sponsors if finishing_position <= 5 else SPONSORS
        new_sponsor = rng.choice(available)
        changes += int(new_sponsor != player.sponsor)
        player.sponsor = new_sponsor
    return changes


def _player_season(
    player: PlayerState,
    finishing_position: int,
    regulation_reset: int,
    difficulty: Difficulty,
    rng: random.Random,
) -> tuple[float, float, bool, float, float]:
    series = SERIES[player.series_index]
    base_cost = series.estimated_race_cost * series.season_length
    payroll = base_cost * (0.24 + player.driver_rating / 420.0) * difficulty.salary_multiplier
    repairs = base_cost * rng.uniform(0.10, 0.22) * difficulty.repair_multiplier
    upkeep = sum(FACILITIES[name][1] * level * 52 for name, level in player.facilities.items())
    operating_cost = base_cost * difficulty.weekend_multiplier + payroll + repairs + upkeep

    performance_factor = 1.24 - min(finishing_position - 1, 19) * 0.022
    sponsor_income = base_cost * 1.48 * series.sponsor_multiplier * difficulty.sponsor_multiplier * performance_factor
    distribution = base_cost * 0.28
    payout = series.payouts[finishing_position - 1] if finishing_position <= len(series.payouts) else 0
    revenue = sponsor_income + distribution + payout * difficulty.prize_multiplier
    cash_change = revenue - operating_cost
    player.cash += cash_change

    reserve = max(12_000.0, base_cost * 0.72 * difficulty.reserve_multiplier)
    if player.cash < 10_000 and not player.recovery_funding_used:
        player.cash += 15_000
        player.recovery_funding_used = True

    met_finish = finishing_position <= max(5, math.ceil(series.field_size * 0.30))
    met_finance = player.cash >= reserve * 0.35
    confidence_delta = (6 if met_finish else -5) + (6 if met_finance else -5)
    player.board_confidence = min(100.0, max(0.0, player.board_confidence + confidence_delta))
    player.job_security = min(100.0, max(0.0, player.job_security + confidence_delta))

    # Recover some regulation performance through ordinary development spending.
    development_budget = min(max(0.0, player.cash - reserve), series.car_price * 0.10)
    if development_budget >= series.car_price * 0.04:
        player.cash -= development_budget
        recovery = (development_budget / max(1.0, series.car_price * 0.10)) * (1.4 + player.facilities["design_office"] * 0.35)
        player.rating = min(series.base_rating + 10.0, player.rating + recovery)

    _manage_facilities(player, reserve)
    _develop_academy(player, reserve, rng)

    promoted = _try_player_promotion(player, finishing_position, reserve)
    if not promoted:
        player.driver_rating = min(92.0, player.driver_rating + rng.uniform(0.10, 0.95))
    if player.manufacturer == "Independent" and finishing_position <= 5 and rng.random() < 0.26:
        player.manufacturer = rng.choice(MANUFACTURERS[1:])
    elif player.manufacturer != "Independent" and finishing_position > 12 and rng.random() < 0.12:
        player.manufacturer = "Independent"

    insolvency_floor = -max(20_000.0, base_cost * 0.45)
    if player.cash < insolvency_floor:
        player.failed = True
        player.failure_reason = "insolvency"
    elif player.job_security <= 10 or player.board_confidence <= 8:
        player.failed = True
        player.failure_reason = "board dismissal"
    return cash_change, operating_cost, promoted, payroll, upkeep


def _manage_facilities(player: PlayerState, reserve: float) -> None:
    priorities = ("driver_academy", "design_office", "quality_lab", "simulator", "medical_centre")
    for name in priorities:
        level = player.facilities[name]
        if level >= 3:
            continue
        cost = FACILITIES[name][0] * (level + 1)
        annual_upkeep = FACILITIES[name][1] * (level + 1) * 52
        if player.cash >= reserve + cost + annual_upkeep * 4:
            player.cash -= cost
            player.facilities[name] = level + 1
            return


def _develop_academy(player: PlayerState, reserve: float, rng: random.Random) -> None:
    academy_level = player.facilities["driver_academy"]
    if len(player.academy) < 2:
        recruit_cost = rng.randint(1_800, 5_200)
        if player.cash >= reserve + recruit_cost:
            overall = rng.randint(max(38, int(player.driver_rating) - 20), max(45, int(player.driver_rating) - 7))
            potential = rng.randint(max(66, overall + 10), 94)
            player.cash -= recruit_cost
            player.academy.append(Prospect(float(overall), float(potential)))
            player.academy_recruits += 1
    promoted: Prospect | None = None
    for prospect in player.academy:
        prospect.seasons += 1
        prospect.overall = min(prospect.potential, prospect.overall + rng.randint(1, 4) + academy_level)
        if prospect.seasons >= 4 and prospect.overall >= player.driver_rating + 1.0:
            promoted = prospect
            break
    if promoted is not None:
        player.driver_rating = promoted.overall
        player.academy.remove(promoted)
        player.academy_promotions += 1


def _try_player_promotion(player: PlayerState, finishing_position: int, reserve: float) -> bool:
    if finishing_position > 3 or player.series_index >= len(SERIES) - 1:
        return False
    target = SERIES[player.series_index + 1]
    while player.hq_level < target.hq_level and player.hq_level <= len(HQ_UPGRADE_COSTS):
        hq_cost = HQ_UPGRADE_COSTS[player.hq_level - 1]
        if player.cash < reserve + hq_cost:
            return False
        player.cash -= hq_cost
        player.hq_level += 1
    move_cost = target.entry_cost + target.car_price
    if player.cash < reserve + move_cost:
        return False
    player.cash -= move_cost
    player.series_index += 1
    player.promotions += 1
    player.rating = max(player.rating, target.base_rating - 2.0)
    return True


def _commercial_shares(teams: list[TeamState], player: PlayerState) -> tuple[float, float, float]:
    counts = Counter(team.manufacturer for team in teams)
    counts[player.manufacturer] += 1
    total = sum(counts.values())
    top_non_independent = max((count for name, count in counts.items() if name != "Independent"), default=0)
    sponsor_counts = Counter(team.sponsor for team in teams)
    sponsor_counts[player.sponsor] += 1
    sponsor_top_share = max(sponsor_counts.values(), default=0) / max(1, sum(sponsor_counts.values()))
    return (
        top_non_independent / max(1, total),
        counts["Independent"] / max(1, total),
        sponsor_top_share,
    )


def _simulate_career(
    difficulty_name: str,
    seasons: int,
    seed: int,
) -> tuple[CareerOutcome, list[dict[str, Any]], Counter[str], int, float, int]:
    difficulty = DIFFICULTIES[difficulty_name]
    rng = random.Random(seed)
    teams = _initial_ai_teams(rng)
    player = PlayerState(cash=float(difficulty.starting_cash - 6_500))
    rows: list[dict[str, Any]] = []
    champions: Counter[str] = Counter()
    series_champions: dict[int, Counter[str]] = defaultdict(Counter)
    previous_champion: dict[int, str] = {}
    current_streak: dict[int, int] = defaultdict(int)
    series_longest_streak: dict[int, int] = defaultdict(int)
    longest_streak = 0
    total_team_seasons = 0
    total_distressed = 0

    for season_number in range(1, seasons + 1):
        regulation_reset = _regulation_reset(teams, player, rng)
        rankings, season_champions, player_position = _rank_series(teams, player, rng)
        for series_index, champion in season_champions.items():
            champions[champion] += 1
            series_champions[series_index][champion] += 1
            if previous_champion.get(series_index) == champion:
                current_streak[series_index] += 1
            else:
                current_streak[series_index] = 1
                previous_champion[series_index] = champion
            series_longest_streak[series_index] = max(
                series_longest_streak[series_index], current_streak[series_index]
            )
            if champion != "player":
                team = next((candidate for candidate in teams if candidate.team_id == champion), None)
                if team is not None:
                    team.championships += 1

        ai_rating_before = mean(team.rating for team in teams)
        distressed, replaced = _develop_ai(rankings, difficulty, rng)
        ai_development = mean(team.rating for team in teams) - ai_rating_before
        movements = _move_ai_teams(rankings)
        allied = _evolve_manufacturers(teams, rankings, rng)
        sponsor_changes = _evolve_sponsors(rankings, player, player_position, rng)
        total_team_seasons += len(teams)
        total_distressed += distressed
        cash_change, operating_cost, promoted, payroll, facility_upkeep = _player_season(
            player, player_position, regulation_reset, difficulty, rng
        )
        top_share, independent_share, sponsor_top_share = _commercial_shares(teams, player)
        ai_ratings = [team.rating for team in teams]
        rows.append(
            {
                "season": season_number,
                "active": not player.failed,
                "cash": round(player.cash, 2),
                "cash_change": round(cash_change, 2),
                "operating_cost": round(operating_cost, 2),
                "payroll": round(payroll, 2),
                "facility_upkeep": round(facility_upkeep, 2),
                "average_facility_level": round(mean(player.facilities.values()), 4),
                "board_confidence": round(player.board_confidence, 2),
                "job_security": round(player.job_security, 2),
                "series_index": player.series_index,
                "finishing_position": player_position,
                "player_rating": round(player.rating, 2),
                "academy_recruits": player.academy_recruits,
                "academy_promotions": player.academy_promotions,
                "regulation_reset": regulation_reset,
                "ai_average_rating": round(mean(ai_ratings), 2),
                "ai_average_development": round(ai_development, 4),
                "ai_rating_spread": round(max(ai_ratings) - min(ai_ratings), 2),
                "ai_distressed": distressed,
                "ai_replacements": replaced,
                "ai_movements": movements,
                "allied_teams": allied,
                "manufacturer_top_share": round(top_share, 4),
                "independent_share": round(independent_share, 4),
                "sponsor_top_share": round(sponsor_top_share, 4),
                "sponsor_changes": sponsor_changes,
                "promoted": promoted,
            }
        )
        if player.failed:
            break

    longest_streak = max(series_longest_streak.values(), default=0)
    champion_concentration = max(
        (
            max(counts.values(), default=0) / max(1, sum(counts.values()))
            for counts in series_champions.values()
        ),
        default=0.0,
    )
    outcome = CareerOutcome(
        failed=player.failed,
        failure_reason=player.failure_reason,
        final_cash=player.cash,
        final_board_confidence=player.board_confidence,
        highest_series_index=player.series_index,
        promotions=player.promotions,
        academy_recruits=player.academy_recruits,
        academy_promotions=player.academy_promotions,
        regulation_loss=player.regulation_loss,
        final_driver_rating=player.driver_rating,
        average_facility_level=mean(player.facilities.values()),
    )
    return (
        outcome,
        rows,
        champions,
        longest_streak,
        champion_concentration,
        total_distressed * 1_000_000 // max(1, total_team_seasons),
    )


def simulate(
    difficulty: str = "Club",
    careers: int = 64,
    seasons: int = 20,
    seed: int = 2026,
    thresholds: dict[str, Any] | None = None,
) -> SimulationReport:
    if difficulty not in DIFFICULTIES:
        raise ValueError(f"Unknown difficulty: {difficulty}")
    if careers < 1 or seasons < 1:
        raise ValueError("careers and seasons must both be positive")

    outcomes: list[CareerOutcome] = []
    season_rows: dict[int, list[dict[str, Any]]] = defaultdict(list)
    champions: Counter[str] = Counter()
    longest_streak = 0
    champion_concentrations: list[float] = []
    distress_rates: list[float] = []
    for career_index in range(careers):
        career_seed = seed + career_index * 1_000_003
        outcome, rows, career_champions, career_streak, career_concentration, distress_scaled = _simulate_career(
            difficulty, seasons, career_seed
        )
        outcomes.append(outcome)
        champions.update(career_champions)
        longest_streak = max(longest_streak, career_streak)
        champion_concentrations.append(career_concentration)
        distress_rates.append(distress_scaled / 1_000_000.0)
        for row in rows:
            season_rows[int(row["season"])].append(row)

    final_cash = [outcome.final_cash for outcome in outcomes]
    total_recruits = sum(outcome.academy_recruits for outcome in outcomes)
    total_academy_promotions = sum(outcome.academy_promotions for outcome in outcomes)
    total_championships = sum(champions.values())
    champion_concentration = mean(champion_concentrations)
    runaway_wealth_rate = sum(
        outcome.final_cash
        > 5.0
        * SERIES[outcome.highest_series_index].estimated_race_cost
        * SERIES[outcome.highest_series_index].season_length
        for outcome in outcomes
    ) / careers
    failure_reasons = Counter(outcome.failure_reason for outcome in outcomes if outcome.failed)
    season_report = [_aggregate_season(number, season_rows[number], careers) for number in sorted(season_rows)]
    summary: dict[str, Any] = {
        "career_failure_rate": round(sum(outcome.failed for outcome in outcomes) / careers, 6),
        "insolvency_rate": round(failure_reasons["insolvency"] / careers, 6),
        "board_dismissal_rate": round(failure_reasons["board dismissal"] / careers, 6),
        "median_final_cash": round(median(final_cash), 2),
        "final_cash_p10": round(_percentile(final_cash, 0.10), 2),
        "final_cash_p90": round(_percentile(final_cash, 0.90), 2),
        "runaway_wealth_rate": round(runaway_wealth_rate, 6),
        "average_final_board_confidence": round(mean(outcome.final_board_confidence for outcome in outcomes), 4),
        "average_highest_series_index": round(mean(outcome.highest_series_index for outcome in outcomes), 4),
        "promotion_rate": round(sum(outcome.promotions > 0 for outcome in outcomes) / careers, 6),
        "average_promotions_per_career": round(mean(outcome.promotions for outcome in outcomes), 6),
        "academy_seat_conversion_rate": round(total_academy_promotions / max(1, total_recruits), 6),
        "average_academy_recruits": round(total_recruits / careers, 4),
        "average_regulation_performance_loss": round(mean(outcome.regulation_loss for outcome in outcomes), 4),
        "average_final_driver_rating": round(mean(outcome.final_driver_rating for outcome in outcomes), 4),
        "average_final_facility_level": round(mean(outcome.average_facility_level for outcome in outcomes), 4),
        "average_annual_payroll": round(mean(float(row["payroll"]) for rows in season_rows.values() for row in rows), 2),
        "average_annual_facility_upkeep": round(mean(float(row["facility_upkeep"]) for rows in season_rows.values() for row in rows), 2),
        "ai_average_annual_development": round(mean(float(row["ai_average_development"]) for rows in season_rows.values() for row in rows), 6),
        "ai_financial_distress_rate": round(mean(distress_rates), 6),
        "champion_concentration": round(champion_concentration, 6),
        "unique_champions": len(champions),
        "longest_championship_streak": longest_streak,
        "manufacturer_top_share": round(max((row["manufacturer_top_share"] for row in season_report), default=0.0), 6),
        "sponsor_top_share": round(max((row["sponsor_top_share"] for row in season_report), default=0.0), 6),
        "average_independent_share": round(mean(row["independent_share"] for row in season_report), 6),
        "career_season_completion_rate": round(sum(len(season_rows[number]) for number in season_rows) / (careers * seasons), 6),
    }
    selected_thresholds = thresholds or {}
    violations = evaluate_thresholds(summary, selected_thresholds)
    return SimulationReport(
        config={"difficulty": difficulty, "careers": careers, "seasons": seasons, "seed": seed},
        summary=summary,
        seasons=season_report,
        thresholds=selected_thresholds,
        violations=violations,
    )


def _aggregate_season(season: int, rows: list[dict[str, Any]], careers: int) -> dict[str, Any]:
    cash = [float(row["cash"]) for row in rows]
    return {
        "season": season,
        "active_careers": len(rows),
        "survival_rate": round(len(rows) / careers, 6),
        "median_cash": round(median(cash), 2),
        "cash_p10": round(_percentile(cash, 0.10), 2),
        "cash_p90": round(_percentile(cash, 0.90), 2),
        "average_board_confidence": round(mean(float(row["board_confidence"]) for row in rows), 4),
        "average_series_index": round(mean(int(row["series_index"]) for row in rows), 4),
        "average_finish": round(mean(int(row["finishing_position"]) for row in rows), 4),
        "average_player_rating": round(mean(float(row["player_rating"]) for row in rows), 4),
        "average_ai_rating": round(mean(float(row["ai_average_rating"]) for row in rows), 4),
        "average_ai_development": round(mean(float(row["ai_average_development"]) for row in rows), 6),
        "ai_rating_spread": round(mean(float(row["ai_rating_spread"]) for row in rows), 4),
        "average_payroll": round(mean(float(row["payroll"]) for row in rows), 2),
        "average_facility_upkeep": round(mean(float(row["facility_upkeep"]) for row in rows), 2),
        "average_facility_level": round(mean(float(row["average_facility_level"]) for row in rows), 4),
        "ai_distressed_teams": sum(int(row["ai_distressed"]) for row in rows),
        "ai_replacements": sum(int(row["ai_replacements"]) for row in rows),
        "ai_movements": sum(int(row["ai_movements"]) for row in rows),
        "academy_promotions": sum(int(row["academy_promotions"]) for row in rows),
        "average_regulation_reset": round(mean(int(row["regulation_reset"]) for row in rows), 4),
        "manufacturer_top_share": round(mean(float(row["manufacturer_top_share"]) for row in rows), 6),
        "sponsor_top_share": round(mean(float(row["sponsor_top_share"]) for row in rows), 6),
        "sponsor_changes": sum(int(row["sponsor_changes"]) for row in rows),
        "independent_share": round(mean(float(row["independent_share"]) for row in rows), 6),
        "allied_teams": sum(int(row["allied_teams"]) for row in rows),
    }


def load_thresholds(path: Path, difficulty: str) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return payload.get(difficulty, payload.get("default", {}))


def evaluate_thresholds(summary: dict[str, Any], thresholds: dict[str, Any]) -> list[dict[str, Any]]:
    violations: list[dict[str, Any]] = []
    for metric, rule_value in thresholds.items():
        rule = rule_value if isinstance(rule_value, dict) else {"max": rule_value}
        if metric not in summary:
            violations.append({"metric": metric, "reason": "metric missing from report"})
            continue
        value = float(summary[metric])
        minimum = rule.get("min")
        maximum = rule.get("max")
        if minimum is not None and value < float(minimum):
            violations.append({"metric": metric, "value": value, "expected": f">= {minimum}", "reason": rule.get("reason", "below minimum")})
        if maximum is not None and value > float(maximum):
            violations.append({"metric": metric, "value": value, "expected": f"<= {maximum}", "reason": rule.get("reason", "above maximum")})
    return violations


def write_json(report: SimulationReport, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report.to_dict(), indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_csv(report: SimulationReport, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = report.seasons
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def print_report(report: SimulationReport) -> None:
    config = report.config
    summary = report.summary
    print(
        f"{config['difficulty']}: {config['careers']} careers x "
        f"{config['seasons']} seasons (seed {config['seed']})"
    )
    print(
        "Career survival: "
        f"{1.0 - summary['career_failure_rate']:.1%} "
        f"(insolvency {summary['insolvency_rate']:.1%}, board dismissals {summary['board_dismissal_rate']:.1%})"
    )
    print(
        f"Final cash: median ${summary['median_final_cash']:,.0f} "
        f"(P10 ${summary['final_cash_p10']:,.0f}, P90 ${summary['final_cash_p90']:,.0f})"
    )
    print(
        f"Promotion: {summary['promotion_rate']:.1%} reached a higher series; "
        f"{summary['average_promotions_per_career']:.2f} moves per career"
    )
    print(f"Academy-to-seat conversion: {summary['academy_seat_conversion_rate']:.1%}")
    print(
        f"AI financial distress: {summary['ai_financial_distress_rate']:.1%}; "
        f"champion concentration: {summary['champion_concentration']:.1%}; "
        f"longest title streak: {summary['longest_championship_streak']}"
    )
    print(
        f"Peak manufacturer share: {summary['manufacturer_top_share']:.1%}; "
        f"peak sponsor share: {summary['sponsor_top_share']:.1%}; "
        f"average independent share: {summary['average_independent_share']:.1%}"
    )
    if report.violations:
        print("Threshold violations:")
        for violation in report.violations:
            print(
                f"- {violation['metric']}: {violation.get('value', 'missing')} "
                f"(expected {violation.get('expected', 'present')}) — {violation['reason']}"
            )
    elif report.thresholds:
        print(f"All {len(report.thresholds)} long-career balance thresholds passed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--difficulty", choices=DIFFICULTIES, default="Club")
    parser.add_argument("--careers", type=int, default=64, help="Independent careers to simulate")
    parser.add_argument("--seasons", type=int, default=20, help="Maximum seasons per career")
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--thresholds", type=Path, default=DEFAULT_THRESHOLDS)
    parser.add_argument("--json", dest="json_path", type=Path, help="Write the complete JSON report")
    parser.add_argument("--csv", dest="csv_path", type=Path, help="Write per-season aggregate CSV data")
    parser.add_argument("--fail-on-threshold", action="store_true", help="Exit non-zero when a configured threshold is violated")
    args = parser.parse_args()

    selected_thresholds = load_thresholds(args.thresholds, args.difficulty) if args.thresholds else {}
    report = simulate(
        difficulty=args.difficulty,
        careers=max(1, args.careers),
        seasons=max(1, args.seasons),
        seed=args.seed,
        thresholds=selected_thresholds,
    )
    print_report(report)
    if args.json_path:
        write_json(report, args.json_path)
    if args.csv_path:
        write_csv(report, args.csv_path)
    return 1 if args.fail_on_threshold and report.violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
