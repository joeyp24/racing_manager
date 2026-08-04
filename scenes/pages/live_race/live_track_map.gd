class_name LiveTrackMap
extends Control

var simulation: RaceSimulation
var marker_progress: Dictionary = {}


func set_simulation(value: RaceSimulation) -> void:
	simulation = value
	set_process(simulation != null)
	queue_redraw()


func _process(_delta: float) -> void:
	if simulation == null or simulation.entries.is_empty():
		return
	for entry in simulation.entries:
		var key := _entry_key(entry)
		var target := _target_progress(entry)
		if not marker_progress.has(key):
			marker_progress[key] = target
		else:
			var current_angle := float(marker_progress[key]) * TAU
			var target_angle := target * TAU
			marker_progress[key] = fposmod(lerp_angle(current_angle, target_angle, 0.16) / TAU, 1.0)
	queue_redraw()


func _draw() -> void:
	if simulation == null or simulation.race == null:
		return
	var bounds := Rect2(Vector2(12.0, 8.0), size - Vector2(24.0, 16.0))
	var track_color := Color("344354")
	var inside_color := Color("111820")
	draw_rect(bounds, inside_color, true)
	if simulation.race.is_oval():
		_draw_oval(bounds, track_color)
	else:
		_draw_road_course(bounds, track_color)
	_draw_status(bounds)
	_draw_markers(bounds)


func _draw_oval(bounds: Rect2, track_color: Color) -> void:
	var center := bounds.get_center()
	var radius := Vector2(maxf(48.0, bounds.size.x * 0.40), maxf(28.0, bounds.size.y * 0.34))
	var points := PackedVector2Array()
	for index in 65:
		var angle := TAU * float(index) / 64.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, Color("1e2935"), 15.0, true)
	draw_polyline(points, track_color, 9.0, true)
	var pit_y := center.y + radius.y + 12.0
	draw_line(Vector2(center.x - radius.x * 0.55, pit_y), Vector2(center.x + radius.x * 0.55, pit_y), Color("8b98a8"), 3.0, true)


func _draw_road_course(bounds: Rect2, track_color: Color) -> void:
	var points := _road_points(bounds)
	draw_polyline(points, Color("1e2935"), 15.0, true)
	draw_polyline(points, track_color, 9.0, true)
	var pit_start := bounds.position + Vector2(bounds.size.x * 0.56, bounds.size.y * 0.78)
	draw_line(pit_start, pit_start + Vector2(bounds.size.x * 0.26, -4.0), Color("8b98a8"), 3.0, true)


func _draw_status(bounds: Rect2) -> void:
	var flag_color := Color("f0c84b") if simulation.race_state in ["SAFETY CAR", "RESTART"] else Color("54d58a")
	if simulation.race_state == "CHECKERED FLAG":
		flag_color = Color("f4f6fa")
	var font := get_theme_default_font()
	draw_circle(bounds.position + Vector2(14.0, 14.0), 5.0, flag_color)
	draw_string(font, bounds.position + Vector2(26.0, 19.0), simulation.race_state, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("e8edf4"))
	draw_string(font, bounds.position + Vector2(10.0, bounds.size.y - 8.0), "%s  •  %s" % [simulation.race.track_name, "OVAL" if simulation.race.is_oval() else simulation.race.track_type.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("8b98a8"))


func _draw_markers(bounds: Rect2) -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var font := get_theme_default_font()
	for entry in simulation.entries:
		if entry.status == "Retired":
			continue
		var progress := float(marker_progress.get(_entry_key(entry), _target_progress(entry)))
		var point := _point_on_track(bounds, progress)
		var is_pitting := entry.last_pit_lap == simulation.current_lap
		if is_pitting:
			point.y += 12.0
		var color := Color("f05a38") if entry.is_player else Color("7aa2d6")
		if is_pitting:
			color = Color("d58cff")
		draw_circle(point, 7.0 if entry.is_player else 5.0, Color("0b1118"))
		draw_circle(point, 5.0 if entry.is_player else 3.5, color)
		if entry.is_player or entry.position <= 3:
			var gap := "LEAD" if entry.position == 1 else "+%.1f" % entry.gap_to(leader)
			var label := "P%d %s%s" % [entry.position, gap, " PIT" if is_pitting else ""]
			draw_string(font, point + Vector2(8.0, -5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("f4f6fa"))


func _point_on_track(bounds: Rect2, progress: float) -> Vector2:
	if simulation.race.is_oval():
		var center := bounds.get_center()
		var radius := Vector2(maxf(48.0, bounds.size.x * 0.40), maxf(28.0, bounds.size.y * 0.34))
		var angle := progress * TAU
		return center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
	var points := _road_points(bounds)
	var segment_progress := progress * float(points.size() - 1)
	var index := mini(points.size() - 2, floori(segment_progress))
	return points[index].lerp(points[index + 1], segment_progress - float(index))


func _road_points(bounds: Rect2) -> PackedVector2Array:
	var origin := bounds.position
	var extent := bounds.size
	return PackedVector2Array([
		origin + Vector2(extent.x * 0.18, extent.y * 0.28),
		origin + Vector2(extent.x * 0.52, extent.y * 0.16),
		origin + Vector2(extent.x * 0.84, extent.y * 0.30),
		origin + Vector2(extent.x * 0.70, extent.y * 0.50),
		origin + Vector2(extent.x * 0.88, extent.y * 0.72),
		origin + Vector2(extent.x * 0.52, extent.y * 0.84),
		origin + Vector2(extent.x * 0.32, extent.y * 0.62),
		origin + Vector2(extent.x * 0.12, extent.y * 0.72),
		origin + Vector2(extent.x * 0.18, extent.y * 0.28)
	])


func _target_progress(entry: RaceEntryState) -> float:
	var race_progress := float(maxi(0, simulation.current_lap - 1)) / maxf(1.0, float(simulation.race.lap_count))
	var field_offset := float(simulation.entries.size() - entry.position) / maxf(1.0, float(simulation.entries.size())) * 0.055
	return fposmod(race_progress + field_offset, 1.0)


func _entry_key(entry: RaceEntryState) -> String:
	return entry.driver_id if not entry.driver_id.is_empty() else entry.driver_name
