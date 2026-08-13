class_name RaceSimulation
extends RefCounted

signal lap_completed(lap: int)
signal race_completed
signal caution_started(lap: int)
signal engineer_advice_ready(advice: Dictionary)
signal crew_chief_call_issued(call: Dictionary)

var race: Race
var current_lap: int = 0
var race_state: String = "GREEN FLAG"
var elapsed_race_time: float = 0.0
var entries: Array[RaceEntryState] = []
var event_log: Array[String] = []
var is_complete: bool = false
var caution_count: int = 0
var green_flag_laps: int = 0
var scheduled_laps: int = 0
var race_distance_laps: int = 0
var overtime_attempts: int = 0
var max_overtime_attempts: int = 3
var player_pit_time_reduction: float = 0.0
var player_pit_mistake_reduction: float = 0.0
var player_engineer_quality: float = 42.0
var random_number_generator := RandomNumberGenerator.new()
var weather_state: String = "Dry"
var rain_intensity: float = 0.0
var track_grip: float = 0.92
var track_temperature: float = 24.0
var rubber_level: float = 0.0
var forecast: Dictionary = {}
var weather_timeline: Array[Dictionary] = []
var replay_timeline: Array[Dictionary] = []
var telemetry_history: Array[Dictionary] = []
var strategy_timeline: Array[Dictionary] = []
var race_events: Array[Dictionary] = []
var engineer_advice_history: Array[Dictionary] = []
var latest_engineer_advice: Dictionary = {}
var caution_start_positions: Dictionary = {}
var automated_player_crew: bool = false
var crew_chief_calls: Array[Dictionary] = []
var crew_controller_label: String = "Crew chief"


func setup(
	selected_race: Race,
	player_driver: Driver,
	player_team_name: String,
	player_score: float,
	starting_position: int,
	ai_drivers: Array[Dictionary],
	ai_scores: Array[float],
	starting_compound: String = "Standard",
	additional_team_entries: Array = [],
	seed: int = -1,
	player_attributes: Dictionary = {},
	locked_setup: String = "Balanced",
	practice_setup: Dictionary = {},
	player_fuel_fraction: float = 0.56
) -> void:
	race = selected_race
	if seed >= 0:
		random_number_generator.seed = seed
	else:
		random_number_generator.randomize()
	var grid: Array[RaceEntryState] = []
	for index in range(ai_drivers.size()):
		var data := ai_drivers[index]
		var entry := RaceEntryState.new()
		entry.driver_id = str(data.get("driver_id", ""))
		entry.driver_name = str(data.get("driver_name", "Unknown Driver"))
		entry.team_id = str(data.get("team_id", ""))
		entry.team_name = str(data.get("team_name", "Unknown Team"))
		entry.consistency = int(data.get("consistency", 50))
		entry.aggression = int(data.get("aggression", 50))
		entry.attributes = data.get("attributes", data).duplicate()
		entry.reliability = float(data.get("reliability", 72))
		entry.fuel_efficiency = float(data.get("fuel_efficiency", 50))
		entry.tyre_preservation = float(data.get("tyre_preservation", 50))
		entry.strategy_skill = float(data.get("strategy_rating", data.get("strategy_skill", 50)))
		entry.philosophy_id = str(data.get("philosophy_id", "balanced_contender"))
		entry.strategy_aggression = float(data.get("strategy_aggression", 0.0))
		entry.reliability_bias = float(data.get("reliability_bias", 0.0))
		entry.qualifying_bias = float(data.get("qualifying_bias", 0.0))
		entry.youth_bias = float(data.get("youth_bias", 0.0))
		entry.development_bias = float(data.get("development_bias", 0.0))
		entry.difficulty_scale = float(data.get("difficulty_scale", 1.0))
		entry.base_pace = ai_scores[index]
		grid.append(entry)
	var player := RaceEntryState.new()
	player.driver_id = player_driver.driver_id
	player.driver_name = player_driver.driver_name
	player.team_id = str(player_attributes.get("team_id", "player_team"))
	player.team_name = player_team_name
	player.is_player = true
	player.consistency = player_driver.consistency
	player.base_pace = player_score
	player.aggression = player_driver.aggression
	player.attributes = player_driver.get_attribute_dictionary()
	player.reliability = float(player_attributes.get("reliability", 75.0))
	player.fuel_efficiency = float(player_attributes.get("fuel", 50.0))
	player.tyre_preservation = float(player_attributes.get("tyres", 50.0))
	player.setup_mode = locked_setup
	player.setup_profile = practice_setup.duplicate(true)
	player.tyre_compound = "Standard"
	player.strategy_skill = float(player_attributes.get("strategy_skill", 45.0))
	player.component_health = (player_attributes.get("component_health", {}) as Dictionary).duplicate(true)
	for component in Car.DAMAGE_COMPONENTS:
		player.component_health[component] = clampf(float(player.component_health.get(component, 100.0)), 0.0, 100.0)
	player.difficulty_scale = float(player_attributes.get("incident_scale", 1.0))
	player_pit_time_reduction = float(player_attributes.get("pit_time_reduction", 0.0))
	player_pit_mistake_reduction = float(player_attributes.get("pit_mistake_reduction", 0.0))
	player_engineer_quality = float(player_attributes.get("engineer_quality", 42.0))
	grid.insert(clampi(starting_position - 1, 0, grid.size()), player)
	for data_value in additional_team_entries:
		var data := data_value as Dictionary
		var teammate := RaceEntryState.new()
		teammate.driver_id = str(data.get("driver_id", ""))
		teammate.driver_name = str(data.get("driver_name", "Team Driver"))
		teammate.team_id = str(data.get("team_id", ""))
		teammate.team_name = str(data.get("team_name", player_team_name))
		teammate.is_player = true
		teammate.consistency = int(data.get("consistency", 50))
		teammate.aggression = int(data.get("aggression", 50))
		teammate.attributes = data.get("attributes", {}).duplicate()
		teammate.base_pace = float(data.get("score", 50.0))
		teammate.tyre_compound = "Standard"
		teammate.reliability = float(data.get("reliability", player.reliability))
		teammate.fuel_efficiency = float(data.get("fuel_efficiency", player.fuel_efficiency))
		teammate.tyre_preservation = float(data.get("tyre_preservation", 50.0))
		teammate.strategy_skill = float(data.get("strategy_skill", player.strategy_skill))
		teammate.strategy_aggression = float(data.get("strategy_aggression", 0.0))
		teammate.difficulty_scale = player.difficulty_scale
		teammate.component_health = (data.get("component_health", {}) as Dictionary).duplicate(true)
		for component in Car.DAMAGE_COMPONENTS:
			teammate.component_health[component] = clampf(float(teammate.component_health.get(component, 100.0)), 0.0, 100.0)
		teammate.mechanical_health = _average_component_health(teammate)
		teammate.setup_profile = practice_setup.duplicate(true)
		grid.insert(clampi(int(data.get("starting_position", grid.size() + 1)) - 1, 0, grid.size()), teammate)
	for index in range(grid.size()):
		var entry := grid[index]
		entry.starting_position = index + 1
		entry.position = index + 1
		entry.elapsed_time = float(index) * 0.18
		var efficiency_modifier := 1.0 + (entry.fuel_efficiency - 50.0) * 0.0015
		var fuel_fraction := player_fuel_fraction if entry.is_player or entry.team_name == player_team_name else lerpf(0.48, 0.64, entry.strategy_skill / 100.0)
		entry.fuel_target_laps = float(race.lap_count) * race.fuel_consumption_factor * fuel_fraction
		entry.fuel_laps = entry.fuel_target_laps * efficiency_modifier
		entry.fuel_remaining = 100.0
		entry.tyre_temperature = 76.0 + race.heat_factor * 12.0
	entries = grid
	scheduled_laps = race.lap_count
	race_distance_laps = scheduled_laps
	event_log.append("LAP 0  The field takes the green flag.")
	var planned_stop := clampi(roundi(float(scheduled_laps) * player_fuel_fraction), 2, maxi(2, scheduled_laps - 2))
	strategy_timeline.append({"lap":0, "type":"plan", "title":"Pre-race plan", "detail":"Initial window centered on lap %d with four tyres and fuel." % planned_stop, "planned_lap":planned_stop})
	_generate_engineer_advice("start")


