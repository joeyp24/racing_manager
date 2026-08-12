extends Control

@onready var positions: Label = %positions_value
@onready var payroll: Label = %payroll_value
@onready var projection: Label = %projection_value
@onready var risk: Label = %risk_value
@onready var role_chips: Label = %RoleChips
@onready var roster_rows: VBoxContainer = %roster_rows
@onready var detail: VBoxContainer = %Content
@onready var roster_search: LineEdit = %roster_search
@onready var market_search: LineEdit = %market_search
@onready var role_filter: OptionButton = %Role
@onready var minimum_filter: SpinBox = %Minimum
@onready var sort_filter: OptionButton = %Sort
@onready var market_rows: VBoxContainer = %market_rows
@onready var status_panel: PanelContainer = %Status
@onready var status_message: Label = %Message
@onready var contract_dialog: ConfirmationDialog = %ContractDialog
@onready var contract_summary: Label = %Summary
@onready var approach: OptionButton = %Approach
@onready var fire_dialog: ConfirmationDialog = %FireDialog
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

var selected: StaffMember
var pending: StaffMember

func _ready() -> void:
	comparison_drawer.action_requested.connect(_on_comparison_action)
	role_filter.add_item("All roles")
	for role in StaffMember.ROLES: role_filter.add_item(role)
	for item in ["Rating: high to low", "Salary: low to high", "Potential: high to low", "Rival interest"]: sort_filter.add_item(item)
	for item in ["Accept terms — high morale", "Balanced offer — neutral", "Hard bargain — cheaper, lower morale"]: approach.add_item(item)
	roster_search.text_changed.connect(func(_text): refresh_lists())
	market_search.text_changed.connect(func(_text): refresh_lists())
	role_filter.item_selected.connect(func(_index): refresh_lists())
	minimum_filter.value_changed.connect(func(_value): refresh_lists())
	sort_filter.item_selected.connect(func(_index): refresh_lists())
	contract_dialog.confirmed.connect(_confirm_contract)
	fire_dialog.confirmed.connect(_confirm_fire)
	refresh()

func refresh() -> void:
	var team: Team = GameManager.team
	var members: Array[StaffMember] = []
	var capacity := 0
	var expiring := 0
	var chips: Array[String] = []
	for role in StaffMember.ROLES:
		var hired := team.get_staff_by_role(role)
		members.append_array(hired)
		capacity += team.get_role_limit(role)
		chips.append("%s %d/%d" % [role, hired.size(), team.get_role_limit(role)])
		for member in hired:
			if member.contract_races_remaining <= 2: expiring += 1
	var remaining := maxi(0, RaceManager.SEASON_RACE_IDS.size() - team.get_completed_races().size())
	positions.text = "POSITIONS\n%d / %d" % [members.size(), capacity]
	payroll.text = "PAYROLL\n$%s / race" % number(team.get_staff_payroll())
	projection.text = "SEASON PROJECTION\n$%s" % number(team.get_total_race_payroll() * remaining)
	risk.text = "CONTRACT RISK\n%d expiring" % expiring
	role_chips.text = "   ·   ".join(chips)
	if selected == null and not members.is_empty(): selected = members[0]
	refresh_lists()

func refresh_lists() -> void:
	clear(roster_rows); clear(market_rows)
	var candidates: Array[StaffMember] = []
	for role in StaffMember.ROLES:
		for member in GameManager.team.get_staff_by_role(role, false):
			if member.hired:
				if roster_search.text.is_empty() or roster_search.text.to_lower() in member.staff_name.to_lower(): roster_rows.add_child(make_row(member, false))
			elif matches_market(member): candidates.append(member)
	candidates.sort_custom(sort_candidates)
	for member in candidates: market_rows.add_child(make_row(member, true))
	show_detail(selected)

func matches_market(member: StaffMember) -> bool:
	return (market_search.text.is_empty() or market_search.text.to_lower() in member.staff_name.to_lower()) and (role_filter.selected == 0 or member.role == role_filter.get_item_text(role_filter.selected)) and member.rating >= minimum_filter.value

func sort_candidates(a: StaffMember, b: StaffMember) -> bool:
	match sort_filter.selected:
		1: return a.salary < b.salary
		2: return a.potential > b.potential
		3: return a.rival_interest < b.rival_interest
	return a.rating > b.rating

