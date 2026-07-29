extends Control

@onready var saves_list: VBoxContainer = %saves_list
@onready var empty_state: Label = %empty_state
@onready var load_button: Button = %load_button
@onready var delete_button: Button = %delete_button

var selected_slot_id: String = ""
var slot_buttons: Array[Button] = []


func _ready() -> void:
	refresh_saves()


func refresh_saves() -> void:
	for child in saves_list.get_children():
		child.queue_free()
	slot_buttons.clear()
	selected_slot_id = ""
	var slots := SaveManager.get_save_slots()
	empty_state.visible = slots.is_empty()
	load_button.disabled = true
	delete_button.disabled = true
	for slot in slots:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size.y = 62
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "  %s\n  Season %d  •  $%s  •  %s" % [
			str(slot.team_name), int(slot.season), format_number(int(slot.money)),
			format_saved_time(int(slot.saved_at))
		]
		button.modulate = slot.get("primary_color", Color.WHITE)
		button.pressed.connect(_on_slot_selected.bind(str(slot.slot_id), button))
		saves_list.add_child(button)
		slot_buttons.append(button)
	if not slots.is_empty():
		_on_slot_selected(str(slots[0].slot_id), slot_buttons[0])


func _on_slot_selected(slot_id: String, selected_button: Button) -> void:
	selected_slot_id = slot_id
	for button in slot_buttons:
		button.set_pressed_no_signal(button == selected_button)
	load_button.disabled = false
	delete_button.disabled = false


func _on_load_pressed() -> void:
	if not selected_slot_id.is_empty() and GameManager.load_game(selected_slot_id):
		var destination := "res://scenes/home/home.tscn"
		if not GameManager.team.tutorial_completed:
			destination = "res://scenes/onboarding/onboarding.tscn"
		get_tree().change_scene_to_file(destination)


func _on_new_game_pressed() -> void:
	GameManager.new_game()
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding.tscn")


func _on_delete_pressed() -> void:
	if selected_slot_id.is_empty():
		return
	GameManager.delete_game(selected_slot_id)
	refresh_saves()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func format_saved_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "Earlier save"
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d UTC" % [date.year, date.month, date.day, date.hour, date.minute]


func format_number(number: int) -> String:
	var output := str(number)
	var index := output.length() - 3
	while index > 0:
		output = output.insert(index, ",")
		index -= 3
	return output
