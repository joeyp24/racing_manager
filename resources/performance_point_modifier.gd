extends RefCounted
class_name PerformancePointModifier

enum Scope { PART, CAR, RACE }
enum Operation { ADDITIVE_PERCENT, MULTIPLICATIVE_PERCENT, FLAT_POINTS }

var id: String = ""
var label: String = ""
var scope: Scope = Scope.PART
var operation: Operation = Operation.ADDITIVE_PERCENT
var value: float = 0.0
var target_part_types: Array[String] = []
var effective_points: float = 0.0


static func create(modifier_id: String, modifier_label: String, modifier_scope: Scope, modifier_operation: Operation, modifier_value: float, targets: Array = []) -> PerformancePointModifier:
	assert(not modifier_id.strip_edges().is_empty(), "Performance Point modifier IDs must not be empty.")
	if modifier_operation != Operation.FLAT_POINTS:
		assert(is_finite(modifier_value), "Percentage modifiers require a finite percentage value.")
	else:
		assert(is_finite(modifier_value), "Flat PP modifiers require a finite point value.")
	for part_type in targets:
		assert(CarPart.PART_TYPES.has(part_type), "Unknown PP modifier part target: %s" % part_type)
	assert(modifier_scope == Scope.PART or targets.is_empty(), "Only part-scoped modifiers may target part types.")
	var modifier := PerformancePointModifier.new()
	modifier.id = modifier_id
	modifier.label = modifier_label
	modifier.scope = modifier_scope
	modifier.operation = modifier_operation
	modifier.value = modifier_value
	modifier.target_part_types.assign(targets)
	return modifier


func applies_to_part(part_type: String) -> bool:
	return scope == Scope.PART and (target_part_types.is_empty() or target_part_types.has(part_type))


func duplicate_modifier() -> PerformancePointModifier:
	return create(id, label, scope, operation, value, target_part_types)
