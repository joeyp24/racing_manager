extends SceneTree


func _initialize() -> void:
	_test_series_prestige_scales_sponsor_value()
	_test_generated_offers_cover_the_remaining_season()
	_test_contract_terms_are_snapshotted()
	_test_multiple_sponsors_pay_the_same_race_team()
	_test_entries_receive_distinct_sponsor_markets()
	_test_series_progression_refreshes_sponsor_brands()
	_test_each_entry_can_sign_multiple_sponsors()
	_test_legacy_contract_is_migrated()
	_test_retirement_does_not_advance_finish_objective()
	_test_failure_applies_relationship_consequences()
	_test_completed_season_cannot_collect_a_signing_bonus()
	print("Sponsorship system tests passed")
	quit(0)


func _test_series_prestige_scales_sponsor_value() -> void:
	var team := Team.new()
	team.career_difficulty = "Club"
	team.current_series_id = "local_short_track"
	var local_value := team.get_effective_sponsor_value(1000)
	team.current_series_id = "premier_cup"
	var premier_value := team.get_effective_sponsor_value(1000)
	assert(local_value == 1000)
	assert(premier_value == 5500)


func _test_generated_offers_cover_the_remaining_season() -> void:
	var team := Team.new()
	team.current_series_id = "premier_cup"
	SponsorManager.ensure_state(team)
	assert(team.sponsor_offers.size() == 6)
	for offer in team.sponsor_offers:
		assert(int(offer.contract_length) == 36)
		assert(int(offer.payment_per_race) > 1500)
		assert(int(offer.expected_value) <= int(offer.maximum_value))


func _test_contract_terms_are_snapshotted() -> void:
	var team := Team.new()
	SponsorManager.ensure_state(team)
	var contract := SponsorManager.sign_offer(team, 0)
	assert(not contract.is_empty())
	var signed_payment := int(contract.payment_per_race)
	team.sponsor_offers[0].payment_per_race = signed_payment * 9
	assert(int(team.active_sponsor_contract.payment_per_race) == signed_payment)
	assert(int(team.active_sponsor_contract.races_remaining) == 12)


func _test_multiple_sponsors_pay_the_same_race_team() -> void:
	var team := Team.new()
	SponsorManager.ensure_state(team)
	var first := SponsorManager.sign_offer(team, 0)
	var second := SponsorManager.sign_offer(team, 1)
	assert(not first.is_empty() and not second.is_empty())
	assert(team.get_active_sponsor_contracts().size() == 2)
	var result := RaceResult.new()
	result.finishing_position = 20
	result.standings = [{"is_player":true, "team_id":team.active_race_team_id, "status":"Finished"}]
	var outcome := SponsorManager.process_race_result(team, result)
	assert(int(outcome.race_payment) >= int(first.payment_per_race) + int(second.payment_per_race))


func _test_entries_receive_distinct_sponsor_markets() -> void:
	var team := Team.new()
	team.ensure_race_teams()
	var second_team := RaceTeam.new()
	second_team.team_id = "team_2"
	second_team.team_name = "Team 2"
	team.race_teams.append(second_team)
	SponsorManager.ensure_state(team)
	var first_names := _offer_names(team.race_teams[0].sponsor_offers)
	var second_names := _offer_names(second_team.sponsor_offers)
	assert(first_names.size() == 6)
	assert(second_names.size() == 6)
	assert(first_names != second_names)
	for sponsor_name in first_names:
		assert(not second_names.has(sponsor_name))


func _test_series_progression_refreshes_sponsor_brands() -> void:
	var team := Team.new()
	team.current_series_id = "local_short_track"
	SponsorManager.ensure_state(team)
	var local_names := _offer_names(team.get_active_race_team().sponsor_offers)
	team.current_series_id = "regional_short_track"
	SponsorManager.ensure_state(team)
	var regional_names := _offer_names(team.get_active_race_team().sponsor_offers)
	assert(local_names != regional_names)
	for sponsor_name in local_names:
		assert(not regional_names.has(sponsor_name))


