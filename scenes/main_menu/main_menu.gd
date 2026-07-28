extends Control

func _on_new_game_pressed() -> void:
	# Load and switch to the main game dashboard scene
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")

func _on_quit_button_pressed() -> void:
	# Exit the application
	get_tree().quit()
