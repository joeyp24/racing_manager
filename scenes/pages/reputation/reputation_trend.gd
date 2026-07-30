extends Control

const SPORTING_COLOR := Color("40a6ff")
const PROFESSIONALISM_COLOR := Color("40d985")
const COMMERCIAL_COLOR := Color("ffa833")
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const BACKGROUND_COLOR := Color(0.02, 0.04, 0.07, 0.45)
const MAX_POINTS: int = 18

var trend_points: Array[Vector3] = []


func configure(history: Array, current_state: Dictionary, season: int) -> void:
	var current := Vector3(
		float(current_state.get("sporting_credibility", 50)),
		float(current_state.get("professionalism", 50)),
		float(current_state.get("commercial_appeal", 50))
	)
	trend_points = [current]
	var latest := current
	var accepted := 0
	for entry_value in history:
		if accepted >= MAX_POINTS - 1:
			break
		var entry := entry_value as Dictionary
		if int(entry.get("season", season)) != season:
			continue
		latest -= Vector3(
			float(entry.get("sporting_credibility", 0)),
			float(entry.get("professionalism", 0)),
			float(entry.get("commercial_appeal", 0))
		)
		trend_points.push_front(latest)
		accepted += 1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var plot := Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0))
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return
	draw_rect(plot, BACKGROUND_COLOR, true)
	for index in 5:
		var y := plot.position.y + plot.size.y * float(index) / 4.0
		draw_line(
			Vector2(plot.position.x, y),
			Vector2(plot.end.x, y),
			GRID_COLOR,
			1.0
		)
	if trend_points.size() < 2:
		_draw_empty_marker(plot, trend_points[0] if not trend_points.is_empty() else Vector3(50, 50, 50))
		return
	_draw_series(plot, 0, SPORTING_COLOR)
	_draw_series(plot, 1, PROFESSIONALISM_COLOR)
	_draw_series(plot, 2, COMMERCIAL_COLOR)


func _draw_series(plot: Rect2, axis: int, color: Color) -> void:
	var points := PackedVector2Array()
	for index in trend_points.size():
		var value := clampf(trend_points[index][axis], 0.0, 100.0)
		points.append(Vector2(
			plot.position.x + plot.size.x * float(index) / float(trend_points.size() - 1),
			plot.end.y - plot.size.y * value / 100.0
		))
	draw_polyline(points, color, 2.0, true)
	draw_circle(points[-1], 3.5, color)


func _draw_empty_marker(plot: Rect2, values: Vector3) -> void:
	var colors := [SPORTING_COLOR, PROFESSIONALISM_COLOR, COMMERCIAL_COLOR]
	for axis in 3:
		var value := clampf(values[axis], 0.0, 100.0)
		var x := plot.position.x + plot.size.x * (0.42 + float(axis) * 0.08)
		var y := plot.end.y - plot.size.y * value / 100.0
		draw_circle(Vector2(x, y), 3.5, colors[axis])
