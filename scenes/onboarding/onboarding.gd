extends Control

@onready var step_label: Label = %step_label
@onready var title_label: Label = %title_label
@onready var body_label: Label = %body_label
@onready var setup_form: VBoxContainer = %setup_form
@onready var name_edit: LineEdit = %name_edit
@onready var hometown_edit: LineEdit = %hometown_edit
@onready var motto_edit: LineEdit = %motto_edit
@onready var badge_option: OptionButton = %badge_option
@onready var primary_picker: ColorPickerButton = %primary_picker
@onready var secondary_picker: ColorPickerButton = %secondary_picker
@onready var back_button: Button = %back_button
@onready var next_button: Button = %next_button

var current_step: int = 0
var steps: Array[Dictionary] = [
	{"title": "Create your team", "body": "Choose the identity that will follow your team through every season. You can change it later from Team Identity at headquarters."},
	{"title": "Run race operations", "body": "Your dashboard shows race readiness. Hire a driver, buy a car, then use Race Calendar to enter an unlocked event. Every purchase and race result is saved to this career."},
	{"title": "Build for the championship", "body": "Upgrade headquarters, recruit staff, develop parts, and sign sponsors. Finances matter: entry fees, repairs, and payroll continue throughout the season."},
	{"title": "Your pit wall is ready", "body": "Start with Drivers to sign your first racer, then visit the Dealership. You can revisit Team Identity from the left navigation whenever you want."}
]


func _ready() -> void:
	if GameManager.team == null:
		GameManager.new_game()
	for badge in ["Diamond", "Shield", "Bolt", "Flag"]:
		badge_option.add_item(badge)
	name_edit.text = GameManager.team.team_name
	hometown_edit.text = GameManager.team.hometown
	motto_edit.text = GameManager.team.team_motto
	primary_picker.color = GameManager.team.primary_color
	secondary_picker.color = GameManager.team.secondary_color
	show_step()


func show_step() -> void:
	var step := steps[current_step]
	step_label.text = "WELCOME // STEP %d OF %d" % [current_step + 1, steps.size()]
	title_label.text = str(step.title)
	body_label.text = str(step.body)
	setup_form.visible = current_step == 0
	back_button.visible = current_step > 0
	next_button.text = "ENTER TEAM HQ  →" if current_step == steps.size() - 1 else "CONTINUE  →"


func _on_back_pressed() -> void:
	current_step = maxi(0, current_step - 1)
	show_step()


func _on_next_pressed() -> void:
	if current_step == 0 and not apply_identity():
		return
	if current_step < steps.size() - 1:
		current_step += 1
		show_step()
		return
	GameManager.team.tutorial_completed = true
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


func apply_identity() -> bool:
	var chosen_name := name_edit.text.strip_edges()
	if chosen_name.length() < 2:
		name_edit.placeholder_text = "Enter at least 2 characters"
		name_edit.grab_focus()
		return false
	var team := GameManager.team
	team.team_name = chosen_name.left(32)
	team.hometown = hometown_edit.text.strip_edges().left(40)
	team.team_motto = motto_edit.text.strip_edges().left(64)
	team.team_badge = badge_option.get_item_text(badge_option.selected)
	team.primary_color = primary_picker.color
	team.secondary_color = secondary_picker.color
	team.accent_color = primary_picker.color.lerp(Color.WHITE, 0.8)
	for driver in team.drivers:
		if driver != null and driver.is_player_driver:
			driver.team_name = team.team_name
	team.emit_changed()
	return true


func _on_cancel_pressed() -> void:
	GameManager.team = null
	GameManager.active_save_id = ""
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
