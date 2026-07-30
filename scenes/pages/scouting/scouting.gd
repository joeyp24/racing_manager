extends Control

@onready var series_filter: OptionButton = %series_filter
@onready var driver_list: VBoxContainer = %driver_list
@onready var detail: VBoxContainer = %detail
@onready var summary: Label = %summary

var selected_series_id := "all"
var selected_driver_id := ""
var entries: Array[Dictionary] = []


func _ready() -> void:
	GameManager.team.ensure_scouting_hours()
	series_filter.add_item("All series")
	series_filter.set_item_metadata(0, "all")
	for series in SeriesCatalog.SERIES:
		series_filter.add_item(str(series.name))
		series_filter.set_item_metadata(series_filter.item_count - 1, str(series.id))
	series_filter.item_selected.connect(_on_series_selected)
	_build_entries()
	_refresh_list()


func _build_entries() -> void:
	entries.clear()
	for series in SeriesCatalog.SERIES:
		var series_drivers: Array[Driver] = []
		for driver in GameManager.team.drivers:
			if driver != null and not driver.is_player_driver and driver.series_id == str(series.id):
				series_drivers.append(driver)
		var race_roster := AIRosterCatalog.get_roster(str(series.id))
		for index in mini(series_drivers.size(), race_roster.size()):
			entries.append({"driver":series_drivers[index], "race_driver":race_roster[index], "series":series})


func _refresh_list() -> void:
	_clear(driver_list)
	var visible: Array[Dictionary] = []
	for entry in entries:
		if selected_series_id == "all" or str(entry.series.id) == selected_series_id:
			visible.append(entry)
	summary.text = "%d drivers • %d / %d scouting hours this week • %s" % [visible.size(), GameManager.team.scouting_hours_remaining, GameManager.team.get_weekly_scouting_hours(), "every series" if selected_series_id == "all" else str(SeriesCatalog.get_series(selected_series_id).name)]
	if visible.is_empty():
		selected_driver_id = ""
		_show_empty_detail()
		return
	var selected_is_visible := false
	for entry in visible:
		if str(entry.race_driver.driver_id) == selected_driver_id:
			selected_is_visible = true
	if not selected_is_visible:
		selected_driver_id = str(visible[0].race_driver.driver_id)
	for entry in visible:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = str(entry.race_driver.driver_id) == selected_driver_id
		button.text = "%s\n%s  ·  OVR %d" % [entry.race_driver.driver_name, entry.race_driver.team_name, (entry.driver as Driver).get_overall_rating()]
		button.pressed.connect(_select_driver.bind(str(entry.race_driver.driver_id)))
		driver_list.add_child(button)
	_show_selected_driver()


