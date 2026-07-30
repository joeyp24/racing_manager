extends Resource
class_name CarPerformanceResult

@export var part_results: Array[PartPerformanceResult] = []
@export var car_modifiers: Array[PerformancePointModifier] = []
@export var raw_part_points: float = 0.0
@export var effective_points: float = 0.0
@export var displayed_points: int = 0
