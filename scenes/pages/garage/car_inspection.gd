extends Control

const MAX_CAR_CONDITION: int = 100
const MINIMUM_REPAIR_COST_PER_POINT: int = 50
const REPAIR_VALUE_PERCENTAGE_PER_POINT: float = 0.001

@onready var car_name_label: Label = %car_name_label
@onready var details_label: Label = %details_label
@onready var parts_container: VBoxContainer = %parts_container
@onready var inventory_title_label: Label = %inventory_title_label
@onready var inventory_container: VBoxContainer = %inventory_container
@onready var repair_button: Button = %repair_button
@onready var status_label: Label = %status_label
@onready var rename_line_edit: LineEdit = %rename_line_edit
@onready var sell_button: Button = %sell_button
@onready var sell_confirmation_dialog: ConfirmationDialog = %sell_confirmation_dialog
@onready var back_button: Button = %back_button

var selected_part_type: String = ""


func _ready() -> void:
	rename_line_edit.text_submitted.connect(func(_text: String) -> void: _on_rename_button_pressed())
	%rename_button.pressed.connect(_on_rename_button_pressed)
	repair_button.pressed.connect(_on_repair_button_pressed)
	sell_button.pressed.connect(_on_sell_button_pressed)
	sell_confirmation_dialog.confirmed.connect(_on_sell_confirmed)
	back_button.pressed.connect(return_to_garage)
	if GameManager.selected_car == null:
		return_to_garage()
		return
	GameManager.selected_car.ensure_standard_parts()
	display_car()


func display_car() -> void:
	var car: Car = GameManager.selected_car
	if car == null:
		return
	car_name_label.text = car.name
	details_label.text = "%d %s %s  •  Performance: %d (base %d)  •  Condition: %d%%\nMileage: %s  •  Value: $%s" % [car.year, car.manufacturer, car.model, car.get_total_performance(), car.performance, car.condition, format_number(car.mileage), format_number(car.value)]
	rename_line_edit.text = car.name
	sell_button.text = "Sell Car ($%s)" % format_number(car.value)
	update_repair_display(car)
	refresh_parts()
	if not selected_part_type.is_empty():
		show_part_inventory(selected_part_type)


func refresh_parts() -> void:
	clear_container(parts_container)
	var car: Car = GameManager.selected_car
	for part_type in CarPart.PART_TYPES:
		var part: CarPart = car.get_part(part_type)
		var button := Button.new()
		button.text = "%s\n%s" % [part_type, part.get_summary()]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "Choose a replacement %s" % part_type.to_lower()
		button.pressed.connect(show_part_inventory.bind(part_type))
		parts_container.add_child(button)


func show_part_inventory(part_type: String) -> void:
	selected_part_type = part_type
	inventory_title_label.text = "%s Inventory" % part_type
	clear_container(inventory_container)
	var available_parts: Array[CarPart] = GameManager.team.get_parts_by_type(part_type)
	if available_parts.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No spare %s parts. Buy some in the Parts Shop." % part_type.to_lower()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inventory_container.add_child(empty_label)
		return
	for part in available_parts:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s\nEffective performance +%d  •  Sell $%s" % [part.get_summary(), part.get_effective_performance_bonus(), format_number(part.sale_price)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var install_button := Button.new()
		install_button.text = "Install"
		install_button.pressed.connect(_on_install_part_pressed.bind(part))
		var sell_part_button := Button.new()
		sell_part_button.text = "Sell"
		sell_part_button.pressed.connect(_on_sell_part_pressed.bind(part))
		row.add_child(label)
		row.add_child(install_button)
		row.add_child(sell_part_button)
		inventory_container.add_child(row)


func _on_install_part_pressed(part: CarPart) -> void:
	if GameManager.team.install_part(GameManager.selected_car, part):
		status_label.text = "%s installed. The previous upgraded part was returned to inventory." % part.part_name
		GameManager.save_game()
		display_car()


func _on_sell_part_pressed(part: CarPart) -> void:
	var sale_price: int = GameManager.team.sell_part(part)
	if sale_price > 0:
		status_label.text = "Sold %s for $%s." % [part.part_name, format_number(sale_price)]
		GameManager.refresh_team_money()
		GameManager.save_game()
		show_part_inventory(selected_part_type)


func update_repair_display(car: Car) -> void:
	if car.condition >= MAX_CAR_CONDITION:
		repair_button.text = "Car Fully Repaired"
		repair_button.disabled = true
		return
	var repair_cost: int = calculate_repair_cost(car)
	repair_button.text = "Repair Car ($%s)" % format_number(repair_cost)
	repair_button.disabled = false


func calculate_repair_cost(car: Car) -> int:
	var missing_condition: int = maxi(0, MAX_CAR_CONDITION - car.condition)
	var value_based_cost: int = roundi(float(car.value) * REPAIR_VALUE_PERCENTAGE_PER_POINT)
	var base_cost := missing_condition * maxi(MINIMUM_REPAIR_COST_PER_POINT, value_based_cost)
	var engineering_discount := GameManager.team.get_department_bonus("engineering")
	var improved_cost := ceili(float(base_cost) * (1.0 - engineering_discount / 100.0))
	return GameManager.team.get_discounted_cost(improved_cost)


func _on_repair_button_pressed() -> void:
	var car: Car = GameManager.selected_car
	if car == null or car.condition >= MAX_CAR_CONDITION:
		return
	var repair_cost: int = calculate_repair_cost(car)
	if not GameManager.remove_team_money(repair_cost):
		status_label.text = "Your team cannot afford these repairs."
		return
	car.condition = MAX_CAR_CONDITION
	GameManager.team.record_finance("Repairs", -repair_cost, "Repaired %s" % car.name)
	car.emit_changed()
	status_label.text = "%s was fully repaired." % car.name
	GameManager.save_game()
	display_car()


func _on_rename_button_pressed() -> void:
	var car: Car = GameManager.selected_car
	var new_name: String = rename_line_edit.text.strip_edges()
	if car == null or new_name.is_empty():
		status_label.text = "Car names cannot be empty."
		return
	car.name = new_name
	car.emit_changed()
	status_label.text = "Car renamed to %s." % car.name
	GameManager.save_game()
	display_car()


func _on_sell_button_pressed() -> void:
	var car: Car = GameManager.selected_car
	if car != null:
		sell_confirmation_dialog.dialog_text = "Sell %s for $%s? Installed upgrades are included." % [car.name, format_number(car.value)]
		sell_confirmation_dialog.popup_centered()


func _on_sell_confirmed() -> void:
	var sale_price: int = GameManager.team.sell_car(GameManager.selected_bay)
	if sale_price <= 0:
		status_label.text = "The car could not be sold."
		return
	GameManager.refresh_team_money()
	GameManager.save_game()
	return_to_garage()


func return_to_garage() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = -1
	GameManager.load_page("res://scenes/pages/garage/garage.tscn")


func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""
	while number_string.length() > 3:
		formatted_number = "," + number_string.right(3) + formatted_number
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted_number
