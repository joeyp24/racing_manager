extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	var packed := load("res://scenes/home/home.tscn") as PackedScene
	assert(packed != null)
	var shell := packed.instantiate() as Control
	root.add_child(shell)
	await process_frame
	await process_frame

	var sidebar := shell.get_node("Layout/Sidebar") as Control
	var top_bar := shell.get_node("Layout/RightSide/OuterMargin/Stack/TopBar") as Control
	var command_bar := shell.get_node("%CommandBar") as Control
	var main_panel := shell.get_node("Layout/RightSide/OuterMargin/Stack/MainPanel") as Control
	assert(sidebar.size.x >= 190.0)
	assert(top_bar.size.y >= 50.0)
	assert(command_bar.size.x > 800.0)
	assert(command_bar.position.y >= top_bar.position.y + top_bar.size.y)
	assert(main_panel.size.y >= 300.0)

	for metric_name in ["ScheduleMetric", "FinanceMetric", "ChampionshipMetric", "ReputationMetric", "BoardMetric", "AttentionMetric"]:
		var metric := shell.get_node("%%%s" % metric_name) as Control
		assert(metric != null)
		assert(metric.size.x >= 100.0)
		assert(metric.size.y >= 48.0)

	shell.queue_free()
	await process_frame
	print("Management shell layout tests passed")
	quit(0)
