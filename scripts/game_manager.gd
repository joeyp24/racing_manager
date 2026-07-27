extends Node

var team: Team
var selected_car = null
var page_container: Control = null


func _ready() -> void:
	load_game()


func new_game() -> void:
	team = Team.new()
	selected_car = null


func save_game() -> void:
	var success = SaveManager.save_game(team)

	if success:
		print("Save completed successfully.")


func load_game() -> void:
	var loaded_team = SaveManager.load_game()

	if loaded_team != null:
		team = loaded_team
	else:
		new_game()


func load_page(scene_path: String) -> void:
	if page_container == null:
		push_error("GameManager.page_container has not been assigned.")
		return

	for child in page_container.get_children():
		child.queue_free()

	var page_scene = load(scene_path)

	if page_scene == null:
		push_error("Could not load page: " + scene_path)
		return

	var page_instance = page_scene.instantiate()
	page_container.add_child(page_instance)
