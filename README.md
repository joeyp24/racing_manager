# Racing Manager

## Economy balance simulation

Run `python3 tools/balance_simulation.py --difficulty Club --seasons 500` to exercise the
career economy with a deterministic Monte Carlo model. The report includes bankruptcy
rate, cash after each race, finishing position, upgrade timing, and modeled ROI for every
part family and department. Use `--seed` to reproduce a run or compare balance changes.

A stock-car motorsports management game built in Godot 4.x.

The goal of the game is to let the player build a racing team by purchasing cars, entering races, earning prize money, repairing vehicles, progressing through a championship season, and eventually competing for the championship.

---

# Project Standards

## Naming Convention

Always follow these conventions throughout the project.

### Files

Use **lowercase with underscores**.

Example:

```
race_manager.gd
race_results.gd
car_inspection.gd
```

---

### Functions

Use **snake_case**.

Example:

```gdscript
func update_display():
func calculate_prize_money():
func load_selected_car():
```

---

### Variables

Use **snake_case**.

Example:

```gdscript
team_money
selected_car
player_score
repair_cost
```

---

### Scene Nodes

Use **snake_case**.

Example:

```
repair_button
status_label
race_name_label
page_container
```

---

### Classes

Use **PascalCase**.

Example:

```gdscript
class_name Race
class_name Team
class_name RaceResult
```

---

# Coding Style

Prefer readable code over compact code.

Use descriptive variable names.

Avoid one-line nested expressions when a few extra lines improve readability.

Keep functions focused on one task.

Always use proper indentation.

---

# AI Development Guidelines

When modifying existing scripts:

**Rewrite the entire file whenever practical.**

Do NOT provide partial patches or isolated snippets unless specifically requested.

The project owner prefers replacing an entire script over manually merging changes.

When adding new features:

- Preserve existing functionality.
- Do not remove working systems.
- Keep changes compatible with save/load.
- Build on the current architecture rather than replacing it.

---

# Current Gameplay Loop

```
Buy Car
	↓
Garage
	↓
Enter Race
	↓
Pay Entry Fee
	↓
Race Simulation
	↓
Race Results
	↓
Car Wear
	↓
Repair
	↓
Next Race
```

---

# Current Systems

Implemented:

- Dashboard
- Garage
- Dealership
- Buy Cars
- Sell Cars
- Car Inspection
- Repairs
- Save / Load
- Dynamic Dealership Inventory
- Race Calendar
- Race Entry
- Race Simulation
- Race Results
- Team Money
- Season Progression
- Championship Points
- 12-race seasons
- Position-based season prize money
- Repeatable seasons
- Eight-tier career series ladder with entry fees and Team HQ promotion requirements
- Series-specific dealership inventories and fictional driver fields sized to real-world grids

## Series progression

Teams begin in the Local Short Track Series. Promotion proceeds through Regional and
National Short Track competition, the fictional Continental East/West and Continental
National levels, then the National Truck, National Grand, and Premier Cup series.
Upgrading Team HQ and paying the one-time series entry fee are both required before
promotion. Cars are homologated to one series, and each entered series has its own
dealership inventory.

---

# GameManager

GameManager is an AutoLoad.

It owns:

```gdscript
team
selected_car
selected_bay
selected_race
page_container
```

Money is changed only through:

```gdscript
GameManager.add_team_money()
GameManager.remove_team_money()
```

Never modify team.money directly unless absolutely necessary.

---

# Team

Team stores:

- money
- reputation
- championship_points
- completed_races
- unlocked_races
- owned cars

Season progression is saved directly inside Team.

---

# Race Progression

Each Race resource has a unique:

```gdscript
race_id
```

Example:

```
spring_100
river_raceway
mountain_250
```

Race resources contain static data only.

Progress is stored in Team.

Completed races:

```gdscript
team.completed_races
```

Unlocked races:

```gdscript
team.unlocked_races
```

The Race Calendar determines progression using the order of the exported race array.

---

# Championship

Current points system:

```
1st = 10
2nd = 8
3rd = 6
4th = 5
5th = 4
6th = 3
7th = 2
8th = 1
```

