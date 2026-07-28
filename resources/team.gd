extends Resource
class_name Team

const GARAGE_SIZE: int = 6

@export var team_name: String = "My Team"
@export var money: int = 15000
@export var reputation: int = 0
@export var championship_points: int = 0
@export var season_number: int = 1
@export var season_complete: bool = false
@export var driver_hired_for_season: bool = false
@export var last_season_position: int = 0
@export var last_season_prize: int = 0
@export var last_development_summary: Array[String] = []

@export var active_sponsor_id: String = ""
@export var sponsor_races_remaining: int = 0
@export var sponsor_objective_progress: int = 0
@export var sponsor_objective_completed: bool = false
@export var sponsor_signed_season: int = 0

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

@export var parts_inventory: Array[CarPart] = []


func _init() -> void:
	ensure_default_player_driver()
	ensure_driver_market()
	ensure_car_parts()


func ensure_car_parts() -> void:
	for car_value in cars:
		var car := car_value as Car
		if car != null:
			car.ensure_standard_parts()


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

	purchased_car.ensure_standard_parts()

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


func buy_part(part_template: CarPart) -> bool:
	if part_template == null or money < part_template.purchase_price:
		return false
	money -= part_template.purchase_price
	parts_inventory.append(part_template.duplicate(true) as CarPart)
	emit_changed()
	return true


func sell_part(part: CarPart) -> int:
	if part == null or not parts_inventory.has(part):
		return 0
	parts_inventory.erase(part)
	money += part.sale_price
	emit_changed()
	return part.sale_price


func install_part(car: Car, part: CarPart) -> bool:
	if car == null or part == null or not parts_inventory.has(part):
		return false
	parts_inventory.erase(part)
	var removed_part: CarPart = car.install_part(part)
	if removed_part != null and removed_part.tier != "Standard":
		parts_inventory.append(removed_part)
	emit_changed()
	return true


func get_parts_by_type(part_type: String) -> Array[CarPart]:
	var matches: Array[CarPart] = []
	for part in parts_inventory:
		if part != null and part.part_type == part_type:
			matches.append(part)
	return matches


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
		if (
			current_driver.driver_id == "player_jordan_hayes"
			and current_driver.age == 25
			and current_driver.potential == 80
		):
			current_driver.age = 24
			current_driver.potential = 78
		return current_driver

	var new_driver := Driver.new()

	new_driver.driver_id = "player_jordan_hayes"
	new_driver.driver_name = "Jordan Hayes"

	new_driver.skill = 55
	new_driver.consistency = 55
	new_driver.aggression = 50
	new_driver.age = 24
	new_driver.potential = 78

	new_driver.salary = 1500
	new_driver.signing_fee = 2000
	new_driver.archetype = "Balanced club racer"
	new_driver.assigned_bay = -1

	new_driver.team_name = team_name
	new_driver.is_player_driver = true

	drivers.append(new_driver)

	emit_changed()

	return new_driver


func ensure_driver_market() -> void:
	var candidates: Array[Dictionary] = [
		{
			"id": "maya_torres", "name": "Maya Torres",
			"archetype": "Talented but inconsistent",
			"skill": 78, "consistency": 43, "aggression": 62,
			"salary": 3200, "fee": 6500,
			"age": 25, "potential": 90
		},
		{
			"id": "grant_holloway", "name": "Grant Holloway",
			"archetype": "Dependable veteran",
			"skill": 67, "consistency": 84, "aggression": 38,
			"salary": 2900, "fee": 5000,
			"age": 35, "potential": 85
		},
		{
			"id": "nia_okafor", "name": "Nia Okafor",
			"archetype": "Aggressive prospect",
			"skill": 65, "consistency": 54, "aggression": 88,
			"salary": 2200, "fee": 4000,
			"age": 21, "potential": 94
		},
		{
			"id": "eli_park", "name": "Eli Park",
			"archetype": "Cheap rookie",
			"skill": 48, "consistency": 51, "aggression": 57,
			"salary": 900, "fee": 1000,
			"age": 19, "potential": 86
		},
		{
			"id": "sofia_varga", "name": "Sofia Varga",
			"archetype": "Expensive championship contender",
			"skill": 91, "consistency": 87, "aggression": 71,
			"salary": 6000, "fee": 12000,
			"age": 29, "potential": 94
		}
	]

	for data in candidates:
		var existing_driver: Driver = get_driver_by_id(str(data["id"]))
		if existing_driver != null:
			migrate_driver_development(existing_driver, data)
			continue
		var driver := Driver.new()
		driver.driver_id = str(data["id"])
		driver.driver_name = str(data["name"])
		driver.archetype = str(data["archetype"])
		driver.skill = int(data["skill"])
		driver.consistency = int(data["consistency"])
		driver.aggression = int(data["aggression"])
		driver.salary = int(data["salary"])
		driver.signing_fee = int(data["fee"])
		driver.age = int(data["age"])
		driver.potential = int(data["potential"])
		drivers.append(driver)


func migrate_driver_development(
	driver: Driver,
	data: Dictionary
) -> void:
	# Values introduced after launch use generic Resource defaults in old saves.
	# Replace those defaults with the archetype-specific values once.
	if driver.age == 25 and driver.potential == 80:
		driver.age = int(data["age"])
		driver.potential = int(data["potential"])

	driver.potential = max(
		driver.potential,
		max(driver.skill, max(driver.consistency, driver.aggression))
	)


func can_hire_driver() -> bool:
	return (
		not season_complete
		and completed_races.is_empty()
		and not driver_hired_for_season
	)


func hire_driver(driver: Driver) -> bool:
	if driver == null or not drivers.has(driver):
		return false
	if not can_hire_driver() or money < driver.signing_fee:
		return false

	for roster_driver in drivers:
		if roster_driver == null:
			continue
		roster_driver.is_player_driver = false
		if roster_driver.team_name == team_name:
			roster_driver.team_name = "Free Agent"

	money -= driver.signing_fee
	driver.is_player_driver = true
	driver.team_name = team_name
	driver_hired_for_season = true
	emit_changed()
	return true


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
