extends Control

const MAX_CAR_CONDITION: int = 100
const MINIMUM_REPAIR_COST_PER_POINT: int = 50
const REPAIR_VALUE_PERCENTAGE_PER_POINT: float = 0.001

@onready var car_name_label: Label = %car_name_label
@onready var details_label: Label = %details_label
@onready var condition_label: Label = %condition_label
@onready var condition_bar: ProgressBar = %condition_bar
@onready var performance_points_label: Label = %performance_points_label
@onready var car_modifiers_label: Label = %car_modifiers_label
@onready var damage_label: Label = %damage_label
@onready var parts_container: VBoxContainer = %parts_container
@onready var columns: HSplitContainer = %columns
@onready var inventory_title_label: Label = %inventory_title_label
@onready var inventory_container: VBoxContainer = %inventory_container
@onready var repair_button: Button = %repair_button
@onready var status_label: Label = %status_label
@onready var rename_line_edit: LineEdit = %rename_line_edit
@onready var sell_button: Button = %sell_button
@onready var sell_confirmation_dialog: ConfirmationDialog = %sell_confirmation_dialog
@onready var back_button: Button = %back_button

var selected_part_type: String = ""
var installed_part_buttons := ButtonGroup.new()

const POSITIVE_COLOR := Color("59df94")
const NEGATIVE_COLOR := Color("ff615b")
const NEUTRAL_COLOR := Color("a8afbd")


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
	update_responsive_split()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		update_responsive_split()


func update_responsive_split() -> void:
	if columns == null:
		return
	columns.split_offset = clampi(roundi(size.x * 0.38), 300, 440)


