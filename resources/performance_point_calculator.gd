extends RefCounted
class_name PerformancePointCalculator


static func calculate_part(part: CarPart, context: PerformancePointContext) -> PartPerformanceResult:
	var result := PartPerformanceResult.new()
	if part == null:
		return result
	result.base_points = part.base_performance_points
	result.condition_points = part.get_condition_adjusted_points()
	if not is_equal_approx(result.condition_points, float(result.base_points)):
		var condition_targets: Array[String] = [part.part_type]
		var condition := PerformancePointModifier.create("part_condition", "Condition (%d%%)" % part.condition, PerformancePointModifier.Scope.PART, PerformancePointModifier.Operation.FLAT_POINTS, result.condition_points - float(result.base_points), condition_targets)
		condition.effective_points = condition.value
		result.modifiers.append(condition)
	var additive_percent := 0.0
	var multiplier := 1.0
	var flat_points := 0.0
	var applied_ids := {"part_condition": true} if not result.modifiers.is_empty() else {}
	var templates: Array[PerformancePointModifier] = []
	if context != null:
		templates = context.part_modifiers
	for template in templates:
		if template == null:
			continue
		if template.scope != PerformancePointModifier.Scope.PART:
			var message := "Modifier '%s' cannot be applied at part scope." % template.id
			result.diagnostics.append(message)
			push_error(message)
			continue
		if not template.applies_to_part(part.part_type):
			continue
		if applied_ids.has(template.id):
			_report_duplicate(result.diagnostics, template.id, "part")
			continue
		applied_ids[template.id] = true
		var modifier := template.duplicate_modifier()
		match modifier.operation:
			PerformancePointModifier.Operation.ADDITIVE_PERCENT:
				modifier.effective_points = result.condition_points * modifier.value / 100.0
				additive_percent += modifier.value
			PerformancePointModifier.Operation.MULTIPLICATIVE_PERCENT:
				modifier.effective_points = result.condition_points * multiplier * modifier.value / 100.0
				multiplier *= 1.0 + modifier.value / 100.0
			PerformancePointModifier.Operation.FLAT_POINTS:
				modifier.effective_points = modifier.value
				flat_points += modifier.value
		result.modifiers.append(modifier)
	result.effective_points = result.condition_points * (1.0 + additive_percent / 100.0) * multiplier + flat_points
	result.displayed_points = roundi(result.effective_points)
	return result


static func calculate_car(car: Car, context: PerformancePointContext) -> CarPerformanceResult:
	var result := CarPerformanceResult.new()
	if car == null:
		return result
	for part in car.installed_parts:
		if part == null:
			continue
		var part_result := calculate_part(part, context)
		result.part_results.append(part_result)
		result.raw_part_points += part_result.effective_points
		result.diagnostics.append_array(part_result.diagnostics)
	var additive_percent := 0.0
	var multiplier := 1.0
	var flat_points := 0.0
	var applied_ids: Dictionary = {}
	var templates: Array[PerformancePointModifier] = []
	if context != null:
		templates = context.car_modifiers
	for template in templates:
		if template == null:
			continue
		if template.scope != PerformancePointModifier.Scope.CAR:
			result.diagnostics.append("Modifier '%s' cannot be applied at car scope." % template.id)
			push_error(result.diagnostics[-1])
			continue
		if applied_ids.has(template.id):
			_report_duplicate(result.diagnostics, template.id, "car")
			continue
		applied_ids[template.id] = true
		var modifier := template.duplicate_modifier()
		match modifier.operation:
			PerformancePointModifier.Operation.ADDITIVE_PERCENT:
				modifier.effective_points = result.raw_part_points * modifier.value / 100.0
				additive_percent += modifier.value
			PerformancePointModifier.Operation.MULTIPLICATIVE_PERCENT:
				modifier.effective_points = result.raw_part_points * multiplier * modifier.value / 100.0
				multiplier *= 1.0 + modifier.value / 100.0
			PerformancePointModifier.Operation.FLAT_POINTS:
				modifier.effective_points = modifier.value
				flat_points += modifier.value
		result.car_modifiers.append(modifier)
	result.effective_points = result.raw_part_points * (1.0 + additive_percent / 100.0) * multiplier + flat_points
	result.displayed_points = roundi(result.effective_points)
	return result


static func _report_duplicate(diagnostics: Array[String], modifier_id: String, stage: String) -> void:
	var message := "Duplicate Performance Point modifier ID '%s' at %s stage." % [modifier_id, stage]
	diagnostics.append(message)
	push_error(message)
