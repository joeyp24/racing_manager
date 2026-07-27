extends Control

@onready var page_container: Control = %page_container


func _ready() -> void:
	%home_button.pressed.connect(_on_home_button_pressed)
	%garage_button.pressed.connect(_on_garage_button_pressed)

	load_page("res://scenes/pages/dashboard/dashboard.tscn")


func load_page(scene_path: String) -> void:
	for child in page_container.get_children():
		child.queue_free()

	var packed_scene: PackedScene = load(scene_path)
	var page: Control = packed_scene.instantiate()

	page_container.add_child(page)


func _on_home_button_pressed() -> void:
	load_page("res://scenes/pages/dashboard/dashboard.tscn")


func _on_garage_button_pressed() -> void:
	load_page("res://scenes/pages/garage/garage.tscn")
