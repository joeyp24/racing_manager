extends Control

@onready var page_container: Control = %page_container
@onready var home_button: Button = %home_button
@onready var garage_button: Button = %garage_button
@onready var drivers_button: Button = %drivers_button
@onready var race_teams_button: Button = %race_teams_button
@onready var championship_button: Button = %championship_button
@onready var staff_button: Button = %staff_button
@onready var finances_button: Button = %finances_button
@onready var race_calendar_button: Button = %race_calendar_button
@onready var shop_button: Button = %shop_button
@onready var dealership_button: Button = %dealership_button
@onready var sponsors_button: Button = %sponsors_button
@onready var hq_button: Button = %hq_button
@onready var scouting_button: Button = %scouting_button
@onready var identity_button: Button = %identity_button
@onready var glossary_button: Button = %glossary_button
@onready var money_label: Label = %money_label
@onready var rep_label: Label = %rep_label
@onready var position_label: Label = %position_label
@onready var next_event_label: Label = %next_event_label
@onready var team_name_label: Label = %team_name_label
@onready var season_label: Label = %season_label
@onready var fullscreen_button: Button = %fullscreen_button
@onready var settings_dialog: ConfirmationDialog = %settings_dialog
@onready var reset_confirmation: ConfirmationDialog = %reset_confirmation
@onready var command_bar: CommandBar = %CommandBar

var navigation_buttons: Array[Button] = []


func _ready() -> void:
	GameManager.page_container = page_container
	navigation_buttons = [home_button, race_calendar_button, championship_button,
		garage_button, race_teams_button, drivers_button, staff_button, shop_button,
		dealership_button, sponsors_button, finances_button, hq_button, identity_button,
		scouting_button]

	home_button.pressed.connect(
		_on_home_button_pressed
	)

	garage_button.pressed.connect(
		_on_garage_button_pressed
	)

	drivers_button.pressed.connect(
		_on_drivers_button_pressed
	)
	race_teams_button.pressed.connect(_on_race_teams_button_pressed)

	championship_button.pressed.connect(
		_on_championship_button_pressed
	)
	staff_button.pressed.connect(_on_staff_button_pressed)
	finances_button.pressed.connect(_on_finances_button_pressed)

	race_calendar_button.pressed.connect(
		_on_race_calendar_button_pressed
	)

	shop_button.pressed.connect(_on_shop_button_pressed)
	dealership_button.pressed.connect(_on_dealership_button_pressed)
	sponsors_button.pressed.connect(_on_sponsors_button_pressed)
	hq_button.pressed.connect(_on_hq_button_pressed)
	identity_button.pressed.connect(_on_identity_button_pressed)
	glossary_button.pressed.connect(_on_glossary_button_pressed)
	scouting_button.pressed.connect(_on_scouting_button_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	_make_top_bar_actionable()
	command_bar.action_requested.connect(_on_command_action_requested)
	GameManager.page_changed.connect(_on_page_changed)
	GameManager.fullscreen_changed.connect(_update_fullscreen_button)
	_update_fullscreen_button(GameManager.is_fullscreen())

	if not GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.connect(
			_on_team_money_changed
		)
	if GameManager.team != null and not GameManager.team.changed.is_connected(update_team_display):
		GameManager.team.changed.connect(update_team_display)

	update_team_display()
	update_unlocked_navigation()

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)
	set_active_navigation(home_button)

	if (
		GameManager.team != null
		and not GameManager.team.driver_hired_for_season
	):
		GameManager.load_page(
			"res://scenes/pages/drivers/drivers.tscn"
		)
		set_active_navigation(drivers_button)


func _exit_tree() -> void:
	if GameManager.fullscreen_changed.is_connected(_update_fullscreen_button):
		GameManager.fullscreen_changed.disconnect(_update_fullscreen_button)
	if GameManager.page_changed.is_connected(_on_page_changed):
		GameManager.page_changed.disconnect(_on_page_changed)
	if GameManager.team_money_changed.is_connected(
		_on_team_money_changed
	):
		GameManager.team_money_changed.disconnect(
			_on_team_money_changed
		)
	if GameManager.team != null and GameManager.team.changed.is_connected(update_team_display):
		GameManager.team.changed.disconnect(update_team_display)


