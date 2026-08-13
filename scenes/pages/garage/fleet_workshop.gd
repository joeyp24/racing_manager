extends Control

@onready var calendar_label: Label = %calendar_label
@onready var fleet_container: VBoxContainer = %fleet_container
@onready var status_label: Label = %status_label
@onready var back_button: Button = %back_button

var next_race: Race = null


func _ready() -> void:
	back_button.pressed.connect(_return_to_garage)
	next_race = RaceManager.get_next_race(GameManager.team)
	refresh()


func refresh() -> void:
	_clear(fleet_container)
	var team := GameManager.team
	if team == null:
		return
	var next_event := "No scheduled event" if next_race == null else "%s on %s" % [next_race.race_name, CalendarCatalog.format_day(next_race.schedule_day)]
	calendar_label.text = "%s  ·  Today %s  ·  %d workshop slot%s  ·  $%s weekly fleet upkeep" % [
		next_event,
		CalendarCatalog.format_day(team.current_season_day),
		team.get_workshop_slot_count(),
		"" if team.get_workshop_slot_count() == 1 else "s",
		String.num_int64(team.get_fleet_weekly_upkeep()),
	]
	for bay in team.cars.size():
		var car := team.get_car(bay)
		if car != null:
			_add_car_lane(car, bay)
	if team.get_owned_car_count() == 0:
		_add_note(fleet_container, "No cars are owned. Purchase a car before planning workshop work.")


func _add_car_lane(car: Car, bay: int) -> void:
	car.ensure_workshop_state()
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	var heading := Label.new()
	heading.theme_type_variation = &"SectionTitle"
	heading.text = "BAY %d  ·  %s  ·  %s" % [bay + 1, car.name, SeriesCatalog.get_series(car.series_id).get("name", car.series_id)]
	stack.add_child(heading)
	var state := Label.new()
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.text = _car_state_text(car)
	stack.add_child(state)
	var timeline := Label.new()
	timeline.theme_type_variation = &"MutedLabel"
	timeline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeline.text = _timeline_text(car)
	stack.add_child(timeline)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	stack.add_child(actions)
	_add_preparation_actions(actions, car)
	_add_damage_actions(actions, car)
	if car.workshop_jobs.is_empty() and car.is_initial_preparation_complete() and car.condition >= 100 and car.get_damage_points() <= 0.5 and (next_race == null or car.get_preparation_score(next_race) >= 100):
		_add_note(actions, "No workshop intervention is currently recommended.")
	fleet_container.add_child(card)


func _car_state_text(car: Car) -> String:
	var availability := "AVAILABLE TODAY" if car.is_race_available(GameManager.team.current_season_day) else "UNAVAILABLE"
	var prep := "No upcoming event"
	if next_race != null and car.series_id == next_race.series_id:
		prep = "%d/100 preparation for %s" % [car.get_preparation_score(next_race), next_race.track_type]
	return "%s  ·  Condition %d%%  ·  %s  ·  Scrutineering risk %d%%\n%s" % [
		availability, car.condition, car.get_damage_summary(), roundi(car.get_scrutineering_risk() * 100.0), prep
	]


func _timeline_text(car: Car) -> String:
	if car.workshop_jobs.is_empty():
		return "WORKSHOP LANE  ·  No scheduled work"
	var lines: Array[String] = ["WORKSHOP LANE"]
	var jobs := car.workshop_jobs.duplicate()
	jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("start_day", 0)) < int(b.get("start_day", 0)))
	for job in jobs:
		lines.append("Slot %d  ·  %s–%s  ·  %s%s" % [
			int(job.get("slot", 0)) + 1,
			CalendarCatalog.format_day(int(job.get("start_day", GameManager.team.current_season_day))),
			CalendarCatalog.format_day(int(job.get("completion_day", GameManager.team.current_season_day))),
			str(job.get("label", "Workshop job")),
			"  ·  RUSHED" if bool(job.get("rushed", false)) else "",
		])
	return "\n".join(lines)


