extends Control

@onready var page_container: Control = %page_container
@onready var garage_button: Button = %garage_button
@onready var money_label: Label = %money_label


func _ready() -> void:
	GameManager.page_container = page_container

	garage_button.pressed.connect(_on_garage_button_pressed)

	GameManager.team.changed.connect(_on_team_changed)

	update_team_display()

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.save_game()
		get_tree().quit()


func _on_garage_button_pressed() -> void:
	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)


func _on_team_changed() -> void:
	update_team_display()


func update_team_display() -> void:
	money_label.text = "Money: $%s" % String.num_int64(
		GameManager.team.money
	)
