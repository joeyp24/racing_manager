extends Node

const AI_COMPETITOR_NAMES: Array[String] = [
	"Redline Racing",
	"Summit Motorsports",
	"Blue Ridge Racing",
	"Velocity Autosport",
	"Iron Horse Racing",
	"Northstar Motorsports",
	"Thunder Valley Racing"
]

var last_result: RaceResult = null

var random_number_generator := RandomNumberGenerator.new()


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

	var result := RaceResult.new()

	result.race = selected_race
	result.player_car = player_car
	result.entry_fee = selected_race.entry_fee

	var race_standings: Array[Dictionary] = []

	for competitor_name in AI_COMPETITOR_NAMES:
		race_standings.append({
			"name": competitor_name,
			"score": calculate_ai_score(selected_race),
			"is_player": false
		})

	race_standings.append({
		"name": player_car.name,
		"score": calculate_player_score(player_car),
		"is_player": true
	})

	race_standings.sort_custom(
		func(
			first_entry: Dictionary,
			second_entry: Dictionary
		) -> bool:
			return (
				float(first_entry["score"])
				> float(second_entry["score"])
			)
	)

	result.standings = race_standings
	result.field_size = race_standings.size()

	result.finishing_position = find_player_position(
		race_standings
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


func calculate_player_score(player_car: Car) -> float:
	var performance_score: float = (
		float(player_car.performance) * 0.75
	)

	var condition_score: float = (
		float(player_car.condition) * 0.25
	)

	var random_variance: float = (
		random_number_generator.randf_range(
			-10.0,
			10.0
		)
	)

	return (
		performance_score
		+ condition_score
		+ random_variance
	)


func calculate_ai_score(selected_race: Race) -> float:
	var difficulty_score: float = (
		35.0
		+ float(selected_race.difficulty) * 0.55
	)

	var random_variance: float = (
		random_number_generator.randf_range(
			-12.0,
			12.0
		)
	)

	return difficulty_score + random_variance


func find_player_position(
	race_standings: Array[Dictionary]
) -> int:
	for index in range(race_standings.size()):
		var entry: Dictionary = race_standings[index]

		if bool(entry["is_player"]):
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
		random_number_generator.randi_range(2, 5)
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


func apply_race_effects(result: RaceResult) -> void:
	if result == null:
		return

	if result.player_car == null:
		return

	result.player_car.mileage += result.mileage_added

	result.player_car.condition = maxi(
		0,
		result.player_car.condition
		- result.condition_lost
	)

	result.player_car.emit_changed()

	GameManager.add_team_money(
		result.prize_money
	)

	GameManager.team.championship_points += (
	result.championship_points_earned
)

	result.total_championship_points = (
	GameManager.team.championship_points
)

	GameManager.team.emit_changed()



func complete_race(completed_race: Race) -> void:
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


func is_race_completed(race: Race) -> bool:
	if GameManager.team == null:
		return false

	if race == null:
		return false

	return GameManager.team.completed_races.has(
		race.race_id
	)


func is_race_unlocked(race: Race) -> bool:
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