func _add_preparation_actions(parent: VBoxContainer, car: Car) -> void:
	if not car.is_initial_preparation_complete():
		if not _has_initial_program(car):
			var row := _action_row(parent, "NEW-CAR PROGRAMME  ·  Inspection, baseline setup and shakedown")
			_add_initial_action(row, car, false, "Queue standard")
			_add_initial_action(row, car, true, "Rush programme")
		return
	if car.condition < 100 or int(car.workshop_state.get("races_since_service", 0)) > 0:
		var service_row := _action_row(parent, "ROUTINE SERVICE  ·  Restore car and installed-part condition")
		_add_quoted_action(service_row, car, "routine_service", "", null, false, "Queue service")
		_add_quoted_action(service_row, car, "routine_service", "", null, true, "Rush service")
	if next_race != null and car.series_id == next_race.series_id and car.get_preparation_score(next_race) < 100:
		var prep_row := _action_row(parent, "EVENT PREPARATION  ·  Build a track-specific setup for %s" % next_race.race_name)
		_add_quoted_action(prep_row, car, "race_preparation", "", next_race, false, "Standard prep")
		_add_quoted_action(prep_row, car, "race_preparation", "", next_race, true, "Rush prep")


func _add_damage_actions(parent: VBoxContainer, car: Car) -> void:
	for component in Car.DAMAGE_COMPONENTS:
		var health := roundi(car.get_component_health(component))
		if health >= 99:
			continue
		var row := _action_row(parent, "%s  ·  %d%% health" % [Car.DAMAGE_LABELS[component], health])
		_add_quoted_action(row, car, "patch", component, null, false, "Patch to 72%")
		_add_quoted_action(row, car, "rebuild", component, null, false, "Rebuild to 95%")
		_add_quoted_action(row, car, "replacement", component, null, false, "Replace to 100%")


func _action_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	parent.add_child(row)
	return row


func _add_quoted_action(row: HBoxContainer, car: Car, kind: String, component: String, race: Race, rushed: bool, button_label: String) -> void:
	var quote := GameManager.team.get_workshop_job_quote(car, kind, component, race, rushed)
	var schedule := GameManager.team.get_workshop_job_schedule(car, quote)
	var completion_day := int(schedule.get("completion_day", GameManager.team.current_season_day))
	var misses_event := kind == "race_preparation" and race != null and completion_day > race.schedule_day
	var repair_conflict := kind in ["patch", "rebuild", "replacement"] and _has_component_repair(car, component)
	var button := Button.new()
	button.text = "%s  ·  $%s  ·  Ready %s%s" % [
		button_label,
		String.num_int64(int(quote.get("cost", 0))),
		CalendarCatalog.format_day(completion_day),
		"  ·  MISSES EVENT" if misses_event else "",
	]
	button.disabled = (
		quote.is_empty()
		or GameManager.team.money < int(quote.get("cost", 0))
		or car.has_pending_workshop_job(kind, component, race.race_id if race != null else "")
		or repair_conflict
		or misses_event
	)
	button.pressed.connect(_queue_job.bind(car, kind, component, race, rushed))
	row.add_child(button)


func _add_initial_action(row: HBoxContainer, car: Car, rushed: bool, label_text: String) -> void:
	var cost := 0
	var duration := 0
	for kind in ["inspection", "baseline_setup", "shakedown"]:
		var quote := GameManager.team.get_workshop_job_quote(car, kind, "", null, rushed)
		cost += int(quote.get("cost", 0))
		duration += int(quote.get("duration", 0))
	var button := Button.new()
	button.text = "%s  ·  $%s / %d work days" % [label_text, String.num_int64(cost), duration]
	button.disabled = GameManager.team.money < cost
	button.pressed.connect(_queue_initial.bind(car, rushed))
	row.add_child(button)


func _add_action(row: HBoxContainer, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(action)
	row.add_child(button)


func _queue_initial(car: Car, rushed: bool) -> void:
	if GameManager.team.queue_initial_preparation(car, rushed):
		_after_plan_change("%s new-car programme scheduled." % car.name)
	else:
		status_label.text = "The programme could not be scheduled. Check cash and existing work."


func _queue_job(car: Car, kind: String, component: String, race: Race, rushed: bool) -> void:
	if GameManager.team.queue_workshop_job(car, kind, component, race, rushed):
		_after_plan_change("%s scheduled for %s." % [car.name, kind.replace("_", " ")])
	else:
		status_label.text = "The job could not be scheduled. Check cash and workshop state."


func _after_plan_change(message: String) -> void:
	status_label.text = message
	GameManager.refresh_team_money()
	GameManager.save_game()
	refresh()


func _has_initial_program(car: Car) -> bool:
	for job in car.workshop_jobs:
		if str(job.get("kind", "")) in ["inspection", "baseline_setup", "shakedown"]:
			return true
	return false


func _has_component_repair(car: Car, component: String) -> bool:
	for kind in ["patch", "rebuild", "replacement"]:
		if car.has_pending_workshop_job(kind, component):
			return true
	return false


func _add_note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _return_to_garage() -> void:
	GameManager.load_page("res://scenes/pages/garage/garage.tscn")
