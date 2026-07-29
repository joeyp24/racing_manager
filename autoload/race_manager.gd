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


func get_next_race(team: Team) -> Race:
	if team == null or team.season_complete:
		return null
	for race_id in SEASON_RACE_IDS:
		if team.unlocked_races.has(race_id) and not team.completed_races.has(race_id):
			return get_race_by_id(race_id)
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
	for ai_driver in AI_DRIVERS:
		ai_scores.append(calculate_ai_score(selected_race, ai_driver))
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
		int(weekend_data.get("starting_position", AI_DRIVERS.size() + 1)),
		AI_DRIVERS,
		ai_scores,
		compound,
		_build_additional_team_entries(selected_race, selected_strategy, weekend_data)
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
	for index in range(1, selected_entries.size()):
		var entry := selected_entries[index] as Dictionary
		var driver := GameManager.team.get_driver_by_id(str(entry.get("driver_id", "")))
		var car := GameManager.team.get_car(int(entry.get("car_bay", -1)))
		if driver == null or car == null:
			continue
		entries.append({
			"driver_id": driver.driver_id,
			"driver_name": driver.driver_name,
			"team_name": str(entry.get("team_name", GameManager.team.team_name)),
			"consistency": driver.consistency,
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
	result.prize_money = calculate_prize_money(selected_race, result.finishing_position)
	result.championship_points_earned = calculate_championship_points(result.finishing_position)
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

	for ai_driver in AI_DRIVERS:
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

	result.prize_money = calculate_prize_money(
		selected_race,
		result.finishing_position
	)

	result.championship_points_earned = (
		calculate_championship_points(
			result.finishing_position
		)
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
	var skill_score: float = float(player_driver.skill) * (1.0 + driver_boost / 100.0) * 0.20

	var consistency_score: float = float(player_driver.consistency) * (1.0 + simulator_boost / 100.0) * 0.10

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

	var aggression_bonus: float = (
		float(player_driver.aggression) * 0.03
	)
	var spotter_restart_bonus := team.get_restart_performance_boost() if team != null else 0.0

	var total_score := (
		performance_score
		+ condition_score
		+ skill_score
		+ consistency_score
		+ aggression_bonus
		+ spotter_restart_bonus
		+ random_variance
	)
	return total_score * float(strategy.get("performance_modifier", 1.0))


func calculate_ai_score(
	selected_race: Race,
	ai_driver: Dictionary
) -> float:
	var skill: int = int(
		ai_driver.get("skill", 50)
	)

	var consistency: int = int(
		ai_driver.get("consistency", 50)
	)

	var aggression: int = int(
		ai_driver.get("aggression", 50)
	)

	var career_growth := 0.0
	if GameManager.team != null:
		career_growth = float(GameManager.team.season_number - 1) * float(GameManager.team.get_difficulty_setting("ai_growth", 0.75))
	var difficulty_score: float = (
		34.0
		+ float(selected_race.difficulty) * 0.30
		+ career_growth
	)

	var skill_score: float = (
		float(skill) * 0.28
	)

	var consistency_score: float = (
		float(consistency) * 0.10
	)

	var aggression_score: float = (
		float(aggression) * 0.05
	)

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
		+ skill_score
		+ consistency_score
		+ aggression_score
		+ random_variance
	)


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

	for ai_driver in AI_DRIVERS:
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
		GameManager.team.championship_standings
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
		GameManager.team.championship_standings
	):
		if str(
			entry.get("driver_id", "")
		) == driver_id:
			normalize_championship_entry(entry)

			entry["driver_name"] = driver_name
			entry["team_name"] = team_name
			entry["is_player"] = is_player
			return

	GameManager.team.championship_standings.append({
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
			calculate_championship_points(
				finishing_position
			)
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

	GameManager.team.championship_standings = (
		GameManager.team
		.get_sorted_championship_standings()
	)

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
		GameManager.team.championship_standings
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

	if not GameManager.team.completed_races.has(
		completed_race.race_id
	):
		GameManager.team.completed_races.append(
			completed_race.race_id
		)

	GameManager.team.emit_changed()
	finish_season_if_complete()


func finish_season_if_complete() -> void:
	if GameManager.team == null:
		return

	if GameManager.team.season_complete:
		return

	for race_id in SEASON_RACE_IDS:
		if not GameManager.team.completed_races.has(race_id):
			return

	var standings := (
		GameManager.team.get_sorted_championship_standings()
	)
	var player_position: int = 0

	for index in range(standings.size()):
		if bool(standings[index].get("is_player", false)):
			player_position = index + 1
			break

	var prize_money: int = calculate_season_prize(
		player_position
	)

	GameManager.team.season_complete = true
	GameManager.team.last_season_position = player_position
	GameManager.team.last_season_prize = prize_money
	if player_position == 1:
		GameManager.team.reputation += 100
	GameManager.add_team_money(prize_money)
	GameManager.team.record_finance("Championship", prize_money, "Season prize")
	GameManager.team.emit_changed()


func calculate_season_prize(finishing_position: int) -> int:
	if finishing_position <= 0:
		return 0

	if finishing_position > SEASON_PRIZES.size():
		return 0

	return SEASON_PRIZES[finishing_position - 1]


func start_new_season() -> bool:
	if GameManager.team == null:
		return false

	if not GameManager.team.season_complete:
		return false

	apply_driver_development()
	GameManager.team.process_staff_season()

	GameManager.team.season_number += 1
	GameManager.team.season_complete = false
	GameManager.team.last_season_position = 0
	GameManager.team.last_season_prize = 0
	GameManager.team.completed_races.clear()
	GameManager.team.unlocked_races = [SEASON_RACE_IDS[0]]
	GameManager.team.championship_standings.clear()
	GameManager.team.championship_points = 0
	GameManager.team.driver_hired_for_season = false
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

		var old_skill: int = driver.skill
		var old_consistency: int = driver.consistency
		var old_aggression: int = driver.aggression
		spend_development_points(driver)
		driver.age += 1
		apply_veteran_decline(driver)
		driver.season_starts = 0

		driver.last_season_development = describe_driver_changes(
			driver,
			old_skill,
			old_consistency,
			old_aggression
		)
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
	var development_cycle: Array[String] = [
		"skill", "consistency", "skill",
		"aggression", "skill", "consistency"
	]

	for point_index in range(attempts):
		var attribute: String = development_cycle[
			point_index % development_cycle.size()
		]
		var current_value: int = int(driver.get(attribute))
		var ceiling: int = min(driver.potential, 100)
		if current_value < ceiling and driver.age < 34:
			driver.set(attribute, current_value + 1)
		driver.development_points -= 1


func apply_veteran_decline(driver: Driver) -> void:
	if driver.age < 35:
		return

	var decline: int = 2 if driver.age >= 39 else 1
	driver.skill = max(1, driver.skill - decline)
	driver.consistency = max(1, driver.consistency - 1)


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

	return GameManager.team.completed_races.has(
		race.race_id
	)


func is_race_unlocked(
	race: Race
) -> bool:
	if GameManager.team == null:
		return false

	if race == null:
		return false

	return GameManager.team.unlocked_races.has(
		race.race_id
	)


func clear_last_result() -> void:
	last_result = null


func calculate_championship_points(
	finishing_position: int
) -> int:
	match finishing_position:
		1:
			return 10
		2:
			return 8
		3:
			return 6
		4:
			return 5
		5:
			return 4
		6:
			return 3
		7:
			return 2
		8:
			return 1
		_:
			return 0