func configure_environment(data: Dictionary) -> void:
	forecast = data.duplicate(true)
	if race.is_oval():
		forecast["weather"] = "Dry"
		forecast["rain_chance"] = 0
	weather_state = str(forecast.get("weather", race.weather))
	track_temperature = float(forecast.get("temperature", 24.0))
	rain_intensity = 0.72 if weather_state == "Wet" else (0.22 if weather_state == "Mixed" else 0.0)
	track_grip = 0.72 if rain_intensity > 0.45 else (0.86 if rain_intensity > 0.0 else 0.92)
	weather_timeline.append({"lap":0, "weather":weather_state, "rain":rain_intensity, "grip":track_grip})
	event_log.append("FORECAST  %s, %d°C, %d%% rain risk." % [weather_state, roundi(track_temperature), int(forecast.get("rain_chance", 0))])


func simulate_lap() -> void:
	if is_complete or race == null:
		return
	current_lap += 1
	_update_environment()
	_update_track_state()
	if race_state == "GREEN FLAG":
		green_flag_laps += 1
	var previous_player_positions := {}
	for player_entry in get_player_entries():
		previous_player_positions[_entry_key(player_entry)] = player_entry.position
	for entry in entries:
		if entry.status == "Retired":
			continue
		if entry.is_player and automated_player_crew:
			_update_crew_chief_strategy(entry)
		elif not entry.is_player:
			_update_ai_strategy(entry)
		var pit_loss := 0.0
		if entry.is_player and not entry.pending_pit_service.is_empty():
			pit_loss = _perform_pit_stop(entry, entry.pending_pit_service)
		elif entry.is_player and automated_player_crew and _ai_should_pit(entry):
			var crew_service := _choose_ai_pit_service(entry)
			_record_crew_chief_call(
				entry,
				"Box this lap",
				"%s. %s" % [describe_pit_service(crew_service), _crew_pit_reason(entry)],
				"action"
			)
			pit_loss = _perform_pit_stop(entry, crew_service)
		elif not entry.is_player and _ai_should_pit(entry):
			pit_loss = _perform_pit_stop(entry, _choose_ai_pit_service(entry))
		entry.pace_mode = entry.pending_pace_mode
		var pace_data := _pace_data(entry)
		_update_mechanical_health(entry, pace_data)
		var incident_loss := _resolve_incident(entry)
		if entry.status == "Retired":
			continue
		var base_lap := 34.0 + float(race.difficulty) * 0.035
		var rating_bonus := (entry.base_pace - 55.0) * 0.030 + (_situational_rating(entry) - 50.0) * 0.018
		var tyre_penalty := _tyre_performance_penalty(entry)
		var fuel_weight_penalty := maxf(0.0, entry.fuel_laps) / maxf(1.0, race.lap_count) * 0.75
		var traffic_penalty := _traffic_penalty(entry)
		entry.traffic_time_loss += traffic_penalty
		var mechanical_penalty := pow(1.0 - entry.mechanical_health / 100.0, 2.0) * 1.6 + _component_performance_penalty(entry)
		var caution_delta := 4.5 if race_state != "GREEN FLAG" else 0.0
		var variance_limit := lerpf(0.55, 0.08, float(entry.rating("consistency", entry.consistency)) / 100.0)
		var late_race_penalty := maxf(0.0, float(current_lap) / maxf(1.0, float(race_distance_laps)) - 0.65) * lerpf(0.55, 0.0, entry.rating("fitness") / 100.0) * (1.0 + race.heat_factor)
		entry.last_lap_time = maxf(20.0, base_lap - rating_bonus + tyre_penalty + fuel_weight_penalty + traffic_penalty + mechanical_penalty + caution_delta + late_race_penalty + float(pace_data.mode) + float(pace_data.compound) + _get_setup_modifier(entry) + pit_loss + incident_loss + random_number_generator.randf_range(-variance_limit, variance_limit))
		entry.elapsed_time += entry.last_lap_time
		entry.completed_laps = current_lap
		entry.best_lap_time = entry.last_lap_time if entry.best_lap_time <= 0.0 else minf(entry.best_lap_time, entry.last_lap_time)
		entry.tyre_condition = maxf(0.0, entry.tyre_condition - float(pace_data.wear))
		entry.stint_laps += 1
		_update_tyre_temperature(entry)
		var consumption := race.fuel_consumption_factor * float(pace_data.fuel) * float({"Save":0.90, "Balanced":1.0, "Push":1.08}.get(entry.fuel_target_mode, 1.0))
		entry.fuel_laps = maxf(0.0, entry.fuel_laps - consumption)
		entry.fuel_remaining = clampf(entry.fuel_laps / maxf(1.0, entry.fuel_target_laps) * 100.0, 0.0, 100.0)
		if entry.fuel_laps <= 0.0 and current_lap < race_distance_laps:
			entry.last_lap_time += 5.0
			entry.elapsed_time += 5.0
			if entry.is_player: event_log.append("LAP %d  FUEL CRITICAL — save immediately or pit." % current_lap)
	_resolve_overtaking_battles()
	_sort_standings()
	if race_state == "SAFETY CAR":
		_compress_field_under_caution()
		_sort_standings()
	var player := get_player_entry()
	for player_entry in get_player_entries():
		var previous_position := int(previous_player_positions.get(_entry_key(player_entry), player_entry.position))
		if player_entry.status != "Retired" and player_entry.position != previous_position:
			event_log.append("LAP %d  %s is now P%d." % [current_lap, player_entry.driver_name, player_entry.position])
	if player != null and current_lap % maxi(4, race_distance_laps / 8) == 0:
		event_log.append("LAP %d  %s: tyres %d%%, fuel %.1f laps, car %d%%, systems %d%%." % [current_lap, crew_controller_label, roundi(player.tyre_condition), player.fuel_laps / maxf(0.1, race.fuel_consumption_factor), roundi(player.car_condition), roundi(player.mechanical_health)])
		_generate_engineer_advice("interval")
	_record_player_telemetry()
	_record_replay_snapshot()
	elapsed_race_time = entries[0].elapsed_time
	lap_completed.emit(current_lap)
	if current_lap >= race_distance_laps and race_state in ["SAFETY CAR", "RESTART"]:
		# Overtime cannot end behind the pace car. Hold the checkered flag until
		# the restart has produced two green-flag laps.
		race_distance_laps = current_lap + (2 if race_state == "RESTART" else 1)
		return
	if current_lap >= race_distance_laps:
		is_complete = true
		race_state = "CHECKERED FLAG"
		event_log.append("LAP %d  Checkered flag — %s wins." % [current_lap, entries[0].driver_name])
		race_completed.emit()


