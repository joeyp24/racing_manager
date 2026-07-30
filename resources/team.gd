extends Resource
class_name Team

const GARAGE_SIZE: int = 6
const MAX_ENGINEERS: int = 3
const ROLE_LIMITS: Dictionary = {
	"Crew Chief": 1,
	"Engineer": 3,
	"Mechanic": 3,
	"Spotter": 1,
	"Pit Crew": 5
}
const MANUFACTURING_BASE_COST: int = 1800
const PART_REPAIR_COST_PER_POINT: int = 12
const MAX_RACE_TEAMS: int = 4
const RACE_TEAM_EXPANSION_COST: int = 25000
const CURRENT_SAVE_FORMAT_VERSION: int = 13
const ENGINEERING_PROJECT_DAYS: int = 14
const DRIVER_TRAINING_DAYS: int = 14
const XP_PER_LEVEL: int = 100
const BASE_SCOUTING_HOURS: int = 20
const SCOUTING_HOURS_PER_LEVEL: int = 10
const CAREER_EXPANSION_MANAGER_PATH: String = "res://resources/career_expansion_manager.gd"
const SCOUTING_ACTIONS: Dictionary = {
	"Current ability": {"hours": 10, "reveal": "ratings"},
	"Potential": {"hours": 15, "reveal": "potential"},
	"Background": {"hours": 5, "reveal": "background"},
	"Recruit": {"hours": 10, "reveal": "recruiting"}
}

@export var team_name: String = "My Team"
@export var hometown: String = "Charlotte, NC"
@export var team_motto: String = "Built to compete"
@export var primary_color: Color = Color("e9421e")
@export var secondary_color: Color = Color("172033")
@export var accent_color: Color = Color("f4f6fa")
@export_enum("Diamond", "Shield", "Bolt", "Flag") var team_badge: String = "Diamond"
@export var tutorial_completed: bool = false
@export var last_saved_unix_time: int = 0
@export var save_format_version: int = CURRENT_SAVE_FORMAT_VERSION
@export var money: int = 50000
@export_enum("Rookie", "Club", "Pro") var career_difficulty: String = "Club"
@export var recovery_funding_used: bool = false
@export var reputation: int = 0
@export var reputation_state: Dictionary = {}
@export var scouting_hours_remaining: int = -1
@export var scouting_hours_week: int = 0
@export var recruiting_progress: Dictionary = {}
@export var contract_offers: Dictionary = {}
@export var hq_level: int = 1
@export var current_series_id: String = "local_short_track"
@export var entered_series_ids: Array[String] = ["local_short_track"]
@export var championship_points: int = 0
@export var season_number: int = 1
@export var current_season_year: int = 2026
@export var season_complete: bool = false
@export var driver_hired_for_season: bool = false
@export var last_season_position: int = 0
@export var last_season_prize: int = 0
@export var last_development_summary: Array[String] = []
@export var fans: int = 0
@export var department_levels: Dictionary = {}
@export var driver_development_progress: float = 0.0
@export var current_race_week: int = 1
@export var current_season_day: int = CalendarCatalog.SEASON_START_DAY
@export var week_advance_required: bool = false
@export var engineering_projects: Array[Dictionary] = []
@export var scouting_assignments: Array[Dictionary] = []
@export var scouting_reports: Dictionary = {}
@export var driver_training_programs: Dictionary = {}

@export var active_sponsor_id: String = ""
@export var sponsor_races_remaining: int = 0
@export var sponsor_objective_progress: int = 0
@export var sponsor_objective_completed: bool = false
@export var sponsor_signed_season: int = 0
@export var active_sponsor_contract: Dictionary = {}
@export var sponsor_offers: Array[Dictionary] = []
@export var sponsor_offer_season: int = 0
@export var sponsor_offer_series_id: String = ""
@export var sponsor_relationships: Dictionary = {}

@export var completed_races: Array[String] = []

@export var unlocked_races: Array[String] = [
	"spring_100"
]

@export var championship_standings: Array[Dictionary] = []
@export var series_progress: Dictionary = {}
@export var world_series_data: Dictionary = {}
@export var ai_team_career: Dictionary = {}
@export var ai_driver_career: Dictionary = {}
@export var offseason_data: Dictionary = {}
@export var transfer_history: Array[Dictionary] = []
@export var season_history: Array[Dictionary] = []
@export var career_state: Dictionary = {}
@export var drivers: Array[Driver] = []
@export var contracted_driver_ids: Array[String] = []
@export var race_teams: Array[RaceTeam] = []

@export var cars: Array = [
	null,
	null,
	null,
	null,
	null,
	null
]

@export var parts_inventory: Array[CarPart] = []
@export var staff: Array[StaffMember] = []
@export var finance_history: Array[Dictionary] = []

const DIFFICULTY_SETTINGS: Dictionary = {
	"Rookie": {
		"starting_cash": 75000, "sponsor_multiplier": 1.20, "ai_growth": 0.45,
		"repair_multiplier": 0.75, "weekend_cost_multiplier": 0.88,
		"prize_multiplier": 1.15, "salary_multiplier": 0.90, "market_cost_multiplier": 0.90,
		"ai_pace_modifier": 0.96, "ai_strategy_modifier": 0.86,
		"player_incident_multiplier": 0.72
	},
	"Club": {
		"starting_cash": 50000, "sponsor_multiplier": 1.0, "ai_growth": 0.75,
		"repair_multiplier": 1.0, "weekend_cost_multiplier": 1.0,
		"prize_multiplier": 1.0, "salary_multiplier": 1.0, "market_cost_multiplier": 1.0,
		"ai_pace_modifier": 1.0, "ai_strategy_modifier": 1.0,
		"player_incident_multiplier": 1.0
	},
	"Pro": {
		"starting_cash": 42000, "sponsor_multiplier": 0.88, "ai_growth": 1.10,
		"repair_multiplier": 1.25, "weekend_cost_multiplier": 1.05,
		"prize_multiplier": 0.95, "salary_multiplier": 1.05, "market_cost_multiplier": 1.04,
		"ai_pace_modifier": 1.04, "ai_strategy_modifier": 1.12,
		"player_incident_multiplier": 1.24
	}
}


func _init() -> void:
	ensure_series_progress()
	ensure_world_series_data()
	ensure_departments()
	ensure_default_player_driver()
	ensure_driver_market()
	ensure_series_rosters()
	ensure_ai_team_career()
	ensure_ai_driver_career()
	ensure_race_teams()
	ensure_car_parts()
	ensure_staff_market()
	_call_career_expansion_manager(&"ensure_state", [self])


func _call_career_expansion_manager(method: StringName, arguments: Array) -> Variant:
	var manager_script: Script = load(CAREER_EXPANSION_MANAGER_PATH) as Script
	if manager_script == null:
		push_error("Could not load the career expansion manager.")
		return null
	return manager_script.callv(method, arguments)


func set_career_difficulty(value: String) -> void:
	career_difficulty = value if DIFFICULTY_SETTINGS.has(value) else "Club"
	money = int(get_difficulty_setting("starting_cash", 50000))
	emit_changed()


func get_difficulty_setting(key: String, fallback: Variant) -> Variant:
	return (DIFFICULTY_SETTINGS.get(career_difficulty, DIFFICULTY_SETTINGS["Club"]) as Dictionary).get(key, fallback)


func get_effective_weekend_cost(race: Race, entry_count: int = 1) -> int:
	if race == null:
		return 0
	var travel_plan := str((career_state.get("logistics", {}) as Dictionary).get("travel_plan", "Standard"))
	var logistics_multiplier: float = float({"Economy":0.94, "Standard":1.0, "Performance":1.08}.get(travel_plan, 1.0))
	return roundi(float(race.get_weekend_cost() * maxi(1, entry_count)) * float(get_difficulty_setting("weekend_cost_multiplier", 1.0)) * logistics_multiplier)


func get_effective_sponsor_value(base_value: int) -> int:
	var series_multiplier := float(
		SeriesCatalog.get_series(current_series_id).get("sponsor_prestige_multiplier", 1.0)
	)
	return roundi(
		float(base_value)
		* float(get_difficulty_setting("sponsor_multiplier", 1.0))
		* series_multiplier
	)


func get_effective_salary(base_value: int) -> int:
	return roundi(float(base_value) * float(get_difficulty_setting("salary_multiplier", 1.0)))


func accept_owner_investment() -> bool:
	if recovery_funding_used or money >= 10000:
		return false
	recovery_funding_used = true
	money += 15000
	record_finance("Funding", 15000, "Emergency owner investment")
	emit_changed()
	return true


func ensure_departments() -> void:
	for department_id in DepartmentCatalog.get_ids():
		if not department_levels.has(department_id):
			department_levels[department_id] = 0


func ensure_race_week_progression() -> void:
	# Saves created before race weeks existed derive their position from season progress.
	current_race_week = maxi(current_race_week, get_completed_races().size() + (0 if week_advance_required else 1))
	if current_season_day < CalendarCatalog.SEASON_START_DAY or current_season_day > CalendarCatalog.SEASON_END_DAY:
		current_season_day = CalendarCatalog.SEASON_START_DAY
	var completed_count := get_completed_races().size()
	if completed_count > 0 and current_season_day == CalendarCatalog.SEASON_START_DAY:
		var events := CalendarCatalog.get_events(current_series_id)
		current_season_day = int(events[mini(completed_count - 1, events.size() - 1)].schedule_day)
	_migrate_date_driven_projects()


func _migrate_date_driven_projects() -> void:
	# Old saves only knew the race week in which work began. Preserve active work,
	# but give it a fair calendar duration from the date at which the save resumes.
	for project in engineering_projects:
		if not project.has("start_day"):
			project["start_day"] = current_season_day
		if not project.has("completion_day"):
			project["completion_day"] = mini(CalendarCatalog.SEASON_END_DAY, current_season_day + ENGINEERING_PROJECT_DAYS)
	for driver_id in driver_training_programs:
		var program := driver_training_programs[driver_id] as Dictionary
		if not program.has("start_day"):
			program["start_day"] = current_season_day
		if not program.has("completion_day"):
			program["completion_day"] = mini(CalendarCatalog.SEASON_END_DAY, current_season_day + DRIVER_TRAINING_DAYS)


