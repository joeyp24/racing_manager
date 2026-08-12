extends Control

@onready var series_select: OptionButton = %series_select
@onready var teams_container: VBoxContainer = %teams_container
@onready var detail_container: VBoxContainer = %detail_container
@onready var directory_button: Button = %directory_button
@onready var operations_button: Button = %operations_button
@onready var summary_label: Label = %summary_label
@onready var content: HSplitContainer = %Content
@onready var operations_scroll: ScrollContainer = %OperationsScroll
@onready var operations_board: VBoxContainer = %OperationsBoard
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

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
	comparison_drawer.action_requested.connect(_on_comparison_action)
	show_directory()


func show_directory() -> void:
	directory_button.button_pressed = true
	operations_button.button_pressed = false
	series_select.disabled = false
	content.visible = true
	operations_scroll.visible = false
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
	var identity_row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(12, 48)
	swatch.color = Color(str(organization.get("primary_color", "7c3aed")))
	identity_row.add_child(swatch)
	var identity_copy := VBoxContainer.new()
	identity_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_copy.add_child(heading(str(organization.team_name), "%s  ·  OVR %d" % [str(organization.get("short_name", "TEAM")), int(organization.overall_rating)]))
	var motto := Label.new()
	motto.theme_type_variation = &"EyebrowLabel"
	motto.text = "“%s”" % str(organization.get("motto", "Race every lap"))
	identity_copy.add_child(motto)
	identity_row.add_child(identity_copy)
	detail_container.add_child(identity_row)
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
	content.visible = false
	operations_scroll.visible = true
	clear_container(operations_board)
	var team := GameManager.team
	team.ensure_race_teams()
	SponsorManager.ensure_state(team)
	var ready_entries := 0
	var prepared_entries := 0
	var total_gaps := 0
	for race_team in team.race_teams:
		if race_team.is_ready(team):
			ready_entries += 1
		var gaps := race_team.get_operations_gaps(team)
		total_gaps += gaps.size()
		if gaps.is_empty():
			prepared_entries += 1
	summary_label.text = "%d entries · %d race ready · %d fully prepared · %d action%s remaining" % [
		team.race_teams.size(), ready_entries, prepared_entries, total_gaps,
		"" if total_gaps == 1 else "s",
	]
	operations_board.add_child(_build_operations_overview(team, ready_entries, prepared_entries, total_gaps))
	var grid := GridContainer.new()
	grid.name = "OperationsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for race_team in team.race_teams:
		grid.add_child(_build_operation_card(team, race_team))
	operations_board.add_child(grid)
	operations_board.add_child(_build_expansion_card(team))


