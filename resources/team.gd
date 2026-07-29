extends Resource
class_name Team

const GARAGE_SIZE: int = 6
const MAX_ENGINEERS: int = 3
const ROLE_LIMITS: Dictionary = {
	"Crew Chief": 1,
	"Engineer": 3,
	"Mechanic": 3,
	"Spotter": 1,
	"Pit Crew": 5
}
const MANUFACTURING_BASE_COST: int = 1800
const PART_REPAIR_COST_PER_POINT: int = 12
const MAX_RACE_TEAMS: int = 4
const RACE_TEAM_EXPANSION_COST: int = 25000

@export var team_name: String = "My Team"
@export var hometown: String = "Charlotte, NC"
@export var team_motto: String = "Built to compete"
@export var primary_color: Color = Color("e9421e")
@export var secondary_color: Color = Color("172033")
@export var accent_color: Color = Color("f4f6fa")
@export_enum("Diamond", "Shield", "Bolt", "Flag") var team_badge: String = "Diamond"
@export var tutorial_completed: bool = false
@export var last_saved_unix_time: int = 0
@export var money: int = 1000000
@export var reputation: int = 0
@export var championship_points: int = 0
@export var season_number: int = 1
@export var season_complete: bool = false
@export var driver_hired_for_season: bool = false
@export var last_season_position: int = 0
@export var last_season_prize: int = 0
@export var last_development_summary: Array[String] = []
@export var fans: int = 0
@export var department_levels: Dictionary = {}
@export var driver_development_progress: float = 0.0

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
@export var contracted_driver_ids: Array[String] = []
@export var race_teams: Array[RaceTeam] = []

@export var cars: Array = [
	null,
	null,
	null,
	null,
	null,
	null
]

@export var parts_inventory: Array[CarPart] = []
@export var staff: Array[StaffMember] = []
@export var finance_history: Array[Dictionary] = []


func _init() -> void:
	ensure_departments()
	ensure_default_player_driver()
	ensure_driver_market()
	ensure_race_teams()
	ensure_car_parts()
	ensure_staff_market()


func ensure_departments() -> void:
	for department_id in DepartmentCatalog.get_ids():
		if not department_levels.has(department_id):
			department_levels[department_id] = 0


func get_department_level(department_id: String) -> int:
	return clampi(int(department_levels.get(department_id, 0)), 0, DepartmentCatalog.MAX_LEVEL)


func get_department_bonus(department_id: String) -> float:
	return DepartmentCatalog.get_bonus(get_department_level(department_id))


func is_secret_department_unlocked() -> bool:
	return season_number >= 3 or championship_points >= 100


func get_discounted_cost(base_cost: int, include_accounting: bool = true) -> int:
	if base_cost <= 0:
		return 0
	var discount: float = get_department_bonus("accounting") if include_accounting else 0.0
	return maxi(1, ceili(float(base_cost) * (1.0 - discount / 100.0)))


func get_department_cost(department_id: String) -> int:
	var level := get_department_level(department_id)
	var base_cost := DepartmentCatalog.get_base_cost(department_id, level)
	# Accounting cannot discount its own construction, avoiding a circular price change.
	return get_discounted_cost(base_cost, department_id != "accounting")


func can_purchase_department(department_id: String) -> bool:
	if not DepartmentCatalog.DEPARTMENTS.has(department_id):
		return false
	if department_id == "cheating" and not is_secret_department_unlocked():
		return false
	var cost := get_department_cost(department_id)
	return cost > 0 and money >= cost


func purchase_department(department_id: String) -> bool:
	if not can_purchase_department(department_id):
		return false
	var cost := get_department_cost(department_id)
	money -= cost
	department_levels[department_id] = get_department_level(department_id) + 1
	record_finance("HQ", -cost, "Upgraded %s" % str(DepartmentCatalog.get_data(department_id).get("name", department_id)))
	emit_changed()
	return true


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

	var purchase_cost := get_discounted_cost(car_template.purchase_price)
	if money < purchase_cost:
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

	money -= purchase_cost
	cars[bay_index] = purchased_car
	record_finance("Garage", -purchase_cost, "Purchased %s" % purchased_car.name)

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
	record_finance("Garage", sale_price, "Sold %s" % car.name)

	emit_changed()

	return sale_price


