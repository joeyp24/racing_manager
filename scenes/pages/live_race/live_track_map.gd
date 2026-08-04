class_name LiveTrackMap
extends Control

var simulation: RaceSimulation
var marker_progress: Dictionary = {}
var profile: Dictionary = {}


func set_simulation(value: RaceSimulation) -> void:
	simulation = value
	profile = TrackPresentationCatalog.get_profile(simulation.race) if simulation != null else {}
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
	if simulation == null or simulation.race == null or profile.is_empty():
		return
	var bounds := Rect2(Vector2(12.0, 8.0), size - Vector2(24.0, 16.0))
	draw_rect(bounds, Color("111820"), true)
	var points := _scaled_points(bounds)
	_draw_track_surface(points, bounds)
	_draw_pit_lane(points)
	_draw_track_features(points)
	_draw_status(bounds)
	_draw_markers(points)


func _draw_track_surface(points: PackedVector2Array, bounds: Rect2) -> void:
	draw_polyline(points, Color("1e2935"), 17.0, true)
	draw_polyline(points, Color("344354"), 11.0, true)
	var center := bounds.get_center()
	var groove_count := int(profile.get("grooves", 2))
	for groove_index in groove_count:
		var groove_points := PackedVector2Array()
		var strength := (float(groove_index) - float(groove_count - 1) * 0.5) * 0.018
		for point in points:
			groove_points.append(point.lerp(center, strength))
		draw_polyline(groove_points, Color("657182", 0.36), 1.2, true)


func _draw_pit_lane(points: PackedVector2Array) -> void:
	var entry_progress := float(profile.get("pit_entry", 0.72))
	var exit_progress := float(profile.get("pit_exit", 0.86))
	var entry := _point_at_progress(points, entry_progress)
	var exit := _point_at_progress(points, exit_progress)
	var center := _points_center(points)
	var lane_mid := entry.lerp(exit, 0.5).lerp(center, 0.22)
	var pit_points := PackedVector2Array([entry, entry.lerp(lane_mid, 0.5), lane_mid, lane_mid.lerp(exit, 0.5), exit])
	draw_polyline(pit_points, Color("9ca8b7"), 3.0, true)
	var font := get_theme_default_font()
	draw_string(font, entry + Vector2(5.0, -5.0), "PIT IN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("d8dee8"))
	draw_string(font, exit + Vector2(5.0, 12.0), "PIT OUT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("d8dee8"))


func _draw_track_features(points: PackedVector2Array) -> void:
	var font := get_theme_default_font()
	for sector_value in profile.get("sectors", []):
		var sector := sector_value as Dictionary
		var sector_point := _point_at_progress(points, float(sector.get("progress", 0.0)))
		draw_circle(sector_point, 6.0, Color("6fc7ff"), false, 2.0)
		draw_string(font, sector_point + Vector2(7.0, 11.0), str(sector.get("name", "S")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("8dd6ff"))
	for corner_value in profile.get("corners", []):
		var corner := corner_value as Dictionary
		var point := _point_at_progress(points, float(corner.get("progress", 0.0)))
		var passing := bool(corner.get("passing", false))
		draw_circle(point, 4.2 if passing else 2.8, Color("f0c84b") if passing else Color("7f8da0"))
		var label := "%s  %d deg%s" % [str(corner.get("name", "Turn")), int(corner.get("banking", 0)), "  PASS" if passing else ""]
		draw_string(font, point + Vector2(6.0, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("f4f6fa") if passing else Color("9aa6b6"))
	for caution_value in profile.get("caution_locations", []):
		var caution := caution_value as Dictionary
		var caution_point := _point_at_progress(points, float(caution.get("progress", 0.0)))
		var triangle := PackedVector2Array([caution_point + Vector2(0.0, -8.0), caution_point + Vector2(7.0, 5.0), caution_point + Vector2(-7.0, 5.0)])
		draw_colored_polygon(triangle, Color("f0c84b", 0.82))
	var camera_point := _point_at_progress(points, float(profile.get("camera_focus", 0.0)))
	draw_arc(camera_point, 8.0, 0.0, TAU, 16, Color("6fc7ff", 0.8), 1.5, true)


func _draw_status(bounds: Rect2) -> void:
	var flag_color := Color("f0c84b") if simulation.race_state in ["SAFETY CAR", "RESTART"] else Color("54d58a")
	if simulation.race_state == "CHECKERED FLAG":
		flag_color = Color("f4f6fa")
	var font := get_theme_default_font()
	draw_circle(bounds.position + Vector2(14.0, 14.0), 5.0, flag_color)
	draw_string(font, bounds.position + Vector2(26.0, 19.0), simulation.race_state, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("e8edf4"))
	var footer := "%s  |  %s  |  %s" % [simulation.race.track_name, str(profile.get("banking_summary", "")), str(profile.get("camera_style", "Track camera"))]
	draw_string(font, bounds.position + Vector2(10.0, bounds.size.y - 8.0), footer, HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x - 20.0, 10, Color("8b98a8"))


func _draw_markers(points: PackedVector2Array) -> void:
	if simulation.entries.is_empty():
		return
	var leader := simulation.entries[0]
	var font := get_theme_default_font()
	for entry in simulation.entries:
		if entry.status == "Retired":
			continue
		var progress := float(marker_progress.get(_entry_key(entry), _target_progress(entry)))
		var point := _point_at_progress(points, progress)
		var is_pitting := entry.last_pit_lap == simulation.current_lap
		if is_pitting:
			point = point.lerp(_points_center(points), 0.16)
		var color := Color("f05a38") if entry.is_player else Color("7aa2d6")
		if is_pitting:
			color = Color("d58cff")
		draw_circle(point, 7.0 if entry.is_player else 5.0, Color("0b1118"))
		draw_circle(point, 5.0 if entry.is_player else 3.5, color)
		if entry.is_player or entry.position <= 3:
			var gap := "LEAD" if entry.position == 1 else "+%.1f" % entry.gap_to(leader)
			var label := "P%d %s%s" % [entry.position, gap, " PIT" if is_pitting else ""]
			draw_string(font, point + Vector2(8.0, -5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("f4f6fa"))


func _scaled_points(bounds: Rect2) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in profile.get("points", PackedVector2Array()):
		scaled.append(bounds.position + Vector2(point.x * bounds.size.x, point.y * bounds.size.y))
	return scaled


func _point_at_progress(points: PackedVector2Array, progress: float) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var lengths: Array[float] = []
	var total := 0.0
	for index in range(points.size() - 1):
		var length := points[index].distance_to(points[index + 1])
		lengths.append(length)
		total += length
	var target := fposmod(progress, 1.0) * total
	var travelled := 0.0
	for index in lengths.size():
		if travelled + lengths[index] >= target:
			return points[index].lerp(points[index + 1], (target - travelled) / maxf(0.01, lengths[index]))
		travelled += lengths[index]
	return points[points.size() - 1]


func _points_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / maxf(1.0, float(points.size()))


func _target_progress(entry: RaceEntryState) -> float:
	var field_offset := float(simulation.entries.size() - entry.position) / maxf(1.0, float(simulation.entries.size())) * 0.10
	var lap_phase := float(simulation.current_lap % 3) / 3.0
	return fposmod(lap_phase + field_offset, 1.0)


func _entry_key(entry: RaceEntryState) -> String:
	return entry.driver_id if not entry.driver_id.is_empty() else entry.driver_name
