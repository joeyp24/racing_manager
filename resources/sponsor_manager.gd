class_name SponsorManager
extends RefCounted

const OFFER_PROFILES: Array[Dictionary] = [
	{
		"id": "anchor_assurance",
		"name": "Anchor Assurance",
		"profile": "GUARANTEED",
		"signing": 4200,
		"race": 620,
		"objective": "finish_without_retiring",
		"target_ratio": 0.45,
		"bonus": 1800,
		"penalty": 500,
		"benefit_type": "stability",
		"benefit_value": 0.0,
		"interest": "Values dependable teams that bring the car home."
	},
	{
		"id": "velocity_performance",
		"name": "Velocity Performance",
		"profile": "PERFORMANCE",
		"signing": 900,
		"race": 760,
		"objective": "top_10_finishes",
		"target_ratio": 0.25,
		"bonus": 7200,
		"penalty": 1500,
		"benefit_type": "performance",
		"benefit_value": 0.0,
		"interest": "Pays aggressively for a team capable of headline results."
	},
	{
		"id": "brightline_media",
		"name": "Brightline Media",
		"profile": "GROWTH",
		"signing": 2200,
		"race": 680,
		"objective": "fans_gained",
		"target_ratio": 22.0,
		"bonus": 5000,
		"penalty": 900,
		"benefit_type": "fan_growth",
		"benefit_value": 0.25,
		"interest": "Your growing audience creates an appealing campaign platform."
	},
	{
		"id": "forge_technical",
		"name": "Forge Technical",
		"profile": "DEVELOPMENT",
		"signing": 1500,
		"race": 850,
		"objective": "points_finishes",
		"target_ratio": 0.35,
		"bonus": 4300,
		"penalty": 1000,
		"benefit_type": "repair_rebate",
		"benefit_value": 0.15,
		"interest": "Wants its engineering brand associated with steady progress."
	},
	{
		"id": "redline_energy",
		"name": "Redline Energy",
		"profile": "HIGH PRESSURE",
		"signing": 500,
		"race": 1100,
		"objective": "top_5_finishes",
		"target_ratio": 0.18,
		"bonus": 10500,
		"penalty": 3500,
		"benefit_type": "high_pressure",
		"benefit_value": 0.0,
		"interest": "Sees championship potential, but expects podium-level exposure."
	},
	{
		"id": "hometown_cooperative",
		"name": "Hometown Cooperative",
		"profile": "REGIONAL",
		"signing": 3100,
		"race": 590,
		"objective": "regional_finishes",
		"target_ratio": 0.30,
		"bonus": 3800,
		"penalty": 650,
		"benefit_type": "regional_bonus",
		"benefit_value": 0.50,
		"interest": "Your hometown roots align with its regional customer base."
	}
]

const SERIES_BRAND_PREFIXES: Dictionary = {
	"local_short_track": ["Main Street", "County Line", "Homefield", "Foundry"],
	"regional_short_track": ["Trailhead", "Cross-State", "Blue Ridge", "Pioneer"],
	"national_short_track": ["Victory Lane", "American Forge", "Highbank", "Patriot"],
	"continental_east_west": ["Coastline", "Meridian", "Waypoint", "Twin Harbor"],
	"continental_national": ["Continental", "Northstar", "Union Peak", "Atlas"],
	"national_truck": ["Ironhaul", "Longroad", "Workhorse", "Freightline"],
	"national_grand": ["Grandview", "Vanguard", "Sterling", "Summit"],
	"premier_cup": ["Crown", "Global Apex", "Prime", "Worldline"],
}

const PROFILE_SUFFIXES: Dictionary = {
	"anchor_assurance": ["Insurance", "Credit Union", "Mutual", "Bank"],
	"velocity_performance": ["Motors", "Performance", "Lubricants", "Speedworks"],
	"brightline_media": ["Media", "Wireless", "Network", "Digital"],
	"forge_technical": ["Machine", "Engineering", "Tools", "Technologies"],
	"redline_energy": ["Energy", "Power", "Fuel", "Athletics"],
	"hometown_cooperative": ["Co-op", "Markets", "Outfitters", "Foods"],
}


