extends Control

const SPEEDS: Array[int] = [1, 2, 4, 8]

@onready var race_title: Label = %race_title
@onready var flag_label: Label = %flag_label
@onready var speed_label: Label = %speed_label
@onready var message_label: Label = %message_label
@onready var timing_tower: RichTextLabel = %timing_tower
@onready var telemetry: RichTextLabel = %telemetry
@onready var event_feed: RichTextLabel = %event_feed
@onready var pause_button: Button = %pause_button
@onready var speed_selector: OptionButton = %speed_selector
@onready var pace_selector: OptionButton = %pace_selector
@onready var apply_pace_button: Button = %apply_pace_button
@onready var next_lap_button: Button = %next_lap_button
@onready var pit_service_selector: OptionButton = %pit_service_selector
@onready var pit_prediction_label: Label = %pit_prediction_label
@onready var pit_button: Button = %pit_button
@onready var setup_selector: OptionButton = %setup_selector
@onready var apply_setup_button: Button = %apply_setup_button
@onready var fuel_selector: OptionButton = %fuel_selector
@onready var racecraft_selector: OptionButton = %racecraft_selector
@onready var apply_command_button: Button = %apply_command_button
@onready var team_order_selector: OptionButton = %team_order_selector
@onready var apply_team_order_button: Button = %apply_team_order_button
@onready var track_map: LiveTrackMap = %track_map
@onready var engineer_label: RichTextLabel = %engineer_label
@onready var engineer_request_button: Button = %engineer_request_button
@onready var caution_overlay: Control = %caution_overlay
@onready var caution_title: Label = %caution_title
@onready var caution_summary: Label = %caution_summary
@onready var caution_service_selector: OptionButton = %caution_service_selector
@onready var caution_prediction_label: Label = %caution_prediction_label
@onready var caution_pit_button: Button = %caution_pit_button
@onready var caution_stay_button: Button = %caution_stay_button
@onready var caution_wave_button: Button = %caution_wave_button
@onready var stint_chart: LiveTelemetryChart = %analysis_tabs.get_node("Stints")
@onready var lap_time_chart: LiveTelemetryChart = %analysis_tabs.get_node("Lap Times")
@onready var tyre_fuel_chart: LiveTelemetryChart = %analysis_tabs.get_node("Tyre & Fuel")
@onready var passing_summary: RichTextLabel = %analysis_tabs.get_node("Passing")
@onready var caution_timeline: RichTextLabel = %analysis_tabs.get_node("Cautions")
@onready var comparison_summary: RichTextLabel = %analysis_tabs.get_node("Comparisons")

var simulation: RaceSimulation
var lap_timer := Timer.new()
var is_paused: bool = true
var finalized: bool = false
var weekend_data: Dictionary = {}
var caution_choice_open: bool = false
var was_running_before_caution: bool = false


