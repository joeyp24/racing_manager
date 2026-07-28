extends Control

const RACE_CAR_OPTION_SCENE: PackedScene = preload(
	"res://scenes/pages/race_entry/race_car_option.tscn"
)

@onready var race_name_label: Label = %race_name_label
@onready var race_details_label: Label = %race_details_label
@onready var cars_container: GridContainer = %cars_container
@onready var selected_car_label: Label = %selected_car_label
@onready var status_label: Label = %status_label
@onready var back_button: Button = %back_button
@onready var confirm_button: Button = %confirm_button

var selected_car: Car = null
var car_option_nodes: Array[RaceCarOption] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)

	confirm_button.disabled = true

	show_race_information()
	create_car_options()


func show_race_information() -> void:
	var selected_race: Race = GameManager.selected_race

	if selected_race == null:
		race_name_label.text = "No Race Selected"
		race_details_label.text = ""
		status_label.text = "Return to the calendar and select a race."
		confirm_button.disabled = true
		return

	race_name_label.text = selected_race.race_name

	race_details_label.text = (
		"%s\n"
		+ "%d laps\n"
		+ "Entry Fee: $%s\n"
		+ "First Place Prize: $%s"
	) % [
		selected_race.track_name,
		selected_race.lap_count,
		format_number(selected_race.entry_fee),
		format_number(selected_race.first_place_prize)
	]

	status_label.text = "Choose the car you want to enter."


func create_car_options() -> void:
	clear_existing_options()

	if GameManager.team == null:
		status_label.text = "No team is currently loaded."
		return

	for car in GameManager.team.cars:
		if car == null:
			continue

		create_car_option(car)

	if car_option_nodes.is_empty():
		status_label.text = "Your team does not own any cars."


func create_car_option(car: Car) -> void:
	var option_instance := (
		RACE_CAR_OPTION_SCENE.instantiate()
		as RaceCarOption
	)

	if option_instance == null:
		push_error("Could not instantiate the race car option scene.")
		return

	option_instance.setup(car)
	option_instance.car_selected.connect(_on_car_selected)

	cars_container.add_child(option_instance)
	car_option_nodes.append(option_instance)


func clear_existing_options() -> void:
	car_option_nodes.clear()

	for child in cars_container.get_children():
		child.queue_free()


func _on_car_selected(car: Car) -> void:
	selected_car = car
	GameManager.selected_car = car

	selected_car_label.text = "Selected Car: %s" % car.name
	status_label.text = "Ready to enter the race."
	confirm_button.disabled = false

	for option in car_option_nodes:
		option.set_selected(option.car == selected_car)


func _on_confirm_button_pressed() -> void:
	var selected_race: Race = GameManager.selected_race

	if selected_race == null:
		status_label.text = "No race is selected."
		confirm_button.disabled = true
		return

	if selected_car == null:
		status_label.text = "Select a car before confirming."
		confirm_button.disabled = true
		return

	if GameManager.team == null:
		status_label.text = "No team is currently loaded."
		return

	if GameManager.team.money < selected_race.entry_fee:
		status_label.text = "Your team cannot afford the entry fee."
		confirm_button.disabled = true
		return

	GameManager.team.money -= selected_race.entry_fee

	status_label.text = (
		"%s has been entered in %s."
		% [
			selected_car.name,
			selected_race.race_name
		]
	)

	confirm_button.text = "Entry Confirmed"
	confirm_button.disabled = true
	back_button.disabled = true

	print(
		"Entered %s in %s"
		% [
			selected_car.name,
			selected_race.race_name
		]
	)

	print(
		"Entry fee paid: $%s"
		% format_number(selected_race.entry_fee)
	)


func _on_back_button_pressed() -> void:
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_calendar/race_calendar.tscn"
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