func _test_each_entry_can_sign_multiple_sponsors() -> void:
	var team := Team.new()
	team.ensure_race_teams()
	var second_team := RaceTeam.new()
	second_team.team_id = "team_2"
	second_team.team_name = "Team 2"
	team.race_teams.append(second_team)
	SponsorManager.ensure_state(team)
	var first_contract := SponsorManager.sign_offer(team, 0)
	var second_contract := SponsorManager.sign_offer(team, 1)
	assert(not first_contract.is_empty() and not second_contract.is_empty())
	assert(team.race_teams[0].sponsor_contracts.size() == 2)
	team.set_active_race_team(second_team.team_id)
	var third_contract := SponsorManager.sign_offer(team, 0)
	var fourth_contract := SponsorManager.sign_offer(team, 1)
	assert(not third_contract.is_empty() and not fourth_contract.is_empty())
	assert(second_team.sponsor_contracts.size() == 2)
	assert(str(first_contract.sponsor_name) != str(third_contract.sponsor_name))


func _offer_names(offers: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for offer in offers:
		names.append(str(offer.get("sponsor_name", "")))
	return names


func _test_legacy_contract_is_migrated() -> void:
	var team := Team.new()
	team.active_sponsor_id = "apex_fuel"
	team.sponsor_races_remaining = 7
	team.sponsor_objective_progress = 1
	SponsorManager.ensure_state(team)
	assert(str(team.active_sponsor_contract.sponsor_id) == "apex_fuel")
	assert(int(team.active_sponsor_contract.races_remaining) == 7)
	assert(int(team.active_sponsor_contract.objective_progress) == 1)
	assert(str(team.active_sponsor_contract.objective_type) == "top_15_finishes")


func _test_retirement_does_not_advance_finish_objective() -> void:
	var team := Team.new()
	team.active_sponsor_contract = {
		"sponsor_id": "test_partner",
		"sponsor_name": "Test Partner",
		"profile": "GUARANTEED",
		"payment_per_race": 500,
		"objective_type": "finish_without_retiring",
		"objective_target": 1,
		"objective_bonus": 1000,
		"failure_penalty": 100,
		"races_remaining": 2,
		"objective_progress": 0,
		"objective_completed": false
	}
	var result := RaceResult.new()
	result.finishing_position = 1
	result.standings = [{"status": "Retired"}]
	var outcome := SponsorManager.process_race_result(team, result)
	assert(not bool(outcome.objective_completed))
	assert(int(team.active_sponsor_contract.objective_progress) == 0)


func _test_failure_applies_relationship_consequences() -> void:
	var team := Team.new()
	team.reputation = 20
	var starting_professionalism := ReputationManager.get_dimension(team, "professionalism")
	var starting_commercial_appeal := ReputationManager.get_dimension(team, "commercial_appeal")
	team.active_sponsor_contract = {
		"sponsor_id": "pressure_partner",
		"sponsor_name": "Pressure Partner",
		"profile": "HIGH PRESSURE",
		"payment_per_race": 1000,
		"objective_type": "top_5_finishes",
		"objective_target": 1,
		"objective_bonus": 5000,
		"failure_penalty": 750,
		"races_remaining": 1,
		"objective_progress": 0,
		"objective_completed": false
	}
	var result := RaceResult.new()
	result.finishing_position = 12
	result.standings = [{"status": "Finished"}]
	var outcome := SponsorManager.process_race_result(team, result)
	assert(int(outcome.failure_penalty) == 750)
	assert(team.active_sponsor_contract.is_empty())
	assert(int(team.sponsor_relationships.pressure_partner) == -10)
	assert(team.reputation == 20)
	assert(ReputationManager.get_dimension(team, "professionalism") == starting_professionalism - 5)
	assert(ReputationManager.get_dimension(team, "commercial_appeal") == starting_commercial_appeal - 4)


func _test_completed_season_cannot_collect_a_signing_bonus() -> void:
	var team := Team.new()
	SponsorManager.ensure_state(team)
	team.set_series_season_complete(team.current_series_id, true)
	assert(SponsorManager.sign_offer(team, 0).is_empty())
