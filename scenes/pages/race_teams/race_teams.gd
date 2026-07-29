extends Control

@onready var teams_container: VBoxContainer = %teams_container
@onready var count_label: Label = %count_label
@onready var add_button: Button = %add_button
@onready var status_label: Label = %status_label


func _ready() -> void:
	add_button.pressed.connect(_add_team)
	refresh()


func refresh() -> void:
	for child in teams_container.get_children():
		child.queue_free()
	var team := GameManager.team
	team.ensure_race_teams()
	count_label.text = "%d / %d teams · $%s expansion cost" % [team.race_teams.size(), Team.MAX_RACE_TEAMS, number(team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST))]
	add_button.disabled = team.race_teams.size() >= Team.MAX_RACE_TEAMS or team.money < team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST)
	for race_team in team.race_teams:
		teams_container.add_child(make_team_card(race_team))


func make_team_card(race_team: RaceTeam) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	var heading := LineEdit.new()
	heading.text = race_team.team_name
	heading.placeholder_text = "Race team name"
	heading.text_submitted.connect(func(new_name: String):
		race_team.team_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else race_team.team_name
		GameManager.team.emit_changed()
		GameManager.save_game())
	content.add_child(heading)

	var assignments := GridContainer.new()
	assignments.columns = 2
	var driver_select := OptionButton.new()
	driver_select.add_item("Unassigned")
	var selected_driver := 0
	for driver in GameManager.team.get_contracted_drivers():
		driver_select.add_item(driver.driver_name)
		driver_select.set_item_metadata(driver_select.item_count - 1, driver.driver_id)
		if driver.driver_id == race_team.driver_id:
			selected_driver = driver_select.item_count - 1
	driver_select.select(selected_driver)
	var car_select := OptionButton.new()
	car_select.add_item("Unassigned")
	var selected_car := 0
	for bay in range(GameManager.team.cars.size()):
		var car := GameManager.team.get_car(bay)
		if car == null:
			continue
		car_select.add_item("Bay %d · %s" % [bay + 1, car.name])
		car_select.set_item_metadata(car_select.item_count - 1, bay)
		if bay == race_team.car_bay:
			selected_car = car_select.item_count - 1
	car_select.select(selected_car)
	assignments.add_child(labeled("DRIVER", driver_select))
	assignments.add_child(labeled("CAR", car_select))
	content.add_child(assignments)
	var readiness := Label.new()
	readiness.theme_type_variation = &"SuccessLabel" if race_team.is_ready(GameManager.team) else &"WarningLabel"
	readiness.text = "READY TO RACE" if race_team.is_ready(GameManager.team) else "Assign one contracted driver and one car"
	content.add_child(readiness)
	driver_select.item_selected.connect(func(index: int): _assign(race_team, str(driver_select.get_item_metadata(index)) if index > 0 else "", race_team.car_bay))
	car_select.item_selected.connect(func(index: int): _assign(race_team, race_team.driver_id, int(car_select.get_item_metadata(index)) if index > 0 else -1))
	panel.add_child(content)
	return panel


func labeled(title: String, field: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"EyebrowLabel"
	box.add_child(label)
	box.add_child(field)
	return box


func _assign(race_team: RaceTeam, driver_id: String, car_bay: int) -> void:
	if GameManager.team.assign_race_team(race_team, driver_id, car_bay):
		status_label.text = "Assignments saved. Each driver and car can belong to only one race team."
		GameManager.save_game()
	else:
		status_label.text = "That driver or car is already assigned to another team."
	refresh()


func _add_team() -> void:
	if GameManager.team.add_race_team() != null:
		GameManager.refresh_team_money()
		GameManager.save_game()
		status_label.text = "A new race team has been opened."
	else:
		status_label.text = "Unable to add a team. Check your cash and team limit."
	refresh()


func number(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result
