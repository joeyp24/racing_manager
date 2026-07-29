extends Control

@onready var team_name_label: Label = %team_name_label
@onready var next_race_label: Label = %next_race_label
@onready var standings_label: Label = %standings_label
@onready var money_label: Label = %money_label
@onready var cars_owned_label: Label = %cars_owned_label
@onready var garage_value_label: Label = %garage_value_label
@onready var reputation_label: Label = %reputation_label
@onready var sponsor_label: Label = %sponsor_label
@onready var driver_ready_label: Label = %driver_ready_label
@onready var car_ready_label: Label = %car_ready_label
@onready var funds_ready_label: Label = %funds_ready_label


func _ready() -> void:
	if GameManager.team == null:
		push_error(
			"Dashboard cannot display because "
			+ "GameManager.team is null."
		)
		return

	if not GameManager.team.changed.is_connected(
		_on_team_changed
	):
		GameManager.team.changed.connect(
			_on_team_changed
		)

	update_dashboard()


func _exit_tree() -> void:
	if GameManager.team == null:
		return

	if GameManager.team.changed.is_connected(
		_on_team_changed
	):
		GameManager.team.changed.disconnect(
			_on_team_changed
		)


func _on_team_changed() -> void:
	update_dashboard()


func update_dashboard() -> void:
	var team: Team = GameManager.team

	if team == null:
		return

	team_name_label.text = "%s • Season %d race operations" % [team.team_name, team.season_number]

	money_label.text = (
		"$%s"
		% String.num_int64(team.money)
	)

	reputation_label.text = (
		"%d PTS"
		% team.reputation
	)

	update_sponsor_summary(team)

	cars_owned_label.text = (
		"%d of %d bays occupied"
		% [
			get_cars_owned(team),
			team.cars.size()
		]
	)

	garage_value_label.text = (
		"$%s total value"
		% String.num_int64(
			get_garage_value(team)
		)
	)

	update_next_race()
	update_championship_summary()
	update_readiness(team)


func update_sponsor_summary(team: Team) -> void:
	var sponsor := SponsorCatalog.find_by_id(team.active_sponsor_id)
	if sponsor == null:
		sponsor_label.text = "No active contract • Visit Sponsors to review offers"
		return

	sponsor_label.text = (
		"%s\n$%s per race  •  Objective %d/%d%s  •  %d races left"
		% [
			sponsor.sponsor_name,
			String.num_int64(sponsor.payment_per_race),
			team.sponsor_objective_progress,
			sponsor.objective_target,
			" complete" if team.sponsor_objective_completed else "",
			team.sponsor_races_remaining
		]
	)


func update_next_race() -> void:
	if GameManager.team.season_complete:
		next_race_label.text = (
			"Season %d Complete — Start a new season from Standings"
			% GameManager.team.season_number
		)
		return

	if GameManager.team.unlocked_races.is_empty():
		next_race_label.text = (
			"Next Race: Season Complete"
		)
		return

	var race_id: String = str(
		GameManager.team.unlocked_races.back()
	)

	next_race_label.text = (
		"Next Race: %s"
		% race_id.capitalize()
	)

	next_race_label.text = (
		"Next Race: %s"
		% race_id.capitalize().replace("_", " ")
	)


func update_championship_summary() -> void:
	var standings: Array[Dictionary] = (
		GameManager.team
		.get_sorted_championship_standings()
	)

	if standings.is_empty():
		standings_label.text = (
			"Championship: No races completed"
		)
		return

	var leader: Dictionary = standings[0]

	var player_position: int = 0
	var player_points: int = 0

	for index in range(standings.size()):
		var entry: Dictionary = standings[index]

		if bool(entry.get("is_player", false)):
			player_position = index + 1
			player_points = int(
				entry.get("points", 0)
			)
			break

	var leader_points: int = int(
		leader.get("points", 0)
	)

	var leader_name: String = str(
		leader.get("name", "Unknown Team")
	)

	var gap: int = (
		leader_points
		- player_points
	)

	if player_position <= 0:
		standings_label.text = (
			"Championship: Team not found"
		)
		return

	if player_position == 1:
		standings_label.text = (
			"Championship: 1st of %d"
			+ "  |  %d pts"
			+ "  |  Championship Leader"
		) % [
			standings.size(),
			player_points
		]
		return

	standings_label.text = (
		"Championship: %s of %d"
		+ "  |  %d pts"
		+ "  |  Leader: %s"
		+ "  |  Gap: %d pts"
	) % [
		get_ordinal(player_position),
		standings.size(),
		player_points,
		leader_name,
		gap
	]


func get_cars_owned(team: Team) -> int:
	var total := 0

	for car in team.cars:
		if car != null:
			total += 1

	return total


func get_garage_value(team: Team) -> int:
	var total := 0

	for car in team.cars:
		if car != null:
			total += car.value

	return total


func update_readiness(team: Team) -> void:
	set_readiness(driver_ready_label, team.driver_hired_for_season, "Driver contracted", "Driver required")
	set_readiness(car_ready_label, get_cars_owned(team) > 0, "Eligible car available", "No car available")
	set_readiness(funds_ready_label, team.money > 0, "Entry funds available", "Funding required")


func set_readiness(label: Label, ready: bool, ready_text: String, blocked_text: String) -> void:
	label.text = ("✓  " + ready_text) if ready else ("!  " + blocked_text)
	label.modulate = Color("43d68a") if ready else Color("ffb547")


func _on_prepare_race_pressed() -> void:
	GameManager.selected_race = null
	GameManager.selected_car = null
	GameManager.load_page("res://scenes/pages/race_calendar/race_calendar.tscn")

func get_ordinal(number: int) -> String:
	var final_two_digits: int = number % 100

	if (
		final_two_digits >= 11
		and final_two_digits <= 13
	):
		return "%dth" % number

	match number % 10:
		1:
			return "%dst" % number
		2:
			return "%dnd" % number
		3:
			return "%drd" % number
		_:
			return "%dth" % number
