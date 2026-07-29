extends Control

const RACE_CAR_OPTION_SCENE: PackedScene = preload("res://scenes/pages/race_entry/race_car_option.tscn")
const READINESS_ROW_SCENE: PackedScene = preload("res://ui/components/readiness_row.tscn")

@onready var race_name_label: Label = %race_name_label
@onready var event_details_label: Label = %event_details_label
@onready var prize_label: Label = %prize_label
@onready var cars_container: GridContainer = %cars_container
@onready var selected_car_label: Label = %selected_car_label
@onready var parts_label: Label = %parts_label
@onready var crew_label: Label = %crew_label
@onready var crew_effects_label: Label = %crew_effects_label
@onready var strategy_selector: OptionButton = %strategy_selector
@onready var strategy_preview_label: Label = %strategy_preview_label
@onready var forecast_label: Label = %forecast_label
@onready var risks_label: Label = %risks_label
@onready var readiness_container: VBoxContainer = %readiness_container
@onready var readiness_summary_label: Label = %readiness_summary_label
@onready var status_label: Label = %status_label
@onready var back_button: Button = %back_button
@onready var confirm_button: Button = %confirm_button

var selected_car: Car = null
var selected_strategy: String = RaceManager.DEFAULT_STRATEGY
var car_option_nodes: Array[RaceCarOption] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	strategy_selector.item_selected.connect(_on_strategy_selected)
	setup_strategy_selector()
	show_event_information()
	create_car_options()
	show_crew_information()
	refresh_operations_center()


func setup_strategy_selector() -> void:
	strategy_selector.clear()
	for strategy_id in ["conservative", "balanced", "aggressive"]:
		var strategy: Dictionary = RaceManager.get_strategy(strategy_id)
		strategy_selector.add_item(str(strategy.get("name", strategy_id.capitalize())))
		strategy_selector.set_item_metadata(strategy_selector.item_count - 1, strategy_id)
	strategy_selector.select(1)


func show_event_information() -> void:
	var race := GameManager.selected_race
	if race == null:
		race_name_label.text = "No Race Selected"
		event_details_label.text = "Return to the calendar and choose an event."
		prize_label.text = ""
		return
	race_name_label.text = race.race_name
	event_details_label.text = "%s  •  %s\n%d laps  •  Difficulty %d/100  •  Entry $%s" % [race.track_name, race.race_date, race.lap_count, race.difficulty, format_number(race.entry_fee)]
	prize_label.text = "PRIZE STRUCTURE  1st $%s  •  2nd $%s  •  3rd $%s" % [format_number(race.first_place_prize), format_number(race.second_place_prize), format_number(race.third_place_prize)]


func create_car_options() -> void:
	for child in cars_container.get_children():
		child.queue_free()
	car_option_nodes.clear()
	if GameManager.team == null:
		return
	for car_value in GameManager.team.cars:
		var car := car_value as Car
		if car == null:
			continue
		var option := RACE_CAR_OPTION_SCENE.instantiate() as RaceCarOption
		cars_container.add_child(option)
		option.setup(car)
		option.car_selected.connect(_on_car_selected)
		car_option_nodes.append(option)
	var recommended := RaceReadiness.get_recommended_car(GameManager.team)
	if recommended != null:
		_on_car_selected(recommended)


func _on_car_selected(car: Car) -> void:
	selected_car = car
	GameManager.selected_car = car
	for option in car_option_nodes:
		option.set_selected(option.car == selected_car)
	refresh_operations_center()


func _on_strategy_selected(index: int) -> void:
	selected_strategy = str(strategy_selector.get_item_metadata(index))
	refresh_operations_center()


func refresh_operations_center() -> void:
	update_entry_information()
	update_strategy_preview()
	update_forecast()
	update_readiness()


