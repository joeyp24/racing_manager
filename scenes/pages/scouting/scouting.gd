extends Control

@onready var candidates: VBoxContainer = %candidates


func _ready() -> void:
	var level := GameManager.team.get_department_level("scouting")
	if level <= 0:
		return
	for driver in GameManager.team.drivers:
		if driver == null or driver.is_player_driver:
			continue
		candidates.add_child(_create_candidate(driver))


func _create_candidate(driver: Driver) -> Control:
	var panel := PanelContainer.new(); var column := VBoxContainer.new(); var label := Label.new()
	var report := GameManager.team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var active := _active_assignment(driver.driver_id)
	if not report.is_empty():
		label.text = "%s • %s\nPotential %d–%d • %s • Risk: %s" % [driver.driver_name, report.get("projected_role", "Unknown role"), report.get("potential_low", 0), report.get("potential_high", 99), report.get("strength", "Unknown strength"), report.get("risk", "Unknown")]
	elif not active.is_empty():
		label.text = "%s • %s in progress • %d week(s) remaining" % [driver.driver_name, active.get("type", "Assessment"), active.get("weeks_remaining", 1)]
	else:
		label.text = "%s • Age %d • Ratings hidden until assessed" % [driver.driver_name, driver.age]
	column.add_child(label)
	if active.is_empty():
		var choices := OptionButton.new()
		for type in ["Background check", "Current ability assessment", "Potential assessment", "Technical evaluation", "Personality evaluation"]: choices.add_item(type)
		var button := Button.new(); button.text = "Assign scout"; button.pressed.connect(_start_assignment.bind(driver, choices)); column.add_child(choices); column.add_child(button)
	panel.add_child(column); return panel


func _active_assignment(driver_id: String) -> Dictionary:
	for assignment in GameManager.team.scouting_assignments:
		if assignment.get("driver_id") == driver_id: return assignment
	return {}


func _start_assignment(driver: Driver, choices: OptionButton) -> void:
	if GameManager.team.start_scouting_assignment(driver, choices.get_item_text(choices.selected)):
		GameManager.save_game(); get_tree().reload_current_scene()
