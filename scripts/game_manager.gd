extends Node

const CAREER_EXPANSION_MANAGER_PATH: String = "res://resources/career_expansion_manager.gd"

signal team_money_changed(new_amount: int)
signal team_loaded(team: Team)
signal fullscreen_changed(is_now_fullscreen: bool)
signal page_changed(scene_path: String)
signal race_weekend_lock_changed(locked: bool)
signal decision_outcome_reported(outcome: Dictionary)

var team: Team = null
var active_save_id: String = ""
var selected_car: Car = null
var selected_bay: int = -1
var selected_race: Race = null
var page_container: Control = null
var active_race_weekend: Dictionary = {}
var pending_decision_outcome: Dictionary = {}


func _ready() -> void:
	SaveManager.migrate_legacy_save()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_changed.emit(is_fullscreen())


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _call_career_expansion_manager(method: StringName, arguments: Array) -> Variant:
	var manager_script: Script = load(CAREER_EXPANSION_MANAGER_PATH) as Script
	if manager_script == null:
		push_error("Could not load the career expansion manager.")
		return null
	return manager_script.callv(method, arguments)


func new_game(slot_id: String = "") -> void:
	team = Team.new()
	_call_career_expansion_manager(&"apply_accessibility", [team])
	active_save_id = slot_id if not slot_id.is_empty() else SaveManager.make_slot_id(team.team_name)
	clear_selected_data()
	refresh_team_money()
	team_loaded.emit(team)


func save_game() -> bool:
	if team == null:
		push_error("Cannot save because no team is loaded.")
		return false
	if active_save_id.is_empty():
		active_save_id = SaveManager.make_slot_id(team.team_name)
	if is_race_weekend_locked():
		if selected_race != null and team.get_completed_races().has(selected_race.race_id):
			finish_race_weekend()
		else:
			var saved_weekend := active_race_weekend.duplicate(true)
			saved_weekend["race_id"] = selected_race.race_id if selected_race != null else ""
			saved_weekend["selected_car_bay"] = _find_selected_car_bay()
			team.active_race_weekend_state = saved_weekend
	return SaveManager.save_game(team, active_save_id)


func load_game(slot_id: String) -> bool:
	var loaded_team := SaveManager.load_game(slot_id)
	if loaded_team == null:
		return false
	team = loaded_team
	active_save_id = slot_id
	team.ensure_departments()
	team.ensure_scouting_hours()
	team.ensure_race_week_progression()
	team.ensure_default_player_driver()
	team.ensure_driver_market()
	team.ensure_series_rosters()
	team.ensure_world_series_data()
	team.ensure_ai_team_career()
	team.ensure_ai_driver_career()
	team.ensure_car_parts()
	team.ensure_staff_market()
	team.ensure_race_teams()
	_call_career_expansion_manager(&"ensure_state", [team])
	_call_career_expansion_manager(&"apply_accessibility", [team])
	clear_selected_data()
	_restore_active_race_weekend()
	refresh_team_money()
	team_loaded.emit(team)
	return true


func delete_game(slot_id: String) -> bool:
	var success := SaveManager.delete_save(slot_id)
	if success and slot_id == active_save_id:
		team = null
		active_save_id = ""
		clear_selected_data()
	return success


func reset_game() -> void:
	if active_save_id.is_empty():
		return
	team = Team.new()
	clear_selected_data()
	if RaceManager != null:
		RaceManager.clear_last_result()
	save_game()
	refresh_team_money()
	reload_current_page()


func clear_selected_data() -> void:
	selected_car = null
	selected_bay = -1
	selected_race = null
	active_race_weekend.clear()
	pending_decision_outcome.clear()
	race_weekend_lock_changed.emit(false)


func reload_current_page() -> void:
	if page_container != null:
		load_page("res://scenes/pages/dashboard/dashboard.tscn")