func update_entry_information() -> void:
	if selected_car == null:
		selected_car_label.text = "No eligible car selected"
		parts_label.text = "Select a car to review its installed package."
		return
	selected_car_label.text = "%s  •  Condition %d%%  •  Performance %d" % [selected_car.name, selected_car.condition, selected_car.get_total_performance()]
	var part_lines: Array[String] = []
	for part_type in CarPart.PART_TYPES:
		var part := selected_car.get_part(part_type)
		part_lines.append("%s: %s" % [part_type, "%s (%d%%)" % [part.part_name, part.condition] if part != null else "MISSING"])
	parts_label.text = "  •  ".join(part_lines)


func show_crew_information() -> void:
	if GameManager.team == null:
		return
	var team := GameManager.team
	var chief := team.get_crew_chief()
	var chief_name := chief.staff_name if chief != null else "VACANT — REQUIRED"
	crew_label.text = "Crew Chief: %s\nEngineers: %s  •  Mechanics: %s  •  Spotter: %s  •  Pit Crew: %s" % [chief_name, _role_summary("Engineer"), _role_summary("Mechanic"), _role_summary("Spotter"), _role_summary("Pit Crew")]
	crew_effects_label.text = "Reliability +%.1f%%  •  Condition-loss reduction %.1f%%  •  Incident risk −%.1f%%  •  Pit mistake risk −%.1f%%" % [team.get_reliability_boost(), minf(30.0, team.get_reliability_boost() + team.get_accident_risk_reduction()), team.get_accident_risk_reduction(), team.get_pit_mistake_reduction()]


func _role_summary(role: String) -> String:
	var members := GameManager.team.get_staff_by_role(role)
	if members.is_empty():
		return "vacant"
	var total := 0
	for member in members:
		total += member.rating
	return "%d assigned (%d avg)" % [members.size(), total / members.size()]


func update_strategy_preview() -> void:
	var copy := {
		"conservative": "−3% expected pace  •  −30% result variance  •  −25% component wear",
		"balanced": "Baseline pace, incident exposure, and component wear",
		"aggressive": "+4% expected pace  •  +40% result variance  •  +35% component wear"
	}
	strategy_preview_label.text = str(copy.get(selected_strategy, copy["balanced"]))


func update_forecast() -> void:
	var race := GameManager.selected_race
	var driver := GameManager.team.get_active_driver() if GameManager.team != null else null
	if race == null or selected_car == null or driver == null:
		forecast_label.text = "Complete the blocked preparation items to generate a race forecast."
		risks_label.text = "Primary risk: incomplete entry package"
		return
	var strategy := RaceManager.get_strategy(selected_strategy)
	var driver_rating := float(driver.skill + driver.consistency + driver.aggression) / 3.0
	var strength := float(selected_car.get_total_performance()) * 0.58 + driver_rating * 0.34 + float(selected_car.condition) * 0.08
	strength *= float(strategy.get("performance_modifier", 1.0))
	var expected_position := clampi(9 - roundi((strength - 55.0) / 7.0), 1, 8)
	var spread := 1 if selected_strategy == "conservative" else (3 if selected_strategy == "aggressive" else 2)
	var best := maxi(1, expected_position - spread)
	var worst := mini(8, expected_position + spread)
	var base_wear := 3 + roundi(float(race.difficulty) / 25.0) + roundi(float(race.lap_count) / 100.0)
	var wear := maxi(1, roundi(float(base_wear) * float(strategy.get("wear_modifier", 1.0))))
	var expected_prize := _prize_for_position(race, expected_position)
	var sponsor := SponsorCatalog.find_by_id(GameManager.team.active_sponsor_id)
	var sponsor_income := sponsor.payment_per_race if sponsor != null else 0
	var payroll := GameManager.team.get_total_race_payroll()
	var objective_chance := clampi(roundi(72.0 + (strength - 60.0) - float(race.difficulty) * 0.25), 10, 95)
	forecast_label.text = "EXPECTED FINISH  P%d–P%d\nExpected revenue $%s  •  Entry + payroll $%s  •  Net forecast %s$%s\nSponsor objective chance %d%%  •  Expected condition loss %d%%" % [best, worst, format_number(expected_prize + sponsor_income), format_number(race.entry_fee + payroll), "+" if expected_prize + sponsor_income >= race.entry_fee + payroll else "−", format_number(absi(expected_prize + sponsor_income - race.entry_fee - payroll)), objective_chance, wear]
	var risks: Array[String] = []
	if selected_car.condition < 70:
		risks.append("low car condition")
	if selected_strategy == "aggressive":
		risks.append("elevated incident and wear exposure")
	if GameManager.team.get_staff_by_role("Spotter").is_empty():
		risks.append("no spotter risk reduction")
	if risks.is_empty():
		risks.append("normal race variance")
	risks_label.text = "PRIMARY RISKS  " + "  •  ".join(risks)


