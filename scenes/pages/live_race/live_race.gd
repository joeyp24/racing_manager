extends Control

const SPEEDS: Array[int] = [1, 2, 4, 8]

@onready var race_flow: RaceFlowProgress = %RaceFlowProgress
@onready var race_title: Label = %race_title
@onready var flag_label: Label = %flag_label
@onready var speed_label: Label = %speed_label
@onready var message_label: Label = %message_label
@onready var timing_tower: RichTextLabel = %timing_tower
@onready var team_summary: RichTextLabel = %team_summary
@onready var crew_chief_feed: RichTextLabel = %crew_chief_feed
@onready var event_feed: RichTextLabel = %event_feed
@onready var pause_button: Button = %pause_button
@onready var speed_selector: OptionButton = %speed_selector
@onready var next_lap_button: Button = %next_lap_button
@onready var track_map: LiveTrackMap = %track_map

var simulation: RaceSimulation
var lap_timer := Timer.new()
var is_paused: bool = true
var finalized: bool = false
var weekend_data: Dictionary = {}


func _ready() -> void:
	weekend_data = GameManager.active_race_weekend.duplicate(true)
	simulation = RaceManager.create_live_simulation(
		GameManager.selected_race,
		GameManager.selected_car,
		str(weekend_data.get("strategy_id", "balanced")),
		weekend_data
	)
	if simulation == null:
		show_error()
		return
	add_child(lap_timer)
	lap_timer.one_shot = false
	lap_timer.timeout.connect(_on_lap_timer_timeout)
	pause_button.pressed.connect(_toggle_pause)
	speed_selector.item_selected.connect(_on_speed_selected)
	next_lap_button.pressed.connect(_advance_one_lap)
	simulation.caution_started.connect(_on_caution_started)
	simulation.crew_chief_call_issued.connect(_on_crew_chief_call_issued)
	for speed in SPEEDS:
		speed_selector.add_item("%dx" % speed)
	speed_selector.select(1)
	_update_timer_speed()
	track_map.set_simulation(simulation)
	race_flow.set_stage(3, "%d team entr%s · AI crew chiefs control race strategy" % [simulation.get_player_entries().size(), "y" if simulation.get_player_entries().size() == 1 else "ies"])
	_apply_race_identity()
	_refresh_display()
	pause_button.call_deferred("grab_focus")


func _on_lap_timer_timeout() -> void:
	if simulation == null or is_paused or simulation.is_complete:
		return
	simulation.simulate_lap()
	_refresh_display()
	if simulation.is_complete:
		_finish_race()


func _toggle_pause() -> void:
	if simulation == null or simulation.is_complete:
		return
	is_paused = not is_paused
	pause_button.text = "Resume race" if is_paused else "Pause race"
	next_lap_button.disabled = not is_paused
	message_label.text = (
		"BROADCAST PAUSED · Crew strategy remains locked"
		if is_paused
		else "Race running · Crew chiefs are managing every team entry"
	)
	if is_paused:
		lap_timer.stop()
	else:
		lap_timer.start()
	_refresh_header()


func _on_speed_selected(_index: int) -> void:
	_update_timer_speed()


func _update_timer_speed() -> void:
	var speed := SPEEDS[speed_selector.selected] if speed_selector.selected >= 0 else 1
	var accessibility_speed := float(CareerExpansionManager.ensure_state(GameManager.team).accessibility.simulation_speed)
	lap_timer.wait_time = 1.1 / (float(speed) * accessibility_speed)
	if not is_paused:
		lap_timer.start()
	_refresh_header()


func _advance_one_lap() -> void:
	if simulation == null or simulation.is_complete or not is_paused:
		return
	simulation.simulate_lap()
	_refresh_display()
	if simulation.is_complete:
		_finish_race()


func _on_caution_started(lap: int) -> void:
	if finalized:
		return
	message_label.text = "YELLOW FLAG · Lap %d · Crew chiefs are handling the caution cycle" % lap
	_refresh_display()


func _on_crew_chief_call_issued(call: Dictionary) -> void:
	message_label.text = "CREW CHIEF / %s · %s" % [str(call.get("driver_name", "Team car")), str(call.get("title", "Strategy update"))]
	_refresh_crew_chief_feed()


