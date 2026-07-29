extends Control

@onready var phase_label: Label = %phase_label
@onready var progress_label: Label = %progress_label
@onready var briefing_label: Label = %briefing_label
@onready var choice_label: Label = %choice_label
@onready var choice_selector: OptionButton = %choice_selector
@onready var secondary_label: Label = %secondary_label
@onready var secondary_selector: OptionButton = %secondary_selector
@onready var outcome_label: Label = %outcome_label
@onready var action_button: Button = %action_button

var phase: int = 0
var decision_index: int = 0
var weekend_data: Dictionary = {}

const PRACTICE_FOCUSES: Array[Dictionary] = [
	{"id": "race_pace", "name": "Race pace", "description": "Improves long-run speed."},
	{"id": "qualifying", "name": "Qualifying pace", "description": "Improves your qualifying lap."},
	{"id": "tyres", "name": "Tyre preservation", "description": "Reduces race wear."},
	{"id": "reliability", "name": "Reliability", "description": "Protects the car during the race."},
	{"id": "confidence", "name": "Driver confidence", "description": "Improves consistency in qualifying and the race."}
]

const DECISIONS: Array[Dictionary] = [
	{"title": "CAUTION — Pit window opens", "text": "The field has slowed under caution. Pit now for fresh tyres or protect track position?", "choices": ["Pit now", "Stay out"]},
	{"title": "TYRE WEAR — Driver needs direction", "text": "Wear is climbing as a rival closes in. Ask the driver to push or protect the car?", "choices": ["Push and defend", "Protect the tyres"]},
	{"title": "FUEL MARGIN — Final stint", "text": "Fuel will be close at the finish. Save fuel now or gamble on outright pace?", "choices": ["Save fuel", "Risk it"]}
]


func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)
	choice_selector.item_selected.connect(_on_choice_changed)
	secondary_selector.item_selected.connect(_on_choice_changed)
	if GameManager.selected_race == null or GameManager.selected_car == null:
		show_invalid_weekend()
		return
	weekend_data = GameManager.active_race_weekend.duplicate(true)
	show_practice()


func show_practice() -> void:
	phase = 0
	phase_label.text = "PRACTICE"
	progress_label.text = "Race weekend • Stage 1 of 4"
	briefing_label.text = "Choose where the team spends its limited practice time. Better staff, driver feedback, car condition, and HQ facilities produce a stronger setup."
	choice_label.text = "Practice focus"
	fill_selector(choice_selector, PRACTICE_FOCUSES, "name")
	secondary_label.visible = false
	secondary_selector.visible = false
	outcome_label.text = ""
	action_button.text = "Complete Practice"
	_update_choice_preview()


func complete_practice() -> void:
	var focus: Dictionary = PRACTICE_FOCUSES[choice_selector.selected]
	var team := GameManager.team
	var driver := _get_primary_driver()
	var staff_rating := 0.0
	var staff_count := 0
	for member in team.staff:
		if member != null and member.hired:
			staff_rating += member.rating
			staff_count += 1
	if staff_count > 0:
		staff_rating /= float(staff_count)
	else:
		staff_rating = 35.0
	var information_quality := (
		float(GameManager.selected_car.condition) * 0.025
		+ float(driver.car_feedback + driver.consistency) * 0.015
		+ staff_rating * 0.025
		+ team.get_department_bonus("engineering") * 0.08
	)
	weekend_data["practice_focus"] = focus["id"]
	weekend_data["practice_focus_name"] = focus["name"]
	weekend_data["practice_quality"] = information_quality
	weekend_data["setup_bonus"] = information_quality * (1.25 if focus["id"] == "race_pace" else 0.65)
	weekend_data["wear_modifier"] = 0.88 if focus["id"] in ["tyres", "reliability"] else 1.0
	show_qualifying()


func show_qualifying() -> void:
	phase = 1
	phase_label.text = "QUALIFYING"
	progress_label.text = "Race weekend • Stage 2 of 4"
	briefing_label.text = "Commit to a qualifying approach. Aggression can gain grid places, but produces a less predictable lap."
	choice_label.text = "Lap approach"
	set_string_items(choice_selector, ["Conservative lap", "Balanced lap", "Aggressive lap"])
	choice_selector.select(1)
	secondary_label.text = "Setup emphasis"
	secondary_label.visible = true
	secondary_selector.visible = true
	set_string_items(secondary_selector, ["Cornering balance", "Straight-line speed", "Race stability"])
	outcome_label.text = "Practice complete: %.1f setup points collected." % float(weekend_data["practice_quality"])
	action_button.text = "Run Qualifying"
	_update_choice_preview()


