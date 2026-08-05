class_name DriverPortrait
extends Control

var driver: Driver
var team_primary := Color("7c3aed")
var team_secondary := Color("111827")


func _ready() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()


func configure(value: Driver, primary: Color = Color("7c3aed"), secondary: Color = Color("111827")) -> void:
	driver = value
	team_primary = primary
	team_secondary = secondary
	if driver != null:
		PersonalityCatalog.assign_identity(driver)
		tooltip_text = "%s · %s\n%s" % [driver.driver_name, PersonalityCatalog.get_personality_name(driver), driver.personality_tagline]
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, team_secondary.darkened(0.28), true)
	draw_rect(Rect2(0, size.y * 0.76, size.x, size.y * 0.24), team_primary, true)
	if driver == null:
		draw_string(get_theme_default_font(), Vector2(10, size.y * 0.55), "DRIVER", HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 11, Color("a7b0c0"))
		return
	var seed := absi(hash(driver.driver_id if not driver.driver_id.is_empty() else driver.driver_name))
	var skin_tones := [Color("f1c7a5"), Color("d89b73"), Color("a96e4e"), Color("704631"), Color("edb98d")]
	var hair_tones := [Color("1b1716"), Color("4c2d1d"), Color("8a5b32"), Color("d2b071"), Color("35323a")]
	var skin: Color = skin_tones[seed % skin_tones.size()]
	var hair: Color = hair_tones[floori(float(seed) / 5.0) % hair_tones.size()]
	var center := Vector2(size.x * 0.5, size.y * 0.43)
	var radius := minf(size.x, size.y) * 0.205
	# Race suit and shoulders.
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.16, size.y), Vector2(size.x * 0.24, size.y * 0.73), Vector2(size.x * 0.41, size.y * 0.65), Vector2(size.x * 0.59, size.y * 0.65), Vector2(size.x * 0.76, size.y * 0.73), Vector2(size.x * 0.84, size.y)]), team_primary.lightened(0.08))
	draw_line(Vector2(size.x * 0.5, size.y * 0.68), Vector2(size.x * 0.5, size.y), team_secondary, 3.0)
	# Head, ears and hairstyle vary deterministically.
	draw_circle(center + Vector2(-radius * 0.94, radius * 0.05), radius * 0.22, skin)
	draw_circle(center + Vector2(radius * 0.94, radius * 0.05), radius * 0.22, skin)
	draw_circle(center, radius, skin)
	var hair_style := seed % 3
	if hair_style == 0:
		draw_arc(center + Vector2(0, -radius * 0.02), radius * 0.94, PI, TAU, 20, hair, radius * 0.45, true)
	elif hair_style == 1:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, -radius * 0.15), center + Vector2(-radius * 0.7, -radius), center + Vector2(radius * 0.82, -radius * 0.82), center + Vector2(radius, -radius * 0.05)]), hair)
	else:
		draw_arc(center, radius * 0.96, PI * 1.08, PI * 1.92, 18, hair, radius * 0.28, true)
	var eye_y := center.y + radius * 0.06
	var eye_gap := radius * 0.38
	draw_circle(Vector2(center.x - eye_gap, eye_y), maxf(1.2, radius * 0.065), Color("171925"))
	draw_circle(Vector2(center.x + eye_gap, eye_y), maxf(1.2, radius * 0.065), Color("171925"))
	var brow_tilt := -0.12 if driver.aggression >= 65 else 0.04
	draw_line(Vector2(center.x - eye_gap - radius * 0.16, eye_y - radius * 0.2), Vector2(center.x - eye_gap + radius * 0.14, eye_y - radius * (0.2 + brow_tilt)), hair, 1.6)
	draw_line(Vector2(center.x + eye_gap - radius * 0.14, eye_y - radius * (0.2 + brow_tilt)), Vector2(center.x + eye_gap + radius * 0.16, eye_y - radius * 0.2), hair, 1.6)
	var mouth_y := center.y + radius * 0.5
	var smile := 0.11 if driver.morale >= 55 else -0.06
	draw_arc(Vector2(center.x, mouth_y - radius * smile), radius * 0.24, 0.15, PI - 0.15, 10, Color("7b3f3f"), 1.5)
	var initial_parts: Array[String] = []
	for part in driver.driver_name.split(" "):
		initial_parts.append(str(part).left(1))
	var initials := "".join(initial_parts).left(2).to_upper()
	draw_string(get_theme_default_font(), Vector2(4, size.y - 6), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