func get_department_level(department_id: String) -> int:
	return clampi(int(department_levels.get(department_id, 0)), 0, DepartmentCatalog.MAX_LEVEL)


func get_hq_upgrade_cost() -> int:
	return get_discounted_cost(SeriesCatalog.get_hq_upgrade_cost(hq_level))


func upgrade_hq() -> bool:
	var cost := get_hq_upgrade_cost()
	if cost <= 0 or money < cost:
		return false
	money -= cost
	hq_level += 1
	record_finance("HQ", -cost, "Upgraded Team HQ to level %d" % hq_level)
	emit_changed()
	return true


func get_reputation_level() -> int:
	return ReputationManager.get_level_for_xp(reputation)


func get_current_level_xp() -> int:
	return reputation - ReputationManager.get_level_start_xp(get_reputation_level())


func get_xp_to_next_level() -> int:
	return get_level_xp_span() - get_current_level_xp()


func get_level_xp_span() -> int:
	return ReputationManager.get_level_span(get_reputation_level())


func get_reputation_tier() -> String:
	return ReputationManager.get_tier_name(get_reputation_level())


func add_reputation_xp(amount: int) -> void:
	if amount <= 0:
		return
	reputation += amount
	emit_changed()


func get_required_level_for_series(series_id: String) -> int:
	return int(SeriesCatalog.get_series(series_id).get("required_level", 1))


func can_enter_series(series_id: String) -> bool:
	var index := SeriesCatalog.get_index(series_id)
	var current_index := SeriesCatalog.get_index(current_series_id)
	if index < 0 or entered_series_ids.has(series_id) or index != current_index + 1:
		return false
	var series := SeriesCatalog.get_series(series_id)
	return is_series_season_complete(current_series_id) and get_reputation_level() >= get_required_level_for_series(series_id) and hq_level >= int(series.hq_level) and money >= get_series_required_cash(series_id)


func get_series_required_cash(series_id: String) -> int:
	var series := SeriesCatalog.get_series(series_id)
	if series.is_empty():
		return 0
	return get_discounted_cost(int(series.entry_cost)) + int(series.car_price) + int(series.estimated_race_cost) * 3


func get_series_entry_requirements(series_id: String) -> Array[String]:
	var unmet: Array[String] = []
	var series := SeriesCatalog.get_series(series_id)
	if not is_series_season_complete(current_series_id): unmet.append("Finish the current season.")
	if not series.is_empty() and get_reputation_level() < get_required_level_for_series(series_id): unmet.append("Reach team level %d (currently level %d)." % [get_required_level_for_series(series_id), get_reputation_level()])
	if not series.is_empty() and hq_level < int(series.hq_level): unmet.append("Upgrade Team HQ to level %d." % int(series.hq_level))
	if not series.is_empty() and money < get_series_required_cash(series_id): unmet.append("Raise $%s for the entry fee, eligible car, and three-race reserve." % String.num_int64(get_series_required_cash(series_id)))
	return unmet


func enter_series(series_id: String) -> bool:
	if not can_enter_series(series_id):
		return false
	var cost := get_discounted_cost(int(SeriesCatalog.get_series(series_id).entry_cost))
	money -= cost
	entered_series_ids.append(series_id)
	current_series_id = series_id
	ensure_series_progress(series_id)
	load_series_progress(series_id)
	record_finance("Series", -cost, "Entered %s" % SeriesCatalog.get_series(series_id).name)
	emit_changed()
	return true


func owns_car_for_series(series_id: String) -> bool:
	for car_value in cars:
		var car := car_value as Car
		if car != null and car.series_id == series_id:
			return true
	return false


func ensure_series_progress(series_id: String = current_series_id) -> void:
	if series_progress.has(series_id):
		return
	var first_race := "spring_100" if series_id == "local_short_track" else "%s_round_01" % series_id
	var is_legacy_season := series_id == "local_short_track"
	series_progress[series_id] = {"completed_races":completed_races.duplicate() if is_legacy_season else [], "unlocked_races":unlocked_races.duplicate() if is_legacy_season else [first_race], "standings":championship_standings.duplicate(true) if is_legacy_season else [], "season_number":season_number if is_legacy_season else 1, "season_complete":season_complete if is_legacy_season else false}


func ensure_world_series_data() -> void:
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		if not world_series_data.has(series_id):
			world_series_data[series_id] = {
				"completed_rounds": 0,
				"results": [],
				"standings": [],
				"season_number": season_number
			}


func get_world_series_data(series_id: String) -> Dictionary:
	ensure_world_series_data()
	return world_series_data.get(series_id, {}) as Dictionary


func set_world_series_data(series_id: String, data: Dictionary) -> void:
	ensure_world_series_data()
	world_series_data[series_id] = data.duplicate(true)
	emit_changed()


func ensure_ai_team_career() -> void:
	if not ai_team_career.is_empty() and save_format_version >= 10:
		var sample := ai_team_career.values()[0] as Dictionary
		if sample.has("career_championships") and sample.has("season_results"):
			return
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		for organization in TeamCatalog.get_teams(series_id):
			var team_id := str(organization.team_id)
			var car_price := int(series.car_price)
			var operating_budget := int(series.estimated_race_cost) * int(series.season_length)
			var defaults := {
				"team_id": team_id,
				"base_team_id": team_id,
				"team_name": str(organization.team_name),
				"current_series_id": series_id,
				"equipment_rating": int(organization.equipment_rating),
				"engineering_rating": int(organization.engineering_rating),
				"staff_quality": int(organization.pit_crew_rating),
				"strategy_rating": int(organization.strategy_rating),
				"budget": car_price * int(organization.driver_count) + operating_budget,
				"trend": 0.0,
				"seasons": 0,
				"last_position": 0,
				"financial_status": "Stable",
				"driver_changes": 0,
				"driver_generation": 0,
				"driver_form": 0,
				"career_championships": int(organization.championships),
				"season_results": [],
				"movement": ""
			}
			var state := ai_team_career.get(team_id, {}) as Dictionary
			defaults.merge(state, true)
			ai_team_career[team_id] = defaults


func get_ai_team_state(team_id: String) -> Dictionary:
	ensure_ai_team_career()
	return ai_team_career.get(team_id, {}) as Dictionary


func get_ai_team_states_for_series(series_id: String) -> Array[Dictionary]:
	ensure_ai_team_career()
	var teams: Array[Dictionary] = []
	for state_value in ai_team_career.values():
		var state := state_value as Dictionary
		if str(state.get("current_series_id", "")) == series_id:
			teams.append(state)
	teams.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first.get("last_position", 0)) == int(second.get("last_position", 0)):
			return str(first.get("team_id", "")) < str(second.get("team_id", ""))
		if int(first.get("last_position", 0)) <= 0:
			return false
		if int(second.get("last_position", 0)) <= 0:
			return true
		return int(first.get("last_position", 0)) < int(second.get("last_position", 0))
	)
	return teams


func get_ai_organizations_for_series(series_id: String) -> Array[Dictionary]:
	var static_teams := TeamCatalog.get_teams(series_id)
	var career_teams := get_ai_team_states_for_series(series_id)
	var organizations: Array[Dictionary] = []
	for index in static_teams.size():
		var organization := static_teams[index].duplicate(true)
		if index < career_teams.size():
			var state := career_teams[index]
			var identity := _get_ai_base_organization(str(state.get("base_team_id", state.team_id)))
			if not identity.is_empty():
				var target_driver_count := int(organization.driver_count)
				organization = identity.duplicate(true)
				organization["series_id"] = series_id
				organization["driver_count"] = target_driver_count
			organization["team_id"] = str(state.team_id)
			organization["team_name"] = str(state.team_name)
			organization["equipment_rating"] = int(state.equipment_rating)
			organization["engineering_rating"] = int(state.engineering_rating)
			organization["pit_crew_rating"] = int(state.staff_quality)
			organization["strategy_rating"] = int(state.strategy_rating)
			organization["overall_rating"] = roundi(_ai_team_strength(state))
			organization["budget"] = int(state.budget)
			organization["trend"] = float(state.trend)
			organization["financial_status"] = str(state.financial_status)
			organization["movement"] = str(state.movement)
			organization["driver_changes"] = int(state.driver_changes)
			organization["championships"] = int(state.get("career_championships", organization.championships))
		organizations.append(organization)
	return organizations


func _get_ai_base_organization(team_id: String) -> Dictionary:
	for series in SeriesCatalog.SERIES:
		var organization := TeamCatalog.get_team(str(series.id), team_id)
		if not organization.is_empty():
			return organization
	return {}


func ensure_ai_driver_career() -> void:
	ensure_series_rosters()
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		var roster := AIRosterCatalog.get_roster(series_id)
		for index in roster.size():
			var roster_entry := roster[index]
			var driver_id := "%s_driver_%02d" % [series_id, index + 1]
			var driver := get_driver_by_id(driver_id)
			if driver == null:
				continue
			var defaults := {
				"driver_id": driver_id,
				"driver_name": driver.driver_name,
				"current_team_id": str(roster_entry.team_id),
				"current_series_id": series_id,
				"car_number": int(roster_entry.team_car_number),
				"age": driver.age,
				"potential": driver.get_potential_overall(),
				"salary": driver.salary,
				"contract_seasons": 1 + index % 3,
				"morale": driver.morale,
				"team_fit": roundi(float(driver.loyalty + driver.teamwork + driver.morale) / 3.0),
				"career_goal": _get_driver_career_goal(driver),
				"retired": false,
				"rookie": false,
				"starts": driver.career_starts,
				"wins": driver.career_wins,
				"podiums": driver.career_podiums,
				"championships": driver.championships,
				"best_championship_finish": driver.best_championship_finish,
				"history": driver.race_history.duplicate(true),
				"season_results": [],
				"team_history": [{"season":current_season_year, "team_id":str(roster_entry.team_id), "series_id":series_id}]
			}
			var state := ai_driver_career.get(driver_id, {}) as Dictionary
			defaults.merge(state, true)
			if contracted_driver_ids.has(driver_id):
				defaults["current_team_id"] = "player_team"
			ai_driver_career[driver_id] = defaults
	for driver in drivers:
		if driver != null:
			ensure_ai_driver_state(driver)