func _build_operations_overview(team: Team, ready_entries: int, prepared_entries: int, total_gaps: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := Label.new()
	title.text = "MULTI-TEAM OPERATIONS CENTER"
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var state := Label.new()
	state.text = "ALL CLEAR" if total_gaps == 0 else "%d OPEN ACTION%s" % [total_gaps, "" if total_gaps == 1 else "S"]
	state.theme_type_variation = &"SuccessLabel" if total_gaps == 0 else &"WarningLabel"
	title_row.add_child(state)
	var explanation := Label.new()
	explanation.text = "Review every entry together. Conflicting assignments are identified before you commit, and each card links directly to the market that resolves its gaps."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(explanation)
	var resources := Label.new()
	resources.name = "ResourceAvailability"
	resources.theme_type_variation = &"MutedLabel"
	resources.text = "%d/%d drivers available · %d/%d cars available · %d crew chiefs available · %d engineers available · %d sponsor slots open" % [
		_count_available_drivers(team), team.get_contracted_drivers().size(),
		_count_available_cars(team), team.cars.size(),
		_count_available_staff(team, "Crew Chief"), _count_available_staff(team, "Engineer"),
		_count_open_sponsor_slots(team),
	]
	layout.add_child(resources)
	var progress := ProgressBar.new()
	progress.name = "OrganizationReadiness"
	progress.max_value = maxi(1, team.race_teams.size() * 5)
	progress.value = team.race_teams.size() * 5 - total_gaps
	progress.show_percentage = true
	progress.tooltip_text = "%d entries can race; %d have every recommended assignment." % [ready_entries, prepared_entries]
	layout.add_child(progress)
	return panel


func _build_operation_card(team: Team, race_team: RaceTeam) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TeamCard_%s" % race_team.team_id
	panel.custom_minimum_size = Vector2(500.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = &"CardPanel"
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := Label.new()
	title.text = race_team.team_name
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var gaps := race_team.get_operations_gaps(team)
	var status := Label.new()
	if not race_team.is_ready(team):
		status.text = "ENTRY BLOCKED"
		status.theme_type_variation = &"DangerLabel"
	elif gaps.is_empty():
		status.text = "FULLY PREPARED"
		status.theme_type_variation = &"SuccessLabel"
	else:
		status.text = "RACE READY · %d/5" % race_team.get_operations_readiness(team)
		status.theme_type_variation = &"WarningLabel"
	title_row.add_child(status)

	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit_%s" % race_team.team_id
	name_edit.text = race_team.team_name
	name_edit.placeholder_text = "Race team name"
	name_edit.text_submitted.connect(_rename_race_team.bind(race_team))
	layout.add_child(name_edit)

	var gap_label := Label.new()
	gap_label.name = "Readiness_%s" % race_team.team_id
	gap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if gaps.is_empty():
		gap_label.text = "Every recommended resource is assigned."
		gap_label.theme_type_variation = &"SuccessLabel"
	else:
		gap_label.text = "NEEDS · %s" % ", ".join(gaps).to_upper()
		gap_label.theme_type_variation = &"WarningLabel"
	layout.add_child(gap_label)

	var assignments := GridContainer.new()
	assignments.columns = 2
	assignments.add_theme_constant_override("h_separation", 8)
	assignments.add_theme_constant_override("v_separation", 4)
	layout.add_child(assignments)
	_add_assignment_label(assignments, "DRIVER")
	var driver_select := _build_driver_select(team, race_team)
	assignments.add_child(driver_select)
	_add_assignment_label(assignments, "CAR")
	var car_select := _build_car_select(team, race_team)
	assignments.add_child(car_select)
	_add_assignment_label(assignments, "CREW CHIEF")
	var chief_select := _build_crew_chief_select(team, race_team)
	assignments.add_child(chief_select)

	var engineer_title := Label.new()
	engineer_title.text = "ENGINEERS · %d/%d" % [race_team.engineer_ids.size(), Team.MAX_ENGINEERS]
	engineer_title.theme_type_variation = &"EyebrowLabel"
	layout.add_child(engineer_title)
	for engineer_id in race_team.engineer_ids:
		var engineer := team.get_staff_by_id(engineer_id)
		if engineer == null:
			continue
		var engineer_row := HBoxContainer.new()
		var engineer_label := Label.new()
		engineer_label.text = "%s · OVR %d · %s" % [engineer.staff_name, engineer.rating, engineer.specialty]
		engineer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		engineer_row.add_child(engineer_label)
		var remove_button := Button.new()
		remove_button.text = "Remove"
		remove_button.pressed.connect(_unassign_staff.bind(engineer, race_team))
		engineer_row.add_child(remove_button)
		layout.add_child(engineer_row)
	var engineer_select := _build_engineer_select(team, race_team)
	layout.add_child(engineer_select)

	var sponsor_title := Label.new()
	sponsor_title.text = "SPONSOR PORTFOLIO · %d/%d · $%s/RACE" % [
		race_team.sponsor_contracts.size(), team.get_sponsor_capacity(), number(race_team.get_sponsor_income_per_race()),
	]
	sponsor_title.theme_type_variation = &"EyebrowLabel"
	layout.add_child(sponsor_title)
	if race_team.sponsor_contracts.is_empty():
		var no_sponsor := Label.new()
		no_sponsor.text = "No partners signed for this entry. Its market contains six entry-specific offers."
		no_sponsor.theme_type_variation = &"MutedLabel"
		no_sponsor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(no_sponsor)
	else:
		for contract in race_team.sponsor_contracts:
			var sponsor := Label.new()
			sponsor.text = "%s · $%s/race · %d races left" % [
				str(contract.get("sponsor_name", "Sponsor")),
				number(int(contract.get("payment_per_race", 0))),
				int(contract.get("races_remaining", 0)),
			]
			layout.add_child(sponsor)

	var shortcuts := HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_END
	for item in [
		["Drivers", "res://scenes/pages/drivers/drivers.tscn"],
		["Garage", "res://scenes/pages/garage/garage.tscn"],
		["Staff", "res://scenes/pages/staff/staff.tscn"],
		["Sponsors", "res://scenes/pages/sponsors/sponsors.tscn"],
	]:
		var shortcut := Button.new()
		shortcut.text = str(item[0])
		shortcut.pressed.connect(_open_for_race_team.bind(race_team.team_id, str(item[1])))
		shortcuts.add_child(shortcut)
	layout.add_child(shortcuts)
	return panel


func _add_assignment_label(grid: GridContainer, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = &"EyebrowLabel"
	label.custom_minimum_size.x = 110.0
	grid.add_child(label)


func _build_driver_select(team: Team, race_team: RaceTeam) -> OptionButton:
	var select := OptionButton.new()
	select.name = "DriverSelect_%s" % race_team.team_id
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Unassigned")
	select.set_item_metadata(0, "")
	var selected := 0
	for driver in team.get_contracted_drivers():
		var conflict := _driver_assignment(team, driver.driver_id, race_team.team_id)
		var label := driver.driver_name
		if conflict != null:
			label += " · Assigned to %s" % conflict.team_name
		select.add_item(label)
		var index := select.item_count - 1
		select.set_item_metadata(index, driver.driver_id)
		select.set_item_disabled(index, conflict != null)
		if conflict != null:
			select.set_item_tooltip(index, "Resolve the assignment on %s before moving this driver." % conflict.team_name)
		if driver.driver_id == race_team.driver_id:
			selected = index
	select.select(selected)
	select.item_selected.connect(func(index: int): _assign_driver(race_team, str(select.get_item_metadata(index))))
	return select


func _build_car_select(team: Team, race_team: RaceTeam) -> OptionButton:
	var select := OptionButton.new()
	select.name = "CarSelect_%s" % race_team.team_id
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Unassigned")
	select.set_item_metadata(0, -1)
	var selected := 0
	for bay in team.cars.size():
		var car := team.get_car(bay)
		if car == null:
			continue
		var conflict := _car_assignment(team, bay, race_team.team_id)
		var label := "Bay %d · %s" % [bay + 1, car.name]
		if conflict != null:
			label += " · Assigned to %s" % conflict.team_name
		select.add_item(label)
		var index := select.item_count - 1
		select.set_item_metadata(index, bay)
		select.set_item_disabled(index, conflict != null)
		if conflict != null:
			select.set_item_tooltip(index, "This car is already committed to %s." % conflict.team_name)
		if bay == race_team.car_bay:
			selected = index
	select.select(selected)
	select.item_selected.connect(func(index: int): _assign_car(race_team, int(select.get_item_metadata(index))))
	return select


func _build_crew_chief_select(team: Team, race_team: RaceTeam) -> OptionButton:
	var select := OptionButton.new()
	select.name = "CrewChiefSelect_%s" % race_team.team_id
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Unassigned")
	select.set_item_metadata(0, "")
	var selected := 0
	for chief in team.get_staff_by_role("Crew Chief"):
		var conflict := _staff_assignment(team, chief.staff_id, race_team.team_id)
		var label := "%s · OVR %d" % [chief.staff_name, chief.rating]
		if conflict != null:
			label += " · Assigned to %s" % conflict.team_name
		select.add_item(label)
		var index := select.item_count - 1
		select.set_item_metadata(index, chief.staff_id)
		select.set_item_disabled(index, conflict != null)
		if conflict != null:
			select.set_item_tooltip(index, "This crew chief is already leading %s." % conflict.team_name)
		if chief.staff_id == race_team.crew_chief_id:
			selected = index
	select.select(selected)
	select.item_selected.connect(func(index: int): _select_crew_chief(race_team, str(select.get_item_metadata(index))))
	return select


func _build_engineer_select(team: Team, race_team: RaceTeam) -> OptionButton:
	var select := OptionButton.new()
	select.name = "EngineerSelect_%s" % race_team.team_id
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Assign an engineer...")
	select.set_item_metadata(0, "")
	for engineer in team.get_staff_by_role("Engineer"):
		if race_team.engineer_ids.has(engineer.staff_id):
			continue
		var conflict := _staff_assignment(team, engineer.staff_id, race_team.team_id)
		var label := "%s · OVR %d" % [engineer.staff_name, engineer.rating]
		if conflict != null:
			label += " · Assigned to %s" % conflict.team_name
		select.add_item(label)
		var index := select.item_count - 1
		select.set_item_metadata(index, engineer.staff_id)
		select.set_item_disabled(index, conflict != null)
		if conflict != null:
			select.set_item_tooltip(index, "This engineer is already assigned to %s." % conflict.team_name)
	select.disabled = race_team.engineer_ids.size() >= Team.MAX_ENGINEERS
	select.tooltip_text = "This team already has the maximum number of engineers." if select.disabled else ""
	select.item_selected.connect(func(index: int):
		if index > 0:
			_assign_staff_to_team(team.get_staff_by_id(str(select.get_item_metadata(index))), race_team)
	)
	return select


func _build_expansion_card(team: Team) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ExpansionCard"
	panel.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = "ORGANIZATION EXPANSION"
	title.theme_type_variation = &"SectionTitle"
	copy.add_child(title)
	var cost := team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST)
	var detail := Label.new()
	detail.text = "%d/%d entries · Expansion cost $%s · Cash after $%s" % [
		team.race_teams.size(), Team.MAX_RACE_TEAMS, number(cost), number(team.money - cost),
	]
	detail.theme_type_variation = &"MutedLabel"
	copy.add_child(detail)
	var button := Button.new()
	button.name = "ReviewExpansionButton"
	button.text = "Review expansion"
	button.theme_type_variation = &"PrimaryButton"
	button.disabled = team.race_teams.size() >= Team.MAX_RACE_TEAMS
	button.tooltip_text = "The organization already operates the maximum of four entries." if button.disabled else "Compare capacity and cash before opening another entry."
	button.pressed.connect(_show_expansion_comparison)
	row.add_child(button)
	return panel


func _driver_assignment(team: Team, driver_id: String, excluding_team_id: String) -> RaceTeam:
	for race_team in team.race_teams:
		if race_team.team_id != excluding_team_id and race_team.driver_id == driver_id:
			return race_team
	return null


func _car_assignment(team: Team, bay: int, excluding_team_id: String) -> RaceTeam:
	for race_team in team.race_teams:
		if race_team.team_id != excluding_team_id and race_team.car_bay == bay:
			return race_team
	return null


func _staff_assignment(team: Team, staff_id: String, excluding_team_id: String) -> RaceTeam:
	for race_team in team.race_teams:
		if race_team.team_id == excluding_team_id:
			continue
		if race_team.crew_chief_id == staff_id or race_team.engineer_ids.has(staff_id):
			return race_team
	return null


func _count_available_drivers(team: Team) -> int:
	var count := 0
	for driver in team.get_contracted_drivers():
		if _driver_assignment(team, driver.driver_id, "") == null:
			count += 1
	return count


func _count_available_cars(team: Team) -> int:
	var count := 0
	for bay in team.cars.size():
		if team.get_car(bay) != null and _car_assignment(team, bay, "") == null:
			count += 1
	return count


func _count_available_staff(team: Team, role: String) -> int:
	var count := 0
	for member in team.get_staff_by_role(role):
		if _staff_assignment(team, member.staff_id, "") == null:
			count += 1
	return count


func _count_open_sponsor_slots(team: Team) -> int:
	var count := 0
	for race_team in team.race_teams:
		count += maxi(0, team.get_sponsor_capacity() - race_team.sponsor_contracts.size())
	return count


func _rename_race_team(value: String, race_team: RaceTeam) -> void:
	var clean_name := value.strip_edges()
	if clean_name.is_empty() or clean_name == race_team.team_name:
		show_operations()
		return
	var previous_name := race_team.team_name
	race_team.team_name = clean_name
	GameManager.save_game()
	show_operations()
	GameManager.report_decision_outcome({
		"title": "%s renamed" % clean_name,
		"message": "%s is now listed as %s across race operations." % [previous_name, clean_name],
		"action_label": "View operations",
		"action_path": "res://scenes/pages/race_teams/race_teams.tscn",
	})


func _assign_driver(race_team: RaceTeam, driver_id: String) -> void:
	var success := GameManager.team.assign_race_team(race_team, driver_id, race_team.car_bay)
	var driver := GameManager.team.get_driver_by_id(driver_id)
	_finish_assignment(
		success,
		"Driver assignment updated" if success else "Driver assignment blocked",
		"%s now drives for %s." % [driver.driver_name, race_team.team_name] if driver != null else "%s no longer has an assigned driver." % race_team.team_name,
		"The selected driver is contracted elsewhere or no longer available."
	)


func _assign_car(race_team: RaceTeam, car_bay: int) -> void:
	var success := GameManager.team.assign_race_team(race_team, race_team.driver_id, car_bay)
	var car := GameManager.team.get_car(car_bay)
	_finish_assignment(
		success,
		"Car assignment updated" if success else "Car assignment blocked",
		"%s is now assigned to %s." % [car.name, race_team.team_name] if car != null else "%s no longer has an assigned car." % race_team.team_name,
		"The selected car is committed to another entry or no longer available."
	)


func _select_crew_chief(race_team: RaceTeam, staff_id: String) -> void:
	if staff_id.is_empty():
		var current := GameManager.team.get_staff_by_id(race_team.crew_chief_id)
		if current == null:
			show_operations()
			return
		_unassign_staff(current, race_team)
		return
	_assign_staff_to_team(GameManager.team.get_staff_by_id(staff_id), race_team)


func _assign_staff_to_team(member: StaffMember, race_team: RaceTeam) -> void:
	var success := GameManager.team.assign_staff_to_race_team(member, race_team)
	_finish_assignment(
		success,
		"Staff assignment updated" if success else "Staff assignment blocked",
		"%s is now assigned to %s." % [member.staff_name, race_team.team_name] if member != null else "Staff assignment updated.",
		"This staff member is unavailable or the team's engineer group is full."
	)


func _unassign_staff(member: StaffMember, race_team: RaceTeam) -> void:
	var success := GameManager.team.unassign_staff_from_race_team(member, race_team)
	_finish_assignment(
		success,
		"Staff assignment cleared" if success else "Staff assignment unchanged",
		"%s is now available to another race team." % member.staff_name if member != null else "Staff assignment cleared.",
		"That assignment no longer exists."
	)


func _finish_assignment(success: bool, title_text: String, success_message: String, error_message: String) -> void:
	if success:
		GameManager.save_game()
	show_operations()
	GameManager.report_decision_outcome({
		"status": "success" if success else "error",
		"title": title_text,
		"message": success_message if success else error_message,
		"action_label": "View operations",
		"action_path": "res://scenes/pages/race_teams/race_teams.tscn",
	})


func _open_for_race_team(team_id: String, path: String) -> void:
	if GameManager.team.set_active_race_team(team_id):
		GameManager.save_game()
		GameManager.load_page(path)


func _show_expansion_comparison() -> void:
	var team := GameManager.team
	var cost := team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST)
	var at_capacity := team.race_teams.size() >= Team.MAX_RACE_TEAMS
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "ORGANIZATION DECISION",
		"title": "Open race entry %d" % (team.race_teams.size() + 1),
		"subtitle": "Compare organization capacity and cash before adding another independently managed entry.",
		"current_title": "%d ENTRIES" % team.race_teams.size(),
		"candidate_title": "%d ENTRIES" % mini(Team.MAX_RACE_TEAMS, team.race_teams.size() + 1),
		"metrics": [
			DecisionComparisonModel.metric("Race entries", str(team.race_teams.size()), str(mini(Team.MAX_RACE_TEAMS, team.race_teams.size() + 1)), "+1", DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Open drivers", str(_count_available_drivers(team)), str(maxi(0, _count_available_drivers(team) - 1)), "-1", DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Open cars", str(_count_available_cars(team)), str(maxi(0, _count_available_cars(team) - 1)), "-1", DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Sponsor slots", str(_count_open_sponsor_slots(team)), str(_count_open_sponsor_slots(team) + team.get_sponsor_capacity()), "+%d" % team.get_sponsor_capacity(), DecisionComparisonModel.IMPROVES),
		],
		"upfront_cost": cost,
		"action_enabled": not at_capacity,
		"disabled_reason": "The organization already operates the maximum of four entries." if at_capacity else "",
		"action_label": "Open race entry",
		"recommendation": "Expand when one driver, one car, and supporting staff are available so the new entry can become race ready quickly.",
		"risk": "The entry opens unassigned and needs its own driver, car, crew, and sponsor portfolio.",
		"context": {"kind": "race_team_expansion"},
	})
	comparison_drawer.display(model)


