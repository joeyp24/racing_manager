extends Control

@onready var title_label: Label = %title_label
@onready var vehicle_label: Label = %vehicle_label
@onready var performance_label: Label = %performance_label
@onready var condition_label: Label = %condition_label
@onready var mileage_label: Label = %mileage_label
@onready var value_label: Label = %value_label

@onready var rename_line_edit: LineEdit = %rename_line_edit
@onready var rename_button: Button = %rename_button
@onready var back_button: Button = %back_button


func _ready() -> void:
	rename_button.pressed.connect(_on_rename_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	display_car()


func display_car() -> void:
	var car = GameManager.selected_car

	if car == null:
		display_no_car()
		return

	title_label.text = car.name

	vehicle_label.text = "%d %s %s" % [
		car.year,
		car.manufacturer,
		car.model
	]

	performance_label.text = "Performance: %d" % car.performance
	condition_label.text = "Condition: %d%%" % car.condition
	mileage_label.text = "Mileage: %d miles" % car.mileage
	value_label.text = "Value: $%d" % car.value

	rename_line_edit.text = car.name


func display_no_car() -> void:
	title_label.text = "No Car Selected"
	vehicle_label.text = ""
	performance_label.text = ""
	condition_label.text = ""
	mileage_label.text = ""
	value_label.text = ""
	rename_line_edit.text = ""


func _on_rename_button_pressed() -> void:
	var car = GameManager.selected_car

	if car == null:
		return

	var new_name = rename_line_edit.text.strip_edges()

	if new_name.is_empty():
		return

	car.name = new_name

	display_car()


func _on_back_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)
