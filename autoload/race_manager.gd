extends Node

const SEASON_RACE_IDS: Array[String] = [
	"spring_100",
	"riverside_200",
	"coastal_150",
	"desert_175",
	"mountain_classic",
	"lakeside_225",
	"capital_200",
	"prairie_250",
	"harbor_180",
	"forest_240",
	"national_stock_car",
	"championship_300"
]

const SEASON_PRIZES: Array[int] = [
	50000,
	35000,
	25000,
	18000,
	14000,
	10000,
	7500,
	5000
]

const DEFAULT_STRATEGY := "balanced"
const RACE_RESOURCE_PATHS: Dictionary = {
	"spring_100": "res://resources/races/spring_speedway_100.tres",
	"riverside_200": "res://resources/races/riverside_200.tres",
	"coastal_150": "res://resources/races/coastal_150.tres",
	"desert_175": "res://resources/races/desert_175.tres",
	"mountain_classic": "res://resources/races/mountain_classic.tres",
	"lakeside_225": "res://resources/races/lakeside_225.tres",
	"capital_200": "res://resources/races/capital_200.tres",
	"prairie_250": "res://resources/races/prairie_250.tres",
	"harbor_180": "res://resources/races/harbor_180.tres",
	"forest_240": "res://resources/races/forest_240.tres",
	"national_stock_car": "res://resources/races/national_stock_car_300.tres",
	"championship_300": "res://resources/races/championship_300.tres"
}
const RACE_STRATEGIES: Dictionary = {
	"conservative": {
		"name": "Conservative",
		"performance_modifier": 0.97,
		"variance_modifier": 0.70,
		"wear_modifier": 0.75
	},
	"balanced": {
		"name": "Balanced",
		"performance_modifier": 1.0,
		"variance_modifier": 1.0,
		"wear_modifier": 1.0
	},
	"aggressive": {
		"name": "Aggressive",
		"performance_modifier": 1.04,
		"variance_modifier": 1.40,
		"wear_modifier": 1.35
	}
}

const AI_DRIVERS: Array[Dictionary] = [
	{
		"driver_id": "logan_brooks",
		"driver_name": "Logan Brooks",
		"team_name": "Redline Racing",
		"skill": 65,
		"consistency": 62,
		"aggression": 58
	},
	{
		"driver_id": "emma_carter",
		"driver_name": "Emma Carter",
		"team_name": "Summit Motorsports",
		"skill": 61,
		"consistency": 70,
		"aggression": 48
	},
	{
		"driver_id": "mason_reed",
		"driver_name": "Mason Reed",
		"team_name": "Blue Ridge Racing",
		"skill": 68,
		"consistency": 55,
		"aggression": 72
	},
	{
		"driver_id": "ava_morgan",
		"driver_name": "Ava Morgan",
		"team_name": "Velocity Autosport",
		"skill": 60,
		"consistency": 67,
		"aggression": 54
	},
	{
		"driver_id": "caleb_turner",
		"driver_name": "Caleb Turner",
		"team_name": "Iron Horse Racing",
		"skill": 58,
		"consistency": 60,
		"aggression": 65
	},
	{
		"driver_id": "sophia_bennett",
		"driver_name": "Sophia Bennett",
		"team_name": "Northstar Motorsports",
		"skill": 64,
		"consistency": 73,
		"aggression": 45
	},
	{
		"driver_id": "ethan_walker",
		"driver_name": "Ethan Walker",
		"team_name": "Thunder Valley Racing",
		"skill": 62,
		"consistency": 58,
		"aggression": 69
	}
]

var last_result: RaceResult = null

var random_number_generator := (
	RandomNumberGenerator.new()
)


func _ready() -> void:
	random_number_generator.randomize()


func get_race_by_id(race_id: String) -> Race:
	var path := str(RACE_RESOURCE_PATHS.get(race_id, ""))
	if path.is_empty():
		return null
	return load(path) as Race


func get_calendar_for_series(series_id: String) -> Array[Race]:
	var series := SeriesCatalog.get_series(series_id)
	var calendar: Array[Race] = []
	if series.is_empty(): return calendar
	var template := get_race_by_id("spring_100")
	for event in CalendarCatalog.get_events(series_id):
		var race := template.duplicate(true) as Race
		race.series_id = series_id
		race.race_id = str(event.race_id); race.race_name = str(event.race_name)
		race.track_name = str(event.track_name); race.race_date = str(event.race_date)
		race.travel_region = str(event.travel_region); race.track_type = str(event.track_type)
		race.season_round = int(event.season_round)
		var multiplier := float(series.weekend_cost_multiplier)
		race.entry_fee = roundi(race.entry_fee * multiplier); race.travel_cost = roundi(race.travel_cost * multiplier)
		race.preparation_cost = roundi(race.preparation_cost * multiplier); race.insurance_cost = roundi(race.insurance_cost * multiplier)
		race.facility_cost = roundi(race.facility_cost * multiplier)
		race.first_place_prize = roundi(race.first_place_prize * multiplier); race.second_place_prize = roundi(race.second_place_prize * multiplier); race.third_place_prize = roundi(race.third_place_prize * multiplier)
		calendar.append(race)
	return calendar


func get_race_for_series_by_id(series_id: String, race_id: String) -> Race:
	for race in get_calendar_for_series(series_id):
		if race.race_id == race_id:
			return race
	return null


func get_maximum_field_size(series_id: String) -> int:
	return int(SeriesCatalog.get_series(series_id).get("maximum_field_size", AI_DRIVERS.size() + 1))


func get_eligible_drivers_for_race(team: Team, race: Race) -> Array[Driver]:
	if team == null or race == null:
		return []
	var drivers := team.get_drivers_for_series(race.series_id)
	drivers.resize(mini(drivers.size(), get_maximum_field_size(race.series_id)))
	return drivers


