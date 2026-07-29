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
	starting_compound: String = "Medium"
) -> void:
	race = selected_race
	random_number_generator.randomize()
	var grid: Array[RaceEntryState] = []
	for index in range(ai_drivers.size()):
		var data := ai_drivers[index]
		var entry := RaceEntryState.new()
		entry.driver_id = str(data.get("driver_id", ""))
		entry.driver_name = str(data.get("driver_name", "Unknown Driver"))
		entry.team_name = str(data.get("team_name", "Unknown Team"))
		entry.consistency = int(data.get("consistency", 50))
		entry.base_pace = ai_scores[index]
		grid.append(entry)
	var player := RaceEntryState.new()
	player.driver_id = player_driver.driver_id
	player.driver_name = player_driver.driver_name
	player.team_name = player_team_name
	player.is_player = true
	player.consistency = player_driver.consistency
	player.base_pace = player_score
	player.tyre_compound = starting_compound
	grid.insert(clampi(starting_position - 1, 0, grid.size()), player)
	for index in range(grid.size()):
		var entry := grid[index]
		entry.starting_position = index + 1
		entry.position = index + 1
		entry.elapsed_time = float(index) * 0.18
	entries = grid
	event_log.append("LAP 0  The field takes the green flag.")


func simulate_lap() -> void:
	if is_complete or race == null:
		return
	current_lap += 1
	var old_player_position := get_player_entry().position
	for entry in entries:
		entry.pace_mode = entry.pending_pace_mode
		var mode_modifier := 0.0
		var wear_rate := 100.0 / maxf(12.0, float(race.lap_count) * 0.72)
		match entry.pace_mode:
			"Conserve":
				mode_modifier = 0.32
				wear_rate *= 0.72
			"Attack":
				mode_modifier = -0.28
				wear_rate *= 1.38
		var base_lap := 34.0 + float(race.difficulty) * 0.035
		var rating_bonus := (entry.base_pace - 55.0) * 0.045
		var tyre_penalty := pow(1.0 - entry.tyre_condition / 100.0, 2.0) * 1.8
		var variance_limit := lerpf(0.45, 0.10, float(entry.consistency) / 100.0)
		entry.last_lap_time = maxf(20.0, base_lap - rating_bonus + tyre_penalty + mode_modifier + random_number_generator.randf_range(-variance_limit, variance_limit))
		entry.elapsed_time += entry.last_lap_time
		entry.completed_laps = current_lap
		entry.best_lap_time = entry.last_lap_time if entry.best_lap_time <= 0.0 else minf(entry.best_lap_time, entry.last_lap_time)
		entry.tyre_condition = maxf(5.0, entry.tyre_condition - wear_rate)
		entry.fuel_remaining = maxf(0.0, 100.0 * (1.0 - float(current_lap) / float(race.lap_count)))
	_sort_standings()
	var player := get_player_entry()
	if player.position < old_player_position:
		event_log.append("LAP %d  %s moves up to P%d." % [current_lap, player.driver_name, player.position])
	elif player.position > old_player_position:
		event_log.append("LAP %d  %s drops to P%d." % [current_lap, player.driver_name, player.position])
	if current_lap % maxi(4, race.lap_count / 8) == 0:
		event_log.append("LAP %d  Crew chief: pace is %s, tyres estimated at %d%%." % [current_lap, player.pace_mode.to_lower(), roundi(player.tyre_condition)])
	elapsed_race_time = entries[0].elapsed_time
	lap_completed.emit(current_lap)
	if current_lap >= race.lap_count:
		is_complete = true
		race_state = "CHECKERED FLAG"
		event_log.append("LAP %d  Checkered flag — %s wins the race." % [current_lap, entries[0].driver_name])
		race_completed.emit()


func _sort_standings() -> void:
	entries.sort_custom(func(first: RaceEntryState, second: RaceEntryState) -> bool: return first.elapsed_time < second.elapsed_time)
	for index in range(entries.size()):
		entries[index].position = index + 1


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


func as_final_standings() -> Array[Dictionary]:
	var standings: Array[Dictionary] = []
	for entry in entries:
		standings.append({
			"driver_id": entry.driver_id,
			"driver_name": entry.driver_name,
			"team_name": entry.team_name,
			"score": -entry.elapsed_time,
			"is_player": entry.is_player
		})
	return standings
