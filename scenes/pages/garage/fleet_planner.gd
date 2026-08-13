extends Control

const HORIZON_EVENTS: int = 5

@onready var team_selector: OptionButton = %team_selector
@onready var horizon_label: Label = %horizon_label
@onready var plan_value: Label = %plan_value
@onready var workload_value: Label = %workload_value
@onready var event_container: VBoxContainer = %event_container
@onready var status_label: Label = %status_label
@onready var workshop_button: Button = %workshop_button
@onready var back_button: Button = %back_button

var upcoming_races: Array[Race] = []


func _ready() -> void:
	team_selector.item_selected.connect(_on_team_selected)
	workshop_button.pressed.connect(_open_workshop)
	back_button.pressed.connect(_return_to_garage)
	_setup_team_selector()
	refresh()


func _setup_team_selector() -> void:
	team_selector.clear()
	if GameManager.team == null:
		return
	GameManager.team.ensure_race_teams()
	var selected_index := 0
	for race_team in GameManager.team.race_teams:
		if race_team == null or not race_team.active:
			continue
		var driver := GameManager.team.get_driver_by_id(race_team.driver_id)
		team_selector.add_item("%s  ·  %s" % [race_team.team_name, driver.driver_name if driver != null else "Driver unassigned"])
		team_selector.set_item_metadata(team_selector.item_count - 1, race_team.team_id)
		if race_team.team_id == GameManager.team.active_race_team_id:
			selected_index = team_selector.item_count - 1
	if team_selector.item_count > 0:
		team_selector.select(selected_index)


func refresh(message: String = "") -> void:
	_clear_events()
	if GameManager.team == null:
		return
	upcoming_races = _get_upcoming_races()
	var race_team := _get_selected_race_team()
	var driver := GameManager.team.get_driver_by_id(race_team.driver_id) if race_team != null else null
	var race_ids: Array[String] = []
	var team_planned := 0
	for race in upcoming_races:
		race_ids.append(race.race_id)
		if race_team != null and GameManager.team.get_race_car_assignment(race.race_id, race_team.team_id) >= 0:
			team_planned += 1
	plan_value.text = "%d / %d" % [team_planned, upcoming_races.size()]
	var job_count := 0
	for car_value in GameManager.team.cars:
		var car := car_value as Car
		if car != null:
			job_count += car.workshop_jobs.size()
	workload_value.text = "%d job%s" % [job_count, "" if job_count == 1 else "s"]
	if upcoming_races.is_empty():
		horizon_label.text = "No upcoming events remain in this campaign."
		_add_note(event_container, "The current series schedule is complete.")
	else:
		horizon_label.text = "Planning horizon  ·  %s to %s  ·  %s" % [
			CalendarCatalog.format_day(upcoming_races[0].schedule_day),
			CalendarCatalog.format_day(upcoming_races[-1].schedule_day),
			driver.driver_name if driver != null else "Assign a driver to complete familiarity forecasts",
		]
		for race in upcoming_races:
			_add_event_card(race, race_team, driver)
	if not message.is_empty():
		status_label.text = message


func _get_upcoming_races() -> Array[Race]:
	var races: Array[Race] = []
	if GameManager.team == null:
		return races
	for race in RaceManager.get_calendar_for_series(GameManager.team.current_series_id):
		if GameManager.team.get_completed_races().has(race.race_id) or race.schedule_day < GameManager.team.current_season_day:
			continue
		races.append(race)
		if races.size() >= HORIZON_EVENTS:
			break
	return races


func _get_selected_race_team() -> RaceTeam:
	if GameManager.team == null or team_selector.item_count == 0:
		return null
	return GameManager.team.get_race_team_by_id(str(team_selector.get_item_metadata(team_selector.selected)))


func _add_event_card(race: Race, race_team: RaceTeam, driver: Driver) -> void:
	var card := PanelContainer.new()
	card.name = "Event_%s" % race.race_id
	card.theme_type_variation = &"CardPanel"
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	card.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title := Label.new()
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "ROUND %02d  ·  %s" % [race.season_round, race.race_name]
	heading.add_child(title)
	var date := Label.new()
	date.theme_type_variation = &"EyebrowLabel"
	date.text = "%s  ·  %s" % [CalendarCatalog.format_day(race.schedule_day), race.track_type.to_upper()]
	heading.add_child(date)
	var assigned_bay := GameManager.team.get_race_car_assignment(race.race_id, race_team.team_id) if race_team != null else -1
	var assigned_car := GameManager.team.get_car(assigned_bay)
	var assignment := Label.new()
	assignment.theme_type_variation = &"SuccessLabel" if assigned_car != null else &"WarningLabel"
	assignment.text = (
		"PLANNED CAR  ·  BAY %02d  ·  %s" % [assigned_bay + 1, assigned_car.name]
		if assigned_car != null
		else "NO CAR ASSIGNED  ·  Choose a chassis below before scheduling its setup"
	)
	stack.add_child(assignment)
	var recommended := GameManager.team.get_recommended_car_for_race(race, race_team)
	for bay in GameManager.team.cars.size():
		var car := GameManager.team.get_car(bay)
		if car == null or car.series_id != race.series_id:
			continue
		_add_car_comparison(stack, race, race_team, driver, car, bay, assigned_bay, car == recommended)
	if recommended == null:
		_add_note(stack, "No eligible car is owned for this series.")
	event_container.add_child(card)


