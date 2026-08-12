extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.money = 250000
	game_manager.team.ensure_race_teams()
	for index in range(1, 4):
		var race_team := RaceTeam.new()
		race_team.team_id = "team_%d" % (index + 1)
		race_team.team_name = "Race Team %d" % (index + 1)
		game_manager.team.race_teams.append(race_team)
	for index in 36:
		CareerExpansionManager.add_inbox_item(
			game_manager.team,
			"Board" if index % 2 == 0 else "Sponsor",
			"Decision %02d" % index,
			"Choose the response that best supports the organization.",
			[
				{"label":"Invest", "cost":1000, "effects":{"confidence":3}},
				{"label":"Protect cash", "cost":0, "effects":{"confidence":-1}},
			],
			{
				"deadline": game_manager.team.current_season_day + 3 + index,
				"priority": "High" if index % 4 == 0 else "Normal",
				"race_team_id": "team_%d" % ((index % 4) + 1),
			}
		)
	var state := CareerExpansionManager.ensure_state(game_manager.team)
	var archived := state.inbox.back() as Dictionary
	assert(CareerExpansionManager.resolve_inbox(game_manager.team, str(archived.id), 1))

	var packed := load("res://scenes/pages/career_hub/career_hub.tscn") as PackedScene
	assert(packed != null)
	var page := packed.instantiate() as Control
	root.add_child(page)
	await process_frame

	var category_filter := page.get_node("%category_filter") as OptionButton
	var status_filter := page.get_node("%status_filter") as OptionButton
	var decision_workspace := page.get_node("%DecisionWorkspace") as HSplitContainer
	var decision_queue := page.get_node("%decision_queue") as VBoxContainer
	var decision_detail := page.get_node("%decision_detail") as VBoxContainer
	var legacy_scroll := page.get_node("%LegacyScroll") as ScrollContainer
	var content := page.get_node("%content") as VBoxContainer
	var comparison_drawer := page.get_node("%DecisionComparisonDrawer") as Control
	assert(category_filter.item_count >= 16)
	assert(status_filter.item_count == 4)
	assert(decision_workspace.visible)
	assert(not legacy_scroll.visible)
	assert(decision_queue.get_child_count() == 35)
	assert(decision_detail.get_child_count() > 4)

	var selected := CareerExpansionManager.get_pending_decisions(game_manager.team)[0]
	page.call("_select_decision", str(selected.id))
	await process_frame
	assert(bool(selected.read))
	assert(decision_detail.get_child_count() > 4)
	page.call("_review_inbox_choice", str(selected.id), 0)
	await process_frame
	assert(comparison_drawer.visible)
	var choice_button := comparison_drawer.get_node("%PrimaryButton") as Button
	assert(not choice_button.disabled)
	choice_button.pressed.emit()
	await process_frame
	assert(bool(selected.resolved))
	assert(str(game_manager.pending_decision_outcome.title) == "Decision recorded")
	game_manager.consume_decision_outcome()

	page.call("_review_time_advance", game_manager.team.current_season_day + 7)
	await process_frame
	assert(comparison_drawer.visible)
	assert((comparison_drawer.get_node("%PrimaryButton") as Button).disabled)
	comparison_drawer.call("hide_comparison")

	status_filter.select(2)
	status_filter.item_selected.emit(2)
	await process_frame
	assert(decision_queue.get_child_count() == 2)

	for index in range(1, 7):
		page.call("_select_view", index)
		await process_frame
		assert(not decision_workspace.visible)
		assert(legacy_scroll.visible)
		assert(content.get_child_count() > 0)

	page.queue_free()
	await process_frame
	print("Career HQ decision-center interaction tests passed")
	quit(0)