func _update_environment() -> void:
	if race.is_oval():
		weather_state = "Dry"
		rain_intensity = 0.0
		rubber_level = clampf(rubber_level + (0.012 if race_state == "GREEN FLAG" else 0.0), 0.0, 1.0)
		track_grip = clampf(0.90 + rubber_level * 0.11, 0.90, 1.05)
		return
	var previous_weather := weather_state
	var rain_chance := float(forecast.get("rain_chance", 0)) / 100.0
	var race_progress := float(current_lap) / maxf(1.0, float(race_distance_laps))
	var change_chance := 0.035 + (0.06 if str(forecast.get("weather", "")) == "Mixed" else 0.0)
	if random_number_generator.randf() < change_chance:
		if random_number_generator.randf() < rain_chance:
			rain_intensity = clampf(rain_intensity + random_number_generator.randf_range(0.16, 0.38), 0.0, 1.0)
		else:
			rain_intensity = clampf(rain_intensity - random_number_generator.randf_range(0.14, 0.30), 0.0, 1.0)
	else:
		var drying := 0.018 + track_temperature * 0.0006
		rain_intensity = maxf(0.0, rain_intensity - drying)
	weather_state = "Wet" if rain_intensity >= 0.45 else ("Damp" if rain_intensity >= 0.08 else "Dry")
	rubber_level = clampf(rubber_level + (0.012 if weather_state == "Dry" and race_state == "GREEN FLAG" else -0.018), 0.0, 1.0)
	var evolved_grip := 0.90 + rubber_level * 0.11 + race_progress * 0.02
	track_grip = clampf(evolved_grip - rain_intensity * 0.34, 0.58, 1.05)
	if weather_state != previous_weather:
		event_log.append("LAP %d  WEATHER — conditions change to %s; track grip is %d%%." % [current_lap, weather_state.to_upper(), roundi(track_grip * 100.0)])
		weather_timeline.append({"lap":current_lap, "weather":weather_state, "rain":rain_intensity, "grip":track_grip})


func _record_replay_snapshot() -> void:
	var positions: Array[Dictionary] = []
	for entry in entries:
		positions.append({"driver_id":entry.driver_id, "driver":entry.driver_name, "position":entry.position, "status":entry.status, "compound":entry.tyre_compound, "pit_stops":entry.pit_stops})
	replay_timeline.append({"lap":current_lap, "flag":race_state, "weather":weather_state, "grip":track_grip, "positions":positions})


func _record_player_telemetry() -> void:
	var player := get_player_entry()
	if player == null:
		return
	var comparisons: Array[Dictionary] = []
	for entry in entries:
		if entry == player:
			continue
		if entry.team_name == player.team_name or abs(entry.position - player.position) <= 1:
			comparisons.append({
				"driver_id":entry.driver_id,
				"driver_name":entry.driver_name,
				"team_name":entry.team_name,
				"position":entry.position,
				"gap":entry.elapsed_time - player.elapsed_time,
				"lap_time":entry.last_lap_time,
				"best_lap":entry.best_lap_time,
				"tyre":entry.tyre_condition,
				"fuel":entry.fuel_remaining,
				"teammate":entry.team_name == player.team_name
			})
	telemetry_history.append({
		"lap":current_lap,
		"lap_time":player.last_lap_time,
		"position":player.position,
		"tyre":player.tyre_condition,
		"tyre_temperature":player.tyre_temperature,
		"fuel":player.fuel_remaining,
		"fuel_laps":player.fuel_laps / maxf(0.1, race.fuel_consumption_factor),
		"stint":player.pit_stops,
		"stint_laps":player.stint_laps,
		"flag":race_state,
		"comparisons":comparisons
	})


func _update_track_state() -> void:
	if race_state == "SAFETY CAR":
		var remaining := int(get_meta("caution_laps", 1)) - 1
		set_meta("caution_laps", remaining)
		if remaining <= 0:
			_record_caution_outcome()
			race_state = "RESTART"
			event_log.append("LAP %d  Pace car is in; restart next lap." % current_lap)
	elif race_state == "RESTART":
		race_state = "GREEN FLAG"
		event_log.append("LAP %d  GREEN FLAG — the field accelerates." % current_lap)


func _pace_data(entry: RaceEntryState) -> Dictionary:
	var wear := 100.0 / maxf(12.0, float(race.lap_count) * 0.72)
	wear *= race.tyre_wear_factor * lerpf(1.18, 0.72, entry.rating("tyre_management", roundi(entry.tyre_preservation)) / 100.0)
	wear *= 1.0 + (100.0 - float(entry.component_health.get("suspension", 100.0))) * 0.006
	var result := {"mode": 0.0, "compound": 0.0, "wear": wear, "fuel": 1.0}
	if entry.pace_mode == "Conserve": result.merge({"mode": 0.32, "wear": float(result.wear) * 0.72, "fuel": 0.88}, true)
	elif entry.pace_mode == "Attack": result.merge({"mode": -0.28, "wear": float(result.wear) * 1.38, "fuel": 1.12}, true)
	if entry.fuel_target_mode == "Save": result.mode = float(result.mode) + 0.18
	elif entry.fuel_target_mode == "Push": result.mode = float(result.mode) - 0.10
	if race_state != "GREEN FLAG":
		result.wear = float(result.wear) * 0.35
		result.fuel = float(result.fuel) * 0.55
	return result


func _resolve_incident(entry: RaceEntryState) -> float:
	var pace_risk: float = float({"Conserve": 0.70, "Balanced": 1.0, "Attack": 1.65}.get(entry.pace_mode, 1.0))
	var traffic_risk := 1.0 + race.overtaking_difficulty * (0.5 if entry.position > 1 else 0.0)
	var control := (entry.rating("consistency") + entry.rating("composure") + (entry.rating("wet_weather") if weather_state != "Dry" else 50)) / 3.0
	var weather_risk := 1.0 + rain_intensity * 1.2
	var command_risk: float = float({"Conserve":0.72, "Race":1.0, "Overtake":1.30, "Defend":1.18}.get(entry.racecraft_command, 1.0))
	var incident_chance: float = 0.0015 * race.accident_factor * pace_risk * traffic_risk * weather_risk * command_risk * lerpf(1.45, 0.55, control / 100.0) * entry.difficulty_scale
	var weakest_component_health := _weakest_component_health(entry)
	var health_risk := lerpf(0.45, 4.8, 1.0 - minf(entry.mechanical_health, weakest_component_health) / 100.0)
	var failure_chance: float = 0.0006 * race.mechanical_stress * pace_risk * lerpf(1.8, 0.35, entry.reliability / 100.0) * health_risk * entry.difficulty_scale
	if random_number_generator.randf() < failure_chance:
		_apply_component_damage(entry, _weakest_component(entry), 100.0)
		entry.status = "Retired"
		entry.retired_lap = current_lap
		entry.car_condition = 0.0
		entry.elapsed_time = INF
		event_log.append("LAP %d  DNF — %s retires with mechanical trouble after warning signs." % [current_lap, entry.driver_name])
		_trigger_caution()
		return 0.0
	if random_number_generator.randf() < incident_chance:
		var severe := random_number_generator.randf() < 0.12
		if severe:
			_apply_component_damage(entry, _incident_component(), random_number_generator.randf_range(55.0, 100.0))
			_apply_component_damage(entry, _incident_component(), random_number_generator.randf_range(25.0, 60.0))
			entry.status = "Retired"
			entry.retired_lap = current_lap
			entry.elapsed_time = INF
			event_log.append("LAP %d  CONTACT — %s is out of the race." % [current_lap, entry.driver_name])
			_trigger_caution()
			return 0.0
		var loss := random_number_generator.randf_range(2.0, 7.0)
		var damaged_component := _incident_component()
		var damage_amount := random_number_generator.randf_range(6.0, 22.0)
		_apply_component_damage(entry, damaged_component, damage_amount)
		entry.car_condition = maxf(1.0, entry.car_condition - random_number_generator.randf_range(3.0, 12.0))
		entry.incident_time_loss += loss
		event_log.append("LAP %d  %s spins in traffic, damages the %s and loses %.1fs." % [current_lap, entry.driver_name, damaged_component, loss])
		if entry.is_player:
			race_events.append({"lap":current_lap, "type":"damage", "title":"%s damage" % damaged_component.capitalize(), "detail":"Contact cost %.1fs and reduced %s health to %d%%." % [loss, damaged_component, roundi(float(entry.component_health[damaged_component]))]})
		return loss
	return 0.0


