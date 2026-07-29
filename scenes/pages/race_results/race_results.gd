extends Control

@onready var race_name_label: Label = %race_name_label
@onready var finishing_position_label: Label = %finishing_position_label
@onready var standings_label: Label = %standings_label
@onready var summary_label: Label = %summary_label
@onready var car_effects_label: Label = %car_effects_label
@onready var continue_button: Button = %continue_button


func _ready() -> void:
	continue_button.pressed.connect(
		_on_continue_button_pressed
	)

	show_race_result()


func show_race_result() -> void:
	var result: RaceResult = RaceManager.last_result

	if result == null:
		show_missing_result()
		return

	if result.race == null:
		show_missing_result()
		return

	race_name_label.text = result.race.race_name

	finishing_position_label.text = (
		"You Finished: %s"
		% format_position(result.finishing_position)
	)

	standings_label.text = create_standings_text(result)
	summary_label.text = create_financial_summary(result)
	car_effects_label.text = create_car_effects_text(result)


func create_standings_text(
	result: RaceResult
) -> String:
	var standings_text: String = "Final Standings\n\n"

	for index in range(result.standings.size()):
		var entry: Dictionary = result.standings[index]
		var position: int = index + 1

		var driver_name: String = str(
			entry.get(
				"driver_name",
				"Unknown Driver"
			)
		)

		var team_name: String = str(
			entry.get(
				"team_name",
				"Unknown Team"
			)
		)

		if bool(entry.get("is_player", false)):
			standings_text += (
				"%d. %s — %s (Your Driver)\n"
				% [
					position,
					driver_name,
					team_name
				]
			)
		else:
			standings_text += (
				"%d. %s — %s\n"
				% [
					position,
					driver_name,
					team_name
				]
			)

	return standings_text


func create_financial_summary(result: RaceResult) -> String:
	return (
		"Financial Summary\n\n"
		+ "Entry Fee: -$%s\n"
		+ "Prize Money: +$%s\n"
		+ "Driver Salary: -$%s\n"
		+ "Crew Chief Salary: -$%s\n"
		+ "Engineering Payroll: -$%s\n"
		+ "Repair Costs: -$%s\n"
		+ "Sponsor Race Payment: +$%s\n"
		+ "Sponsor Objective Bonus: +$%s\n"
		+ "Rules Penalty: -$%s\n"
		+ "Net Earnings: %s\n\n"
		+ "Championship Points: +%d\n"
		+ "Season Total: %d\n"
		+ "Reputation: +%d\n"
		+ "Fans: +%d%s"
	) % [
		format_number(result.entry_fee),
		format_number(result.prize_money),
		format_number(result.driver_salary),
		format_number(result.crew_chief_salary),
		format_number(result.engineering_payroll),
		format_number(result.repair_cost),
		format_number(result.sponsor_race_payment),
		format_number(result.sponsor_objective_bonus),
		format_number(result.cheating_penalty),
		format_money_change(result.net_earnings),
		result.championship_points_earned,
		result.total_championship_points,
		result.reputation_earned,
		result.fans_earned,
		("\n%s objective completed!" % result.sponsor_name if result.sponsor_objective_completed else "")
		+ ("\nContracts expired: %s" % ", ".join(result.expired_staff_names) if not result.expired_staff_names.is_empty() else "")
	]


func create_car_effects_text(result: RaceResult) -> String:
	var current_condition: int = result.player_car.condition
	var current_mileage: int = result.player_car.mileage

	return (
		"Car Effects\n\n"
		+ "Strategy: %s\n"
		+ "Performance: %s | Variance: %s | Wear: %s\n"
		+ "Mileage Added: +%s\n"
		+ "Condition Lost: -%d%%\n"
		+ "Current Mileage: %s\n"
		+ "Current Condition: %d%%"
	) % [
		result.strategy_name,
		format_modifier(result.strategy_performance_modifier),
		format_modifier(result.strategy_variance_modifier),
		format_modifier(result.strategy_wear_modifier),
		format_number(result.mileage_added),
		result.condition_lost,
		format_number(current_mileage),
		current_condition
	]


func format_modifier(modifier: float) -> String:
	var percent := roundi((modifier - 1.0) * 100.0)
	if percent > 0:
		return "+%d%%" % percent
	return "%d%%" % percent


func format_position(position: int) -> String:
	var last_two_digits: int = position % 100

	if last_two_digits >= 11 and last_two_digits <= 13:
		return "%dth" % position

	match position % 10:
		1:
			return "%dst" % position
		2:
			return "%dnd" % position
		3:
			return "%drd" % position
		_:
			return "%dth" % position


func format_money_change(amount: int) -> String:
	if amount > 0:
		return "+$%s" % format_number(amount)

	if amount < 0:
		return "-$%s" % format_number(abs(amount))

	return "$0"


func show_missing_result() -> void:
	race_name_label.text = "No Race Result"
	finishing_position_label.text = ""
	standings_label.text = ""
	summary_label.text = (
		"No race result is currently available."
	)
	car_effects_label.text = ""


func _on_continue_button_pressed() -> void:
	RaceManager.clear_last_result()

	GameManager.selected_car = null
	GameManager.selected_race = null

	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""

	while number_string.length() > 3:
		formatted_number = (
			","
			+ number_string.right(3)
			+ formatted_number
		)

		number_string = number_string.left(
			number_string.length() - 3
		)

	return number_string + formatted_number
