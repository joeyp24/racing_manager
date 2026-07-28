extends Control

const PLAYER_ROW_COLOR := Color(
	1.0,
	0.82,
	0.25,
	1.0
)

const HEADER_COLOR := Color(
	0.8,
	0.8,
	0.8,
	1.0
)

@onready var summary_label: Label = %summary_label
@onready var standings_grid: GridContainer = %standings_grid
@onready var season_status_label: Label = %season_status_label
@onready var new_season_button: Button = %new_season_button


func _ready() -> void:
	new_season_button.pressed.connect(
		_on_new_season_button_pressed
	)
	display_championship_standings()


func display_championship_standings() -> void:
	clear_standings_grid()
	update_season_controls()

	if GameManager.team == null:
		summary_label.text = "No team is currently loaded."
		return

	var standings: Array[Dictionary] = (
		GameManager.team
		.get_sorted_championship_standings()
	)

	if standings.is_empty():
		summary_label.text = (
			"Complete your first race to begin "
			+ "the driver championship."
		)

		create_header_row()
		return

	create_header_row()

	var player_position: int = 0

	for index in range(standings.size()):
		var entry: Dictionary = standings[index]
		var position: int = index + 1

		var is_player: bool = bool(
			entry.get("is_player", false)
		)

		if is_player:
			player_position = position

		create_standings_row(
			position,
			entry,
			is_player
		)

	update_summary(
		player_position,
		standings.size()
	)


func update_season_controls() -> void:
	if GameManager.team == null:
		season_status_label.text = ""
		new_season_button.visible = false
		return

	var team: Team = GameManager.team

	if team.season_complete:
		season_status_label.text = (
			"Season %d complete — finished %s and earned $%s"
			% [
				team.season_number,
				get_ordinal(team.last_season_position),
				format_number(team.last_season_prize)
			]
		)
		new_season_button.visible = true
		return

	season_status_label.text = "Season %d — Race %d of %d" % [
		team.season_number,
		team.completed_races.size(),
		RaceManager.SEASON_RACE_IDS.size()
	]
	new_season_button.visible = false


func _on_new_season_button_pressed() -> void:
	if RaceManager.start_new_season():
		display_championship_standings()


func format_number(number: int) -> String:
	var number_string: String = str(number)
	var formatted_number: String = ""

	while number_string.length() > 3:
		formatted_number = "," + number_string.right(3) + formatted_number
		number_string = number_string.left(number_string.length() - 3)

	return number_string + formatted_number


func clear_standings_grid() -> void:
	for child in standings_grid.get_children():
		child.queue_free()


func create_header_row() -> void:
	create_grid_label(
		"Pos",
		true,
		false,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		"Driver / Team",
		true,
		false,
		HORIZONTAL_ALIGNMENT_LEFT
	)

	create_grid_label(
		"Points",
		true,
		false,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		"Wins",
		true,
		false,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		"Podiums",
		true,
		false,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func create_standings_row(
	position: int,
	entry: Dictionary,
	is_player: bool
) -> void:
	var driver_name: String = str(
		entry.get(
			"driver_name",
			"Unknown Driver"
		)
	)

	var team_name: String = str(
		entry.get(
			"team_name",
			"Unknown Team"
		)
	)

	var driver_display: String = (
		"%s — %s"
		% [
			driver_name,
			team_name
		]
	)

	create_grid_label(
		str(position),
		false,
		is_player,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		driver_display,
		false,
		is_player,
		HORIZONTAL_ALIGNMENT_LEFT
	)

	create_grid_label(
		str(entry.get("points", 0)),
		false,
		is_player,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		str(entry.get("wins", 0)),
		false,
		is_player,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	create_grid_label(
		str(entry.get("podiums", 0)),
		false,
		is_player,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func create_grid_label(
	label_text: String,
	is_header: bool,
	is_player: bool,
	alignment: HorizontalAlignment
) -> void:
	var label := Label.new()

	label.text = label_text
	label.horizontal_alignment = alignment
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	label.custom_minimum_size = Vector2(
		90,
		38
	)

	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	if is_header:
		label.add_theme_color_override(
			"font_color",
			HEADER_COLOR
		)

		label.add_theme_font_size_override(
			"font_size",
			18
		)
	elif is_player:
		label.add_theme_color_override(
			"font_color",
			PLAYER_ROW_COLOR
		)

		label.add_theme_font_size_override(
			"font_size",
			17
		)

	standings_grid.add_child(label)


func update_summary(
	player_position: int,
	field_size: int
) -> void:
	var player_entry: Dictionary = (
		GameManager.team
		.get_player_championship_entry()
	)

	var player_points: int = int(
		player_entry.get("points", 0)
	)

	var driver_name: String = str(
		player_entry.get(
			"driver_name",
			"Your Driver"
		)
	)

	if player_position <= 0:
		summary_label.text = (
			"Your driver has not entered "
			+ "the championship."
		)
		return

	summary_label.text = (
		"%s: %s of %d    |    "
		+ "Championship points: %d"
	) % [
		driver_name,
		get_ordinal(player_position),
		field_size,
		player_points
	]


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