func get_ai_field_for_race(race: Race, player_entry_count: int = 1) -> Array[Dictionary]:
	if race == null: return []
	var roster := AIRosterCatalog.get_roster(race.series_id)
	roster.resize(maxi(0, get_maximum_field_size(race.series_id) - maxi(1, player_entry_count)))
	return roster


func get_next_race(team: Team) -> Race:
	if team == null or team.is_series_season_complete():
		return null
	for race in get_calendar_for_series(team.current_series_id):
		var race_id := race.race_id
		if team.get_unlocked_races().has(race_id) and not team.get_completed_races().has(race_id):
			return race
	return null


func create_live_simulation(
	selected_race: Race,
	player_car: Car,
	selected_strategy: String,
	weekend_data: Dictionary
) -> RaceSimulation:
	if selected_race == null or player_car == null or GameManager.team == null:
		return null
	var player_driver := _get_entry_driver(weekend_data)
	if player_driver == null:
		return null
	var ai_scores: Array[float] = []
	var detailed_ai_drivers: Array[Dictionary] = []
	var player_entry_count := maxi(1, (weekend_data.get("entries", []) as Array).size())
	var ai_roster := get_ai_field_for_race(selected_race, player_entry_count)
	for ai_driver in ai_roster:
		ai_scores.append(calculate_ai_score(selected_race, ai_driver))
		var detailed := ai_driver.duplicate(true)
		detailed["attributes"] = _normalized_ai_attributes(ai_driver)
		detailed_ai_drivers.append(detailed)
	var simulation := RaceSimulation.new()
	var compound := "Medium"
	var plan := str(weekend_data.get("pre_race_plan", ""))
	if plan.begins_with("Hard"):
		compound = "Hard"
	elif plan.begins_with("Soft"):
		compound = "Soft"
	simulation.setup(
		selected_race,
		player_driver,
		GameManager.team.team_name,
		calculate_player_score(player_car, player_driver, selected_strategy, selected_race)
			+ float(weekend_data.get("setup_bonus", 0.0))
			+ float(weekend_data.get("race_modifier", 0.0)),
		int(weekend_data.get("starting_position", detailed_ai_drivers.size() + 1)),
		detailed_ai_drivers,
		ai_scores,
		compound,
		_build_additional_team_entries(selected_race, selected_strategy, weekend_data),
		int(weekend_data.get("simulation_seed", -1)),
		player_car.get_race_attributes(),
		str(weekend_data.get("setup_emphasis", "Balanced"))
	)
	return simulation


func _get_entry_driver(weekend_data: Dictionary) -> Driver:
	var entries := weekend_data.get("entries", []) as Array
	if not entries.is_empty():
		var entry := entries[0] as Dictionary
		var assigned := GameManager.team.get_driver_by_id(str(entry.get("driver_id", "")))
		if assigned != null:
			return assigned
	return GameManager.team.get_active_driver()


func _build_additional_team_entries(selected_race: Race, selected_strategy: String, weekend_data: Dictionary) -> Array:
	var entries: Array = []
	var selected_entries := weekend_data.get("entries", []) as Array
	var maximum_players := mini(selected_entries.size(), get_maximum_field_size(selected_race.series_id))
	for index in range(1, maximum_players):
		var entry := selected_entries[index] as Dictionary
		var driver := GameManager.team.get_driver_by_id(str(entry.get("driver_id", "")))
		var car := GameManager.team.get_car(int(entry.get("car_bay", -1)))
		if driver == null or car == null or driver.series_id != selected_race.series_id or car.series_id != selected_race.series_id:
			continue
		entries.append({
			"driver_id": driver.driver_id,
			"driver_name": driver.driver_name,
			"team_name": str(entry.get("team_name", GameManager.team.team_name)),
			"consistency": driver.consistency,
			"attributes": driver.get_attribute_dictionary(),
			"score": calculate_player_score(car, driver, selected_strategy, selected_race),
			"starting_position": int(weekend_data.get("starting_position", AI_DRIVERS.size() + 1)) + index
		})
	return entries


func finalize_live_race(
	simulation: RaceSimulation,
	player_car: Car,
	selected_strategy: String,
	weekend_data: Dictionary
) -> RaceResult:
	if simulation == null or not simulation.is_complete or player_car == null:
		push_error("Cannot finalize an incomplete live race.")
		return null
	var selected_race := simulation.race
	var player_driver := _get_entry_driver(weekend_data)
	initialize_championship_standings(player_driver)
	var strategy := get_strategy(selected_strategy)
	var result := RaceResult.new()
	result.race = selected_race
	result.player_car = player_car
	result.player_driver = player_driver
	result.entry_fee = int(weekend_data.get("entry_fee_total", selected_race.entry_fee))
	result.driver_salary = player_driver.salary
	result.strategy_id = normalize_strategy_id(selected_strategy)
	result.strategy_name = str(strategy.get("name", "Balanced"))
	result.strategy_performance_modifier = float(strategy.get("performance_modifier", 1.0))
	result.strategy_variance_modifier = float(strategy.get("variance_modifier", 1.0))
	result.strategy_wear_modifier = float(strategy.get("wear_modifier", 1.0))
	result.starting_position = int(weekend_data.get("starting_position", AI_DRIVERS.size() + 1))
	result.practice_focus_name = str(weekend_data.get("practice_focus_name", "None"))
	result.qualifying_approach_name = str(weekend_data.get("qualifying_approach_name", "Balanced lap"))
	result.qualifying_score = float(weekend_data.get("qualifying_score", 0.0))
	result.setup_bonus = float(weekend_data.get("setup_bonus", 0.0))
	result.strategy_effectiveness = float(weekend_data.get("race_modifier", 0.0))
	for summary in weekend_data.get("decision_log", []):
		result.weekend_summary.append(str(summary))
	result.weekend_summary.append("Live timing completed over %d laps." % selected_race.lap_count)
	result.standings = simulation.as_final_standings()
	result.field_size = result.standings.size()
	result.finishing_position = find_player_position(result.standings)
	result.positions_gained = result.starting_position - result.finishing_position
	_populate_decisive_factors(result, simulation)
	result.prize_money = calculate_prize_money(selected_race, result.finishing_position)
	result.championship_points_earned = calculate_championship_points(selected_race.series_id, {"position":result.finishing_position})
	result.mileage_added = calculate_mileage_added(selected_race)
	result.condition_lost = calculate_condition_loss(selected_race, result.strategy_id)
	result.condition_lost = maxi(1, roundi(float(result.condition_lost) * float(weekend_data.get("wear_modifier", 1.0))))
	result.net_earnings = result.prize_money - result.entry_fee - result.driver_salary
	var staff_payroll := GameManager.team.process_staff_race()
	result.crew_chief_salary = int(staff_payroll.get("crew_chief_salary", 0))
	result.engineering_payroll = int(staff_payroll.get("engineering_payroll", 0))
	for expired_name in staff_payroll.get("expired_names", []):
		result.expired_staff_names.append(str(expired_name))
	result.net_earnings -= result.crew_chief_salary + result.engineering_payroll
	player_driver.record_race({"race_id":selected_race.race_id, "race_name":selected_race.race_name, "start":result.starting_position, "finish":result.finishing_position, "positions_gained":result.positions_gained, "qualifying":result.starting_position, "points":result.championship_points_earned, "track_type":selected_race.track_type, "weather":selected_race.weather, "status":str((result.standings[result.finishing_position - 1] as Dictionary).get("status", "Finished")), "incident":false})
	apply_race_effects(result)
	complete_race(selected_race)
	last_result = result
	GameManager.save_game()
	return result