func ensure_ai_driver_state(driver: Driver) -> Dictionary:
	if driver == null:
		return {}
	var state := ai_driver_career.get(driver.driver_id, {}) as Dictionary
	if state.is_empty():
		state = {
			"driver_id": driver.driver_id,
			"driver_name": driver.driver_name,
			"current_team_id": "player_team" if contracted_driver_ids.has(driver.driver_id) else "",
			"current_series_id": driver.series_id,
			"car_number": driver.preferred_number,
			"age": driver.age,
			"potential": driver.get_potential_overall(),
			"salary": driver.salary,
			"contract_seasons": 1,
			"morale": driver.morale,
			"team_fit": roundi(float(driver.loyalty + driver.teamwork + driver.morale) / 3.0),
			"career_goal": _get_driver_career_goal(driver),
			"retired": false,
			"rookie": driver.career_starts == 0,
			"starts": driver.career_starts,
			"wins": driver.career_wins,
			"podiums": driver.career_podiums,
			"championships": driver.championships,
			"best_championship_finish": driver.best_championship_finish,
			"history": driver.race_history.duplicate(true),
			"season_results": [],
			"team_history": []
		}
		ai_driver_career[driver.driver_id] = state
	return state


func get_ai_driver_state(driver_id: String) -> Dictionary:
	if not ai_driver_career.has(driver_id):
		ensure_ai_driver_career()
	return ai_driver_career.get(driver_id, {}) as Dictionary


func get_ai_lineup_for_team(team_id: String) -> Array[Dictionary]:
	if ai_driver_career.is_empty():
		ensure_ai_driver_career()
	var lineup: Array[Dictionary] = []
	for state_value in ai_driver_career.values():
		var state := state_value as Dictionary
		if str(state.get("current_team_id", "")) == team_id and not bool(state.get("retired", false)):
			lineup.append(state)
	lineup.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_driver := get_driver_by_id(str(first.driver_id))
		var second_driver := get_driver_by_id(str(second.driver_id))
		var first_rating := first_driver.get_overall_rating() if first_driver != null else 0
		var second_rating := second_driver.get_overall_rating() if second_driver != null else 0
		if first_rating == second_rating:
			return str(first.driver_id) < str(second.driver_id)
		return first_rating > second_rating
	)
	return lineup


func get_ai_team_slot_count(team_id: String, series_id: String) -> int:
	for organization in get_ai_organizations_for_series(series_id):
		if str(organization.team_id) == team_id:
			return int(organization.driver_count)
	return 1


func get_ai_team_name(team_id: String) -> String:
	var state := get_ai_team_state(team_id)
	return str(state.get("team_name", "Free Agent")) if not state.is_empty() else "Free Agent"


func record_ai_driver_result(driver_id: String, team_id: String, series_id: String, result: Dictionary) -> void:
	var driver := get_driver_by_id(driver_id)
	var state := ensure_ai_driver_state(driver)
	if state.is_empty() or contracted_driver_ids.has(driver_id):
		return
	state["current_team_id"] = team_id
	state["current_series_id"] = series_id
	state["starts"] = int(state.get("starts", 0)) + 1
	var position := int(result.get("position", 0))
	if position == 1:
		state["wins"] = int(state.get("wins", 0)) + 1
	if position > 0 and position <= 3:
		state["podiums"] = int(state.get("podiums", 0)) + 1
	var history := state.get("history", []) as Array
	history.push_front(result.duplicate(true))
	if history.size() > 60:
		history.resize(60)
	state["history"] = history
	ai_driver_career[driver_id] = state
	if driver != null:
		driver.career_starts = int(state.starts)
		driver.career_wins = int(state.wins)
		driver.career_podiums = int(state.podiums)
		driver.record_race(result)


func record_driver_season_results() -> void:
	ensure_ai_driver_career()
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		var standings: Array[Dictionary] = []
		if series_id == current_series_id:
			standings = get_sorted_championship_standings()
		else:
			standings = _dictionary_array((get_world_series_data(series_id) as Dictionary).get("standings", []))
		for index in standings.size():
			var row := standings[index]
			var driver_id := str(row.get("driver_id", ""))
			var driver := get_driver_by_id(driver_id)
			if driver == null:
				continue
			var state := ensure_ai_driver_state(driver)
			var position := index + 1
			state["best_championship_finish"] = position if int(state.get("best_championship_finish", 0)) <= 0 else mini(int(state.best_championship_finish), position)
			if position == 1:
				state["championships"] = int(state.get("championships", 0)) + 1
			var season_results := state.get("season_results", []) as Array
			season_results.push_front({
				"season": current_season_year,
				"series_id": series_id,
				"team_id": str(row.get("team_id", state.get("current_team_id", ""))),
				"position": position,
				"points": int(row.get("points", 0)),
				"wins": int(row.get("wins", 0)),
				"podiums": int(row.get("podiums", 0))
			})
			if season_results.size() > 20:
				season_results.resize(20)
			state["season_results"] = season_results
			ai_driver_career[driver_id] = state
			driver.championships = int(state.championships)
			driver.best_championship_finish = int(state.best_championship_finish)


func get_offseason_free_agents() -> Array[Driver]:
	var available: Array[Driver] = []
	var ids := offseason_data.get("free_agent_ids", []) as Array
	for driver_id in ids:
		var driver := get_driver_by_id(str(driver_id))
		if driver != null and not contracted_driver_ids.has(driver.driver_id):
			available.append(driver)
	available.sort_custom(func(first: Driver, second: Driver) -> bool:
		if first.get_overall_rating() == second.get_overall_rating():
			return first.salary < second.salary
		return first.get_overall_rating() > second.get_overall_rating()
	)
	return available


func process_driver_race_contracts(weekend_data: Dictionary) -> void:
	var processed := {}
	for entry_value in weekend_data.get("entries", []):
		var entry := entry_value as Dictionary
		var driver_id := str(entry.get("driver_id", ""))
		if driver_id.is_empty() or processed.has(driver_id):
			continue
		var driver := get_driver_by_id(driver_id)
		if driver != null and contracted_driver_ids.has(driver_id):
			driver.contract_races_remaining = maxi(0, driver.contract_races_remaining - 1)
			processed[driver_id] = true
	var active_driver := get_active_driver()
	if active_driver != null and contracted_driver_ids.has(active_driver.driver_id) and not processed.has(active_driver.driver_id):
		active_driver.contract_races_remaining = maxi(0, active_driver.contract_races_remaining - 1)


func _get_driver_career_goal(driver: Driver) -> String:
	if driver == null:
		return "Secure a competitive seat"
	if driver.ambition >= 72:
		return "Fight for championships"
	if driver.loyalty >= 72:
		return "Build a long-term home"
	if driver.marketability >= 72:
		return "Join a high-profile team"
	if driver.age <= 23:
		return "Earn a promotion"
	return "Secure a competitive seat"


func process_ai_team_season() -> Array[String]:
	ensure_ai_team_career()
	var summaries: Array[String] = []
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		var states := get_ai_team_states_for_series(series_id)
		if states.is_empty():
			continue
		var team_points := _get_ai_team_points(series_id)
		states.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			var first_points := int(team_points.get(str(first.team_id), -1))
			var second_points := int(team_points.get(str(second.team_id), -1))
			if first_points == second_points:
				return _ai_team_strength(first) > _ai_team_strength(second)
			return first_points > second_points
		)
		for index in states.size():
			var state := states[index]
			var position := index + 1
			var old_equipment := int(state.equipment_rating)
			var season_cost := int(series.estimated_race_cost) * int(series.season_length)
			var commercial_factor := lerpf(0.70, 1.35, 1.0 - float(position - 1) / maxf(1.0, float(states.size() - 1)))
			var revenue := roundi(float(season_cost) * commercial_factor + float(series.car_price) * 0.16)
			var expenses := roundi(float(season_cost) * (0.82 + float(state.staff_quality) / 500.0))
			state["budget"] = int(state.budget) + revenue - expenses
			var available_investment := maxi(0, int(state.budget) - roundi(float(season_cost) * 0.55))
			var investment := mini(available_investment, roundi(float(series.car_price) * 0.20))
			state["budget"] = int(state.budget) - investment
			var development_rate := (float(state.engineering_rating) * 0.55 + float(state.staff_quality) * 0.25 + float(state.strategy_rating) * 0.20) / 100.0
			var investment_rate := clampf(float(investment) / maxf(1.0, float(series.car_price) * 0.20), 0.0, 1.0)
			var competitive_pressure := 0.45 if position > states.size() / 2 else 0.18
			var rating_change := roundi(development_rate * investment_rate * 2.2 - competitive_pressure)
			if int(state.budget) < 0:
				rating_change -= 2
				state["staff_quality"] = maxi(30, int(state.staff_quality) - 1)
				state["financial_status"] = "Under pressure"
			elif int(state.budget) < season_cost / 2:
				state["financial_status"] = "Limited"
			else:
				state["financial_status"] = "Stable"
			state["equipment_rating"] = clampi(old_equipment + rating_change, 30, 99)
			state["engineering_rating"] = clampi(int(state.engineering_rating) + (1 if investment_rate > 0.72 else 0), 30, 99)
			state["strategy_rating"] = clampi(int(state.strategy_rating) + (1 if position <= maxi(1, states.size() / 3) else 0), 30, 99)
			state["trend"] = clampf(float(state.trend) * 0.55 + float(int(state.equipment_rating) - old_equipment), -5.0, 5.0)
			state["last_position"] = position
			state["seasons"] = int(state.seasons) + 1
			if position == 1:
				state["career_championships"] = int(state.get("career_championships", 0)) + 1
			var season_results := state.get("season_results", []) as Array
			season_results.push_front({
				"season": current_season_year,
				"series_id": series_id,
				"position": position,
				"points": int(team_points.get(str(state.team_id), 0)),
				"budget": int(state.budget),
				"equipment_rating": int(state.equipment_rating)
			})
			if season_results.size() > 20:
				season_results.resize(20)
			state["season_results"] = season_results
			state["movement"] = ""
			var change_trigger := position > roundi(float(states.size()) * 0.70) or int(state.budget) < 0
			if change_trigger and (season_number + position + str(state.team_id).length()) % 3 == 0:
				state["driver_changes"] = int(state.driver_changes) + 1
				state["driver_generation"] = int(state.driver_generation) + 1
				state["driver_form"] = clampi(3 - position % 7, -3, 3)
			else:
				state["driver_form"] = clampi(int(state.driver_form) + (1 if position <= 3 else -1), -4, 4)
			ai_team_career[str(state.team_id)] = state
		var leader := states[0]
		summaries.append("%s: %s leads development (%+.1f trend)." % [str(series.name), str(leader.team_name), float(leader.trend)])
	summaries.append_array(_process_ai_promotions())
	emit_changed()
	return summaries


