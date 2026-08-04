extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.money = 250000
	var packed := load("res://scenes/pages/career_hub/career_hub.tscn") as PackedScene
	assert(packed != null)
	var page := packed.instantiate() as Control
	root.add_child(page)
	await process_frame
	var tab_selector := page.get_node("%tab_selector") as OptionButton
	var category_filter := page.get_node("%category_filter") as OptionButton
	var status_filter := page.get_node("%status_filter") as OptionButton
	var content := page.get_node("%content") as VBoxContainer
	assert(tab_selector.item_count == 7)
	assert(category_filter.item_count >= 10)
	assert(status_filter.item_count == 4)
	for index in tab_selector.item_count:
		tab_selector.select(index)
		tab_selector.item_selected.emit(index)
		await process_frame
		assert(content.get_child_count() > 0)
	page.queue_free()
	await process_frame
	print("Career HQ interaction smoke tests passed")
	quit(0)