func run_race(
	selected_race: Race,
	player_car: Car,
	selected_strategy: String = DEFAULT_STRATEGY,
	weekend_data: Dictionary = {}
) -> RaceResult:
	if selected_race == null:
		push_error(
			"Cannot run a race without a selected race."
		)
		return null

	if player_car == null:
		push_error(
			"Cannot run a race without a selected car."
		)
		return null

	if selected_race.race_id.is_empty():
		push_error(
			"Cannot run a race without a race_id."
		)
		return null

	if GameManager.team == null:
		push_error(
			"Cannot run a race without a loaded team."
		)
		return null

	if not GameManager.team.driver_hired_for_season:
		push_error(
			"Cannot run a race before hiring a driver for the season."
		)
		return null

	var player_driver: Driver = (
		GameManager.team.get_active_driver()
	)

	if player_driver == null:
		push_error(
			"Cannot run a race without a player driver."
		)
		return null

	player_driver.team_name = GameManager.team.team_name

	initialize_championship_standings(
		player_driver
	)

	var result := RaceResult.new()
	var strategy := get_strategy(selected_strategy)

	result.race = selected_race
	result.player_car = player_car
	result.player_driver = player_driver
	result.entry_fee = selected_race.entry_fee
	result.driver_salary = player_driver.salary
	result.strategy_id = normalize_strategy_id(selected_strategy)
	result.strategy_name = str(strategy.get("name", "Balanced"))
	result.strategy_performance_modifier = float(strategy.get("performance_modifier", 1.0))
	result.strategy_variance_modifier = float(strategy.get("variance_modifier", 1.0))
	result.strategy_wear_modifier = float(strategy.get("wear_modifier", 1.0))
	result.starting_position = int(weekend_data.get("starting_position", AI_DRIVERS.size() + 1))
	result.practice_focus_name = str(weekend_data.get("practice_focus_name", "None"))
	result.qualifying_approach_name = str(weekend_data.get("qualifying_approach_name", "Balanced lap"))
	result.qualifying_score = float(weekend_data.get("qualifying_score", 0.0))
	result.setup_bonus = float(weekend_data.get("setup_bonus", 0.0))
	result.strategy_effectiveness = float(weekend_data.get("race_modifier", 0.0))
	for summary in weekend_data.get("decision_log", []):
		result.weekend_summary.append(str(summary))

	var race_standings: Array[Dictionary] = []

	for ai_driver in get_ai_field_for_race(selected_race):
		race_standings.append({
			"driver_id": str(
				ai_driver.get("driver_id", "")
			),
			"driver_name": str(
				ai_driver.get(
					"driver_name",
					"Unknown Driver"
				)
			),
			"team_name": str(
				ai_driver.get(
					"team_name",
					"Unknown Team"
				)
			),
			"score": calculate_ai_score(
				selected_race,
				ai_driver
			),
			"is_player": false
		})

	race_standings.append({
		"driver_id": player_driver.driver_id,
		"driver_name": player_driver.driver_name,
		"team_name": GameManager.team.team_name,
		"score": calculate_player_score(
			player_car,
			player_driver,
			result.strategy_id,
			selected_race
		) + result.setup_bonus + result.strategy_effectiveness,
		"is_player": true
	})

	race_standings.sort_custom(
		func(
			first_entry: Dictionary,
			second_entry: Dictionary
		) -> bool:
			return (
				float(
					first_entry.get("score", 0.0)
				)
				> float(
					second_entry.get("score", 0.0)
				)
			)
	)

	result.standings = race_standings
	result.field_size = race_standings.size()

	result.finishing_position = (
		find_player_position(race_standings)
	)
	result.positions_gained = result.starting_position - result.finishing_position
	_populate_decisive_factors(result)

	result.prize_money = calculate_prize_money(
		selected_race,
		result.finishing_position
	)

	result.championship_points_earned = (
		calculate_championship_points(selected_race.series_id, {"position":result.finishing_position})
	)

	result.mileage_added = calculate_mileage_added(
		selected_race
	)

	result.condition_lost = calculate_condition_loss(
		selected_race,
		result.strategy_id
	)
	result.condition_lost = maxi(1, roundi(float(result.condition_lost) * float(weekend_data.get("wear_modifier", 1.0))))

	result.net_earnings = (
		result.prize_money
		- result.entry_fee
		- result.driver_salary
	)
	var staff_payroll := GameManager.team.process_staff_race()
	result.crew_chief_salary = int(staff_payroll.get("crew_chief_salary", 0))
	result.engineering_payroll = int(staff_payroll.get("engineering_payroll", 0))
	for expired_name in staff_payroll.get("expired_names", []):
		result.expired_staff_names.append(str(expired_name))
	result.net_earnings -= result.crew_chief_salary + result.engineering_payroll

	apply_race_effects(result)
	complete_race(selected_race)

	last_result = result

	GameManager.save_game()

	return result