func _get_ai_team_points(series_id: String) -> Dictionary:
	var points := {}
	var standings: Array[Dictionary] = []
	if series_id == current_series_id:
		standings = get_sorted_championship_standings()
	else:
		standings = _dictionary_array((get_world_series_data(series_id) as Dictionary).get("standings", []))
	for row in standings:
		var team_id := str(row.get("team_id", ""))
		if not team_id.is_empty():
			points[team_id] = int(points.get(team_id, 0)) + int(row.get("points", 0))
	return points


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result


func _ai_team_strength(state: Dictionary) -> float:
	return float(state.get("equipment_rating", 50)) * 0.45 + float(state.get("engineering_rating", 50)) * 0.25 + float(state.get("staff_quality", 50)) * 0.15 + float(state.get("strategy_rating", 50)) * 0.15 + float(state.get("trend", 0.0))


func _process_ai_promotions() -> Array[String]:
	var summaries: Array[String] = []
	var moved := {}
	for upper_index in range(SeriesCatalog.SERIES.size() - 1, 0, -1):
		var lower_id := str(SeriesCatalog.SERIES[upper_index - 1].id)
		var upper_id := str(SeriesCatalog.SERIES[upper_index].id)
		var lower_teams := get_ai_team_states_for_series(lower_id)
		var upper_teams := get_ai_team_states_for_series(upper_id)
		var promoted: Dictionary = {}
		var relegated: Dictionary = {}
		for state in lower_teams:
			if not moved.has(str(state.team_id)):
				promoted = state
				break
		for index in range(upper_teams.size() - 1, -1, -1):
			var state := upper_teams[index]
			if not moved.has(str(state.team_id)):
				relegated = state
				break
		if promoted.is_empty() or relegated.is_empty():
			continue
		promoted["current_series_id"] = upper_id
		promoted["movement"] = "Promoted"
		relegated["current_series_id"] = lower_id
		relegated["movement"] = "Relegated"
		moved[str(promoted.team_id)] = true
		moved[str(relegated.team_id)] = true
		ai_team_career[str(promoted.team_id)] = promoted
		ai_team_career[str(relegated.team_id)] = relegated
		summaries.append("%s promoted; %s relegated." % [str(promoted.team_name), str(relegated.team_name)])
	return summaries


func save_series_progress() -> void:
	ensure_series_progress()
	# Version 4 keeps the exported fields as compatibility mirrors only.  The
	# per-series dictionary is the single mutable source of truth.
	_sync_legacy_progress_mirrors()


func load_series_progress(series_id: String = current_series_id) -> void:
	ensure_series_progress(series_id)
	var progress: Dictionary = series_progress[series_id]
	completed_races.assign(progress.get("completed_races", []))
	unlocked_races.assign(progress.get("unlocked_races", []))
	championship_standings.assign(progress.get("standings", []))
	season_number = int(progress.get("season_number", 1))
	season_complete = bool(progress.get("season_complete", false))


func get_completed_races() -> Array[String]:
	ensure_series_progress(current_series_id)
	return (series_progress[current_series_id] as Dictionary).get("completed_races", [])


func get_unlocked_races() -> Array[String]:
	ensure_series_progress(current_series_id)
	return (series_progress[current_series_id] as Dictionary).get("unlocked_races", [])


func get_championship_standings() -> Array[Dictionary]:
	ensure_series_progress(current_series_id)
	return (series_progress[current_series_id] as Dictionary).get("standings", [])


func complete_race_for_series(series_id: String, race_id: String) -> void:
	ensure_series_progress(series_id)
	var progress := series_progress[series_id] as Dictionary
	var races: Array = progress.get("completed_races", [])
	if not races.has(race_id): races.append(race_id)
	progress["completed_races"] = races
	_sync_legacy_progress_mirrors()


func unlock_race_for_series(series_id: String, race_id: String) -> void:
	ensure_series_progress(series_id)
	var progress := series_progress[series_id] as Dictionary
	var races: Array = progress.get("unlocked_races", [])
	if not races.has(race_id): races.append(race_id)
	progress["unlocked_races"] = races
	_sync_legacy_progress_mirrors()


func set_series_standings(series_id: String, standings: Array[Dictionary]) -> void:
	ensure_series_progress(series_id)
	(series_progress[series_id] as Dictionary)["standings"] = standings.duplicate(true)
	_sync_legacy_progress_mirrors()


func set_series_season_complete(series_id: String, value: bool) -> void:
	ensure_series_progress(series_id)
	(series_progress[series_id] as Dictionary)["season_complete"] = value
	_sync_legacy_progress_mirrors()


func is_series_season_complete(series_id: String = current_series_id) -> bool:
	ensure_series_progress(series_id)
	return bool((series_progress[series_id] as Dictionary).get("season_complete", false))


func reset_series_season(series_id: String, first_race_id: String) -> void:
	ensure_series_progress(series_id)
	var progress := series_progress[series_id] as Dictionary
	progress["completed_races"] = []
	progress["unlocked_races"] = [first_race_id] if not first_race_id.is_empty() else []
	progress["standings"] = []
	progress["season_complete"] = false
	progress["season_number"] = int(progress.get("season_number", 1)) + 1
	load_series_progress(series_id)


func _sync_legacy_progress_mirrors() -> void:
	if not series_progress.has(current_series_id): return
	var progress := series_progress[current_series_id] as Dictionary
	completed_races.assign(progress.get("completed_races", []))
	unlocked_races.assign(progress.get("unlocked_races", []))
	championship_standings.assign(progress.get("standings", []))
	season_number = int(progress.get("season_number", season_number))
	season_complete = bool(progress.get("season_complete", false))


func get_drivers_for_series(series_id: String) -> Array[Driver]:
	var eligible: Array[Driver] = []
	for driver in drivers:
		if driver != null and driver.series_id == series_id:
			eligible.append(driver)
	return eligible


func get_weekly_scouting_hours() -> int:
	return BASE_SCOUTING_HOURS + get_department_level("scouting") * SCOUTING_HOURS_PER_LEVEL


func ensure_scouting_hours() -> void:
	if scouting_hours_remaining < 0 or scouting_hours_week != current_race_week:
		scouting_hours_remaining = get_weekly_scouting_hours()
		scouting_hours_week = current_race_week


func spend_scouting_hours(driver: Driver, action: String) -> bool:
	ensure_scouting_hours()
	if driver == null or not SCOUTING_ACTIONS.has(action) or get_department_level("scouting") <= 0:
		return false
	var cost := int((SCOUTING_ACTIONS[action] as Dictionary).hours)
	if scouting_hours_remaining < cost:
		return false
	scouting_hours_remaining -= cost
	var report := scouting_reports.get(driver.driver_id, {}) as Dictionary
	var reveal := str((SCOUTING_ACTIONS[action] as Dictionary).reveal)
	if reveal == "recruiting":
		var gain := 20 + get_department_level("scouting") * 5
		recruiting_progress[driver.driver_id] = mini(100, int(recruiting_progress.get(driver.driver_id, 0)) + gain)
	else:
		report.merge(build_scouting_report(driver, action), true)
		report["revealed_%s" % reveal] = true
		scouting_reports[driver.driver_id] = report
	emit_changed()
	return true


func get_driver_required_level(driver: Driver) -> int:
	if driver == null:
		return 1
	return maxi(get_required_level_for_series(driver.series_id), 1 + floori(float(maxi(0, driver.get_overall_rating() - 50)) / 5.0))


func can_negotiate_with_driver(driver: Driver) -> bool:
	# A new team must be able to open a conversation immediately. Scouting still
	# improves negotiating interest and reveals information, but it is not a
	# hard gate that can prevent a career from starting.
	return driver != null


func get_driver_negotiation_terms(driver: Driver) -> Dictionary:
	if driver == null:
		return {"salary_multiplier": 1.0, "signing_multiplier": 1.0, "level_gap": 0}
	var level_gap := get_driver_required_level(driver) - get_reputation_level()
	var professionalism := ReputationManager.get_dimension(self, "professionalism")
	var sporting := ReputationManager.get_dimension(self, "sporting_credibility")
	var gap_premium := maxf(0.0, float(level_gap) * 0.08)
	var standing_discount := maxf(0.0, float(professionalism + sporting - 120) * 0.0025)
	return {
		"salary_multiplier": clampf(1.0 + gap_premium - standing_discount, 0.85, 1.65),
		"signing_multiplier": clampf(1.0 + gap_premium * 1.25 - standing_discount, 0.82, 1.85),
		"level_gap": level_gap
	}


