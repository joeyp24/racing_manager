extends Control

const RACE_EVENT_SCENE: PackedScene = preload(
	"res://scenes/pages/race_calendar/race_event.tscn"
)

@export var race_calendar: Array[Race] = []

@onready var races_container: GridContainer = %races_container
@onready var back_button: Button = %back_button


func _ready() -> void:
	back_button.pressed.connect(
		_on_back_button_pressed
	)

	rebuild_race_progression()
	create_race_events()


func rebuild_race_progression() -> void:
	if GameManager.team == null:
		return

	if race_calendar.is_empty():
		return

	var valid_races: Array[Race] = []

	for race_resource in race_calendar:
		if race_resource == null:
			continue

		if race_resource.race_id.is_empty():
			push_warning(
				"Race '%s' is missing a race_id."
				% race_resource.race_name
			)
			continue

		valid_races.append(race_resource)

	if valid_races.is_empty():
		return

	var progression_changed: bool = false
	var first_race: Race = valid_races[0]

	if not GameManager.team.unlocked_races.has(
		first_race.race_id
	):
		GameManager.team.unlocked_races.append(
			first_race.race_id
		)

		progression_changed = true

	for race_index in range(valid_races.size() - 1):
		var current_race: Race = valid_races[race_index]
		var next_race: Race = valid_races[race_index + 1]

		var current_race_completed: bool = (
			GameManager.team.completed_races.has(
				current_race.race_id
			)
		)

		if not current_race_completed:
			break

		if not GameManager.team.unlocked_races.has(
			next_race.race_id
		):
			GameManager.team.unlocked_races.append(
				next_race.race_id
			)

			progression_changed = true

	if progression_changed:
		GameManager.team.emit_changed()
		GameManager.save_game()


func create_race_events() -> void:
	clear_existing_events()

	if race_calendar.is_empty():
		push_warning(
			"The race calendar contains no races."
		)
		return

	for race_resource in race_calendar:
		create_race_event(race_resource)


func create_race_event(race_resource: Race) -> void:
	if race_resource == null:
		push_warning(
			"The race calendar contains an empty entry."
		)
		return

	var event_instance := (
		RACE_EVENT_SCENE.instantiate()
		as RaceEvent
	)

	if event_instance == null:
		push_error(
			"The race event scene could not be instantiated."
		)
		return

	races_container.add_child(event_instance)
	event_instance.setup(race_resource)


func clear_existing_events() -> void:
	for child in races_container.get_children():
		child.queue_free()


func _on_back_button_pressed() -> void:
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)
