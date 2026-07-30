extends Control

@onready var series_selector: OptionButton = %series_selector
@onready var view_tabs: TabContainer = %view_tabs
@onready var standings_grid: GridContainer = %standings_grid
@onready var results_selector: OptionButton = %results_selector
@onready var results_grid: GridContainer = %results_grid
@onready var status_label: Label = %status_label

var selected_series_id: String = ""


func _ready() -> void:
	series_selector.item_selected.connect(_on_series_selected)
	results_selector.item_selected.connect(_display_selected_result)
	_populate_series_selector()


func _populate_series_selector() -> void:
	series_selector.clear()
	for series in SeriesCatalog.SERIES:
		var suffix := " (Your series)" if GameManager.team != null and str(series.id) == GameManager.team.current_series_id else ""
		series_selector.add_item(str(series.name) + suffix)
		series_selector.set_item_metadata(series_selector.item_count - 1, str(series.id))
	var initial := 0
	if GameManager.team != null:
		initial = (SeriesCatalog.get_index(GameManager.team.current_series_id) + 1) % SeriesCatalog.SERIES.size()
	series_selector.select(initial)
	_on_series_selected(initial)


func _on_series_selected(index: int) -> void:
	selected_series_id = str(series_selector.get_item_metadata(index))
	_refresh_page()


func _refresh_page() -> void:
	_clear_grid(standings_grid)
	_clear_grid(results_grid)
	results_selector.clear()
	if GameManager.team == null:
		status_label.text = "No career is loaded."
		return
	if selected_series_id == GameManager.team.current_series_id:
		status_label.text = "This is your active championship. Open Championship for your live standings."
		_build_standings(GameManager.team.get_sorted_championship_standings())
		return
	var data := GameManager.team.get_world_series_data(selected_series_id)
	var completed := int(data.get("completed_rounds", 0))
	var season_length := int(SeriesCatalog.get_series(selected_series_id).season_length)
	status_label.text = "Season %d  •  %d of %d rounds complete  •  Simulated alongside your career" % [int(data.get("season_number", 1)), completed, season_length]
	_build_standings(data.get("standings", []))
	var results: Array = data.get("results", [])
	for index in results.size():
		var result := results[index] as Dictionary
		results_selector.add_item("Round %d — %s" % [int(result.get("round", index + 1)), str(result.get("race_name", "Race"))])
		results_selector.set_item_metadata(index, index)
	if not results.is_empty():
		results_selector.select(results.size() - 1)
		_display_selected_result(results.size() - 1)


func _build_standings(standings: Array) -> void:
	_add_row(standings_grid, ["POS", "DRIVER / TEAM", "PTS", "WINS", "PODIUMS", "STARTS", "AVG"] , true)
	for index in standings.size():
		var entry := standings[index] as Dictionary
		var starts := int(entry.get("starts", 0))
		var average := "—" if starts == 0 else "%.1f" % (float(entry.get("average_finish_total", 0)) / starts)
		_add_row(standings_grid, [str(index + 1), "%s\n%s" % [entry.get("driver_name", "Unknown"), entry.get("team_name", "Unknown")], str(entry.get("points", 0)), str(entry.get("wins", 0)), str(entry.get("podiums", 0)), str(starts) if entry.has("starts") else "—", average])


func _display_selected_result(index: int) -> void:
	_clear_grid(results_grid)
	_add_row(results_grid, ["POS", "DRIVER", "TEAM"], true)
	if GameManager.team == null or selected_series_id == GameManager.team.current_series_id:
		return
	var results: Array = GameManager.team.get_world_series_data(selected_series_id).get("results", [])
	if index < 0 or index >= results.size():
		return
	for row in (results[index] as Dictionary).get("rows", []):
		_add_row(results_grid, [str(row.get("position", 0)), str(row.get("driver_name", "Unknown")), str(row.get("team_name", "Unknown"))])


func _add_row(grid: GridContainer, values: Array, header: bool = false) -> void:
	for value in values:
		var label := Label.new()
		label.text = str(value)
		label.custom_minimum_size = Vector2(72, 38)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if header:
			label.theme_type_variation = &"EyebrowLabel"
		grid.add_child(label)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
