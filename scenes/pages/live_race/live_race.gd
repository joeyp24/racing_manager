extends Control

const SPEEDS: Array[int] = [1, 2, 4, 8]

@onready var race_title: Label = %race_title
@onready var flag_label: Label = %flag_label
@onready var speed_label: Label = %speed_label
@onready var message_label: Label = %message_label
@onready var timing_tower: RichTextLabel = %timing_tower
@onready var telemetry: Label = %telemetry
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

var simulation: RaceSimulation
var lap_timer := Timer.new()
var is_paused: bool = true
var finalized: bool = false
var weekend_data: Dictionary = {}


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
	for speed in SPEEDS:
		speed_selector.add_item("%dx" % speed)
	pace_selector.add_item("Conserve")
	pace_selector.add_item("Balanced")
	pace_selector.add_item("Attack")
	pace_selector.select(1)
	for compound in ["Soft", "Medium", "Hard"]:
		tyre_selector.add_item(compound)
	for setup in ["Top Speed", "Balanced", "High Grip"]:
		setup_selector.add_item(setup)
	tyre_selector.select(1)
	setup_selector.select(1)
	speed_selector.select(1)
	_update_timer_speed()
	_refresh_display()


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
	lap_timer.wait_time = 1.1 / float(speed)
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
	if simulation == null or simulation.is_complete:
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
		message_label.text = "PIT CONFIRMED • Box next lap for %s tyres" % compound
		_refresh_display()


func _apply_setup() -> void:
	if simulation == null or simulation.is_complete:
		return
	var setup := setup_selector.get_item_text(setup_selector.selected)
	simulation.set_player_setup(setup)
	message_label.text = "%s setup applied" % setup
	_refresh_display()


func _refresh_display() -> void:
	_refresh_header()
	_refresh_tower()
	_refresh_telemetry()
	_refresh_feed()


func _refresh_header() -> void:
	if simulation == null:
		return
	race_title.text = "%s — LAP %d / %d" % [simulation.race.race_name.to_upper(), simulation.current_lap, simulation.race.lap_count]
	flag_label.text = simulation.race_state
	flag_label.modulate = Color("55d68b") if simulation.race_state == "GREEN FLAG" else Color("f4f6fa")
	var speed := SPEEDS[speed_selector.selected] if speed_selector.selected >= 0 else 1
	speed_label.text = ("PAUSED  •  " if is_paused else "") + "%dx SPEED" % speed


func _refresh_tower() -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var primary_hex := GameManager.team.primary_color.to_html(false)
	var text := "[table=8][cell][b]POS[/b][/cell][cell][b]DRIVER[/b][/cell][cell][b]CHANGE[/b][/cell][cell][b]GAP[/b][/cell][cell][b]LAST LAP[/b][/cell][cell][b]BEST[/b][/cell][cell][b]TYRE[/b][/cell][cell][b]STATUS[/b][/cell]"
	for entry in simulation.entries:
		var change := entry.starting_position - entry.position
		var change_text := "—" if change == 0 else ("↑%d" % change if change > 0 else "↓%d" % abs(change))
		var gap := "LEADER" if entry.position == 1 else "+%.3f" % entry.gap_to(leader)
		var lap := "—" if entry.last_lap_time <= 0.0 else "%.3f" % entry.last_lap_time
		var best := "—" if entry.best_lap_time <= 0.0 else "%.3f" % entry.best_lap_time
		var tyre := "%s %d%%" % [entry.tyre_compound.left(1), roundi(entry.tyre_condition)]
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
	telemetry.text = "POSITION\nP%d  %s\n\nGAP AHEAD\n%s\n\nGAP BEHIND\n%s\n\nTYRES\n%d%% %s\n\nPIT STOPS\n%d\n\nSETUP\n%s\n\nFUEL ESTIMATE\n%d%%\n\nCAR CONDITION\n%d%%\n\nPACE\n%s" % [player.position, trend, ahead, behind, roundi(player.tyre_condition), player.tyre_compound, player.pit_stops, player.setup_mode, roundi(player.fuel_remaining), roundi(player.car_condition), pace]


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