func display_car() -> void:
	var car: Car = GameManager.selected_car
	if car == null:
		return
	car_name_label.text = car.name
	var car_result := GameManager.team.calculate_car_performance(car)
	performance_points_label.text = "%d PERFORMANCE POINTS" % car_result.displayed_points
	var car_modifier_text: Array[String] = []
	for modifier in car_result.car_modifiers:
		car_modifier_text.append("%s %s" % [modifier.label, PerformancePointFormatter.format_modifier_points(modifier)])
	car_modifiers_label.text = "Car Modifiers: %s" % ("None" if car_modifier_text.is_empty() else "  •  ".join(car_modifier_text))
	details_label.text = "%d %s %s  •  %s\nParts base %d PP  •  %s miles  •  Value $%s" % [car.year, car.manufacturer, car.model, SeriesCatalog.get_series(car.series_id).get("name", "Unknown series"), car.get_base_performance_points(), format_number(car.mileage), format_number(car.value)]
	condition_label.text = "CONDITION %d%%" % car.condition
	condition_bar.value = car.condition
	condition_bar.modulate = POSITIVE_COLOR if car.condition >= 80 else (Color("f2b84b") if car.condition >= 50 else NEGATIVE_COLOR)
	car.ensure_damage_state()
	damage_label.text = "COMPONENT HEALTH  |  %s\nDamage affects live pace, tyre wear, braking, fuel use and mechanical risk." % car.get_damage_summary()
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
		var breakdown := GameManager.team.calculate_part_performance(part)
		var button := Button.new()
		button.text = "%s   %d PP\n%s" % [part_type, breakdown.displayed_points, part.get_summary()]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%s\nChoose a replacement %s" % [format_performance_breakdown(breakdown), part_type.to_lower()]
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
		var shop_button := Button.new()
		shop_button.text = "Open Parts Shop"
		shop_button.theme_type_variation = &"PrimaryButton"
		shop_button.pressed.connect(func() -> void: GameManager.load_page("res://scenes/pages/shop/shop.tscn"))
		inventory_container.add_child(shop_button)
		return
	for part in available_parts:
		var row := VBoxContainer.new()
		var summary_row := HBoxContainer.new()
		var label := Label.new()
		var breakdown := GameManager.team.calculate_part_performance(part)
		label.text = "%s  •  Base %d PP\n%s\n%s  •  Sell $%s" % [PerformancePointFormatter.format_part_points(breakdown), breakdown.base_points, part.get_summary(), format_performance_breakdown(breakdown), format_number(part.sale_price)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var delta_label := Label.new()
		var preview := preview_replacement(part)
		delta_label.text = "PART %+.1f PP   •   CAR %d → %d PP (%+d)" % [preview.raw_delta, preview.current_pp, preview.preview_pp, preview.displayed_delta]
		delta_label.add_theme_color_override("font_color", POSITIVE_COLOR if preview.displayed_delta > 0 else (NEGATIVE_COLOR if preview.displayed_delta < 0 else NEUTRAL_COLOR))
		var install_button := Button.new()
		install_button.text = "Install"
		install_button.theme_type_variation = &"PrimaryButton"
		install_button.pressed.connect(_on_install_part_pressed.bind(part))
		var sell_part_button := Button.new()
		sell_part_button.text = "Sell"
		sell_part_button.pressed.connect(_on_sell_part_pressed.bind(part))
		summary_row.add_child(label)
		summary_row.add_child(install_button)
		summary_row.add_child(sell_part_button)
		row.add_child(summary_row)
		row.add_child(delta_label)
		inventory_container.add_child(row)


func preview_replacement(candidate: CarPart) -> Dictionary:
	var car: Car = GameManager.selected_car
	var installed := car.get_part(candidate.part_type)
	var installed_result := GameManager.team.calculate_part_performance(installed)
	var candidate_result := GameManager.team.calculate_part_performance(candidate)
	var current_result := GameManager.team.calculate_car_performance(car)
	var preview_car := car.duplicate(true) as Car
	preview_car.install_part(candidate.duplicate(true) as CarPart)
	var preview_result := GameManager.team.calculate_car_performance(preview_car)
	return {"raw_delta": candidate_result.effective_points - installed_result.effective_points, "current_pp": current_result.displayed_points, "preview_pp": preview_result.displayed_points, "displayed_delta": preview_result.displayed_points - current_result.displayed_points}


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
	if car.condition >= MAX_CAR_CONDITION and car.get_damage_points() <= 0.5:
		repair_button.text = "Car Fully Repaired"
		repair_button.disabled = true
		return
	var repair_cost: int = calculate_repair_cost(car)
	repair_button.text = "Workshop Restoration ($%s)" % format_number(repair_cost)
	repair_button.disabled = false


func calculate_repair_cost(car: Car) -> int:
	var missing_condition: int = maxi(0, MAX_CAR_CONDITION - car.condition)
	var value_based_cost: int = roundi(float(car.value) * REPAIR_VALUE_PERCENTAGE_PER_POINT)
	var base_cost := missing_condition * maxi(MINIMUM_REPAIR_COST_PER_POINT, value_based_cost)
	var engineering_discount := GameManager.team.get_department_bonus("engineering")
	var mechanic_discount := GameManager.team.get_repair_time_reduction() * 0.35
	var improved_cost := ceili(float(base_cost) * (1.0 - (engineering_discount + mechanic_discount) / 100.0))
	var difficulty_cost := roundi(float(improved_cost) * float(GameManager.team.get_difficulty_setting("repair_multiplier", 1.0)))
	return GameManager.team.get_discounted_cost(difficulty_cost) + GameManager.team.get_workshop_damage_repair_cost(car)


func _on_repair_button_pressed() -> void:
	var car: Car = GameManager.selected_car
	if car == null or (car.condition >= MAX_CAR_CONDITION and car.get_damage_points() <= 0.5):
		return
	var repair_cost: int = calculate_repair_cost(car)
	if not GameManager.remove_team_money(repair_cost):
		status_label.text = "Your team cannot afford these repairs."
		return
	car.condition = MAX_CAR_CONDITION
	car.restore_all_damage()
	GameManager.team.record_finance("Repairs", -repair_cost, "Repaired %s" % car.name)
	car.emit_changed()
	status_label.text = "%s received full workshop restoration, including all five damage systems." % car.name
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


func format_performance_breakdown(breakdown: PartPerformanceResult) -> String:
	var details: Array[String] = ["Base %d PP" % breakdown.base_points]
	for modifier in breakdown.modifiers:
		var percent_detail := " (+%.1f%%)" % modifier.value if modifier.operation != PerformancePointModifier.Operation.FLAT_POINTS else ""
		details.append("%s %s%s" % [modifier.label, PerformancePointFormatter.format_modifier_points(modifier), percent_detail])
	return "  •  ".join(details)


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""
	while number_string.length() > 3:
		formatted_number = "," + number_string.right(3) + formatted_number
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted_number
