extends Node
class_name SaveManager

const SAVE_DIRECTORY: String = "user://saves"
const LEGACY_SAVE_PATH: String = "user://team_save.tres"
const SAVE_EXTENSION: String = ".tres"


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
	var error := ResourceSaver.save(team, get_save_path(slot_id))
	if error != OK:
		push_error("Failed to save slot '%s'. Error code: %d" % [slot_id, error])
		return false
	return true


static func load_game(slot_id: String) -> Team:
	var save_path := get_save_path(slot_id)
	if not ResourceLoader.exists(save_path):
		return null
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded is Team:
		push_error("Save slot '%s' does not contain a Team resource." % slot_id)
		return null
	return loaded as Team


static func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not ensure_save_directory():
		return slots
	var directory := DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return slots
	for file_name in directory.get_files():
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
	if error != OK:
		push_error("Failed to delete save slot '%s'. Error code: %d" % [slot_id, error])
		return false
	return true
