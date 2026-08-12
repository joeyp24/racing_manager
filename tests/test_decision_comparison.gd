extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_financial_effects_and_risk_states()
	_test_income_decisions_improve_the_forecast()
	_test_drawer_renders_and_emits_context()
	await _test_management_pages_enter_tree()
	print("Decision comparison system tests passed")
	quit(0)


func _test_financial_effects_and_risk_states() -> void:
	var team := Team.new()
	team.money = 50000
	var model := DecisionComparisonModel.build(team, {
		"upfront_cost": 5000,
		"recurring_per_race": 250,
		"action_enabled": true,
	})
	assert(str(model.finance.upfront) == "-$5,000")
	assert(str(model.finance.recurring) == "-$250 / race · 12 races")
	assert(str(model.finance.cash_after) == "$45,000")
	assert(bool(model.action_enabled))

	team.money = 1000
	var blocked := DecisionComparisonModel.build(team, {
		"upfront_cost": 2000,
		"action_enabled": true,
		"disabled_reason": "Not enough cash.",
		"risk": "A secondary risk should not obscure the blocker.",
	})
	assert(not bool(blocked.action_enabled))
	assert(str(blocked.risk_level) == "blocked")
	assert(str(blocked.risk) == "Not enough cash.")
	assert(str(blocked.disabled_reason) == "Not enough cash.")

	var automatic_reason := DecisionComparisonModel.build(team, {"upfront_cost": 2000})
	assert(str(automatic_reason.disabled_reason) == "You need $1,000 more cash to complete this decision.")


func _test_income_decisions_improve_the_forecast() -> void:
	var team := Team.new()
	team.money = 1000
	var baseline := FinanceManager.build_forecast(team)
	var model := DecisionComparisonModel.build(team, {
		"upfront_cost": -3000,
		"recurring_per_race": -500,
	})
	assert(str(model.finance.upfront) == "+$3,000")
	assert(str(model.finance.recurring) == "+$500 / race · 12 races")
	assert(str(model.finance.cash_after) == "$4,000")
	assert(int(str(model.finance.season_end_after).replace("$", "").replace(",", "")) > int(baseline.season_end_cash))


func _test_drawer_renders_and_emits_context() -> void:
	var packed := load("res://ui/components/decision_comparison_drawer.tscn") as PackedScene
	var drawer := packed.instantiate() as DecisionComparisonDrawer
	root.add_child(drawer)
	var emitted: Array[Dictionary] = []
	drawer.action_requested.connect(func(context: Dictionary) -> void: emitted.append(context))
	drawer.display({
		"title": "Candidate",
		"metrics": [DecisionComparisonModel.metric("Overall", "70", "75", "+5", DecisionComparisonModel.IMPROVES)],
		"finance": {"upfront": "-$1,000", "recurring": "No change", "cash_after": "$9,000", "season_end_after": "$12,000", "reserve": "$3,000"},
		"action_enabled": true,
		"context": {"kind": "test", "id": 7},
	})
	assert(drawer.visible)
	assert(drawer.metric_rows.get_child_count() == 1)
	assert(drawer.primary_button.text == "Confirm decision")
	assert(drawer.review_scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL)
	assert(drawer.primary_button.get_parent().get_parent() == drawer.review_scroll.get_parent())
	drawer.primary_button.pressed.emit()
	assert(not drawer.visible)
	assert(emitted.size() == 1)
	assert(int(emitted[0].id) == 7)
	drawer.free()


func _test_management_pages_enter_tree() -> void:
	var game_manager := root.get_node("GameManager")
	game_manager.team = Team.new()
	game_manager.team.money = 250000
	var page_paths: Array[String] = [
		"res://scenes/pages/dealership/dealership.tscn",
		"res://scenes/pages/shop/shop.tscn",
		"res://scenes/pages/driver_market/driver_market.tscn",
		"res://scenes/pages/staff/staff.tscn",
		"res://scenes/pages/sponsors/sponsors.tscn",
		"res://scenes/pages/engineering/engineering.tscn",
		"res://scenes/pages/departments/departments.tscn",
	]
	for page_path in page_paths:
		var packed := load(page_path) as PackedScene
		var page := packed.instantiate() as Control
		root.add_child(page)
		await process_frame
		var drawer := page.get_node_or_null("%DecisionComparisonDrawer") as DecisionComparisonDrawer
		assert(drawer != null, page_path)
		_exercise_page_comparison(page_path, page, game_manager.team)
		await process_frame
		assert(drawer.visible, page_path)
		assert(not drawer.cash_after_value.text.is_empty(), page_path)
		assert(drawer.get_combined_minimum_size().y <= drawer.size.y, "%s comparison overflows the reference viewport" % page_path)
		page.queue_free()
		await process_frame


func _exercise_page_comparison(page_path: String, page: Control, team: Team) -> void:
	if "dealership" in page_path:
		var templates := SeriesCatalog.create_car_templates(team.current_series_id)
		page.call("_show_car_comparison", templates[0])
	elif "/shop/" in page_path:
		var inventory: Array = page.get("store_inventory")
		page.call("_show_part_comparison", inventory[0])
	elif "driver_market" in page_path:
		var driver := Driver.new()
		driver.driver_id = "comparison_test_driver"
		driver.driver_name = "Test Driver"
		driver.salary = 1200
		driver.signing_fee = 2000
		driver.initialize_detailed_ratings(65, 70, 55, 82)
		team.drivers.append(driver)
		page.call("_show_driver_comparison", driver)
	elif "/staff/" in page_path:
		var member := StaffMember.new()
		member.staff_name = "Test Engineer"
		member.role = "Engineer"
		member.signing_fee = 1500
		member.salary = 600
		page.call("_show_staff_comparison", member)
	elif "/sponsors/" in page_path:
		assert(not team.sponsor_offers.is_empty())
		page.call("_show_sponsor_comparison", 0, team.sponsor_offers[0])
	elif "/engineering/" in page_path:
		var engineer := StaffMember.new()
		engineer.staff_name = "Test Engineer"
		engineer.role = "Engineer"
		engineer.hired = true
		page.call("_show_project_comparison", engineer)
	elif "/departments/" in page_path:
		page.call("_show_hq_comparison")
