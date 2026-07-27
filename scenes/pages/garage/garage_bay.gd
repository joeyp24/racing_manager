extends PanelContainer

var has_car: bool = false

@onready var car_name_label: Label = %car_name_label
@onready var car_details_label: Label = %car_details_label
@onready var action_button: Button = %action_button


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	update_display()


func _on_action_button_pressed() -> void:
	if has_car:
		print("Inspecting car")
	else:
		build_car()


func build_car() -> void:
	has_car = true
	update_display()


func update_display() -> void:
	if has_car:
		car_name_label.text = "Starter Stock Car"
		car_details_label.text = "Condition: 100%\nPerformance: 50"
		action_button.text = "Inspect Car"
	else:
		car_name_label.text = "No Car"
		car_details_label.text = "Empty Garage Bay"
		action_button.text = "Build Car"