func make_row(member: StaffMember, hiring: bool) -> PanelContainer:
	var card := PanelContainer.new(); card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size.y = UITokens.COMPACT_ROW_HEIGHT
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", UITokens.SPACE_MD)
	var label := Label.new(); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s\n%s  ·  %d %s  ·  $%s/race%s" % [member.staff_name, member.role, member.rating, member.get_rating_grade(), number(GameManager.team.get_effective_salary(member.salary)), "  ·  %d races" % member.contract_races_remaining if member.hired else ""]
	label.theme_type_variation = &"BodyStrong"
	var action := Button.new()
	if hiring:
		action.text = "Compare"
		action.theme_type_variation = &"PrimaryButton"
		var peers := GameManager.team.get_staff_by_role(member.role)
		if not peers.is_empty():
			label.tooltip_text = "Compared with %s: Overall %+d  ·  Primary %+d  ·  Secondary %+d  ·  Salary %+d/race" % [peers[0].staff_name, member.rating - peers[0].rating, member.primary_rating - peers[0].primary_rating, member.secondary_rating - peers[0].secondary_rating, GameManager.team.get_effective_salary(member.salary) - GameManager.team.get_effective_salary(peers[0].salary)]
		action.tooltip_text = "Compare capability, payroll, and season forecast."
		action.pressed.connect(_show_staff_comparison.bind(member))
	else:
		action.text = "View"
		action.pressed.connect(func(): selected = member; show_detail(member))
	row.add_child(label); row.add_child(action); card.add_child(row)
	return card

func show_detail(member: StaffMember) -> void:
	clear(detail)
	if member == null:
		add_label(detail, "Select a staff member", &"SectionTitle"); return
	add_label(detail, member.staff_name, &"PageTitle")
	add_label(detail, "%s  /  %s" % [member.role.to_upper(), member.specialty.to_upper()], &"EyebrowLabel")
	add_label(detail, "%d OVR · %s · %d potential" % [member.rating, member.get_rating_grade(), member.potential], &"BodyStrong")
	var names := member.get_attribute_names()
	add_rating(detail, names[0], member.primary_rating)
	add_rating(detail, names[1], member.secondary_rating)
	add_label(detail, "RACE EFFECT", &"EyebrowLabel")
	add_label(detail, "Team performance: +%.1f%%\nCondition-loss reduction: %.1f%%" % [member.primary_rating * 0.035, member.secondary_rating * 0.08], &"BodyStrong")
	add_label(detail, "Morale: %s (%d%%)  ·  %d XP\nContract: %d races remaining  ·  $%s/race\nDevelopment: %s" % [member.get_morale_label(), member.morale, member.experience, member.contract_races_remaining, number(GameManager.team.get_effective_salary(member.salary)), member.last_development], &"MutedLabel")
	var actions := HBoxContainer.new()
	if member.hired:
		var negotiate := Button.new(); negotiate.text = "Negotiate contract"; negotiate.theme_type_variation = &"PrimaryButton"; negotiate.pressed.connect(open_contract.bind(member))
		var terminate := Button.new(); terminate.text = "Terminate…"; terminate.theme_type_variation = &"DangerButton"; terminate.pressed.connect(open_fire.bind(member))
		actions.add_child(negotiate); actions.add_child(terminate)
	else:
		var hire := Button.new(); hire.text = "Compare hire"; hire.theme_type_variation = &"PrimaryButton"; hire.pressed.connect(_show_staff_comparison.bind(member)); actions.add_child(hire)
	detail.add_child(actions)

func _show_staff_comparison(member: StaffMember) -> void:
	var team: Team = GameManager.team
	var peers := team.get_staff_by_role(member.role)
	var current: StaffMember = peers[0] if not peers.is_empty() else null
	for peer in peers:
		if current == null or peer.rating > current.rating:
			current = peer
	var names := member.get_attribute_names()
	var metrics: Array = [
		_staff_metric("Overall", current.rating if current != null else 0, member.rating, current != null),
		_staff_metric(names[0], current.primary_rating if current != null else 0, member.primary_rating, current != null),
		_staff_metric(names[1], current.secondary_rating if current != null else 0, member.secondary_rating, current != null),
		_staff_metric("Potential", current.potential if current != null else 0, member.potential, current != null),
		_staff_metric("Performance", current.primary_rating if current != null else 0, member.primary_rating, current != null, "Estimated team-performance contribution."),
		_staff_metric("Condition care", current.secondary_rating if current != null else 0, member.secondary_rating, current != null, "Higher secondary rating reduces condition loss."),
	]
	var signing_cost := team.get_discounted_cost(member.signing_fee)
	var can_add := team.can_add_staff_role(member.role)
	var recommendation := "This fills an open %s position and adds capability without replacing a current employee." % member.role
	if current != null:
		var delta := member.rating - current.rating
		recommendation = (
			"A strong capability upgrade over %s; check the payroll impact before committing." % current.staff_name
			if delta >= 5 else
			"A comparable option to %s; specialty and long-term potential should drive the choice." % current.staff_name
			if delta >= -3 else
			"Below the current benchmark; best suited to depth or development."
		)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "STAFF DECISION",
		"title": member.staff_name,
		"subtitle": "%s specialist compared with %s." % [member.role, current.staff_name if current != null else "an open position"],
		"current_title": current.staff_name.to_upper() if current != null else "OPEN ROLE",
		"candidate_title": "CANDIDATE",
		"metrics": metrics,
		"upfront_cost": signing_cost,
		"recurring_per_race": team.get_effective_salary(member.salary),
		"recurring_events": member.get_default_contract_length(),
		"action_enabled": can_add and not member.hired,
		"disabled_reason": "This role is at capacity." if not can_add else "This employee is already contracted." if member.hired else "",
		"action_label": "Hire %s" % member.staff_name.split(" ")[0],
		"recommendation": recommendation,
		"risk": "Rival interest is %s; the candidate may become more expensive if left on the market." % member.rival_interest if member.rival_interest in ["High", "Very high"] else "",
		"context": {"kind": "staff", "candidate": member},
	})
	comparison_drawer.display(model)

