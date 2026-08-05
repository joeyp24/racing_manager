extends SceneTree


func _initialize() -> void:
	var driver := Driver.new()
	driver.driver_id = "personality_test_driver"
	driver.driver_name = "Morgan Vale"
	driver.age = 38
	driver.team_name = "Test Racing"
	driver.career_wins = 1
	assert(PersonalityCatalog.assign_identity(driver) == "veteran")
	assert(driver.get_personality_name() == "Old Hand")
	var first_quote := PersonalityCatalog.reaction(driver, "win", {"season":2026, "event":"test_race"})
	var repeated_quote := PersonalityCatalog.reaction(driver, "win", {"season":2026, "event":"test_race"})
	assert(not first_quote.is_empty())
	assert(first_quote == repeated_quote)

	var teams := TeamCatalog.get_teams("local_short_track")
	var colors: Array[String] = []
	var unique_colors: Dictionary = {}
	for organization in teams:
		assert(not str(organization.get("short_name", "")).is_empty())
		assert(not str(organization.get("motto", "")).is_empty())
		colors.append(str(organization.get("primary_color", "")))
		unique_colors[str(organization.get("primary_color", ""))] = true
	assert(colors.size() == 7)
	assert(unique_colors.size() == colors.size())
	assert(str(SeriesCatalog.get_identity("premier_cup").short_name) == "PREMIER CUP")

	var team := Team.new()
	team.team_name = "Test Racing"
	team.ensure_default_player_driver()
	var active := team.get_active_driver()
	active.driver_id = driver.driver_id
	active.driver_name = driver.driver_name
	active.age = driver.age
	active.career_wins = 1
	active.update_archetype()
	CareerExpansionManager.ensure_state(team)
	var race := Race.new()
	race.race_id = "identity_race"
	race.race_name = "Identity 100"
	race.track_name = "Pine Ridge Raceway"
	var result := RaceResult.new()
	result.race = race
	result.player_driver = active
	result.starting_position = 8
	result.expected_finishing_position = 4
	result.finishing_position = 1
	result.positions_gained = 7
	result.standings = [
		{"driver_id":active.driver_id, "driver_name":active.driver_name, "team_name":team.team_name, "is_player":true, "status":"Finished", "incident_time_loss":0.0},
		{"driver_id":"recurring_rival", "driver_name":"Casey Stone", "team_name":"Pine Ridge Motorsports", "is_player":false, "status":"Finished", "incident_time_loss":0.0}
	]
	CareerExpansionManager._update_rivalries(team, result)
	CareerExpansionManager._update_rivalries(team, result)
	CareerExpansionManager._update_driver_dynamics(team, result)
	CareerExpansionManager._write_race_story(team, result)
	CareerExpansionManager._generate_story_arc(team, result)
	assert(str(team.career_state.featured_rival_id) == "recurring_rival")
	var rivalry := (team.career_state.rivalries as Dictionary).get("recurring_rival", {}) as Dictionary
	assert(int(rivalry.encounters) == 2)
	assert("Casey Stone" in result.rival_summary)
	assert(not result.driver_reaction.is_empty())
	assert("THE " in result.authored_incident)
	assert(not result.storyline_summary.is_empty())
	assert(not active.memorable_moments.is_empty())

	team.last_season_position = 2
	active.record_race({"race_name":"Identity 100", "finish":1, "positions_gained":7})
	var season_story := PersonalityCatalog.build_season_summary(team)
	assert(not str(season_story.get("headline", "")).is_empty())
	assert("Casey Stone" in str(season_story.get("rivalry_story", "")))

	var portrait := DriverPortrait.new()
	portrait.configure(active, team.primary_color, team.secondary_color)
	assert(active.driver_name in portrait.tooltip_text)
	portrait.free()
	print("Personality and identity tests passed")
	quit(0)
