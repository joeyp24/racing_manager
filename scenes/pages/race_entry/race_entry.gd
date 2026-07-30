extends Control

const READINESS_ROW_SCENE: PackedScene = preload("res://ui/components/readiness_row.tscn")

@onready var race_name_label: Label = %race_name_label
@onready var event_details_label: Label = %event_details_label
@onready var prize_label: Label = %prize_label
@onready var cars_container: VBoxContainer = %cars_container
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
var selected_race_teams: Array[RaceTeam] = []


func _ready() -> void:
	if GameManager.team != null and GameManager.team.week_advance_required:
		GameManager.call_deferred("load_page", "res://scenes/pages/dashboard/dashboard.tscn")
		return
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
	var race: Race = GameManager.selected_race
	if race == null:
		race_name_label.text = "No Race Selected"
		event_details_label.text = "Return to the calendar and choose an event."
		prize_label.text = ""
		return
	race_name_label.text = race.race_name
	event_details_label.text = "%s  •  %s\n%d laps  •  Difficulty %d/100  •  Track charges $%s  •  Operations $%s" % [race.track_name, race.race_date, race.lap_count, race.difficulty, format_number(race.get_track_charges()), format_number(race.get_operating_cost())]
	prize_label.text = "PRIZE STRUCTURE  1st $%s  •  2nd $%s  •  3rd $%s" % [format_number(race.first_place_prize), format_number(race.second_place_prize), format_number(race.third_place_prize)]


func create_car_options() -> void:
	for child in cars_container.get_children():
		child.queue_free()
	selected_race_teams.clear()
	if GameManager.team == null:
		return
	GameManager.team.ensure_race_teams()
	for race_team in GameManager.team.race_teams:
		if race_team == null:
			continue
		var driver: Driver = GameManager.team.get_driver_by_id(race_team.driver_id)
		var car: Car = GameManager.team.get_car(race_team.car_bay)
		var option: CheckBox = CheckBox.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.clip_text = true
		option.disabled = not race_team.is_ready(GameManager.team) or not RaceReadiness.is_car_eligible(car, GameManager.selected_race.series_id)
		option.text = "%s  •  %s  •  %s" % [race_team.team_name, driver.driver_name if driver != null else "No driver", car.name if car != null else "No car"]
		option.tooltip_text = "Assign a contracted driver and eligible car on the Race Teams page." if option.disabled else "Include this team in the race entry."
		option.button_pressed = not option.disabled
		option.toggled.connect(_on_race_team_toggled.bind(race_team))
		cars_container.add_child(option)
		if option.button_pressed:
			selected_race_teams.append(race_team)
	_sync_primary_entry()


func _on_race_team_toggled(enabled: bool, race_team: RaceTeam) -> void:
	if enabled and not selected_race_teams.has(race_team):
		selected_race_teams.append(race_team)
	elif not enabled:
		selected_race_teams.erase(race_team)
	_sync_primary_entry()


func _sync_primary_entry() -> void:
	selected_car = GameManager.team.get_car(selected_race_teams[0].car_bay) if not selected_race_teams.is_empty() else null
	GameManager.selected_car = selected_car
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
	var primary_team: RaceTeam = selected_race_teams[0]
	var driver: Driver = GameManager.team.get_driver_by_id(primary_team.driver_id)
	if driver == null:
		selected_car_label.text = "The primary race team has no assigned driver"
		parts_label.text = "Assign a contracted driver before reviewing the entry package."
		return
	selected_car_label.text = "%d team%s entered  •  Primary: %s / %s" % [selected_race_teams.size(), "s" if selected_race_teams.size() != 1 else "", driver.driver_name, selected_car.name]
	var part_lines: Array[String] = []
	for part_type in CarPart.PART_TYPES:
		var part := selected_car.get_part(part_type)
		part_lines.append("%s: %s" % [part_type, "%s (%d%%)" % [part.part_name, part.condition] if part != null else "MISSING"])
	var attributes := selected_car.get_race_attributes()
	var race := GameManager.selected_race
	var suitability := float(attributes.power) * race.power_demand + (float(attributes.grip) + float(attributes.aero) + float(attributes.braking)) / 3.0 * race.handling_demand
	var strengths: Array[String] = []
	if float(attributes.power) >= 65.0 and race.power_demand >= 0.55: strengths.append("power suits the long full-throttle sections")
	if float(attributes.grip) >= 65.0 and race.handling_demand >= 0.55: strengths.append("mechanical grip suits the corner load")
	if float(attributes.tyres) >= 65.0 and race.tyre_wear_factor >= 1.0: strengths.append("tyre preservation should extend the pit window")
	if strengths.is_empty(): strengths.append("a balanced package offers no dominant track advantage")
	parts_label.text = "  •  ".join(part_lines) + "\nFIT %d/100 — %s." % [roundi(suitability / maxf(0.1, race.power_demand + race.handling_demand)), "; ".join(strengths)]


