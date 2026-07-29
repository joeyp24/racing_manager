extends Control

@onready var roster_summary_label: Label = %roster_summary_label
@onready var candidates_container: GridContainer = %candidates_container
@onready var engineer_option: OptionButton = %engineer_option
@onready var part_type_option: OptionButton = %part_type_option
@onready var manufacture_button: Button = %manufacture_button
@onready var repair_engineer_option: OptionButton = %repair_engineer_option
@onready var repair_part_option: OptionButton = %repair_part_option
@onready var repair_button: Button = %repair_button
@onready var status_label: Label = %status_label

var available_engineers: Array[StaffMember] = []
var repairable_parts: Array[CarPart] = []


func _ready() -> void:
	manufacture_button.pressed.connect(_on_manufacture_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	refresh_page()


func refresh_page() -> void:
	var team: Team = GameManager.team
	var chief := team.get_crew_chief()
	var chief_text := "None"
	if chief != null:
		chief_text = "%s — %d rating (+%.1f%% race performance)" % [chief.staff_name, chief.rating, team.get_crew_chief_performance_boost()]
	roster_summary_label.text = "Crew Chief: %s\nEngineers: %d / %d" % [chief_text, team.get_engineers().size(), Team.MAX_ENGINEERS]
	refresh_candidates()
	refresh_workshop()


func refresh_candidates() -> void:
	clear_container(candidates_container)
	for member in GameManager.team.staff:
		if member == null:
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 155)
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 10)
		var content := VBoxContainer.new()
		var title := Label.new()
		title.text = member.staff_name
		title.add_theme_font_size_override("font_size", 18)
		var details := Label.new()
		details.text = "%s\nSigning fee: $%s · Salary: $%s/race" % [member.get_summary(), format_number(GameManager.team.get_discounted_cost(member.signing_fee)), format_number(member.salary)]
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var action := Button.new()
		configure_hire_button(action, member)
		content.add_child(title)
		content.add_child(details)
		content.add_child(action)
		margin.add_child(content)
		panel.add_child(margin)
		candidates_container.add_child(panel)


func configure_hire_button(button: Button, member: StaffMember) -> void:
	if member.hired:
		button.text = "Hired"
		button.disabled = true
		return
	button.text = "Hire"
	var team: Team = GameManager.team
	var role_full := member.role == "Crew Chief" and team.get_crew_chief() != null
	var engineer_full := member.role == "Engineer" and team.get_engineers().size() >= Team.MAX_ENGINEERS
	button.disabled = role_full or engineer_full or team.money < team.get_discounted_cost(member.signing_fee)
	button.pressed.connect(_on_hire_pressed.bind(member))


func refresh_workshop() -> void:
	available_engineers = GameManager.team.get_engineers()
	populate_engineers(engineer_option)
	populate_engineers(repair_engineer_option)
	part_type_option.clear()
	for part_type in CarPart.PART_TYPES:
		part_type_option.add_item(part_type)
	repairable_parts.clear()
	repair_part_option.clear()
	for part in GameManager.team.parts_inventory:
		if part != null and part.condition < 100:
			repairable_parts.append(part)
			repair_part_option.add_item("%s — %d%%" % [part.part_name, part.condition])
	manufacture_button.text = "Manufacture Part ($%s)" % format_number(GameManager.team.get_discounted_cost(Team.MANUFACTURING_BASE_COST))
	manufacture_button.disabled = available_engineers.is_empty() or GameManager.team.money < GameManager.team.get_discounted_cost(Team.MANUFACTURING_BASE_COST)
	repair_button.disabled = available_engineers.is_empty() or repairable_parts.is_empty()


func populate_engineers(option: OptionButton) -> void:
	option.clear()
	for engineer in available_engineers:
		option.add_item("%s — %d rating" % [engineer.staff_name, engineer.rating])


func _on_hire_pressed(member: StaffMember) -> void:
	if not GameManager.team.hire_staff(member):
		status_label.text = "That staff member cannot be hired. Check your funds and roster limits."
		return
	status_label.text = "%s joined the team as %s." % [member.staff_name, member.role]
	finish_transaction()


func _on_manufacture_pressed() -> void:
	if available_engineers.is_empty():
		return
	var engineer := available_engineers[engineer_option.selected]
	var part_type := part_type_option.get_item_text(part_type_option.selected)
	var part := GameManager.team.manufacture_part(engineer, part_type)
	if part == null:
		status_label.text = "The part could not be manufactured."
		return
	status_label.text = "%s manufactured %s: +%d performance at %d%% condition." % [engineer.staff_name, part.part_name, part.performance_bonus, part.condition]
	finish_transaction()


func _on_repair_pressed() -> void:
	if available_engineers.is_empty() or repairable_parts.is_empty():
		return
	var engineer := available_engineers[repair_engineer_option.selected]
	var part := repairable_parts[repair_part_option.selected]
	var restored := GameManager.team.repair_part(engineer, part)
	if restored <= 0:
		status_label.text = "The repair could not be completed. Check your funds."
		return
	status_label.text = "%s restored %d condition to %s. Higher-rated engineers restore more per repair." % [engineer.staff_name, restored, part.part_name]
	finish_transaction()


func finish_transaction() -> void:
	GameManager.refresh_team_money()
	GameManager.save_game()
	refresh_page()


func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
