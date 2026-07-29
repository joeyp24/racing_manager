extends Control

@onready var save_summary: Label = %SaveSummary


func _ready() -> void:
	var team: Team = GameManager.team
	if team != null:
		save_summary.text = "%s  •  Season %d  •  $%s available" % [
			team.team_name,
			team.season_number,
			format_number(team.money)
		]


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")

func _on_new_game_pressed() -> void:
	GameManager.new_game()
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func format_number(number: int) -> String:
	var output := str(number)
	var index := output.length() - 3
	while index > 0:
		output = output.insert(index, ",")
		index -= 3
	return output
