extends RefCounted
class_name OffseasonManager

const FIRST_NAMES := ["Ari", "Casey", "Devon", "Emery", "Frankie", "Harper", "Jules", "Kai", "Lane", "Morgan", "Nico", "Parker", "Quinn", "Reese", "Sage", "Taylor"]
const LAST_NAMES := ["Bishop", "Chen", "Costa", "Dawson", "Ellis", "Flores", "Grant", "Hughes", "Ibrahim", "Kim", "Lopez", "Meyer", "Novak", "Patel", "Reed", "Vega"]


static func prepare(team: Team, target_series_id: String, ai_summaries: Array[String]) -> Dictionary:
	if team == null:
		return {}
	if (
		str(team.offseason_data.get("status", "")) == "Prepared"
		and int(team.offseason_data.get("season_year", 0)) == team.current_season_year
	):
		return team.offseason_data
	team.ensure_ai_driver_career()
	var source_series_id := team.current_series_id
	var target_id := target_series_id if not target_series_id.is_empty() else source_series_id
	var data := {
		"status": "Prepared",
		"season_year": team.current_season_year,
		"season_number": team.season_number,
		"source_series_id": source_series_id,
		"target_series_id": target_id,
		"championship_position": team.last_season_position,
		"championship_prize": team.last_season_prize,
		"player_contracts": _build_player_contracts(team, target_id),
		"rumors": [],
		"transactions": [],
		"retirements": [],
		"rookies": [],
		"free_agent_ids": [],
		"ai_development": ai_summaries.duplicate(),
		"development": team.last_development_summary.duplicate()
	}
	_run_ai_market(team, data)
	_refresh_free_agents(team, data)
	team.offseason_data = data
	team.emit_changed()
	return data


static func retarget(team: Team, target_series_id: String) -> void:
	if team == null or str(team.offseason_data.get("status", "")) != "Prepared" or target_series_id.is_empty():
		return
	if str(team.offseason_data.get("target_series_id", "")) == target_series_id:
		return
	var previous_contracts := team.offseason_data.get("player_contracts", []) as Array
	var rebuilt := _build_player_contracts(team, target_series_id)
	for contract in rebuilt:
		for previous_value in previous_contracts:
			var previous := previous_value as Dictionary
			if str(previous.get("driver_id", "")) != str(contract.driver_id):
				continue
			if str(previous.get("status", "")) != "Pending":
				contract["status"] = str(previous.status)
				contract["decision"] = str(previous.get("decision", "Resolved"))
			break
	team.offseason_data["target_series_id"] = target_series_id
	team.offseason_data["player_contracts"] = rebuilt
	_refresh_free_agents(team, team.offseason_data)
	team.emit_changed()


static func renew_player_driver(team: Team, driver_id: String, match_rival: bool = false) -> Dictionary:
	var contract := _get_player_contract(team, driver_id)
	if contract.is_empty() or str(contract.get("status", "")) != "Pending":
		return {"accepted": false, "reason": "This contract no longer needs a decision."}
	var driver := team.get_driver_by_id(driver_id)
	if driver == null:
		return {"accepted": false, "reason": "The driver is no longer available."}
	var salary := int(contract.rival_salary) if match_rival else int(contract.demand_salary)
	var signing_fee := int(contract.demand_signing)
	if not match_rival and int(contract.team_fit) < 45:
		return {"accepted": false, "reason": "%s wants the rival offer matched because team fit is only %d%%." % [driver.driver_name, int(contract.team_fit)]}
	var total_cost := team.get_discounted_cost(signing_fee)
	if team.money < total_cost:
		return {"accepted": false, "reason": "The team cannot afford the $%s renewal fee." % String.num_int64(total_cost)}
	team.money -= total_cost
	driver.salary = salary
	driver.signing_fee = signing_fee
	driver.contract_length = int(contract.contract_length)
	driver.contract_races_remaining = driver.contract_length
	driver.morale = mini(99, driver.morale + (8 if match_rival else 4))
	driver.team_name = team.team_name
	driver.is_player_driver = team.get_active_driver() == null or driver.is_player_driver
	var state := team.ensure_ai_driver_state(driver)
	state["current_team_id"] = "player_team"
	state["current_series_id"] = str(team.offseason_data.target_series_id)
	var season_length := maxi(1, int(SeriesCatalog.get_series(str(team.offseason_data.target_series_id)).season_length))
	state["contract_seasons"] = maxi(1, ceili(float(int(contract.contract_length)) / float(season_length)))
	state["morale"] = driver.morale
	_record_team_history(state, "player_team", str(team.offseason_data.target_series_id), team.current_season_year + 1)
	team.ai_driver_career[driver_id] = state
	contract["status"] = "Retained"
	contract["decision"] = "Matched rival offer" if match_rival else "Renewed"
	_update_player_contract(team, contract)
	team.record_finance("Driver", -total_cost, "Renewed %s" % driver.driver_name)
	_append_transaction(team, "%s stays with %s on a %d-race agreement." % [driver.driver_name, team.team_name, driver.contract_length], driver_id, "player_team", "renewal")
	team.emit_changed()
	return {"accepted": true, "reason": "%s has renewed." % driver.driver_name}


