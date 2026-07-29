class_name RaceSimulation
extends RefCounted

signal lap_completed(lap: int)
signal race_completed

var race: Race
var current_lap: int = 0
var race_state: String = "GREEN FLAG"
var elapsed_race_time: float = 0.0
var entries: Array[RaceEntryState] = []
var event_log: Array[String] = []
var is_complete: bool = false
var random_number_generator := RandomNumberGenerator.new()


func setup(
	selected_race: Race,
	player_driver: Driver,
	player_team_name: String,
	player_score: float,
	starting_position: int,
	ai_drivers: Array[Dictionary],
	ai_scores: Array[float],
	starting_compound: String = "Medium",
	additional_team_entries: Array = [],
	seed: int = -1,
	player_attributes: Dictionary = {},
	locked_setup: String = "Balanced"
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
		entry.team_name = str(data.get("team_name", "Unknown Team"))
		entry.consistency = int(data.get("consistency", 50))
		entry.aggression = int(data.get("aggression", 50))
		entry.reliability = float(data.get("reliability", 72))
		entry.fuel_efficiency = float(data.get("fuel_efficiency", 50))
		entry.tyre_preservation = float(data.get("tyre_preservation", 50))
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
	player.reliability = float(player_attributes.get("reliability", 75.0))
	player.fuel_efficiency = float(player_attributes.get("fuel", 50.0))
	player.tyre_preservation = float(player_attributes.get("tyres", 50.0))
	player.setup_mode = locked_setup
	player.tyre_compound = starting_compound
	grid.insert(clampi(starting_position - 1, 0, grid.size()), player)
	for data_value in additional_team_entries:
		var data := data_value as Dictionary
		var teammate := RaceEntryState.new()
		teammate.driver_id = str(data.get("driver_id", ""))
		teammate.driver_name = str(data.get("driver_name", "Team Driver"))
		teammate.team_name = str(data.get("team_name", player_team_name))
		teammate.consistency = int(data.get("consistency", 50))
		teammate.base_pace = float(data.get("score", 50.0))
		teammate.tyre_compound = starting_compound
		grid.insert(clampi(int(data.get("starting_position", grid.size() + 1)) - 1, 0, grid.size()), teammate)
	for index in range(grid.size()):
		var entry := grid[index]
		entry.starting_position = index + 1
		entry.position = index + 1
		entry.elapsed_time = float(index) * 0.18
		entry.fuel_laps = float(race.lap_count) * (1.03 + (entry.fuel_efficiency - 50.0) * 0.0015)
	entries = grid
	event_log.append("LAP 0  The field takes the green flag.")


func simulate_lap() -> void:
	if is_complete or race == null:
		return
	current_lap += 1
	_update_track_state()
	var player := get_player_entry()
	var old_player_position := player.position if player != null else 0
	for entry in entries:
		if entry.status == "Retired":
			continue
		var pit_loss := 0.0
		if entry.is_player and not entry.pending_pit_compound.is_empty():
			pit_loss = _perform_pit_stop(entry, entry.pending_pit_compound)
		elif not entry.is_player and _ai_should_pit(entry):
			pit_loss = _perform_pit_stop(entry, _choose_ai_compound())
		entry.pace_mode = entry.pending_pace_mode
		var pace_data := _pace_data(entry)
		var incident_loss := _resolve_incident(entry)
		if entry.status == "Retired":
			continue
		var base_lap := 34.0 + float(race.difficulty) * 0.035
		var rating_bonus := (entry.base_pace - 55.0) * 0.045
		var tyre_penalty := pow(1.0 - entry.tyre_condition / 100.0, 2.0) * 2.4
		var fuel_weight_penalty := maxf(0.0, entry.fuel_laps) / maxf(1.0, race.lap_count) * 0.75
		var traffic_penalty := _traffic_penalty(entry)
		var caution_delta := 4.5 if race_state != "GREEN FLAG" else 0.0
		var variance_limit := lerpf(0.50, 0.10, float(entry.consistency) / 100.0)
		entry.last_lap_time = maxf(20.0, base_lap - rating_bonus + tyre_penalty + fuel_weight_penalty + traffic_penalty + caution_delta + float(pace_data.mode) + float(pace_data.compound) + _get_setup_modifier(entry) + pit_loss + incident_loss + random_number_generator.randf_range(-variance_limit, variance_limit))
		entry.elapsed_time += entry.last_lap_time
		entry.completed_laps = current_lap
		entry.best_lap_time = entry.last_lap_time if entry.best_lap_time <= 0.0 else minf(entry.best_lap_time, entry.last_lap_time)
		entry.tyre_condition = maxf(0.0, entry.tyre_condition - float(pace_data.wear))
		var consumption := race.fuel_consumption_factor * float(pace_data.fuel)
		entry.fuel_laps = maxf(0.0, entry.fuel_laps - consumption)
		entry.fuel_remaining = clampf(entry.fuel_laps / maxf(1.0, float(race.lap_count)) * 100.0, 0.0, 100.0)
		if entry.fuel_laps <= 0.0 and current_lap < race.lap_count:
			entry.last_lap_time += 5.0
			entry.elapsed_time += 5.0
			if entry.is_player: event_log.append("LAP %d  FUEL CRITICAL — save immediately or pit." % current_lap)
	_sort_standings()
	player = get_player_entry()
	if player != null and player.status != "Retired" and player.position != old_player_position:
		event_log.append("LAP %d  %s is now P%d." % [current_lap, player.driver_name, player.position])
	if player != null and current_lap % maxi(4, race.lap_count / 8) == 0:
		event_log.append("LAP %d  Crew chief: tyres %d%%, fuel %.1f laps, car %d%%." % [current_lap, roundi(player.tyre_condition), player.fuel_laps, roundi(player.car_condition)])
	elapsed_race_time = entries[0].elapsed_time
	lap_completed.emit(current_lap)
	if current_lap >= race.lap_count:
		is_complete = true
		race_state = "CHECKERED FLAG"
		event_log.append("LAP %d  Checkered flag — %s wins." % [current_lap, entries[0].driver_name])
		race_completed.emit()


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
	wear *= race.tyre_wear_factor * lerpf(1.12, 0.82, entry.tyre_preservation / 100.0)
	var result := {"mode": 0.0, "compound": 0.0, "wear": wear, "fuel": 1.0}
	if entry.tyre_compound == "Soft": result.merge({"compound": -0.18, "wear": wear * 1.28}, true)
	elif entry.tyre_compound == "Hard": result.merge({"compound": 0.16, "wear": wear * 0.72}, true)
	if entry.pace_mode == "Conserve": result.merge({"mode": 0.32, "wear": float(result.wear) * 0.72, "fuel": 0.88}, true)
	elif entry.pace_mode == "Attack": result.merge({"mode": -0.28, "wear": float(result.wear) * 1.38, "fuel": 1.12}, true)
	if race_state != "GREEN FLAG":
		result.wear = float(result.wear) * 0.35
		result.fuel = float(result.fuel) * 0.55
	return result


func _resolve_incident(entry: RaceEntryState) -> float:
	var pace_risk := {"Conserve": 0.70, "Balanced": 1.0, "Attack": 1.65}.get(entry.pace_mode, 1.0)
	var traffic_risk := 1.0 + race.overtaking_difficulty * (0.5 if entry.position > 1 else 0.0)
	var incident_chance := 0.0015 * race.accident_factor * pace_risk * traffic_risk * lerpf(0.65, 1.45, entry.aggression / 100.0)
	var failure_chance := 0.0008 * race.mechanical_stress * pace_risk * lerpf(1.8, 0.35, entry.reliability / 100.0)
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
		set_meta("caution_laps", random_number_generator.randi_range(2, 4))
		event_log.append("LAP %d  YELLOW FLAG — safety car deployed; pit loss is reduced." % current_lap)


func _traffic_penalty(entry: RaceEntryState) -> float:
	if race_state != "GREEN FLAG" or entry.position <= 1: return 0.0
	var ahead := entries[entry.position - 2]
	if entry.elapsed_time - ahead.elapsed_time < 1.0:
		return race.overtaking_difficulty * 0.30
	return 0.0


func _ai_should_pit(entry: RaceEntryState) -> bool:
	if current_lap >= race.lap_count - 2: return false
	var remaining := race.lap_count - current_lap
	var threshold := 20.0 + entry.aggression * 0.10
	if race_state == "SAFETY CAR" and entry.tyre_condition < 68.0: return true
	if entry.fuel_laps < float(remaining) * 0.75: return true
	return entry.tyre_condition < threshold


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


func request_player_pit_stop(compound: String) -> bool:
	var player := get_player_entry()
	if player == null or is_complete or compound not in ["Soft", "Medium", "Hard"]:
		return false
	player.pending_pit_compound = compound
	event_log.append("LAP %d  Pit wall: box next lap for %s tyres." % [current_lap, compound])
	return true


func set_player_brake_bias(mode: String) -> void:
	var player := get_player_entry()
	if player != null and mode in ["Forward", "Neutral", "Rearward"]:
		player.brake_bias = mode
		event_log.append("LAP %d  Brake bias adjusted to %s." % [current_lap, mode])


func _perform_pit_stop(entry: RaceEntryState, compound: String) -> float:
	entry.pending_pit_compound = ""
	entry.tyre_compound = compound
	entry.tyre_condition = 100.0
	var fuel_added := maxf(0.0, float(race.lap_count - current_lap) * 1.04 - entry.fuel_laps)
	entry.fuel_laps += fuel_added
	entry.pit_stops += 1
	var pit_loss := race.pit_lane_time_loss + random_number_generator.randf_range(-0.8, 0.8)
	if race_state == "SAFETY CAR": pit_loss *= 0.58
	if entry.is_player and GameManager.team != null:
		pit_loss = maxf(4.2, pit_loss - GameManager.team.get_pit_stop_time_reduction())
		var mistake_chance := maxf(0.01, 0.12 - GameManager.team.get_pit_mistake_reduction() / 100.0)
		if random_number_generator.randf() < mistake_chance:
			pit_loss += random_number_generator.randf_range(1.0, 2.5)
			event_log.append("LAP %d  A pit-crew mistake costs valuable time." % current_lap)
	event_log.append("LAP %d  %s pits for %s tyres and %.1f laps of fuel (%.1fs)." % [current_lap, entry.driver_name, compound, fuel_added, pit_loss])
	return pit_loss


func _choose_ai_compound() -> String:
	var remaining := race.lap_count - current_lap
	return "Soft" if remaining < race.lap_count / 4 else "Medium"


func _get_setup_modifier(entry: RaceEntryState) -> float:
	var preference_bonus := -0.10 if entry.setup_mode == race.preferred_setup else 0.08
	match entry.setup_mode:
		"Top Speed":
			return preference_bonus - race.power_demand * 0.12 + race.handling_demand * 0.08 + (100.0 - entry.tyre_condition) * 0.004
		"High Grip":
			return preference_bonus - race.handling_demand * 0.12 + race.power_demand * 0.08 - (100.0 - entry.tyre_condition) * 0.004
		_:
			return preference_bonus


func as_final_standings() -> Array[Dictionary]:
	var standings: Array[Dictionary] = []
	for entry in entries:
		standings.append({
			"driver_id": entry.driver_id,
			"driver_name": entry.driver_name,
			"team_name": entry.team_name,
			"score": -entry.elapsed_time,
			"status": entry.status,
			"incident_time_loss": entry.incident_time_loss,
			"is_player": entry.is_player
		})
	return standings
