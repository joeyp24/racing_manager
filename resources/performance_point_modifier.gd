extends Resource
class_name PerformancePointModifier

@export var id: String = ""
@export var label: String = ""
@export var source_type: String = "part"
@export var raw_percent: float = 0.0
@export var raw_points: float = 0.0
@export var display_points: int = 0


static func create(modifier_id: String, modifier_label: String, type: String, percent: float, points: float) -> PerformancePointModifier:
	var modifier := PerformancePointModifier.new()
	modifier.id = modifier_id
	modifier.label = modifier_label
	modifier.source_type = type
	modifier.raw_percent = percent
	modifier.raw_points = points
	modifier.display_points = roundi(points)
	return modifier
