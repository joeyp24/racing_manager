extends Control

@onready var series_select: OptionButton = %series_select
@onready var teams_container: VBoxContainer = %teams_container
@onready var detail_container: VBoxContainer = %detail_container
@onready var directory_button: Button = %directory_button
@onready var operations_button: Button = %operations_button
@onready var summary_label: Label = %summary_label

var selected_series_id: String = ""
var selected_team_id: String = ""


func _ready() -> void:
	for series in SeriesCatalog.SERIES:
		series_select.add_item(str(series.name))
		series_select.set_item_metadata(series_select.item_count - 1, str(series.id))
		if str(series.id) == GameManager.team.current_series_id:
			series_select.select(series_select.item_count - 1)
	selected_series_id = str(series_select.get_selected_metadata())
	series_select.item_selected.connect(_on_series_selected)
	directory_button.pressed.connect(show_directory)
	operations_button.pressed.connect(show_operations)
	show_directory()


func show_directory() -> void:
	directory_button.button_pressed = true
	operations_button.button_pressed = false
	series_select.disabled = false
	refresh_directory()


func refresh_directory() -> void:
	clear_container(teams_container)
	var organizations := GameManager.team.get_ai_organizations_for_series(selected_series_id)
	summary_label.text = "%d organizations · %d cars · Ratings %d–%d" % [organizations.size(), RaceManager.get_ai_roster_for_series(selected_series_id).size(), minimum_rating(organizations), maximum_rating(organizations)]
	if selected_team_id.is_empty() or _get_organization(selected_team_id).is_empty():
		selected_team_id = str(organizations[0].team_id) if not organizations.is_empty() else ""
	for organization in organizations:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = str(organization.team_id) == selected_team_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\nOVR %d  ·  %d cars" % [organization.team_name, organization.overall_rating, organization.driver_count]
		button.tooltip_text = "%s · Founded %d" % [organization.hometown, organization.founded]
		button.pressed.connect(_select_team.bind(str(organization.team_id)))
		teams_container.add_child(button)
	show_team_detail()


func show_team_detail() -> void:
	clear_container(detail_container)
	var organization := _get_organization(selected_team_id)
	if organization.is_empty():
		return
	var series := SeriesCatalog.get_series(selected_series_id)
	detail_container.add_child(heading(str(organization.team_name), "OVR %d" % int(organization.overall_rating)))
	add_muted("%s  ·  Founded %d  ·  %d championships" % [organization.hometown, organization.founded, organization.championships])
	add_muted("TREND %+.1f  ·  FINANCES %s%s" % [float(organization.get("trend", 0.0)), str(organization.get("financial_status", "Stable")).to_upper(), "  ·  " + str(organization.movement).to_upper() if not str(organization.get("movement", "")).is_empty() else ""])
	add_section("TEAM RATINGS")
	var ratings := GridContainer.new()
	ratings.columns = 2
	for row in [["Equipment", organization.equipment_rating], ["Engineering", organization.engineering_rating], ["Pit crew", organization.pit_crew_rating], ["Strategy", organization.strategy_rating]]:
		ratings.add_child(metric(str(row[0]), int(row[1])))
	detail_container.add_child(ratings)
	add_section("TEAM PHILOSOPHY")
	add_body("%s  |  %s" % [str(organization.get("philosophy", "Balanced contender")), str(organization.get("philosophy_description", "Balanced decision-making."))])
	add_muted("REGULATION PREFERENCE  %s" % str(organization.get("regulation_preference", "Competitive balance")))
	var style_notes: Array[String] = []
	style_notes.append("development %+.0f%%" % ((float(organization.get("development_multiplier", 1.0)) - 1.0) * 100.0))
	style_notes.append("strategy risk %+.0f%%" % (float(organization.get("strategy_aggression", 0.0)) * 100.0))
	style_notes.append("youth bias %+.0f%%" % (float(organization.get("youth_bias", 0.0)) * 100.0))
	add_muted("DECISION MODEL  " + "  |  ".join(style_notes))
	add_section("HISTORY")
	add_body(str(organization.history))
	var team_state := GameManager.team.get_ai_team_state(selected_team_id)
	for season_value in (team_state.get("season_results", []) as Array).slice(0, 5):
		var season_result := season_value as Dictionary
		var record_series := SeriesCatalog.get_series(str(season_result.get("series_id", "")))
		add_muted("%d  ·  %s  ·  P%d  ·  %d points  ·  Equipment %d" % [
			int(season_result.get("season", 0)),
			str(record_series.get("name", "Unknown series")),
			int(season_result.get("position", 0)),
			int(season_result.get("points", 0)),
			int(season_result.get("equipment_rating", 0))
		])
	add_section("DRIVERS")
	var roster := RaceManager.get_ai_roster_for_series(selected_series_id)
	for driver in roster:
		if str(driver.team_id) != selected_team_id:
			continue
		var driver_row := Label.new()
		driver_row.text = "CAR %d    %s    DRV %d  ·  CAR %d" % [driver.team_car_number, driver.driver_name, driver.skill, driver.car_performance]
		driver_row.theme_type_variation = &"BodyStrong"
		detail_container.add_child(driver_row)
	add_section("SEASON STATS")
	var stats := get_team_stats(selected_series_id, selected_team_id, str(organization.team_name))
	var stats_grid := GridContainer.new()
	stats_grid.columns = 4
	for row in [["Starts", stats.starts], ["Wins", stats.wins], ["Podiums", stats.podiums], ["Points", stats.points]]:
		stats_grid.add_child(metric(str(row[0]), int(row[1])))
	detail_container.add_child(stats_grid)
	add_section("RACE RESULTS")
	if stats.results.is_empty():
		add_muted("No races completed in this series yet.")
	else:
		for result in stats.results:
			add_body("%s  ·  Best: P%d  ·  %s" % [result.race_name, result.best_finish, result.finishes])
	add_muted("Competing in %s" % str(series.name))