func _staff_metric(label_text: String, current_value: int, candidate_value: int, has_current: bool, detail_text: String = "") -> Dictionary:
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(label_text, str(current_value) if has_current else "--", str(candidate_value), "%+d" % delta if has_current else "New", _staff_impact(delta) if has_current else DecisionComparisonModel.IMPROVES, detail_text)

func _staff_impact(delta: int) -> int:
	if delta > 0: return DecisionComparisonModel.IMPROVES
	if delta < 0: return DecisionComparisonModel.WORSENS
	return DecisionComparisonModel.NEUTRAL

func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) == "staff":
		hire_member(context.get("candidate") as StaffMember)

func add_rating(parent: VBoxContainer, label_text: String, value: int) -> void:
	var label := Label.new(); label.text = "%s   %d · %s" % [label_text.to_upper(), value, selected.get_rating_grade()]; label.theme_type_variation = &"BodyStrong"; parent.add_child(label)
	var bar := ProgressBar.new(); bar.value = value; bar.show_percentage = false; bar.custom_minimum_size.y = 8; parent.add_child(bar)

func open_contract(member: StaffMember) -> void:
	pending = member
	var effective_salary := GameManager.team.get_effective_salary(member.salary)
	contract_summary.text = "Current salary: $%s / race\nRequested salary: $%s / race\nDuration: %d races\nRival interest: %s\nProjected season cost: $%s" % [number(effective_salary), number(effective_salary), member.get_default_contract_length(), member.rival_interest, number(effective_salary * member.get_default_contract_length())]
	contract_dialog.popup_centered(Vector2i(520, 330))

func _confirm_contract() -> void:
	var hard := approach.selected == 2
	if pending and GameManager.team.renew_staff_contract(pending, hard): show_status("Contract renewed with %s." % pending.staff_name, true); finish()
	else: show_status("Offer rejected or funds unavailable.", false)

func open_fire(member: StaffMember) -> void:
	pending = member; fire_dialog.dialog_text = "Terminate %s for $%s? This cannot be undone." % [member.staff_name, number(member.get_termination_fee())]; fire_dialog.popup_centered()

func _confirm_fire() -> void:
	if pending and GameManager.team.fire_staff(pending): selected = null; show_status("Contract terminated.", true); finish()
	else: show_status("Termination failed. Check available funds.", false)

func hire_member(member: StaffMember) -> void:
	if GameManager.team.hire_staff(member): selected = member; show_status("%s joined the team." % member.staff_name, true); finish()
	else: show_status("Unable to hire: check funds and role capacity.", false)

func show_status(text: String, success: bool) -> void:
	status_panel.show(); status_message.text = ("SUCCESS  ·  " if success else "WARNING  ·  ") + text; status_message.theme_type_variation = &"SuccessLabel" if success else &"WarningLabel"

func finish() -> void:
	GameManager.refresh_team_money(); GameManager.save_game(); refresh()

func add_label(parent: VBoxContainer, text: String, variation: StringName) -> void:
	var label := Label.new(); label.text = text; label.theme_type_variation = variation; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)

func clear(node: Node) -> void:
	for child in node.get_children(): child.queue_free()

func number(value: int) -> String:
	var raw := str(value); var result := ""
	while raw.length() > 3: result = "," + raw.right(3) + result; raw = raw.left(raw.length() - 3)
	return raw + result
