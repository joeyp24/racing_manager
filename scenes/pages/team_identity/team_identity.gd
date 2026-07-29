extends Control

@onready var name_edit: LineEdit = %name_edit
@onready var hometown_edit: LineEdit = %hometown_edit
@onready var motto_edit: LineEdit = %motto_edit
@onready var badge_option: OptionButton = %badge_option
@onready var primary_picker: ColorPickerButton = %primary_picker
@onready var secondary_picker: ColorPickerButton = %secondary_picker
@onready var preview_panel: PanelContainer = %preview_panel
@onready var preview_name: Label = %preview_name
@onready var status_label: Label = %status_label


func _ready() -> void:
	var team := GameManager.team
	if team == null:
		return
	for badge in ["Diamond", "Shield", "Bolt", "Flag"]:
		badge_option.add_item(badge)
	name_edit.text = team.team_name
	hometown_edit.text = team.hometown
	motto_edit.text = team.team_motto
	for index in range(badge_option.item_count):
		if badge_option.get_item_text(index) == team.team_badge:
			badge_option.select(index)
			break
	primary_picker.color = team.primary_color
	secondary_picker.color = team.secondary_color
	update_preview()
	name_edit.text_changed.connect(func(_value: String) -> void: update_preview())
	primary_picker.color_changed.connect(func(_value: Color) -> void: update_preview())


func update_preview() -> void:
	preview_name.text = "%s  %s" % [get_badge_symbol(badge_option.get_item_text(badge_option.selected)), name_edit.text.to_upper()]
	preview_name.modulate = primary_picker.color
	var style := StyleBoxFlat.new()
	style.bg_color = secondary_picker.color
	style.border_color = primary_picker.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	preview_panel.add_theme_stylebox_override("panel", style)


func _on_save_pressed() -> void:
	var chosen_name := name_edit.text.strip_edges()
	if chosen_name.length() < 2:
		status_label.text = "Team name must contain at least two characters."
		return
	var team := GameManager.team
	var previous_name := team.team_name
	team.team_name = chosen_name.left(32)
	team.hometown = hometown_edit.text.strip_edges().left(40)
	team.team_motto = motto_edit.text.strip_edges().left(64)
	team.team_badge = badge_option.get_item_text(badge_option.selected)
	team.primary_color = primary_picker.color
	team.secondary_color = secondary_picker.color
	team.accent_color = primary_picker.color.lerp(Color.WHITE, 0.8)
	for driver in team.drivers:
		if driver != null and (driver.is_player_driver or driver.team_name == previous_name):
			driver.team_name = team.team_name
	team.emit_changed()
	if GameManager.save_game():
		status_label.text = "Team identity saved to this career."
	update_preview()


func _on_badge_selected(_index: int) -> void:
	update_preview()


func get_badge_symbol(badge: String) -> String:
	match badge:
		"Shield": return "⬟"
		"Bolt": return "ϟ"
		"Flag": return "⚑"
		_: return "◆"