func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) == "race_team_expansion":
		_add_race_team()


func _show_operations_legacy() -> void:
	directory_button.button_pressed = false
	operations_button.button_pressed = true
	series_select.disabled = true
	clear_container(teams_container)
	clear_container(detail_container)
	var team := GameManager.team
	team.ensure_race_teams()
	summary_label.text = "%d / %d race teams · Managing %s · $%s expansion cost" % [team.race_teams.size(), Team.MAX_RACE_TEAMS, team.get_active_race_team().team_name, number(team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST))]
	var add_button := Button.new()
	add_button.text = "+ Add player race entry"
	add_button.theme_type_variation = &"PrimaryButton"
	add_button.disabled = team.race_teams.size() >= Team.MAX_RACE_TEAMS or team.money < team.get_discounted_cost(Team.RACE_TEAM_EXPANSION_COST)
	add_button.pressed.connect(_add_race_team)
	teams_container.add_child(add_button)
	for race_team in team.race_teams:
		teams_container.add_child(make_operation_button(race_team))
	add_section("MY RACE OPERATIONS")
	add_body("Each race team has its own driver, car, crew chief, engineers and sponsor portfolio. Select one team and manage it as a focused operation.")
	add_muted("The highlighted team becomes the context used by Drivers, Garage, Staff and Sponsors.")
	if not team.race_teams.is_empty():
		show_operation_detail(team.get_active_race_team())


