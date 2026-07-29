extends Control

@onready var offers_container: GridContainer = %offers_container
@onready var inventory_label: Label = %inventory_label
@onready var status_label: Label = %status_label

var store_inventory: Array[CarPart] = []


func _ready() -> void:
	store_inventory = PartCatalog.create_store_inventory()
	refresh_shop()


func refresh_shop() -> void:
	for child in offers_container.get_children():
		child.queue_free()
	for part in store_inventory:
		var purchase_cost := GameManager.team.get_discounted_cost(part.purchase_price)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(225, 145)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		var content := VBoxContainer.new()
		var title := Label.new()
		title.text = "%s — %s" % [part.part_type, part.part_name]
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var details := Label.new()
		details.text = "%s tier\n%s\nPerformance +%d at %d%% condition" % [part.tier, part.get_effect_text(), part.get_effective_performance_bonus(), part.condition]
		var buy_button := Button.new()
		buy_button.text = "Buy — $%s" % format_number(purchase_cost)
		buy_button.disabled = GameManager.team.money < purchase_cost
		details.tooltip_text = "Effective bonus already includes condition. Compare the +%d shown here with the same part type installed in your garage." % part.get_effective_performance_bonus()
		buy_button.tooltip_text = "Disabled: you need $%s more." % format_number(purchase_cost - GameManager.team.money) if buy_button.disabled else "Buy now; install and compare it from Car Inspection."
		buy_button.pressed.connect(_on_buy_pressed.bind(part))
		content.add_child(title)
		content.add_child(details)
		content.add_child(buy_button)
		margin.add_child(content)
		panel.add_child(margin)
		offers_container.add_child(panel)
	inventory_label.text = "Parts Inventory: %d item%s" % [GameManager.team.parts_inventory.size(), "" if GameManager.team.parts_inventory.size() == 1 else "s"]


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