Points are accumulated in:

```gdscript
team.championship_points
```

---

# Resources

## Car

Stores:

- name
- manufacturer
- model
- year
- purchase_price
- value
- performance
- condition
- mileage
- installed engine, suspension, brakes, chassis, drivetrain, and body parts

## Car Parts

Every purchased car receives standard parts. Upgraded parts are bought in the Parts Shop, stored in `team.parts_inventory`, and installed or sold from Car Inspection. Each category improves a distinct vehicle characteristic and contributes to total race performance.

---

## Race

Stores:

- race_id
- race_name
- track_name
- race_date
- lap_count
- difficulty
- entry_fee
- first_place_prize
- second_place_prize
- third_place_prize

Race resources contain only static race data.

---

## RaceResult

Stores:

- race
- player_car
- finishing_position
- field_size
- standings
- prize_money
- entry_fee
- net_earnings
- mileage_added
- condition_lost
- championship_points_earned
- total_championship_points

---

# Save Philosophy

Player progression should be stored in Team whenever possible.

Avoid modifying Resource (.tres) files during gameplay.

Resources define the game.

Team stores the player's progress.

---

# Development Philosophy

Prefer simple, maintainable solutions over clever ones.

Avoid unnecessary abstraction.

If a feature can be implemented cleanly with existing architecture, prefer that over introducing new systems.

Keep the project beginner-friendly and easy to understand.

---

# Validation

Every pull request is checked automatically for:

- duplicate top-level GDScript function declarations
- missing literal `res://` resource paths
- committed temporary or editor-generated files
- source-level gameplay contracts
- Godot project and scene parsing in headless mode
- Performance Points behavioral tests

Run the fast repository checks locally with:

```sh
python tools/validate_project.py
python -m pytest -q tests
```

With Godot 4.7 available on the command line, run the engine checks with:

```sh
python tools/run_godot_checks.py
```

---

# Feature Status

## Implemented and playable

- Multi-season careers, driver and staff contracts, sponsorships, departments, parts, finances, championship standings, and multiple player race teams.
- Live races with deterministic seed injection, tyre compounds, meaningful fuel weight and consumption, refueling, traffic, track-specific pit loss and overtaking, incidents, mechanical DNFs, yellow flags, safety cars, and restarts.
- Versioned, verified atomic career saves with automatic backup recovery and collection repair.

## Implemented but needs balancing

- Track demand profiles and distinct car attributes (power, aero, grip, braking, tyre preservation, fuel efficiency, and reliability).
- Caution frequency, reliability risk, fuel windows, tyre degradation, and adaptive AI pit decisions.
- Economy progression, sponsor objectives, staff bonuses, and AI season development.

## Prototype / experimental

- Practice feedback and setup discovery, persistent rival development, and the team news feed are foundations for deeper authored content.
- Department manufacturing and multi-team race entries may need additional usability passes.

## Next milestone

- Expand practice into multiple timed runs with uncertain feedback and tyre allocation.
- Add event eligibility, invitationals, schedule choices, offseason rules, transfers, rivalries, and richer historical commentary.
- Grow deterministic headless coverage from simulation contracts into complete career journeys.

## Known limitations

- Mechanical setup is locked once the race begins; brake bias is the only live chassis adjustment.
- Weather and injuries are not yet simulated, and the core calendar remains a fixed twelve-event schedule.
- Static race definitions still require manual balancing and visual track maps are not yet available.

---

# Staff and Workshop

The Staff page allows a team to hire one crew chief and up to three engineers.
Crew-chief rating supplies a percentage race-performance boost. Engineers can
manufacture parts and repair worn inventory parts; their rating controls the
quality of manufactured parts and the condition restored by each repair.
Staff work on race-based contracts, receive payroll after every event, and can
be renewed, negotiated with, or released for a termination fee. Specialties
provide smaller role-specific bonuses alongside each staff member's rating.
The Finances page summarizes cash, assets, salaries, projected payroll, and a
persistent history of race, sponsor, workshop, staff, and purchasing activity.