func _incident_component() -> String:
	var weights := ["aerodynamics", "aerodynamics", "suspension", "suspension", "brakes", "drivetrain", "engine"]
	return weights[random_number_generator.randi_range(0, weights.size() - 1)]


func _apply_component_damage(entry: RaceEntryState, component: String, amount: float) -> void:
	entry.component_health[component] = maxf(0.0, float(entry.component_health.get(component, 100.0)) - amount)
	entry.mechanical_health = _average_component_health(entry)


func _average_component_health(entry: RaceEntryState) -> float:
	var total := 0.0
	for component in Car.DAMAGE_COMPONENTS:
		total += float(entry.component_health.get(component, 100.0))
	return total / float(Car.DAMAGE_COMPONENTS.size())


func _weakest_component(entry: RaceEntryState) -> String:
	var weakest := "engine"
	for component in Car.DAMAGE_COMPONENTS:
		if float(entry.component_health.get(component, 100.0)) < float(entry.component_health.get(weakest, 100.0)):
			weakest = component
	return weakest


func _weakest_component_health(entry: RaceEntryState) -> float:
	return float(entry.component_health.get(_weakest_component(entry), 100.0))


func _component_performance_penalty(entry: RaceEntryState) -> float:
	var aero_damage := 1.0 - float(entry.component_health.get("aerodynamics", 100.0)) / 100.0
	var suspension_damage := 1.0 - float(entry.component_health.get("suspension", 100.0)) / 100.0
	var engine_damage := 1.0 - float(entry.component_health.get("engine", 100.0)) / 100.0
	var brake_damage := 1.0 - float(entry.component_health.get("brakes", 100.0)) / 100.0
	var drivetrain_damage := 1.0 - float(entry.component_health.get("drivetrain", 100.0)) / 100.0
	return aero_damage * (0.55 + race.power_demand * 0.45) + suspension_damage * (0.45 + race.handling_demand * 0.70) + engine_damage * (0.55 + race.power_demand * 0.90) + brake_damage * (0.30 + race.handling_demand * 0.55) + drivetrain_damage * 0.85


func _trigger_caution() -> void:
	if race_state == "GREEN FLAG":
		race_state = "SAFETY CAR"
		caution_count += 1
		caution_start_positions.clear()
		for entry in entries:
			caution_start_positions[_entry_key(entry)] = entry.position
		set_meta("caution_laps", random_number_generator.randi_range(2, 4))
		race_events.append({"lap":current_lap, "type":"caution", "title":"Caution %d" % caution_count, "detail":"Field compressed and pit lane opened."})
		if current_lap >= race_distance_laps - 2 and overtime_attempts < max_overtime_attempts:
			overtime_attempts += 1
			race_distance_laps = maxi(race_distance_laps, current_lap + 2)
			event_log.append("LAP %d  OVERTIME - distance extended to %d laps for a two-lap finish." % [current_lap, race_distance_laps])
			race_events.append({"lap":current_lap, "type":"overtime", "title":"Overtime attempt %d" % overtime_attempts, "detail":"Race distance extended to %d laps." % race_distance_laps})
		_generate_engineer_advice("caution")
		event_log.append("LAP %d  YELLOW FLAG — safety car deployed; pit loss is reduced." % current_lap)
		caution_started.emit(current_lap)


func _record_caution_outcome() -> void:
	var player := get_player_entry()
	if player == null or caution_start_positions.is_empty():
		return
	var start_position := int(caution_start_positions.get(_entry_key(player), player.position))
	var gain := start_position - player.position
	player.caution_position_gain += gain
	race_events.append({
		"lap":current_lap, "type":"caution_outcome", "title":"Caution cycle",
		"detail":"Rejoined P%d (%+d positions across the caution)." % [player.position, gain], "position_delta":gain
	})
	caution_start_positions.clear()


func _traffic_penalty(entry: RaceEntryState) -> float:
	if race_state != "GREEN FLAG" or entry.position <= 1: return 0.0
	var ahead := entries[entry.position - 2]
	if entry.elapsed_time - ahead.elapsed_time < 1.0:
		var dirty_air := lerpf(0.48, 0.12, entry.rating("racecraft") / 100.0) + (100.0 - float(entry.component_health.get("aerodynamics", 100.0))) * 0.0025
		var tyre_offset := maxf(0.0, ahead.tyre_condition - entry.tyre_condition) * 0.002
		var command_modifier := 0.76 if entry.racecraft_command == "Overtake" else (1.15 if entry.racecraft_command == "Conserve" else 1.0)
		return (race.overtaking_difficulty * dirty_air + tyre_offset) * command_modifier
	return 0.0


func _situational_rating(entry: RaceEntryState) -> float:
	var total := 0.0
	var weight_total := 0.0
	var weights := race.get_driver_attribute_weights()
	for field in weights:
		var weight := float(weights[field])
		total += entry.rating(field) * weight
		weight_total += weight
	if current_lap == 1 or race_state == "RESTART":
		total += entry.rating("starts_restarts") * 0.12
		weight_total += 0.12
	return total / maxf(weight_total, 0.01)


func _ai_should_pit(entry: RaceEntryState) -> bool:
	if current_lap >= race_distance_laps - 1: return false
	var remaining := race_distance_laps - current_lap
	var strategy_confidence := entry.strategy_skill / 100.0
	var projected_fuel_need := float(remaining) * race.fuel_consumption_factor
	var tyre_cliff := 16.0 + entry.aggression * 0.08 + lerpf(7.0, -3.0, strategy_confidence)
	var can_finish_on_tyres := entry.tyre_condition > tyre_cliff and entry.stint_laps < roundi(float(race.lap_count) * 0.72)
	if race_state == "SAFETY CAR":
		var cheap_stop_threshold := lerpf(78.0, 58.0, strategy_confidence) + entry.strategy_aggression * 24.0
		var next_window_fuel := minf(projected_fuel_need, float(race.lap_count) * race.fuel_consumption_factor * lerpf(0.28, 0.42, strategy_confidence))
		if entry.tyre_condition < cheap_stop_threshold or entry.fuel_laps < next_window_fuel:
			return true
	if entry.fuel_laps <= race.fuel_consumption_factor * lerpf(2.8, 1.6, strategy_confidence):
		return true
	if not can_finish_on_tyres:
		return true
	var traffic_window := entry.position > 1 and entry.gap_to(entries[entry.position - 2]) < 0.8
	return traffic_window and entry.tyre_condition < 42.0 + entry.strategy_aggression * 25.0 and random_number_generator.randf() < strategy_confidence * (0.08 + maxf(0.0, entry.strategy_aggression) * 0.25)


