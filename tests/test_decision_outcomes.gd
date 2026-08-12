extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_outcome_model()
	_test_global_reporting_api()
	_test_receipt_rendering_and_action()
	await _test_management_shell_delivery()
	print("Decision outcome feedback tests passed")
	quit(0)


func _test_outcome_model() -> void:
	var team := Team.new()
	team.money = 12345
	var success := DecisionOutcomeModel.build(team, {
		"title": "Part purchased",
		"cash_delta": -1500,
		"action_label": "Open garage",
		"action_path": "res://scenes/pages/garage/garage.tscn",
	})
	assert(str(success.status) == "success")
	assert(str(success.cash_effect) == "-$1,500")
	assert(str(success.balance_text) == "$12,345")
	assert(bool(success.show_finance))
	var failure := DecisionOutcomeModel.build(team, {"status":"error", "message":"Unavailable"})
	assert(str(failure.eyebrow) == "ACTION NOT COMPLETED")
	assert(not bool(failure.show_finance))


func _test_global_reporting_api() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.money = 9000
	var emitted: Array[Dictionary] = []
	var capture := func(outcome: Dictionary) -> void: emitted.append(outcome)
	game_manager.decision_outcome_reported.connect(capture)
	game_manager.report_decision_outcome({"title":"Test update", "cash_delta":-1000})
	assert(emitted.size() == 1)
	assert(str(emitted[0].balance_text) == "$9,000")
	assert(not game_manager.pending_decision_outcome.is_empty())
	assert(str(game_manager.consume_decision_outcome().title) == "Test update")
	assert(game_manager.pending_decision_outcome.is_empty())
	game_manager.decision_outcome_reported.disconnect(capture)


func _test_receipt_rendering_and_action() -> void:
	var packed := load("res://ui/components/decision_outcome_receipt.tscn") as PackedScene
	var receipt := packed.instantiate() as DecisionOutcomeReceipt
	root.add_child(receipt)
	var requested_paths: Array[String] = []
	receipt.action_requested.connect(func(path: String) -> void: requested_paths.append(path))
	receipt.display({
		"status":"success", "title":"Car purchased", "message":"Ready for inspection.",
		"detail":"Bay 2", "show_finance":true, "cash_delta":-5000,
		"cash_effect":"-$5,000", "balance_text":"$20,000",
		"action_label":"View car", "action_path":"res://scenes/pages/garage/car_inspection.tscn",
	})
	assert(receipt.visible)
	assert(receipt.finance_receipt.visible)
	assert(receipt.cash_effect.text == "-$5,000")
	assert(receipt.action_button.visible)
	assert(receipt.get_combined_minimum_size().y <= receipt.size.y)
	receipt.action_button.pressed.emit()
	assert(not receipt.visible)
	assert(requested_paths == ["res://scenes/pages/garage/car_inspection.tscn"])
	receipt.free()


func _test_management_shell_delivery() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.money = 25000
	game_manager.team.driver_hired_for_season = true
	var packed := load("res://scenes/home/home.tscn") as PackedScene
	var shell := packed.instantiate() as Control
	root.add_child(shell)
	await process_frame
	await process_frame
	game_manager.team.money = 24000
	game_manager.report_decision_outcome({
		"title":"Facility upgraded", "message":"Accounting is now level 2.",
		"cash_delta":-1000, "action_label":"View update",
		"action_path":"res://scenes/pages/dashboard/dashboard.tscn",
	})
	await process_frame
	var receipt := shell.get_node("%DecisionOutcomeReceipt") as DecisionOutcomeReceipt
	var finance_metric := shell.get_node("%FinanceMetric") as StatusMetric
	assert(receipt.visible)
	assert(receipt.title.text == "Facility upgraded")
	assert(finance_metric.value_label.text == "$24,000")
	receipt.action_button.pressed.emit()
	await process_frame
	assert(not receipt.visible)
	shell.queue_free()
	await process_frame
	game_manager.page_container = null
