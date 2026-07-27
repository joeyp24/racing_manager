extends Control

@onready var car_name_label: Label = %car_name_label
@onready var year_label: Label = %year_label
@onready var manufacturer_label: Label = %manufacturer_label
@onready var model_label: Label = %model_label
@onready var performance_label: Label = %performance_label
@onready var condition_label: Label = %condition_label
@onready var mileage_label: Label = %mileage_label
@onready var value_label: Label = %value_label

@onready var rename_line_edit: LineEdit = %rename_line_edit
@onready var rename_button: Button = %rename_button
@onready var sell_button: Button = %sell_button
@onready var sell_confirmation_dialog: ConfirmationDialog = %sell_confirmation_dialog
@onready var back_button: Button = %back_button


func _ready() -> void:
	rename_button.pressed.connect(_on_rename_button_pressed)
	sell_button.pressed.connect(_on_sell_button_pressed)
	sell_confirmation_dialog.confirmed.connect(_on_sell_confirmed)
	back_button.pressed.connect(_on_back_button_pressed)

	if GameManager.selected_car == null:
		return_to_garage()
		return

	display_car()


func display_car() -> void:
	var car = GameManager.selected_car

	if car == null:
		return

	car_name_label.text = car.name
	year_label.text = "Year: %d" % car.year
	manufacturer_label.text = "Manufacturer: %s" % car.manufacturer
	model_label.text = "Model: %s" % car.model
	performance_label.text = "Performance: %d" % car.performance
	condition_label.text = "Condition: %d%%" % car.condition
	mileage_label.text = "Mileage: %d" % car.mileage
	value_label.text = "Value: $%s" % String.num_int64(car.value)

	rename_line_edit.text = car.name
	sell_button.text = "Sell Car ($%s)" % String.num_int64(car.value)


func _on_rename_button_pressed() -> void:
	var car = GameManager.selected_car

	if car == null:
		return

	var new_name: String = rename_line_edit.text.strip_edges()

	if new_name.is_empty():
		rename_line_edit.text = car.name
		return

	car.name = new_name
	car.emit_changed()

	GameManager.save_game()
	display_car()


func _on_sell_button_pressed() -> void:
	var car = GameManager.selected_car

	if car == null:
		return

	sell_confirmation_dialog.dialog_text = (
		"Sell %s for $%s?"
		% [
			car.name,
			String.num_int64(car.value)
		]
	)

	sell_confirmation_dialog.popup_centered()


func _on_sell_confirmed() -> void:
	var bay_index: int = GameManager.selected_bay

	if bay_index < 0:
		push_error("Cannot sell car because no garage bay was selected.")
		return

	var sale_price: int = GameManager.team.sell_car(bay_index)

	if sale_price <= 0:
		push_error("The car could not be sold.")
		return

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