func _update_ai_strategy(entry: RaceEntryState) -> void:
	var remaining := maxi(0, race_distance_laps - current_lap)
	var projected_need := float(remaining) * race.fuel_consumption_factor
	var can_finish := entry.fuel_laps >= projected_need
	if not can_finish and entry.fuel_laps <= race.fuel_consumption_factor * 3.2:
		entry.pending_pace_mode = "Conserve"
	elif entry.tyre_condition < 24.0 or entry.mechanical_health < 42.0:
		entry.pending_pace_mode = "Conserve"
	elif race_state == "RESTART" and entry.tyre_condition > 48.0:
		entry.pending_pace_mode = "Attack" if entry.aggression + entry.strategy_skill + entry.strategy_aggression * 80.0 > 105.0 else "Balanced"
	elif remaining < maxi(4, race.lap_count / 8) and can_finish and entry.fuel_laps - projected_need > 0.8 and entry.tyre_condition > 38.0:
		entry.pending_pace_mode = "Attack"
	else:
		entry.pending_pace_mode = "Balanced"


func _update_crew_chief_strategy(entry: RaceEntryState) -> void:
	var previous_pace := entry.pending_pace_mode
	var previous_fuel := entry.fuel_target_mode
	var previous_racecraft := entry.racecraft_command
	_update_ai_strategy(entry)
	var remaining := maxi(0, race_distance_laps - current_lap)
	var projected_need := float(remaining) * race.fuel_consumption_factor
	if entry.fuel_laps < projected_need + race.fuel_consumption_factor * 0.8:
		entry.fuel_target_mode = "Save"
	elif remaining <= maxi(4, race.lap_count / 8) and entry.fuel_laps > projected_need + race.fuel_consumption_factor * 1.8:
		entry.fuel_target_mode = "Push"
	else:
		entry.fuel_target_mode = "Balanced"
	if entry.mechanical_health < 48.0 or entry.tyre_condition < 24.0:
		entry.racecraft_command = "Conserve"
	elif entry.position > 1 and entry.gap_to(entries[entry.position - 2]) < 0.9 and entry.tyre_condition > 34.0:
		entry.racecraft_command = "Overtake"
	elif entry.position < entries.size() and entries[entry.position].gap_to(entry) < 0.75:
		entry.racecraft_command = "Defend"
	else:
		entry.racecraft_command = "Race"
	if current_lap <= 1:
		return
	var changes: Array[String] = []
	if entry.pending_pace_mode != previous_pace:
		changes.append("pace %s" % entry.pending_pace_mode.to_lower())
	if entry.fuel_target_mode != previous_fuel:
		changes.append("fuel %s" % entry.fuel_target_mode.to_lower())
	if entry.racecraft_command != previous_racecraft:
		changes.append("driver %s" % entry.racecraft_command.to_lower())
	if not changes.is_empty():
		_record_crew_chief_call(entry, "Strategy adjusted", ", ".join(changes).capitalize(), "info")


func _crew_pit_reason(entry: RaceEntryState) -> String:
	var remaining := maxi(0, race_distance_laps - current_lap)
	if _weakest_component_health(entry) < 60.0:
		return "%s damage requires attention" % _weakest_component(entry).capitalize()
	if entry.fuel_laps < float(remaining) * race.fuel_consumption_factor:
		return "Fuel cannot reach the finish"
	if race_state == "SAFETY CAR":
		return "Reduced loss under caution"
	return "Tyres have reached the planned service window"


func _record_crew_chief_call(
	entry: RaceEntryState,
	title: String,
	detail: String,
	severity: String
) -> void:
	var call := {
		"lap": current_lap,
		"driver_id": entry.driver_id,
		"driver_name": entry.driver_name,
		"team_id": entry.team_id,
		"title": title,
		"detail": detail,
		"severity": severity,
	}
	crew_chief_calls.append(call)
	if crew_chief_calls.size() > 40:
		crew_chief_calls.pop_front()
	strategy_timeline.append({
		"lap": current_lap,
		"type": "crew_call",
		"title": "%s: %s" % [entry.driver_name, title],
		"detail": detail,
	})
	event_log.append("LAP %d  %s / %s — %s: %s" % [current_lap, crew_controller_label.to_upper(), entry.driver_name, title, detail])
	crew_chief_call_issued.emit(call.duplicate(true))


func _resolve_overtaking_battles() -> void:
	if race_state != "GREEN FLAG":
		return
	var active_entries: Array[RaceEntryState] = []
	for entry in entries:
		if entry.status != "Retired":
			active_entries.append(entry)
	for index in range(1, active_entries.size()):
		var chaser := active_entries[index]
		var ahead := active_entries[index - 1]
		var gap := chaser.elapsed_time - ahead.elapsed_time
		if gap < -0.01:
			chaser.overtakes += 1
			ahead.overtaken += 1
			continue
		if gap > 1.35:
			continue
		var pace_advantage := clampf((chaser.base_pace - ahead.base_pace) * 0.025, -0.12, 0.18)
		var racecraft := float(chaser.rating("racecraft")) / 100.0
		var tyre_advantage := clampf((chaser.tyre_condition - ahead.tyre_condition) * 0.008, -0.15, 0.22)
		var aggression_bonus := (float(chaser.aggression) - 50.0) * 0.002
		var track_window := lerpf(0.34, 0.10, race.overtaking_difficulty)
		var command_bonus := 0.12 if chaser.racecraft_command == "Overtake" else (-0.06 if chaser.racecraft_command == "Conserve" else 0.0)
		var defence_penalty := 0.11 if ahead.racecraft_command == "Defend" else 0.0
		if chaser.team_name == ahead.team_name and chaser.team_order == "Swap positions":
			command_bonus += 0.62
			defence_penalty = 0.0
		elif chaser.team_name == ahead.team_name and chaser.team_order == "Hold position":
			command_bonus -= 0.30
		var grip_window := lerpf(0.65, 1.05, track_grip)
		var brake_health := float(chaser.component_health.get("brakes", 100.0)) / 100.0
		var pass_chance := clampf((track_window + pace_advantage + tyre_advantage + aggression_bonus + command_bonus - defence_penalty + (racecraft - 0.5) * 0.18) * grip_window * lerpf(0.65, 1.0, brake_health), 0.02, 0.78)
		if random_number_generator.randf() >= pass_chance:
			continue
		chaser.elapsed_time = minf(chaser.elapsed_time, ahead.elapsed_time - 0.04)
		ahead.elapsed_time += 0.04
		chaser.overtakes += 1
		ahead.overtaken += 1
		if chaser.is_player or ahead.is_player:
			race_events.append({"lap":current_lap, "type":"pass", "title":"Decisive pass", "detail":"%s passed %s for P%d." % [chaser.driver_name, ahead.driver_name, index]})
		if chaser.is_player or ahead.is_player:
			event_log.append("LAP %d  PASS — %s gets by %s after a close battle." % [current_lap, chaser.driver_name, ahead.driver_name])


