extends RefCounted
class_name PerformancePointFormatter


static func format_part_points(result: PartPerformanceResult) -> String:
	return "%.1f PP" % result.effective_points


static func format_modifier_points(modifier: PerformancePointModifier) -> String:
	return "%+.2f PP" % modifier.effective_points if absf(modifier.effective_points) < 1.0 else "%+.1f PP" % modifier.effective_points