func _add_car_comparison(parent: VBoxContainer, race: Race, race_team: RaceTeam, driver: Driver, car: Car, bay: int, assigned_bay: int, recommended: bool) -> void:
	var forecast := GameManager.team.get_car_race_forecast(car, race, driver)
	var row := PanelContainer.new()
	row.name = "Car_%d" % bay
	row.theme_type_variation = &"StatusMetricPanel"
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	row.add_child(stack)
	var top := HBoxContainer.new()
	stack.add_child(top)
	var identity := Label.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.theme_type_variation = &"BodyStrong"
	identity.text = "BAY %02d  ·  %s%s" % [bay + 1, car.name, "  ·  RECOMMENDED" if recommended else ""]
	top.add_child(identity)
	var assign_button := Button.new()
	assign_button.name = "Assign_%d" % bay
	assign_button.custom_minimum_size.x = 170.0
	var quote := GameManager.team.get_assignment_change_quote(race, race_team, bay) if race_team != null else {}
	if bay == assigned_bay:
		assign_button.text = "PLANNED"
		assign_button.disabled = true
	elif bool(quote.get("late_change", false)):
		assign_button.text = "CHANGE  ·  $%s LATE FEE" % String.num_int64(int(quote.get("cost", 0)))
		assign_button.disabled = GameManager.team.money < int(quote.get("cost", 0))
	else:
		assign_button.text = "ASSIGN CAR"
	assign_button.pressed.connect(_assign_car.bind(race, race_team, bay))
	top.add_child(assign_button)
	var details := Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.theme_type_variation = &"MutedLabel"
	details.text = "%s\nPACE %.1f  ·  IDENTITY %+.1f  ·  RELIABILITY %d  ·  WEAR %d%%  ·  SETUP %d DAYS%s  ·  DRIVER/CAR STARTS %d%s" % [
		car.get_identity_summary().to_upper(),
		float(forecast.get("pace_index", 0.0)),
		float(forecast.get("pace_bonus", 0.0)),
		int(forecast.get("reliability", 0)),
		int(forecast.get("wear_index", 100)),
		int(forecast.get("preparation_days", 0)),
		" (SAVED)" if bool(forecast.get("saved_setup", false)) else "",
		int(forecast.get("familiarity_starts", 0)),
		"  ·  TIGHT TURNAROUND %dD" % int(forecast.get("turnaround_days", 0)) if bool(forecast.get("tight_turnaround", false)) else "",
	]
	stack.add_child(details)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	var readiness := Label.new()
	readiness.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readiness.theme_type_variation = &"SuccessLabel" if bool(forecast.get("available_for_event", false)) else &"WarningLabel"
	readiness.text = (
		"CAN BE READY BY %s  ·  CURRENT PREP %d/100" % [CalendarCatalog.format_day(int(forecast.get("ready_day", GameManager.team.current_season_day))), car.get_preparation_score(race)]
		if bool(forecast.get("available_for_event", false))
		else "PREPARATION RISK  ·  Open the workshop and resolve availability before this event"
	)
	footer.add_child(readiness)
	if bay == assigned_bay:
		var prep_button := Button.new()
		prep_button.name = "Prepare_%d" % bay
		prep_button.custom_minimum_size.x = 210.0
		var prep_quote := GameManager.team.get_workshop_job_quote(car, "race_preparation", "", race, false)
		var prep_schedule := GameManager.team.get_workshop_job_schedule(car, prep_quote)
		var setup_complete := car.get_preparation_score(race) >= 100
		var setup_queued := car.has_pending_workshop_job("race_preparation", "", race.race_id)
		if setup_complete:
			prep_button.text = "EVENT SETUP COMPLETE"
		elif setup_queued:
			prep_button.text = "EVENT SETUP QUEUED"
		else:
			prep_button.text = "QUEUE SETUP  ·  $%s / %dD" % [String.num_int64(int(prep_quote.get("cost", 0))), int(prep_quote.get("duration", 0))]
		prep_button.disabled = setup_complete or setup_queued or not car.is_initial_preparation_complete() or GameManager.team.money < int(prep_quote.get("cost", 0)) or int(prep_schedule.get("completion_day", race.schedule_day + 1)) > race.schedule_day
		prep_button.pressed.connect(_queue_setup.bind(car, race))
		footer.add_child(prep_button)
	parent.add_child(row)


func _assign_car(race: Race, race_team: RaceTeam, bay: int) -> void:
	if race_team == null:
		return
	var quote := GameManager.team.get_assignment_change_quote(race, race_team, bay)
	if GameManager.team.assign_car_to_race(race, race_team, bay):
		GameManager.save_game()
		var detail := " Late-change fee: $%s." % String.num_int64(int(quote.get("cost", 0))) if bool(quote.get("late_change", false)) else ""
		var lost_setup := " The previous car's event setup work was discarded." if bool(quote.get("loses_setup_work", false)) else ""
		refresh("%s assigned to %s.%s%s" % [GameManager.team.get_car(bay).name, race.race_name, detail, lost_setup])
	else:
		status_label.text = "That assignment could not be committed. Check car eligibility, cash, and other team plans."


func _queue_setup(car: Car, race: Race) -> void:
	if GameManager.team.queue_workshop_job(car, "race_preparation", "", race):
		GameManager.save_game()
		refresh("%s's %s setup has been added to the workshop calendar." % [car.name, race.race_name])
	else:
		status_label.text = "The setup could not be queued. Check cash, workshop capacity, and existing work."


func _on_team_selected(_index: int) -> void:
	refresh("Showing the selected race team's campaign plan.")


func _clear_events() -> void:
	for child in event_container.get_children():
		event_container.remove_child(child)
		child.queue_free()


func _add_note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _open_workshop() -> void:
	GameManager.load_page("res://scenes/pages/garage/fleet_workshop.tscn")


func _return_to_garage() -> void:
	GameManager.load_page("res://scenes/pages/garage/garage.tscn")