func _populate_decisive_factors(result: RaceResult, simulation: RaceSimulation = null) -> void:
	if result.player_driver == null or result.player_car == null:
		return
	# The neutral 50-rated driver/car baselines mirror the weighted score model.
	result.driver_factor = (
		(float(result.player_driver.skill) - 50.0) * 0.20
		+ (float(result.player_driver.consistency) - 50.0) * 0.10
		+ (float(result.player_driver.aggression) - 50.0) * 0.03
	)
	result.car_factor = (
		(float(result.player_car.get_total_performance()) - 50.0) * 0.55
		+ (float(result.player_car.condition) - 75.0) * 0.08
	)
	result.setup_factor = result.setup_bonus
	result.strategy_factor = result.strategy_effectiveness
	if result.strategy_id == "aggressive":
		result.strategy_factor += 2.0
	elif result.strategy_id == "conservative":
		result.strategy_factor -= 1.5
	if simulation == null:
		result.incident_factor = clampf(float(result.positions_gained) * 0.35, -3.0, 3.0)
		result.incident_summary = "Race variance was estimated from the difference between grid and finish"
		return
	var player_entry := simulation.get_player_entry()
	if player_entry != null:
		result.pit_stop_factor = -float(player_entry.pit_stops) * 0.8
		result.pit_stop_summary = "%d stop%s; time loss was partly offset by fresher tyres" % [player_entry.pit_stops, "" if player_entry.pit_stops == 1 else "s"]
	var mistakes := 0
	for event in simulation.event_log:
		if "mistake" in event.to_lower():
			mistakes += 1
	result.incident_factor = -float(mistakes) * 1.5
	result.incident_summary = "%d costly random incident%s recorded" % [mistakes, "" if mistakes == 1 else "s"] if mistakes > 0 else "No significant random incident recorded"


func calculate_player_score(
	player_car: Car,
	player_driver: Driver,
	selected_strategy: String = DEFAULT_STRATEGY,
	selected_race: Race = null
) -> float:
	var strategy := get_strategy(selected_strategy)
	var car_performance := float(player_car.get_total_performance())
	var team := GameManager.team
	if team != null:
		var part_bonus := 0
		var body_bonus := 0
		for part in player_car.installed_parts:
			if part is CarPart:
				part_bonus += part.get_effective_performance_bonus()
				if part.part_type == "Body":
					body_bonus += part.get_effective_performance_bonus()
		car_performance += float(part_bonus) * team.get_department_bonus("engineering") / 100.0
		car_performance += float(body_bonus) * team.get_department_bonus("wind_tunnel") / 100.0
		car_performance *= 1.0 + team.get_department_bonus("cheating") / 100.0
		car_performance *= 1.0 + (team.get_crew_chief_performance_boost() + team.get_engineering_performance_boost()) / 100.0
	# A stock car should run in the midfield; several meaningful part upgrades
	# are required before its raw pace matches the established front-runners.
	var performance_score: float = car_performance * 0.55

	var condition_score: float = (
		float(player_car.condition) * 0.08
	)

	var driver_boost := team.get_department_bonus("driver_development") if team != null else 0.0
	var simulator_boost := team.get_department_bonus("simulator") if team != null else 0.0
	var detailed_driver_score := calculate_driver_attribute_score(selected_race, player_driver.get_attribute_dictionary())
	var driver_attribute_score: float = detailed_driver_score * (1.0 + driver_boost / 100.0) * 0.30
	var feedback_score := float(player_driver.car_feedback) * (1.0 + simulator_boost / 100.0) * 0.04

	var variance_limit: float = lerpf(
		12.0,
		4.0,
		float(player_driver.consistency) / 100.0
	)
	if team != null:
		variance_limit = maxf(1.0, variance_limit - team.get_car_setup_variance_reduction())
	var variance_modifier := float(strategy.get("variance_modifier", 1.0))
	if normalize_strategy_id(selected_strategy) == "aggressive" and selected_race != null:
		variance_modifier += float(selected_race.difficulty) / 500.0
	variance_limit *= variance_modifier

	var random_variance: float = (
		random_number_generator.randf_range(
			-variance_limit,
			variance_limit
		)
	)

	var spotter_restart_bonus := team.get_restart_performance_boost() if team != null else 0.0

	var total_score := (
		performance_score
		+ condition_score
		+ driver_attribute_score
		+ feedback_score
		+ spotter_restart_bonus
		+ random_variance
	)
	return total_score * float(strategy.get("performance_modifier", 1.0))


func calculate_ai_score(
	selected_race: Race,
	ai_driver: Dictionary
) -> float:
	var attributes := _normalized_ai_attributes(ai_driver)
	var consistency := int(attributes.get("consistency", 50))

	var career_growth := 0.0
	if GameManager.team != null:
		career_growth = float(GameManager.team.season_number - 1) * float(GameManager.team.get_difficulty_setting("ai_growth", 0.75))
	var difficulty_score: float = (
		34.0
		+ float(selected_race.difficulty) * 0.30
		+ career_growth
	)

	var driver_attribute_score := calculate_driver_attribute_score(selected_race, attributes) * 0.43

	var variance_limit: float = lerpf(
		12.0,
		4.0,
		float(consistency) / 100.0
	)

	var random_variance: float = (
		random_number_generator.randf_range(
			-variance_limit,
			variance_limit
		)
	)

	return (
		difficulty_score
		+ driver_attribute_score
		+ random_variance
	)