func buy_part(part_template: CarPart) -> bool:
	if part_template == null:
		return false
	var purchase_cost := get_discounted_cost(part_template.purchase_price)
	if money < purchase_cost:
		return false
	money -= purchase_cost
	parts_inventory.append(part_template.duplicate(true) as CarPart)
	record_finance("Parts", -purchase_cost, "Purchased %s" % part_template.part_name)
	emit_changed()
	return true


func sell_part(part: CarPart) -> int:
	if part == null or not parts_inventory.has(part):
		return 0
	parts_inventory.erase(part)
	money += part.sale_price
	record_finance("Parts", part.sale_price, "Sold %s" % part.part_name)
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


func ensure_staff_market() -> void:
	var candidates: Array[Dictionary] = [
		{"id":"chief_morgan","name":"Alex Morgan","role":"Crew Chief","a":68,"b":56,"potential":76,"fee":4500,"salary":1600,"specialty":"Race strategy"},
		{"id":"chief_chen","name":"Lena Chen","role":"Crew Chief","a":75,"b":81,"potential":88,"fee":9000,"salary":2800,"specialty":"Car setup"},
		{"id":"chief_bennett","name":"Marcus Bennett","role":"Crew Chief","a":94,"b":88,"potential":94,"fee":16000,"salary":4500,"specialty":"Championship leadership"},
		{"id":"engineer_singh","name":"Priya Singh","role":"Engineer","a":61,"b":69,"potential":84,"fee":3200,"salary":1200,"specialty":"Engines"},
		{"id":"engineer_romero","name":"Diego Romero","role":"Engineer","a":74,"b":68,"potential":82,"fee":6000,"salary":1900,"specialty":"Suspension"},
		{"id":"engineer_nakamura","name":"Emi Nakamura","role":"Engineer","a":89,"b":79,"potential":92,"fee":10500,"salary":3100,"specialty":"Aerodynamics"},
		{"id":"engineer_okafor","name":"Tunde Okafor","role":"Engineer","a":96,"b":92,"potential":97,"fee":17500,"salary":4800,"specialty":"Advanced manufacturing"},
		{"id":"mechanic_cole","name":"Jamie Cole","role":"Mechanic","a":64,"b":72,"potential":82,"fee":3600,"salary":1300,"specialty":"Rapid repairs"},
		{"id":"mechanic_alvarez","name":"Rosa Alvarez","role":"Mechanic","a":83,"b":79,"potential":90,"fee":7600,"salary":2400,"specialty":"Pit precision"},
		{"id":"mechanic_ward","name":"Cal Ward","role":"Mechanic","a":91,"b":88,"potential":94,"fee":13000,"salary":3700,"specialty":"Damage recovery"},
		{"id":"spotter_brooks","name":"Taylor Brooks","role":"Spotter","a":70,"b":66,"potential":85,"fee":4100,"salary":1500,"specialty":"Traffic awareness"},
		{"id":"spotter_kim","name":"Jules Kim","role":"Spotter","a":88,"b":92,"potential":95,"fee":12000,"salary":3600,"specialty":"Restarts"},
		{"id":"pit_hughes","name":"Sam Hughes","role":"Pit Crew","a":61,"b":73,"potential":83,"fee":2600,"salary":900,"specialty":"Tire carrier"},
		{"id":"pit_patel","name":"Ari Patel","role":"Pit Crew","a":78,"b":81,"potential":90,"fee":5200,"salary":1600,"specialty":"Jack operator"},
		{"id":"pit_davis","name":"Morgan Davis","role":"Pit Crew","a":86,"b":77,"potential":91,"fee":7200,"salary":2100,"specialty":"Tire changer"},
		{"id":"pit_owens","name":"Casey Owens","role":"Pit Crew","a":72,"b":91,"potential":93,"fee":6800,"salary":1900,"specialty":"Fueler"},
		{"id":"pit_wright","name":"Devon Wright","role":"Pit Crew","a":94,"b":89,"potential":96,"fee":12500,"salary":3300,"specialty":"Crew captain"}
	]
	for data in candidates:
		var existing_member := get_staff_by_id(str(data["id"]))
		if existing_member != null:
			# Migrate staff created before individual attributes were introduced.
			if existing_member.primary_rating == 50 and existing_member.secondary_rating == 50:
				existing_member.primary_rating = int(data["a"])
				existing_member.secondary_rating = int(data["b"])
				existing_member.potential = int(data["potential"])
				existing_member.recalculate_rating()
			continue
		var member := StaffMember.new()
		member.staff_id = str(data["id"])
		member.staff_name = str(data["name"])
		member.role = str(data["role"])
		member.primary_rating = int(data["a"])
		member.secondary_rating = int(data["b"])
		member.potential = int(data["potential"])
		member.signing_fee = int(data["fee"])
		member.salary = int(data["salary"])
		member.specialty = str(data["specialty"])
		member.recalculate_rating()
		member.rival_interest = get_rival_interest(member.rating)
		staff.append(member)


