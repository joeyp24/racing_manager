extends Node

signal team_money_changed(new_amount: int)

var team: Team = null

var selected_car = null
var selected_bay: int = -1
var selected_race: Race = null

var page_container: Control = null


func _ready() -> void:
	load_game()


func new_game() -> void:
	team = Team.new()

	clear_selected_data()
	refresh_team_money()


func save_game() -> void:
	if team == null:
		push_error(
			"Cannot save because no team is loaded."
		)
		return

	var success: bool = SaveManager.save_game(team)

	if success:
		print("Save completed successfully.")


func load_game() -> void:
	var loaded_team: Team = SaveManager.load_game()

	if loaded_team != null:
		team = loaded_team
		team.ensure_default_player_driver()
	else:
		new_game()
		save_game()

	refresh_team_money()


func reset_game() -> void:
	var save_deleted: bool = SaveManager.delete_save()

	if not save_deleted:
		push_error(
			"The game could not be reset because the save "
			+ "file could not be deleted."
		)
		return

	team = Team.new()

	clear_selected_data()

	if RaceManager != null:
		RaceManager.clear_last_result()

	var save_created: bool = SaveManager.save_game(team)

	if not save_created:
		push_error(
			"The game was reset, but the new save file "
			+ "could not be created."
		)

	refresh_team_money()

	print("All save data has been reset.")
	print("Starting money: ", team.money)
	print("Owned cars: ", team.cars.size())
	print("Completed races: ", team.completed_races)
	print("Unlocked races: ", team.unlocked_races)
	print(
		"Championship points: ",
		team.championship_points
	)

	reload_current_page()


func clear_selected_data() -> void:
	selected_car = null
	selected_bay = -1
	selected_race = null


func reload_current_page() -> void:
	if page_container == null:
		return

	load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)


func load_page(scene_path: String) -> void:
	if page_container == null:
		push_error(
			"GameManager.page_container has not been assigned."
		)
		return

	for child in page_container.get_children():
		child.queue_free()

	var page_scene: PackedScene = load(scene_path)

	if page_scene == null:
		push_error(
			"Could not load page: %s"
			% scene_path
		)
		return

	var page_instance: Node = page_scene.instantiate()
	page_container.add_child(page_instance)


func add_team_money(amount: int) -> void:
	if team == null:
		push_error(
			"Cannot add money because no team is loaded."
		)
		return

	if amount < 0:
		push_error(
			"Money addition amount cannot be negative."
		)
		return

	team.money += amount
	team.emit_changed()

	refresh_team_money()


func remove_team_money(amount: int) -> bool:
	if team == null:
		push_error(
			"Cannot remove money because no team is loaded."
		)
		return false

	if amount < 0:
		push_error(
			"Money removal amount cannot be negative."
		)
		return false

	if team.money < amount:
		return false

	team.money -= amount
	team.emit_changed()

	refresh_team_money()

	return true


func refresh_team_money() -> void:
	if team == null:
		return

	team_money_changed.emit(team.money)
