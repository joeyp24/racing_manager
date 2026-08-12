extends PanelContainer

signal comparison_requested(car: Car)

@export var car_template: Car

@onready var car_name_label: Label = %car_name_label
@onready var car_details_label: Label = %car_details_label
@onready var price_label: Label = %price_label
@onready var buy_button: Button = %buy_button


func _ready() -> void:
	buy_button.pressed.connect(_on_compare_button_pressed)
	update_offer_display()


func update_offer_display() -> void:
	if car_template == null:
		car_name_label.text = "No car assigned"
		car_details_label.text = ""
		price_label.text = ""
		buy_button.disabled = true
		return

	car_name_label.text = car_template.name

	car_details_label.text = (
		"%d %s %s\n%s\nPerformance points: %d\nCondition: %d%%\nMileage: %d"
		% [
			car_template.year,
			car_template.manufacturer,
			car_template.model,
			SeriesCatalog.get_series(car_template.series_id).get("name", "Unknown series"),
			car_template.get_total_performance_points(GameManager.team),
			car_template.condition,
			car_template.mileage
		]
	)
	var current_car: Car = GameManager.team.get_car(GameManager.selected_bay) if GameManager.team != null and GameManager.selected_bay >= 0 else null
	car_details_label.tooltip_text = "Compared with selected bay: Performance points %+d  •  Condition %+d%%  •  Value %s$%s" % [car_template.get_total_performance_points(GameManager.team) - current_car.get_total_performance_points(GameManager.team), car_template.condition - current_car.condition, "+" if car_template.value >= current_car.value else "−", format_number(absi(car_template.value - current_car.value))] if current_car != null else "Performance points include installed parts and team modifiers; condition affects usable pace."

	price_label.text = (
		"Price: $%s"
		% format_number(GameManager.team.get_discounted_cost(car_template.purchase_price))
	)

	buy_button.disabled = false
	buy_button.text = "Compare"
	buy_button.tooltip_text = "Compare performance, condition, cost, and cash impact before purchasing."
	if GameManager.selected_bay < 0:
		buy_button.text = "Compare  ·  Garage Full"
	elif not GameManager.team.entered_series_ids.has(car_template.series_id):
		buy_button.text = "Compare  ·  Series Locked"


func _on_compare_button_pressed() -> void:
	if car_template == null:
		push_error("No car template is assigned to this offer.")
		return
	comparison_requested.emit(car_template)


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
