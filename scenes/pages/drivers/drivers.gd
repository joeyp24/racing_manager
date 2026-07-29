extends Control

@onready var roster_container: VBoxContainer = %roster_container
@onready var summary_label: Label = %summary_label


func _ready() -> void:
	refresh_roster()


func refresh_roster() -> void:
	var team: Team = GameManager.team
	var drivers := team.get_contracted_drivers()
	summary_label.text = "%d / %d contracted  •  Complete performance, potential and career profiles" % [drivers.size(), team.get_driver_roster_limit()]
	for child in roster_container.get_children():
		child.queue_free()
	if drivers.is_empty():
		var empty := Label.new()
		empty.text = "No drivers are under contract. Visit Driver Hiring from the Employees section."
		roster_container.add_child(empty)
		return
	for driver in drivers:
		roster_container.add_child(create_driver_profile(driver))


func create_driver_profile(driver: Driver) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	var profile := VBoxContainer.new()
	profile.add_theme_constant_override("separation", 14)
	profile.add_child(_create_header(driver))
	profile.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.add_child(_create_personal_column(driver))
	columns.add_child(_create_ratings_column(driver, driver.get_rating_rows().slice(0, 5), "PACE & RACECRAFT"))
	columns.add_child(_create_ratings_column(driver, driver.get_rating_rows().slice(5, 10), "CONTROL & TECHNICAL"))
	profile.add_child(columns)
	profile.add_child(HSeparator.new())
	profile.add_child(_create_career_row(driver))
	margin.add_child(profile)
	card.add_child(margin)
	return card


func _create_header(driver: Driver) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var badge := Label.new()
	badge.text = str(driver.get_overall_rating())
	badge.tooltip_text = "Overall is the rounded average of all ten performance ratings."
	badge.add_theme_font_size_override("font_size", 38)
	badge.custom_minimum_size = Vector2(76, 62)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Label.new()
	name.theme_type_variation = &"SectionTitle"
	name.text = "%s  ·  #%02d" % [driver.driver_name, driver.preferred_number]
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"MutedLabel"
	subtitle.text = "%s  •  %s  •  %s" % [driver.archetype, driver.team_name, driver.nationality]
	identity.add_child(name)
	identity.add_child(subtitle)
	var ceiling := VBoxContainer.new()
	var potential_title := Label.new()
	potential_title.text = "POTENTIAL OVR"
	potential_title.theme_type_variation = &"MutedLabel"
	var potential_value := Label.new()
	potential_value.text = str(driver.get_potential_overall())
	potential_value.add_theme_font_size_override("font_size", 28)
	potential_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ceiling.add_child(potential_title)
	ceiling.add_child(potential_value)
	row.add_child(badge)
	row.add_child(identity)
	row.add_child(ceiling)
	return row


func _create_personal_column(driver: Driver) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	var title := Label.new()
	title.text = "DRIVER PROFILE"
	title.theme_type_variation = &"BodyStrong"
	column.add_child(title)
	_add_detail(column, "Age", str(driver.age))
	_add_detail(column, "Hometown", driver.hometown)
	_add_detail(column, "Height / weight", "%d cm  /  %d kg" % [driver.height_cm, driver.weight_kg])
	_add_detail(column, "Background", driver.racing_background)
	var bio := Label.new()
	bio.text = driver.biography
	bio.theme_type_variation = &"MutedLabel"
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size.y = 54
	column.add_child(bio)
	return column


func _create_ratings_column(driver: Driver, ratings: Array, heading: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 285
	var title := Label.new()
	title.text = heading
	title.theme_type_variation = &"BodyStrong"
	column.add_child(title)
	for rating in ratings:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = rating["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.text = "%02d" % rating["rating"]
		value.tooltip_text = "Maximum potential: %d" % rating["potential"]
		value.add_theme_font_size_override("font_size", 18)
		var cap := Label.new()
		cap.text = "/ %02d POT" % rating["potential"]
		cap.theme_type_variation = &"MutedLabel"
		row.add_child(label)
		row.add_child(value)
		row.add_child(cap)
		column.add_child(row)
	return column


func _create_career_row(driver: Driver) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	for metric in [["STARTS", driver.career_starts], ["WINS", driver.career_wins], ["PODIUMS", driver.career_podiums], ["POLES", driver.career_poles], ["FASTEST LAPS", driver.career_fastest_laps], ["POINTS", driver.career_points], ["TITLES", driver.championships]]:
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.text = str(metric[1])
		value.add_theme_font_size_override("font_size", 22)
		var label := Label.new()
		label.text = metric[0]
		label.theme_type_variation = &"MutedLabel"
		block.add_child(value)
		block.add_child(label)
		row.add_child(block)
	return row


func _add_detail(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = &"MutedLabel"
	label.custom_minimum_size.x = 110
	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(value)
	parent.add_child(row)
