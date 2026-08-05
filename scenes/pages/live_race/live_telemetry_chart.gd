class_name LiveTelemetryChart
extends Control

@export_enum("Stints", "Lap Times", "Tyre & Fuel") var chart_mode: String = "Lap Times"
const STINT_COLORS: Array[Color] = [Color("4f9ee8"), Color("a96fe8"), Color("e8884f"), Color("52c98b")]

var simulation: RaceSimulation


func set_simulation(value: RaceSimulation) -> void:
	simulation = value
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2(42.0, 14.0), size - Vector2(54.0, 38.0))
	draw_rect(bounds, Color("101820"), true)
	for division in range(1, 4):
		var y := bounds.position.y + bounds.size.y * float(division) / 4.0
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color("273646"), 1.0)
	for division in range(1, 5):
		var x := bounds.position.x + bounds.size.x * float(division) / 5.0
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), Color("202e3c"), 1.0)
	draw_line(Vector2(bounds.position.x, bounds.end.y), bounds.end, Color("536173"), 1.0)
	draw_line(bounds.position, Vector2(bounds.position.x, bounds.end.y), Color("536173"), 1.0)
	if simulation == null or simulation.telemetry_history.is_empty():
		_draw_label("Telemetry begins after lap 1", bounds.get_center() - Vector2(70.0, 0.0), Color("8996a6"))
		return
	match chart_mode:
		"Stints":
			_draw_stints(bounds)
		"Tyre & Fuel":
			_draw_resources(bounds)
		_:
			_draw_lap_times(bounds)


func _draw_lap_times(bounds: Rect2) -> void:
	var values: Array[float] = []
	for sample in simulation.telemetry_history:
		values.append(float(sample.get("lap_time", 0.0)))
	_draw_series(bounds, values, Color("61b7ff"), false)
	_draw_label("LAP TIME", Vector2(bounds.position.x, 11.0), Color("8fa1b5"))
	_draw_label("%.3fs latest" % values[-1], Vector2(bounds.position.x + 78.0, 11.0), Color("eef3f8"))


func _draw_resources(bounds: Rect2) -> void:
	var tyres: Array[float] = []
	var fuel: Array[float] = []
	for sample in simulation.telemetry_history:
		tyres.append(float(sample.get("tyre", 100.0)))
		fuel.append(float(sample.get("fuel", 100.0)))
	_draw_series(bounds, tyres, Color("f3c84a"), true)
	_draw_series(bounds, fuel, Color("59d79a"), true)
	_draw_label("TYRE", Vector2(bounds.position.x, 11.0), Color("f3c84a"))
	_draw_label("FUEL", Vector2(bounds.position.x + 55.0, 11.0), Color("59d79a"))


func _draw_stints(bounds: Rect2) -> void:
	var previous_stint := int(simulation.telemetry_history[0].get("stint", 0))
	var segment_start := 0
	for index in range(1, simulation.telemetry_history.size() + 1):
		var changed: bool = index == simulation.telemetry_history.size() or int(simulation.telemetry_history[index].get("stint", previous_stint)) != previous_stint
		if not changed:
			continue
		var x_start := bounds.position.x + bounds.size.x * float(segment_start) / float(maxi(1, simulation.telemetry_history.size()))
		var x_end := bounds.position.x + bounds.size.x * float(index) / float(maxi(1, simulation.telemetry_history.size()))
		var color: Color = STINT_COLORS[previous_stint % STINT_COLORS.size()]
		draw_rect(Rect2(Vector2(x_start, bounds.position.y + 18.0), Vector2(maxf(2.0, x_end - x_start - 2.0), bounds.size.y - 36.0)), color, true)
		_draw_label("STINT %d" % (previous_stint + 1), Vector2(x_start + 5.0, bounds.get_center().y + 4.0), Color.WHITE)
		segment_start = index
		if index < simulation.telemetry_history.size():
			previous_stint = int(simulation.telemetry_history[index].get("stint", previous_stint))
	_draw_label("STINT PLAN / PIT CYCLES", Vector2(bounds.position.x, 11.0), Color("8fa1b5"))


func _draw_series(bounds: Rect2, values: Array[float], color: Color, percentage: bool) -> void:
	if values.is_empty():
		return
	var minimum: float = 0.0 if percentage else float(values.min())
	var maximum: float = 100.0 if percentage else float(values.max())
	if is_equal_approx(minimum, maximum):
		maximum = minimum + 1.0
	var points := PackedVector2Array()
	for index in values.size():
		var x := bounds.position.x + bounds.size.x * float(index) / float(maxi(1, values.size() - 1))
		var normalized: float = (values[index] - minimum) / (maximum - minimum)
		var y: float = bounds.end.y - normalized * bounds.size.y
		points.append(Vector2(x, y))
	if points.size() == 1:
		draw_circle(points[0], 3.0, color)
	else:
		draw_polyline(points, color, 2.4, true)
		draw_circle(points[-1], 3.2, color.lightened(0.18))
	_draw_label("%d" % roundi(maximum) if percentage else "%.2f" % maximum, Vector2(3.0, bounds.position.y + 8.0), Color("718196"))
	_draw_label("%d" % roundi(minimum) if percentage else "%.2f" % minimum, Vector2(3.0, bounds.end.y), Color("718196"))


func _draw_label(value: String, position: Vector2, color: Color) -> void:
	draw_string(get_theme_default_font(), position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, color)