func _get_organization(team_id: String) -> Dictionary:
	for organization in GameManager.team.get_ai_organizations_for_series(selected_series_id):
		if str(organization.team_id) == team_id:
			return organization
	return {}


func get_team_stats(series_id: String, team_id: String, team_name: String) -> Dictionary:
	var stats := {"starts":0, "wins":0, "podiums":0, "points":0, "results":[]}
	var data := GameManager.team.get_world_series_data(series_id)
	var standings: Array = data.get("standings", [])
	if series_id == GameManager.team.current_series_id:
		standings = GameManager.team.get_championship_standings()
	for entry in standings:
		if str(entry.get("team_id", "")) == team_id or str(entry.get("team_name", "")) == team_name:
			stats.starts += int(entry.get("starts", 0))
			stats.wins += int(entry.get("wins", 0))
			stats.podiums += int(entry.get("podiums", 0))
			stats.points += int(entry.get("points", 0))
	for race_result in data.get("results", []):
		var finishes: Array[int] = []
		for row in race_result.get("rows", []):
			if str(row.get("team_id", "")) == team_id or str(row.get("team_name", "")) == team_name:
				finishes.append(int(row.get("position", 0)))
		if not finishes.is_empty():
			finishes.sort()
			var finish_text: Array[String] = []
			for finish in finishes:
				finish_text.append("P%d" % finish)
			stats.results.push_front({"race_name":str(race_result.get("race_name", "Race")), "best_finish":finishes[0], "finishes":", ".join(finish_text)})
	if stats.results.size() > 6:
		stats.results.resize(6)
	return stats


func show_operations() -> void:
	directory_button.button_pressed = false
	operations_button.button_pressed = true
	series_select.disabled = true
	clear_container(teams_container)
	clear_container(detail_container)
	var team := GameManager.team
	team.ensure_race_teams()
	summary_label.text = "%d / %d player entries · $%s expansion cost" % [team.race_teams.size(), Team.MAX_RACE_TEAMS, number(team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST))]
	var add_button := Button.new()
	add_button.text = "+ Add player race entry"
	add_button.theme_type_variation = &"PrimaryButton"
	add_button.disabled = team.race_teams.size() >= Team.MAX_RACE_TEAMS or team.money < team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST)
	add_button.pressed.connect(_add_race_team)
	teams_container.add_child(add_button)
	for race_team in team.race_teams:
		teams_container.add_child(make_operation_button(race_team))
	add_section("MY RACE OPERATIONS")
	add_body("Your organization can field up to four cars in its current series. Every entry needs a unique contracted driver and garage car.")
	add_muted("Select an entry on the left to change its driver and car assignments.")
	if not team.race_teams.is_empty():
		show_operation_detail(team.race_teams[0])


