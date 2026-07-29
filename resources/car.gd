extends Resource
class_name Car

@export var name: String = "Starter Stock Car"

@export var manufacturer: String = "Generic Motors"
@export var model: String = "Stock Car"
@export var year: int = 2026

@export var performance: int = 50
@export var condition: int = 100

@export var mileage: int = 0

@export var purchase_price: int = 10000
@export var value: int = 7500

@export var installed_parts: Array[CarPart] = []


func ensure_standard_parts() -> void:
	for part_type in CarPart.PART_TYPES:
		if get_part(part_type) == null:
			installed_parts.append(
				PartCatalog.create_standard_part(part_type)
			)


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


func get_total_performance() -> int:
	var total: int = performance
	for part in installed_parts:
		if part != null:
			total += part.get_effective_performance_bonus()
	return total