func negotiate_driver_contract(driver: Driver, salary_offer: int, signing_offer: int, length: int) -> Dictionary:
	if not can_negotiate_with_driver(driver):
		return {"accepted": false, "reason": "Select a valid driver before negotiating."}
	var terms := get_driver_negotiation_terms(driver)
	var requested_salary := roundi(float(driver.salary) * float(terms.salary_multiplier))
	var requested_signing := roundi(float(driver.signing_fee) * float(terms.signing_multiplier))
	var salary_ratio := float(salary_offer) / maxi(1, requested_salary)
	var signing_ratio := float(signing_offer) / maxi(1, requested_signing)
	var interest := int(recruiting_progress.get(driver.driver_id, 0))
	var professionalism := ReputationManager.get_dimension(self, "professionalism")
	var score := salary_ratio * 45.0 + signing_ratio * 30.0 + interest * 0.20 + float(professionalism) * 0.05
	var accepted := (
		(salary_offer >= requested_salary and signing_offer >= requested_signing)
		or score >= 88.0
	)
	contract_offers[driver.driver_id] = {
		"salary": salary_offer,
		"signing_fee": signing_offer,
		"counter_salary": requested_salary,
		"counter_signing_fee": requested_signing,
		"length": clampi(length, 4, 36),
		"accepted": accepted
	}
	if accepted:
		driver.salary = salary_offer
		driver.signing_fee = signing_offer
		driver.contract_length = clampi(length, 4, 36)
	emit_changed()
	var reason := "Offer accepted."
	if not accepted:
		reason = (
			"The driver countered at $%s per race and a $%s signing fee. "
			+ "Your prestige and professionalism shape these demands."
		) % [String.num_int64(requested_salary), String.num_int64(requested_signing)]
	return {"accepted":accepted, "reason":reason, "terms":terms}


func build_scouting_report(driver: Driver, assignment_type: String) -> Dictionary:
	var level := get_department_level("scouting"); var spread := maxi(1, 12-level*2); var ratings := {}
	for field in Driver.RATING_FIELDS:
		var value := int(driver.get(field)); ratings[field] = {"low":maxi(0,value-spread), "high":mini(99,value+spread), "confidence":mini(100,50+level*10)}
	return {"assignment":assignment_type, "ratings":ratings, "potential_low":maxi(driver.get_overall_rating(),driver.get_potential_overall()-spread), "potential_high":mini(99,driver.get_potential_overall()+spread), "personality":driver.archetype, "strength":driver.archetype, "risk":"High expectations" if driver.ambition > 75 else "No major concern", "projected_role":driver.expected_role}


func advance_driver_programs() -> void:
	for driver_id in driver_training_programs:
		var driver := get_driver_by_id(str(driver_id))
		var program := driver_training_programs[driver_id] as Dictionary
		if driver == null or money < int(program.get("cost", 0)):
			continue
		money -= int(program.get("cost", 0))
		driver.development_points += 1
		driver.fatigue = mini(100, driver.fatigue + int(program.get("fatigue", 5)))
	process_driver_availability()


func set_driver_training(driver: Driver, focus: String) -> bool:
	var programs := {"Race pace":"race_pace", "Qualifying":"qualifying_pace", "Tyre conservation":"tyre_management", "Racecraft":"racecraft", "Wet-weather training":"wet_weather", "Fitness":"fitness", "Simulator work":"consistency", "Technical feedback":"car_feedback", "Mental coaching":"composure"}
	if driver == null or not contracted_driver_ids.has(driver.driver_id) or not programs.has(focus): return false
	driver.development_focus = focus
	driver_training_programs[driver.driver_id] = {"attribute":programs[focus], "cost":350, "fatigue":8 if focus == "Fitness" else 4, "focus":focus, "start_day":current_season_day, "completion_day":mini(CalendarCatalog.SEASON_END_DAY, current_season_day + DRIVER_TRAINING_DAYS)}
	emit_changed()
	return true


func process_driver_availability() -> void:
	for driver in drivers:
		if driver == null: continue
		driver.fatigue = maxi(0, driver.fatigue - 8)
		if driver.unavailable_weeks > 0:
			driver.unavailable_weeks -= 1
			if driver.unavailable_weeks == 0: driver.availability_status = "Available"


func get_department_bonus(department_id: String) -> float:
	return DepartmentCatalog.get_bonus(get_department_level(department_id))


func is_secret_department_unlocked() -> bool:
	return season_number >= 3 or championship_points >= 100


func get_discounted_cost(base_cost: int, include_accounting: bool = true) -> int:
	if base_cost <= 0:
		return 0
	var discount: float = get_department_bonus("accounting") if include_accounting else 0.0
	var market_scale := float(get_difficulty_setting("market_cost_multiplier", 1.0))
	return maxi(1, ceili(float(base_cost) * market_scale * (1.0 - discount / 100.0)))


func get_department_cost(department_id: String) -> int:
	var level := get_department_level(department_id)
	var base_cost := DepartmentCatalog.get_base_cost(department_id, level)
	# Accounting cannot discount its own construction, avoiding a circular price change.
	return get_discounted_cost(base_cost, department_id != "accounting")


func can_purchase_department(department_id: String) -> bool:
	if not DepartmentCatalog.DEPARTMENTS.has(department_id):
		return false
	if department_id == "cheating" and not is_secret_department_unlocked():
		return false
	var cost := get_department_cost(department_id)
	return cost > 0 and money >= cost


func purchase_department(department_id: String) -> bool:
	if not can_purchase_department(department_id):
		return false
	var cost := get_department_cost(department_id)
	money -= cost
	department_levels[department_id] = get_department_level(department_id) + 1
	record_finance("HQ", -cost, "Upgraded %s" % str(DepartmentCatalog.get_data(department_id).get("name", department_id)))
	emit_changed()
	return true


func ensure_car_parts() -> void:
	for car_value in cars:
		var car := car_value as Car
		if car != null:
			car.ensure_standard_parts()


func get_car(bay_index: int) -> Car:
	if not is_valid_bay_index(bay_index):
		return null

	return cars[bay_index] as Car


func buy_car(
	car_template: Car,
	bay_index: int
) -> bool:
	if car_template == null:
		push_error(
			"Cannot purchase a null car template."
		)
		return false
	if not entered_series_ids.has(car_template.series_id):
		return false

	if not is_valid_bay_index(bay_index):
		push_error(
			"Invalid garage bay index: %d"
			% bay_index
		)
		return false

	if cars[bay_index] != null:
		return false

	var purchase_cost := get_discounted_cost(car_template.purchase_price)
	if money < purchase_cost:
		return false

	var purchased_car: Car = (
		car_template.duplicate(true) as Car
	)

	if purchased_car == null:
		push_error(
			"The car template could not be duplicated."
		)
		return false

	purchased_car.ensure_standard_parts()

	money -= purchase_cost
	cars[bay_index] = purchased_car
	record_finance("Garage", -purchase_cost, "Purchased %s" % purchased_car.name)

	emit_changed()

	return true


func sell_car(bay_index: int) -> int:
	if not is_valid_bay_index(bay_index):
		push_error(
			"Invalid garage bay index: %d"
			% bay_index
		)
		return 0

	var car: Car = cars[bay_index] as Car

	if car == null:
		return 0

	var sale_price: int = car.value

	money += sale_price
	cars[bay_index] = null
	record_finance("Garage", sale_price, "Sold %s" % car.name)

	emit_changed()

	return sale_price


func buy_part(part_template: CarPart) -> bool:
	if part_template == null:
		return false
	var purchase_cost := get_discounted_cost(part_template.purchase_price)
	if money < purchase_cost:
		return false
	money -= purchase_cost
	parts_inventory.append(part_template.duplicate(true) as CarPart)
	record_finance("Parts", -purchase_cost, "Purchased %s" % part_template.part_name)
	emit_changed()
	return true


func sell_part(part: CarPart) -> int:
	if part == null or not parts_inventory.has(part):
		return 0
	parts_inventory.erase(part)
	money += part.sale_price
	record_finance("Parts", part.sale_price, "Sold %s" % part.part_name)
	emit_changed()
	return part.sale_price


func install_part(car: Car, part: CarPart) -> bool:
	if car == null or part == null or not parts_inventory.has(part):
		return false
	parts_inventory.erase(part)
	var removed_part: CarPart = car.install_part(part)
	if removed_part != null and removed_part.tier != "Standard":
		parts_inventory.append(removed_part)
	emit_changed()
	return true


func get_parts_by_type(part_type: String) -> Array[CarPart]:
	var matches: Array[CarPart] = []
	for part in parts_inventory:
		if part != null and part.part_type == part_type:
			matches.append(part)
	return matches