func load_page(scene_path: String) -> void:
	if page_container == null:
		push_error("GameManager.page_container has not been assigned.")
		return
	var requested_path := scene_path
	if is_race_weekend_locked():
		var required_path := get_active_race_weekend_path()
		if scene_path != required_path:
			scene_path = required_path
			push_warning("Navigation to %s was blocked during a committed race weekend." % requested_path)
	elif team != null and not FirstHourExperience.is_complete(team) and not is_first_hour_page_allowed(scene_path):
		scene_path = "res://scenes/pages/dashboard/dashboard.tscn"
		push_warning("Navigation to %s is unlocked after the guided opening." % requested_path)
	var page_scene: PackedScene = load(scene_path)
	if page_scene == null:
		push_error("Could not load page: %s" % scene_path)
		return
	var page_instance := page_scene.instantiate()
	for child in page_container.get_children():
		page_container.remove_child(child)
		child.queue_free()
	page_container.add_child(page_instance)
	if page_instance is Control:
		var page_control := page_instance as Control
		page_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var accessibility: Dictionary = {}
		if team != null:
			accessibility = team.career_state.get("accessibility", {}) as Dictionary
		var reduced_motion := bool(accessibility.get("reduced_motion", false))
		if not reduced_motion:
			page_control.modulate.a = 0.0
			page_container.mouse_filter = Control.MOUSE_FILTER_STOP
			var tween := page_control.create_tween()
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(page_control, "modulate:a", 1.0, 0.14)
			tween.finished.connect(func() -> void: page_container.mouse_filter = Control.MOUSE_FILTER_PASS)
	page_changed.emit(scene_path)


func begin_race_weekend(data: Dictionary) -> void:
	active_race_weekend = data.duplicate(true)
	active_race_weekend["entry_fee_paid"] = true
	active_race_weekend["flow_stage"] = "race_weekend"
	race_weekend_lock_changed.emit(true)


func set_race_weekend_stage(stage: String) -> void:
	if active_race_weekend.is_empty():
		return
	active_race_weekend["flow_stage"] = stage
	race_weekend_lock_changed.emit(true)


func finish_race_weekend() -> void:
	active_race_weekend.clear()
	if team != null:
		team.active_race_weekend_state.clear()
	race_weekend_lock_changed.emit(false)


func is_race_weekend_locked() -> bool:
	return (
		not active_race_weekend.is_empty()
		and bool(active_race_weekend.get("entry_fee_paid", false))
	)


func get_active_race_weekend_path() -> String:
	if str(active_race_weekend.get("flow_stage", "race_weekend")) == "live_race":
		return "res://scenes/pages/live_race/live_race.tscn"
	return "res://scenes/pages/race_weekend/race_weekend.tscn"


func is_first_hour_page_allowed(scene_path: String) -> bool:
	return scene_path.get_file().get_basename() in [
		"dashboard",
		"driver_market",
		"dealership",
		"garage",
		"car_inspection",
		"sponsors",
		"race_calendar",
		"race_entry",
		"race_weekend",
		"live_race",
		"race_results",
		"shop",
		"glossary",
	]


func _find_selected_car_bay() -> int:
	if team == null or selected_car == null:
		return -1
	for index in range(team.cars.size()):
		if team.cars[index] == selected_car:
			return index
	return -1


func _restore_active_race_weekend() -> void:
	if team == null or team.active_race_weekend_state.is_empty():
		return
	var restored := team.active_race_weekend_state.duplicate(true)
	if not bool(restored.get("entry_fee_paid", false)):
		team.active_race_weekend_state.clear()
		return
	selected_race = RaceManager.get_race_for_series_by_id(team.current_series_id, str(restored.get("race_id", "")))
	var bay := int(restored.get("selected_car_bay", -1))
	selected_car = team.get_car(bay)
	if selected_race == null or selected_car == null:
		push_error("A saved race weekend could not restore its race or car.")
		team.active_race_weekend_state.clear()
		return
	active_race_weekend = restored
	race_weekend_lock_changed.emit(true)


func add_team_money(amount: int) -> void:
	if team == null or amount < 0:
		push_error("Cannot add an invalid amount of money.")
		return
	team.money += amount
	team.emit_changed()
	refresh_team_money()


func remove_team_money(amount: int) -> bool:
	if team == null or amount < 0 or team.money < amount:
		return false
	team.money -= amount
	team.emit_changed()
	refresh_team_money()
	return true


func charge_team_money(amount: int) -> void:
	if team == null or amount < 0:
		push_error("Cannot charge an invalid team expense.")
		return
	team.money -= amount
	team.emit_changed()
	refresh_team_money()


func refresh_team_money() -> void:
	if team != null:
		team_money_changed.emit(team.money)


func report_decision_outcome(specification: Dictionary) -> Dictionary:
	var outcome := DecisionOutcomeModel.build(team, specification)
	pending_decision_outcome = outcome.duplicate(true)
	refresh_team_money()
	decision_outcome_reported.emit(outcome.duplicate(true))
	return outcome


func consume_decision_outcome() -> Dictionary:
	var outcome := pending_decision_outcome.duplicate(true)
	pending_decision_outcome.clear()
	return outcome
