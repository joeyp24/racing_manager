class_name RaceCarOption
extends PanelContainer

signal car_selected(selected_car: Car)

var car: Car = null
var is_selected: bool = false

@onready var car_name_label: Label = %car_name_label
@onready var car_details_label: Label = %car_details_label
@onready var car_stats_label: Label = %car_stats_label
@onready var select_button: Button = %select_button


func _ready() -> void:
	select_button.pressed.connect(_on_select_button_pressed)
	update_display()


func setup(new_car: Car) -> void:
	car = new_car

	if is_node_ready():
		update_display()


func set_selected(selected: bool) -> void:
	is_selected = selected

	if not is_node_ready():
		return

	if is_selected:
		select_button.text = "Selected"
		select_button.disabled = true
	else:
		select_button.text = "Select Car"
		select_button.disabled = false


func update_display() -> void:
	if car == null:
		show_missing_car()
		return

	car_name_label.text = car.name

	car_details_label.text = (
		"%d %s %s"
		% [
			car.year,
			car.manufacturer,
			car.model
		]
	)

	car_stats_label.text = (
		"Performance points: %d\n"
		+ "Condition: %d%%\n"
		+ "Mileage: %s"
	) % [
		car.get_total_performance(GameManager.team),
		car.condition,
		format_number(car.mileage)
	]

	set_selected(is_selected)


func show_missing_car() -> void:
	car_name_label.text = "Missing Car"
	car_details_label.text = ""
	car_stats_label.text = ""
	select_button.disabled = true


func _on_select_button_pressed() -> void:
	if car == null:
		return

	car_selected.emit(car)


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
