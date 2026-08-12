extends Control

@onready var project_rows: VBoxContainer = %project_rows
@onready var engineer_rows: VBoxContainer = %engineer_rows
@onready var part_type: OptionButton = %part_type
@onready var status_label: Label = %status_label
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

func _ready() -> void:
	comparison_drawer.action_requested.connect(_on_comparison_action)
	for type in CarPart.PART_TYPES:
		part_type.add_item(type)
	refresh()

func refresh() -> void:
	clear(project_rows)
	clear(engineer_rows)
	var team: Team = GameManager.team
	if team.engineering_projects.is_empty():
		add_text(project_rows, "No active projects. Assign an engineer below; development takes %d calendar days." % Team.ENGINEERING_PROJECT_DAYS)
	else:
		for project in team.engineering_projects:
			add_text(project_rows, "%s  •  %s development  •  Ready %s" % [project.get("engineer_name", "Engineer"), project.get("part_type", "Part"), CalendarCatalog.format_day(int(project.get("completion_day", team.current_season_day)))])
	var engineers := team.get_engineers()
	if engineers.is_empty():
		add_text(engineer_rows, "No engineers employed. Hire one from the Staff Market in Employees.")
	for engineer in engineers:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s\nRating %d  •  Potential %d  •  %s" % [engineer.staff_name, engineer.rating, engineer.potential, engineer.specialty]
		var button := Button.new()
		button.text = "Compare project"
		button.tooltip_text = "Preview the prototype, delivery date, and financial impact."
		button.pressed.connect(_show_project_comparison.bind(engineer))
		row.add_child(label)
		row.add_child(button)
		engineer_rows.add_child(row)

func _show_project_comparison(engineer: StaffMember) -> void:
	var team: Team = GameManager.team
	var selected_type := part_type.get_item_text(part_type.selected)
	var candidate := PartCatalog.create_manufactured_part(selected_type, engineer)
	var current := _best_installed_part(selected_type)
	var has_current := current != null
	var candidate_points := candidate.get_condition_adjusted_points()
	var current_points := current.get_condition_adjusted_points() if has_current else 0.0
	var metrics: Array = [
		_part_float_metric("Effective PP", current_points, candidate_points, has_current),
		_part_metric("Base PP", current.base_performance_points if has_current else 0, candidate.base_performance_points, has_current),
		_part_metric("Effect", current.effect_value if has_current else 0, candidate.effect_value, has_current),
		_part_metric("Condition", current.condition if has_current else 0, candidate.condition, has_current, "%"),
		_part_metric("Reliability", current.reliability_modifier if has_current else 0, candidate.reliability_modifier, has_current),
		DecisionComparisonModel.metric("Delivery", "Installed" if has_current else "None", CalendarCatalog.format_day(team.current_season_day + Team.ENGINEERING_PROJECT_DAYS), "%d days" % Team.ENGINEERING_PROJECT_DAYS, DecisionComparisonModel.NEUTRAL),
	]
	var available := team.is_engineer_available(engineer)
	var cost := team.get_discounted_cost(Team.MANUFACTURING_BASE_COST)
	var delta := candidate_points - current_points
	var recommendation := (
		"Projected to outperform the strongest installed %s by %.1f effective PP." % [selected_type.to_lower(), delta]
		if delta > 0.0 else
		"Not projected to beat the strongest installed %s; consider another part type or engineer." % selected_type.to_lower()
	)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "ENGINEERING DECISION",
		"title": "%s prototype" % selected_type,
		"subtitle": "%s's projected output compared with the team's strongest installed %s." % [engineer.staff_name, selected_type.to_lower()],
		"current_title": current.part_name.to_upper() if has_current else "NO PART",
		"candidate_title": "PROTOTYPE",
		"metrics": metrics,
		"upfront_cost": cost,
		"recurring_per_race": 0,
		"action_enabled": available,
		"disabled_reason": "This engineer is already assigned to an active project." if not available else "",
		"action_label": "Start development",
		"recommendation": recommendation,
		"risk": "Prototype values are projected from engineer rating and specialty; the part is delivered after %d calendar days." % Team.ENGINEERING_PROJECT_DAYS,
		"context": {"kind": "engineering", "engineer": engineer},
	})
	comparison_drawer.display(model)

func _best_installed_part(selected_type: String) -> CarPart:
	var best: CarPart = null
	for value in GameManager.team.cars:
		var car := value as Car
		if car == null:
			continue
		var installed := car.get_part(selected_type)
		if installed != null and (best == null or installed.get_condition_adjusted_points() > best.get_condition_adjusted_points()):
			best = installed
	return best

func _part_metric(label_text: String, current_value: int, candidate_value: int, has_current: bool, suffix: String = "") -> Dictionary:
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(label_text, "%d%s" % [current_value, suffix] if has_current else "--", "%d%s" % [candidate_value, suffix], "%+d%s" % [delta, suffix] if has_current else "New", _comparison_impact(delta) if has_current else DecisionComparisonModel.IMPROVES)

func _part_float_metric(label_text: String, current_value: float, candidate_value: float, has_current: bool) -> Dictionary:
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(label_text, "%.1f" % current_value if has_current else "--", "%.1f" % candidate_value, "%+.1f" % delta if has_current else "New", _comparison_impact(signf(delta)) if has_current else DecisionComparisonModel.IMPROVES)

func _comparison_impact(delta: float) -> int:
	if delta > 0.0: return DecisionComparisonModel.IMPROVES
	if delta < 0.0: return DecisionComparisonModel.WORSENS
	return DecisionComparisonModel.NEUTRAL

func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) == "engineering":
		start_project(context.get("engineer") as StaffMember)

func start_project(engineer: StaffMember) -> void:
	var selected_type := part_type.get_item_text(part_type.selected)
	var cash_before := GameManager.team.money
	if GameManager.team.queue_part_project(engineer, selected_type):
		var delivery := CalendarCatalog.format_day(GameManager.team.current_season_day + Team.ENGINEERING_PROJECT_DAYS)
		status_label.text = "%s started. Delivery: %s." % [selected_type, delivery]
		GameManager.refresh_team_money()
		GameManager.save_game()
		GameManager.report_decision_outcome({
			"title": "%s development started" % selected_type,
			"message": "%s is assigned to the project." % engineer.staff_name,
			"detail": "Projected delivery: %s" % delivery,
			"cash_delta": GameManager.team.money - cash_before,
			"action_label": "View project", "action_path": "res://scenes/pages/engineering/engineering.tscn",
		})
	else:
		status_label.text = "Unable to start that project. Check engineer availability and funds."
		GameManager.report_decision_outcome({
			"status": "error", "title": "Project not started", "message": status_label.text,
			"action_label": "Review engineering", "action_path": "res://scenes/pages/engineering/engineering.tscn",
		})
	refresh()

func add_text(parent: Control, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func clear(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()