static func release_player_driver(team: Team, driver_id: String) -> bool:
	var contract := _get_player_contract(team, driver_id)
	if contract.is_empty() or str(contract.get("status", "")) != "Pending":
		return false
	var driver := team.get_driver_by_id(driver_id)
	if driver == null:
		return false
	team.contracted_driver_ids.erase(driver_id)
	for race_team in team.race_teams:
		if race_team != null and race_team.driver_id == driver_id:
			race_team.driver_id = ""
	driver.is_player_driver = false
	driver.team_name = str(contract.rival_team_name)
	driver.salary = int(contract.rival_salary)
	driver.morale = maxi(0, driver.morale - 6)
	var state := team.ensure_ai_driver_state(driver)
	state["current_team_id"] = str(contract.rival_team_id)
	state["current_series_id"] = str(team.offseason_data.target_series_id)
	state["contract_seasons"] = 2
	state["salary"] = int(contract.rival_salary)
	state["morale"] = driver.morale
	team.ai_driver_career[driver_id] = state
	_place_driver_on_team(team, state, str(contract.rival_team_id), team.offseason_data)
	contract["status"] = "Departed"
	contract["decision"] = "Accepted rival offer"
	_update_player_contract(team, contract)
	_append_transaction(team, "%s leaves %s for %s." % [driver.driver_name, team.team_name, str(contract.rival_team_name)], driver_id, str(contract.rival_team_id), "transfer")
	_assign_primary_player_driver(team)
	team.emit_changed()
	return true


static func sign_free_agent(team: Team, driver_id: String) -> Dictionary:
	if team == null or str(team.offseason_data.get("status", "")) != "Prepared":
		return {"accepted": false, "reason": "The transfer window is not open."}
	if team.contracted_driver_ids.size() >= team.get_driver_roster_limit():
		return {"accepted": false, "reason": "The player driver roster is full."}
	var free_ids := team.offseason_data.get("free_agent_ids", []) as Array
	if not free_ids.has(driver_id):
		return {"accepted": false, "reason": "That driver has already signed elsewhere."}
	var driver := team.get_driver_by_id(driver_id)
	if driver == null:
		return {"accepted": false, "reason": "The driver is no longer available."}
	var signing_cost := team.get_discounted_cost(driver.signing_fee)
	if team.money < signing_cost:
		return {"accepted": false, "reason": "The team cannot afford the signing fee."}
	team.money -= signing_cost
	if not team.contracted_driver_ids.has(driver_id):
		team.contracted_driver_ids.append(driver_id)
	driver.team_name = team.team_name
	driver.series_id = str(team.offseason_data.target_series_id)
	driver.contract_length = maxi(driver.contract_length, int(SeriesCatalog.get_series(driver.series_id).season_length))
	driver.contract_races_remaining = driver.contract_length
	driver.is_player_driver = team.get_active_driver() == null
	driver.morale = mini(99, driver.morale + 10)
	var state := team.ensure_ai_driver_state(driver)
	state["current_team_id"] = "player_team"
	state["current_series_id"] = driver.series_id
	state["contract_seasons"] = 1
	state["morale"] = driver.morale
	_record_team_history(state, "player_team", driver.series_id, team.current_season_year + 1)
	team.ai_driver_career[driver_id] = state
	free_ids.erase(driver_id)
	team.offseason_data["free_agent_ids"] = free_ids
	team.record_finance("Driver", -signing_cost, "Signed %s in the offseason" % driver.driver_name)
	_append_transaction(team, "%s signs with %s as a free agent." % [driver.driver_name, team.team_name], driver_id, "player_team", "signing")
	team.emit_changed()
	return {"accepted": true, "reason": "%s has joined the team." % driver.driver_name}


