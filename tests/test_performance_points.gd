extends SceneTree


func _initialize() -> void:
	_test_factory_baseline_and_condition()
	_test_series_factory_profiles()
	_test_typed_calculator_behavior()
	_test_modifier_targeting_and_scopes()
	_test_fraction_rounding_and_replacement_delta()
	_test_migration_is_idempotent()
	_test_serialized_migration_fixtures()
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
	car.legacy_performance = 999 # Runtime calculations must ignore this legacy field.
	car.ensure_standard_parts()
	assert(car.installed_parts.size() == 6)
	assert(car.get_base_performance_points() == 48)
	assert(car.get_total_performance_points() == 48)
	var engine := car.get_part("Engine")
	assert(is_equal_approx(engine.get_condition_adjusted_points(), 8.0))
	engine.condition = 50
	assert(is_equal_approx(engine.get_condition_adjusted_points(), 4.0))
	assert(car.get_total_performance_points() == 44)


func _modifier(id: String, percent: float, scope := PerformancePointModifier.Scope.PART, targets: Array[String] = []) -> PerformancePointModifier:
	return PerformancePointModifier.create(id, id.capitalize(), scope, PerformancePointModifier.Operation.ADDITIVE_PERCENT, percent, targets)


func _test_typed_calculator_behavior() -> void:
	var car := Car.new()
	car.ensure_standard_parts()
	var context := PerformancePointContext.new()
	context.part_modifiers = [_modifier("engineering_department", 2.5), _modifier("engineering_staff", 2.5)]
	var part_result := PerformancePointCalculator.calculate_part(car.get_part("Engine"), context)
	assert(is_equal_approx(part_result.effective_points, 8.4))
	assert(part_result.modifiers.size() == 2)
	assert(part_result.modifiers.filter(func(modifier): return modifier.id == "engineering_department").size() == 1)
	var car_result := PerformancePointCalculator.calculate_car(car, context)
	assert(is_equal_approx(car_result.raw_part_points, 50.4))
	assert(car_result.displayed_points == roundi(car_result.effective_points))
	var duplicate_context := PerformancePointContext.new()
	duplicate_context.part_modifiers = [_modifier("duplicate", 1.0), _modifier("duplicate", 2.0)]
	var duplicate_result := PerformancePointCalculator.calculate_part(car.get_part("Engine"), duplicate_context)
	assert(duplicate_result.diagnostics.size() == 1)


func _test_modifier_targeting_and_scopes() -> void:
	var car := Car.new()
	car.ensure_standard_parts()
	var context := PerformancePointContext.new()
	context.part_modifiers = [
		_modifier("wind_tunnel_body", 4.0, PerformancePointModifier.Scope.PART, ["Body"]),
		_modifier("engine_specialty", 3.0, PerformancePointModifier.Scope.PART, ["Engine"]),
		_modifier("suspension_specialty", 3.0, PerformancePointModifier.Scope.PART, ["Suspension"]),
		_modifier("aero_specialty", 3.0, PerformancePointModifier.Scope.PART, ["Body"]),
	]
	context.car_modifiers = [
		_modifier("crew_chief_setup", 2.0, PerformancePointModifier.Scope.CAR),
		_modifier("secret_department_car", 1.0, PerformancePointModifier.Scope.CAR),
	]
	for part_type in CarPart.PART_TYPES:
		var result := PerformancePointCalculator.calculate_part(car.get_part(part_type), context)
		assert(result.modifiers.any(func(modifier): return modifier.id == "wind_tunnel_body") == (part_type == "Body"))
		assert(result.modifiers.any(func(modifier): return modifier.id == "engine_specialty") == (part_type == "Engine"))
		assert(result.modifiers.any(func(modifier): return modifier.id == "suspension_specialty") == (part_type == "Suspension"))
		assert(result.modifiers.any(func(modifier): return modifier.id == "aero_specialty") == (part_type == "Body"))
		assert(not result.modifiers.any(func(modifier): return modifier.scope == PerformancePointModifier.Scope.CAR))
	var car_result := PerformancePointCalculator.calculate_car(car, context)
	assert(car_result.car_modifiers.filter(func(modifier): return modifier.id == "crew_chief_setup").size() == 1)
	assert(car_result.car_modifiers.filter(func(modifier): return modifier.id == "secret_department_car").size() == 1)


func _test_fraction_rounding_and_replacement_delta() -> void:
	var car := Car.new()
	car.ensure_standard_parts()
	var context := PerformancePointContext.new()
	context.part_modifiers = [_modifier("fractional", 6.25)]
	var original := PerformancePointCalculator.calculate_car(car, context)
	var rounded_part_sum := 0
	for result in original.part_results:
		rounded_part_sum += roundi(result.effective_points)
	assert(rounded_part_sum != original.displayed_points)
	assert(roundi(original.part_results.reduce(func(total, result): return total + result.effective_points, 0.0)) == original.displayed_points)
	var replacement := PartCatalog.create_standard_part("Engine", 13)
	var old_part := car.get_part("Engine")
	var old_result := PerformancePointCalculator.calculate_part(old_part, context)
	var replacement_result := PerformancePointCalculator.calculate_part(replacement, context)
	assert(replacement.base_performance_points - old_part.base_performance_points == 5)
	assert(is_equal_approx(replacement_result.effective_points - old_result.effective_points, 5.3125))


func _test_migration_is_idempotent() -> void:
	var team := Team.new()
	team.save_format_version = 7
	var car := Car.new()
	car.legacy_performance = 60
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


func _test_serialized_migration_fixtures() -> void:
	var expectations := {"complete": 50, "partial": 60, "empty": 60}
	SaveManager.ensure_save_directory()
	for fixture_name in expectations:
		var slot := "pp_fixture_%s" % fixture_name
		var destination := SaveManager.get_save_path(slot)
		var source := "res://tests/fixtures/pre_pp_%s_car.tres" % fixture_name
		var input := FileAccess.open(source, FileAccess.READ)
		var output := FileAccess.open(destination, FileAccess.WRITE)
		output.store_buffer(input.get_buffer(input.get_length()))
		var migrated := SaveManager.load_game(slot)
		assert(migrated != null and migrated.save_format_version == Team.CURRENT_SAVE_FORMAT_VERSION)
		var backup := destination.trim_suffix(".tres") + SaveManager.BACKUP_EXTENSION
		var temporary := destination.trim_suffix(".tres") + SaveManager.TEMP_EXTENSION
		assert(FileAccess.file_exists(backup))
		assert(not FileAccess.file_exists(temporary))
		var car := migrated.get_car(0)
		assert(car.installed_parts.size() == 6)
		assert(car.get_base_performance_points() == expectations[fixture_name])
		for part in car.installed_parts:
			assert(part.performance_bonus == 0)
		var first_total := car.get_base_performance_points()
		var reloaded := SaveManager.load_game(slot)
		assert(reloaded.get_car(0).get_base_performance_points() == first_total)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
