class_name RaceSimulation
extends RefCounted

signal lap_completed(lap: int)
signal race_completed
signal caution_started(lap: int)

var race: Race
var current_lap: int = 0
var race_state: String = "GREEN FLAG"
var elapsed_race_time: float = 0.0
var entries: Array[RaceEntryState] = []
var event_log: Array[String] = []
var is_complete: bool = false
var caution_count: int = 0
var green_flag_laps: int = 0
var player_pit_time_reduction: float = 0.0
var player_pit_mistake_reduction: float = 0.0
var random_number_generator := RandomNumberGenerator.new()
var weather_state: String = "Dry"
var rain_intensity: float = 0.0
var track_grip: float = 0.92
var track_temperature: float = 24.0
var rubber_level: float = 0.0
var forecast: Dictionary = {}
var weather_timeline: Array[Dictionary] = []
var replay_timeline: Array[Dictionary] = []


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
		entry.difficulty_scale = float(data.get("difficulty_scale", 1.0))
		entry.base_pace = ai_scores[index]
		grid.append(entry)
	var player := RaceEntryState.new()
	player.driver_id = player_driver.driver_id
	player.driver_name = player_driver.driver_name
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
	player.difficulty_scale = float(player_attributes.get("incident_scale", 1.0))
	player_pit_time_reduction = float(player_attributes.get("pit_time_reduction", 0.0))
	player_pit_mistake_reduction = float(player_attributes.get("pit_mistake_reduction", 0.0))
	grid.insert(clampi(starting_position - 1, 0, grid.size()), player)
	for data_value in additional_team_entries:
		var data := data_value as Dictionary
		var teammate := RaceEntryState.new()
		teammate.driver_id = str(data.get("driver_id", ""))
		teammate.driver_name = str(data.get("driver_name", "Team Driver"))
		teammate.team_name = str(data.get("team_name", player_team_name))
		teammate.consistency = int(data.get("consistency", 50))
		teammate.attributes = data.get("attributes", {}).duplicate()
		teammate.base_pace = float(data.get("score", 50.0))
		teammate.tyre_compound = "Standard"
		teammate.reliability = float(data.get("reliability", player.reliability))
		teammate.fuel_efficiency = float(data.get("fuel_efficiency", player.fuel_efficiency))
		teammate.tyre_preservation = float(data.get("tyre_preservation", 50.0))
		teammate.strategy_skill = player.strategy_skill
		teammate.difficulty_scale = player.difficulty_scale
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
	event_log.append("LAP 0  The field takes the green flag.")


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
	var player := get_player_entry()
	var old_player_position := player.position if player != null else 0
	for entry in entries:
		if entry.status == "Retired":
			continue
		if not entry.is_player:
			_update_ai_strategy(entry)
		var pit_loss := 0.0
		if entry.is_player and not entry.pending_pit_compound.is_empty():
			pit_loss = _perform_pit_stop(entry, entry.pending_pit_compound)
		elif not entry.is_player and _ai_should_pit(entry):
			pit_loss = _perform_pit_stop(entry, _choose_ai_compound(entry))
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
		var mechanical_penalty := pow(1.0 - entry.mechanical_health / 100.0, 2.0) * 1.6
		var caution_delta := 4.5 if race_state != "GREEN FLAG" else 0.0
		var variance_limit := lerpf(0.55, 0.08, float(entry.rating("consistency", entry.consistency)) / 100.0)
		var late_race_penalty := maxf(0.0, float(current_lap) / race.lap_count - 0.65) * lerpf(0.55, 0.0, entry.rating("fitness") / 100.0) * (1.0 + race.heat_factor)
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
		if entry.fuel_laps <= 0.0 and current_lap < race.lap_count:
			entry.last_lap_time += 5.0
			entry.elapsed_time += 5.0
			if entry.is_player: event_log.append("LAP %d  FUEL CRITICAL — save immediately or pit." % current_lap)
	_resolve_overtaking_battles()
	_sort_standings()
	if race_state == "SAFETY CAR":
		_compress_field_under_caution()
		_sort_standings()
	player = get_player_entry()
	if player != null and player.status != "Retired" and player.position != old_player_position:
		event_log.append("LAP %d  %s is now P%d." % [current_lap, player.driver_name, player.position])
	if player != null and current_lap % maxi(4, race.lap_count / 8) == 0:
		event_log.append("LAP %d  Crew chief: tyres %d%%, fuel %.1f laps, car %d%%, systems %d%%." % [current_lap, roundi(player.tyre_condition), player.fuel_laps / maxf(0.1, race.fuel_consumption_factor), roundi(player.car_condition), roundi(player.mechanical_health)])
	_record_replay_snapshot()
	elapsed_race_time = entries[0].elapsed_time
	lap_completed.emit(current_lap)
	if current_lap >= race.lap_count:
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
	var race_progress := float(current_lap) / maxf(1.0, float(race.lap_count))
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


