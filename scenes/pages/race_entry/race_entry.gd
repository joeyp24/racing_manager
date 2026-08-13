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
@onready var race_flow: RaceFlowProgress = %RaceFlowProgress

var selected_car: Car = null
var selected_strategy: String = RaceManager.DEFAULT_STRATEGY
var selected_race_teams: Array[RaceTeam] = []
var backup_bays_by_team: Dictionary = {}
var entry_options_by_team: Dictionary = {}


func _ready() -> void:
	if GameManager.team != null and GameManager.team.week_advance_required:
		GameManager.call_deferred("load_page", "res://scenes/pages/dashboard/dashboard.tscn")
		return
	back_button.pressed.connect(_on_back_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	strategy_selector.item_selected.connect(_on_strategy_selected)
	race_flow.set_stage(0, "Select eligible teams, review the forecast, and commit the entry")
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
	event_details_label.text = "%s  •  %s\n%d laps  •  Difficulty %d/100  •  Weekend cost $%s per entry" % [race.track_name, race.race_date, race.lap_count, race.difficulty, format_number(GameManager.team.get_effective_weekend_cost(race))]
	prize_label.text = "PRIZE STRUCTURE  1st $%s  •  2nd $%s  •  3rd $%s" % [format_number(race.first_place_prize), format_number(race.second_place_prize), format_number(race.third_place_prize)]


func create_car_options() -> void:
	for child in cars_container.get_children():
		child.queue_free()
	selected_race_teams.clear()
	backup_bays_by_team.clear()
	entry_options_by_team.clear()
	if GameManager.team == null:
		return
	GameManager.team.ensure_race_teams()
	for race_team in GameManager.team.race_teams:
		if race_team == null:
			continue
		var driver: Driver = GameManager.team.get_driver_by_id(race_team.driver_id)
		var planned_bay := _get_planned_primary_bay(race_team)
		var car: Car = GameManager.team.get_car(planned_bay)
		var entry_stack := VBoxContainer.new()
		var option: CheckBox = CheckBox.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.clip_text = true
		var backup_selector := _create_backup_selector(race_team)
		var primary_ready := _is_car_ready_for_entry(car)
		var backup_bay := int(backup_bays_by_team.get(race_team.team_id, -1))
		option.disabled = not race_team.active or driver == null or (not primary_ready and backup_bay < 0)
		var is_planned_rotation := planned_bay >= 0 and planned_bay != race_team.car_bay
		var car_status := ("planned rotation · ready" if is_planned_rotation else "ready") if primary_ready else "unavailable — backup required"
		option.text = "%s  •  %s  •  %s (%s)" % [race_team.team_name, driver.driver_name if driver != null else "No driver", car.name if car != null else "No car", car_status]
		option.tooltip_text = "Assign a driver and prepare either the primary or a backup car." if option.disabled else "Include this team in the race entry."
		option.button_pressed = not option.disabled
		option.toggled.connect(_on_race_team_toggled.bind(race_team))
		entry_options_by_team[race_team.team_id] = option
		entry_stack.add_child(option)
		var backup_row := HBoxContainer.new()
		var backup_label := Label.new()
		backup_label.text = "Travelling backup"
		backup_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		backup_row.add_child(backup_label)
		backup_row.add_child(backup_selector)
		entry_stack.add_child(backup_row)
		cars_container.add_child(entry_stack)
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
	selected_car = GameManager.team.get_car(_get_effective_car_bay(selected_race_teams[0])) if not selected_race_teams.is_empty() else null
	GameManager.selected_car = selected_car
	refresh_operations_center()


func _create_backup_selector(race_team: RaceTeam) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size.x = 240.0
	selector.add_item("No travelling backup")
	selector.set_item_metadata(0, -1)
	var selected_index := 0
	var primary_bays: Array[int] = []
	for other in GameManager.team.race_teams:
		if other != null:
			var planned_bay := _get_planned_primary_bay(other)
			if planned_bay >= 0:
				primary_bays.append(planned_bay)
	for bay in GameManager.team.cars.size():
		if primary_bays.has(bay):
			continue
		var candidate := GameManager.team.get_car(bay)
		if not _is_car_ready_for_entry(candidate):
			continue
		selector.add_item("Bay %d  ·  %s  ·  Prep %d/100" % [bay + 1, candidate.name, candidate.get_preparation_score(GameManager.selected_race)])
		selector.set_item_metadata(selector.item_count - 1, bay)
		if bay == race_team.backup_car_bay:
			selected_index = selector.item_count - 1
	selector.select(selected_index)
	backup_bays_by_team[race_team.team_id] = int(selector.get_item_metadata(selected_index))
	selector.item_selected.connect(_on_backup_selected.bind(race_team, selector))
	selector.tooltip_text = "A prepared, unassigned car can substitute for failed inspection or an unavailable primary. Transport adds 22% of one entry's weekend cost."
	return selector


func _on_backup_selected(index: int, race_team: RaceTeam, selector: OptionButton) -> void:
	var bay := int(selector.get_item_metadata(index))
	race_team.backup_car_bay = bay
	backup_bays_by_team[race_team.team_id] = bay
	var option := entry_options_by_team.get(race_team.team_id) as CheckBox
	var driver := GameManager.team.get_driver_by_id(race_team.driver_id)
	var primary := GameManager.team.get_car(_get_planned_primary_bay(race_team))
	var primary_ready := _is_car_ready_for_entry(primary)
	if option != null:
		var was_disabled := option.disabled
		option.disabled = not race_team.active or driver == null or (not primary_ready and bay < 0)
		var car_status := "ready" if primary_ready else ("backup selected" if bay >= 0 else "unavailable - backup required")
		option.text = "%s  -  %s  -  %s (%s)" % [race_team.team_name, driver.driver_name if driver != null else "No driver", primary.name if primary != null else "No car", car_status]
		if option.disabled:
			option.button_pressed = false
			selected_race_teams.erase(race_team)
		elif was_disabled and not selected_race_teams.has(race_team):
			option.button_pressed = true
			selected_race_teams.append(race_team)
	_sync_primary_entry()


func _is_car_ready_for_entry(car: Car) -> bool:
	return (
		RaceReadiness.is_car_eligible(car, GameManager.selected_race.series_id if GameManager.selected_race != null else "")
		and car.is_race_available(GameManager.team.current_season_day)
	)


func _get_effective_car_bay(race_team: RaceTeam) -> int:
	var primary_bay := _get_planned_primary_bay(race_team)
	var primary := GameManager.team.get_car(primary_bay)
	if _is_car_ready_for_entry(primary):
		return primary_bay
	var backup_bay := int(backup_bays_by_team.get(race_team.team_id, race_team.backup_car_bay))
	return backup_bay if _is_car_ready_for_entry(GameManager.team.get_car(backup_bay)) else -1


func _get_planned_primary_bay(race_team: RaceTeam) -> int:
	if race_team == null or GameManager.team == null or GameManager.selected_race == null:
		return race_team.car_bay if race_team != null else -1
	var planned_bay := GameManager.team.get_race_car_assignment(GameManager.selected_race.race_id, race_team.team_id)
	return planned_bay if planned_bay >= 0 else race_team.car_bay


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
	var backup_bay := int(backup_bays_by_team.get(primary_team.team_id, -1))
	if backup_bay >= 0:
		var backup := GameManager.team.get_car(backup_bay)
		selected_car_label.text += "  ·  Backup: %s" % (backup.name if backup != null else "Unavailable")
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
	var identity_bonus := selected_car.get_identity_pace_bonus(race, driver.driver_id)
	parts_label.text = "  •  ".join(part_lines) + "\nFIT %d/100 — %s.\n%s  ·  Identity pace %+.1f  ·  Driver/car familiarity %d starts" % [roundi(suitability / maxf(0.1, race.power_demand + race.handling_demand)), "; ".join(strengths), selected_car.get_identity_summary().to_upper(), identity_bonus, selected_car.get_driver_familiarity_starts(driver.driver_id)]


func show_crew_information() -> void:
	if GameManager.team == null:
		return
	var team: Team = GameManager.team
	var chief: StaffMember = team.get_crew_chief()
	var using_volunteers := chief == null and RaceReadiness.can_use_volunteer_crew(team)
	var chief_name: String = chief.staff_name if chief != null else ("VOLUNTEER CREW — OPENING RACE" if using_volunteers else "VACANT — REQUIRED")
	crew_label.text = "Crew Chief: %s\nEngineers: %s  •  Mechanics: %s  •  Spotter: %s  •  Pit Crew: %s" % [chief_name, _role_summary("Engineer"), _role_summary("Mechanic"), _role_summary("Spotter"), _role_summary("Pit Crew")]
	if using_volunteers:
		crew_effects_label.text = "Opening-race exception active • Basic setup and automated race calls • No Crew Chief performance bonuses"
	else:
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
	var strength := float(selected_car.get_total_performance_points(GameManager.team)) * 0.58 + driver_rating * 0.34 + float(selected_car.condition) * 0.08
	strength += selected_car.get_identity_pace_bonus(race, driver.driver_id) + selected_car.get_preparation_bonus(race)
	strength *= float(strategy.get("performance_modifier", 1.0))
	var expected_position := clampi(9 - roundi((strength - 55.0) / 7.0), 1, 8)
	var spread := 1 if selected_strategy == "conservative" else (3 if selected_strategy == "aggressive" else 2)
	var best := maxi(1, expected_position - spread)
	var worst := mini(8, expected_position + spread)
	var base_wear := 3 + roundi(float(race.difficulty) / 25.0) + roundi(float(race.lap_count) / 100.0)
	var wear := maxi(1, roundi(float(base_wear) * float(strategy.get("wear_modifier", 1.0)) * selected_car.get_wear_multiplier(race)))
	var expected_prize := _prize_for_position(race, expected_position)
	SponsorManager.ensure_state(GameManager.team)
	var sponsor_income := 0
	var entered_driver_ids: Array[String] = []
	for race_team in selected_race_teams:
		sponsor_income += race_team.get_sponsor_income_per_race()
		entered_driver_ids.append(race_team.driver_id)
	var pay_driver_income := GameManager.team.get_pay_driver_income(entered_driver_ids)
	var commercial_income := int(FinanceManager.get_race_commercial_revenue(GameManager.team, race).total)
	var driver_payroll := 0
	for race_team in selected_race_teams:
		var entry_driver := GameManager.team.get_driver_by_id(race_team.driver_id)
		if entry_driver != null:
			driver_payroll += GameManager.team.get_effective_salary(entry_driver.salary)
	var staff_payroll: int = GameManager.team.get_staff_payroll()
	var objective_chance := clampi(roundi(72.0 + (strength - 60.0) - float(race.difficulty) * 0.25), 10, 95)
	var total_fee: int = _get_total_entry_cost()
	var repair_per_point := maxi(50, roundi(float(selected_car.value) * 0.006))
	var expected_wear_cost := wear * repair_per_point
	var fixed_costs := total_fee + driver_payroll + staff_payroll + expected_wear_cost
	var best_cash := GameManager.team.money - fixed_costs + _prize_for_position(race, best) + sponsor_income + pay_driver_income + commercial_income
	var average_cash := GameManager.team.money - fixed_costs + expected_prize + sponsor_income + pay_driver_income + commercial_income
	var worst_cash := GameManager.team.money - fixed_costs + _prize_for_position(race, worst) + sponsor_income + pay_driver_income + commercial_income
	forecast_label.text = (
		"EXPECTED FINISH  P%d–P%d\n\n"
		+ "COST PROJECTION\nEntry & operations  −$%s\nDriver salary  −$%s\nStaff payroll  −$%s\nExpected wear  %d%%  ≈ −$%s\nSponsor income  +$%s\nSeries, event & owner income  +$%s\n\n"
		+ "CASH AFTER RACE\nBest (P%d)  $%s\nAverage (P%d)  $%s\nWorst (P%d)  $%s\n\nSponsor objective chance  %d%%"
	) % [best, worst, format_number(total_fee), format_number(driver_payroll), format_number(staff_payroll), wear, format_number(expected_wear_cost), format_number(sponsor_income + pay_driver_income), format_number(commercial_income), best, format_number(best_cash), expected_position, format_number(average_cash), worst, format_number(worst_cash), objective_chance]
	var risks: Array[String] = []
	if selected_car.condition < 70:
		risks.append("low car condition")
	if selected_strategy == "aggressive":
		risks.append("elevated incident and wear exposure")
	if GameManager.team.get_staff_by_role("Spotter").is_empty():
		risks.append("no spotter risk reduction")
	if selected_car.get_preparation_score(race) < 78:
		risks.append("limited event-specific preparation")
	if selected_car.get_scrutineering_risk() > 0.01:
		risks.append("%d%% scrutineering risk from rushed or patched work" % roundi(selected_car.get_scrutineering_risk() * 100.0))
	if selected_car.get_wear_multiplier(race) > 1.05:
		risks.append("%s increases expected component wear" % selected_car.get_chassis_trait_data().get("name", "chassis trait"))
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
	var total_fee: int = _get_total_entry_cost()
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
	var pages := {"drivers": "res://scenes/pages/driver_market/driver_market.tscn", "garage": "res://scenes/pages/garage/garage.tscn", "workshop": "res://scenes/pages/garage/fleet_workshop.tscn", "staff": "res://scenes/pages/staff/staff.tscn", "finances": "res://scenes/pages/finances/finances.tscn", "sponsors": "res://scenes/pages/sponsors/sponsors.tscn"}
	var path := str(pages.get(action, ""))
	if not path.is_empty():
		GameManager.load_page(path)


func _on_confirm_button_pressed() -> void:
	if confirm_button.disabled or selected_car == null or GameManager.selected_race == null or selected_race_teams.is_empty():
		return
	var entries: Array[Dictionary] = []
	var committed_bays: Array[int] = []
	var travelling_backup_bays: Array[int] = []
	for race_team in selected_race_teams:
		var assigned_bay := _get_planned_primary_bay(race_team)
		var backup_bay := int(backup_bays_by_team.get(race_team.team_id, race_team.backup_car_bay))
		var entry_bay := _get_effective_car_bay(race_team)
		var entry_car := GameManager.team.get_car(entry_bay)
		var substitution_reason := "Workshop rotation" if entry_bay != assigned_bay else ""
		if backup_bay >= 0:
			if travelling_backup_bays.has(backup_bay):
				status_label.text = "Entry blocked: one travelling backup cannot support two race teams."
				refresh_operations_center()
				return
			travelling_backup_bays.append(backup_bay)
		if entry_bay == assigned_bay and entry_car != null and RaceManager.random_number_generator.randf() < entry_car.get_scrutineering_risk():
			var backup := GameManager.team.get_car(backup_bay)
			if _is_car_ready_for_entry(backup):
				entry_bay = backup_bay
				entry_car = backup
				substitution_reason = "Primary car failed scrutineering after rushed or patched work"
			else:
				status_label.text = "Entry blocked: %s failed scrutineering and no prepared backup travelled." % entry_car.name
				refresh_operations_center()
				return
		if not _is_car_ready_for_entry(entry_car):
			status_label.text = "Entry blocked: every car must be homologated for %s." % SeriesCatalog.get_series(GameManager.selected_race.series_id).get("name", GameManager.selected_race.series_id)
			GameManager.report_decision_outcome({
				"status": "error",
				"title": "Race entry not committed",
				"message": status_label.text,
				"action_label": "Review garage",
				"action_path": "res://scenes/pages/garage/garage.tscn",
			})
			back_button.disabled = false
			refresh_operations_center()
			return
		if committed_bays.has(entry_bay):
			status_label.text = "Entry blocked: the same prepared car cannot support two race entries."
			refresh_operations_center()
			return
		committed_bays.append(entry_bay)
		entries.append({
			"team_id": race_team.team_id, "team_name": race_team.team_name,
			"driver_id": race_team.driver_id, "car_bay": entry_bay,
			"assigned_car_bay": assigned_bay, "backup_car_bay": backup_bay,
			"substitution_reason": substitution_reason,
		})
	if entries.is_empty():
		return
	GameManager.selected_car = GameManager.team.get_car(int(entries[0].car_bay))
	selected_car = GameManager.selected_car
	confirm_button.disabled = true
	back_button.disabled = true
	status_label.text = "Committing entry fee and opening race weekend..."
	var total_fee: int = _get_total_entry_cost()
	var cash_before := GameManager.team.money
	if not GameManager.remove_team_money(total_fee):
		status_label.text = "The entry fee could not be paid."
		GameManager.report_decision_outcome({
			"status": "error",
			"title": "Race entry not committed",
			"message": "The team no longer has enough cash to cover the displayed weekend cost.",
			"action_label": "Review finances",
			"action_path": "res://scenes/pages/finances/finances.tscn",
		})
		back_button.disabled = false
		refresh_operations_center()
		return
	GameManager.team.record_finance("Race Operations", -total_fee, "%s track, travel, preparation, insurance, and facility costs (%d teams)" % [GameManager.selected_race.race_name, selected_race_teams.size()])
	var uses_volunteer_crew := GameManager.team.get_crew_chief() == null and RaceReadiness.can_use_volunteer_crew(GameManager.team)
	GameManager.begin_race_weekend({"strategy_id": selected_strategy, "entry_fee_total": total_fee, "entries": entries, "uses_volunteer_crew": uses_volunteer_crew})
	GameManager.save_game()
	GameManager.report_decision_outcome({
		"title": "%d race entr%s committed" % [selected_race_teams.size(), "y" if selected_race_teams.size() == 1 else "ies"],
		"message": "%s is ready for practice and qualifying." % GameManager.selected_race.race_name,
		"detail": _entry_commit_detail(entries, uses_volunteer_crew),
		"cash_delta": GameManager.team.money - cash_before,
		"action_label": "Continue weekend",
		"action_path": "res://scenes/pages/race_weekend/race_weekend.tscn",
	})
	GameManager.load_page("res://scenes/pages/race_weekend/race_weekend.tscn")


func _on_back_button_pressed() -> void:
	GameManager.selected_car = null
	GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")


func _prize_for_position(race: Race, position: int) -> int:
	return RaceManager.calculate_prize_money(race, position)


func _get_total_entry_cost() -> int:
	if GameManager.team == null or GameManager.selected_race == null:
		return 0
	var backup_count := 0
	for race_team in selected_race_teams:
		if int(backup_bays_by_team.get(race_team.team_id, -1)) >= 0:
			backup_count += 1
	return (
		GameManager.team.get_effective_weekend_cost(GameManager.selected_race, selected_race_teams.size())
		+ GameManager.team.get_backup_transport_cost(GameManager.selected_race, backup_count)
	)


func _entry_commit_detail(entries: Array[Dictionary], uses_volunteer_crew: bool) -> String:
	var substitutions: Array[String] = []
	for entry in entries:
		if not str(entry.get("substitution_reason", "")).is_empty():
			var car := GameManager.team.get_car(int(entry.get("car_bay", -1)))
			substitutions.append("%s uses %s: %s." % [entry.get("team_name", "Team"), car.name if car != null else "the backup", entry.substitution_reason])
	if not substitutions.is_empty():
		return " ".join(substitutions)
	return "The volunteer crew will manage each car after the green flag." if uses_volunteer_crew else "AI crew chiefs will manage each car after the green flag."


func format_number(number: int) -> String:
	return String.num_int64(number)