func show_crew_information() -> void:
	if GameManager.team == null:
		return
	var team: Team = GameManager.team
	var chief: StaffMember = team.get_crew_chief()
	var chief_name: String = chief.staff_name if chief != null else "VACANT — REQUIRED"
	crew_label.text = "Crew Chief: %s\nEngineers: %s  •  Mechanics: %s  •  Spotter: %s  •  Pit Crew: %s" % [chief_name, _role_summary("Engineer"), _role_summary("Mechanic"), _role_summary("Spotter"), _role_summary("Pit Crew")]
	crew_effects_label.text = "Reliability +%.1f%%  •  Condition-loss reduction %.1f%%  •  Incident risk −%.1f%%  •  Pit mistake risk −%.1f%%" % [team.get_reliability_boost(), minf(30.0, team.get_reliability_boost() + team.get_accident_risk_reduction()), team.get_accident_risk_reduction(), team.get_pit_mistake_reduction()]


func _role_summary(role: String) -> String:
	var members: Array[StaffMember] = GameManager.team.get_staff_by_role(role)
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
	var race: Race = GameManager.selected_race
	var driver: Driver = GameManager.team.get_driver_by_id(selected_race_teams[0].driver_id) if GameManager.team != null and not selected_race_teams.is_empty() else null
	if race == null or selected_car == null or driver == null:
		forecast_label.text = "Complete the blocked preparation items to generate a race forecast."
		risks_label.text = "Primary risk: incomplete entry package"
		return
	var strategy: Dictionary = RaceManager.get_strategy(selected_strategy)
	var driver_rating := float(driver.get_overall_rating())
	var strength := float(selected_car.get_total_performance(GameManager.team)) * 0.58 + driver_rating * 0.34 + float(selected_car.condition) * 0.08
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
	var driver_payroll := 0
	for race_team in selected_race_teams:
		var entry_driver := GameManager.team.get_driver_by_id(race_team.driver_id)
		if entry_driver != null:
			driver_payroll += entry_driver.salary
	var staff_payroll: int = GameManager.team.get_staff_payroll()
	var objective_chance := clampi(roundi(72.0 + (strength - 60.0) - float(race.difficulty) * 0.25), 10, 95)
	var total_fee: int = race.get_weekend_cost() * selected_race_teams.size()
	var repair_per_point := maxi(50, roundi(float(selected_car.value) * 0.006))
	var expected_wear_cost := wear * repair_per_point
	var fixed_costs := total_fee + driver_payroll + staff_payroll + expected_wear_cost
	var best_cash := GameManager.team.money - fixed_costs + _prize_for_position(race, best) + sponsor_income
	var average_cash := GameManager.team.money - fixed_costs + expected_prize + sponsor_income
	var worst_cash := GameManager.team.money - fixed_costs + _prize_for_position(race, worst) + sponsor_income
	forecast_label.text = (
		"EXPECTED FINISH  P%d–P%d\n\n"
		+ "COST PROJECTION\nEntry & operations  −$%s\nDriver salary  −$%s\nStaff payroll  −$%s\nExpected wear  %d%%  ≈ −$%s\nSponsor income  +$%s\n\n"
		+ "CASH AFTER RACE\nBest (P%d)  $%s\nAverage (P%d)  $%s\nWorst (P%d)  $%s\n\nSponsor objective chance  %d%%"
	) % [best, worst, format_number(total_fee), format_number(driver_payroll), format_number(staff_payroll), wear, format_number(expected_wear_cost), format_number(sponsor_income), best, format_number(best_cash), expected_position, format_number(average_cash), worst, format_number(worst_cash), objective_chance]
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
	var total_fee: int = GameManager.selected_race.get_weekend_cost() * selected_race_teams.size()
	if selected_race_teams.is_empty() or GameManager.team.money < total_fee:
		overall = RaceReadiness.BLOCKED
	readiness_summary_label.text = {RaceReadiness.READY: "READY TO ENTER", RaceReadiness.SUBOPTIMAL: "ENTRY AVAILABLE WITH WARNINGS", RaceReadiness.BLOCKED: "ENTRY BLOCKED"}.get(overall, "REVIEW")
	readiness_summary_label.modulate = {RaceReadiness.READY: Color("43d68a"), RaceReadiness.SUBOPTIMAL: Color("ffb547"), RaceReadiness.BLOCKED: Color("ff667a")}.get(overall, Color.WHITE)
	for check in checks:
		var row := READINESS_ROW_SCENE.instantiate() as ReadinessRow
		readiness_container.add_child(row)
		row.setup(check)
		row.action_requested.connect(_on_readiness_action_requested)
	confirm_button.disabled = overall == RaceReadiness.BLOCKED or selected_car == null
	confirm_button.text = "COMMIT %d ENTR%s  •  $%s  →" % [selected_race_teams.size(), "Y" if selected_race_teams.size() == 1 else "IES", format_number(total_fee)]
	status_label.text = "RECOMMENDED NEXT ACTION  " + ("Resolve the first blocked readiness item below." if confirm_button.disabled else "Commit the entry when the cash scenarios fit your plan.")
	confirm_button.tooltip_text = _get_commit_block_reason(total_fee) if confirm_button.disabled else "Pay the displayed entry cost and open the race weekend."