func _compress_field_under_caution() -> void:
	var active_index := 0
	var leader_time := 0.0
	for entry in entries:
		if entry.status == "Retired":
			continue
		if active_index == 0:
			leader_time = entry.elapsed_time
		else:
			entry.elapsed_time = minf(entry.elapsed_time, leader_time + float(active_index) * 0.28)
		active_index += 1


func _update_mechanical_health(entry: RaceEntryState, pace_data: Dictionary) -> void:
	var pace_stress := float({"Conserve": 0.72, "Balanced": 1.0, "Attack": 1.48}.get(entry.pace_mode, 1.0))
	if race_state != "GREEN FLAG":
		pace_stress *= 0.45
	var reliability_factor := lerpf(1.65, 0.45, entry.reliability / 100.0)
	var damage_factor := lerpf(1.7, 1.0, entry.car_condition / 100.0)
	var loss := (0.025 + race.mechanical_stress * 0.12 * reliability_factor) * pace_stress * damage_factor
	loss *= 1.0 + maxf(0.0, float(pace_data.fuel) - 1.0) * 0.5
	var stress_component := "engine" if race.power_demand >= race.handling_demand else "suspension"
	if entry.brake_bias == "Forward":
		stress_component = "brakes"
	elif entry.brake_bias == "Rearward":
		stress_component = "drivetrain"
	_apply_component_damage(entry, stress_component, loss * 0.48)
	entry.mechanical_health = maxf(0.0, _average_component_health(entry) - loss * 0.12)
	var warning_level := 2 if entry.mechanical_health < 32.0 else (1 if entry.mechanical_health < 58.0 else 0)
	if warning_level > entry.mechanical_warning_level:
		entry.mechanical_warning_level = warning_level
		if entry.is_player:
			var message := "critical" if warning_level == 2 else "elevated"
			event_log.append("LAP %d  ENGINEER WARNING — system temperatures are %s; reduce stress." % [current_lap, message])


func _update_tyre_temperature(entry: RaceEntryState) -> void:
	var compound_target: float = 92.0
	var mode_offset: float = float({"Conserve": -7.0, "Balanced": 0.0, "Attack": 8.0}.get(entry.pace_mode, 0.0))
	var track_offset := race.heat_factor * 10.0 + (track_temperature - 24.0) * 0.25 - rain_intensity * 12.0
	var target := float(compound_target) + float(mode_offset) + track_offset
	if race_state != "GREEN FLAG":
		target -= 18.0
	entry.tyre_temperature = lerpf(entry.tyre_temperature, target, 0.24)


func _tyre_performance_penalty(entry: RaceEntryState) -> float:
	var wear_penalty := pow(1.0 - entry.tyre_condition / 100.0, 2.0) * 2.4
	var cliff_penalty := pow(maxf(0.0, 18.0 - entry.tyre_condition) / 18.0, 2.0) * 3.2
	var ideal_temperature := 92.0
	var temperature_penalty := pow(absf(entry.tyre_temperature - ideal_temperature) / 18.0, 2.0) * 0.45
	var stint_penalty := maxf(0.0, float(entry.stint_laps) / maxf(8.0, float(race.lap_count) * 0.55) - 1.0) * 0.35
	var weather_penalty := 0.0
	if rain_intensity >= 0.45:
		weather_penalty = 2.6 + rain_intensity * 2.2
	elif rain_intensity >= 0.08:
		weather_penalty = 1.15
	return wear_penalty + cliff_penalty + temperature_penalty + stint_penalty + weather_penalty + maxf(0.0, 0.92 - track_grip) * 2.0


func _sort_standings() -> void:
	entries.sort_custom(func(first: RaceEntryState, second: RaceEntryState) -> bool:
		if first.status == "Retired" and second.status != "Retired": return false
		if first.status != "Retired" and second.status == "Retired": return true
		if first.status == "Retired": return first.completed_laps > second.completed_laps
		return first.elapsed_time < second.elapsed_time)
	for index in range(entries.size()): entries[index].position = index + 1


func get_player_entry() -> RaceEntryState:
	for entry in entries:
		if entry.is_player:
			return entry
	return null


func get_player_entries() -> Array[RaceEntryState]:
	var player_entries: Array[RaceEntryState] = []
	for entry in entries:
		if entry.is_player:
			player_entries.append(entry)
	return player_entries


func set_crew_chief_automation(enabled: bool, controller_label: String = "Crew chief") -> void:
	var starting_automation := enabled and not automated_player_crew
	automated_player_crew = enabled
	crew_controller_label = controller_label
	if not starting_automation:
		return
	for entry in get_player_entries():
		_record_crew_chief_call(
			entry,
			"Race plan active",
			"The %s will manage pace, fuel, traffic, cautions, and pit service." % crew_controller_label.to_lower(),
			"info"
		)


func _entry_key(entry: RaceEntryState) -> String:
	return entry.driver_id if not entry.driver_id.is_empty() else entry.driver_name


func set_player_pace(mode: String) -> void:
	var player := get_player_entry()
	if player != null and mode in ["Conserve", "Balanced", "Attack"]:
		player.pending_pace_mode = mode
		event_log.append("LAP %d  Pit wall: %s mode requested for next lap." % [current_lap, mode])


func set_player_fuel_target(mode: String) -> void:
	var player := get_player_entry()
	if player != null and mode in ["Save", "Balanced", "Push"]:
		player.fuel_target_mode = mode
		event_log.append("LAP %d  Fuel target set to %s." % [current_lap, mode])


func set_player_racecraft_command(command: String) -> void:
	var player := get_player_entry()
	if player != null and command in ["Conserve", "Race", "Overtake", "Defend"]:
		player.racecraft_command = command
		event_log.append("LAP %d  Driver command: %s." % [current_lap, command])


func set_team_order(order: String, team_name: String) -> void:
	for entry in entries:
		if entry.team_name != team_name:
			continue
		entry.team_order = order
		if order == "Hold position":
			entry.racecraft_command = "Conserve"
		elif order == "Swap positions":
			entry.racecraft_command = "Overtake" if not entry.is_player else "Race"
		elif order == "Help lead car":
			entry.racecraft_command = "Defend" if not entry.is_player else "Race"
		elif order == "Conserve equipment":
			entry.pending_pace_mode = "Conserve"
			entry.racecraft_command = "Conserve"
	event_log.append("LAP %d  Team order issued: %s." % [current_lap, order])


func request_player_pit_stop(service: Variant = {}) -> bool:
	var player := get_player_entry()
	if player == null or is_complete:
		return false
	var normalized := normalize_pit_service(service)
	player.pending_pit_compound = "Standard"
	player.pending_pit_service = normalized
	strategy_timeline.append({
		"lap":current_lap, "type":"call", "title":"Pit call",
		"detail":"Called %s for the next lap." % describe_pit_service(normalized), "service":normalized.duplicate(true)
	})
	event_log.append("LAP %d  Pit wall: box next lap for fresh tyres." % current_lap)
	return true


