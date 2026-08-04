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
@onready var tyre_selector: OptionButton = %tyre_selector
@onready var pit_button: Button = %pit_button
@onready var setup_selector: OptionButton = %setup_selector
@onready var apply_setup_button: Button = %apply_setup_button
@onready var fuel_selector: OptionButton = %fuel_selector
@onready var racecraft_selector: OptionButton = %racecraft_selector
@onready var apply_command_button: Button = %apply_command_button
@onready var team_order_selector: OptionButton = %team_order_selector
@onready var apply_team_order_button: Button = %apply_team_order_button
@onready var track_map: LiveTrackMap = %track_map
@onready var caution_dialog: ConfirmationDialog = %caution_dialog

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
	caution_dialog.confirmed.connect(_pit_under_caution)
	caution_dialog.canceled.connect(_stay_out_under_caution)
	for speed in SPEEDS:
		speed_selector.add_item("%dx" % speed)
	pace_selector.add_item("Conserve")
	pace_selector.add_item("Balanced")
	pace_selector.add_item("Attack")
	pace_selector.select(1)
	tyre_selector.add_item("Standard")
	for setup in ["Forward", "Neutral", "Rearward"]:
		setup_selector.add_item(setup)
	for fuel_target in ["Save", "Balanced", "Push"]:
		fuel_selector.add_item(fuel_target)
	for command in ["Conserve", "Race", "Overtake", "Defend"]:
		racecraft_selector.add_item(command)
	for order in ["Race freely", "Hold position", "Swap positions", "Help lead car", "Conserve equipment"]:
		team_order_selector.add_item(order)
	tyre_selector.select(0)
	setup_selector.select(1)
	fuel_selector.select(1)
	racecraft_selector.select(1)
	speed_selector.select(1)
	_update_timer_speed()
	track_map.set_simulation(simulation)
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
	var compound := tyre_selector.get_item_text(tyre_selector.selected)
	if simulation.request_player_pit_stop(compound):
		message_label.text = "PIT CONFIRMED • Box next lap for fresh tyres"
		_refresh_display()


func _on_caution_started(lap: int) -> void:
	if finalized or caution_choice_open or lap >= simulation.race.lap_count:
		return
	was_running_before_caution = not is_paused
	caution_choice_open = true
	is_paused = true
	lap_timer.stop()
	pause_button.text = "Resume Race"
	next_lap_button.disabled = true
	var player := simulation.get_player_entry()
	var position_text := ""
	if player != null:
		position_text = "\n\nYou are P%d with %d%% tyre life and %.1f fuel laps remaining." % [player.position, roundi(player.tyre_condition), player.fuel_laps / maxf(0.1, simulation.race.fuel_consumption_factor)]
	caution_dialog.dialog_text = "Caution on lap %d. The field is compressed and pit-lane time loss is reduced.%s\n\nPit for fresh tyres and fuel, or stay out to protect track position?" % [lap, position_text]
	message_label.text = "YELLOW FLAG • SIMULATION PAUSED FOR PIT DECISION"
	_refresh_display()
	caution_dialog.popup_centered(Vector2i(520, 250))


func _pit_under_caution() -> void:
	if simulation != null:
		simulation.request_player_pit_stop("Standard")
	_finish_caution_choice("PIT CONFIRMED • Box under caution for fresh tyres and fuel")


func _stay_out_under_caution() -> void:
	_finish_caution_choice("STAYING OUT • Track position protected under caution")


func _finish_caution_choice(message: String) -> void:
	if not caution_choice_open:
		return
	caution_choice_open = false
	next_lap_button.disabled = false
	message_label.text = message
	if was_running_before_caution:
		is_paused = false
		pause_button.text = "Pause Race"
		lap_timer.start()
	_refresh_display()


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
	track_map.queue_redraw()


func _refresh_header() -> void:
	if simulation == null:
		return
	race_title.text = "%s — LAP %d / %d" % [simulation.race.race_name.to_upper(), simulation.current_lap, simulation.race.lap_count]
	flag_label.text = "●  %s" % simulation.race_state
	flag_label.modulate = Color("55d68b") if simulation.race_state == "GREEN FLAG" else (Color("f0c84b") if simulation.race_state in ["SAFETY CAR", "RESTART"] else Color("f4f6fa"))
	var speed := SPEEDS[speed_selector.selected] if speed_selector.selected >= 0 else 1
	speed_label.text = ("PAUSED  •  " if is_paused else "LIVE  •  ") + "%d× SPEED" % speed


func _refresh_tower() -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var primary_hex := GameManager.team.primary_color.to_html(false)
	var text := "[table=8][cell][b]POS[/b][/cell][cell][b]DRIVER[/b][/cell][cell][b]CHANGE[/b][/cell][cell][b]GAP[/b][/cell][cell][b]LAST LAP[/b][/cell][cell][b]BEST[/b][/cell][cell][b]TYRE LIFE[/b][/cell][cell][b]STATUS[/b][/cell]"
	for entry in simulation.entries:
		var change := entry.starting_position - entry.position
		var change_text := "—" if change == 0 else ("↑%d" % change if change > 0 else "↓%d" % abs(change))
		var gap := "LEADER" if entry.position == 1 else "+%.3f" % entry.gap_to(leader)
		var lap := "—" if entry.last_lap_time <= 0.0 else "%.3f" % entry.last_lap_time
		var best := "—" if entry.best_lap_time <= 0.0 else "%.3f" % entry.best_lap_time
		var tyre := "%d%%" % roundi(entry.tyre_condition)
		var values := ["P%d" % entry.position, entry.driver_name, change_text, gap, lap, best, tyre, entry.pace_mode if entry.is_player else entry.status]
		for value in values:
			if entry.is_player:
				text += "[cell bg=#%s][color=#ffffff][b]%s[/b][/color][/cell]" % [primary_hex, value]
			else:
				text += "[cell]%s[/cell]" % value
	timing_tower.text = text + "[/table]"


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
