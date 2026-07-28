extends Control

const MAX_CAR_CONDITION: int = 100
const MINIMUM_REPAIR_COST_PER_POINT: int = 50
const REPAIR_VALUE_PERCENTAGE_PER_POINT: float = 0.001

@onready var car_name_label: Label = %car_name_label
@onready var year_label: Label = %year_label
@onready var manufacturer_label: Label = %manufacturer_label
@onready var model_label: Label = %model_label
@onready var performance_label: Label = %performance_label
@onready var condition_label: Label = %condition_label
@onready var mileage_label: Label = %mileage_label
@onready var value_label: Label = %value_label

@onready var repair_cost_label: Label = %repair_cost_label
@onready var repair_button: Button = %repair_button
@onready var status_label: Label = %status_label

@onready var rename_line_edit: LineEdit = %rename_line_edit
@onready var rename_button: Button = %rename_button
@onready var sell_button: Button = %sell_button

@onready var sell_confirmation_dialog: ConfirmationDialog = (
	%sell_confirmation_dialog
)

@onready var back_button: Button = %back_button


func _ready() -> void:
	rename_button.pressed.connect(
		_on_rename_button_pressed
	)

	repair_button.pressed.connect(
		_on_repair_button_pressed
	)

	sell_button.pressed.connect(
		_on_sell_button_pressed
	)

	sell_confirmation_dialog.confirmed.connect(
		_on_sell_confirmed
	)

	back_button.pressed.connect(
		_on_back_button_pressed
	)

	if GameManager.selected_car == null:
		return_to_garage()
		return

	display_car()


func display_car() -> void:
	var car: Car = GameManager.selected_car

	if car == null:
		return

	car_name_label.text = car.name
	year_label.text = "Year: %d" % car.year

	manufacturer_label.text = (
		"Manufacturer: %s"
		% car.manufacturer
	)

	model_label.text = "Model: %s" % car.model

	performance_label.text = (
		"Performance: %d"
		% car.performance
	)

	condition_label.text = (
		"Condition: %d%%"
		% car.condition
	)

	mileage_label.text = (
		"Mileage: %s"
		% format_number(car.mileage)
	)

	value_label.text = (
		"Value: $%s"
		% format_number(car.value)
	)

	rename_line_edit.text = car.name

	sell_button.text = (
		"Sell Car ($%s)"
		% format_number(car.value)
	)

	update_repair_display(car)


func update_repair_display(car: Car) -> void:
	if car.condition >= MAX_CAR_CONDITION:
		repair_cost_label.text = (
			"Repair Cost: No repairs needed"
		)

		repair_button.text = "Car Fully Repaired"
		repair_button.disabled = true
		return

	var repair_cost: int = calculate_repair_cost(car)

	repair_cost_label.text = (
		"Repair Cost: $%s"
		% format_number(repair_cost)
	)

	repair_button.text = (
		"Repair Car ($%s)"
		% format_number(repair_cost)
	)

	repair_button.disabled = false


func calculate_repair_cost(car: Car) -> int:
	var missing_condition: int = maxi(
		0,
		MAX_CAR_CONDITION - car.condition
	)

	var value_based_cost: int = roundi(
		float(car.value)
		* REPAIR_VALUE_PERCENTAGE_PER_POINT
	)

	var cost_per_condition_point: int = maxi(
		MINIMUM_REPAIR_COST_PER_POINT,
		value_based_cost
	)

	return (
		missing_condition
		* cost_per_condition_point
	)


func _on_repair_button_pressed() -> void:
	var car: Car = GameManager.selected_car

	if car == null:
		status_label.text = "No car is selected."
		return

	if car.condition >= MAX_CAR_CONDITION:
		status_label.text = (
			"This car does not need repairs."
		)

		update_repair_display(car)
		return

	var repair_cost: int = calculate_repair_cost(car)

	var repair_paid: bool = (
		GameManager.remove_team_money(repair_cost)
	)

	if not repair_paid:
		status_label.text = (
			"Your team cannot afford these repairs."
		)
		return

	var previous_condition: int = car.condition

	car.condition = MAX_CAR_CONDITION
	car.emit_changed()

	status_label.text = (
		"%s was repaired from %d%% to %d%% condition."
		% [
			car.name,
			previous_condition,
			car.condition
		]
	)

	GameManager.save_game()
	display_car()


func _on_rename_button_pressed() -> void:
	var car: Car = GameManager.selected_car

	if car == null:
		return

	var new_name: String = (
		rename_line_edit.text.strip_edges()
	)

	if new_name.is_empty():
		rename_line_edit.text = car.name
		status_label.text = (
			"Car names cannot be empty."
		)
		return

	if new_name == car.name:
		status_label.text = (
			"The car already has that name."
		)
		return

	car.name = new_name
	car.emit_changed()

	status_label.text = (
		"Car renamed to %s."
		% car.name
	)

	GameManager.save_game()
	display_car()


func _on_sell_button_pressed() -> void:
	var car: Car = GameManager.selected_car

	if car == null:
		return

	sell_confirmation_dialog.dialog_text = (
		"Sell %s for $%s?"
		% [
			car.name,
			format_number(car.value)
		]
	)

	sell_confirmation_dialog.popup_centered()


func _on_sell_confirmed() -> void:
	var bay_index: int = GameManager.selected_bay

	if bay_index < 0:
		push_error(
			"Cannot sell car because no garage bay was selected."
		)
		return

	var sale_price: int = (
		GameManager.team.sell_car(bay_index)
	)

	if sale_price <= 0:
		push_error("The car could not be sold.")
		status_label.text = "The car could not be sold."
		return

	GameManager.refresh_team_money()

	GameManager.selected_car = null
	GameManager.selected_bay = -1

	GameManager.save_game()
	return_to_garage()


func _on_back_button_pressed() -> void:
	return_to_garage()


func return_to_garage() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = -1

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
