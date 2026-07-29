class_name RaceEvent
extends PanelContainer

var race: Race = null

@onready var race_name_label: Label = %race_name_label
@onready var track_label: Label = %track_label
@onready var date_label: Label = %date_label
@onready var status_label: Label = %status_label
@onready var enter_button: Button = %enter_button
@onready var details_button: Button = %details_button
@onready var details_dialog: AcceptDialog = %details_dialog
@onready var dialog_title: Label = %dialog_title
@onready var dialog_details: Label = %dialog_details


func _ready() -> void:
	enter_button.pressed.connect(
		_on_enter_button_pressed
	)
	details_button.pressed.connect(_on_details_button_pressed)

	update_display()


func setup(new_race: Race) -> void:
	race = new_race

	if is_node_ready():
		update_display()


func update_display() -> void:
	if race == null:
		show_missing_race()
		return

	# _ready() runs before setup() when calendar cards are instantiated. Undo the
	# missing-resource state once the race is assigned so Details stays clickable.
	details_button.disabled = false

	race_name_label.text = race.race_name
	track_label.text = race.track_name
	date_label.text = race.race_date
	dialog_title.text = race.race_name
	dialog_details.text = (
		"%s  •  %s\n\n%d laps  •  Difficulty %d/100\nEntry fee: $%s\n\nPrize money\n1st  $%s\n2nd  $%s\n3rd  $%s"
	) % [race.track_name, race.race_date, race.lap_count, race.difficulty,
		format_number(race.entry_fee),
		format_number(race.first_place_prize),
		format_number(race.second_place_prize),
		format_number(race.third_place_prize)
	]
	if not race.description.is_empty():
		dialog_details.text += "\n\n%s" % race.description

	update_entry_status()


func update_entry_status() -> void:
	if GameManager.team == null:
		status_label.text = "No team"
		enter_button.text = "Unavailable"
		enter_button.disabled = true
		return

	if race.race_id.is_empty():
		status_label.text = "Missing race ID"
		enter_button.text = "Unavailable"
		enter_button.disabled = true
		return

	if RaceManager.is_race_completed(race):
		status_label.text = "Completed"
		enter_button.text = "Completed"
		enter_button.disabled = true
		return

	if not RaceManager.is_race_unlocked(race):
		status_label.text = "Locked"
		enter_button.text = "Locked"
		enter_button.disabled = true
		return

	if not team_has_a_car():
		status_label.text = "No car"
		enter_button.text = "Enter Race"
		enter_button.disabled = true
		return

	if GameManager.team.money < race.entry_fee:
		status_label.text = "Need funds"

		enter_button.text = "Enter Race"
		enter_button.disabled = true
		return

	status_label.text = "Available"
	enter_button.text = "Enter Race"
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
	status_label.text = "No race resource assigned"
	details_button.disabled = true
	enter_button.text = "Unavailable"
	enter_button.disabled = true


func _on_details_button_pressed() -> void:
	if race == null:
		return
	details_dialog.popup_centered()


func _on_enter_button_pressed() -> void:
	if race == null:
		return

	if RaceManager.is_race_completed(race):
		update_entry_status()
		return

	if not RaceManager.is_race_unlocked(race):
		update_entry_status()
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
