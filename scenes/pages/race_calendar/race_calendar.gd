extends Control

const RACE_EVENT_SCENE: PackedScene = preload(
	"res://scenes/pages/race_calendar/race_event.tscn"
)

@export var race_calendar: Array[Race] = []

@onready var races_container: VBoxContainer = %races_container
@onready var back_button: Button = %back_button


func _ready() -> void:
	if GameManager.team != null:
		race_calendar = RaceManager.get_calendar_for_series(GameManager.team.current_series_id)
	back_button.pressed.connect(
		_on_back_button_pressed
	)

	rebuild_race_progression()
	create_race_events()


func rebuild_race_progression() -> void:
	if GameManager.team == null:
		return
	if GameManager.team.ensure_calendar_progression(GameManager.team.current_series_id):
		GameManager.team.emit_changed()
		GameManager.save_game()


func create_race_events() -> void:
	clear_existing_events()

	if race_calendar.is_empty():
		push_warning(
			"The race calendar contains no races."
		)
		return

	var calendar_items: Array[Dictionary] = []
	for race_resource in race_calendar:
		calendar_items.append({"day":race_resource.schedule_day, "type":"championship", "race":race_resource})
	if GameManager.team != null:
		for event in CareerExpansionManager.get_special_events(GameManager.team):
			calendar_items.append({"day":int(event.day), "type":"special", "event":event})
	calendar_items.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first.day) < int(second.day))
	for item in calendar_items:
		if str(item.type) == "special":
			create_special_event(item.event as Dictionary)
		else:
			create_race_event(item.race as Race)


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


func create_special_event(event: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "SPECIAL EVENT · %s\n%s · %s\n%s\nEntry $%s · Purse $%s · Status: %s\nEnter from Career HQ → World." % [event.type, event.name, CalendarCatalog.format_day(int(event.day)), event.description, int(event.entry_cost), int(event.prize), event.status]
	margin.add_child(label)
	races_container.add_child(panel)


func clear_existing_events() -> void:
	for child in races_container.get_children():
		child.queue_free()


func _on_back_button_pressed() -> void:
	GameManager.selected_race = null
	GameManager.selected_car = null

	GameManager.load_page(
		"res://scenes/pages/dashboard/dashboard.tscn"
	)
