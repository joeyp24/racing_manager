extends PanelContainer

@export var bay_index: int = 0

@onready var car_name_label: Label = %car_name_label
@onready var car_details_label: Label = %car_details_label
@onready var action_button: Button = %action_button


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	update_display()


func get_car():
	return GameManager.team.get_car(bay_index)


func _on_action_button_pressed() -> void:
	if get_car() != null:
		inspect_car()
	else:
		build_car()


func build_car() -> void:
	var new_car = Car.new()

	var success = GameManager.team.add_car_to_bay(
		new_car,
		bay_index
	)

	if success:
		update_display()


func inspect_car() -> void:
	GameManager.selected_car = get_car()

	GameManager.load_page(
		"res://scenes/pages/garage/car_inspection.tscn"
	)


func update_display() -> void:
	var current_car = get_car()

	if current_car != null:
		display_car(current_car)
	else:
		display_empty_bay()


func display_car(current_car) -> void:
	car_name_label.text = current_car.name

	car_details_label.text = "%d %s %s\nCondition: %d%%\nPerformance: %d" % [
		current_car.year,
		current_car.manufacturer,
		current_car.model,
		current_car.condition,
		current_car.performance
	]

	action_button.text = "Inspect Car"


func display_empty_bay() -> void:
	car_name_label.text = "No Car"
	car_details_label.text = "Empty Garage Bay"
	action_button.text = "Build Car"