static func ensure_state(team: Team) -> void:
	if team == null:
		return
	team.ensure_race_teams()
	if not team.active_sponsor_id.is_empty() and team.active_sponsor_contract.is_empty():
		_migrate_legacy_contract(team)
	var active_team := team.get_active_race_team()
	if active_team != null and not team.active_sponsor_contract.is_empty() and active_team.sponsor_contracts.is_empty():
		active_team.sponsor_contracts.append(team.active_sponsor_contract.duplicate(true))
	# Team still mirrors the active entry for older UI and saves. Reuse a mirror
	# that already has entry ownership; legacy generic markets are regenerated.
	if (
		active_team != null
		and active_team.sponsor_offers.is_empty()
		and not team.sponsor_offers.is_empty()
		and str(team.sponsor_offers[0].get("race_team_id", "")) == active_team.team_id
		and team.sponsor_offer_season == team.season_number
		and team.sponsor_offer_series_id == team.current_series_id
	):
		active_team.sponsor_offers = team.sponsor_offers.duplicate(true)
		active_team.sponsor_offer_season = team.sponsor_offer_season
		active_team.sponsor_offer_series_id = team.sponsor_offer_series_id
	for race_team in team.race_teams:
		if race_team == null:
			continue
		if (
			race_team.sponsor_offer_season != team.season_number
			or race_team.sponsor_offer_series_id != team.current_series_id
			or race_team.sponsor_offers.is_empty()
		):
			race_team.sponsor_offers = generate_offers(team, race_team)
			race_team.sponsor_offer_season = team.season_number
			race_team.sponsor_offer_series_id = team.current_series_id
	team._sync_active_sponsor_legacy_fields()


static func generate_offers(team: Team, race_team: RaceTeam = null) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if race_team == null:
		race_team = team.get_active_race_team()
	var season_length := _season_length(team)
	var series_index := maxi(0, SeriesCatalog.get_index(team.current_series_id))
	var marketing_level := team.get_department_level("marketing")
	var active_driver: Driver = team.get_driver_by_id(race_team.driver_id) if race_team != null else team.get_active_driver()
	var driver_marketability := float(active_driver.marketability) / 500.0 if active_driver != null else 0.10
	var commercial_appeal := ReputationManager.get_dimension(team, "commercial_appeal")
	var professionalism := ReputationManager.get_dimension(team, "professionalism")
	var sporting_credibility := ReputationManager.get_dimension(team, "sporting_credibility")
	var marketability := clampf(
		float(team.get_reputation_level()) / 60.0
		+ float(team.fans) / 5000.0
		+ float(marketing_level) * 0.05
		+ driver_marketability
		+ float(commercial_appeal - 50) / 500.0,
		0.0,
		0.35
	)
	for profile_index in OFFER_PROFILES.size():
		var profile := OFFER_PROFILES[profile_index]
		var sponsor_identity := _sponsor_identity(team, race_team, profile, profile_index)
		var sponsor_id := str(sponsor_identity.id)
		var relationship := int(team.sponsor_relationships.get(sponsor_id, 0))
		var loyalty_multiplier := (
			1.0
			+ maxf(0.0, float(relationship)) * 0.003
			+ maxf(0.0, float(professionalism - 50)) * 0.001
		)
		var base_multiplier := 1.0 + marketability + float(series_index) * 0.035
		if str(profile.profile) in ["PERFORMANCE", "HIGH PRESSURE"]:
			base_multiplier += maxf(0.0, float(sporting_credibility - 50)) * 0.002
		var signing := team.get_effective_sponsor_value(roundi(float(profile.signing) * base_multiplier * loyalty_multiplier))
		var race_payment := team.get_effective_sponsor_value(roundi(float(profile.race) * base_multiplier * loyalty_multiplier))
		var objective_bonus := team.get_effective_sponsor_value(roundi(float(profile.bonus) * base_multiplier * loyalty_multiplier))
		var failure_penalty := team.get_effective_sponsor_value(roundi(float(profile.penalty) * base_multiplier))
		var target := _objective_target(str(profile.objective), float(profile.target_ratio), season_length)
		var probability := estimate_objective_probability(team, str(profile.objective), target, season_length)
		var guaranteed := signing + race_payment * season_length
		var maximum := guaranteed + objective_bonus
		var expected := guaranteed + roundi(float(objective_bonus) * probability) - roundi(float(failure_penalty) * (1.0 - probability))
		offers.append({
			"sponsor_id": sponsor_id,
			"sponsor_name": str(sponsor_identity.name),
			"profile": str(profile.profile),
			"signing_bonus": signing,
			"payment_per_race": race_payment,
			"objective_type": str(profile.objective),
			"objective_target": target,
			"objective_bonus": objective_bonus,
			"failure_penalty": failure_penalty,
			"benefit_type": str(profile.benefit_type),
			"benefit_value": float(profile.benefit_value),
			"contract_length": season_length,
			"guaranteed_value": guaranteed,
			"maximum_value": maximum,
			"expected_value": expected,
			"objective_probability": probability,
			"interest_reason": str(profile.interest),
			"relationship": relationship,
			"renewal": relationship > 0 and professionalism >= 40,
			"required_reputation": maxi(1, int(SeriesCatalog.get_series(team.current_series_id).get("required_level", 1))),
			"market_series_id": team.current_series_id,
			"race_team_id": race_team.team_id if race_team != null else "",
		})
	return offers