func calculate_driver_attribute_score(selected_race: Race, attributes: Dictionary) -> float:
	var weights := selected_race.get_driver_attribute_weights() if selected_race != null else {}
	var total := 0.0
	var weight_total := 0.0
	for field in Driver.RATING_FIELDS:
		var weight := float(weights.get(field, 0.10))
		total += float(attributes.get(field, 50)) * weight
		weight_total += weight
	return total / maxf(0.01, weight_total)


func _normalized_ai_attributes(data: Dictionary) -> Dictionary:
	if data.has("race_pace"):
		return data
	var skill := int(data.get("skill", 50)); var consistency := int(data.get("consistency", 50)); var aggression := int(data.get("aggression", 50))
	return {"race_pace":skill, "qualifying_pace":skill, "tyre_management":consistency, "racecraft":roundi((skill+aggression)/2.0), "wet_weather":skill-3, "starts_restarts":aggression, "consistency":consistency, "car_feedback":consistency, "fitness":consistency, "composure":consistency}


func find_player_position(
	race_standings: Array[Dictionary]
) -> int:
	for index in range(race_standings.size()):
		var entry: Dictionary = race_standings[index]

		if bool(entry.get("is_player", false)):
			return index + 1

	return race_standings.size()


func calculate_prize_money(
	selected_race: Race,
	finishing_position: int
) -> int:
	if finishing_position == 1:
		return selected_race.first_place_prize
	if finishing_position == 2:
		return selected_race.second_place_prize
	if finishing_position == 3:
		return selected_race.third_place_prize
	# Weekly short-track purses pay the whole field, including start money.
	var base_payouts: Array[int] = [175, 150, 125, 110, 100, 90, 85]
	var base := base_payouts[finishing_position - 4] if finishing_position >= 4 and finishing_position <= 10 else 75
	return roundi(float(base) * float(selected_race.first_place_prize) / 500.0)


func calculate_mileage_added(
	selected_race: Race
) -> int:
	return selected_race.lap_count


func calculate_condition_loss(
	selected_race: Race,
	selected_strategy: String = DEFAULT_STRATEGY
) -> int:
	var base_wear: int = (
		random_number_generator.randi_range(
			2,
			5
		)
	)

	var difficulty_wear: int = roundi(
		float(selected_race.difficulty) / 25.0
	)

	var distance_wear: int = roundi(
		float(selected_race.lap_count) / 100.0
	)

	var balanced_wear := maxi(
		1,
		base_wear
		+ difficulty_wear
		+ distance_wear
	)
	var wear_modifier := float(
		get_strategy(selected_strategy).get("wear_modifier", 1.0)
	)
	return maxi(1, roundi(float(balanced_wear) * wear_modifier))


func normalize_strategy_id(selected_strategy: String) -> String:
	if RACE_STRATEGIES.has(selected_strategy):
		return selected_strategy
	return DEFAULT_STRATEGY


func get_strategy(selected_strategy: String) -> Dictionary:
	return RACE_STRATEGIES[normalize_strategy_id(selected_strategy)]


func apply_race_effects(
	result: RaceResult
) -> void:
	if result == null:
		return

	if result.player_car == null:
		return

	if GameManager.team == null:
		return

	result.player_car.mileage += (
		result.mileage_added
	)
	# Engineering reliability and spotter awareness prevent avoidable race damage.
	var protection := (
		GameManager.team.get_reliability_boost()
		+ GameManager.team.get_accident_risk_reduction()
	)
	result.condition_lost = maxi(
		1,
		roundi(float(result.condition_lost) * (1.0 - minf(0.30, protection / 100.0)))
	)

	result.player_car.condition = maxi(
		0,
		result.player_car.condition
		- result.condition_lost
	)
	for part in result.player_car.installed_parts:
		if part is CarPart:
			part.condition = maxi(0, part.condition - maxi(1, result.condition_lost / 3))
			part.emit_changed()

	result.player_car.emit_changed()

	GameManager.add_team_money(
		result.prize_money
	)
	GameManager.team.record_finance("Race", result.prize_money, "Prize money")
	GameManager.charge_team_money(
		result.driver_salary
	)
	GameManager.team.record_finance("Payroll", -result.driver_salary, "Driver salary")
	apply_department_race_effects(result)

	apply_reputation_reward(result)
	apply_sponsor_reward(result)

	update_championship_standings(
		result.standings
	)

	update_driver_career_stats(result)

	var player_entry: Dictionary = (
		GameManager.team
		.get_player_championship_entry()
	)

	result.total_championship_points = int(
		player_entry.get("points", 0)
	)

	GameManager.team.championship_points = (
		result.total_championship_points
	)

	GameManager.team.emit_changed()


func apply_department_race_effects(result: RaceResult) -> void:
	var team := GameManager.team
	var base_fans := maxi(10, 110 - result.finishing_position * 5)
	result.fans_earned = roundi(float(base_fans) * (1.0 + team.get_department_bonus("marketing") / 100.0))
	team.fans += result.fans_earned

	var cheating_level := team.get_department_level("cheating")
	if cheating_level > 0:
		var penalty_chance := 0.04 + float(cheating_level) * 0.04
		if random_number_generator.randf() < penalty_chance:
			result.cheating_penalty = 1000 * cheating_level * cheating_level
			GameManager.charge_team_money(result.cheating_penalty)
			team.record_finance("Penalty", -result.cheating_penalty, "Rules penalty")
			result.net_earnings -= result.cheating_penalty


func apply_reputation_reward(result: RaceResult) -> void:
	var position := result.finishing_position
	if position == 1:
		result.reputation_earned = 25
	elif position <= 5:
		result.reputation_earned = 15
	elif position <= 10:
		result.reputation_earned = 10
	elif position <= 15:
		result.reputation_earned = 5
	elif position > 0:
		result.reputation_earned = 2

	GameManager.team.reputation += result.reputation_earned