static func can_complete(team: Team) -> Dictionary:
	if team == null or str(team.offseason_data.get("status", "")) != "Prepared":
		return {"ready": false, "reason": "Prepare the offseason before continuing."}
	for contract_value in team.offseason_data.get("player_contracts", []):
		var contract := contract_value as Dictionary
		if str(contract.get("status", "")) == "Pending":
			return {"ready": false, "reason": "Resolve every expiring player contract first."}
	var target_id := str(team.offseason_data.get("target_series_id", team.current_series_id))
	if target_id != team.current_series_id and not team.can_enter_series(target_id):
		return {"ready": false, "reason": "Promotion funding or facility requirements are no longer met."}
	return {"ready": true, "reason": "The roster and season plan are ready."}


static func complete(team: Team) -> bool:
	var readiness := can_complete(team)
	if not bool(readiness.ready):
		return false
	var recap := team.offseason_data.duplicate(true)
	recap["status"] = "Complete"
	for transaction_value in recap.get("transactions", []):
		var transaction := (transaction_value as Dictionary).duplicate(true)
		transaction["season"] = team.current_season_year + 1
		var already_recorded := false
		for recorded_value in team.transfer_history:
			var recorded := recorded_value as Dictionary
			if str(recorded.get("text", "")) == str(transaction.get("text", "")) and int(recorded.get("season", 0)) == int(transaction.season):
				already_recorded = true
				break
		if not already_recorded:
			team.transfer_history.push_front(transaction)
	if team.transfer_history.size() > 100:
		team.transfer_history.resize(100)
	team.season_history.push_front(recap)
	if team.season_history.size() > 20:
		team.season_history.resize(20)
	team.offseason_data["status"] = "Complete"
	team.emit_changed()
	return true


static func _build_player_contracts(team: Team, target_series_id: String) -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	var organizations := team.get_ai_organizations_for_series(target_series_id)
	if organizations.is_empty():
		organizations = team.get_ai_organizations_for_series(team.current_series_id)
	var season_length := int(SeriesCatalog.get_series(target_series_id).get("season_length", 12))
	for driver in team.get_contracted_drivers():
		var overall := driver.get_overall_rating()
		var team_fit := clampi(48 + roundi(float(driver.loyalty) * 0.28) + team.hq_level * 3 - roundi(float(driver.ambition) * 0.14) + (8 if team.last_season_position <= 3 and team.last_season_position > 0 else 0), 20, 95)
		var salary_growth := 1.04 + float(maxi(0, overall - 55)) * 0.006 + float(driver.ambition) * 0.0015
		var demand_salary := maxi(500, roundi(float(driver.salary) * salary_growth / 50.0) * 50)
		var demand_signing := maxi(demand_salary, roundi(float(driver.signing_fee) * 0.55))
		var rival := organizations[absi(hash(driver.driver_id + str(team.current_season_year))) % organizations.size()] if not organizations.is_empty() else {}
		var pending := driver.contract_races_remaining <= 0
		contracts.append({
			"driver_id": driver.driver_id,
			"driver_name": driver.driver_name,
			"overall": overall,
			"current_salary": driver.salary,
			"demand_salary": demand_salary,
			"demand_signing": demand_signing,
			"contract_length": season_length * (2 if driver.loyalty >= 65 else 1),
			"team_fit": team_fit,
			"career_goal": team._get_driver_career_goal(driver),
			"rival_team_id": str(rival.get("team_id", "")),
			"rival_team_name": str(rival.get("team_name", "a rival team")),
			"rival_salary": roundi(float(demand_salary) * 1.10 / 50.0) * 50,
			"status": "Pending" if pending else "Under contract",
			"decision": "Decision required" if pending else "%d races remaining" % driver.contract_races_remaining
		})
	return contracts


