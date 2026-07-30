extends Node
class_name SaveManager

const SAVE_DIRECTORY: String = "user://saves"
const LEGACY_SAVE_PATH: String = "user://team_save.tres"
const SAVE_EXTENSION: String = ".tres"
const BACKUP_EXTENSION: String = ".backup.tres"
const TEMP_EXTENSION: String = ".temporary.tres"


static func ensure_save_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(SAVE_DIRECTORY)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK:
		push_error("Could not create the save directory. Error code: %d" % error)
		return false
	return true


static func migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH) or not ensure_save_directory():
		return
	if not get_save_slots().is_empty():
		return
	var legacy := ResourceLoader.load(LEGACY_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Team
	if legacy != null and save_game(legacy, "legacy_career"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))


static func make_slot_id(display_name: String) -> String:
	var safe_name := display_name.strip_edges().to_lower()
	var result := ""
	for character in safe_name:
		if character.to_ascii_buffer()[0] in range(97, 123) or character.to_ascii_buffer()[0] in range(48, 58):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	result = result.trim_suffix("_").trim_prefix("_")
	if result.is_empty():
		result = "career"
	var candidate := result
	var suffix := 2
	while FileAccess.file_exists(get_save_path(candidate)):
		candidate = "%s_%d" % [result, suffix]
		suffix += 1
	return candidate


static func get_save_path(slot_id: String) -> String:
	return "%s/%s%s" % [SAVE_DIRECTORY, slot_id.validate_filename(), SAVE_EXTENSION]


static func save_game(team: Team, slot_id: String) -> bool:
	if team == null or slot_id.strip_edges().is_empty() or not ensure_save_directory():
		push_error("Cannot save without a team and save slot.")
		return false
	team.last_saved_unix_time = int(Time.get_unix_time_from_system())
	team.save_format_version = Team.CURRENT_SAVE_FORMAT_VERSION
	team.save_series_progress()
	var save_path := get_save_path(slot_id)
	var temporary_path := save_path.trim_suffix(SAVE_EXTENSION) + TEMP_EXTENSION
	var backup_path := save_path.trim_suffix(SAVE_EXTENSION) + BACKUP_EXTENSION
	var error := ResourceSaver.save(team, temporary_path)
	if error != OK:
		push_error("Failed to save slot '%s'. Error code: %d" % [slot_id, error])
		return false
	var temporary_resource := ResourceLoader.load(temporary_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not temporary_resource is Team:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		push_error("Save verification failed for slot '%s'." % slot_id)
		return false
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		push_error("Could not atomically replace slot '%s'. Error code: %d" % [slot_id, error])
		return false
	return true


static func load_game(slot_id: String) -> Team:
	var save_path := get_save_path(slot_id)
	var backup_path := save_path.trim_suffix(SAVE_EXTENSION) + BACKUP_EXTENSION
	if not ResourceLoader.exists(save_path) and not ResourceLoader.exists(backup_path):
		return null
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(save_path) else null
	if not loaded is Team:
		loaded = ResourceLoader.load(backup_path, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(backup_path) else null
		if not loaded is Team:
			push_error("Save slot '%s' is corrupt and no valid backup was found." % slot_id)
			return null
	var team := loaded as Team
	var needs_resave := team.save_format_version < Team.CURRENT_SAVE_FORMAT_VERSION
	_repair_and_migrate(team)
	if needs_resave and not save_game(team, slot_id):
		push_error("Loaded and migrated save, but could not persist migration.")
	return team


static func _repair_and_migrate(team: Team) -> void:
	# Resource defaults cover newly introduced scalar fields; these calls repair collections.
	if team.save_format_version < 4:
		# V3 and older stored only the local championship in exported fields.
		team.series_progress.erase("local_short_track")
		team.current_series_id = "local_short_track"
	if team.save_format_version < 8:
		_migrate_performance_points(team)
	team.ensure_series_progress(team.current_series_id)
	team.load_series_progress(team.current_series_id)
	team.ensure_world_series_data()
	team.ensure_ai_team_career()
	team.ensure_departments()
	team.ensure_scouting_hours()
	team.ensure_default_player_driver()
	team.ensure_driver_market()
	team.ensure_series_rosters()
	team.ensure_ai_driver_career()
	team.ensure_car_parts()
	team.ensure_staff_market()
	team.ensure_race_teams()
	team.ensure_race_week_progression()
	team.save_format_version = Team.CURRENT_SAVE_FORMAT_VERSION


static func _migrate_performance_points(team: Team) -> void:
	# V8 makes installed part base PP authoritative. A legacy car's old rating is
	# used only once to build a deterministic six-part factory profile.
	for car_value in team.cars:
		var car := car_value as Car
		if car == null:
			continue
		for part in car.installed_parts:
			if part != null:
				part.base_performance_points += part.performance_bonus
				part.performance_bonus = 0
		var missing_types: Array[String] = []
		for part_type in CarPart.PART_TYPES:
			if car.get_part(part_type) == null:
				missing_types.append(part_type)
		var profile_total := maxi(CarPart.PART_TYPES.size(), car.legacy_performance)
		var missing_total := maxi(missing_types.size(), profile_total - car.get_base_performance_points())
		for index in missing_types.size():
			var slots_left := missing_types.size() - index
			var points := maxi(1, floori(float(missing_total) / float(slots_left)))
			car.installed_parts.append(PartCatalog.create_standard_part(missing_types[index], points))
			missing_total -= points
	for part in team.parts_inventory:
		if part != null:
			part.base_performance_points += part.performance_bonus
			part.performance_bonus = 0


static func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not ensure_save_directory():
		return slots
	var directory := DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return slots
	for file_name in directory.get_files():
		if file_name.ends_with(BACKUP_EXTENSION) or file_name.ends_with(TEMP_EXTENSION):
			continue
		if not file_name.ends_with(SAVE_EXTENSION):
			continue
		var slot_id := file_name.trim_suffix(SAVE_EXTENSION)
		var saved_team := load_game(slot_id)
		if saved_team == null:
			continue
		slots.append({
			"slot_id": slot_id,
			"team_name": saved_team.team_name,
			"season": saved_team.season_number,
			"money": saved_team.money,
			"saved_at": saved_team.last_saved_unix_time,
			"primary_color": saved_team.primary_color
		})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.saved_at) > int(b.saved_at))
	return slots


static func delete_save(slot_id: String) -> bool:
	var path := get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var backup_path := path.trim_suffix(SAVE_EXTENSION) + BACKUP_EXTENSION
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	if error != OK:
		push_error("Failed to delete save slot '%s'. Error code: %d" % [slot_id, error])
		return false
	return true