func _ready() -> void:
	weekend_data = GameManager.active_race_weekend.duplicate(true)
	var strategy_id := str(weekend_data.get("strategy_id", "balanced"))
	simulation = RaceManager.create_live_simulation(
		GameManager.selected_race,
		GameManager.selected_car,
		strategy_id,
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
	apply_pace_button.pressed.connect(_apply_pace)
	next_lap_button.pressed.connect(_advance_one_lap)
	pit_button.pressed.connect(_request_pit_stop)
	apply_setup_button.pressed.connect(_apply_setup)
	apply_command_button.pressed.connect(_apply_commands)
	apply_team_order_button.pressed.connect(_apply_team_order)
	simulation.caution_started.connect(_on_caution_started)
	simulation.engineer_advice_ready.connect(_on_engineer_advice_ready)
	engineer_request_button.pressed.connect(_request_engineer_update)
	caution_pit_button.pressed.connect(_pit_under_caution)
	caution_stay_button.pressed.connect(_stay_out_under_caution)
	caution_wave_button.pressed.connect(_wave_around_under_caution)
	pit_service_selector.item_selected.connect(_on_pit_service_selected)
	caution_service_selector.item_selected.connect(_on_caution_service_selected)
	for speed in SPEEDS:
		speed_selector.add_item("%dx" % speed)
	pace_selector.add_item("Conserve")
	pace_selector.add_item("Balanced")
	pace_selector.add_item("Attack")
	pace_selector.select(1)
	_populate_pit_services(pit_service_selector)
	_populate_pit_services(caution_service_selector)
	for setup in ["Forward", "Neutral", "Rearward"]:
		setup_selector.add_item(setup)
	for fuel_target in ["Save", "Balanced", "Push"]:
		fuel_selector.add_item(fuel_target)
	for command in ["Conserve", "Race", "Overtake", "Defend"]:
		racecraft_selector.add_item(command)
	for order in ["Race freely", "Hold position", "Swap positions", "Help lead car", "Conserve equipment"]:
		team_order_selector.add_item(order)
	pit_service_selector.select(0)
	caution_service_selector.select(0)
	setup_selector.select(1)
	fuel_selector.select(1)
	racecraft_selector.select(1)
	speed_selector.select(1)
	_update_timer_speed()
	track_map.set_simulation(simulation)
	_apply_race_identity()
	for chart in [stint_chart, lap_time_chart, tyre_fuel_chart]:
		chart.set_simulation(simulation)
	caution_overlay.visible = false
	_refresh_display()


func _on_lap_timer_timeout() -> void:
	if simulation == null or is_paused or simulation.is_complete:
		return
	simulation.simulate_lap()
	_refresh_display()
	if simulation.is_complete:
		_finish_race()


func _toggle_pause() -> void:
	if simulation == null or simulation.is_complete or caution_choice_open:
		return
	is_paused = not is_paused
	pause_button.text = "Resume Race" if is_paused else "Pause Race"
	message_label.text = "SIMULATION PAUSED" if is_paused else "Pit window estimate: laps %d–%d" % [roundi(simulation.race.lap_count * 0.42), roundi(simulation.race.lap_count * 0.62)]
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


func _apply_pace() -> void:
	if simulation == null or simulation.is_complete:
		return
	var mode := pace_selector.get_item_text(pace_selector.selected)
	simulation.set_player_pace(mode)
	message_label.text = "%s mode will begin next lap" % mode
	_refresh_display()


func _advance_one_lap() -> void:
	if simulation == null or simulation.is_complete or caution_choice_open:
		return
	simulation.simulate_lap()
	_refresh_display()
	if simulation.is_complete:
		_finish_race()


func _request_pit_stop() -> void:
	if simulation == null or simulation.is_complete:
		return
	var service := _selected_pit_service(pit_service_selector)
	if simulation.request_player_pit_stop(service):
		_refresh_display()
		message_label.text = "PIT CONFIRMED - %s" % simulation.describe_pit_service(service)


func _populate_pit_services(selector: OptionButton) -> void:
	for service_value in simulation.get_pit_service_options().values():
		var service := service_value as Dictionary
		selector.add_item(str(service.label))
		selector.set_item_metadata(selector.item_count - 1, str(service.id))


func _selected_pit_service(selector: OptionButton) -> Dictionary:
	var service_id := str(selector.get_item_metadata(selector.selected)) if selector.selected >= 0 else "four_tyres_fuel"
	return (simulation.get_pit_service_options().get(service_id, simulation.get_pit_service_options().four_tyres_fuel) as Dictionary).duplicate(true)


func _on_pit_service_selected(_index: int) -> void:
	_refresh_pit_prediction()


func _on_caution_service_selected(_index: int) -> void:
	_refresh_caution_prediction()


func _on_caution_started(lap: int) -> void:
	if finalized or caution_choice_open or lap >= simulation.get_total_laps():
		return
	was_running_before_caution = not is_paused
	caution_choice_open = true
	is_paused = true
	lap_timer.stop()
	pause_button.text = "Resume Race"
	next_lap_button.disabled = true
	var caution_player := simulation.get_player_entry()
	caution_title.text = "CAUTION - LAP %d" % lap
	if caution_player != null:
		var weakest := "engine"
		for component in Car.DAMAGE_COMPONENTS:
			if float(caution_player.component_health.get(component, 100.0)) < float(caution_player.component_health.get(weakest, 100.0)):
				weakest = component
		caution_summary.text = "P%d | Tyres %d%% | Fuel %.1f laps | %s %d%%\nChoose service, protect the lead lap, or take a wave-around." % [caution_player.position, roundi(caution_player.tyre_condition), caution_player.fuel_laps / maxf(0.1, simulation.race.fuel_consumption_factor), weakest.capitalize(), roundi(float(caution_player.component_health.get(weakest, 100.0)))]
	caution_overlay.visible = true
	_refresh_caution_prediction()
	message_label.text = "YELLOW FLAG - SIMULATION PAUSED FOR STRATEGY"
	_refresh_display()


func _pit_under_caution() -> void:
	if simulation != null:
		var service := _selected_pit_service(caution_service_selector)
		simulation.request_player_pit_stop(service)
		_finish_caution_choice("PIT CONFIRMED - %s" % simulation.describe_pit_service(service))


func _wave_around_under_caution() -> void:
	var outcome := simulation.request_player_wave_around() if simulation != null else {}
	_finish_caution_choice(str(outcome.get("message", "Staying out under caution.")))


func _stay_out_under_caution() -> void:
	_finish_caution_choice("STAYING OUT • Track position protected under caution")


func _finish_caution_choice(message: String) -> void:
	if not caution_choice_open:
		return
	caution_choice_open = false
	caution_overlay.visible = false
	next_lap_button.disabled = false
	message_label.text = message
	if was_running_before_caution:
		is_paused = false
		pause_button.text = "Pause Race"
		lap_timer.start()
	_refresh_display()


func _refresh_pit_prediction() -> void:
	if simulation == null or pit_service_selector.item_count == 0:
		return
	var prediction := simulation.predict_player_pit_loss(_selected_pit_service(pit_service_selector))
	pit_prediction_label.text = "Projected %.1fs | lose %d-%d | likely rejoin P%d" % [float(prediction.get("time_loss", 0.0)), int(prediction.get("minimum_positions_lost", 0)), int(prediction.get("maximum_positions_lost", 0)), int(prediction.get("likely_rejoin_position", 0))]


func _refresh_caution_prediction() -> void:
	if simulation == null or caution_service_selector.item_count == 0:
		return
	var prediction := simulation.predict_player_pit_loss(_selected_pit_service(caution_service_selector))
	caution_prediction_label.text = "MODEL: %.1fs loss | lose %d-%d positions | likely P%d | confidence %d%%" % [float(prediction.get("time_loss", 0.0)), int(prediction.get("minimum_positions_lost", 0)), int(prediction.get("maximum_positions_lost", 0)), int(prediction.get("likely_rejoin_position", 0)), int(prediction.get("confidence", 0))]


func _request_engineer_update() -> void:
	if simulation != null:
		simulation.request_engineer_update()
		_refresh_engineer()


func _on_engineer_advice_ready(_advice: Dictionary) -> void:
	_refresh_engineer()


func _refresh_engineer() -> void:
	if simulation == null or simulation.latest_engineer_advice.is_empty():
		engineer_label.text = "[color=#8793a3]Engineer is reviewing the opening stint.[/color]"
		return
	var advice := simulation.latest_engineer_advice
	var confidence := int(advice.get("confidence", 0))
	var confidence_color := "#56d690" if confidence >= 80 else ("#f0c84b" if confidence >= 60 else "#ff8a65")
	engineer_label.text = "[b]%s  |  QUALITY %d[/b]\n[color=%s]CONFIDENCE %d%%[/color]\n%s" % [str(advice.get("category", "update")).to_upper(), int(advice.get("staff_quality", 0)), confidence_color, confidence, str(advice.get("message", "No recommendation."))]


func _apply_setup() -> void:
	if simulation == null or simulation.is_complete:
		return
	var setup := setup_selector.get_item_text(setup_selector.selected)
	simulation.set_player_brake_bias(setup)
	message_label.text = "%s brake bias applied" % setup
	_refresh_display()


func _apply_commands() -> void:
	if simulation == null or simulation.is_complete:
		return
	var fuel_target := fuel_selector.get_item_text(fuel_selector.selected)
	var command := racecraft_selector.get_item_text(racecraft_selector.selected)
	simulation.set_player_fuel_target(fuel_target)
	simulation.set_player_racecraft_command(command)
	message_label.text = "%s fuel · %s instruction" % [fuel_target, command]
	_refresh_display()


func _apply_team_order() -> void:
	if simulation == null or simulation.is_complete:
		return
	var order := team_order_selector.get_item_text(team_order_selector.selected)
	simulation.set_team_order(order, GameManager.team.team_name)
	weekend_data["team_order"] = order
	message_label.text = "Team order: %s" % order
	_refresh_display()


func _refresh_display() -> void:
	_refresh_header()
	_refresh_tower()
	_refresh_telemetry()
	_refresh_feed()
	_refresh_analysis()
	_refresh_engineer()
	_refresh_pit_prediction()
	track_map.queue_redraw()


func _refresh_analysis() -> void:
	for chart in [stint_chart, lap_time_chart, tyre_fuel_chart]:
		chart.queue_redraw()
	var player := simulation.get_player_entry()
	if player == null:
		return
	var pass_lines := PackedStringArray(["[b]PASSING SUMMARY[/b]", "Made %d passes · Lost %d positions · Net %+d" % [player.overtakes, player.overtaken, player.overtakes - player.overtaken]])
	for event in simulation.race_events:
		if str(event.get("type", "")) == "pass":
			pass_lines.append("L%d · %s" % [int(event.get("lap", 0)), str(event.get("detail", "Pass"))])
	if pass_lines.size() == 2:
		pass_lines.append("No recorded passing battles yet.")
	passing_summary.text = "\n".join(pass_lines)
	var caution_lines := PackedStringArray(["[b]CAUTION TIMELINE[/b]"])
	for event in simulation.race_events:
		if str(event.get("type", "")) in ["caution", "caution_outcome"]:
			caution_lines.append("L%d · %s\n%s" % [int(event.get("lap", 0)), str(event.get("title", "Caution")), str(event.get("detail", ""))])
	if caution_lines.size() == 1:
		caution_lines.append("No cautions to report.")
	caution_timeline.text = "\n\n".join(caution_lines)
	var comparison_lines := PackedStringArray(["[b]TEAMMATE & RIVAL COMPARISON[/b]"])
	for entry in simulation.entries:
		if entry == player or (entry.team_name != player.team_name and abs(entry.position - player.position) > 1):
			continue
		var relation := "TEAMMATE" if entry.team_name == player.team_name else ("CAR AHEAD" if entry.position < player.position else "CAR BEHIND")
		var signed_gap := entry.elapsed_time - player.elapsed_time
		comparison_lines.append("%s · P%d %s\nGap %+.2fs · Last %.3fs · Best %.3fs · Tyre %d%% · Fuel %d%%" % [relation, entry.position, entry.driver_name, signed_gap, entry.last_lap_time, entry.best_lap_time, roundi(entry.tyre_condition), roundi(entry.fuel_remaining)])
	if comparison_lines.size() == 1:
		comparison_lines.append("No teammate or adjacent rival comparison is available yet.")
	comparison_summary.text = "\n\n".join(comparison_lines)


func _refresh_header() -> void:
	if simulation == null:
		return
	flag_label.text = "●  %s" % simulation.race_state
	flag_label.modulate = Color("55d68b") if simulation.race_state == "GREEN FLAG" else (Color("f0c84b") if simulation.race_state in ["SAFETY CAR", "RESTART"] else Color("f4f6fa"))
	var series_identity := SeriesCatalog.get_identity(simulation.race.series_id)
	race_title.text = "%s / %s  ·  LAP %d / %d%s" % [str(series_identity.short_name), simulation.race.race_name.to_upper(), simulation.current_lap, simulation.get_total_laps(), " (OVERTIME)" if simulation.overtime_attempts > 0 else ""]
	var speed := SPEEDS[speed_selector.selected] if speed_selector.selected >= 0 else 1
	speed_label.text = ("PAUSED  •  " if is_paused else "LIVE  •  ") + "%d× SPEED" % speed


func _refresh_tower() -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var text := "[table=6][cell][b]POS[/b][/cell][cell][b]DRIVER / TEAM[/b][/cell][cell][b]CHANGE[/b][/cell][cell][b]GAP[/b][/cell][cell][b]LAST[/b][/cell][cell][b]TYRE / STATUS[/b][/cell]"
	for entry in simulation.entries:
		var change := entry.starting_position - entry.position
		var change_text := "—" if change == 0 else ("↑%d" % change if change > 0 else "↓%d" % abs(change))
		var gap := "LEADER" if entry.position == 1 else "+%.3f" % entry.gap_to(leader)
		var lap := "—" if entry.last_lap_time <= 0.0 else "%.3f" % entry.last_lap_time
		var tyre := "%d%%" % roundi(entry.tyre_condition)
		var identity := _team_identity(entry.team_id, entry.team_name, entry.is_player)
		var primary_hex := str(identity.primary_color)
		var driver_cell := "[color=#%s]▌[/color] [b]%s[/b] [color=#8491a3]· %s[/color]" % [primary_hex, entry.driver_name, str(identity.short_name)]
		var status := entry.pace_mode if entry.is_player else entry.status
		var values := ["P%d" % entry.position, driver_cell, change_text, gap, lap, "%s · %s" % [tyre, status]]
		for value in values:
			if entry.is_player:
				text += "[cell bg=#%s33][color=#ffffff]%s[/color][/cell]" % [primary_hex, value]
			else:
				text += "[cell]%s[/cell]" % value
	timing_tower.text = text + "[/table]"


func _team_identity(team_id: String, team_name: String, is_player: bool) -> Dictionary:
	if is_player:
		return {"primary_color":GameManager.team.primary_color.to_html(false), "secondary_color":GameManager.team.secondary_color.to_html(false), "short_name":team_name.left(14).to_upper()}
	var organization := TeamCatalog.get_team(simulation.race.series_id, team_id)
	if organization.is_empty() and GameManager.team != null:
		for candidate in GameManager.team.get_ai_organizations_for_series(simulation.race.series_id):
			if str(candidate.team_id) == team_id:
				organization = candidate
				break
	return {"primary_color":str(organization.get("primary_color", "6d93a8")), "secondary_color":str(organization.get("secondary_color", "101d24")), "short_name":str(organization.get("short_name", team_name.left(14))).to_upper()}


func _apply_race_identity() -> void:
	if simulation == null:
		return
	var presentation := TrackPresentationCatalog.get_profile(simulation.race)
	var accent := presentation.get("accent", Color("e85d45")) as Color
	var header := $Root/Header as PanelContainer
	var style := header.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent
	header.add_theme_stylebox_override("panel", style)
	message_label.modulate = accent.lightened(0.16)


func _refresh_telemetry() -> void:
	var player := simulation.get_player_entry()
	if player == null:
		return
	var ahead := "—" if player.position == 1 else "%.2fs" % player.gap_to(simulation.entries[player.position - 2])
	var behind := "—" if player.position == simulation.entries.size() else "%.2fs" % simulation.entries[player.position].gap_to(player)
	var change := player.starting_position - player.position
	var trend := "—" if change == 0 else ("↑%d" % change if change > 0 else "↓%d" % abs(change))
	var pace := "STRONG" if player.last_lap_time <= player.best_lap_time + 0.18 else "MANAGING"
	telemetry.text = "[table=2]" + \
		"[cell][color=#778493]POSITION[/color]\n[b]P%d  %s[/b][/cell]" % [player.position, trend] + \
		"[cell][color=#778493]TYRES[/color]\n[b]%d%%  %s  %d°C[/b][/cell]" % [roundi(player.tyre_condition), player.tyre_compound, roundi(player.tyre_temperature)] + \
		"[cell][color=#778493]GAP AHEAD[/color]\n[b]%s[/b][/cell]" % ahead + \
		"[cell][color=#778493]GAP BEHIND[/color]\n[b]%s[/b][/cell]" % behind + \
		"[cell][color=#778493]FUEL LAPS / CAR / SYSTEMS[/color]\n[b]%.1f  /  %d%%  /  %d%%[/b][/cell]" % [player.fuel_laps / maxf(0.1, simulation.race.fuel_consumption_factor), roundi(player.car_condition), roundi(player.mechanical_health)] + \
		"[cell][color=#778493]PACE[/color]\n[b]%s[/b][/cell]" % pace + \
		"[cell][color=#778493]BRAKE BIAS[/color]\n[b]%s[/b][/cell]" % player.brake_bias + \
		"[cell][color=#778493]PIT STOPS[/color]\n[b]%d[/b][/cell]" % player.pit_stops + \
		"[cell][color=#778493]TRACK[/color]\n[b]%s · %d%% GRIP[/b][/cell]" % [simulation.weather_state, roundi(simulation.track_grip * 100.0)] + \
		"[cell][color=#778493]COMMANDS[/color]\n[b]%s FUEL · %s[/b][/cell][/table]" % [player.fuel_target_mode, player.racecraft_command]

	var component_lines: Array[String] = []
	for component in Car.DAMAGE_COMPONENTS:
		var health := roundi(float(player.component_health.get(component, 100.0)))
		var color := "#56d690" if health >= 85 else ("#f0c84b" if health >= 60 else "#ff6b62")
		component_lines.append("[color=%s]%s %d%%[/color]" % [color, component.left(4).to_upper(), health])
	telemetry.text += "\n[color=#778493]COMPONENT HEALTH[/color]\n" + "  |  ".join(component_lines)


func _refresh_feed() -> void:
	var first := maxi(0, simulation.event_log.size() - 8)
	var lines := PackedStringArray()
	for index in range(first, simulation.event_log.size()):
		lines.append(simulation.event_log[index])
	event_feed.text = "\n".join(lines)
	event_feed.scroll_to_line(maxi(0, lines.size() - 1))


func _finish_race() -> void:
	if finalized:
		return
	finalized = true
	is_paused = true
	lap_timer.stop()
	pause_button.disabled = true
	apply_pace_button.disabled = true
	pit_button.disabled = true
	apply_setup_button.disabled = true
	apply_command_button.disabled = true
	apply_team_order_button.disabled = true
	engineer_request_button.disabled = true
	caution_overlay.visible = false
	next_lap_button.disabled = true
	message_label.text = "Race complete — preparing official results"
	var result := RaceManager.finalize_live_race(simulation, GameManager.selected_car, str(weekend_data.get("strategy_id", "balanced")), weekend_data)
	GameManager.active_race_weekend.clear()
	if result == null:
		message_label.text = "The race could not be finalized."
		return
	await get_tree().create_timer(1.2).timeout
	GameManager.load_page("res://scenes/pages/race_results/race_results.tscn")


func show_error() -> void:
	race_title.text = "LIVE RACE UNAVAILABLE"
	message_label.text = "The active race entry could not be loaded."
	pause_button.disabled = true
	apply_pace_button.disabled = true
	next_lap_button.disabled = true
