extends Node
class_name SaveManager

const SAVE_PATH: String = "user://team_save.tres"


static func save_game(team: Team) -> bool:
	if team == null:
		push_error("Cannot save because the team is null.")
		return false

	var error = ResourceSaver.save(team, SAVE_PATH)

	if error != OK:
		push_error(
			"Failed to save game. Error code: %d" % error
		)
		return false

	print("Game saved to: ", SAVE_PATH)
	return true


static func load_game():
	if not ResourceLoader.exists(SAVE_PATH):
		print("No save file found.")
		return null

	var loaded_resource = ResourceLoader.load(
		SAVE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)

	if loaded_resource == null:
		push_error("The save file could not be loaded.")
		return null

	if not loaded_resource is Team:
		push_error("The save file does not contain a Team resource.")
		return null

	print("Game loaded from: ", SAVE_PATH)
	return loaded_resource