func ensure_staff_market() -> void:
	var candidates: Array[Dictionary] = [
		{"id":"chief_morgan","name":"Alex Morgan","role":"Crew Chief","a":68,"b":56,"potential":76,"fee":4500,"salary":1600,"specialty":"Race strategy"},
		{"id":"chief_chen","name":"Lena Chen","role":"Crew Chief","a":75,"b":81,"potential":88,"fee":9000,"salary":2800,"specialty":"Car setup"},
		{"id":"chief_bennett","name":"Marcus Bennett","role":"Crew Chief","a":94,"b":88,"potential":94,"fee":16000,"salary":4500,"specialty":"Championship leadership"},
		{"id":"engineer_singh","name":"Priya Singh","role":"Engineer","a":61,"b":69,"potential":84,"fee":3200,"salary":1200,"specialty":"Engines"},
		{"id":"engineer_romero","name":"Diego Romero","role":"Engineer","a":74,"b":68,"potential":82,"fee":6000,"salary":1900,"specialty":"Suspension"},
		{"id":"engineer_nakamura","name":"Emi Nakamura","role":"Engineer","a":89,"b":79,"potential":92,"fee":10500,"salary":3100,"specialty":"Aerodynamics"},
		{"id":"engineer_okafor","name":"Tunde Okafor","role":"Engineer","a":96,"b":92,"potential":97,"fee":17500,"salary":4800,"specialty":"Advanced manufacturing"},
		{"id":"mechanic_cole","name":"Jamie Cole","role":"Mechanic","a":64,"b":72,"potential":82,"fee":3600,"salary":1300,"specialty":"Rapid repairs"},
		{"id":"mechanic_alvarez","name":"Rosa Alvarez","role":"Mechanic","a":83,"b":79,"potential":90,"fee":7600,"salary":2400,"specialty":"Pit precision"},
		{"id":"mechanic_ward","name":"Cal Ward","role":"Mechanic","a":91,"b":88,"potential":94,"fee":13000,"salary":3700,"specialty":"Damage recovery"},
		{"id":"spotter_brooks","name":"Taylor Brooks","role":"Spotter","a":70,"b":66,"potential":85,"fee":4100,"salary":1500,"specialty":"Traffic awareness"},
		{"id":"spotter_kim","name":"Jules Kim","role":"Spotter","a":88,"b":92,"potential":95,"fee":12000,"salary":3600,"specialty":"Restarts"},
		{"id":"pit_hughes","name":"Sam Hughes","role":"Pit Crew","a":61,"b":73,"potential":83,"fee":2600,"salary":900,"specialty":"Tire carrier"},
		{"id":"pit_patel","name":"Ari Patel","role":"Pit Crew","a":78,"b":81,"potential":90,"fee":5200,"salary":1600,"specialty":"Jack operator"},
		{"id":"pit_davis","name":"Morgan Davis","role":"Pit Crew","a":86,"b":77,"potential":91,"fee":7200,"salary":2100,"specialty":"Tire changer"},
		{"id":"pit_owens","name":"Casey Owens","role":"Pit Crew","a":72,"b":91,"potential":93,"fee":6800,"salary":1900,"specialty":"Fueler"},
		{"id":"pit_wright","name":"Devon Wright","role":"Pit Crew","a":94,"b":89,"potential":96,"fee":12500,"salary":3300,"specialty":"Crew captain"}
	]
	for data in candidates:
		var existing_member := get_staff_by_id(str(data["id"]))
		if existing_member != null:
			# Migrate staff created before individual attributes were introduced.
			if existing_member.primary_rating == 50 and existing_member.secondary_rating == 50:
				existing_member.primary_rating = int(data["a"])
				existing_member.secondary_rating = int(data["b"])
				existing_member.potential = int(data["potential"])
				existing_member.recalculate_rating()
			continue
		var member := StaffMember.new()
		member.staff_id = str(data["id"])
		member.staff_name = str(data["name"])
		member.role = str(data["role"])
		member.primary_rating = int(data["a"])
		member.secondary_rating = int(data["b"])
		member.potential = int(data["potential"])
		member.signing_fee = int(data["fee"])
		member.salary = int(data["salary"])
		member.specialty = str(data["specialty"])
		member.recalculate_rating()
		member.rival_interest = get_rival_interest(member.rating)
		staff.append(member)


func get_staff_by_id(staff_id: String) -> StaffMember:
	for member in staff:
		if member != null and member.staff_id == staff_id:
			return member
	return null


func get_crew_chief() -> StaffMember:
	for member in staff:
		if member != null and member.hired and member.role == "Crew Chief":
			return member
	return null


func get_engineers() -> Array[StaffMember]:
	var engineers: Array[StaffMember] = []
	for member in staff:
		if member != null and member.hired and member.role == "Engineer":
			engineers.append(member)
	return engineers


func get_staff_by_role(role: String, hired_only: bool = true) -> Array[StaffMember]:
	var matches: Array[StaffMember] = []
	for member in staff:
		if member != null and member.role == role and (member.hired or not hired_only):
			matches.append(member)
	return matches


func get_role_limit(role: String) -> int:
	return int(ROLE_LIMITS.get(role, 0))


func can_add_staff_role(role: String) -> bool:
	return get_staff_by_role(role).size() < get_role_limit(role)


func get_rival_interest(rating: int) -> String:
	if rating >= 88:
		return "Very high"
	if rating >= 76:
		return "High"
	if rating >= 62:
		return "Medium"
	return "Low"


func hire_staff(member: StaffMember) -> bool:
	if member == null or not staff.has(member) or member.hired:
		return false
	if not can_add_staff_role(member.role):
		return false
	var cost := get_discounted_cost(member.signing_fee)
	if money < cost:
		return false
	money -= cost
	member.hired = true
	member.contract_races_remaining = member.get_default_contract_length()
	member.morale = 70
	record_finance("Staff", -cost, "Signed %s" % member.staff_name)
	emit_changed()
	return true


func fire_staff(member: StaffMember) -> bool:
	if member == null or not member.hired:
		return false
	var fee := get_discounted_cost(member.get_termination_fee())
	if money < fee:
		return false
	money -= fee
	record_finance("Staff", -fee, "Terminated %s's contract" % member.staff_name)
	member.hired = false
	member.contract_races_remaining = 0
	emit_changed()
	return true


func renew_staff_contract(member: StaffMember, negotiate: bool = false) -> bool:
	if member == null or not member.hired:
		return false
	var renewal_fee := get_discounted_cost(maxi(member.salary, member.signing_fee / 3))
	if money < renewal_fee:
		return false
	money -= renewal_fee
	if negotiate:
		member.salary = maxi(100, roundi(float(member.salary) * 0.95))
		member.morale = maxi(0, member.morale - 8)
	else:
		member.morale = mini(100, member.morale + 5)
	member.contract_races_remaining = member.get_default_contract_length()
	record_finance("Staff", -renewal_fee, "Renewed %s" % member.staff_name)
	emit_changed()
	return true


func process_staff_race() -> Dictionary:
	var crew_chief_salary := 0
	var engineering_payroll := 0
	var expired_names: Array[String] = []
	for member in staff:
		if member == null or not member.hired:
			continue
		if member.role == "Crew Chief":
			crew_chief_salary += get_effective_salary(member.salary)
		else:
			engineering_payroll += get_effective_salary(member.salary)
		member.experience += 1
		if member.experience % 6 == 0:
			member.development_points += 1
		member.contract_races_remaining = maxi(0, member.contract_races_remaining - 1)
		member.morale = mini(100, member.morale + 1)
		if member.contract_races_remaining == 0:
			expired_names.append(member.staff_name)
			member.hired = false
	var total := crew_chief_salary + engineering_payroll
	money -= total
	if crew_chief_salary > 0:
		record_finance("Payroll", -crew_chief_salary, "Crew chief salary")
	if engineering_payroll > 0:
		record_finance("Payroll", -engineering_payroll, "Engineering payroll")
	emit_changed()
	return {
		"crew_chief_salary": crew_chief_salary,
		"engineering_payroll": engineering_payroll,
		"expired_names": expired_names
	}


func get_staff_payroll() -> int:
	var total := 0
	for member in staff:
		if member != null and member.hired:
			total += get_effective_salary(member.salary)
	return total


func get_total_race_payroll() -> int:
	var driver := get_active_driver()
	var driver_payroll := get_effective_salary(driver.salary) if driver != null and driver_hired_for_season else 0
	return get_staff_payroll() + driver_payroll


func record_finance(category: String, amount: int, description: String) -> void:
	finance_history.push_front({
		"season": season_number,
		"race": get_completed_races().size() + 1,
		"category": category,
		"amount": amount,
		"description": description
	})
	if finance_history.size() > 100:
		finance_history.resize(100)


func get_finance_total(positive: bool) -> int:
	var total := 0
	for entry in finance_history:
		var amount := int(entry.get("amount", 0))
		if (positive and amount > 0) or (not positive and amount < 0):
			total += abs(amount)
	return total


func get_crew_chief_performance_boost() -> float:
	var chief := get_crew_chief()
	if chief == null:
		return 0.0
	var specialty_bonus := 0.75 if chief.specialty == "Race strategy" else 0.0
	return float(chief.rating) * 0.05 + specialty_bonus


func get_car_setup_variance_reduction() -> float:
	var chief := get_crew_chief()
	if chief == null:
		return 0.0
	return float(chief.secondary_rating) * 0.012 + (0.5 if chief.specialty == "Car setup" else 0.0)


func get_engineering_performance_boost() -> float:
	return get_average_role_attribute("Engineer", true) * 0.035


func create_performance_point_context() -> PerformancePointContext:
	var context := PerformancePointContext.new()
	_append_percent_modifier(context.part_modifiers, "engineering_department", "Engineering department", PerformancePointModifier.Scope.PART, get_department_bonus("engineering"))
	_append_percent_modifier(context.part_modifiers, "engineering_staff", "Engineering staff", PerformancePointModifier.Scope.PART, get_engineering_performance_boost())
	_append_percent_modifier(context.part_modifiers, "wind_tunnel_body", "Wind tunnel", PerformancePointModifier.Scope.PART, get_department_bonus("wind_tunnel"), ["Body"])
	var specialty_targets := {"Engines":["Engine"], "Suspension":["Suspension"], "Aerodynamics":["Body"]}
	for engineer in get_engineers():
		if specialty_targets.has(engineer.specialty):
			var targets: Array[String] = []
			targets.assign(specialty_targets[engineer.specialty])
			_append_percent_modifier(context.part_modifiers, "engineer_specialty_%s" % engineer.staff_id, "%s specialty" % engineer.staff_name, PerformancePointModifier.Scope.PART, float(engineer.rating) * 0.015, targets)
	_append_percent_modifier(context.car_modifiers, "crew_chief_setup", "Crew chief setup", PerformancePointModifier.Scope.CAR, get_crew_chief_performance_boost())
	_append_percent_modifier(context.car_modifiers, "secret_department_car", "Secret department", PerformancePointModifier.Scope.CAR, get_department_bonus("cheating"))
	return context


func _append_percent_modifier(destination: Array[PerformancePointModifier], id: String, label: String, scope: int, percent: float, targets: Array[String] = []) -> void:
	if percent > 0.0:
		destination.append(PerformancePointModifier.create(id, label, scope, PerformancePointModifier.Operation.ADDITIVE_PERCENT, percent, targets))


func calculate_part_performance(part: CarPart, calculation_team: Team = null) -> PartPerformanceResult:
	var context := (calculation_team if calculation_team != null else self).create_performance_point_context()
	return PerformancePointCalculator.calculate_part(part, context)


func calculate_car_performance(car: Car) -> CarPerformanceResult:
	return PerformancePointCalculator.calculate_car(car, create_performance_point_context())