static func _sponsor_identity(team: Team, race_team: RaceTeam, profile: Dictionary, profile_index: int) -> Dictionary:
	var prefixes := SERIES_BRAND_PREFIXES.get(
		team.current_series_id,
		["Independent", "National", "United", "Premier"]
	) as Array
	var suffixes := PROFILE_SUFFIXES.get(str(profile.id), [str(profile.name)]) as Array
	var entry_index := maxi(0, team.race_teams.find(race_team))
	var season_offset := maxi(0, team.season_number - 1)
	var prefix_index := posmod(entry_index + profile_index + season_offset, prefixes.size())
	var suffix_index := posmod(entry_index * 2 + profile_index + season_offset, suffixes.size())
	var sponsor_name := "%s %s" % [str(prefixes[prefix_index]), str(suffixes[suffix_index])]
	return {
		"id": "%s_%s_%s_%d" % [
			team.current_series_id,
			race_team.team_id if race_team != null else "team",
			str(profile.id),
			season_offset,
		],
		"name": sponsor_name,
	}


static func sign_offer(team: Team, offer_index: int) -> Dictionary:
	ensure_state(team)
	if (
		team == null
		or team.is_series_season_complete()
	):
		return {}
	var race_team := team.get_active_race_team()
	if race_team == null or race_team.sponsor_contracts.size() >= team.get_sponsor_capacity():
		return {}
	if offer_index < 0 or offer_index >= race_team.sponsor_offers.size():
		return {}
	var offer := (race_team.sponsor_offers[offer_index] as Dictionary).duplicate(true)
	for existing in race_team.sponsor_contracts:
		if str(existing.get("sponsor_id", "")) == str(offer.get("sponsor_id", "")):
			return {}
	var remaining_races := maxi(1, _season_length(team) - team.get_completed_races().size())
	offer["contract_length"] = remaining_races
	offer["races_remaining"] = remaining_races
	offer["objective_progress"] = 0
	offer["objective_completed"] = false
	offer["objective_failed"] = false
	offer["signed_season"] = team.season_number
	offer["signed_series_id"] = team.current_series_id
	offer["fans_progress"] = 0
	offer["race_team_id"] = race_team.team_id
	race_team.sponsor_contracts.append(offer)
	for sponsor_id in team.sponsor_relationships:
		if str(sponsor_id) != str(offer.sponsor_id) and int(team.sponsor_relationships[sponsor_id]) >= 20:
			adjust_relationship(team, str(sponsor_id), -3)
	team._sync_active_sponsor_legacy_fields()
	return offer


static func process_race_result(team: Team, result: RaceResult) -> Dictionary:
	ensure_state(team)
	var outcome := {
		"sponsor_name": "",
		"race_payment": 0,
		"objective_bonus": 0,
		"objective_completed": false,
		"failure_penalty": 0
	}
	var sponsor_names: Array[String] = []
	var entered_team_ids: Array[String] = []
	for row in result.standings:
		if bool(row.get("is_player", false)):
			entered_team_ids.append(str(row.get("team_id", "")))
	for race_team in team.race_teams:
		if race_team == null or not race_team.active or (not entered_team_ids.is_empty() and not entered_team_ids.has(race_team.team_id)):
			continue
		var renewed_contracts: Array[Dictionary] = []
		for contract_value in race_team.sponsor_contracts:
			var contract := contract_value.duplicate(true) as Dictionary
			var contract_outcome := _process_contract(team, result, contract)
			sponsor_names.append(str(contract.get("sponsor_name", "Sponsor")))
			outcome.race_payment = int(outcome.race_payment) + int(contract_outcome.race_payment)
			outcome.objective_bonus = int(outcome.objective_bonus) + int(contract_outcome.objective_bonus)
			outcome.failure_penalty = int(outcome.failure_penalty) + int(contract_outcome.failure_penalty)
			outcome.objective_completed = bool(outcome.objective_completed) or bool(contract_outcome.objective_completed)
			if not bool(contract_outcome.expired):
				renewed_contracts.append(contract)
		race_team.sponsor_contracts = renewed_contracts
	outcome.sponsor_name = ", ".join(sponsor_names)
	team._sync_active_sponsor_legacy_fields()
	return outcome