static func _run_ai_market(team: Team, data: Dictionary) -> void:
	var rumors := data.rumors as Array
	var transactions := data.transactions as Array
	var retirements := data.retirements as Array
	var released: Array[String] = []
	var retirement_counts: Dictionary = {}
	for state_value in team.ai_driver_career.values():
		var state := state_value as Dictionary
		var driver := team.get_driver_by_id(str(state.driver_id))
		if driver == null or team.contracted_driver_ids.has(driver.driver_id):
			continue
		state["age"] = driver.age
		state["contract_seasons"] = maxi(0, int(state.get("contract_seasons", 1)) - 1)
		var age := driver.age
		var retirement_threshold := clampi((age - 36) * 13, 0, 92)
		var retirement_roll := absi(hash(driver.driver_id + str(team.current_season_year))) % 100
		if age >= 44 or (age >= 37 and retirement_roll < retirement_threshold):
			var retirement_series_id := str(state.get("current_series_id", driver.series_id))
			state["retired"] = true
			state["current_team_id"] = ""
			driver.availability_status = "Retired"
			retirements.append("%s retires at age %d after %d career starts." % [driver.driver_name, age, int(state.get("starts", driver.career_starts))])
			transactions.append({"text":"%s announces retirement." % driver.driver_name, "driver_id":driver.driver_id, "team_id":"", "type":"retirement"})
			retirement_counts[retirement_series_id] = int(retirement_counts.get(retirement_series_id, 0)) + 1
			team.ai_driver_career[driver.driver_id] = state
			continue
		var team_id := str(state.get("current_team_id", ""))
		if team_id.is_empty():
			if not released.has(driver.driver_id):
				released.append(driver.driver_id)
			continue
		if team_id == "player_team":
			continue
		var organization := team.get_ai_team_state(team_id)
		if organization.is_empty():
			state["current_team_id"] = ""
			released.append(driver.driver_id)
			team.ai_driver_career[driver.driver_id] = state
			continue
		var organization_series_id := str(organization.current_series_id)
		if str(state.get("current_series_id", "")) != organization_series_id:
			_record_team_history(state, team_id, organization_series_id, team.current_season_year + 1)
		state["current_series_id"] = organization_series_id
		var last_position := int(organization.get("last_position", 0))
		var result_morale := 2 if last_position > 0 and last_position <= 3 else (-3 if last_position >= 8 else 0)
		driver.morale = clampi(driver.morale + result_morale, 0, 99)
		state["morale"] = driver.morale
		state["team_fit"] = clampi(roundi(float(driver.loyalty + driver.teamwork + driver.morale) / 3.0), 0, 99)
		var lineup := team.get_ai_lineup_for_team(team_id)
		var weakest_rating := 100
		for teammate_state in lineup:
			var teammate := team.get_driver_by_id(str(teammate_state.driver_id))
			if teammate != null:
				weakest_rating = mini(weakest_rating, teammate.get_overall_rating())
		var financially_limited := str(organization.get("financial_status", "Stable")) != "Stable"
		var release_expired := int(state.contract_seasons) <= 0 and (driver.get_overall_rating() <= weakest_rating + 2 or financially_limited)
		if release_expired:
			state["current_team_id"] = ""
			released.append(driver.driver_id)
			rumors.append("%s is expected to test free agency after talks with %s stalled." % [driver.driver_name, team.get_ai_team_name(team_id)])
			transactions.append({"text":"%s releases %s." % [team.get_ai_team_name(team_id), driver.driver_name], "driver_id":driver.driver_id, "team_id":team_id, "type":"release"})
		else:
			state["contract_seasons"] = maxi(1, int(state.contract_seasons))
		team.ai_driver_career[driver.driver_id] = state

	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		var retirement_count := int(retirement_counts.get(series_id, 0))
		var rookie_count := maxi(1, retirement_count)
		for rookie_index in rookie_count:
			var rookie := _create_rookie(team, series_id, rookie_index)
			if rookie != null:
				released.append(rookie.driver_id)
				(data.rookies as Array).append("%s enters the %s with %d overall and %d potential." % [rookie.driver_name, str(series.name), rookie.get_overall_rating(), rookie.get_potential_overall()])

	for series in SeriesCatalog.SERIES:
		var series_id := str(series.id)
		for organization in team.get_ai_organizations_for_series(series_id):
			var team_id := str(organization.team_id)
			var slots := int(organization.driver_count)
			var lineup := team.get_ai_lineup_for_team(team_id)
			while lineup.size() > slots:
				var displaced: Dictionary = lineup.pop_back()
				displaced["current_team_id"] = ""
				released.append(str(displaced.driver_id))
				team.ai_driver_career[str(displaced.driver_id)] = displaced
			while lineup.size() < slots:
				var candidate := _choose_candidate(team, released, series_id, organization)
				if candidate.is_empty():
					break
				var candidate_driver := team.get_driver_by_id(str(candidate.driver_id))
				rumors.append("%s has emerged as a target for %s." % [candidate_driver.driver_name, str(organization.team_name)])
				_place_driver_on_team(team, candidate, team_id, data)
				released.erase(str(candidate.driver_id))
				lineup.append(candidate)
				transactions.append({"text":"%s signs %s." % [str(organization.team_name), candidate_driver.driver_name], "driver_id":candidate_driver.driver_id, "team_id":team_id, "type":"signing"})
	data["rumors"] = rumors
	data["transactions"] = transactions
	data["retirements"] = retirements