func apply_sponsor_reward(result: RaceResult) -> void:
	var team := GameManager.team
	if team.active_sponsor_id.is_empty():
		return

	var sponsor := SponsorCatalog.find_by_id(team.active_sponsor_id)
	if sponsor == null:
		push_warning("Saved sponsor no longer exists: %s" % team.active_sponsor_id)
		team.active_sponsor_id = ""
		team.sponsor_races_remaining = 0
		return

	result.sponsor_name = sponsor.sponsor_name
	result.sponsor_race_payment = roundi(float(sponsor.payment_per_race) * float(team.get_difficulty_setting("sponsor_multiplier", 1.0)))
	GameManager.add_team_money(result.sponsor_race_payment)
	team.record_finance("Sponsor", result.sponsor_race_payment, "%s race payment" % sponsor.sponsor_name)
	result.net_earnings += result.sponsor_race_payment

	if (
		not team.sponsor_objective_completed
		and sponsor.result_advances_objective(result.finishing_position)
	):
		team.sponsor_objective_progress += 1
		if team.sponsor_objective_progress >= sponsor.objective_target:
			team.sponsor_objective_completed = true
			result.sponsor_objective_completed = true
			result.sponsor_objective_bonus = roundi(float(sponsor.objective_bonus) * float(team.get_difficulty_setting("sponsor_multiplier", 1.0)))
			GameManager.add_team_money(result.sponsor_objective_bonus)
			team.record_finance("Sponsor", result.sponsor_objective_bonus, "%s objective bonus" % sponsor.sponsor_name)
			result.net_earnings += result.sponsor_objective_bonus

	team.sponsor_races_remaining = maxi(0, team.sponsor_races_remaining - 1)
	if team.sponsor_races_remaining == 0:
		team.active_sponsor_id = ""


func update_driver_career_stats(
	result: RaceResult
) -> void:
	if result.player_driver == null:
		return

	var driver: Driver = result.player_driver

	driver.career_starts += 1
	driver.season_starts += 1
	driver.career_points += (
		result.championship_points_earned
	)
	driver.development_points += 1
	var development_bonus := GameManager.team.get_department_bonus("driver_development") / 100.0
	GameManager.team.driver_development_progress += development_bonus
	if GameManager.team.driver_development_progress >= 1.0:
		driver.development_points += floori(GameManager.team.driver_development_progress)
		GameManager.team.driver_development_progress = fmod(GameManager.team.driver_development_progress, 1.0)

	if result.finishing_position == 1:
		driver.career_wins += 1
		driver.development_points += 1

	if result.finishing_position <= 3:
		driver.career_podiums += 1
		driver.development_points += 1

	if (
		driver.potential >= 85
		and (driver.career_starts + driver.career_points) % 3 == 0
	):
		driver.development_points += 1

	driver.emit_changed()


func initialize_championship_standings(
	player_driver: Driver
) -> void:
	if GameManager.team == null:
		return

	ensure_championship_entry(
		player_driver.driver_id,
		player_driver.driver_name,
		GameManager.team.team_name,
		true
	)

	for ai_driver in AIRosterCatalog.get_roster(GameManager.team.current_series_id):
		ensure_championship_entry(
			str(ai_driver.get("driver_id", "")),
			str(
				ai_driver.get(
					"driver_name",
					"Unknown Driver"
				)
			),
			str(
				ai_driver.get(
					"team_name",
					"Unknown Team"
				)
			),
			false
		)

	for entry in (
		GameManager.team.get_championship_standings()
	):
		if bool(entry.get("is_player", false)):
			entry["driver_name"] = (
				player_driver.driver_name
			)

			entry["team_name"] = (
				GameManager.team.team_name
			)

	GameManager.team.emit_changed()


func ensure_championship_entry(
	driver_id: String,
	driver_name: String,
	team_name: String,
	is_player: bool
) -> void:
	if GameManager.team == null:
		return

	for entry in (
		GameManager.team.get_championship_standings()
	):
		if str(
			entry.get("driver_id", "")
		) == driver_id:
			normalize_championship_entry(entry)

			entry["driver_name"] = driver_name
			entry["team_name"] = team_name
			entry["is_player"] = is_player
			return

	GameManager.team.get_championship_standings().append({
		"driver_id": driver_id,
		"driver_name": driver_name,
		"team_name": team_name,
		"points": 0,
		"wins": 0,
		"podiums": 0,
		"is_player": is_player
	})


func normalize_championship_entry(
	entry: Dictionary
) -> void:
	if not entry.has("driver_id"):
		entry["driver_id"] = ""

	if not entry.has("driver_name"):
		entry["driver_name"] = "Unknown Driver"

	if not entry.has("team_name"):
		entry["team_name"] = "Unknown Team"

	if not entry.has("points"):
		entry["points"] = 0

	if not entry.has("wins"):
		entry["wins"] = 0

	if not entry.has("podiums"):
		entry["podiums"] = 0

	if not entry.has("is_player"):
		entry["is_player"] = false


func update_championship_standings(
	race_standings: Array[Dictionary]
) -> void:
	if GameManager.team == null:
		return

	for index in range(race_standings.size()):
		var race_entry: Dictionary = (
			race_standings[index]
		)

		var finishing_position: int = index + 1

		var points_earned: int = (
			calculate_championship_points(GameManager.team.current_series_id, {"position":finishing_position})
		)

		var championship_entry: Dictionary = (
			find_championship_entry(
				race_entry
			)
		)

		if championship_entry.is_empty():
			push_error(
				"Could not find championship entry "
				+ "for driver: "
				+ str(
					race_entry.get(
						"driver_name",
						"Unknown Driver"
					)
				)
			)
			continue

		championship_entry["points"] = (
			int(
				championship_entry.get(
					"points",
					0
				)
			)
			+ points_earned
		)

		if finishing_position == 1:
			championship_entry["wins"] = (
				int(
					championship_entry.get(
						"wins",
						0
					)
				)
				+ 1
			)

		if finishing_position <= 3:
			championship_entry["podiums"] = (
				int(
					championship_entry.get(
						"podiums",
						0
					)
				)
				+ 1
			)
		championship_entry["best_finish"] = mini(finishing_position, int(championship_entry.get("best_finish", 999)))

	GameManager.team.set_series_standings(GameManager.team.current_series_id, GameManager.team.get_sorted_championship_standings())

	GameManager.team.emit_changed()