func get_staff_by_id(staff_id: String) -> StaffMember:
	for member in staff:
		if member != null and member.staff_id == staff_id:
			return member
	return null


func get_crew_chief() -> StaffMember:
	for member in staff:
		if member != null and member.hired and member.role == "Crew Chief":
			return member
	return null


func get_engineers() -> Array[StaffMember]:
	var engineers: Array[StaffMember] = []
	for member in staff:
		if member != null and member.hired and member.role == "Engineer":
			engineers.append(member)
	return engineers


func get_staff_by_role(role: String, hired_only: bool = true) -> Array[StaffMember]:
	var matches: Array[StaffMember] = []
	for member in staff:
		if member != null and member.role == role and (member.hired or not hired_only):
			matches.append(member)
	return matches


func get_role_limit(role: String) -> int:
	return int(ROLE_LIMITS.get(role, 0))


func can_add_staff_role(role: String) -> bool:
	return get_staff_by_role(role).size() < get_role_limit(role)


func get_rival_interest(rating: int) -> String:
	if rating >= 88:
		return "Very high"
	if rating >= 76:
		return "High"
	if rating >= 62:
		return "Medium"
	return "Low"


func hire_staff(member: StaffMember) -> bool:
	if member == null or not staff.has(member) or member.hired:
		return false
	if not can_add_staff_role(member.role):
		return false
	var cost := get_discounted_cost(member.signing_fee)
	if money < cost:
		return false
	money -= cost
	member.hired = true
	member.contract_races_remaining = member.get_default_contract_length()
	member.morale = 70
	record_finance("Staff", -cost, "Signed %s" % member.staff_name)
	emit_changed()
	return true


func fire_staff(member: StaffMember) -> bool:
	if member == null or not member.hired:
		return false
	var fee := get_discounted_cost(member.get_termination_fee())
	if money < fee:
		return false
	money -= fee
	record_finance("Staff", -fee, "Terminated %s's contract" % member.staff_name)
	member.hired = false
	member.contract_races_remaining = 0
	emit_changed()
	return true


func renew_staff_contract(member: StaffMember, negotiate: bool = false) -> bool:
	if member == null or not member.hired:
		return false
	var renewal_fee := get_discounted_cost(maxi(member.salary, member.signing_fee / 3))
	if money < renewal_fee:
		return false
	money -= renewal_fee
	if negotiate:
		member.salary = maxi(100, roundi(float(member.salary) * 0.95))
		member.morale = maxi(0, member.morale - 8)
	else:
		member.morale = mini(100, member.morale + 5)
	member.contract_races_remaining = member.get_default_contract_length()
	record_finance("Staff", -renewal_fee, "Renewed %s" % member.staff_name)
	emit_changed()
	return true


func process_staff_race() -> Dictionary:
	var crew_chief_salary := 0
	var engineering_payroll := 0
	var expired_names: Array[String] = []
	for member in staff:
		if member == null or not member.hired:
			continue
		if member.role == "Crew Chief":
			crew_chief_salary += member.salary
		else:
			engineering_payroll += member.salary
		member.experience += 1
		if member.experience % 6 == 0:
			member.development_points += 1
		member.contract_races_remaining = maxi(0, member.contract_races_remaining - 1)
		member.morale = mini(100, member.morale + 1)
		if member.contract_races_remaining == 0:
			expired_names.append(member.staff_name)
			member.hired = false
	var total := crew_chief_salary + engineering_payroll
	money -= total
	if crew_chief_salary > 0:
		record_finance("Payroll", -crew_chief_salary, "Crew chief salary")
	if engineering_payroll > 0:
		record_finance("Payroll", -engineering_payroll, "Engineering payroll")
	emit_changed()
	return {
		"crew_chief_salary": crew_chief_salary,
		"engineering_payroll": engineering_payroll,
		"expired_names": expired_names
	}