static func _create_rookie(team: Team, series_id: String, rookie_index: int) -> Driver:
	var seed := absi(hash("%s_%d_%d" % [series_id, team.current_season_year, rookie_index]))
	var driver_id := "rookie_%d_%s_%02d" % [team.current_season_year, series_id, rookie_index + 1]
	if team.get_driver_by_id(driver_id) != null:
		return null
	var series := SeriesCatalog.get_series(series_id)
	var base_rating := clampi(int(series.car_rating) - 8 + seed % 9, 38, 88)
	var potential := clampi(base_rating + 10 + seed % 14, base_rating, 97)
	var driver := Driver.new()
	driver.driver_id = driver_id
	var last_name_index := floori(float(seed) / 3.0) % LAST_NAMES.size()
	driver.driver_name = "%s %s" % [FIRST_NAMES[seed % FIRST_NAMES.size()], LAST_NAMES[last_name_index]]
	driver.series_id = series_id
	driver.age = 18 + seed % 5
	driver.salary = roundi(float(series.car_price) * (0.018 + float(seed % 4) * 0.003))
	driver.signing_fee = driver.salary * 2
	driver.initialize_detailed_ratings(base_rating, base_rating - 2 + seed % 5, 45 + seed % 38, potential)
	driver.ambition = 62 + seed % 30
	driver.loyalty = 38 + seed % 45
	driver.marketability = 35 + seed % 55
	driver.racing_background = "Academy graduate"
	driver.biography = "A highly rated rookie entering the professional ladder after a strong development campaign."
	driver.update_archetype()
	team.drivers.append(driver)
	var state := team.ensure_ai_driver_state(driver)
	state["rookie"] = true
	state["current_team_id"] = ""
	state["current_series_id"] = series_id
	state["contract_seasons"] = 0
	team.ai_driver_career[driver_id] = state
	return driver


