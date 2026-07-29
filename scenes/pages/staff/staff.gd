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
@onready var fire_confirmation_dialog: ConfirmationDialog = %fire_confirmation_dialog

var available_engineers: Array[StaffMember] = []
var repairable_parts: Array[CarPart] = []
var pending_fire_member: StaffMember = null


func _ready() -> void:
	manufacture_button.pressed.connect(_on_manufacture_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	fire_confirmation_dialog.confirmed.connect(_on_fire_confirmed)
	refresh_page()


func refresh_page() -> void:
	var team: Team = GameManager.team
	var chief := team.get_crew_chief()
	var chief_text := "None"
	if chief != null:
		chief_text = "%s — %d rating (+%.1f%% race performance)" % [chief.staff_name, chief.rating, team.get_crew_chief_performance_boost()]
	var races_remaining := maxi(0, RaceManager.SEASON_RACE_IDS.size() - team.completed_races.size())
	roster_summary_label.text = "Crew Chief: %s\nEngineers: %d / %d\nStaff payroll: $%s/race · Total payroll with driver: $%s/race\nProjected remaining-season payroll: $%s · Available funds: $%s" % [chief_text, team.get_engineers().size(), Team.MAX_ENGINEERS, format_number(team.get_staff_payroll()), format_number(team.get_total_race_payroll()), format_number(team.get_total_race_payroll() * races_remaining), format_number(team.money)]
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
		if member.hired:
			details.text += "\nContract: %d races · Morale: %d%% · Termination: $%s" % [member.contract_races_remaining, member.morale, format_number(GameManager.team.get_discounted_cost(member.get_termination_fee()))]
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var action := HBoxContainer.new()
		configure_staff_actions(action, member)
		content.add_child(title)
		content.add_child(details)
		content.add_child(action)
		margin.add_child(content)
		panel.add_child(margin)
		candidates_container.add_child(panel)


func configure_staff_actions(container: HBoxContainer, member: StaffMember) -> void:
	if member.hired:
		var renew_button := Button.new()
		renew_button.text = "Renew (%d races)" % member.contract_races_remaining
		renew_button.pressed.connect(_on_renew_pressed.bind(member, false))
		var negotiate_button := Button.new()
		negotiate_button.text = "Negotiate"
		negotiate_button.tooltip_text = "Reduce salary 5%, but lower morale."
		negotiate_button.pressed.connect(_on_renew_pressed.bind(member, true))
		var fire_button := Button.new()
		fire_button.text = "Fire"
		fire_button.pressed.connect(_on_fire_pressed.bind(member))
		container.add_child(renew_button)
		container.add_child(negotiate_button)
		container.add_child(fire_button)
		return
	var button := Button.new()
	button.text = "Hire"
	var team: Team = GameManager.team
	var role_full := member.role == "Crew Chief" and team.get_crew_chief() != null
	var engineer_full := member.role == "Engineer" and team.get_engineers().size() >= Team.MAX_ENGINEERS
	button.disabled = role_full or engineer_full or team.money < team.get_discounted_cost(member.signing_fee)
	button.pressed.connect(_on_hire_pressed.bind(member))
	container.add_child(button)


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


func _on_fire_pressed(member: StaffMember) -> void:
	pending_fire_member = member
	var fee := GameManager.team.get_discounted_cost(member.get_termination_fee())
	fire_confirmation_dialog.dialog_text = "Fire %s for a $%s termination fee? The signing fee will not be refunded." % [member.staff_name, format_number(fee)]
	fire_confirmation_dialog.popup_centered()


func _on_fire_confirmed() -> void:
	if pending_fire_member == null or not GameManager.team.fire_staff(pending_fire_member):
		status_label.text = "The contract could not be terminated. Check your funds."
		return
	status_label.text = "%s was released from the team." % pending_fire_member.staff_name
	pending_fire_member = null
	finish_transaction()


func _on_renew_pressed(member: StaffMember, negotiate: bool) -> void:
	if not GameManager.team.renew_staff_contract(member, negotiate):
		status_label.text = "The contract could not be renewed. Check your funds."
		return
	status_label.text = "%s signed a new %d-race contract%s." % [member.staff_name, member.contract_races_remaining, " after salary negotiations" if negotiate else ""]
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