func make_operation_button(race_team: RaceTeam) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_pressed = race_team.team_id == GameManager.team.active_race_team_id
	var driver := GameManager.team.get_driver_by_id(race_team.driver_id)
	var car := GameManager.team.get_car(race_team.car_bay)
	button.text = "%s\n%s · %s\n%d sponsor%s · %s" % [race_team.team_name, driver.driver_name if driver != null else "No driver", car.name if car != null else "No car", race_team.sponsor_contracts.size(), "s" if race_team.sponsor_contracts.size() != 1 else "", "READY" if race_team.is_ready(GameManager.team) else "Needs assignments"]
	button.pressed.connect(show_operation_detail.bind(race_team))
	return button


func show_operation_detail(race_team: RaceTeam) -> void:
	GameManager.team.set_active_race_team(race_team.team_id)
	clear_container(detail_container)
	detail_container.add_child(heading(race_team.team_name, "ACTIVE TEAM"))
	add_muted("Manage this operation's people, equipment and commercial partners without changing another race team.")
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
	var assigned_driver := GameManager.team.get_driver_by_id(race_team.driver_id)
	if assigned_driver != null and assigned_driver.is_pay_driver:
		add_muted("PAY DRIVER · Brings $%s in commercial backing per entered race." % number(GameManager.team.get_effective_sponsor_value(assigned_driver.sponsorship_contribution_per_race)))
	add_section("CAR")
	detail_container.add_child(car_select)
	driver_select.item_selected.connect(func(index: int): _assign(race_team, str(driver_select.get_item_metadata(index)) if index > 0 else "", race_team.car_bay))
	car_select.item_selected.connect(func(index: int): _assign(race_team, race_team.driver_id, int(car_select.get_item_metadata(index)) if index > 0 else -1))
	add_section("CREW CHIEF")
	var chief_select := OptionButton.new()
	chief_select.add_item("Unassigned")
	for chief in GameManager.team.get_staff_by_role("Crew Chief"):
		chief_select.add_item("%s · OVR %d" % [chief.staff_name, chief.rating])
		chief_select.set_item_metadata(chief_select.item_count - 1, chief.staff_id)
		if chief.staff_id == race_team.crew_chief_id:
			chief_select.select(chief_select.item_count - 1)
	chief_select.item_selected.connect(func(index: int):
		if index > 0:
			_assign_staff(GameManager.team.get_staff_by_id(str(chief_select.get_item_metadata(index))), race_team)
	)
	detail_container.add_child(chief_select)
	add_section("ENGINEERS")
	for engineer_id in race_team.engineer_ids:
		var engineer := GameManager.team.get_staff_by_id(engineer_id)
		if engineer != null:
			add_body("%s · OVR %d · %s" % [engineer.staff_name, engineer.rating, engineer.specialty])
	var engineer_select := OptionButton.new()
	engineer_select.add_item("Assign an engineer...")
	for engineer in GameManager.team.get_staff_by_role("Engineer"):
		if not race_team.engineer_ids.has(engineer.staff_id):
			engineer_select.add_item("%s · OVR %d" % [engineer.staff_name, engineer.rating])
			engineer_select.set_item_metadata(engineer_select.item_count - 1, engineer.staff_id)
	engineer_select.item_selected.connect(func(index: int):
		if index > 0:
			_assign_staff(GameManager.team.get_staff_by_id(str(engineer_select.get_item_metadata(index))), race_team)
	)
	detail_container.add_child(engineer_select)
	add_section("SPONSORS · %d / %d" % [race_team.sponsor_contracts.size(), GameManager.team.get_sponsor_capacity()])
	if race_team.sponsor_contracts.is_empty():
		add_muted("No partners signed. This race team has no guaranteed sponsor income.")
	else:
		for contract in race_team.sponsor_contracts:
			add_body("%s · $%s/race · %d races left" % [str(contract.get("sponsor_name", "Sponsor")), number(int(contract.get("payment_per_race", 0))), int(contract.get("races_remaining", 0))])
	var shortcuts := HBoxContainer.new()
	for item in [["Garage", "res://scenes/pages/garage/garage.tscn"], ["Drivers", "res://scenes/pages/drivers/drivers.tscn"], ["Staff", "res://scenes/pages/staff/staff.tscn"], ["Sponsors", "res://scenes/pages/sponsors/sponsors.tscn"]]:
		var shortcut := Button.new()
		shortcut.text = str(item[0])
		shortcut.pressed.connect(GameManager.load_page.bind(str(item[1])))
		shortcuts.add_child(shortcut)
	detail_container.add_child(shortcuts)
	GameManager.save_game()