func _refresh_display() -> void:
	_refresh_header()
	_refresh_tower()
	_refresh_team_summary()
	_refresh_crew_chief_feed()
	_refresh_event_feed()
	track_map.queue_redraw()


func _refresh_header() -> void:
	if simulation == null:
		return
	flag_label.text = "●  %s" % simulation.race_state
	flag_label.modulate = (
		Color("55d68b")
		if simulation.race_state == "GREEN FLAG"
		else (Color("f0c84b") if simulation.race_state in ["SAFETY CAR", "RESTART"] else Color("f4f6fa"))
	)
	var series_identity := SeriesCatalog.get_identity(simulation.race.series_id)
	race_title.text = "%s / %s  ·  LAP %d / %d%s" % [
		str(series_identity.short_name),
		simulation.race.race_name.to_upper(),
		simulation.current_lap,
		simulation.get_total_laps(),
		" (OVERTIME)" if simulation.overtime_attempts > 0 else "",
	]
	var speed := SPEEDS[speed_selector.selected] if speed_selector.selected >= 0 else 1
	speed_label.text = ("PAUSED  ·  " if is_paused else "LIVE  ·  ") + "%d× SPEED" % speed


func _refresh_tower() -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var text := "[table=6][cell][b]POS[/b][/cell][cell][b]DRIVER / TEAM[/b][/cell][cell][b]CHANGE[/b][/cell][cell][b]GAP[/b][/cell][cell][b]LAST[/b][/cell][cell][b]STATUS[/b][/cell]"
	for entry in simulation.entries:
		var change := entry.starting_position - entry.position
		var change_text := "—" if change == 0 else ("↑%d" % change if change > 0 else "↓%d" % abs(change))
		var gap := "LEADER" if entry.position == 1 else "+%.3f" % entry.gap_to(leader)
		var lap := "—" if entry.last_lap_time <= 0.0 else "%.3f" % entry.last_lap_time
		var identity := _team_identity(entry.team_id, entry.team_name, entry.is_player)
		var primary_hex := str(identity.primary_color)
		var driver_cell := "[color=#%s]▌[/color] [b]%s[/b] [color=#8491a3]· %s[/color]" % [primary_hex, entry.driver_name, str(identity.short_name)]
		var status := entry.status if entry.status != "Running" else ("AI · %s" % entry.pace_mode if entry.is_player else entry.status)
		var values := ["P%d" % entry.position, driver_cell, change_text, gap, lap, "%d%% · %s" % [roundi(entry.tyre_condition), status]]
		for value in values:
			if entry.is_player:
				text += "[cell bg=#%s33][color=#ffffff]%s[/color][/cell]" % [primary_hex, value]
			else:
				text += "[cell]%s[/cell]" % value
	timing_tower.text = text + "[/table]"


func _refresh_team_summary() -> void:
	var text := "[table=6][cell][b]TEAM CAR[/b][/cell][cell][b]POS[/b][/cell][cell][b]TYRES[/b][/cell][cell][b]FUEL[/b][/cell][cell][b]SYSTEMS[/b][/cell][cell][b]CREW PLAN[/b][/cell]"
	for entry in simulation.get_player_entries():
		var identity := _team_identity(entry.team_id, entry.team_name, true)
		var status_color := "#56d690" if entry.mechanical_health >= 75.0 else ("#f0c84b" if entry.mechanical_health >= 50.0 else "#ff6b62")
		var values := [
			"[color=#%s]▌[/color] [b]%s[/b]" % [str(identity.primary_color), entry.driver_name],
			"P%d  (%+d)" % [entry.position, entry.starting_position - entry.position],
			"%d%%" % roundi(entry.tyre_condition),
			"%.1f laps" % (entry.fuel_laps / maxf(0.1, simulation.race.fuel_consumption_factor)),
			"[color=%s]%d%%[/color]" % [status_color, roundi(entry.mechanical_health)],
			entry.status if entry.status != "Running" else "%s · %s" % [entry.pace_mode, entry.racecraft_command],
		]
		for value in values:
			text += "[cell]%s[/cell]" % value
	team_summary.text = text + "[/table]"