func _on_fullscreen_button_pressed() -> void:
	GameManager.toggle_fullscreen()


func _on_settings_pressed() -> void:
	settings_dialog.popup_centered(Vector2i(420, 250))


func _on_reset_requested() -> void:
	settings_dialog.hide()
	reset_confirmation.popup_centered(Vector2i(460, 190))


func _make_top_bar_actionable() -> void:
	var actions := {
		%money_label.get_parent(): _on_finances_button_pressed,
		%position_label.get_parent(): _on_championship_button_pressed,
		%next_event_label.get_parent(): _on_race_calendar_button_pressed,
	}
	for box: Control in actions:
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.tooltip_text = "Open details"
		box.gui_input.connect(_on_status_box_input.bind(actions[box]))


func _on_status_box_input(event: InputEvent, action: Callable) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		action.call()


func _update_fullscreen_button(is_now_fullscreen: bool) -> void:
	if is_now_fullscreen:
		fullscreen_button.text = "  ⛶  Exit Full Screen (F11)"
	else:
		fullscreen_button.text = "  ⛶  Full Screen (F11)"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.save_game()
		get_tree().quit()


func _on_home_button_pressed() -> void:
	set_active_navigation(home_button)
	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)


func _on_garage_button_pressed() -> void:
	set_active_navigation(garage_button)
	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)


func _on_drivers_button_pressed() -> void:
	set_active_navigation(drivers_button)
	GameManager.load_page(
		"res://scenes/pages/drivers/drivers.tscn"
	)


func _on_race_teams_button_pressed() -> void:
	set_active_navigation(race_teams_button)
	GameManager.load_page("res://scenes/pages/race_teams/race_teams.tscn")


func _on_championship_button_pressed() -> void:
	set_active_navigation(championship_button)
	GameManager.load_page(
		"res://scenes/pages/championship/championship.tscn"
	)


func _on_staff_button_pressed() -> void:
	set_active_navigation(staff_button)
	GameManager.load_page("res://scenes/pages/staff/staff.tscn")


func _on_finances_button_pressed() -> void:
	set_active_navigation(finances_button)
	GameManager.load_page("res://scenes/pages/finances/finances.tscn")


func _on_race_calendar_button_pressed() -> void:
	set_active_navigation(race_calendar_button)
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/race_calendar/race_calendar.tscn"
	)


func _on_shop_button_pressed() -> void:
	set_active_navigation(shop_button)
	GameManager.load_page("res://scenes/pages/shop/shop.tscn")


func _on_dealership_button_pressed() -> void:
	set_active_navigation(dealership_button)
	GameManager.selected_car = null
	GameManager.selected_bay = -1
	GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")


func _on_sponsors_button_pressed() -> void:
	set_active_navigation(sponsors_button)
	GameManager.load_page("res://scenes/pages/sponsors/sponsors.tscn")


func _on_hq_button_pressed() -> void:
	set_active_navigation(hq_button)
	GameManager.load_page("res://scenes/pages/departments/departments.tscn")


func _on_identity_button_pressed() -> void:
	set_active_navigation(identity_button)
	GameManager.load_page("res://scenes/pages/team_identity/team_identity.tscn")


func _on_glossary_button_pressed() -> void:
	set_active_navigation(null)
	GameManager.load_page("res://scenes/pages/glossary/glossary.tscn")


func _on_scouting_button_pressed() -> void:
	if scouting_button.disabled:
		return
	set_active_navigation(scouting_button)
	GameManager.load_page("res://scenes/pages/scouting/scouting.tscn")


