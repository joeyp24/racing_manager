extends Resource
class_name Team

const GARAGE_SIZE: int = 6

@export var team_name: String = "My Team"
@export var money: int = 15000
@export var reputation: int = 0
@export var championship_points: int = 0
@export var completed_races: Array[String] = []

@export var unlocked_races: Array[String] = [
	"spring_100"
]

@export var cars: Array = [
	null,
	null,
	null,
	null,
	null,
	null
]


func get_car(bay_index: int):
	if not is_valid_bay_index(bay_index):
		return null

	return cars[bay_index]


func buy_car(car_template: Car, bay_index: int) -> bool:
	if car_template == null:
		push_error("Cannot purchase a null car template.")
		return false

	if not is_valid_bay_index(bay_index):
		push_error("Invalid garage bay index: %d" % bay_index)
		return false

	if cars[bay_index] != null:
		return false

	if money < car_template.purchase_price:
		return false

	var purchased_car := car_template.duplicate(true) as Car

	if purchased_car == null:
		push_error("The car template could not be duplicated.")
		return false

	money -= car_template.purchase_price
	cars[bay_index] = purchased_car

	emit_changed()
	return true


func sell_car(bay_index: int) -> int:
	if not is_valid_bay_index(bay_index):
		push_error("Invalid garage bay index: %d" % bay_index)
		return 0

	var car = cars[bay_index]

	if car == null:
		return 0

	var sale_price: int = car.value

	money += sale_price
	cars[bay_index] = null

	emit_changed()
	return sale_price


func remove_car_from_bay(bay_index: int) -> void:
	if not is_valid_bay_index(bay_index):
		return

	cars[bay_index] = null
	emit_changed()


func can_afford_car(car_template: Car) -> bool:
	if car_template == null:
		return false

	return money >= car_template.purchase_price


func is_valid_bay_index(bay_index: int) -> bool:
	return bay_index >= 0 and bay_index < cars.size()
