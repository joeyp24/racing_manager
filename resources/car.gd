extends Resource
class_name Car

@export var name: String = "Starter Stock Car"
@export var series_id: String = "local_short_track"

@export var manufacturer: String = "Generic Motors"
@export var model: String = "Stock Car"
@export var year: int = 2026

# Compatibility-only input for pre-v8 resources. Runtime car creation and PP
# calculations must never use this value.
@export_storage var legacy_performance: int = 50
@export var condition: int = 100
@export_range(0, 100) var horsepower: int = 50
@export_range(0, 100) var aerodynamic_efficiency: int = 50
@export_range(0, 100) var mechanical_grip: int = 50
@export_range(0, 100) var braking: int = 50
@export_range(0, 100) var tyre_preservation: int = 50
@export_range(0, 100) var fuel_efficiency: int = 50
@export_range(0, 100) var reliability: int = 75

@export var mileage: int = 0

@export var purchase_price: int = 10000
@export var value: int = 7500

@export var installed_parts: Array[CarPart] = []


func _set(property: StringName, value: Variant) -> bool:
	# Godot forwards the removed `performance` property from old .tres saves here.
	if property == &"performance":
		legacy_performance = int(value)
		return true
	return false


func ensure_standard_parts() -> void:
	for part_type in CarPart.PART_TYPES:
		if get_part(part_type) == null:
			installed_parts.append(PartCatalog.create_standard_part(part_type))


func get_part(part_type: String) -> CarPart:
	for part in installed_parts:
		if part != null and part.part_type == part_type:
			return part
	return null


func install_part(new_part: CarPart) -> CarPart:
	if new_part == null or not CarPart.PART_TYPES.has(new_part.part_type):
		return null
	var old_part: CarPart = get_part(new_part.part_type)
	if old_part != null:
		installed_parts.erase(old_part)
	installed_parts.append(new_part)
	emit_changed()
	return old_part


func get_base_performance_points() -> int:
	var total := 0
	for part in installed_parts:
		if part != null:
			total += part.base_performance_points
	return total


func get_total_performance_points(team: Team = null) -> int:
	if team != null:
		return team.calculate_car_performance(self).displayed_points
	var raw_total := 0.0
	for part in installed_parts:
		if part != null:
			raw_total += part.get_condition_adjusted_points()
	return roundi(raw_total)


func get_race_attributes() -> Dictionary:
	var attributes := {"power": float(horsepower), "aero": float(aerodynamic_efficiency), "grip": float(mechanical_grip), "braking": float(braking), "tyres": float(tyre_preservation), "fuel": float(fuel_efficiency), "reliability": float(reliability)}
	for part in installed_parts:
		if part == null:
			continue
		var key := part.get_attribute_key()
		if attributes.has(key):
			attributes[key] = clampf(float(attributes[key]) + part.get_effective_attribute_modifier(), 1.0, 100.0)
		attributes["reliability"] = clampf(float(attributes["reliability"]) + part.get_effective_reliability_modifier(), 1.0, 100.0)
	return attributes
