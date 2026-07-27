extends Control

const RACE_EVENT_SCENE: PackedScene = preload(
	"res://scenes/pages/race_calendar/race_event.tscn"
)

@export var race_calendar: Array[Race] = []

@onready var races_container: GridContainer = %races_container
@onready var back_button: Button = %back_button


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	create_race_events()


func create_race_events() -> void:
	clear_existing_events()

	print("Race count: ", race_calendar.size())

	if race_calendar.is_empty():
		push_warning("The race calendar contains no races.")
		return

	for race_resource in race_calendar:
		create_race_event(race_resource)

	print(
		"Generated event count: ",
		races_container.get_child_count()
	)


func create_race_event(race_resource: Race) -> void:
	if race_resource == null:
		push_warning("The race calendar contains an empty entry.")
		return

	var event_instance := RACE_EVENT_SCENE.instantiate() as RaceEvent

	if event_instance == null:
		push_error("The race event scene could not be instantiated.")
		return

	races_container.add_child(event_instance)

	event_instance.setup(race_resource)
	event_instance.race_selected.connect(_on_race_selected)


func clear_existing_events() -> void:
	for child in races_container.get_children():
		child.queue_free()


func _on_race_selected(selected_race: Race) -> void:
	if selected_race == null:
		return

	GameManager.selected_race = selected_race

	print(
		"Selected race: %s"
		% selected_race.race_name
	)


func _on_back_button_pressed() -> void:
	GameManager.selected_race = null

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)
