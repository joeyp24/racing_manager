extends RefCounted
class_name FinanceManager

const FACILITY_WEEKLY_UPKEEP := {
	"design_office": 260,
	"driver_academy": 220,
	"simulator": 300,
	"quality_lab": 280,
	"medical_centre": 190,
	"marketing_suite": 180
}


static func get_race_commercial_revenue(team: Team, race: Race) -> Dictionary:
	if team == null or race == null:
		return {"series_distribution":0, "gate_share":0, "owner_support":0, "manufacturer_support":0, "total":0}
	var series := SeriesCatalog.get_series(race.series_id)
	var estimated_cost := int(series.get("estimated_race_cost", 1200))
	var distribution := roundi(float(estimated_cost) * 1.10)
	var gate_share := team.get_effective_sponsor_value(200 + mini(800, roundi(float(team.fans) * 0.25)))
	var owner_support := roundi(float(estimated_cost) * 0.65) if team.season_number == 1 else 0
	var manufacturer := team.career_state.get("manufacturer", {}) as Dictionary
	var manufacturer_support := int(manufacturer.get("support", 0)) * 4
	return {
		"series_distribution": distribution,
		"gate_share": gate_share,
		"owner_support": owner_support,
		"manufacturer_support": manufacturer_support,
		"total": distribution + gate_share + owner_support + manufacturer_support
	}


static func apply_race_commercial_revenue(team: Team, result: RaceResult) -> int:
	if team == null or result == null or result.race == null:
		return 0
	var revenue := get_race_commercial_revenue(team, result.race)
	result.series_distribution = int(revenue.series_distribution)
	result.gate_revenue = int(revenue.gate_share)
	result.owner_race_support = int(revenue.owner_support)
	result.manufacturer_race_support = int(revenue.manufacturer_support)
	for item in [
		["Series Distribution", result.series_distribution, "Championship commercial and broadcast distribution"],
		["Event Revenue", result.gate_revenue, "Team share of tickets, hospitality, and local promotion"],
		["Ownership", result.owner_race_support, "First-season operating support"],
		["Manufacturer", result.manufacturer_race_support, "Technical partner race support"]
	]:
		var amount := int(item[1])
		if amount <= 0:
			continue
		team.money += amount
		team.record_finance(str(item[0]), amount, str(item[2]))
	result.commercial_revenue = int(revenue.total)
	result.net_earnings += result.commercial_revenue
	return result.commercial_revenue


static func build_forecast(team: Team) -> Dictionary:
	if team == null:
		return {}
	var series := SeriesCatalog.get_series(team.current_series_id)
	var remaining_races := maxi(0, int(series.get("season_length", 12)) - team.get_completed_races().size())
	var race_stub := Race.new()
	race_stub.series_id = team.current_series_id
	var commercial := get_race_commercial_revenue(team, race_stub)
	var sponsor_per_race := 0
	if not team.active_sponsor_contract.is_empty():
		sponsor_per_race = int(team.active_sponsor_contract.get("payment_per_race", 0))
	var available_sponsor_estimate := 0
	for offer_value in team.sponsor_offers:
		available_sponsor_estimate = maxi(available_sponsor_estimate, int((offer_value as Dictionary).get("payment_per_race", 0)))
	var series_index := maxi(0, SeriesCatalog.get_index(team.current_series_id))
	var expected_purse := roundi(350.0 * (1.0 + float(series_index) * 0.75) * float(team.get_difficulty_setting("prize_multiplier", 1.0)))
	var race_income := int(commercial.total) + sponsor_per_race + expected_purse
	var operations := roundi(
		float(series.get("estimated_race_cost", 1200))
		* float(team.get_difficulty_setting("weekend_cost_multiplier", 1.0))
	)
	var payroll := team.get_total_race_payroll()
	var race_cost := operations + payroll
	var weekly_upkeep := 0
	var facilities := team.career_state.get("facilities", {}) as Dictionary
	for facility_id in FACILITY_WEEKLY_UPKEEP:
		var facility := facilities.get(facility_id, {}) as Dictionary
		weekly_upkeep += int(FACILITY_WEEKLY_UPKEEP[facility_id]) * int(facility.get("level", 0))
	var weeks_remaining := maxi(0, CalendarCatalog.SEASON_END_DAY - team.current_season_day) / 7
	var projected_income := race_income * remaining_races
	var projected_costs := race_cost * remaining_races + weekly_upkeep * weeks_remaining
	var projected_net := projected_income - projected_costs
	var minimum_reserve := race_cost * mini(3, maxi(1, remaining_races)) + weekly_upkeep * 4
	return {
		"cash": team.money,
		"remaining_races": remaining_races,
		"race_income": race_income,
		"race_cost": race_cost,
		"race_net": race_income - race_cost,
		"series_distribution": int(commercial.series_distribution),
		"gate_share": int(commercial.gate_share),
		"owner_support": int(commercial.owner_support),
		"manufacturer_support": int(commercial.manufacturer_support),
		"sponsor_income": sponsor_per_race,
		"available_sponsor_estimate": available_sponsor_estimate,
		"expected_purse": expected_purse,
		"operations_cost": operations,
		"payroll_cost": payroll,
		"weekly_upkeep": weekly_upkeep,
		"projected_income": projected_income,
		"projected_costs": projected_costs,
		"projected_net": projected_net,
		"season_end_cash": team.money + projected_net,
		"minimum_reserve": minimum_reserve,
		"upgrade_budget": maxi(0, team.money - minimum_reserve),
		"sustainable": team.money + projected_net >= 0,
		"payroll_warning": payroll > race_income - operations
	}
