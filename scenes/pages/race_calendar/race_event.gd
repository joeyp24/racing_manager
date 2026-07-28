class_name RaceEvent
extends PanelContainer

var race: Race = null

@onready var race_name_label: Label = %race_name_label
@onready var track_label: Label = %track_label
@onready var date_label: Label = %date_label
@onready var race_details_label: Label = %race_details_label
@onready var prize_label: Label = %prize_label
@onready var status_label: Label = %status_label
@onready var enter_button: Button = %enter_button


func _ready() -> void:
	enter_button.pressed.connect(_on_enter_button_pressed)
	update_display()


func setup(new_race: Race) -> void:
	race = new_race

	if is_node_ready():
		update_display()


func update_display() -> void:
	if race == null:
		show_missing_race()
		return

	race_name_label.text = race.race_name
	track_label.text = "Track: %s" % race.track_name
	date_label.text = "Date: %s" % race.race_date

	race_details_label.text = (
		"Laps: %d\nEntry Fee: $%s\nDifficulty: %d/100"
		% [
			race.lap_count,
			format_number(race.entry_fee),
			race.difficulty
		]
	)

	prize_label.text = (
		"Prize Money\n"
		+ "1st: $%s\n"
		+ "2nd: $%s\n"
		+ "3rd: $%s"
	) % [
		format_number(race.first_place_prize),
		format_number(race.second_place_prize),
		format_number(race.third_place_prize)
	]

	update_entry_status()


func update_entry_status() -> void:
	if GameManager.team == null:
		status_label.text = "No team loaded"
		enter_button.disabled = true
		return

	if not team_has_a_car():
		status_label.text = "You need a car to enter"
		enter_button.disabled = true
		return

	if GameManager.team.money < race.entry_fee:
		status_label.text = "Not enough money for the entry fee"
		enter_button.disabled = true
		return

	status_label.text = "Available"
	enter_button.disabled = false


func team_has_a_car() -> bool:
	for car in GameManager.team.cars:
		if car != null:
			return true

	return false


func show_missing_race() -> void:
	race_name_label.text = "Missing Race"
	track_label.text = ""
	date_label.text = ""
	race_details_label.text = ""
	prize_label.text = ""
	status_label.text = "No race resource assigned"
	enter_button.disabled = true


func _on_enter_button_pressed() -> void:
	if race == null:
		return

	GameManager.selected_race = race
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_entry/race_entry.tscn"
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
