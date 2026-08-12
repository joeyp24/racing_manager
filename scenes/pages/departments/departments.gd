extends Control

@onready var department_grid: GridContainer = %department_grid
@onready var status_label: Label = %status_label
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer


func _ready() -> void:
	comparison_drawer.action_requested.connect(_on_comparison_action)
	refresh_departments()


func refresh_departments() -> void:
	for child in department_grid.get_children():
		child.queue_free()

	var team: Team = GameManager.team
	department_grid.add_child(create_hq_card())
	for department_id in DepartmentCatalog.get_ids():
		if department_id == "cheating" and not team.is_secret_department_unlocked():
			continue
		department_grid.add_child(create_department_card(department_id))


func create_hq_card() -> Control:
	var team: Team = GameManager.team
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(285, 160)
	panel.theme_type_variation = &"CardPanel"
	var content := VBoxContainer.new()
	var title := Label.new(); title.text = "Team Headquarters"
	var level := Label.new(); level.text = "Level %d / %d" % [team.hq_level, SeriesCatalog.SERIES.size()]
	var description := Label.new(); description.text = "Headquarters improves operational capacity and remains an optional investment. Series promotion is earned through reputation, season completion and financial readiness."; description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var action := Button.new()
	var cost := team.get_hq_upgrade_cost()
	action.text = "Maximum Level" if cost <= 0 else "Review HQ upgrade"
	action.disabled = cost <= 0
	action.pressed.connect(_show_hq_comparison)
	content.add_child(title); content.add_child(level); content.add_child(description); content.add_child(action); panel.add_child(content)
	return panel


func _on_hq_upgrade_pressed() -> void:
	if GameManager.team.upgrade_hq():
		status_label.text = "Team HQ upgraded to level %d." % GameManager.team.hq_level
		GameManager.refresh_team_money(); GameManager.save_game(); refresh_departments()


