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


static func ensure_state(team: Team) -> void:
	if team == null:
		return
	if not team.active_sponsor_id.is_empty() and team.active_sponsor_contract.is_empty():
		_migrate_legacy_contract(team)
	if (
		team.sponsor_offer_season != team.season_number
		or team.sponsor_offer_series_id != team.current_series_id
		or team.sponsor_offers.is_empty()
	):
		team.sponsor_offers = generate_offers(team)
		team.sponsor_offer_season = team.season_number
		team.sponsor_offer_series_id = team.current_series_id


static func generate_offers(team: Team) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var season_length := _season_length(team)
	var series_index := maxi(0, SeriesCatalog.get_index(team.current_series_id))
	var marketing_level := team.get_department_level("marketing")
	var active_driver: Driver = team.get_active_driver()
	var driver_marketability := float(active_driver.marketability) / 500.0 if active_driver != null else 0.10
	var marketability := clampf(
		float(team.reputation) / 800.0
		+ float(team.fans) / 5000.0
		+ float(marketing_level) * 0.05
		+ driver_marketability,
		0.0,
		0.35
	)
	for profile in OFFER_PROFILES:
		var relationship := int(team.sponsor_relationships.get(str(profile.id), 0))
		var loyalty_multiplier := 1.0 + maxf(0.0, float(relationship)) * 0.003
		var base_multiplier := 1.0 + marketability + float(series_index) * 0.035
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
			"sponsor_id": str(profile.id),
			"sponsor_name": str(profile.name),
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
			"renewal": relationship > 0,
			"required_reputation": maxi(0, series_index * 35 - 25)
		})
	return offers


static func sign_offer(team: Team, offer_index: int) -> Dictionary:
	ensure_state(team)
	if (
		team == null
		or not team.active_sponsor_contract.is_empty()
		or team.is_series_season_complete()
	):
		return {}
	if offer_index < 0 or offer_index >= team.sponsor_offers.size():
		return {}
	var offer := (team.sponsor_offers[offer_index] as Dictionary).duplicate(true)
	if team.reputation < int(offer.required_reputation):
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
	team.active_sponsor_contract = offer
	for sponsor_id in team.sponsor_relationships:
		if str(sponsor_id) != str(offer.sponsor_id) and int(team.sponsor_relationships[sponsor_id]) >= 20:
			adjust_relationship(team, str(sponsor_id), -3)
	_sync_legacy_fields(team)
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
	if team.active_sponsor_contract.is_empty():
		return outcome
	var contract := team.active_sponsor_contract
	outcome.sponsor_name = str(contract.sponsor_name)
	outcome.race_payment = int(contract.payment_per_race)
	match str(contract.get("benefit_type", "")):
		"fan_growth":
			var bonus_fans := roundi(float(result.fans_earned) * float(contract.get("benefit_value", 0.0)))
			result.fans_earned += bonus_fans
			team.fans += bonus_fans
		"repair_rebate":
			outcome.race_payment = int(outcome.race_payment) + roundi(
				float(result.repair_cost) * float(contract.get("benefit_value", 0.0))
			)
		"regional_bonus":
			if result.race != null and result.race.track_type == "Short Track":
				outcome.race_payment = int(outcome.race_payment) + roundi(
					float(contract.payment_per_race) * float(contract.get("benefit_value", 0.0))
				)
	var progress_gain := _objective_progress_for_result(contract, result)
	if not bool(contract.objective_completed) and progress_gain > 0:
		contract.objective_progress = int(contract.objective_progress) + progress_gain
		if int(contract.objective_progress) >= int(contract.objective_target):
			contract.objective_completed = true
			outcome.objective_completed = true
			outcome.objective_bonus = int(contract.objective_bonus)
			adjust_relationship(team, str(contract.sponsor_id), 12)
	contract.races_remaining = maxi(0, int(contract.races_remaining) - 1)
	team.active_sponsor_contract = contract
	if int(contract.races_remaining) == 0:
		if not bool(contract.objective_completed):
			outcome.failure_penalty = int(contract.failure_penalty)
			contract.objective_failed = true
			adjust_relationship(team, str(contract.sponsor_id), -10)
			team.reputation = maxi(0, team.reputation - 5)
		team.active_sponsor_contract = {}
	_sync_legacy_fields(team)
	return outcome


static func add_activation_progress(team: Team, sponsor_id: String) -> void:
	if team.active_sponsor_contract.is_empty():
		return
	var contract := team.active_sponsor_contract
	if str(contract.sponsor_id) != sponsor_id or str(contract.objective_type) != "sponsor_activations":
		return
	contract.objective_progress = int(contract.objective_progress) + 1
	if int(contract.objective_progress) >= int(contract.objective_target):
		contract.objective_completed = true
	team.active_sponsor_contract = contract
	_sync_legacy_fields(team)


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