func _show_selected_driver() -> void:
	_clear(detail)
	var entry := _get_selected_entry()
	if entry.is_empty():
		_show_empty_detail()
		return
	var driver := entry.driver as Driver
	var race_driver: Dictionary = entry.race_driver
	var title := Label.new()
	title.text = str(race_driver.driver_name)
	title.theme_type_variation = &"PageTitle"
	detail.add_child(title)
	_add_muted("%s  ·  %s  ·  Car #%d" % [entry.series.name, race_driver.team_name, race_driver.team_car_number])
	_add_section("DRIVER OVERVIEW")
	var overview := GridContainer.new()
	overview.columns = 4
	var report := GameManager.team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var potential_text := "%d–%d" % [report.get("potential_low", 0), report.get("potential_high", 99)] if report.get("revealed_potential", false) else "???"
	for item in [["OVR", driver.get_overall_rating()], ["Age", driver.age], ["Potential", potential_text], ["Interest", "%d%%" % int(GameManager.team.recruiting_progress.get(driver.driver_id, 0))]]:
		overview.add_child(_metric(str(item[0]), str(item[1])))
	detail.add_child(overview)
	_add_section("PERFORMANCE RATINGS")
	var ratings := GridContainer.new()
	ratings.columns = 2
	for row in driver.get_rating_rows():
		ratings.add_child(_metric(str(row.label), str(row.rating)))
	detail.add_child(ratings)
	_add_section("RECENT RACE RESULTS")
	var results := _recent_results(str(entry.series.id), str(race_driver.driver_id))
	if results.is_empty():
		_add_muted("No race results have been recorded for this driver yet.")
	else:
		for result in results:
			_add_body("%s  ·  P%d" % [result.race_name, result.position])
	_add_section("SCOUTING")
	report = GameManager.team.scouting_reports.get(driver.driver_id, {}) as Dictionary
	var active := _active_assignment(driver.driver_id)
	if not report.is_empty():
		var potential_summary := "%d–%d" % [report.get("potential_low", 0), report.get("potential_high", 99)] if report.get("revealed_potential", false) else "not scouted"
		_add_body("%s  ·  Potential %s  ·  %s  ·  Risk: %s" % [report.get("projected_role", "Unknown role"), potential_summary, report.get("strength", "Unknown strength"), report.get("risk", "Unknown")])
	_add_muted("Spend this week's hours to uncover ratings or build recruiting interest. Scouting HQ upgrades add 10 hours per week.")
	for action in Team.SCOUTING_ACTIONS:
		var hours := int((Team.SCOUTING_ACTIONS[action] as Dictionary).hours)
		var button := Button.new()
		button.text = "%s  •  %d hours" % [action, hours]
		button.disabled = GameManager.team.get_department_level("scouting") <= 0 or GameManager.team.scouting_hours_remaining < hours
		button.pressed.connect(_spend_hours.bind(driver, str(action)))
		detail.add_child(button)


func _recent_results(series_id: String, driver_id: String) -> Array[Dictionary]:
	var recent: Array[Dictionary] = []
	var races: Array = GameManager.team.get_world_series_data(series_id).get("results", [])
	for race_index in range(races.size() - 1, -1, -1):
		var race: Dictionary = races[race_index]
		for row in race.get("rows", []):
			if str(row.get("driver_id", "")) == driver_id:
				recent.append({"race_name":str(race.get("race_name", "Race")), "position":int(row.get("position", 0))})
				break
		if recent.size() == 5:
			break
	return recent


func _get_selected_entry() -> Dictionary:
	for entry in entries:
		if str(entry.race_driver.driver_id) == selected_driver_id:
			return entry
	return {}


func _active_assignment(driver_id: String) -> Dictionary:
	for assignment in GameManager.team.scouting_assignments:
		if assignment.get("driver_id") == driver_id:
			return assignment
	return {}


func _start_assignment(driver: Driver, choices: OptionButton) -> void:
	if GameManager.team.start_scouting_assignment(driver, choices.get_item_text(choices.selected)):
		GameManager.save_game()
		_show_selected_driver()


func _spend_hours(driver: Driver, action: String) -> void:
	if GameManager.team.spend_scouting_hours(driver, action):
		GameManager.save_game()
		_refresh_list()


func _on_series_selected(index: int) -> void:
	selected_series_id = str(series_filter.get_item_metadata(index))
	_refresh_list()


func _select_driver(driver_id: String) -> void:
	selected_driver_id = driver_id
	_refresh_list()


func _show_empty_detail() -> void:
	_clear(detail)
	_add_muted("Select a driver to open their scouting profile.")


func _metric(label_text: String, value: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new(); value_label.text = value; value_label.theme_type_variation = &"MetricValue"
	var label := Label.new(); label.text = label_text.to_upper(); label.theme_type_variation = &"EyebrowLabel"
	box.add_child(value_label); box.add_child(label)
	return box


func _add_section(value: String) -> void:
	var label := Label.new(); label.text = value; label.theme_type_variation = &"EyebrowLabel"
	detail.add_child(label)


func _add_body(value: String) -> void:
	var label := Label.new(); label.text = value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(label)


func _add_muted(value: String) -> void:
	var label := Label.new(); label.text = value; label.theme_type_variation = &"MutedLabel"; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(label)


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