func complete_qualifying() -> void:
	var driver := _get_primary_driver()
	var approach_modifiers: Array[float] = [-1.0, 1.0, 3.0]
	var variance: float = float([1.5, 3.0, 6.0][choice_selector.selected])
	var focus_bonus: float = 3.0 if weekend_data["practice_focus"] == "qualifying" else 0.0
	var confidence_bonus: float = 1.5 if weekend_data["practice_focus"] == "confidence" else 0.0
	var qualifying_score: float = (
		float(GameManager.selected_car.get_total_performance()) * 0.55
		+ float(driver.qualifying_pace) * 0.30
		+ float(driver.consistency) * 0.15
		+ float(weekend_data["practice_quality"]) * 0.45
		+ approach_modifiers[choice_selector.selected]
		+ focus_bonus + confidence_bonus
		+ RaceManager.random_number_generator.randf_range(-variance, variance)
	)
	var rival_scores: Array[float] = []
	for rival in RaceManager.AI_DRIVERS:
		rival_scores.append(48.0 + float(RaceManager._normalized_ai_attributes(rival)["qualifying_pace"]) * 0.35 + RaceManager.random_number_generator.randf_range(-5.0, 5.0))
	var position := 1
	for rival_score in rival_scores:
		if rival_score > qualifying_score:
			position += 1
	weekend_data["qualifying_score"] = qualifying_score
	weekend_data["starting_position"] = position
	weekend_data["qualifying_approach_name"] = choice_selector.get_item_text(choice_selector.selected)
	weekend_data["setup_emphasis"] = ["High Grip", "Top Speed", "Balanced"][secondary_selector.selected]
	show_strategy()


func show_strategy() -> void:
	phase = 2
	phase_label.text = "PRE-RACE STRATEGY"
	progress_label.text = "Race weekend • Stage 3 of 4"
	briefing_label.text = "Qualified %s. Choose the opening stint plan; you can still react to three pit-wall events during the race." % format_position(int(weekend_data["starting_position"]))
	choice_label.text = "Starting aggression"
	set_string_items(choice_selector, ["Conservative", "Balanced", "Aggressive"])
	choice_selector.select(1)
	secondary_label.text = "Tyre and fuel plan"
	secondary_label.visible = true
	secondary_selector.visible = true
	set_string_items(secondary_selector, ["Hard tyres / long first stint", "Medium tyres / flexible window", "Soft tyres / early stop"])
	secondary_selector.select(1)
	outcome_label.text = "Grid: P%d • Setup: %s" % [int(weekend_data["starting_position"]), weekend_data["setup_emphasis"]]
	action_button.text = "Start Race"
	_update_choice_preview()


func start_race() -> void:
	var strategy_ids: Array[String] = ["conservative", "balanced", "aggressive"]
	weekend_data["strategy_id"] = strategy_ids[choice_selector.selected]
	weekend_data["pre_race_plan"] = secondary_selector.get_item_text(secondary_selector.selected)
	weekend_data["race_modifier"] = [0.0, 0.5, 1.4][choice_selector.selected]
	weekend_data["decision_log"] = []
	if choice_selector.selected == 2:
		weekend_data["wear_modifier"] = float(weekend_data["wear_modifier"]) * 1.08
	if secondary_selector.selected == 0:
		weekend_data["wear_modifier"] = float(weekend_data["wear_modifier"]) * 0.92
	GameManager.active_race_weekend = weekend_data.duplicate(true)
	# A crash between the grid and green flag must never lose the paid entry state.
	GameManager.save_game()
	GameManager.load_page("res://scenes/pages/live_race/live_race.tscn")


func show_decision() -> void:
	var event: Dictionary = DECISIONS[decision_index]
	phase_label.text = str(event["title"])
	progress_label.text = "Live race • Decision %d of %d" % [decision_index + 1, DECISIONS.size()]
	briefing_label.text = str(event["text"])
	choice_label.text = "Pit-wall call"
	var choices: Array = event["choices"] as Array
	set_string_items(choice_selector, choices)
	secondary_label.visible = false
	secondary_selector.visible = false
	outcome_label.text = "Current projected position: P%d" % projected_position()
	action_button.text = "Make Call"
	_update_choice_preview()


