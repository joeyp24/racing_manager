extends Control

@onready var roster_summary_label: Label = %roster_summary_label
@onready var roster_container: VBoxContainer = %roster_container
@onready var market_container: VBoxContainer = %market_container
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
	var races_remaining := maxi(0, RaceManager.SEASON_RACE_IDS.size() - team.completed_races.size())
	var filled_roles: Array[String] = []
	for role in StaffMember.ROLES:
		filled_roles.append("%s %d/%d" % [role, team.get_staff_by_role(role).size(), team.get_role_limit(role)])
	roster_summary_label.text = "ACTIVE ROSTER\n%s\n\n$%s per race  ·  $%s projected through season end  ·  $%s available" % [
		"   •   ".join(filled_roles), format_number(team.get_staff_payroll()),
		format_number(team.get_total_race_payroll() * races_remaining), format_number(team.money)
	]
	refresh_staff_lists()
	refresh_workshop()


func refresh_staff_lists() -> void:
	clear_container(roster_container)
	clear_container(market_container)
	var hired_count := 0
	for role in StaffMember.ROLES:
		var hired_members := GameManager.team.get_staff_by_role(role)
		if not hired_members.is_empty():
			add_role_heading(roster_container, role, hired_members.size(), GameManager.team.get_role_limit(role))
			for member in hired_members:
				roster_container.add_child(create_staff_card(member))
				hired_count += 1
	if hired_count == 0:
		add_empty_state(roster_container, "No staff hired", "Use the Hiring Market to assemble your first race crew.")
	for role in StaffMember.ROLES:
		var candidates := GameManager.team.get_staff_by_role(role, false).filter(func(member: StaffMember) -> bool: return not member.hired)
		if candidates.is_empty():
			continue
		add_role_heading(market_container, role, GameManager.team.get_staff_by_role(role).size(), GameManager.team.get_role_limit(role))
		for member in candidates:
			market_container.add_child(create_staff_card(member))


func add_role_heading(container: VBoxContainer, role: String, current: int, limit: int) -> void:
	var heading := Label.new()
	heading.text = "%s  ·  %d / %d positions filled" % [role, current, limit]
	heading.theme_type_variation = &"SectionTitle"
	container.add_child(heading)