func create_department_card(department_id: String) -> Control:
	var team: Team = GameManager.team
	var data := DepartmentCatalog.get_data(department_id)
	var level := team.get_department_level(department_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(285, 160)
	panel.theme_type_variation = &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_top", UITokens.CARD_PADDING_VERTICAL)
	margin.add_theme_constant_override("margin_right", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_bottom", UITokens.CARD_PADDING_VERTICAL)
	var content := VBoxContainer.new()
	var title := Label.new()
	title.text = str(data.get("name", department_id))
	title.theme_type_variation = &"CardTitle"
	var level_label := Label.new()
	level_label.text = "Not purchased" if level == 0 else "Level %d / %d  •  %.1f%% bonus" % [level, DepartmentCatalog.MAX_LEVEL, team.get_department_bonus(department_id)]
	var description := Label.new()
	description.text = str(data.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var action := Button.new()
	if level >= DepartmentCatalog.MAX_LEVEL:
		action.text = "Maximum Level"
		action.disabled = true
	else:
		var cost := team.get_department_cost(department_id)
		action.text = "Review %s" % ("purchase" if level == 0 else "upgrade")
		action.pressed.connect(_show_department_comparison.bind(department_id))
	content.add_child(title)
	content.add_child(level_label)
	content.add_child(description)
	content.add_child(action)
	margin.add_child(content)
	panel.add_child(margin)
	return panel


func _show_hq_comparison() -> void:
	var team: Team = GameManager.team
	var cost := team.get_hq_upgrade_cost()
	var next_level := mini(SeriesCatalog.SERIES.size(), team.hq_level + 1)
	var current_series := SeriesCatalog.SERIES[clampi(team.hq_level - 1, 0, SeriesCatalog.SERIES.size() - 1)] as Dictionary
	var next_series := SeriesCatalog.SERIES[clampi(next_level - 1, 0, SeriesCatalog.SERIES.size() - 1)] as Dictionary
	var metrics: Array = [
		DecisionComparisonModel.metric("HQ level", str(team.hq_level), str(next_level), "+1", DecisionComparisonModel.IMPROVES),
		DecisionComparisonModel.metric("Series gate", str(current_series.get("name", "Current tier")), str(next_series.get("name", "Next tier")), "Unlocked", DecisionComparisonModel.IMPROVES, "HQ is one of several requirements for promotion."),
		DecisionComparisonModel.metric("Tier capacity", "%d tiers" % team.hq_level, "%d tiers" % next_level, "+1", DecisionComparisonModel.IMPROVES),
		DecisionComparisonModel.metric("Promotion", "Current gates", "HQ gate ready", "Partial", DecisionComparisonModel.WARNING, "Reputation, season completion, and financial readiness still apply."),
	]
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "HEADQUARTERS DECISION",
		"title": "Upgrade HQ to level %d" % next_level,
		"subtitle": "Expand the team's operational ceiling and satisfy the next series' headquarters gate.",
		"current_title": "LEVEL %d" % team.hq_level,
		"candidate_title": "LEVEL %d" % next_level,
		"metrics": metrics,
		"upfront_cost": cost,
		"recurring_per_race": 0,
		"action_enabled": cost > 0,
		"disabled_reason": "Headquarters is already at maximum level." if cost <= 0 else "",
		"action_label": "Upgrade headquarters",
		"recommendation": "Upgrade when the next series is a near-term goal and the remaining cash stays above the operating reserve.",
		"risk": "This unlocks the HQ gate only; promotion still depends on reputation, season completion, and finances.",
		"context": {"kind": "hq"},
	})
	comparison_drawer.display(model)


func _show_department_comparison(department_id: String) -> void:
	var team: Team = GameManager.team
	var data := DepartmentCatalog.get_data(department_id)
	var current_level := team.get_department_level(department_id)
	var next_level := mini(DepartmentCatalog.MAX_LEVEL, current_level + 1)
	var current_bonus := team.get_department_bonus(department_id)
	var next_bonus := DepartmentCatalog.get_bonus(next_level)
	var cost := team.get_department_cost(department_id)
	var metrics: Array = [
		DecisionComparisonModel.metric("Department level", str(current_level), str(next_level), "+1", DecisionComparisonModel.IMPROVES),
		DecisionComparisonModel.metric("Team bonus", "%.1f%%" % current_bonus, "%.1f%%" % next_bonus, "+%.1f%%" % (next_bonus - current_bonus), DecisionComparisonModel.IMPROVES),
		DecisionComparisonModel.metric("Benefit", "Inactive" if current_level == 0 else "Active", str(data.get("description", "Team improvement")), "Enabled" if current_level == 0 else "Stronger", DecisionComparisonModel.IMPROVES, str(data.get("description", ""))),
		DecisionComparisonModel.metric("Level ceiling", "%d" % DepartmentCatalog.MAX_LEVEL, "%d" % DepartmentCatalog.MAX_LEVEL, "%d remaining" % (DepartmentCatalog.MAX_LEVEL - next_level), DecisionComparisonModel.NEUTRAL),
	]
	var department_name := str(data.get("name", department_id.capitalize()))
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "FACILITY DECISION",
		"title": "%s · level %d" % [department_name, next_level],
		"subtitle": "Review the permanent team-wide benefit before investing.",
		"current_title": "LEVEL %d" % current_level if current_level > 0 else "NOT OWNED",
		"candidate_title": "LEVEL %d" % next_level,
		"metrics": metrics,
		"upfront_cost": cost,
		"recurring_per_race": 0,
		"action_enabled": current_level < DepartmentCatalog.MAX_LEVEL and cost > 0,
		"disabled_reason": "This department is already at maximum level." if current_level >= DepartmentCatalog.MAX_LEVEL else "",
		"action_label": "Purchase department" if current_level == 0 else "Upgrade department",
		"recommendation": "%s Prioritize it when that benefit supports the team's current bottleneck." % str(data.get("description", "This adds a permanent team bonus.")),
		"context": {"kind": "department", "department_id": department_id},
	})
	comparison_drawer.display(model)


func _on_comparison_action(context: Dictionary) -> void:
	match str(context.get("kind", "")):
		"hq":
			_on_hq_upgrade_pressed()
		"department":
			_on_purchase_pressed(str(context.get("department_id", "")))


func _on_purchase_pressed(department_id: String) -> void:
	if not GameManager.team.purchase_department(department_id):
		status_label.text = "That department cannot be purchased right now."
		return
	var data := DepartmentCatalog.get_data(department_id)
	status_label.text = "%s is now level %d." % [data.get("name", department_id), GameManager.team.get_department_level(department_id)]
	GameManager.refresh_team_money()
	GameManager.save_game()
	refresh_departments()


func format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