func _refresh_crew_chief_feed() -> void:
	if simulation.crew_chief_calls.is_empty():
		crew_chief_feed.text = "[color=#8793a3]Crew chiefs are preparing the opening stint.[/color]"
		return
	var lines := PackedStringArray()
	var first := maxi(0, simulation.crew_chief_calls.size() - 6)
	for index in range(simulation.crew_chief_calls.size() - 1, first - 1, -1):
		var call := simulation.crew_chief_calls[index]
		var accent := "#f0c84b" if str(call.get("severity", "info")) == "action" else "#56d690"
		lines.append("[color=%s][b]L%d · %s · %s[/b][/color]\n%s" % [
			accent,
			int(call.get("lap", 0)),
			str(call.get("driver_name", "Team car")),
			str(call.get("title", "Update")),
			str(call.get("detail", "")),
		])
	crew_chief_feed.text = "\n\n".join(lines)


func _refresh_event_feed() -> void:
	var first := maxi(0, simulation.event_log.size() - 8)
	var lines := PackedStringArray()
	for index in range(first, simulation.event_log.size()):
		lines.append(simulation.event_log[index])
	event_feed.text = "\n".join(lines)
	event_feed.scroll_to_line(maxi(0, lines.size() - 1))


func _team_identity(team_id: String, team_name: String, is_player: bool) -> Dictionary:
	if is_player:
		return {
			"primary_color": GameManager.team.primary_color.to_html(false),
			"secondary_color": GameManager.team.secondary_color.to_html(false),
			"short_name": team_name.left(14).to_upper(),
		}
	var organization := TeamCatalog.get_team(simulation.race.series_id, team_id)
	if organization.is_empty() and GameManager.team != null:
		for candidate in GameManager.team.get_ai_organizations_for_series(simulation.race.series_id):
			if str(candidate.team_id) == team_id:
				organization = candidate
				break
	return {
		"primary_color": str(organization.get("primary_color", "6d93a8")),
		"secondary_color": str(organization.get("secondary_color", "101d24")),
		"short_name": str(organization.get("short_name", team_name.left(14))).to_upper(),
	}


func _apply_race_identity() -> void:
	if simulation == null:
		return
	var presentation := TrackPresentationCatalog.get_profile(simulation.race)
	var accent := presentation.get("accent", Color("e85d45")) as Color
	var header := %Header as PanelContainer
	var style := header.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent
	header.add_theme_stylebox_override("panel", style)
	message_label.modulate = accent.lightened(0.16)


func _finish_race() -> void:
	if finalized:
		return
	finalized = true
	is_paused = true
	lap_timer.stop()
	pause_button.disabled = true
	next_lap_button.disabled = true
	speed_selector.disabled = true
	message_label.text = "Race complete · Preparing the team debrief"
	var cash_before := GameManager.team.money
	var result := RaceManager.finalize_live_race(
		simulation,
		GameManager.selected_car,
		str(weekend_data.get("strategy_id", "balanced")),
		weekend_data
	)
	GameManager.finish_race_weekend()
	if result == null:
		message_label.text = "The race could not be finalized."
		GameManager.report_decision_outcome({
			"status": "error",
			"title": "Race settlement failed",
			"message": "The completed race could not be converted into an official result.",
		})
		return
	GameManager.report_decision_outcome({
		"title": "Race settled · Primary car P%d" % result.finishing_position,
		"message": "%d team entr%s reached the debrief." % [simulation.get_player_entries().size(), "y" if simulation.get_player_entries().size() == 1 else "ies"],
		"detail": "Championship, sponsor, payroll, and car-condition effects are applied.",
		"cash_delta": GameManager.team.money - cash_before,
		"action_label": "Open debrief",
		"action_path": "res://scenes/pages/race_results/race_results.tscn",
	})
	await get_tree().create_timer(0.35).timeout
	GameManager.load_page("res://scenes/pages/race_results/race_results.tscn")


func show_error() -> void:
	race_title.text = "LIVE RACE UNAVAILABLE"
	message_label.text = "The active race entry could not be loaded."
	pause_button.disabled = true
	next_lap_button.disabled = true
	speed_selector.disabled = true
