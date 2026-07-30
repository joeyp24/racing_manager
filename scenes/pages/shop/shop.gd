extends Control

@onready var offers_container: GridContainer = %offers_container
@onready var inventory_label: Label = %inventory_label
@onready var status_label: Label = %status_label
@onready var comparison_car_selector: OptionButton = %comparison_car_selector

var store_inventory: Array[CarPart] = []


func _ready() -> void:
	store_inventory = PartCatalog.create_store_inventory()
	comparison_car_selector.item_selected.connect(func(_index: int) -> void: refresh_shop())
	populate_comparison_cars()
	refresh_shop()
	update_responsive_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		update_responsive_columns()


func update_responsive_columns() -> void:
	var width := size.x
	offers_container.columns = 1 if width < 620.0 else (2 if width < 920.0 else 3)


func populate_comparison_cars() -> void:
	comparison_car_selector.clear()
	comparison_car_selector.add_item("No car comparison")
	comparison_car_selector.set_item_metadata(0, -1)
	var preferred_bay := GameManager.selected_bay
	for bay in GameManager.team.cars.size():
		var car := GameManager.team.get_car(bay)
		if car == null:
			continue
		comparison_car_selector.add_item("Bay %d — %s" % [bay + 1, car.name])
		comparison_car_selector.set_item_metadata(comparison_car_selector.item_count - 1, bay)
		if car == GameManager.selected_car or (GameManager.selected_car == null and bay == preferred_bay):
			comparison_car_selector.select(comparison_car_selector.item_count - 1)
	if comparison_car_selector.selected == 0 and comparison_car_selector.item_count > 1:
		comparison_car_selector.select(1)


func refresh_shop() -> void:
	for child in offers_container.get_children():
		child.queue_free()
	for part in store_inventory:
		var purchase_cost := GameManager.team.get_discounted_cost(part.purchase_price)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(235, 188)
		panel.theme_type_variation = &"CardPanel"
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", UITokens.CARD_PADDING_HORIZONTAL)
		margin.add_theme_constant_override("margin_top", UITokens.CARD_PADDING_VERTICAL)
		margin.add_theme_constant_override("margin_right", UITokens.CARD_PADDING_HORIZONTAL)
		margin.add_theme_constant_override("margin_bottom", UITokens.CARD_PADDING_VERTICAL)
		var content := VBoxContainer.new()
		var title := Label.new()
		title.theme_type_variation = &"CardTitle"
		title.text = "%s — %s" % [part.part_type, part.part_name]
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var details := Label.new()
		details.text = "%s tier  •  %s" % [part.tier, part.get_effect_text()]
		var pp_result := GameManager.team.calculate_part_performance(part)
		var pp_bubble := PanelContainer.new()
		var pp_label := Label.new()
		pp_label.theme_type_variation = &"MutedLabel"
		pp_label.text = "%d base PP\n%.1f PP at %d%% condition\n%s with current team" % [part.base_performance_points, part.get_condition_adjusted_points(), part.condition, PerformancePointFormatter.format_part_points(pp_result)]
		var comparison := get_comparison_car()
		if comparison != null and comparison.get_part(part.part_type) != null:
			var installed := comparison.get_part(part.part_type)
			var installed_result := GameManager.team.calculate_part_performance(installed)
			var current_result := GameManager.team.calculate_car_performance(comparison)
			var preview := comparison.duplicate(true) as Car
			preview.install_part(part.duplicate(true) as CarPart)
			var preview_result := GameManager.team.calculate_car_performance(preview)
			pp_label.text += "\nCompared with %s\nInstalled: %s  •  Candidate: %s\nChange: %+.1f raw PP / %+d displayed car PP" % [get_comparison_car_label(), PerformancePointFormatter.format_part_points(installed_result), PerformancePointFormatter.format_part_points(pp_result), pp_result.effective_points - installed_result.effective_points, preview_result.displayed_points - current_result.displayed_points]
		pp_bubble.add_child(pp_label)
		var buy_button := Button.new()
		buy_button.text = "Buy — $%s" % format_number(purchase_cost)
		buy_button.theme_type_variation = &"PrimaryButton"
		buy_button.disabled = GameManager.team.money < purchase_cost
		details.tooltip_text = "Part attributes are separate from Performance Points. PP includes condition and current part-level team modifiers."
		buy_button.tooltip_text = "Disabled: you need $%s more." % format_number(purchase_cost - GameManager.team.money) if buy_button.disabled else "Buy now; install and compare it from Car Inspection."
		buy_button.pressed.connect(_on_buy_pressed.bind(part))
		content.add_child(title)
		content.add_child(details)
		content.add_child(pp_bubble)
		if buy_button.disabled:
			var affordability := Label.new()
			affordability.text = "Need $%s more" % format_number(purchase_cost - GameManager.team.money)
			affordability.theme_type_variation = &"DangerLabel"
			content.add_child(affordability)
		content.add_child(buy_button)
		margin.add_child(content)
		panel.add_child(margin)
		offers_container.add_child(panel)
	inventory_label.text = "Parts Inventory: %d item%s" % [GameManager.team.parts_inventory.size(), "" if GameManager.team.parts_inventory.size() == 1 else "s"]


func get_comparison_car() -> Car:
	if comparison_car_selector.selected < 0:
		return null
	var bay := int(comparison_car_selector.get_item_metadata(comparison_car_selector.selected))
	return GameManager.team.get_car(bay) if bay >= 0 else null


func get_comparison_car_label() -> String:
	return comparison_car_selector.get_item_text(comparison_car_selector.selected)


func _on_buy_pressed(part: CarPart) -> void:
	if not GameManager.team.buy_part(part):
		status_label.text = "Your team cannot afford that part."
		return
	GameManager.refresh_team_money()
	GameManager.save_game()
	status_label.text = "%s added to your parts inventory. Install it from a car's inspection screen." % part.part_name
	refresh_shop()


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""
	while number_string.length() > 3:
		formatted_number = "," + number_string.right(3) + formatted_number
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted_number
