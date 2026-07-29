extends Control

@onready var overview_label: Label = %overview_label
@onready var payroll_label: Label = %payroll_label
@onready var history_container: VBoxContainer = %history_container
@onready var recovery_button: Button = %recovery_button


func _ready() -> void:
	recovery_button.pressed.connect(_on_recovery_pressed)
	refresh_finances()


func refresh_finances() -> void:
	var team: Team = GameManager.team
	var garage_value := 0
	for car_value in team.cars:
		var car := car_value as Car
		if car != null:
			garage_value += car.value
	var inventory_value := 0
	for part in team.parts_inventory:
		if part != null:
			inventory_value += part.sale_price
	var remaining_races := maxi(0, RaceManager.SEASON_RACE_IDS.size() - team.get_completed_races().size())
	overview_label.text = "Cash: $%s\nGarage value: $%s\nParts resale value: $%s\nTotal liquid and asset value: $%s\n\nRecorded income: +$%s\nRecorded expenses: -$%s\nRecorded net: %s" % [format_number(team.money), format_number(garage_value), format_number(inventory_value), format_number(team.money + garage_value + inventory_value), format_number(team.get_finance_total(true)), format_number(team.get_finance_total(false)), format_money(team.get_finance_total(true) - team.get_finance_total(false))]

	var driver := team.get_active_driver()
	var driver_salary := driver.salary if driver != null and team.driver_hired_for_season else 0
	var chief := team.get_crew_chief()
	var chief_salary := chief.salary if chief != null else 0
	var engineer_salary := team.get_staff_payroll() - chief_salary
	payroll_label.text = "Driver: $%s/race\nCrew chief: $%s/race\nEngineers: $%s/race\nTotal payroll: $%s/race\nRaces remaining: %d\nProjected remaining payroll: $%s" % [format_number(driver_salary), format_number(chief_salary), format_number(engineer_salary), format_number(team.get_total_race_payroll()), remaining_races, format_number(team.get_total_race_payroll() * remaining_races)]
	recovery_button.disabled = team.recovery_funding_used or team.money >= 10000
	recovery_button.text = "Owner investment already used" if team.recovery_funding_used else "Accept emergency owner investment (+$15,000)"

	for child in history_container.get_children():
		child.queue_free()
	if team.finance_history.is_empty():
		var empty := Label.new()
		empty.text = "No transactions recorded yet. New race, payroll, staff, and workshop transactions will appear here."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history_container.add_child(empty)
		return
	for entry in team.finance_history:
		var row := HBoxContainer.new()
		var description := Label.new()
		description.text = "S%d R%d · %s · %s" % [int(entry.get("season", 0)), int(entry.get("race", 0)), str(entry.get("category", "Other")), str(entry.get("description", "Transaction"))]
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := Label.new()
		amount.text = format_money(int(entry.get("amount", 0)))
		row.add_child(description)
		row.add_child(amount)
		history_container.add_child(row)


func format_money(amount: int) -> String:
	if amount > 0:
		return "+$%s" % format_number(amount)
	if amount < 0:
		return "-$%s" % format_number(abs(amount))
	return "$0"


func _on_recovery_pressed() -> void:
	if GameManager.team.accept_owner_investment():
		GameManager.refresh_team_money()
		GameManager.save_game()
		refresh_finances()


func format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
