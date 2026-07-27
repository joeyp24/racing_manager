extends Resource
class_name Team

@export var team_name: String = "My Team"
@export var money: int = 15000
@export var reputation: int = 0

@export var cars: Array = [
	null,
	null,
	null,
	null,
	null,
	null
]


func get_car(bay_index: int):
	if bay_index < 0 or bay_index >= cars.size():
		return null

	return cars[bay_index]


func add_car_to_bay(car, bay_index: int) -> bool:
	if bay_index < 0 or bay_index >= cars.size():
		return false

	if cars[bay_index] != null:
		return false

	cars[bay_index] = car
	emit_changed()
	return true


func remove_car_from_bay(bay_index: int) -> void:
	if bay_index < 0 or bay_index >= cars.size():
		return

	cars[bay_index] = null
	emit_changed()
