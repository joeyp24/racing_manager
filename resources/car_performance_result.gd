extends RefCounted
class_name CarPerformanceResult

var part_results: Array[PartPerformanceResult] = []
var car_modifiers: Array[PerformancePointModifier] = []
var raw_part_points: float = 0.0
var effective_points: float = 0.0
var displayed_points: int = 0
var diagnostics: Array[String] = []
