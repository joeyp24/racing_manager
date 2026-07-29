extends Control

@onready var department_grid: GridContainer = %department_grid
@onready var status_label: Label = %status_label


func _ready() -> void:
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
	department_grid.add_child(create_series_ladder_card())


func create_hq_card() -> Control:
	var team: Team = GameManager.team
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(315, 190)
	var content := VBoxContainer.new()
	var title := Label.new(); title.text = "Team Headquarters"
	var level := Label.new(); level.text = "Level %d / %d" % [team.hq_level, SeriesCatalog.SERIES.size()]
	var description := Label.new(); description.text = "HQ level gates promotion so the team builds infrastructure before taking on a more expensive series."; description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var action := Button.new()
	var cost := team.get_hq_upgrade_cost()
	action.text = "Maximum Level" if cost <= 0 else "Upgrade HQ — $%s" % format_number(cost)
	action.disabled = cost <= 0 or team.money < cost
	action.pressed.connect(_on_hq_upgrade_pressed)
	content.add_child(title); content.add_child(level); content.add_child(description); content.add_child(action); panel.add_child(content)
	return panel


func create_series_ladder_card() -> Control:
	var team: Team = GameManager.team
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(315, 190)
	var content := VBoxContainer.new()
	var title := Label.new(); title.text = "Series Ladder"
	var current := Label.new(); current.text = "Current: %s" % SeriesCatalog.get_series(team.current_series_id).name; current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action := Button.new()
	var next_index := SeriesCatalog.get_index(team.current_series_id) + 1
	if next_index >= SeriesCatalog.SERIES.size():
		action.text = "Top Series Reached"; action.disabled = true
	else:
		var next: Dictionary = SeriesCatalog.SERIES[next_index]
		action.text = "Enter %s — $%s" % [next.name, format_number(team.get_discounted_cost(int(next.entry_cost)))]
		action.tooltip_text = "Requires Team HQ level %d. A series-specific car must be purchased separately." % next.hq_level
		action.disabled = not team.can_enter_series(str(next.id))
		action.pressed.connect(_on_enter_series_pressed.bind(str(next.id)))
	content.add_child(title); content.add_child(current); content.add_child(action); panel.add_child(content)
	return panel


func _on_hq_upgrade_pressed() -> void:
	if GameManager.team.upgrade_hq():
		status_label.text = "Team HQ upgraded to level %d." % GameManager.team.hq_level
		GameManager.refresh_team_money(); GameManager.save_game(); refresh_departments()


func _on_enter_series_pressed(series_id: String) -> void:
	if GameManager.team.enter_series(series_id):
		status_label.text = "Welcome to %s. Visit the dealership for an eligible car." % SeriesCatalog.get_series(series_id).name
		GameManager.refresh_team_money(); GameManager.save_game(); refresh_departments()


func create_department_card(department_id: String) -> Control:
	var team: Team = GameManager.team
	var data := DepartmentCatalog.get_data(department_id)
	var level := team.get_department_level(department_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(315, 190)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	var content := VBoxContainer.new()
	var title := Label.new()
	title.text = str(data.get("name", department_id))
	title.add_theme_font_size_override("font_size", 18)
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
		action.text = "%s — $%s" % ["Purchase" if level == 0 else "Upgrade to Level %d" % (level + 1), format_number(cost)]
		action.disabled = team.money < cost
		action.pressed.connect(_on_purchase_pressed.bind(department_id))
	content.add_child(title)
	content.add_child(level_label)
	content.add_child(description)
	content.add_child(action)
	margin.add_child(content)
	panel.add_child(margin)
	return panel


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