func predict_player_pit_loss(service: Variant = {}) -> Dictionary:
	var player := get_player_entry()
	if player == null:
		return {}
	var normalized := normalize_pit_service(service)
	var tyre_count := int(normalized.tyres)
	var estimated_loss := race.pit_lane_time_loss + 1.4
	estimated_loss += 2.2 if tyre_count == 2 else (4.1 if tyre_count >= 4 else 0.0)
	if bool(normalized.fuel):
		estimated_loss += 1.5
	if bool(normalized.repairs):
		estimated_loss += 5.5
	if race_state == "SAFETY CAR":
		estimated_loss *= 0.58
	estimated_loss = maxf(3.2, estimated_loss - player_pit_time_reduction)
	var likely_lost := 0
	for entry in entries:
		if entry.position <= player.position or entry.status == "Retired":
			continue
		if entry.elapsed_time - player.elapsed_time < estimated_loss:
			likely_lost += 1
	var uncertainty := ceili(lerpf(3.0, 0.5, player_engineer_quality / 100.0))
	var minimum_lost := maxi(0, likely_lost - uncertainty)
	var maximum_lost := mini(entries.size() - player.position, likely_lost + uncertainty)
	return {
		"time_loss":estimated_loss,
		"likely_positions_lost":likely_lost,
		"minimum_positions_lost":minimum_lost,
		"maximum_positions_lost":maximum_lost,
		"likely_rejoin_position":mini(entries.size(), player.position + likely_lost),
		"confidence":roundi(lerpf(52.0, 94.0, player_engineer_quality / 100.0))
	}


func request_player_wave_around() -> Dictionary:
	var player := get_player_entry()
	if player == null or race_state != "SAFETY CAR":
		return {"success":false, "message":"Wave-around is only available under caution."}
	var gained_lap := player.laps_down > 0
	if gained_lap:
		player.laps_down -= 1
	var message := "Wave-around taken; one lap recovered without service." if gained_lap else "Stayed out to protect lead-lap track position."
	strategy_timeline.append({"lap":current_lap, "type":"caution_call", "title":"Wave-around / stay out", "detail":message})
	event_log.append("LAP %d  Pit wall: %s" % [current_lap, message])
	return {"success":true, "gained_lap":gained_lap, "message":message}


func get_total_laps() -> int:
	return race_distance_laps if race_distance_laps > 0 else (race.lap_count if race != null else 0)


func request_engineer_update() -> Dictionary:
	_generate_engineer_advice("request")
	return latest_engineer_advice


func _generate_engineer_advice(trigger: String) -> void:
	var player := get_player_entry()
	if player == null:
		return
	var remaining := maxi(0, get_total_laps() - current_lap)
	var fuel_laps := player.fuel_laps / maxf(0.1, race.fuel_consumption_factor)
	var fuel_shortfall := float(remaining) - fuel_laps
	var weakest := _weakest_component(player)
	var weakest_health := _weakest_component_health(player)
	var window_center := clampi(current_lap + roundi(maxf(1.0, minf(fuel_laps, player.tyre_condition * 0.36))), current_lap, get_total_laps())
	var true_recommendation := "STAY OUT"
	if player.tyre_condition < 38.0 or fuel_shortfall > 1.0 or weakest_health < 48.0:
		true_recommendation = "PIT"
	if race_state == "SAFETY CAR" and (player.tyre_condition < 68.0 or fuel_shortfall > -3.0 or weakest_health < 70.0):
		true_recommendation = "PIT"
	var error_chance := clampf(0.36 - player_engineer_quality * 0.0033, 0.035, 0.30)
	var wrong := random_number_generator.randf() < error_chance
	var recommendation := ("PIT" if true_recommendation == "STAY OUT" else "STAY OUT") if wrong else true_recommendation
	var confidence := clampi(roundi(player_engineer_quality * 0.62 + random_number_generator.randf_range(20.0, 36.0)), 35, 96)
	var category_index := int(current_lap / maxi(1, race.lap_count / 7)) % 5
	var category: String = ["pit_window", "fuel", "traffic", "tyres", "mechanical"][category_index]
	if trigger == "caution":
		category = "caution"
	var telemetry_error := lerpf(9.0, 0.8, player_engineer_quality / 100.0)
	var reported_tyres := clampi(roundi(player.tyre_condition + random_number_generator.randf_range(-telemetry_error, telemetry_error)), 0, 100)
	var reported_fuel := maxf(0.0, fuel_laps + random_number_generator.randf_range(-telemetry_error * 0.09, telemetry_error * 0.09))
	var message := "Window estimate laps %d-%d. Recommendation: %s." % [maxi(current_lap, window_center - 2), mini(get_total_laps(), window_center + 2), recommendation]
	match category:
		"fuel":
			message = "Fuel estimate %.1f laps for %d remaining. Target %s; %s." % [reported_fuel, remaining, "SAVE" if fuel_shortfall > 0.0 else "BALANCED", recommendation]
		"traffic":
			var prediction := predict_player_pit_loss(get_pit_service_options().four_tyres_fuel)
			message = "Traffic model projects P%d after a four-tyre stop, range P%d-P%d. %s." % [int(prediction.get("likely_rejoin_position", player.position)), player.position + int(prediction.get("minimum_positions_lost", 0)), player.position + int(prediction.get("maximum_positions_lost", 0)), recommendation]
		"tyres":
			message = "Tyre model reports %d%% life; performance cliff expected in about %d laps. %s." % [reported_tyres, maxi(0, roundi((player.tyre_condition - 18.0) / maxf(0.1, 100.0 / maxf(12.0, float(race.lap_count) * 0.72)))), recommendation]
		"mechanical":
			message = "%s is the limiting system at %d%%. %s%s." % [weakest.capitalize(), roundi(weakest_health), "Quick repairs advised; " if weakest_health < 62.0 else "Risk is manageable; ", recommendation]
		"caution":
			var caution_prediction := predict_player_pit_loss(get_pit_service_options().four_tyres_fuel)
			message = "Caution call: %s. Four tyres + fuel projects P%d with %d%% confidence." % [recommendation, int(caution_prediction.get("likely_rejoin_position", player.position)), int(caution_prediction.get("confidence", confidence))]
	latest_engineer_advice = {
		"lap":current_lap, "trigger":trigger, "category":category, "message":message,
		"recommendation":recommendation, "confidence":confidence, "staff_quality":roundi(player_engineer_quality),
		"was_accurate":not wrong, "uncertain":confidence < 70
	}
	engineer_advice_history.append(latest_engineer_advice.duplicate(true))
	strategy_timeline.append({"lap":current_lap, "type":"radio", "title":"Engineer: %s" % category.capitalize(), "detail":message, "confidence":confidence, "accurate":not wrong})
	event_log.append("LAP %d  RADIO [%d%%]: %s" % [current_lap, confidence, message])
	engineer_advice_ready.emit(latest_engineer_advice)


func set_player_brake_bias(mode: String) -> void:
	var player := get_player_entry()
	if player != null and mode in ["Forward", "Neutral", "Rearward"]:
		player.brake_bias = mode
		event_log.append("LAP %d  Brake bias adjusted to %s." % [current_lap, mode])