static func _choose_candidate(team: Team, candidate_ids: Array[String], series_id: String, organization: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	var target_index := SeriesCatalog.get_index(series_id)
	for driver_id in candidate_ids:
		var state := team.get_ai_driver_state(driver_id)
		var driver := team.get_driver_by_id(driver_id)
		if state.is_empty() or driver == null or bool(state.get("retired", false)) or team.contracted_driver_ids.has(driver_id):
			continue
		var source_index := SeriesCatalog.get_index(str(state.get("current_series_id", driver.series_id)))
		if source_index >= 0 and absi(source_index - target_index) > 1:
			continue
		var team_state := team.get_ai_team_state(str(organization.team_id))
		var affordability := clampf(float(team_state.get("budget", 0)) / maxf(1.0, float(driver.salary * int(SeriesCatalog.get_series(series_id).season_length))), 0.0, 6.0)
		var fit := 8.0 if driver.desired_competitiveness <= int(organization.overall_rating) else -5.0
		var score := float(driver.get_overall_rating()) * 1.2 + float(driver.get_potential_overall()) * 0.22 + affordability * 3.0 + fit
		if source_index == target_index:
			score += 1000.0
		if score > best_score:
			best_score = score
			best = state
	return best


static func _place_driver_on_team(team: Team, state: Dictionary, team_id: String, data: Dictionary) -> void:
	if state.is_empty() or team_id.is_empty():
		return
	var organization := team.get_ai_team_state(team_id)
	var driver := team.get_driver_by_id(str(state.driver_id))
	if driver == null or organization.is_empty():
		return
	state["current_team_id"] = team_id
	state["current_series_id"] = str(organization.current_series_id)
	state["contract_seasons"] = 1 + absi(hash(driver.driver_id + str(team.current_season_year))) % 3
	state["salary"] = driver.salary
	state["morale"] = mini(99, driver.morale + 5)
	state["team_fit"] = clampi(roundi(float(driver.loyalty + driver.teamwork + int(state.morale)) / 3.0), 0, 99)
	_record_team_history(state, team_id, str(organization.current_series_id), team.current_season_year + 1)
	driver.team_name = str(organization.team_name)
	driver.series_id = str(organization.current_series_id)
	team.ai_driver_career[driver.driver_id] = state
	var signing_cost := maxi(driver.signing_fee, driver.salary)
	organization["budget"] = int(organization.get("budget", 0)) - signing_cost
	organization["driver_changes"] = int(organization.get("driver_changes", 0)) + 1
	team.ai_team_career[team_id] = organization
	if data.has("free_agent_ids"):
		(data.free_agent_ids as Array).erase(driver.driver_id)
	var lineup := team.get_ai_lineup_for_team(team_id)
	var slots := team.get_ai_team_slot_count(team_id, str(organization.current_series_id))
	if lineup.size() > slots:
		var displaced := lineup[lineup.size() - 1]
		if str(displaced.driver_id) == driver.driver_id and lineup.size() > 1:
			displaced = lineup[lineup.size() - 2]
		displaced["current_team_id"] = ""
		team.ai_driver_career[str(displaced.driver_id)] = displaced
		var displaced_driver := team.get_driver_by_id(str(displaced.driver_id))
		if displaced_driver != null:
			displaced_driver.team_name = "Free Agent"
			(data.get("free_agent_ids", []) as Array).append(displaced_driver.driver_id)
			if data.has("transactions"):
				(data.transactions as Array).append({
					"text": "%s releases %s to make room in its lineup." % [str(organization.team_name), displaced_driver.driver_name],
					"driver_id": displaced_driver.driver_id,
					"team_id": team_id,
					"type": "release"
				})


static func _refresh_free_agents(team: Team, data: Dictionary) -> void:
	var ids: Array[String] = []
	var target_index := SeriesCatalog.get_index(str(data.target_series_id))
	for state_value in team.ai_driver_career.values():
		var state := state_value as Dictionary
		if bool(state.get("retired", false)) or not str(state.get("current_team_id", "")).is_empty():
			continue
		var driver := team.get_driver_by_id(str(state.driver_id))
		if driver == null or team.contracted_driver_ids.has(driver.driver_id):
			continue
		var driver_index := SeriesCatalog.get_index(str(state.get("current_series_id", driver.series_id)))
		if driver_index < 0 or absi(driver_index - target_index) <= 1:
			ids.append(driver.driver_id)
	ids.sort_custom(func(first_id: String, second_id: String) -> bool:
		var first := team.get_driver_by_id(first_id)
		var second := team.get_driver_by_id(second_id)
		return first.get_overall_rating() > second.get_overall_rating()
	)
	if ids.size() > 16:
		ids.resize(16)
	data["free_agent_ids"] = ids


static func _get_player_contract(team: Team, driver_id: String) -> Dictionary:
	for contract_value in team.offseason_data.get("player_contracts", []):
		var contract := contract_value as Dictionary
		if str(contract.get("driver_id", "")) == driver_id:
			return contract
	return {}


static func _update_player_contract(team: Team, updated: Dictionary) -> void:
	var contracts := team.offseason_data.get("player_contracts", []) as Array
	for index in contracts.size():
		if str((contracts[index] as Dictionary).get("driver_id", "")) == str(updated.driver_id):
			contracts[index] = updated
			break
	team.offseason_data["player_contracts"] = contracts


static func _append_transaction(team: Team, text: String, driver_id: String, team_id: String, type: String) -> void:
	var transaction := {"season":team.current_season_year + 1, "text":text, "driver_id":driver_id, "team_id":team_id, "type":type}
	var transactions := team.offseason_data.get("transactions", []) as Array
	transactions.append(transaction)
	team.offseason_data["transactions"] = transactions
	team.transfer_history.push_front(transaction)
	if team.transfer_history.size() > 100:
		team.transfer_history.resize(100)


static func _record_team_history(state: Dictionary, team_id: String, series_id: String, season: int) -> void:
	var history := state.get("team_history", []) as Array
	if not history.is_empty():
		var latest := history[0] as Dictionary
		if str(latest.get("team_id", "")) == team_id and str(latest.get("series_id", "")) == series_id and int(latest.get("season", 0)) == season:
			return
	history.push_front({"season":season, "team_id":team_id, "series_id":series_id})
	if history.size() > 20:
		history.resize(20)
	state["team_history"] = history


static func _assign_primary_player_driver(team: Team) -> void:
	var active := team.get_active_driver()
	if active != null and team.contracted_driver_ids.has(active.driver_id):
		return
	for driver in team.drivers:
		if driver != null:
			driver.is_player_driver = false
	var contracted := team.get_contracted_drivers()
	if not contracted.is_empty():
		contracted[0].is_player_driver = true