static func _process_contract(team: Team, result: RaceResult, contract: Dictionary) -> Dictionary:
	var outcome := {"race_payment":int(contract.get("payment_per_race", 0)), "objective_bonus":0, "objective_completed":false, "failure_penalty":0, "expired":false}
	match str(contract.get("benefit_type", "")):
		"fan_growth":
			var bonus_fans := roundi(float(result.fans_earned) * float(contract.get("benefit_value", 0.0)))
			result.fans_earned += bonus_fans
			team.fans += bonus_fans
		"repair_rebate":
			outcome.race_payment = int(outcome.race_payment) + roundi(float(result.repair_cost) * float(contract.get("benefit_value", 0.0)))
		"regional_bonus":
			if result.race != null and result.race.track_type == "Short Track":
				outcome.race_payment = int(outcome.race_payment) + roundi(float(contract.get("payment_per_race", 0)) * float(contract.get("benefit_value", 0.0)))
	var progress_gain := _objective_progress_for_result(contract, result)
	if not bool(contract.get("objective_completed", false)) and progress_gain > 0:
		contract["objective_progress"] = int(contract.get("objective_progress", 0)) + progress_gain
		if int(contract.objective_progress) >= int(contract.get("objective_target", 1)):
			contract["objective_completed"] = true
			outcome.objective_completed = true
			outcome.objective_bonus = int(contract.get("objective_bonus", 0))
			adjust_relationship(team, str(contract.get("sponsor_id", "")), 12)
			ReputationManager.apply_sponsor_outcome(team, true, str(contract.get("sponsor_name", "Sponsor")))
	contract["races_remaining"] = maxi(0, int(contract.get("races_remaining", 0)) - 1)
	if int(contract.races_remaining) == 0:
		outcome.expired = true
		if not bool(contract.get("objective_completed", false)):
			outcome.failure_penalty = int(contract.get("failure_penalty", 0))
			adjust_relationship(team, str(contract.get("sponsor_id", "")), -10)
			ReputationManager.apply_sponsor_outcome(team, false, str(contract.get("sponsor_name", "Sponsor")))
	return outcome


static func add_activation_progress(team: Team, sponsor_id: String) -> void:
	for race_team in team.race_teams:
		for contract in race_team.sponsor_contracts:
			if str(contract.get("sponsor_id", "")) != sponsor_id or str(contract.get("objective_type", "")) != "sponsor_activations":
				continue
			contract["objective_progress"] = int(contract.get("objective_progress", 0)) + 1
			if int(contract.objective_progress) >= int(contract.get("objective_target", 1)):
				contract["objective_completed"] = true
	team._sync_active_sponsor_legacy_fields()


static func adjust_relationship(team: Team, sponsor_id: String, amount: int) -> void:
	team.sponsor_relationships[sponsor_id] = clampi(
		int(team.sponsor_relationships.get(sponsor_id, 0)) + amount,
		-100,
		100
	)


static func objective_description(contract: Dictionary) -> String:
	var target := int(contract.get("objective_target", 1))
	match str(contract.get("objective_type", "")):
		"finish_without_retiring":
			return "Finish %d races without retiring" % target
		"top_15_finishes":
			return "Score %d top-15 finishes" % target
		"top_10_finishes":
			return "Score %d top-10 finishes" % target
		"top_5_finishes":
			return "Score %d top-five finishes" % target
		"points_finishes":
			return "Score points in %d races" % target
		"fans_gained":
			return "Gain %d fans through race weekends" % target
		"regional_finishes":
			return "Earn %d top-15 results at short tracks" % target
		"sponsor_activations":
			return "Complete %d sponsor activations" % target
		_:
			return "Complete the sponsor objective"


static func benefit_description(contract: Dictionary) -> String:
	match str(contract.get("benefit_type", "")):
		"fan_growth":
			return "Campaign support adds %d%% to race-week fan growth." % roundi(float(contract.get("benefit_value", 0.0)) * 100.0)
		"repair_rebate":
			return "Technical partnership rebates %d%% of post-race repair costs." % roundi(float(contract.get("benefit_value", 0.0)) * 100.0)
		"regional_bonus":
			return "Regional events pay a %d%% race-payment premium." % roundi(float(contract.get("benefit_value", 0.0)) * 100.0)
		"high_pressure":
			return "Highest earning ceiling, paired with the market's toughest penalty."
		"performance":
			return "A result-heavy structure converts competitive form into cash."
		"stability":
			return "The largest guaranteed package protects cash flow through poor form."
	return "Standard commercial support."