func update_unlocked_navigation() -> void:
	var unlocked := GameManager.team != null and GameManager.team.get_department_level("scouting") > 0
	scouting_button.disabled = not unlocked
	scouting_button.text = "⌕   Scouting" if unlocked else "⌕   Scouting  ·  LOCKED"
	scouting_button.tooltip_text = "Build the Scouting department at HQ to unlock." if not unlocked else "Find emerging driver talent."


func _on_reset_game_button_pressed() -> void:
	GameManager.reset_game()


func _on_team_money_changed(
	new_amount: int
) -> void:
	update_money_label(new_amount)


func update_team_display() -> void:
	if GameManager.team == null:
		money_label.text = "$0"
		command_bar.display(NextActionModel.derive(null))
		return

	var team: Team = GameManager.team
	update_money_label(team.money)
	team_name_label.text = team.team_name.to_upper()
	season_label.text = "SEASON %d • TEAM HQ" % team.season_number
	rep_label.text = "%d PTS" % team.reputation
	next_event_label.text = get_next_event_name(team)
	position_label.text = get_championship_position(team)
	command_bar.display(NextActionModel.derive(team))
	update_unlocked_navigation()


func _on_command_action_requested(action: String) -> void:
	var paths := {
		"dashboard": "res://scenes/pages/dashboard/dashboard.tscn",
		"calendar": "res://scenes/pages/race_calendar/race_calendar.tscn",
		"championship": "res://scenes/pages/championship/championship.tscn",
		"drivers": "res://scenes/pages/drivers/drivers.tscn",
		"garage": "res://scenes/pages/garage/garage.tscn",
		"dealership": "res://scenes/pages/dealership/dealership.tscn",
		"staff": "res://scenes/pages/staff/staff.tscn",
		"finances": "res://scenes/pages/finances/finances.tscn",
		"sponsors": "res://scenes/pages/sponsors/sponsors.tscn",
		"race_entry": "res://scenes/pages/race_entry/race_entry.tscn",
	}
	if not paths.has(action):
		return
	if action == "race_entry":
		GameManager.selected_race = RaceManager.get_next_race(GameManager.team)
	GameManager.load_page(str(paths[action]))


func _on_page_changed(scene_path: String) -> void:
	var destinations := {
		"dashboard": home_button, "race_calendar": race_calendar_button,
		"race_entry": race_calendar_button, "race_weekend": race_calendar_button,
		"live_race": race_calendar_button, "race_results": race_calendar_button,
		"championship": championship_button, "garage": garage_button,
		"drivers": drivers_button, "race_teams": race_teams_button,
		"staff": staff_button, "finances": finances_button, "shop": shop_button,
		"dealership": shop_button, "sponsors": sponsors_button,
		"departments": hq_button, "team_identity": identity_button,
		"scouting": scouting_button,
	}
	var page_id := scene_path.get_file().get_basename()
	set_active_navigation(destinations.get(page_id, null) as Button)
	command_bar.display(NextActionModel.derive(GameManager.team, scene_path))


func update_money_label(amount: int) -> void:
	money_label.text = (
		"$%s"
		% format_number(amount)
	)


func set_active_navigation(active_button: Button) -> void:
	for button in navigation_buttons:
		button.set_pressed_no_signal(button == active_button)


func get_next_event_name(team: Team) -> String:
	if team.season_complete:
		return "Season complete"
	if team.unlocked_races.is_empty():
		return "No event scheduled"
	return str(team.unlocked_races.back()).capitalize().replace("_", " ")


func get_championship_position(team: Team) -> String:
	var standings := team.get_sorted_championship_standings()
	for index in range(standings.size()):
		if bool(standings[index].get("is_player", false)):
			return "P%d • %d PTS" % [index + 1, int(standings[index].get("points", 0))]
	return "NOT RANKED"


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""

	while number_string.length() > 3:
		formatted_number = (
			","
			+ number_string.right(3)
			+ formatted_number
		)

		number_string = number_string.left(
			number_string.length() - 3
		)

	return number_string + formatted_number
