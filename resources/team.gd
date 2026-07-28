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

@export var championship_standings: Array[Dictionary] = []
@export var drivers: Array[Driver] = []

@export var cars: Array = [
	null,
	null,
	null,
	null,
	null,
	null
]


func _init() -> void:
	ensure_default_player_driver()


func get_car(bay_index: int) -> Car:
	if not is_valid_bay_index(bay_index):
		return null

	return cars[bay_index] as Car


func buy_car(
	car_template: Car,
	bay_index: int
) -> bool:
	if car_template == null:
		push_error(
			"Cannot purchase a null car template."
		)
		return false

	if not is_valid_bay_index(bay_index):
		push_error(
			"Invalid garage bay index: %d"
			% bay_index
		)
		return false

	if cars[bay_index] != null:
		return false

	if money < car_template.purchase_price:
		return false

	var purchased_car: Car = (
		car_template.duplicate(true) as Car
	)

	if purchased_car == null:
		push_error(
			"The car template could not be duplicated."
		)
		return false

	money -= car_template.purchase_price
	cars[bay_index] = purchased_car

	emit_changed()

	return true


func sell_car(bay_index: int) -> int:
	if not is_valid_bay_index(bay_index):
		push_error(
			"Invalid garage bay index: %d"
			% bay_index
		)
		return 0

	var car: Car = cars[bay_index] as Car

	if car == null:
		return 0

	var sale_price: int = car.value

	money += sale_price
	cars[bay_index] = null

	emit_changed()

	return sale_price


func remove_car_from_bay(
	bay_index: int
) -> void:
	if not is_valid_bay_index(bay_index):
		return

	cars[bay_index] = null

	emit_changed()


func can_afford_car(
	car_template: Car
) -> bool:
	if car_template == null:
		return false

	return money >= car_template.purchase_price


func is_valid_bay_index(
	bay_index: int
) -> bool:
	return (
		bay_index >= 0
		and bay_index < cars.size()
	)


func ensure_default_player_driver() -> Driver:
	var current_driver: Driver = get_active_driver()

	if current_driver != null:
		current_driver.team_name = team_name
		current_driver.is_player_driver = true
		return current_driver

	var new_driver := Driver.new()

	new_driver.driver_id = "player_jordan_hayes"
	new_driver.driver_name = "Jordan Hayes"

	new_driver.skill = 55
	new_driver.consistency = 55
	new_driver.aggression = 50

	new_driver.salary = 1500
	new_driver.assigned_bay = -1

	new_driver.team_name = team_name
	new_driver.is_player_driver = true

	drivers.append(new_driver)

	emit_changed()

	return new_driver


func get_active_driver() -> Driver:
	for driver in drivers:
		if driver == null:
			continue

		if driver.is_player_driver:
			return driver

	return null


func get_driver_by_id(
	driver_id: String
) -> Driver:
	for driver in drivers:
		if driver == null:
			continue

		if driver.driver_id == driver_id:
			return driver

	return null


func get_player_championship_entry() -> Dictionary:
	for entry in championship_standings:
		if bool(entry.get("is_player", false)):
			return entry

	return {}


func get_sorted_championship_standings() -> Array[Dictionary]:
	var sorted_standings: Array[Dictionary] = []

	for entry in championship_standings:
		sorted_standings.append(
			entry.duplicate(true)
		)

	sorted_standings.sort_custom(
		func(
			first_entry: Dictionary,
			second_entry: Dictionary
		) -> bool:
			var first_points: int = int(
				first_entry.get("points", 0)
			)

			var second_points: int = int(
				second_entry.get("points", 0)
			)

			if first_points != second_points:
				return first_points > second_points

			var first_wins: int = int(
				first_entry.get("wins", 0)
			)

			var second_wins: int = int(
				second_entry.get("wins", 0)
			)

			if first_wins != second_wins:
				return first_wins > second_wins

			var first_podiums: int = int(
				first_entry.get("podiums", 0)
			)

			var second_podiums: int = int(
				second_entry.get("podiums", 0)
			)

			if first_podiums != second_podiums:
				return first_podiums > second_podiums

			return (
				str(
					first_entry.get(
						"driver_name",
						""
					)
				)
				< str(
					second_entry.get(
						"driver_name",
						""
					)
				)
			)
	)

	return sorted_standings