func add_empty_state(container: VBoxContainer, title_text: String, body_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"SectionTitle"
	var body := Label.new()
	body.text = body_text
	body.theme_type_variation = &"MutedLabel"
	container.add_child(title)
	container.add_child(body)


func create_staff_card(member: StaffMember) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	panel.custom_minimum_size = Vector2(0, 126)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(220, 0)
	var role := Label.new()
	role.text = "%s  /  %s" % [member.role.to_upper(), member.specialty.to_upper()]
	role.theme_type_variation = &"EyebrowLabel"
	var title := Label.new()
	title.text = member.staff_name
	title.theme_type_variation = &"CardTitle"
	var grade := Label.new()
	grade.text = "%s · %d OVR · %d potential" % [member.get_rating_grade(), member.rating, member.potential]
	grade.theme_type_variation = &"MutedLabel"
	identity.add_child(role)
	identity.add_child(title)
	identity.add_child(grade)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var attributes := Label.new()
	attributes.text = member.get_attributes_summary()
	attributes.theme_type_variation = &"BodyStrong"
	var career := Label.new()
	if member.hired:
		career.text = "%d races left  ·  %s morale (%d%%)  ·  %d XP  ·  %d seasons\nDevelopment: %s" % [member.contract_races_remaining, member.get_morale_label(), member.morale, member.experience, member.seasons_with_team, member.last_development]
	else:
		career.text = "$%s signing fee  ·  $%s/race\nRival interest: %s — top candidates may demand more next season" % [format_number(GameManager.team.get_discounted_cost(member.signing_fee)), format_number(member.salary), member.rival_interest]
	career.theme_type_variation = &"MutedLabel"
	career.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(attributes)
	details.add_child(career)
	var action := VBoxContainer.new()
	action.custom_minimum_size = Vector2(190, 0)
	configure_staff_actions(action, member)
	row.add_child(identity)
	row.add_child(details)
	row.add_child(action)
	panel.add_child(row)
	return panel


func configure_staff_actions(container: VBoxContainer, member: StaffMember) -> void:
	if member.hired:
		var renew_button := Button.new()
		renew_button.text = "Renew contract"
		renew_button.tooltip_text = "Pay a renewal fee and improve morale."
		renew_button.pressed.connect(_on_renew_pressed.bind(member, false))
		var negotiate_button := Button.new()
		negotiate_button.text = "Negotiate salary −5%"
		negotiate_button.tooltip_text = "A hard negotiation lowers salary and morale."
		negotiate_button.pressed.connect(_on_renew_pressed.bind(member, true))
		var fire_button := Button.new()
		fire_button.text = "Terminate"
		fire_button.pressed.connect(_on_fire_pressed.bind(member))
		container.add_child(renew_button)
		container.add_child(negotiate_button)
		container.add_child(fire_button)
		return
	var button := Button.new()
	button.text = "Hire for $%s" % format_number(GameManager.team.get_discounted_cost(member.signing_fee))
	button.theme_type_variation = &"PrimaryButton"
	button.disabled = not GameManager.team.can_add_staff_role(member.role) or GameManager.team.money < GameManager.team.get_discounted_cost(member.signing_fee)
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
	manufacture_button.text = "Manufacture ($%s)" % format_number(GameManager.team.get_discounted_cost(Team.MANUFACTURING_BASE_COST))
	manufacture_button.disabled = available_engineers.is_empty() or GameManager.team.money < GameManager.team.get_discounted_cost(Team.MANUFACTURING_BASE_COST)
	repair_button.disabled = available_engineers.is_empty() or repairable_parts.is_empty()


func populate_engineers(option: OptionButton) -> void:
	option.clear()
	for engineer in available_engineers:
		option.add_item("%s — performance %d / reliability %d" % [engineer.staff_name, engineer.primary_rating, engineer.secondary_rating])


func _on_hire_pressed(member: StaffMember) -> void:
	if not GameManager.team.hire_staff(member):
		status_label.text = "Unable to hire: check your funds and the role's roster limit."
		return
	status_label.text = "%s joined the team as %s." % [member.staff_name, member.role]
	finish_transaction()


func _on_fire_pressed(member: StaffMember) -> void:
	pending_fire_member = member
	var fee := GameManager.team.get_discounted_cost(member.get_termination_fee())
	fire_confirmation_dialog.dialog_text = "Terminate %s's contract for $%s?" % [member.staff_name, format_number(fee)]
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
	status_label.text = "%s renewed for %d races%s." % [member.staff_name, member.contract_races_remaining, " at a lower salary" if negotiate else ""]
	finish_transaction()


func _on_manufacture_pressed() -> void:
	if available_engineers.is_empty(): return
	var engineer := available_engineers[engineer_option.selected]
	var part := GameManager.team.manufacture_part(engineer, part_type_option.get_item_text(part_type_option.selected))
	if part == null:
		status_label.text = "The part could not be manufactured."
		return
	status_label.text = "%s manufactured %s: +%d performance at %d%% condition." % [engineer.staff_name, part.part_name, part.performance_bonus, part.condition]
	finish_transaction()


func _on_repair_pressed() -> void:
	if available_engineers.is_empty() or repairable_parts.is_empty(): return
	var engineer := available_engineers[repair_engineer_option.selected]
	var part := repairable_parts[repair_part_option.selected]
	var restored := GameManager.team.repair_part(engineer, part)
	if restored <= 0:
		status_label.text = "The repair could not be completed. Check your funds."
		return
	status_label.text = "%s restored %d condition to %s." % [engineer.staff_name, restored, part.part_name]
	finish_transaction()


func finish_transaction() -> void:
	GameManager.refresh_team_money()
	GameManager.save_game()
	refresh_page()


func clear_container(container: Node) -> void:
	for child in container.get_children(): child.queue_free()


func format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