func _update_track_state() -> void:
	if race_state == "SAFETY CAR":
		var remaining := int(get_meta("caution_laps", 1)) - 1
		set_meta("caution_laps", remaining)
		if remaining <= 0:
			race_state = "RESTART"
			event_log.append("LAP %d  Pace car is in; restart next lap." % current_lap)
	elif race_state == "RESTART":
		race_state = "GREEN FLAG"
		event_log.append("LAP %d  GREEN FLAG — the field accelerates." % current_lap)


func _pace_data(entry: RaceEntryState) -> Dictionary:
	var wear := 100.0 / maxf(12.0, float(race.lap_count) * 0.72)
	wear *= race.tyre_wear_factor * lerpf(1.18, 0.72, entry.rating("tyre_management", roundi(entry.tyre_preservation)) / 100.0)
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
	var health_risk := lerpf(0.45, 4.8, 1.0 - entry.mechanical_health / 100.0)
	var failure_chance: float = 0.0006 * race.mechanical_stress * pace_risk * lerpf(1.8, 0.35, entry.reliability / 100.0) * health_risk * entry.difficulty_scale
	if random_number_generator.randf() < failure_chance:
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
			entry.status = "Retired"
			entry.retired_lap = current_lap
			entry.elapsed_time = INF
			event_log.append("LAP %d  CONTACT — %s is out of the race." % [current_lap, entry.driver_name])
			_trigger_caution()
			return 0.0
		var loss := random_number_generator.randf_range(2.0, 7.0)
		entry.car_condition = maxf(1.0, entry.car_condition - random_number_generator.randf_range(3.0, 12.0))
		entry.incident_time_loss += loss
		event_log.append("LAP %d  %s spins in traffic and loses %.1fs." % [current_lap, entry.driver_name, loss])
		return loss
	return 0.0


func _trigger_caution() -> void:
	if race_state == "GREEN FLAG":
		race_state = "SAFETY CAR"
		caution_count += 1
		set_meta("caution_laps", random_number_generator.randi_range(2, 4))
		event_log.append("LAP %d  YELLOW FLAG — safety car deployed; pit loss is reduced." % current_lap)
		caution_started.emit(current_lap)


func _traffic_penalty(entry: RaceEntryState) -> float:
	if race_state != "GREEN FLAG" or entry.position <= 1: return 0.0
	var ahead := entries[entry.position - 2]
	if entry.elapsed_time - ahead.elapsed_time < 1.0:
		var dirty_air := lerpf(0.48, 0.12, entry.rating("racecraft") / 100.0)
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
	if current_lap >= race.lap_count - 2: return false
	var remaining := race.lap_count - current_lap
	var strategy_confidence := entry.strategy_skill / 100.0
	var projected_fuel_need := float(remaining) * race.fuel_consumption_factor
	var tyre_cliff := 16.0 + entry.aggression * 0.08 + lerpf(7.0, -3.0, strategy_confidence)
	var can_finish_on_tyres := entry.tyre_condition > tyre_cliff and entry.stint_laps < roundi(float(race.lap_count) * 0.72)
	if race_state == "SAFETY CAR":
		var cheap_stop_threshold := lerpf(78.0, 58.0, strategy_confidence)
		var next_window_fuel := minf(projected_fuel_need, float(race.lap_count) * race.fuel_consumption_factor * lerpf(0.28, 0.42, strategy_confidence))
		if entry.tyre_condition < cheap_stop_threshold or entry.fuel_laps < next_window_fuel:
			return true
	if entry.fuel_laps <= race.fuel_consumption_factor * lerpf(2.8, 1.6, strategy_confidence):
		return true
	if not can_finish_on_tyres:
		return true
	var traffic_window := entry.position > 1 and entry.gap_to(entries[entry.position - 2]) < 0.8
	return traffic_window and entry.tyre_condition < 42.0 and random_number_generator.randf() < strategy_confidence * 0.08