func find_championship_entry(
	race_entry: Dictionary
) -> Dictionary:
	if GameManager.team == null:
		return {}

	var driver_id: String = str(
		race_entry.get("driver_id", "")
	)

	for championship_entry in (
		GameManager.team.get_championship_standings()
	):
		if str(
			championship_entry.get(
				"driver_id",
				""
			)
		) == driver_id:
			return championship_entry

	return {}


func complete_race(
	completed_race: Race
) -> void:
	if GameManager.team == null:
		return

	if completed_race == null:
		return

	if completed_race.race_id.is_empty():
		push_error(
			"Cannot complete a race without a race_id."
		)
		return

	if not GameManager.team.get_completed_races().has(
		completed_race.race_id
	):
		GameManager.team.complete_race_for_series(completed_race.series_id, completed_race.race_id)
	GameManager.team.save_series_progress()
	simulate_other_series_through_round(GameManager.team.get_completed_races().size())
	GameManager.team.week_advance_required = true

	GameManager.team.emit_changed()
	finish_season_if_complete()


func simulate_other_series_through_round(target_round: int) -> void:
	if GameManager.team == null:
		return
	GameManager.team.ensure_world_series_data()
	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		if series_id == GameManager.team.current_series_id:
			continue
		var calendar := get_calendar_for_series(series_id)
		var series_data := GameManager.team.get_world_series_data(series_id)
		var completed_rounds := int(series_data.get("completed_rounds", 0))
		var last_round := mini(target_round, calendar.size())
		while completed_rounds < last_round:
			_simulate_world_series_race(series_id, calendar[completed_rounds], series_data)
			completed_rounds += 1
			series_data["completed_rounds"] = completed_rounds
		GameManager.team.set_world_series_data(series_id, series_data)


func _simulate_world_series_race(series_id: String, race: Race, series_data: Dictionary) -> void:
	var field: Array[Dictionary] = []
	for driver in AIRosterCatalog.get_roster(series_id):
		field.append({
			"driver_id": str(driver.driver_id),
			"driver_name": str(driver.driver_name),
			"team_name": str(driver.team_name),
			"score": calculate_ai_score(race, driver)
		})
	field.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.score) > float(second.score))
	var standings: Array[Dictionary] = series_data.get("standings", [])
	if standings.is_empty():
		for driver in AIRosterCatalog.get_roster(series_id):
			standings.append({"driver_id":str(driver.driver_id), "driver_name":str(driver.driver_name), "team_name":str(driver.team_name), "points":0, "wins":0, "podiums":0, "starts":0, "best_finish":999, "average_finish_total":0})
	var result_rows: Array[Dictionary] = []
	for index in field.size():
		var race_entry := field[index]
		var position := index + 1
		result_rows.append({"position":position, "driver_id":race_entry.driver_id, "driver_name":race_entry.driver_name, "team_name":race_entry.team_name})
		for championship_entry in standings:
			if str(championship_entry.driver_id) != str(race_entry.driver_id):
				continue
			championship_entry["points"] = int(championship_entry.points) + calculate_championship_points(series_id, {"position":position})
			championship_entry["starts"] = int(championship_entry.starts) + 1
			championship_entry["average_finish_total"] = int(championship_entry.average_finish_total) + position
			championship_entry["best_finish"] = mini(int(championship_entry.best_finish), position)
			if position == 1: championship_entry["wins"] = int(championship_entry.wins) + 1
			if position <= 3: championship_entry["podiums"] = int(championship_entry.podiums) + 1
			break
	standings.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first.points) == int(second.points): return int(first.best_finish) < int(second.best_finish)
		return int(first.points) > int(second.points))
	var results: Array = series_data.get("results", [])
	results.append({"race_id":race.race_id, "race_name":race.race_name, "track_name":race.track_name, "round":race.season_round, "rows":result_rows})
	series_data["results"] = results
	series_data["standings"] = standings


func finish_season_if_complete() -> void:
	if GameManager.team == null:
		return

	if GameManager.team.is_series_season_complete():
		return

	for race in get_calendar_for_series(GameManager.team.current_series_id):
		var race_id := race.race_id
		if not GameManager.team.get_completed_races().has(race_id):
			return

	var standings := (
		GameManager.team.get_sorted_championship_standings()
	)
	var player_position: int = 0

	for index in range(standings.size()):
		if bool(standings[index].get("is_player", false)):
			player_position = index + 1
			break

	var prize_money: int = calculate_season_prize(player_position, GameManager.team.current_series_id)

	GameManager.team.set_series_season_complete(GameManager.team.current_series_id, true)
	GameManager.team.last_season_position = player_position
	GameManager.team.last_season_prize = prize_money
	if player_position == 1:
		GameManager.team.reputation += 100
	GameManager.add_team_money(prize_money)
	GameManager.team.record_finance("Championship", prize_money, "Season prize")
	GameManager.team.emit_changed()


func calculate_season_prize(finishing_position: int, series_id: String = "local_short_track") -> int:
	if finishing_position <= 0:
		return 0

	var payouts: Array = SeriesCatalog.get_series(series_id).get("championship_payouts", SEASON_PRIZES)
	if finishing_position > payouts.size():
		return 0
	return int(payouts[finishing_position - 1])


