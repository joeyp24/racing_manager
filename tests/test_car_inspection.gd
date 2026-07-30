extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	var templates := SeriesCatalog.create_car_templates("local_short_track")
	assert(not templates.is_empty())
	var car := templates[0] as Car
	game_manager.team.cars[0] = car
	game_manager.selected_car = car
	game_manager.selected_bay = 0

	var packed := load("res://scenes/pages/garage/car_inspection.tscn") as PackedScene
	assert(packed != null)
	var page := packed.instantiate() as Control
	root.add_child(page)
	await process_frame

	var columns := page.get_node("%columns") as HSplitContainer
	assert(columns != null)
	assert(columns.split_offset >= 300)
	assert(columns.split_offset <= 440)

	page.queue_free()
	await process_frame
	print("Car inspection interaction smoke tests passed")
	quit(0)