func _assign(race_team: RaceTeam, driver_id: String, car_bay: int) -> void:
	GameManager.team.assign_race_team(race_team, driver_id, car_bay)
	GameManager.save_game()
	show_operations()


func _assign_staff(member: StaffMember, race_team: RaceTeam) -> void:
	if GameManager.team.assign_staff_to_race_team(member, race_team):
		GameManager.save_game()
	show_operations()


func _add_race_team() -> void:
	var cash_before := GameManager.team.money
	var race_team := GameManager.team.add_race_team()
	if race_team == null:
		show_operations()
		GameManager.report_decision_outcome({
			"status": "error",
			"title": "Race entry not opened",
			"message": "The organization is at capacity or no longer has enough cash.",
			"action_label": "Review operations",
			"action_path": "res://scenes/pages/race_teams/race_teams.tscn",
		})
		return
	SponsorManager.ensure_state(GameManager.team)
	GameManager.refresh_team_money()
	GameManager.save_game()
	show_operations()
	GameManager.report_decision_outcome({
		"title": "%s opened" % race_team.team_name,
		"message": "The new entry has its own assignments and a fresh six-sponsor market.",
		"detail": "Resolve the driver, car, crew, and commercial gaps before entering a race.",
		"cash_delta": GameManager.team.money - cash_before,
		"action_label": "Prepare entry",
		"action_path": "res://scenes/pages/race_teams/race_teams.tscn",
	})


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
