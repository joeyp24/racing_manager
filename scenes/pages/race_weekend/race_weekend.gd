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

const PRACTICE_ADJUSTMENTS: Array[Dictionary] = [
	{"axis": "", "delta": 0, "name": "Baseline run", "description": "Gather clean reference data without changing the car."},
	{"axis": "aero_balance", "delta": 1, "name": "More aero balance", "description": "Adds cornering stability but can cost straight-line speed."},
	{"axis": "aero_balance", "delta": -1, "name": "Less aero balance", "description": "Reduces drag but makes the car less settled in corners."},
	{"axis": "suspension", "delta": 1, "name": "Softer suspension", "description": "Improves compliance and tyre life but slows direction changes."},
	{"axis": "suspension", "delta": -1, "name": "Stiffer suspension", "description": "Sharpens response but can overwork the tyres."},
	{"axis": "gearing", "delta": 1, "name": "Shorter gearing", "description": "Improves acceleration but limits maximum speed."},
	{"axis": "gearing", "delta": -1, "name": "Longer gearing", "description": "Adds top speed but weakens acceleration."},
	{"axis": "tyre_pressure", "delta": 1, "name": "Raise tyre pressure", "description": "Improves response while narrowing the temperature window."},
	{"axis": "tyre_pressure", "delta": -1, "name": "Lower tyre pressure", "description": "Adds grip and tyre life but increases rolling resistance."},
	{"axis": "brake_bias", "delta": 1, "name": "Move brake bias forward", "description": "Adds braking stability but can lock the front tyres."},
	{"axis": "brake_bias", "delta": -1, "name": "Move brake bias rearward", "description": "Helps rotation but makes braking less forgiving."}
]

const PRACTICE_COMPOUNDS: Array[String] = ["Soft", "Medium", "Hard", "Intermediate", "Wet"]

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
	if (weekend_data.get("practice_runs", []) as Array).size() >= PracticeRunSimulator.RUN_LIMIT:
		show_qualifying()
	else:
		show_practice()


func show_practice() -> void:
	phase = 0
	_ensure_practice_data()
	var run_number := (weekend_data["practice_runs"] as Array).size() + 1
	phase_label.text = "PRACTICE"
	progress_label.text = "Race weekend · Practice run %d of %d · %s forecast" % [run_number, PracticeRunSimulator.RUN_LIMIT, (weekend_data.forecast as Dictionary).weather]
	progress_label.text = "Race weekend • Practice run %d of %d" % [run_number, PracticeRunSimulator.RUN_LIMIT]
	briefing_label.text = "Use three timed runs to find the setup window. Feedback becomes clearer with each run, but the driver can still misread the car."
	progress_label.text = "Race weekend · Practice run %d of %d · %s forecast" % [run_number, PracticeRunSimulator.RUN_LIMIT, (weekend_data.forecast as Dictionary).weather]
	choice_label.text = "Setup adjustment"
	fill_selector(choice_selector, PRACTICE_ADJUSTMENTS, "name")
	secondary_label.text = "Tyre set"
	secondary_label.visible = true
	secondary_selector.visible = true
	set_string_items(secondary_selector, PRACTICE_COMPOUNDS)
	var tyre_sets := weekend_data["practice_tyre_sets"] as Dictionary
	for index in range(PRACTICE_COMPOUNDS.size()):
		var compound := PRACTICE_COMPOUNDS[index]
		secondary_selector.set_item_text(index, "%s (%d sets)" % [compound, int(tyre_sets.get(compound, 0))])
		secondary_selector.set_item_disabled(index, int(tyre_sets.get(compound, 0)) <= 0)
	_select_available_compound()
	action_button.text = "Run Timed Practice"
	_update_choice_preview()