func complete_decision() -> void:
	var choice: int = choice_selector.selected
	var outcome: String = ""
	var race_modifier: float = float(weekend_data["race_modifier"])
	var wear_modifier: float = float(weekend_data["wear_modifier"])
	match decision_index:
		0:
			if choice == 0:
				race_modifier += 1.4
				wear_modifier *= 0.90
				outcome = "Pitting under caution saved time and fitted fresh tyres."
			else:
				race_modifier += 0.4
				outcome = "Staying out preserved track position, but leaves older tyres."
		1:
			if choice == 0:
				race_modifier += 1.8
				wear_modifier *= 1.15
				outcome = "The driver held the rival off, at the cost of extra wear."
			else:
				race_modifier -= 0.3
				wear_modifier *= 0.88
				outcome = "The car was protected for a stronger finish."
		2:
			if choice == 0:
				race_modifier += 0.5
				outcome = "Fuel saving secured a clean run to the flag."
			else:
				race_modifier += RaceManager.random_number_generator.randf_range(-2.5, 3.5)
				wear_modifier *= 1.08
				outcome = "The fuel gamble created an unpredictable final sprint."
	weekend_data["race_modifier"] = race_modifier
	weekend_data["wear_modifier"] = wear_modifier
	var decision_log: Array = weekend_data["decision_log"] as Array
	decision_log.append(outcome)
	weekend_data["decision_log"] = decision_log
	decision_index += 1
	if decision_index < DECISIONS.size():
		show_decision()
	else:
		finish_race()


func finish_race() -> void:
	action_button.disabled = true
	phase_label.text = "CHECKERED FLAG"
	progress_label.text = "Calculating weekend result..."
	var result := RaceManager.run_race(
		GameManager.selected_race,
		GameManager.selected_car,
		str(weekend_data["strategy_id"]),
		weekend_data
	)
	GameManager.active_race_weekend.clear()
	if result == null:
		briefing_label.text = "The race could not be completed. Your entry fee has been refunded."
		GameManager.add_team_money(int(weekend_data.get("entry_fee_total", GameManager.selected_race.entry_fee)))
		return
	GameManager.load_page("res://scenes/pages/race_results/race_results.tscn")


func _on_action_pressed() -> void:
	match phase:
		-1: GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")
		0: complete_practice()
		1: complete_qualifying()
		2: start_race()
		3: complete_decision()


func _on_choice_changed(_index: int) -> void:
	_update_choice_preview()


func _update_choice_preview() -> void:
	if phase == 0 and choice_selector.item_count > 0:
		outcome_label.text = str(PRACTICE_FOCUSES[choice_selector.selected]["description"])
	elif phase == 1:
		outcome_label.text = ["Safe and consistent, but gives away pace.", "A representative lap with moderate risk.", "Maximum pace with much greater variance."][choice_selector.selected]
	elif phase == 2:
		outcome_label.text = ["Protect the car at the start.", "Respond to the race as it develops.", "Attack immediately, increasing pace and wear."][choice_selector.selected]
	elif phase == 3:
		outcome_label.text = "Selected call: %s" % choice_selector.get_item_text(choice_selector.selected)


func fill_selector(selector: OptionButton, values: Array[Dictionary], key: String) -> void:
	selector.clear()
	for value in values:
		selector.add_item(str(value[key]))


func set_string_items(selector: OptionButton, values: Array) -> void:
	selector.clear()
	for value in values:
		selector.add_item(str(value))


func projected_position() -> int:
	return clampi(int(weekend_data["starting_position"]) - roundi(float(weekend_data["race_modifier"]) / 2.0), 1, RaceManager.AI_DRIVERS.size() + 1)


func show_invalid_weekend() -> void:
	phase = -1
	phase_label.text = "No Active Race Weekend"
	progress_label.text = ""
	briefing_label.text = "Select a race and car from the race calendar to begin."
	choice_label.visible = false
	choice_selector.visible = false
	secondary_label.visible = false
	secondary_selector.visible = false
	action_button.text = "Return to Calendar"


func format_position(position: int) -> String:
	if position % 100 in [11, 12, 13]:
		return "%dth" % position
	return "%d%s" % [position, {1: "st", 2: "nd", 3: "rd"}.get(position % 10, "th")]


func _get_primary_driver() -> Driver:
	var entries := weekend_data.get("entries", []) as Array
	if not entries.is_empty():
		var driver := GameManager.team.get_driver_by_id(str((entries[0] as Dictionary).get("driver_id", "")))
		if driver != null:
			return driver
	return GameManager.team.get_active_driver()
