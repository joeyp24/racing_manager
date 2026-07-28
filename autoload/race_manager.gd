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


func run_race(
	selected_race: Race,
	player_car: Car
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

	result.race = selected_race
	result.player_car = player_car
	result.player_driver = player_driver
	result.entry_fee = selected_race.entry_fee

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
			player_driver
		),
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
		selected_race
	)

	result.net_earnings = (
		result.prize_money
		- result.entry_fee
	)

	apply_race_effects(result)
	complete_race(selected_race)

	last_result = result

	GameManager.save_game()

	return result


func calculate_player_score(
	player_car: Car,
	player_driver: Driver
) -> float:
	var performance_score: float = (
		float(player_car.performance) * 0.50
	)

	var condition_score: float = (
		float(player_car.condition) * 0.20
	)

	var skill_score: float = (
		float(player_driver.skill) * 0.20
	)

	var consistency_score: float = (
		float(player_driver.consistency) * 0.10
	)

	var variance_limit: float = lerpf(
		12.0,
		4.0,
		float(player_driver.consistency) / 100.0
	)

	var random_variance: float = (
		random_number_generator.randf_range(
			-variance_limit,
			variance_limit
		)
	)

	var aggression_bonus: float = (
		float(player_driver.aggression) * 0.03
	)

	return (
		performance_score
		+ condition_score
		+ skill_score
		+ consistency_score
		+ aggression_bonus
		+ random_variance
	)


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

	var difficulty_score: float = (
		25.0
		+ float(selected_race.difficulty) * 0.25
	)

	var skill_score: float = (
		float(skill) * 0.25
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
	match finishing_position:
		1:
			return selected_race.first_place_prize
		2:
			return selected_race.second_place_prize
		3:
			return selected_race.third_place_prize
		_:
			return 0


func calculate_mileage_added(
	selected_race: Race
) -> int:
	return selected_race.lap_count


func calculate_condition_loss(
	selected_race: Race
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

	return maxi(
		1,
		base_wear
		+ difficulty_wear
		+ distance_wear
	)


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

	result.player_car.condition = maxi(
		0,
		result.player_car.condition
		- result.condition_lost
	)

	result.player_car.emit_changed()

	GameManager.add_team_money(
		result.prize_money
	)

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


func update_driver_career_stats(
	result: RaceResult
) -> void:
	if result.player_driver == null:
		return

	var driver: Driver = result.player_driver

	driver.career_starts += 1
	driver.career_points += (
		result.championship_points_earned
	)

	if result.finishing_position == 1:
		driver.career_wins += 1

	if result.finishing_position <= 3:
		driver.career_podiums += 1

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
	GameManager.add_team_money(prize_money)
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

	GameManager.team.season_number += 1
	GameManager.team.season_complete = false
	GameManager.team.last_season_position = 0
	GameManager.team.last_season_prize = 0
	GameManager.team.completed_races.clear()
	GameManager.team.unlocked_races = [SEASON_RACE_IDS[0]]
	GameManager.team.championship_standings.clear()
	GameManager.team.championship_points = 0
	clear_last_result()
	GameManager.clear_selected_data()
	GameManager.team.emit_changed()
	GameManager.save_game()
	return true


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
