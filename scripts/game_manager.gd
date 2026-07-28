extends Node

signal team_money_changed(new_amount: int)

var team: Team
var selected_car = null
var selected_bay: int = -1
var page_container: Control = null
var selected_race: Race = null


func _ready() -> void:
	load_game()


func new_game() -> void:
	team = Team.new()
	selected_car = null
	selected_bay = -1
	selected_race = null

	refresh_team_money()


func save_game() -> void:
	if team == null:
		push_error("Cannot save because no team is loaded.")
		return

	var success: bool = SaveManager.save_game(team)

	if success:
		print("Save completed successfully.")


func load_game() -> void:
	var loaded_team: Team = SaveManager.load_game()

	if loaded_team != null:
		team = loaded_team
	else:
		new_game()

	refresh_team_money()


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

	team.money += amount
	team_money_changed.emit(team.money)


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
	team_money_changed.emit(team.money)

	return true


func refresh_team_money() -> void:
	if team == null:
		return

	team_money_changed.emit(team.money)
	

func reset_season() -> void:
	if team == null:
		return

	team.completed_races.clear()
	team.unlocked_races.clear()

	team.unlocked_races.append("spring_100")

	team.championship_points = 0

	team.emit_changed()

	save_game()
	print("Completed: ", team.completed_races)
	print("Unlocked: ", team.unlocked_races)
	print("Points: ", team.championship_points)