func _update_ai_strategy(entry: RaceEntryState) -> void:
	var remaining := maxi(0, race.lap_count - current_lap)
	var projected_need := float(remaining) * race.fuel_consumption_factor
	var can_finish := entry.fuel_laps >= projected_need
	if not can_finish and entry.fuel_laps <= race.fuel_consumption_factor * 3.2:
		entry.pending_pace_mode = "Conserve"
	elif entry.tyre_condition < 24.0 or entry.mechanical_health < 42.0:
		entry.pending_pace_mode = "Conserve"
	elif race_state == "RESTART" and entry.tyre_condition > 48.0:
		entry.pending_pace_mode = "Attack" if entry.aggression + entry.strategy_skill > 105.0 else "Balanced"
	elif remaining < maxi(4, race.lap_count / 8) and can_finish and entry.fuel_laps - projected_need > 0.8 and entry.tyre_condition > 38.0:
		entry.pending_pace_mode = "Attack"
	else:
		entry.pending_pace_mode = "Balanced"


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
		var pass_chance := clampf((track_window + pace_advantage + tyre_advantage + aggression_bonus + command_bonus - defence_penalty + (racecraft - 0.5) * 0.18) * grip_window, 0.02, 0.78)
		if random_number_generator.randf() >= pass_chance:
			continue
		chaser.elapsed_time = minf(chaser.elapsed_time, ahead.elapsed_time - 0.04)
		ahead.elapsed_time += 0.04
		chaser.overtakes += 1
		ahead.overtaken += 1
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
	entry.mechanical_health = maxf(0.0, entry.mechanical_health - loss)
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


func request_player_pit_stop(compound: String = "Standard") -> bool:
	var player := get_player_entry()
	if player == null or is_complete:
		return false
	player.pending_pit_compound = "Standard"
	event_log.append("LAP %d  Pit wall: box next lap for fresh tyres." % current_lap)
	return true


func set_player_brake_bias(mode: String) -> void:
	var player := get_player_entry()
	if player != null and mode in ["Forward", "Neutral", "Rearward"]:
		player.brake_bias = mode
		event_log.append("LAP %d  Brake bias adjusted to %s." % [current_lap, mode])


func _perform_pit_stop(entry: RaceEntryState, compound: String) -> float:
	entry.pending_pit_compound = ""
	entry.tyre_compound = "Standard"
	entry.tyre_condition = 100.0
	entry.stint_laps = 0
	entry.tyre_temperature = 78.0
	entry.last_pit_lap = current_lap
	var fuel_margin := lerpf(1.08, 1.025, entry.strategy_skill / 100.0)
	var remaining_laps := race.lap_count - current_lap
	var planned_stint := mini(remaining_laps, maxi(6, roundi(float(race.lap_count) * lerpf(0.34, 0.48, entry.strategy_skill / 100.0))))
	if remaining_laps <= roundi(float(race.lap_count) * 0.55):
		planned_stint = remaining_laps
	var fuel_target := float(planned_stint) * race.fuel_consumption_factor * fuel_margin
	var fuel_added := maxf(0.0, fuel_target - entry.fuel_laps)
	entry.fuel_laps += fuel_added
	entry.fuel_target_laps = maxf(entry.fuel_laps, fuel_target)
	entry.fuel_remaining = clampf(entry.fuel_laps / maxf(1.0, entry.fuel_target_laps) * 100.0, 0.0, 100.0)
	entry.pit_stops += 1
	var pit_loss := race.pit_lane_time_loss + random_number_generator.randf_range(-0.8, 0.8)
	if race_state == "SAFETY CAR": pit_loss *= 0.58
	if entry.is_player:
		pit_loss = maxf(4.2, pit_loss - player_pit_time_reduction)
		var mistake_chance := maxf(0.01, 0.12 - player_pit_mistake_reduction / 100.0)
		if random_number_generator.randf() < mistake_chance:
			pit_loss += random_number_generator.randf_range(1.0, 2.5)
			event_log.append("LAP %d  A pit-crew mistake costs valuable time." % current_lap)
	event_log.append("LAP %d  %s pits for fresh tyres and %.1f laps of fuel (%.1fs)." % [current_lap, entry.driver_name, fuel_added / maxf(0.1, race.fuel_consumption_factor), pit_loss])
	return pit_loss


func _choose_ai_compound(entry: RaceEntryState) -> String:
	return "Standard"


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
			"fuel_target": entry.fuel_target_mode,
			"racecraft_command": entry.racecraft_command,
			"team_order": entry.team_order,
			"is_player": entry.is_player
		})
	return standings
