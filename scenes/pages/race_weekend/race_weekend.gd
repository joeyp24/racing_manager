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
@onready var race_flow: RaceFlowProgress = %RaceFlowProgress

var phase: int = 0
var weekend_data: Dictionary = {}

const PRACTICE_ADJUSTMENTS: Array[Dictionary] = [
	{"axis": "", "delta": 0, "name": "Baseline run", "description": "Gather clean reference data without changing the car."},
	{"axis": "gearing", "delta": 1, "name": "Shorter gearing", "description": "Improves acceleration but limits maximum speed."},
	{"axis": "gearing", "delta": -1, "name": "Longer gearing", "description": "Adds top speed but weakens acceleration."},
	{"axis": "front_springs", "delta": 1, "name": "Stiffen front springs", "description": "Sharpens response but can reduce compliance over bumps."},
	{"axis": "front_springs", "delta": -1, "name": "Soften front springs", "description": "Adds front grip and compliance at the cost of response."},
	{"axis": "rear_springs", "delta": 1, "name": "Stiffen rear springs", "description": "Helps rotation but can make power delivery nervous."},
	{"axis": "rear_springs", "delta": -1, "name": "Soften rear springs", "description": "Adds traction but can introduce mid-corner understeer."},
	{"axis": "downforce", "delta": 1, "name": "Add downforce", "description": "Adds cornering stability while sacrificing straight-line speed."},
	{"axis": "downforce", "delta": -1, "name": "Trim downforce", "description": "Reduces drag but narrows the cornering window."},
	{"axis": "left_tyre_pressure", "delta": 1, "name": "Raise left-side pressures", "description": "An oval-specific asymmetric adjustment that changes rotation and warm-up."},
	{"axis": "left_tyre_pressure", "delta": -1, "name": "Lower left-side pressures", "description": "Builds left-side grip and alters the oval cross-weight balance."},
	{"axis": "right_tyre_pressure", "delta": 1, "name": "Raise right-side pressures", "description": "Improves response but can overheat the loaded side of the car."},
	{"axis": "right_tyre_pressure", "delta": -1, "name": "Lower right-side pressures", "description": "Adds loaded-side grip and a wider tyre-temperature window."},
	{"axis": "camber", "delta": 1, "name": "Add camber", "description": "Improves loaded-corner grip but increases inner-shoulder wear."},
	{"axis": "camber", "delta": -1, "name": "Reduce camber", "description": "Protects the tyre while giving away peak cornering grip."},
	{"axis": "toe", "delta": 1, "name": "Add toe-out", "description": "Improves turn-in while increasing drag and tyre scrub."},
	{"axis": "toe", "delta": -1, "name": "Reduce toe-out", "description": "Stabilizes the car and protects tyres at turn-in."},
	{"axis": "track_bar", "delta": 1, "name": "Raise track bar", "description": "Adds oval rotation and rear responsiveness."},
	{"axis": "track_bar", "delta": -1, "name": "Lower track bar", "description": "Adds oval rear stability and traction."}
]

const PRACTICE_COMPOUNDS: Array[String] = ["Standard"]

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
	race_flow.set_stage(1, "Run %d of %d · Build a stable setup window" % [run_number, PracticeRunSimulator.RUN_LIMIT])
	phase_label.text = "PRACTICE"
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
	race_flow.set_stage(2, "Commit the grid lap and lock the race setup")
	phase_label.text = "QUALIFYING"
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
	var controller := "Volunteer crew" if bool(weekend_data.get("uses_volunteer_crew", false)) else "Crew chiefs"
	var controller_action := "takes" if bool(weekend_data.get("uses_volunteer_crew", false)) else "take"
	race_flow.set_stage(2, "Set the opening plan · %s %s control after the green flag" % [controller, controller_action])
	phase_label.text = "PRE-RACE STRATEGY"
	progress_label.text = "Race weekend · Grid formed · AI crew control ready"
	briefing_label.text = "Qualified %s. Choose the opening stint philosophy; the %s will manage pace, fuel, cautions, traffic, and pit service during the race." % [format_position(int(weekend_data["starting_position"])), controller.to_lower()]
	choice_label.text = "Starting aggression"
	set_string_items(choice_selector, ["Conservative", "Balanced", "Aggressive"])
	choice_selector.select(1)
	secondary_label.text = "Tyre and fuel plan"
	secondary_label.visible = true
	secondary_selector.visible = true
	set_string_items(secondary_selector, ["Long fuel load / extended opening stint", "Balanced fuel load / flexible window", "Short fuel load / early stop"])
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
	weekend_data["flow_stage"] = "live_race"
	if choice_selector.selected == 2:
		weekend_data["wear_modifier"] = float(weekend_data["wear_modifier"]) * 1.08
	if secondary_selector.selected == 0:
		weekend_data["wear_modifier"] = float(weekend_data["wear_modifier"]) * 0.92
	GameManager.active_race_weekend = weekend_data.duplicate(true)
	FirstHourExperience.mark_strategy_committed(GameManager.team)
	GameManager.set_race_weekend_stage("live_race")
	# A crash between the grid and green flag must never lose the paid entry state.
	GameManager.save_game()
	GameManager.load_page("res://scenes/pages/live_race/live_race.tscn")


func _on_action_pressed() -> void:
	match phase:
		-1: GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")
		0: complete_practice()
		1: complete_qualifying()
		2: start_race()


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


func fill_selector(selector: OptionButton, values: Array[Dictionary], key: String) -> void:
	selector.clear()
	for value in values:
		selector.add_item(str(value[key]))


func set_string_items(selector: OptionButton, values: Array) -> void:
	selector.clear()
	for value in values:
		selector.add_item(str(value))


func show_invalid_weekend() -> void:
	phase = -1
	race_flow.set_stage(0, "No active race weekend · Return to the calendar")
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