func _get_commit_block_reason(total_fee: int) -> String:
	if selected_race_teams.is_empty():
		return "Disabled: select at least one race team with an assigned driver and eligible car."
	if GameManager.team.money < total_fee:
		return "Disabled: you need $%s more to pay the weekend cost." % format_number(total_fee - GameManager.team.money)
	if selected_car == null:
		return "Disabled: the primary entry does not have an eligible car."
	return "Disabled: resolve the blocked readiness checks shown above."


func _on_readiness_action_requested(action: String) -> void:
	var pages := {"drivers": "res://scenes/pages/driver_market/driver_market.tscn", "garage": "res://scenes/pages/garage/garage.tscn", "staff": "res://scenes/pages/staff/staff.tscn", "finances": "res://scenes/pages/finances/finances.tscn", "sponsors": "res://scenes/pages/sponsors/sponsors.tscn"}
	var path := str(pages.get(action, ""))
	if not path.is_empty():
		GameManager.load_page(path)


func _on_confirm_button_pressed() -> void:
	if confirm_button.disabled or selected_car == null or GameManager.selected_race == null or selected_race_teams.is_empty():
		return
	for race_team in selected_race_teams:
		var entry_car := GameManager.team.cars[race_team.car_bay] as Car if race_team.car_bay >= 0 and race_team.car_bay < GameManager.team.cars.size() else null
		if not RaceReadiness.is_car_eligible(entry_car, GameManager.selected_race.series_id):
			status_label.text = "Entry blocked: every car must be homologated for %s." % SeriesCatalog.get_series(GameManager.selected_race.series_id).get("name", GameManager.selected_race.series_id)
			back_button.disabled = false
			refresh_operations_center()
			return
	confirm_button.disabled = true
	back_button.disabled = true
	status_label.text = "Committing entry fee and opening race weekend..."
	var total_fee: int = GameManager.selected_race.get_weekend_cost() * selected_race_teams.size()
	if not GameManager.remove_team_money(total_fee):
		status_label.text = "The entry fee could not be paid."
		back_button.disabled = false
		refresh_operations_center()
		return
	GameManager.team.record_finance("Race Operations", -total_fee, "%s track, travel, preparation, insurance, and facility costs (%d teams)" % [GameManager.selected_race.race_name, selected_race_teams.size()])
	var entries: Array[Dictionary] = []
	for race_team in selected_race_teams:
		entries.append({"team_id": race_team.team_id, "team_name": race_team.team_name, "driver_id": race_team.driver_id, "car_bay": race_team.car_bay})
	GameManager.active_race_weekend = {"strategy_id": selected_strategy, "entry_fee_paid": true, "entry_fee_total": total_fee, "entries": entries}
	GameManager.save_game()
	GameManager.load_page("res://scenes/pages/race_weekend/race_weekend.tscn")


func _on_back_button_pressed() -> void:
	GameManager.selected_car = null
	GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")


func _prize_for_position(race: Race, position: int) -> int:
	return RaceManager.calculate_prize_money(race, position)


func format_number(number: int) -> String:
	return String.num_int64(number)
