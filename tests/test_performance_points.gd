extends SceneTree


func _initialize() -> void:
	_test_factory_baseline_and_condition()
	_test_series_factory_profiles()
	_test_additive_modifiers_and_final_rounding()
	_test_migration_is_idempotent()
	print("Performance Points behavioral tests passed")
	quit(0)


func _test_series_factory_profiles() -> void:
	for target in [48, 74, 94]:
		var parts := PartCatalog.create_factory_parts("test_series", target)
		assert(parts.size() == CarPart.PART_TYPES.size())
		var total := 0
		for part in parts:
			total += part.base_performance_points
		assert(total == target)
	var premier_cars := SeriesCatalog.create_car_templates("premier_cup")
	assert(premier_cars[1].get_base_performance_points() == 94)


func _test_factory_baseline_and_condition() -> void:
	var car := Car.new()
	car.performance = 999 # Runtime calculations must ignore this legacy field.
	car.ensure_standard_parts()
	assert(car.installed_parts.size() == 6)
	assert(car.get_base_performance_points() == 48)
	assert(car.get_total_performance_points() == 48)
	var engine := car.get_part("Engine")
	assert(is_equal_approx(engine.get_condition_adjusted_points(), 8.0))
	engine.condition = 50
	assert(is_equal_approx(engine.get_condition_adjusted_points(), 4.0))
	assert(car.get_total_performance_points() == 44)


func _test_additive_modifiers_and_final_rounding() -> void:
	var team := Team.new()
	var car := Car.new()
	car.ensure_standard_parts()
	# A fractional bonus across six parts survives until the one car-level round.
	team.department_levels["engineering"] = 1
	var part_result := team.calculate_part_performance(car.get_part("Engine"))
	assert(part_result.effective_points > 8.0)
	assert(part_result.modifiers.size() == 1)
	var car_result := team.calculate_car_performance(car)
	assert(car_result.raw_part_points > 48.0)
	assert(car_result.displayed_points == roundi(car_result.effective_points))
	assert(car_result.car_modifiers.is_empty())


func _test_migration_is_idempotent() -> void:
	var team := Team.new()
	team.save_format_version = 7
	var car := Car.new()
	car.performance = 60
	var engine := PartCatalog.create_standard_part("Engine", 8)
	engine.performance_bonus = 4
	car.installed_parts.append(engine)
	team.cars[0] = car
	SaveManager._repair_and_migrate(team)
	assert(engine.base_performance_points == 12)
	assert(engine.performance_bonus == 0)
	assert(car.installed_parts.size() == 6)
	var migrated_total := car.get_base_performance_points()
	SaveManager._repair_and_migrate(team)
	assert(car.get_base_performance_points() == migrated_total)