func start_new_season() -> bool:
	if GameManager.team == null:
		return false

	if not GameManager.team.is_series_season_complete():
		return false

	apply_driver_development()
	GameManager.team.process_staff_season()

	GameManager.team.last_season_position = 0
	GameManager.team.last_season_prize = 0
	var calendar := get_calendar_for_series(GameManager.team.current_series_id)
	GameManager.team.reset_series_season(GameManager.team.current_series_id, calendar[0].race_id if not calendar.is_empty() else "")
	GameManager.team.championship_points = 0
	GameManager.team.driver_hired_for_season = false
	GameManager.team.current_race_week = 1
	GameManager.team.week_advance_required = false
	GameManager.team.engineering_projects.clear()
	for contracted_driver in GameManager.team.get_contracted_drivers():
		contracted_driver.is_player_driver = false
		contracted_driver.team_name = "Free Agent"
	GameManager.team.contracted_driver_ids.clear()
	for race_team in GameManager.team.race_teams:
		if race_team != null:
			race_team.driver_id = ""
	GameManager.team.active_sponsor_id = ""
	GameManager.team.sponsor_races_remaining = 0
	GameManager.team.sponsor_objective_progress = 0
	GameManager.team.sponsor_objective_completed = false
	clear_last_result()
	GameManager.clear_selected_data()
	GameManager.team.emit_changed()
	GameManager.save_game()
	return true


func apply_driver_development() -> void:
	var team: Team = GameManager.team
	team.last_development_summary.clear()

	for driver in team.drivers:
		if driver == null:
			continue

		var represented_team: bool = driver.season_starts > 0
		if represented_team:
			driver.seasons_with_team += 1
			var season_bonus := GameManager.team.get_department_bonus("driver_development") / 100.0
			GameManager.team.driver_development_progress += float(driver.development_points) * season_bonus
			if GameManager.team.driver_development_progress >= 1.0:
				driver.development_points += floori(GameManager.team.driver_development_progress)
				GameManager.team.driver_development_progress = fmod(GameManager.team.driver_development_progress, 1.0)
		else:
			driver.development_points += get_free_agent_development(driver)

		var old_ratings := driver.get_attribute_dictionary()
		spend_development_points(driver)
		driver.age += 1
		apply_veteran_decline(driver)
		driver.season_starts = 0

		driver.update_archetype()
		driver.last_season_development = describe_detailed_driver_changes(driver, old_ratings)
		team.last_development_summary.append(
			"%s: %s" % [
				driver.driver_name,
				driver.last_season_development
			]
		)
		driver.emit_changed()


func get_free_agent_development(driver: Driver) -> int:
	if driver.age >= 34:
		return 0
	if driver.potential >= 88 and driver.age <= 24:
		return 2
	return 1


func spend_development_points(driver: Driver) -> void:
	var attempts: int = driver.development_points
	var development_cycle: Array[String] = Driver.RATING_FIELDS.duplicate()
	var focus_map := {"Race pace":"race_pace", "Qualifying":"qualifying_pace", "Tyre conservation":"tyre_management", "Racecraft":"racecraft", "Wet-weather training":"wet_weather", "Fitness":"fitness", "Simulator work":"consistency", "Technical feedback":"car_feedback", "Mental coaching":"composure"}
	if focus_map.has(driver.development_focus):
		development_cycle.push_front(str(focus_map[driver.development_focus]))

	for point_index in range(attempts):
		var attribute: String = development_cycle[
			point_index % development_cycle.size()
		]
		var current_value: int = int(driver.get(attribute))
		var ceiling: int = int(driver.get(attribute + "_potential"))
		if current_value < ceiling and driver.age < 34:
			driver.set(attribute, current_value + 1)
		driver.development_points -= 1
	driver.sync_legacy_ratings()


func describe_detailed_driver_changes(driver: Driver, old_ratings: Dictionary) -> String:
	var changes: Array[String] = []
	for row in driver.get_rating_rows():
		append_attribute_change(changes, str(row["label"]), int(row["rating"]) - int(old_ratings.get(row["key"], row["rating"])))
	return "No change" if changes.is_empty() else ", ".join(changes)


func apply_veteran_decline(driver: Driver) -> void:
	if driver.age < 35:
		return

	var decline: int = 2 if driver.age >= 39 else 1
	for attribute in Driver.RATING_FIELDS:
		var physical_decline := decline if attribute in ["race_pace", "qualifying_pace", "fitness", "starts_restarts"] else 1
		driver.set(attribute, maxi(0, int(driver.get(attribute)) - physical_decline))
	driver.sync_legacy_ratings()


func describe_driver_changes(
	driver: Driver,
	old_skill: int,
	old_consistency: int,
	old_aggression: int
) -> String:
	var changes: Array[String] = []
	append_attribute_change(changes, "Skill", driver.skill - old_skill)
	append_attribute_change(
		changes,
		"Consistency",
		driver.consistency - old_consistency
	)
	append_attribute_change(
		changes,
		"Aggression",
		driver.aggression - old_aggression
	)
	return "No change" if changes.is_empty() else ", ".join(changes)


func append_attribute_change(
	changes: Array[String],
	attribute_name: String,
	amount: int
) -> void:
	if amount == 0:
		return
	changes.append("%s %s%d" % [
		attribute_name,
		"+" if amount > 0 else "",
		amount
	])


func is_race_completed(
	race: Race
) -> bool:
	if GameManager.team == null:
		return false

	if race == null:
		return false

	return GameManager.team.get_completed_races().has(
		race.race_id
	)


func is_race_unlocked(
	race: Race
) -> bool:
	if GameManager.team == null:
		return false

	if race == null:
		return false

	return GameManager.team.get_unlocked_races().has(
		race.race_id
	)


func clear_last_result() -> void:
	last_result = null


func calculate_championship_points(series_id: String, result: Dictionary) -> int:
	var system_id := str(SeriesCatalog.get_series(series_id).get("points_system", "short_track"))
	return PointsSystemCatalog.calculate(system_id, result)