func get_reliability_boost() -> float:
	return get_average_role_attribute("Engineer", false) * 0.08


func get_repair_time_reduction() -> float:
	return get_average_role_attribute("Mechanic", true) * 0.22


func get_pit_stop_time_reduction() -> float:
	var mechanic_bonus := get_average_role_attribute("Mechanic", false) * 0.008
	var pit_bonus := get_average_role_attribute("Pit Crew", true) * 0.012
	return mechanic_bonus + pit_bonus


func get_pit_mistake_reduction() -> float:
	return get_average_role_attribute("Pit Crew", false) * 0.1


func get_accident_risk_reduction() -> float:
	return get_average_role_attribute("Spotter", true) * 0.1


func get_restart_performance_boost() -> float:
	return get_average_role_attribute("Spotter", false) * 0.025


func get_average_role_attribute(role: String, primary: bool) -> float:
	var members := get_staff_by_role(role)
	if members.is_empty():
		return 0.0
	var total := 0.0
	for member in members:
		var attribute := member.primary_rating if primary else member.secondary_rating
		total += float(attribute) * lerpf(0.8, 1.05, float(member.morale) / 100.0)
	return total / float(members.size())


func process_staff_season() -> Array[String]:
	var updates: Array[String] = []
	for member in staff:
		if member == null:
			continue
		member.rival_interest = get_rival_interest(member.rating)
		if member.hired:
			member.apply_season_development()
			updates.append("%s: %s" % [member.staff_name, member.last_development])
		elif member.rating >= 82 and (season_number + member.staff_id.length()) % 3 == 0:
			# Rival offers make elite free agents more expensive rather than deleting save data.
			member.salary = roundi(float(member.salary) * 1.08)
			member.signing_fee = roundi(float(member.signing_fee) * 1.08)
	return updates


func is_engineer_available(engineer: StaffMember) -> bool:
	if engineer == null or not engineer.hired or engineer.role != "Engineer":
		return false
	for project in engineering_projects:
		if str(project.get("engineer_id", "")) == engineer.staff_id:
			return false
	return true


func queue_part_project(engineer: StaffMember, part_type: String) -> bool:
	if not is_engineer_available(engineer) or not CarPart.PART_TYPES.has(part_type):
		return false
	var cost := get_discounted_cost(MANUFACTURING_BASE_COST)
	if money < cost:
		return false
	money -= cost
	engineering_projects.append({
		"engineer_id": engineer.staff_id,
		"engineer_name": engineer.staff_name,
		"part_type": part_type,
		"start_day": current_season_day,
		"completion_day": mini(CalendarCatalog.SEASON_END_DAY, current_season_day + ENGINEERING_PROJECT_DAYS)
	})
	record_finance("Workshop", -cost, "Started %s development" % part_type)
	emit_changed()
	return true


func complete_engineering_projects(through_day: int = CalendarCatalog.SEASON_END_DAY) -> Array[String]:
	var completed: Array[String] = []
	var remaining: Array[Dictionary] = []
	for project in engineering_projects:
		if int(project.get("completion_day", current_season_day)) > through_day:
			remaining.append(project)
			continue
		var engineer := get_staff_by_id(str(project.get("engineer_id", "")))
		if engineer == null:
			continue
		var part_type := str(project.get("part_type", "Engine"))
		var part := PartCatalog.create_manufactured_part(part_type, engineer)
		parts_inventory.append(part)
		completed.append("%s completed %s" % [engineer.staff_name, part.part_name])
	engineering_projects = remaining
	return completed


func get_date_events(target_day: int) -> Array[Dictionary]:
	_migrate_date_driven_projects()
	var events: Array[Dictionary] = []
	for project in engineering_projects:
		var day := int(project.get("completion_day", target_day))
		if day > current_season_day and day <= target_day:
			events.append({"day":day, "type":"engineering", "title":"%s development completes" % project.get("part_type", "Part")})
	for driver_id in driver_training_programs:
		var program := driver_training_programs[driver_id] as Dictionary
		var day := int(program.get("completion_day", target_day))
		while day > current_season_day and day <= target_day:
			var driver := get_driver_by_id(str(driver_id))
			events.append({"day":day, "type":"training", "title":"%s training milestone" % (driver.driver_name if driver != null else "Driver")})
			day += DRIVER_TRAINING_DAYS
	for assignment in scouting_assignments:
		var day := int(assignment.get("completion_day", target_day + 1))
		if day > current_season_day and day <= target_day:
			events.append({"day":day, "type":"scouting", "title":"Scouting assignment completes"})
	return events


func advance_to_date(target_day: int) -> Array[String]:
	var clamped_target := clampi(target_day, current_season_day, CalendarCatalog.SEASON_END_DAY)
	if clamped_target == current_season_day:
		return []
	var elapsed_days := clamped_target - current_season_day
	var summaries := complete_engineering_projects(clamped_target)
	for driver_id in driver_training_programs.keys():
		var program := driver_training_programs[driver_id] as Dictionary
		while int(program.get("completion_day", clamped_target + 1)) <= clamped_target:
			var driver := get_driver_by_id(str(driver_id))
			if driver != null and money >= int(program.get("cost", 0)):
				money -= int(program.get("cost", 0))
				driver.development_points += 1
				driver.fatigue = mini(100, driver.fatigue + int(program.get("fatigue", 5)))
				summaries.append("%s completed %s training" % [driver.driver_name, program.get("focus", "driver")])
			program["start_day"] = int(program.get("completion_day", clamped_target))
			program["completion_day"] = int(program.start_day) + DRIVER_TRAINING_DAYS
	current_season_day = clamped_target
	current_race_week = maxi(current_race_week, get_completed_races().size() + 1)
	week_advance_required = false
	process_driver_availability()
	ensure_scouting_hours()
	var career_summaries: Variant = _call_career_expansion_manager(&"process_day", [self, elapsed_days])
	if career_summaries is Array:
		summaries.append_array(career_summaries)
	emit_changed()
	return summaries


func advance_to_next_race_week(next_race_day: int = current_season_day) -> Array[String]:
	if not week_advance_required or is_series_season_complete():
		return []
	return advance_to_date(next_race_day)


func manufacture_part(engineer: StaffMember, part_type: String) -> CarPart:
	if engineer == null or not engineer.hired or engineer.role != "Engineer":
		return null
	if not CarPart.PART_TYPES.has(part_type):
		return null
	var cost := get_discounted_cost(MANUFACTURING_BASE_COST)
	if money < cost:
		return null
	money -= cost
	var part := PartCatalog.create_manufactured_part(part_type, engineer)
	_call_career_expansion_manager(&"apply_manufacturing_quality", [self, part])
	parts_inventory.append(part)
	record_finance("Workshop", -cost, "Manufactured %s" % part.part_name)
	emit_changed()
	return part


func repair_part(engineer: StaffMember, part: CarPart) -> int:
	if engineer == null or not engineer.hired or engineer.role != "Engineer":
		return 0
	if part == null or not parts_inventory.has(part) or part.condition >= 100:
		return 0
	var maximum_restore := 10 + roundi(float(engineer.rating) * 0.35)
	if engineer.specialty == "Advanced manufacturing":
		maximum_restore += 5
	elif (
		(engineer.specialty == "Engines" and part.part_type == "Engine")
		or (engineer.specialty == "Suspension" and part.part_type == "Suspension")
		or (engineer.specialty == "Aerodynamics" and part.part_type == "Body")
	):
		maximum_restore += 4
	var restored := mini(100 - part.condition, maximum_restore)
	var difficulty_cost := roundi(float(restored * PART_REPAIR_COST_PER_POINT) * float(get_difficulty_setting("repair_multiplier", 1.0)))
	var cost := get_discounted_cost(difficulty_cost)
	if money < cost:
		return 0
	money -= cost
	part.condition += restored
	record_finance("Workshop", -cost, "Repaired %s" % part.part_name)
	part.emit_changed()
	emit_changed()
	return restored


func remove_car_from_bay(
	bay_index: int
) -> void:
	if not is_valid_bay_index(bay_index):
		return

	cars[bay_index] = null

	emit_changed()


func can_afford_car(
	car_template: Car
) -> bool:
	if car_template == null:
		return false

	return money >= get_discounted_cost(car_template.purchase_price)


func is_valid_bay_index(
	bay_index: int
) -> bool:
	return (
		bay_index >= 0
		and bay_index < cars.size()
	)


func ensure_default_player_driver() -> Driver:
	var current_driver: Driver = get_active_driver()

	if current_driver != null:
		if not contracted_driver_ids.has(current_driver.driver_id):
			contracted_driver_ids.append(current_driver.driver_id)
		current_driver.team_name = team_name
		current_driver.is_player_driver = true
		if (
			current_driver.driver_id == "player_jordan_hayes"
			and current_driver.age == 25
			and current_driver.potential == 80
		):
			current_driver.age = 24
			current_driver.potential = 78
		if current_driver.race_pace == 50 and current_driver.qualifying_pace == 50:
			current_driver.initialize_detailed_ratings(current_driver.skill, current_driver.consistency, current_driver.aggression, current_driver.potential)
		return current_driver

	var new_driver := Driver.new()

	new_driver.driver_id = "player_jordan_hayes"
	new_driver.driver_name = "Jordan Hayes"

	new_driver.skill = 55
	new_driver.consistency = 55
	new_driver.aggression = 50
	new_driver.age = 24
	new_driver.potential = 78
	new_driver.hometown = "Charlotte, North Carolina"
	new_driver.racing_background = "Late models and regional stock cars"
	new_driver.biography = "A composed homegrown prospect stepping up from the regional short-track scene."
	new_driver.preferred_number = 27
	new_driver.initialize_detailed_ratings(55, 55, 50, 78)

	new_driver.salary = 1500
	new_driver.signing_fee = 2000
	new_driver.archetype = "Balanced club racer"
	new_driver.assigned_bay = -1

	new_driver.team_name = team_name
	new_driver.is_player_driver = true

	drivers.append(new_driver)
	contracted_driver_ids.append(new_driver.driver_id)

	emit_changed()

	return new_driver