func complete_practice() -> void:
	var adjustment: Dictionary = PRACTICE_ADJUSTMENTS[choice_selector.selected]
	var compound := PRACTICE_COMPOUNDS[secondary_selector.selected]
	var tyre_sets := weekend_data["practice_tyre_sets"] as Dictionary
	if int(tyre_sets.get(compound, 0)) <= 0:
		return
	var setup := weekend_data["practice_setup"] as Dictionary
	setup = PracticeRunSimulator.apply_adjustment(setup, str(adjustment["axis"]), int(adjustment["delta"]))
	tyre_sets[compound] = int(tyre_sets[compound]) - 1
	var driver := _get_primary_driver()
	var runs := weekend_data["practice_runs"] as Array
	var result := PracticeRunSimulator.simulate_run(
		GameManager.selected_race,
		driver,
		_practice_staff_quality(),
		setup,
		compound,
		runs.size() + 1,
		RaceManager.random_number_generator.randi()
	)
	result["adjustment"] = str(adjustment["name"])
	runs.append(result)
	weekend_data["practice_setup"] = setup
	weekend_data["practice_tyre_sets"] = tyre_sets
	weekend_data["practice_runs"] = runs
	GameManager.active_race_weekend = weekend_data.duplicate(true)
	GameManager.save_game()
	if runs.size() < PracticeRunSimulator.RUN_LIMIT:
		show_practice()
	else:
		_finalize_practice()
		GameManager.active_race_weekend = weekend_data.duplicate(true)
		GameManager.save_game()
		show_qualifying()


func show_qualifying() -> void:
	phase = 1
	phase_label.text = "QUALIFYING"
	progress_label.text = "Race weekend · %s qualifying" % weekend_data.qualifying_format
	progress_label.text = "Race weekend • Stage 2 of 4"
	briefing_label.text = "Commit to a qualifying approach. Aggression can gain grid places, but produces a less predictable lap."
	progress_label.text = "Race weekend · %s qualifying" % weekend_data.qualifying_format
	choice_label.text = "Lap approach"
	set_string_items(choice_selector, ["Conservative lap", "Balanced lap", "Aggressive lap"])
	choice_selector.select(1)
	secondary_label.text = "Setup emphasis"
	secondary_label.visible = true
	secondary_selector.visible = true
	set_string_items(secondary_selector, ["Cornering balance", "Straight-line speed", "Race stability"])
	outcome_label.text = "Practice complete: %.0f%% setup confidence • Best lap %.3fs" % [
		float(weekend_data["practice_quality"]),
		float(weekend_data["practice_best_lap"])
	]
	action_button.text = "Run Qualifying"
	_update_choice_preview()


func complete_qualifying() -> void:
	var driver := _get_primary_driver()
	var approach_modifiers: Array[float] = [-1.0, 1.0, 3.0]
	var variance: float = float([1.5, 3.0, 6.0][choice_selector.selected])
	var setup_bonus := float(weekend_data.get("setup_bonus", 0.0))
	var practice_quality := float(weekend_data.get("practice_quality", 35.0))
	var qualifying_score: float = (
		float(GameManager.selected_car.get_total_performance_points(GameManager.team)) * 0.55
		+ float(driver.qualifying_pace) * 0.30
		+ float(driver.consistency) * 0.15
		+ practice_quality * 0.12
		+ setup_bonus * 0.80
		+ approach_modifiers[choice_selector.selected]
		+ RaceManager.random_number_generator.randf_range(-variance, variance)
	)
	var forecast_weather := str((weekend_data.forecast as Dictionary).weather)
	if forecast_weather == "Wet":
		qualifying_score += float(driver.wet_weather - driver.qualifying_pace) * 0.18
	elif forecast_weather == "Mixed":
		qualifying_score += float(driver.wet_weather - 50) * 0.08
	match str(weekend_data.qualifying_format):
		"Knockout":
			var second_run := qualifying_score + RaceManager.random_number_generator.randf_range(-variance, variance)
			qualifying_score = maxf(qualifying_score, second_run)
		"Groups":
			qualifying_score += RaceManager.random_number_generator.randf_range(-2.5, 2.5)
		"Heat races":
			qualifying_score += float(driver.racecraft + driver.starts_restarts - 100) * 0.06
		"Provisionals":
			var prestige_bonus := minf(
				2.0,
				float(GameManager.team.get_reputation_level()) * 0.10
			)
			qualifying_score += prestige_bonus
	var rival_scores: Array[float] = []
	var player_entries := maxi(1, (weekend_data.get("entries", []) as Array).size())
	for rival in RaceManager.get_ai_field_for_race(GameManager.selected_race, player_entries):
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
	set_string_items(secondary_selector, ["Hard tyres / 68% fuel / long stint", "Medium tyres / 56% fuel / flexible", "Soft tyres / 42% fuel / early stop", "Intermediate tyres / 56% fuel / changeable", "Wet tyres / 60% fuel / heavy rain"])
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
		var preview := str(PRACTICE_ADJUSTMENTS[choice_selector.selected]["description"])
		var runs := weekend_data.get("practice_runs", []) as Array
		if not runs.is_empty():
			preview += "\n\n" + _practice_summary(runs.back() as Dictionary)
		outcome_label.text = preview
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
	return clampi(int(weekend_data["starting_position"]) - roundi(float(weekend_data["race_modifier"]) / 2.0), 1, RaceManager.get_maximum_field_size(GameManager.selected_race.series_id))


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