func _perform_pit_stop(entry: RaceEntryState, service: Dictionary) -> float:
	var normalized := normalize_pit_service(service)
	entry.pending_pit_compound = ""
	entry.pending_pit_service.clear()
	entry.tyre_compound = "Standard"
	var tyre_count := int(normalized.tyres)
	if tyre_count >= 4:
		entry.tyre_condition = 100.0
		entry.stint_laps = 0
		entry.tyre_temperature = 78.0
	elif tyre_count == 2:
		entry.tyre_condition = maxf(entry.tyre_condition, 82.0)
		entry.stint_laps = roundi(float(entry.stint_laps) * 0.45)
		entry.tyre_temperature = 82.0
	entry.last_pit_lap = current_lap
	var fuel_added := 0.0
	if bool(normalized.fuel):
		var fuel_margin := lerpf(1.08, 1.025, entry.strategy_skill / 100.0)
		var remaining_laps := race_distance_laps - current_lap
		var planned_stint := mini(remaining_laps, maxi(6, roundi(float(race.lap_count) * lerpf(0.34, 0.48, entry.strategy_skill / 100.0))))
		if remaining_laps <= roundi(float(race.lap_count) * 0.55):
			planned_stint = remaining_laps
		var fuel_target := float(planned_stint) * race.fuel_consumption_factor * fuel_margin
		fuel_added = maxf(0.0, fuel_target - entry.fuel_laps)
		entry.fuel_laps += fuel_added
		entry.fuel_target_laps = maxf(entry.fuel_laps, fuel_target)
		entry.fuel_remaining = clampf(entry.fuel_laps / maxf(1.0, entry.fuel_target_laps) * 100.0, 0.0, 100.0)
	var repair_gain := 0.0
	if bool(normalized.repairs):
		repair_gain = _perform_quick_repairs(entry)
	entry.pit_stops += 1
	var service_time := 1.4
	if tyre_count == 2:
		service_time += 2.2
	elif tyre_count >= 4:
		service_time += 4.1
	if bool(normalized.fuel):
		service_time += clampf(fuel_added / maxf(0.1, race.fuel_consumption_factor) * 0.06, 0.5, 2.4)
	if bool(normalized.repairs):
		service_time += 5.5
	var pit_loss := race.pit_lane_time_loss + service_time + random_number_generator.randf_range(-0.6, 0.6)
	if race_state == "SAFETY CAR":
		pit_loss *= 0.58
	if entry.is_player:
		pit_loss = maxf(3.2, pit_loss - player_pit_time_reduction)
		var mistake_chance := maxf(0.01, 0.12 - player_pit_mistake_reduction / 100.0)
		if random_number_generator.randf() < mistake_chance:
			pit_loss += random_number_generator.randf_range(1.0, 2.5)
			event_log.append("LAP %d  A pit-crew mistake costs valuable time." % current_lap)
		strategy_timeline.append({
			"lap":current_lap, "type":"stop", "title":"Actual stop %d" % entry.pit_stops,
			"detail":"%s, %.1fs loss%s" % [describe_pit_service(normalized), pit_loss, ", %.0f repair points recovered" % repair_gain if repair_gain > 0.0 else ""],
			"loss":pit_loss, "service":normalized.duplicate(true)
		})
	event_log.append("LAP %d  %s pits: %s (%.1fs)." % [current_lap, entry.driver_name, describe_pit_service(normalized), pit_loss])
	return pit_loss


func normalize_pit_service(service: Variant) -> Dictionary:
	if service is String:
		return {"id":"four_tyres_fuel", "tyres":4, "fuel":true, "repairs":false}
	var data := service as Dictionary
	var service_id := str(data.get("id", "four_tyres_fuel"))
	var defaults := get_pit_service_options().get(service_id, get_pit_service_options().four_tyres_fuel) as Dictionary
	var normalized := defaults.duplicate(true)
	normalized.merge(data, true)
	return normalized


func get_pit_service_options() -> Dictionary:
	return {
		"four_tyres_fuel":{"id":"four_tyres_fuel", "label":"Four tyres + fuel", "tyres":4, "fuel":true, "repairs":false},
		"two_tyres_fuel":{"id":"two_tyres_fuel", "label":"Two tyres + fuel", "tyres":2, "fuel":true, "repairs":false},
		"fuel_only":{"id":"fuel_only", "label":"Fuel only", "tyres":0, "fuel":true, "repairs":false},
		"four_tyres_only":{"id":"four_tyres_only", "label":"Four tyres only", "tyres":4, "fuel":false, "repairs":false},
		"quick_repairs":{"id":"quick_repairs", "label":"Quick repairs + four tyres", "tyres":4, "fuel":true, "repairs":true}
	}


func describe_pit_service(service: Dictionary) -> String:
	return str(normalize_pit_service(service).get("label", "Four tyres + fuel"))


func _choose_ai_pit_service(entry: RaceEntryState) -> Dictionary:
	var fuel_need := entry.fuel_laps < float(race_distance_laps - current_lap) * race.fuel_consumption_factor
	var needs_repairs := _weakest_component_health(entry) < lerpf(45.0, 66.0, maxf(0.0, entry.reliability_bias))
	if needs_repairs and race_state == "SAFETY CAR":
		return get_pit_service_options().quick_repairs
	if entry.tyre_condition > 70.0 and fuel_need:
		return get_pit_service_options().fuel_only
	if entry.strategy_aggression > 0.10 and entry.tyre_condition > 42.0:
		return get_pit_service_options().two_tyres_fuel
	return get_pit_service_options().four_tyres_fuel


func _perform_quick_repairs(entry: RaceEntryState) -> float:
	var restored := 0.0
	for unused in 2:
		var component := _weakest_component(entry)
		var gain := minf(18.0, 88.0 - float(entry.component_health.get(component, 100.0)))
		if gain <= 0.0:
			break
		entry.component_health[component] = float(entry.component_health[component]) + gain
		restored += gain
	entry.mechanical_health = _average_component_health(entry)
	return restored


func _get_setup_modifier(entry: RaceEntryState) -> float:
	var preference_bonus := -0.10 if entry.setup_mode == race.preferred_setup else 0.08
	var practice_bonus := 0.0
	if not entry.setup_profile.is_empty():
		practice_bonus = -PracticeRunSimulator.setup_score(race, entry.setup_profile) * 0.0018
	match entry.setup_mode:
		"Top Speed":
			return preference_bonus + practice_bonus - race.power_demand * 0.12 + race.handling_demand * 0.08 + (100.0 - entry.tyre_condition) * 0.004
		"High Grip":
			return preference_bonus + practice_bonus - race.handling_demand * 0.12 + race.power_demand * 0.08 - (100.0 - entry.tyre_condition) * 0.004
		_:
			return preference_bonus + practice_bonus


func as_final_standings() -> Array[Dictionary]:
	var standings: Array[Dictionary] = []
	for entry in entries:
		standings.append({
			"driver_id": entry.driver_id,
			"driver_name": entry.driver_name,
			"team_id": entry.team_id,
			"team_name": entry.team_name,
			"starting_position": entry.starting_position,
			"score": -entry.elapsed_time,
			"status": entry.status,
			"incident_time_loss": entry.incident_time_loss,
			"traffic_time_loss": entry.traffic_time_loss,
			"overtakes": entry.overtakes,
			"overtaken": entry.overtaken,
			"pit_stops": entry.pit_stops,
			"best_lap_time": entry.best_lap_time,
			"tyre_condition": entry.tyre_condition,
			"mechanical_health": entry.mechanical_health,
			"component_health": entry.component_health.duplicate(true),
			"caution_position_gain": entry.caution_position_gain,
			"laps_down": entry.laps_down,
			"philosophy_id": entry.philosophy_id,
			"fuel_target": entry.fuel_target_mode,
			"racecraft_command": entry.racecraft_command,
			"team_order": entry.team_order,
			"is_player": entry.is_player
		})
	return standings