func get_staff_payroll() -> int:
	var total := 0
	for member in staff:
		if member != null and member.hired:
			total += member.salary
	return total


func get_total_race_payroll() -> int:
	var driver := get_active_driver()
	var driver_payroll := driver.salary if driver != null and driver_hired_for_season else 0
	return get_staff_payroll() + driver_payroll


func record_finance(category: String, amount: int, description: String) -> void:
	finance_history.push_front({
		"season": season_number,
		"race": completed_races.size() + 1,
		"category": category,
		"amount": amount,
		"description": description
	})
	if finance_history.size() > 100:
		finance_history.resize(100)


func get_finance_total(positive: bool) -> int:
	var total := 0
	for entry in finance_history:
		var amount := int(entry.get("amount", 0))
		if (positive and amount > 0) or (not positive and amount < 0):
			total += abs(amount)
	return total


func get_crew_chief_performance_boost() -> float:
	var chief := get_crew_chief()
	if chief == null:
		return 0.0
	var specialty_bonus := 0.75 if chief.specialty == "Race strategy" else 0.0
	return float(chief.rating) * 0.05 + specialty_bonus


func get_car_setup_variance_reduction() -> float:
	var chief := get_crew_chief()
	if chief == null:
		return 0.0
	return float(chief.secondary_rating) * 0.012 + (0.5 if chief.specialty == "Car setup" else 0.0)


func get_engineering_performance_boost() -> float:
	return get_average_role_attribute("Engineer", true) * 0.035


func get_reliability_boost() -> float:
	return get_average_role_attribute("Engineer", false) * 0.08


func get_repair_time_reduction() -> float:
	return get_average_role_attribute("Mechanic", true) * 0.22


func get_pit_stop_time_reduction() -> float:
	var mechanic_bonus := get_average_role_attribute("Mechanic", false) * 0.008
	var pit_bonus := get_average_role_attribute("Pit Crew", true) * 0.012
	return mechanic_bonus + pit_bonus


func get_pit_mistake_reduction() -> float:
	return get_average_role_attribute("Pit Crew", false) * 0.1


func get_accident_risk_reduction() -> float:
	return get_average_role_attribute("Spotter", true) * 0.1


func get_restart_performance_boost() -> float:
	return get_average_role_attribute("Spotter", false) * 0.025


func get_average_role_attribute(role: String, primary: bool) -> float:
	var members := get_staff_by_role(role)
	if members.is_empty():
		return 0.0
	var total := 0.0
	for member in members:
		var attribute := member.primary_rating if primary else member.secondary_rating
		total += float(attribute) * lerpf(0.8, 1.05, float(member.morale) / 100.0)
	return total / float(members.size())


func process_staff_season() -> Array[String]:
	var updates: Array[String] = []
	for member in staff:
		if member == null:
			continue
		member.rival_interest = get_rival_interest(member.rating)
		if member.hired:
			member.apply_season_development()
			updates.append("%s: %s" % [member.staff_name, member.last_development])
		elif member.rating >= 82 and (season_number + member.staff_id.length()) % 3 == 0:
			# Rival offers make elite free agents more expensive rather than deleting save data.
			member.salary = roundi(float(member.salary) * 1.08)
			member.signing_fee = roundi(float(member.signing_fee) * 1.08)
	return updates


func manufacture_part(engineer: StaffMember, part_type: String) -> CarPart:
	if engineer == null or not engineer.hired or engineer.role != "Engineer":
		return null
	if not CarPart.PART_TYPES.has(part_type):
		return null
	var cost := get_discounted_cost(MANUFACTURING_BASE_COST)
	if money < cost:
		return null
	money -= cost
	var part := PartCatalog.create_manufactured_part(part_type, engineer)
	parts_inventory.append(part)
	record_finance("Workshop", -cost, "Manufactured %s" % part.part_name)
	emit_changed()
	return part