func ensure_driver_market() -> void:
	var candidates: Array[Dictionary] = [
		{
			"id": "maya_torres", "name": "Maya Torres",
			"archetype": "Talented but inconsistent",
			"skill": 78, "consistency": 43, "aggression": 62,
			"salary": 3200, "fee": 6500,
			"age": 25, "potential": 90
		},
		{
			"id": "grant_holloway", "name": "Grant Holloway",
			"archetype": "Dependable veteran",
			"skill": 67, "consistency": 84, "aggression": 38,
			"salary": 2900, "fee": 5000,
			"age": 35, "potential": 85
		},
		{
			"id": "nia_okafor", "name": "Nia Okafor",
			"archetype": "Aggressive prospect",
			"skill": 65, "consistency": 54, "aggression": 88,
			"salary": 2200, "fee": 4000,
			"age": 21, "potential": 94
		},
		{
			"id": "eli_park", "name": "Eli Park",
			"archetype": "Cheap rookie",
			"skill": 48, "consistency": 51, "aggression": 57,
			"salary": 900, "fee": 1000,
			"age": 19, "potential": 86
		},
		{
			"id": "sofia_varga", "name": "Sofia Varga",
			"archetype": "Expensive championship contender",
			"skill": 91, "consistency": 87, "aggression": 71,
			"salary": 6000, "fee": 12000,
			"age": 29, "potential": 94
		}
	]

	for data in candidates:
		var existing_driver: Driver = get_driver_by_id(str(data["id"]))
		if existing_driver != null:
			migrate_driver_development(existing_driver, data)
			continue
		var driver := Driver.new()
		driver.driver_id = str(data["id"])
		driver.driver_name = str(data["name"])
		driver.archetype = str(data["archetype"])
		driver.skill = int(data["skill"])
		driver.consistency = int(data["consistency"])
		driver.aggression = int(data["aggression"])
		driver.salary = int(data["salary"])
		driver.signing_fee = int(data["fee"])
		driver.age = int(data["age"])
		driver.potential = int(data["potential"])
		driver.initialize_detailed_ratings(driver.skill, driver.consistency, driver.aggression, driver.potential)
		_apply_driver_profile(driver)
		drivers.append(driver)


func ensure_series_rosters() -> void:
	# Persistent fictional fields match the approximate entry-list sizes of each tier.
	var first_names := ["Avery", "Blake", "Cameron", "Dakota", "Emery", "Finley", "Harper", "Jesse", "Kai", "Logan", "Morgan", "Parker"]
	var last_names := ["Adams", "Baker", "Carter", "Diaz", "Ellis", "Foster", "Gray", "Howard", "Irwin", "James", "King", "Lewis", "Miller", "Nolan", "Owens", "Price", "Reed", "Stone", "Turner", "Young"]
	for series_index in SeriesCatalog.SERIES.size():
		var series: Dictionary = SeriesCatalog.SERIES[series_index]
		var target_size := int(series.roster_size)
		for roster_index in target_size:
			var driver_id := "%s_driver_%02d" % [series.id, roster_index + 1]
			if get_driver_by_id(driver_id) != null:
				continue
			var driver := Driver.new()
			driver.driver_id = driver_id
			driver.driver_name = "%s %s" % [first_names[(roster_index + series_index) % first_names.size()], last_names[(roster_index * 3 + series_index) % last_names.size()]]
			driver.series_id = str(series.id)
			driver.age = 18 + ((roster_index * 5 + series_index) % 25)
			var skill := clampi(44 + series_index * 6 + (roster_index * 7) % 13, 0, 96)
			driver.initialize_detailed_ratings(skill, skill - 2 + roster_index % 5, 45 + (roster_index * 9) % 45, mini(99, skill + 8 + roster_index % 8))
			driver.salary = roundi(float(series.car_price) * (0.025 + float(roster_index % 5) * 0.004))
			driver.signing_fee = driver.salary * 2
			driver.update_archetype()
			drivers.append(driver)


func migrate_driver_development(
	driver: Driver,
	data: Dictionary
) -> void:
	# Values introduced after launch use generic Resource defaults in old saves.
	# Replace those defaults with the archetype-specific values once.
	if driver.age == 25 and driver.potential == 80:
		driver.age = int(data["age"])
		driver.potential = int(data["potential"])

	driver.potential = max(
		driver.potential,
		max(driver.skill, max(driver.consistency, driver.aggression))
	)
	if driver.race_pace == 50 and driver.qualifying_pace == 50:
		driver.initialize_detailed_ratings(driver.skill, driver.consistency, driver.aggression, driver.potential)
	_apply_driver_profile(driver)


func _apply_driver_profile(driver: Driver) -> void:
	var profiles := {
		"maya_torres": ["Monterrey, Mexico", "Mexican", "Karting and touring cars", "An instinctive qualifier whose fearless rise through touring cars made her a paddock favorite."],
		"grant_holloway": ["Bristol, Tennessee", "American", "Short tracks and endurance racing", "A respected veteran known for mechanical sympathy and bringing the car home."],
		"nia_okafor": ["Atlanta, Georgia", "American", "National karting and late models", "A bold young prospect with exceptional wheel-to-wheel instincts and raw speed."],
		"eli_park": ["Vancouver, Canada", "Canadian", "Karting and rookie stock cars", "A patient academy graduate taking the first steps of a professional career."],
		"sofia_varga": ["Budapest, Hungary", "Hungarian", "Formula cars and international GT", "A polished international contender chasing the one major title missing from her résumé."]
	}
	if profiles.has(driver.driver_id):
		var profile: Array = profiles[driver.driver_id]
		driver.hometown = profile[0]
		driver.nationality = profile[1]
		driver.racing_background = profile[2]
		driver.biography = profile[3]


func can_hire_driver(driver: Driver = null) -> bool:
	return (
		not is_series_season_complete()
		and get_completed_races().is_empty()
		and contracted_driver_ids.size() < MAX_RACE_TEAMS
		and (driver == null or (not contracted_driver_ids.has(driver.driver_id) and can_negotiate_with_driver(driver) and bool((contract_offers.get(driver.driver_id, {}) as Dictionary).get("accepted", false))))
	)


func get_driver_roster_limit() -> int:
	# Every contracted driver can be assigned to one of the team's race entries.
	return MAX_RACE_TEAMS


func hire_driver(driver: Driver) -> bool:
	if driver == null or not drivers.has(driver):
		return false
	var signing_cost := get_discounted_cost(driver.signing_fee)
	if not can_hire_driver(driver) or money < signing_cost:
		return false

	money -= signing_cost
	driver.is_player_driver = get_active_driver() == null
	driver.team_name = team_name
	driver.contract_races_remaining = maxi(driver.contract_length, int(SeriesCatalog.get_series(current_series_id).get("season_length", 12)))
	driver.series_id = current_series_id
	contracted_driver_ids.append(driver.driver_id)
	var ai_state := ensure_ai_driver_state(driver)
	ai_state["current_team_id"] = "player_team"
	ai_state["current_series_id"] = current_series_id
	ai_driver_career[driver.driver_id] = ai_state
	driver_hired_for_season = true
	record_finance("Driver", -signing_cost, "Signed %s" % driver.driver_name)
	emit_changed()
	return true


func get_active_driver() -> Driver:
	for driver in drivers:
		if driver == null:
			continue

		if driver.is_player_driver:
			return driver

	return null


func get_contracted_drivers() -> Array[Driver]:
	var roster: Array[Driver] = []
	for driver_id in contracted_driver_ids:
		var driver := get_driver_by_id(driver_id)
		if driver != null:
			roster.append(driver)
	return roster


func ensure_race_teams() -> void:
	if race_teams.is_empty():
		var first_team := RaceTeam.new()
		first_team.team_id = "team_1"
		first_team.team_name = "Team 1"
		var active_driver := get_active_driver()
		first_team.driver_id = active_driver.driver_id if active_driver != null else ""
		race_teams.append(first_team)
	for index in range(race_teams.size()):
		if race_teams[index] != null and race_teams[index].team_id.is_empty():
			race_teams[index].team_id = "team_%d" % (index + 1)


func add_race_team() -> RaceTeam:
	if race_teams.size() >= MAX_RACE_TEAMS:
		return null
	var cost := get_discounted_cost(RACE_TEAM_EXPANSION_COST)
	if money < cost:
		return null
	money -= cost
	var race_team := RaceTeam.new()
	race_team.team_id = "team_%d" % (race_teams.size() + 1)
	race_team.team_name = "Team %d" % (race_teams.size() + 1)
	race_teams.append(race_team)
	record_finance("Race Teams", -cost, "Opened %s" % race_team.team_name)
	emit_changed()
	return race_team


func assign_race_team(race_team: RaceTeam, driver_id: String, car_bay: int) -> bool:
	if race_team == null or not race_teams.has(race_team):
		return false
	if not driver_id.is_empty() and not contracted_driver_ids.has(driver_id):
		return false
	if car_bay >= 0 and get_car(car_bay) == null:
		return false
	for other_team in race_teams:
		if other_team == race_team:
			continue
		if not driver_id.is_empty() and other_team.driver_id == driver_id:
			return false
		if car_bay >= 0 and other_team.car_bay == car_bay:
			return false
	race_team.driver_id = driver_id
	race_team.car_bay = car_bay
	emit_changed()
	return true


func get_driver_by_id(
	driver_id: String
) -> Driver:
	for driver in drivers:
		if driver == null:
			continue

		if driver.driver_id == driver_id:
			return driver

	return null


func get_player_championship_entry() -> Dictionary:
	for entry in get_championship_standings():
		if bool(entry.get("is_player", false)):
			return entry

	return {}


func get_sorted_championship_standings() -> Array[Dictionary]:
	var sorted_standings: Array[Dictionary] = []

	for entry in get_championship_standings():
		sorted_standings.append(
			entry.duplicate(true)
		)

	sorted_standings.sort_custom(PointsSystemCatalog.standings_before)

	return sorted_standings
