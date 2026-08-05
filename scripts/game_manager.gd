extends Node

const CAREER_EXPANSION_MANAGER_PATH: String = "res://resources/career_expansion_manager.gd"

signal team_money_changed(new_amount: int)
signal team_loaded(team: Team)
signal fullscreen_changed(is_now_fullscreen: bool)
signal page_changed(scene_path: String)

var team: Team = null
var active_save_id: String = ""
var selected_car: Car = null
var selected_bay: int = -1
var selected_race: Race = null
var page_container: Control = null
var active_race_weekend: Dictionary = {}


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


func reload_current_page() -> void:
	if page_container != null:
		load_page("res://scenes/pages/dashboard/dashboard.tscn")


func load_page(scene_path: String) -> void:
	if page_container == null:
		push_error("GameManager.page_container has not been assigned.")
		return
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