func repair_part(engineer: StaffMember, part: CarPart) -> int:
	if engineer == null or not engineer.hired or engineer.role != "Engineer":
		return 0
	if part == null or not parts_inventory.has(part) or part.condition >= 100:
		return 0
	var maximum_restore := 10 + roundi(float(engineer.rating) * 0.35)
	if engineer.specialty == "Advanced manufacturing":
		maximum_restore += 5
	elif (
		(engineer.specialty == "Engines" and part.part_type == "Engine")
		or (engineer.specialty == "Suspension" and part.part_type == "Suspension")
		or (engineer.specialty == "Aerodynamics" and part.part_type == "Body")
	):
		maximum_restore += 4
	var restored := mini(100 - part.condition, maximum_restore)
	var cost := get_discounted_cost(restored * PART_REPAIR_COST_PER_POINT)
	if money < cost:
		return 0
	money -= cost
	part.condition += restored
	record_finance("Workshop", -cost, "Repaired %s" % part.part_name)
	part.emit_changed()
	emit_changed()
	return restored


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

	return money >= get_discounted_cost(car_template.purchase_price)


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
		if not contracted_driver_ids.has(current_driver.driver_id):
			contracted_driver_ids.append(current_driver.driver_id)
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
	contracted_driver_ids.append(new_driver.driver_id)

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


func can_hire_driver(driver: Driver = null) -> bool:
	return (
		not season_complete
		and completed_races.is_empty()
		and contracted_driver_ids.size() < MAX_RACE_TEAMS
		and (driver == null or not contracted_driver_ids.has(driver.driver_id))
	)


func get_driver_roster_limit() -> int:
	# Every contracted driver can be assigned to one of the team's race entries.
	return MAX_RACE_TEAMS


func hire_driver(driver: Driver) -> bool:
	if driver == null or not drivers.has(driver):
		return false
	var signing_cost := get_discounted_cost(driver.signing_fee)
	if not can_hire_driver(driver) or money < signing_cost:
		return false

	money -= signing_cost
	driver.is_player_driver = get_active_driver() == null
	driver.team_name = team_name
	contracted_driver_ids.append(driver.driver_id)
	driver_hired_for_season = true
	record_finance("Driver", -signing_cost, "Signed %s" % driver.driver_name)
	emit_changed()
	return true


func get_active_driver() -> Driver:
	for driver in drivers:
		if driver == null:
			continue

		if driver.is_player_driver:
			return driver

	return null


func get_contracted_drivers() -> Array[Driver]:
	var roster: Array[Driver] = []
	for driver_id in contracted_driver_ids:
		var driver := get_driver_by_id(driver_id)
		if driver != null:
			roster.append(driver)
	return roster


func ensure_race_teams() -> void:
	if race_teams.is_empty():
		var first_team := RaceTeam.new()
		first_team.team_id = "team_1"
		first_team.team_name = "Team 1"
		var active_driver := get_active_driver()
		first_team.driver_id = active_driver.driver_id if active_driver != null else ""
		race_teams.append(first_team)
	for index in range(race_teams.size()):
		if race_teams[index] != null and race_teams[index].team_id.is_empty():
			race_teams[index].team_id = "team_%d" % (index + 1)


func add_race_team() -> RaceTeam:
	if race_teams.size() >= MAX_RACE_TEAMS:
		return null
	var cost := get_discounted_cost(RACE_TEAM_EXPANSION_COST)
	if money < cost:
		return null
	money -= cost
	var race_team := RaceTeam.new()
	race_team.team_id = "team_%d" % (race_teams.size() + 1)
	race_team.team_name = "Team %d" % (race_teams.size() + 1)
	race_teams.append(race_team)
	record_finance("Race Teams", -cost, "Opened %s" % race_team.team_name)
	emit_changed()
	return race_team


func assign_race_team(race_team: RaceTeam, driver_id: String, car_bay: int) -> bool:
	if race_team == null or not race_teams.has(race_team):
		return false
	if not driver_id.is_empty() and not contracted_driver_ids.has(driver_id):
		return false
	if car_bay >= 0 and get_car(car_bay) == null:
		return false
	for other_team in race_teams:
		if other_team == race_team:
			continue
		if not driver_id.is_empty() and other_team.driver_id == driver_id:
			return false
		if car_bay >= 0 and other_team.car_bay == car_bay:
			return false
	race_team.driver_id = driver_id
	race_team.car_bay = car_bay
	emit_changed()
	return true


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