func _ensure_practice_data() -> void:
	if not weekend_data.has("forecast") or not weekend_data.has("qualifying_format"):
		var expansion_weekend := CareerExpansionManager.configure_race_weekend(GameManager.team, GameManager.selected_race)
		weekend_data["forecast"] = (expansion_weekend.forecast as Dictionary).duplicate(true)
		weekend_data["qualifying_format"] = str(expansion_weekend.qualifying_format)
		weekend_data["team_order"] = str(expansion_weekend.team_order)
		GameManager.selected_race.weather = str((weekend_data.forecast as Dictionary).weather)
	if not weekend_data.has("practice_setup"):
		weekend_data["practice_setup"] = PracticeRunSimulator.DEFAULT_SETUP.duplicate(true)
	if not weekend_data.has("practice_runs"):
		weekend_data["practice_runs"] = []
	if not weekend_data.has("practice_tyre_sets"):
		weekend_data["practice_tyre_sets"] = PracticeRunSimulator.DEFAULT_TYRE_SETS.duplicate(true)


func _select_available_compound() -> void:
	for index in range(secondary_selector.item_count):
		if not secondary_selector.is_item_disabled(index):
			secondary_selector.select(index)
			return


func _practice_staff_quality() -> float:
	var total := 0.0
	var count := 0
	for member in GameManager.team.staff:
		if member != null and member.hired and member.role in ["Crew Chief", "Engineer"]:
			total += (float(member.primary_rating) + float(member.secondary_rating)) * 0.5
			count += 1
	var average := total / float(count) if count > 0 else 35.0
	return clampf(average + GameManager.team.get_department_bonus("engineering") * 0.8, 20.0, 100.0)


func _practice_summary(run: Dictionary) -> String:
	return "Run %d • %s • %.3fs • %.1f%% tyre wear\n%s\n%s" % [
		int(run["run"]),
		str(run["compound"]),
		float(run["lap_time"]),
		float(run["tyre_wear"]),
		str(run["feedback"]),
		str(run["guidance"])
	]


func _finalize_practice() -> void:
	var runs := weekend_data["practice_runs"] as Array
	var quality_total := 0.0
	var best_lap := INF
	for run in runs:
		var result := run as Dictionary
		quality_total += float(result["feedback_quality"])
		best_lap = minf(best_lap, float(result["lap_time"]))
	var practice_quality := quality_total / float(maxi(1, runs.size()))
	var setup_score := PracticeRunSimulator.setup_score(GameManager.selected_race, weekend_data["practice_setup"])
	weekend_data["practice_focus"] = "multi_run_setup"
	weekend_data["practice_focus_name"] = "Three-run setup programme"
	weekend_data["practice_quality"] = practice_quality
	weekend_data["practice_best_lap"] = best_lap
	weekend_data["practice_setup_score"] = setup_score
	weekend_data["setup_bonus"] = setup_score * 0.045 + practice_quality * 0.015
	weekend_data["wear_modifier"] = lerpf(1.04, 0.92, setup_score / 100.0)
	weekend_data["practice_guidance"] = str((runs.back() as Dictionary)["guidance"])