static func estimate_objective_probability(
	team: Team,
	objective_type: String,
	target: int,
	season_length: int
) -> float:
	var form_position := team.last_season_position
	if form_position <= 0:
		form_position = 12
	var per_race := 0.70
	match objective_type:
		"finish_without_retiring":
			per_race = 0.86
		"top_15_finishes", "regional_finishes":
			per_race = clampf(1.05 - float(form_position) / 24.0, 0.30, 0.90)
		"top_10_finishes", "points_finishes":
			per_race = clampf(0.90 - float(form_position) / 22.0, 0.18, 0.80)
		"top_5_finishes":
			per_race = clampf(0.65 - float(form_position) / 18.0, 0.08, 0.62)
		"fans_gained":
			return clampf(0.52 + float(team.fans) / 8000.0, 0.45, 0.88)
	var expected_hits := per_race * float(season_length)
	return clampf(0.5 + (expected_hits - float(target)) / maxf(4.0, float(season_length)), 0.08, 0.94)


static func _objective_progress_for_result(contract: Dictionary, result: RaceResult) -> int:
	var player_status := ""
	if result.finishing_position > 0 and result.finishing_position <= result.standings.size():
		player_status = str((result.standings[result.finishing_position - 1] as Dictionary).get("status", ""))
	var finished := result.finishing_position > 0 and player_status != "Retired"
	match str(contract.objective_type):
		"finish_without_retiring":
			return 1 if finished else 0
		"top_15_finishes":
			return 1 if finished and result.finishing_position <= 15 else 0
		"top_10_finishes":
			return 1 if finished and result.finishing_position <= 10 else 0
		"top_5_finishes":
			return 1 if finished and result.finishing_position <= 5 else 0
		"points_finishes":
			return 1 if result.championship_points_earned > 0 else 0
		"fans_gained":
			return maxi(0, result.fans_earned)
		"regional_finishes":
			return 1 if finished and result.finishing_position <= 15 and result.race != null and result.race.track_type == "Short Track" else 0
	return 0


static func _objective_target(objective_type: String, ratio: float, season_length: int) -> int:
	if objective_type == "fans_gained":
		return maxi(120, roundi(ratio * float(season_length)))
	return maxi(1, roundi(ratio * float(season_length)))


static func _season_length(team: Team) -> int:
	return int(SeriesCatalog.get_series(team.current_series_id).get("season_length", 12))


static func _migrate_legacy_contract(team: Team) -> void:
	var sponsor := SponsorCatalog.find_by_id(team.active_sponsor_id)
	if sponsor == null:
		team.active_sponsor_id = ""
		team.sponsor_races_remaining = 0
		return
	var objective_type := sponsor.objective_type
	if objective_type == "finish_race":
		objective_type = "finish_without_retiring"
	elif objective_type == "top_15":
		objective_type = "top_15_finishes"
	team.active_sponsor_contract = {
		"sponsor_id": sponsor.sponsor_id,
		"sponsor_name": sponsor.sponsor_name,
		"profile": "LEGACY",
		"payment_per_race": team.get_effective_sponsor_value(sponsor.payment_per_race),
		"signing_bonus": team.get_effective_sponsor_value(sponsor.signing_bonus),
		"objective_type": objective_type,
		"objective_target": sponsor.objective_target,
		"objective_bonus": team.get_effective_sponsor_value(sponsor.objective_bonus),
		"failure_penalty": 0,
		"benefit_type": "stability",
		"benefit_value": 0.0,
		"races_remaining": maxi(1, team.sponsor_races_remaining),
		"contract_length": maxi(1, team.sponsor_races_remaining),
		"objective_progress": team.sponsor_objective_progress,
		"objective_completed": team.sponsor_objective_completed,
		"objective_failed": false,
		"signed_season": team.season_number,
		"signed_series_id": team.current_series_id,
		"relationship": int(team.sponsor_relationships.get(sponsor.sponsor_id, 0))
	}
	_sync_legacy_fields(team)


static func _sync_legacy_fields(team: Team) -> void:
	if team.active_sponsor_contract.is_empty():
		team.active_sponsor_id = ""
		team.sponsor_races_remaining = 0
		team.sponsor_objective_progress = 0
		team.sponsor_objective_completed = false
		return
	var contract := team.active_sponsor_contract
	team.active_sponsor_id = str(contract.sponsor_id)
	team.sponsor_races_remaining = int(contract.races_remaining)
	team.sponsor_objective_progress = int(contract.objective_progress)
	team.sponsor_objective_completed = bool(contract.objective_completed)