func update_readiness() -> void:
	for child in readiness_container.get_children():
		child.queue_free()
	if GameManager.team == null or GameManager.selected_race == null:
		confirm_button.disabled = true
		return
	var checks := RaceReadiness.evaluate(GameManager.team, GameManager.selected_race, selected_car)
	var overall := RaceReadiness.get_overall_status(checks)
	readiness_summary_label.text = {RaceReadiness.READY: "READY TO ENTER", RaceReadiness.SUBOPTIMAL: "ENTRY AVAILABLE WITH WARNINGS", RaceReadiness.BLOCKED: "ENTRY BLOCKED"}.get(overall, "REVIEW")
	readiness_summary_label.modulate = {RaceReadiness.READY: Color("43d68a"), RaceReadiness.SUBOPTIMAL: Color("ffb547"), RaceReadiness.BLOCKED: Color("ff667a")}.get(overall, Color.WHITE)
	for check in checks:
		var row := READINESS_ROW_SCENE.instantiate() as ReadinessRow
		readiness_container.add_child(row)
		row.setup(check)
		row.action_requested.connect(_on_readiness_action_requested)
	confirm_button.disabled = overall == RaceReadiness.BLOCKED or selected_car == null
	status_label.text = "Resolve blocked items before entry." if confirm_button.disabled else "Review the forecast, then commit the entry fee."


func _on_readiness_action_requested(action: String) -> void:
	var pages := {"drivers": "res://scenes/pages/drivers/drivers.tscn", "garage": "res://scenes/pages/garage/garage.tscn", "staff": "res://scenes/pages/staff/staff.tscn", "finances": "res://scenes/pages/finances/finances.tscn", "sponsors": "res://scenes/pages/sponsors/sponsors.tscn"}
	var path := str(pages.get(action, ""))
	if not path.is_empty():
		GameManager.load_page(path)


func _on_confirm_button_pressed() -> void:
	if confirm_button.disabled or selected_car == null or GameManager.selected_race == null:
		return
	confirm_button.disabled = true
	back_button.disabled = true
	status_label.text = "Committing entry fee and opening race weekend..."
	if not GameManager.remove_team_money(GameManager.selected_race.entry_fee):
		status_label.text = "The entry fee could not be paid."
		back_button.disabled = false
		refresh_operations_center()
		return
	GameManager.team.record_finance("Race", -GameManager.selected_race.entry_fee, "%s entry fee" % GameManager.selected_race.race_name)
	GameManager.active_race_weekend = {"strategy_id": selected_strategy, "entry_fee_paid": true}
	GameManager.save_game()
	GameManager.load_page("res://scenes/pages/race_weekend/race_weekend.tscn")


func _on_back_button_pressed() -> void:
	GameManager.selected_car = null
	GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")


func _prize_for_position(race: Race, position: int) -> int:
	match position:
		1: return race.first_place_prize
		2: return race.second_place_prize
		3: return race.third_place_prize
		_: return 0


func format_number(number: int) -> String:
	return String.num_int64(number)
