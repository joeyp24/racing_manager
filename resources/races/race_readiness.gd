class_name RaceReadiness
extends RefCounted

const READY := "ready"
const SUBOPTIMAL := "suboptimal"
const BLOCKED := "blocked"


static func evaluate(team: Team, race: Race, selected_car: Car = null) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	if team == null or race == null:
		return checks

	checks.append(_driver_check(team))
	checks.append(_car_check(team, race, selected_car))
	checks.append(_staff_check(team))
	checks.append(_finance_check(team, race))
	checks.append(_sponsor_check(team))
	return checks


static func get_overall_status(checks: Array[Dictionary]) -> String:
	var overall := READY
	for check in checks:
		var status := str(check.get("status", READY))
		if status == BLOCKED:
			return BLOCKED
		if status == SUBOPTIMAL:
			overall = SUBOPTIMAL
	return overall


static func get_recommended_car(team: Team, series_id: String = "") -> Car:
	if team == null:
		return null
	var best_car: Car = null
	var best_score := -1
	for car_value in team.cars:
		var car := car_value as Car
		if car == null or not is_car_eligible(car, series_id):
			continue
		var score := car.get_total_performance_points(team) + car.condition
		if score > best_score:
			best_score = score
			best_car = car
	return best_car


static func is_car_eligible(car: Car, series_id: String = "") -> bool:
	if car == null or car.condition <= 0:
		return false
	if not series_id.is_empty() and car.series_id != series_id:
		return false
	for part_type in CarPart.PART_TYPES:
		var part := car.get_part(part_type)
		if part == null or part.condition <= 0:
			return false
	return true


static func _driver_check(team: Team) -> Dictionary:
	var driver := team.get_active_driver()
	if not team.driver_hired_for_season or driver == null:
		return _check(BLOCKED, "DRIVER", "No driver is contracted for this season.", "Open Drivers", "drivers")
	var rating := driver.get_overall_rating()
	if rating < 55:
		return _check(SUBOPTIMAL, "DRIVER", "%s is contracted, but a %d average rating limits the forecast." % [driver.driver_name, rating], "Open Drivers", "drivers", "Target: 55+")
	return _check(READY, "DRIVER", "%s is contracted for the season (rating %d)." % [driver.driver_name, rating], "", "", "Season contract")


static func _car_check(team: Team, race: Race, selected_car: Car) -> Dictionary:
	var car := selected_car if selected_car != null else get_recommended_car(team, race.series_id)
	if car != null and car.series_id != race.series_id:
		var car_series := SeriesCatalog.get_series(car.series_id)
		var race_series := SeriesCatalog.get_series(race.series_id)
		return _check(BLOCKED, "CAR HOMOLOGATION", "This car is homologated for the %s and cannot enter a %s event." % [car_series.get("name", car.series_id), race_series.get("name", race.series_id)], "Open Garage", "garage")
	if car == null:
		return _check(BLOCKED, "ELIGIBLE CAR", "No race-ready car has a complete, functioning parts package.", "Open Garage", "garage")
	var worn_parts := 0
	for part in car.installed_parts:
		if part != null and part.condition < 60:
			worn_parts += 1
	if car.condition < 70 or worn_parts > 0:
		var reliability_penalty := maxi(1, roundi(float(70 - mini(car.condition, 70)) * 0.25) + worn_parts * 2)
		return _check(SUBOPTIMAL, "CAR CONDITION", "%s is at %d%% condition; estimated reliability penalty is %d%%." % [car.name, car.condition, reliability_penalty], "Open Garage", "garage", "%d worn components" % worn_parts)
	return _check(READY, "ELIGIBLE CAR", "%s is fully equipped and at %d%% condition." % [car.name, car.condition], "", "", "Performance points %d" % car.get_total_performance_points(team))


static func _staff_check(team: Team) -> Dictionary:
	var crew_chief := team.get_crew_chief()
	if crew_chief == null:
		return _check(BLOCKED, "RACE CREW", "A contracted Crew Chief is required to run race operations.", "Open Staff", "staff")
	var missing_roles: Array[String] = []
	for role in ["Engineer", "Mechanic", "Spotter", "Pit Crew"]:
		if team.get_staff_by_role(role).is_empty():
			missing_roles.append(role)
	if not missing_roles.is_empty():
		return _check(SUBOPTIMAL, "RACE CREW", "%s will lead, but supporting roles are missing: %s." % [crew_chief.staff_name, ", ".join(missing_roles)], "Open Staff", "staff", "%d/5 role groups" % (5 - missing_roles.size()))
	return _check(READY, "RACE CREW", "%s leads a complete operational crew." % crew_chief.staff_name, "", "", "All key roles filled")


static func _finance_check(team: Team, race: Race) -> Dictionary:
	if team.money < race.entry_fee:
		return _check(BLOCKED, "ENTRY FUNDS", "You need $%s more to cover the $%s entry fee." % [_money(race.entry_fee - team.money), _money(race.entry_fee)], "Open Finances", "finances")
	var reserve := team.money - race.entry_fee
	var payroll := team.get_total_race_payroll()
	if reserve < maxi(5000, payroll):
		return _check(SUBOPTIMAL, "ENTRY FUNDS", "Entry is affordable, but only $%s remains before race payroll." % _money(reserve), "Open Finances", "finances", "Payroll $%s" % _money(payroll))
	return _check(READY, "ENTRY FUNDS", "$%s remains after the $%s entry fee." % [_money(reserve), _money(race.entry_fee)], "", "", "Healthy reserve")


static func _sponsor_check(team: Team) -> Dictionary:
	var sponsor := SponsorCatalog.find_by_id(team.active_sponsor_id)
	if sponsor == null:
		return _check(SUBOPTIMAL, "SPONSOR", "No sponsor is active, so this race has no sponsor income or objective bonus.", "Open Sponsors", "sponsors")
	if team.sponsor_objective_completed:
		return _check(READY, "SPONSOR", "%s's objective is already complete." % sponsor.sponsor_name, "", "", "$%s per race" % _money(sponsor.payment_per_race))
	var needed := maxi(0, sponsor.objective_target - team.sponsor_objective_progress)
	if needed > team.sponsor_races_remaining:
		return _check(BLOCKED, "SPONSOR", "%s's objective is no longer achievable: %d results needed with %d races left." % [sponsor.sponsor_name, needed, team.sponsor_races_remaining], "Open Sponsors", "sponsors")
	if needed == team.sponsor_races_remaining:
		return _check(SUBOPTIMAL, "SPONSOR", "%s requires an objective result in every remaining race." % sponsor.sponsor_name, "Open Sponsors", "sponsors", "%d/%d complete" % [team.sponsor_objective_progress, sponsor.objective_target])
	return _check(READY, "SPONSOR", "%s's objective remains achievable." % sponsor.sponsor_name, "", "", "%d/%d complete" % [team.sponsor_objective_progress, sponsor.objective_target])


static func _check(status: String, title: String, explanation: String, action_label: String = "", action: String = "", threshold: String = "") -> Dictionary:
	return {"status": status, "title": title, "explanation": explanation, "action_label": action_label, "action": action, "threshold": threshold}


static func _money(amount: int) -> String:
	return String.num_int64(amount)