func make_operation_button(race_team: RaceTeam) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s\n%s" % [race_team.team_name, "READY" if race_team.is_ready(GameManager.team) else "Needs assignments"]
	button.pressed.connect(show_operation_detail.bind(race_team))
	return button


func show_operation_detail(race_team: RaceTeam) -> void:
	clear_container(detail_container)
	detail_container.add_child(heading(race_team.team_name, "PLAYER ENTRY"))
	var name_edit := LineEdit.new()
	name_edit.text = race_team.team_name
	name_edit.text_submitted.connect(func(value: String):
		if not value.strip_edges().is_empty(): race_team.team_name = value.strip_edges()
		GameManager.save_game(); show_operations())
	detail_container.add_child(name_edit)
	var driver_select := OptionButton.new()
	driver_select.add_item("Unassigned")
	var selected_driver := 0
	for driver in GameManager.team.get_contracted_drivers():
		driver_select.add_item(driver.driver_name)
		driver_select.set_item_metadata(driver_select.item_count - 1, driver.driver_id)
		if driver.driver_id == race_team.driver_id: selected_driver = driver_select.item_count - 1
	driver_select.select(selected_driver)
	var car_select := OptionButton.new()
	car_select.add_item("Unassigned")
	var selected_car := 0
	for bay in GameManager.team.cars.size():
		var car := GameManager.team.get_car(bay)
		if car == null: continue
		car_select.add_item("Bay %d · %s" % [bay + 1, car.name])
		car_select.set_item_metadata(car_select.item_count - 1, bay)
		if bay == race_team.car_bay: selected_car = car_select.item_count - 1
	car_select.select(selected_car)
	add_section("DRIVER")
	detail_container.add_child(driver_select)
	add_section("CAR")
	detail_container.add_child(car_select)
	driver_select.item_selected.connect(func(index: int): _assign(race_team, str(driver_select.get_item_metadata(index)) if index > 0 else "", race_team.car_bay))
	car_select.item_selected.connect(func(index: int): _assign(race_team, race_team.driver_id, int(car_select.get_item_metadata(index)) if index > 0 else -1))


func _assign(race_team: RaceTeam, driver_id: String, car_bay: int) -> void:
	GameManager.team.assign_race_team(race_team, driver_id, car_bay)
	GameManager.save_game()
	show_operations()


func _add_race_team() -> void:
	if GameManager.team.add_race_team() != null:
		GameManager.refresh_team_money()
		GameManager.save_game()
	show_operations()


func _on_series_selected(index: int) -> void:
	selected_series_id = str(series_select.get_item_metadata(index))
	selected_team_id = ""
	refresh_directory()


func _select_team(team_id: String) -> void:
	selected_team_id = team_id
	refresh_directory()


func heading(title: String, badge: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new(); label.text = title; label.theme_type_variation = &"SectionTitle"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge_label := Label.new(); badge_label.text = badge; badge_label.theme_type_variation = &"SuccessLabel"
	row.add_child(label); row.add_child(badge_label)
	return row


func metric(label_text: String, value: int) -> Control:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new(); value_label.text = str(value); value_label.theme_type_variation = &"MetricValue"
	var label := Label.new(); label.text = label_text.to_upper(); label.theme_type_variation = &"EyebrowLabel"
	box.add_child(value_label); box.add_child(label)
	return box


func add_section(value: String) -> void:
	var label := Label.new(); label.text = value; label.theme_type_variation = &"EyebrowLabel"
	detail_container.add_child(label)


func add_body(value: String) -> void:
	var label := Label.new(); label.text = value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_container.add_child(label)


func add_muted(value: String) -> void:
	var label := Label.new(); label.text = value; label.theme_type_variation = &"MutedLabel"; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_container.add_child(label)


func clear_container(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func minimum_rating(teams: Array[Dictionary]) -> int:
	var result := 100
	for team in teams: result = mini(result, int(team.overall_rating))
	return result if not teams.is_empty() else 0


func maximum_rating(teams: Array[Dictionary]) -> int:
	var result := 0
	for team in teams: result = maxi(result, int(team.overall_rating))
	return result


func number(value: int) -> String:
	var raw := str(value); var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result; raw = raw.left(raw.length() - 3)
	return raw + result
