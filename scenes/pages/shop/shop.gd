extends Control

@onready var offers_container: GridContainer = %offers_container
@onready var inventory_label: Label = %inventory_label
@onready var status_label: Label = %status_label
@onready var comparison_car_selector: OptionButton = %comparison_car_selector
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

var store_inventory: Array[CarPart] = []


func _ready() -> void:
	store_inventory = PartCatalog.create_store_inventory()
	comparison_car_selector.item_selected.connect(func(_index: int) -> void: refresh_shop())
	comparison_drawer.action_requested.connect(_on_comparison_action)
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
		buy_button.text = "Compare  ·  $%s" % format_number(purchase_cost)
		buy_button.theme_type_variation = &"PrimaryButton"
		details.tooltip_text = "Part attributes are separate from Performance Points. PP includes condition and current part-level team modifiers."
		buy_button.tooltip_text = "Compare the installed part, candidate, whole-car effect, and post-purchase cash."
		buy_button.pressed.connect(_show_part_comparison.bind(part))
		content.add_child(title)
		content.add_child(details)
		content.add_child(pp_bubble)
		if GameManager.team.money < purchase_cost:
			var affordability := Label.new()
			affordability.text = "Need $%s more" % format_number(purchase_cost - GameManager.team.money)
			affordability.theme_type_variation = &"DangerLabel"
			content.add_child(affordability)
		content.add_child(buy_button)
		margin.add_child(content)
		panel.add_child(margin)
		offers_container.add_child(panel)
	inventory_label.text = "Parts Inventory: %d item%s" % [GameManager.team.parts_inventory.size(), "" if GameManager.team.parts_inventory.size() == 1 else "s"]


func _show_part_comparison(part: CarPart) -> void:
	var team := GameManager.team
	var car := get_comparison_car()
	var installed := car.get_part(part.part_type) if car != null else null
	var installed_result := team.calculate_part_performance(installed) if installed != null else null
	var candidate_result := team.calculate_part_performance(part)
	var current_car_pp := car.get_total_performance_points(team) if car != null else 0
	var preview_car := car.duplicate(true) as Car if car != null else null
	if preview_car != null:
		preview_car.install_part(part.duplicate(true) as CarPart)
	var preview_car_pp := preview_car.get_total_performance_points(team) if preview_car != null else current_car_pp
	var purchase_cost := team.get_discounted_cost(part.purchase_price)
	var pp_current := float(installed_result.effective_points) if installed_result != null else 0.0
	var pp_candidate := float(candidate_result.effective_points)
	var pp_delta := pp_candidate - pp_current
	var effect_delta := part.effect_value - (installed.effect_value if installed != null else 0)
	var reliability_delta := part.reliability_modifier - (installed.reliability_modifier if installed != null else 0)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "PART ACQUISITION",
		"title": "%s  ·  %s" % [part.part_type, part.part_name],
		"subtitle": "The purchase adds the part to inventory. Installation remains reversible from Car Inspection.",
		"current_title": installed.part_name.to_upper() if installed != null else "NO INSTALLED PART",
		"candidate_title": "CANDIDATE",
		"metrics": [
			DecisionComparisonModel.metric("Effective PP", "%.1f" % pp_current if installed != null else "—", "%.1f" % pp_candidate, "%+.1f" % pp_delta, _impact_float(pp_delta), "Includes condition and current part-level team modifiers."),
			DecisionComparisonModel.metric("Whole-car PP", str(current_car_pp) if car != null else "—", str(preview_car_pp) if car != null else "Select car", "%+d" % (preview_car_pp - current_car_pp) if car != null else "—", _impact(preview_car_pp - current_car_pp)),
			DecisionComparisonModel.metric(part.effect_name, str(installed.effect_value) if installed != null else "—", str(part.effect_value), "%+d" % effect_delta, _impact(effect_delta)),
			DecisionComparisonModel.metric("Condition", "%d%%" % installed.condition if installed != null else "—", "%d%%" % part.condition, "%+d%%" % (part.condition - installed.condition) if installed != null else "NEW", _impact(part.condition - installed.condition) if installed != null else DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Reliability", str(installed.reliability_modifier) if installed != null else "—", str(part.reliability_modifier), "%+d" % reliability_delta, _impact(reliability_delta)),
		],
		"upfront_cost": purchase_cost,
		"action_label": "Buy for %s" % DecisionComparisonModel.money(purchase_cost),
		"action_enabled": team.money >= purchase_cost,
		"disabled_reason": "You need %s more cash." % DecisionComparisonModel.money(purchase_cost - team.money),
		"recommendation": _part_recommendation(car, pp_delta, preview_car_pp - current_car_pp),
		"context": {"kind": "part", "candidate": part},
	})
	comparison_drawer.display(model)


func _part_recommendation(car: Car, part_delta: float, car_delta: int) -> String:
	if car == null:
		return "Select a comparison car to see authoritative whole-car impact before buying."
	if car_delta > 0:
		return "This is a measurable whole-car upgrade. Buy it if the reserve still covers upcoming race operations."
	if part_delta > 0.0:
		return "The part improves its category, but the displayed whole-car gain rounds to zero. Consider waiting for a larger step."
	return "This part does not improve the selected car. Buy only for inventory depth or a different vehicle."


func _impact(delta: int) -> int:
	return DecisionComparisonModel.IMPROVES if delta > 0 else (DecisionComparisonModel.WORSENS if delta < 0 else DecisionComparisonModel.NEUTRAL)


func _impact_float(delta: float) -> int:
	return DecisionComparisonModel.IMPROVES if delta > 0.01 else (DecisionComparisonModel.WORSENS if delta < -0.01 else DecisionComparisonModel.NEUTRAL)


func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) != "part":
		return
	_on_buy_pressed(context.get("candidate") as CarPart)


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
