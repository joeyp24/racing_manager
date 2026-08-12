class_name CareerDecisionModel
extends RefCounted


static func build_inbox_choice(team: Team, item: Dictionary, choice_index: int) -> Dictionary:
	var choices := item.get("choices", []) as Array
	if choice_index < 0 or choice_index >= choices.size():
		return {}
	var choice := choices[choice_index] as Dictionary
	var effects := choice.get("effects", {}) as Dictionary
	var cost := int(choice.get("cost", 0))
	var money_effect := int(effects.get("money", 0))
	var deadline := int(item.get("deadline", CareerExpansionManager.SEASON_END_DAY))
	var expired := team.current_season_day > deadline
	return DecisionComparisonModel.build(team, {
		"eyebrow": "%s DECISION" % str(item.get("category", "CAREER")).to_upper(),
		"title": str(choice.get("label", "Respond")),
		"subtitle": "%s · Due %s" % [
			str(item.get("subject", "Career decision")),
			CalendarCatalog.format_day(deadline),
		],
		"current_title": "NO RESPONSE",
		"candidate_title": "THIS CHOICE",
		"metrics": _effect_metrics(team, effects),
		"upfront_cost": cost - money_effect,
		"action_enabled": not bool(item.get("resolved", false)) and not expired,
		"disabled_reason": "This decision expired on %s." % CalendarCatalog.format_day(deadline) if expired else "",
		"action_label": "Confirm response",
		"recommendation": str(item.get("why_changed", "Review how this choice supports the organization plan.")),
		"risk": _choice_risk(effects, cost),
		"context": {
			"kind": "career_inbox_choice",
			"item_id": str(item.get("id", "")),
			"choice_index": choice_index,
			"choice_label": str(choice.get("label", "Responded")),
		},
	})


static func build_time_advance(team: Team, target_day: int, preview: Dictionary, impacts: Dictionary) -> Dictionary:
	var expiring := impacts.get("expiring_decisions", []) as Array
	var activations := impacts.get("expiring_activations", []) as Array
	var completions := impacts.get("completions", []) as Array
	var readiness := impacts.get("entry_readiness", []) as Array
	var ready_entries := 0
	for value in readiness:
		if bool((value as Dictionary).get("race_ready", false)):
			ready_entries += 1
	var blocked_count := expiring.size() + activations.size()
	var blocker := ""
	if not expiring.is_empty():
		blocker = "%d unresolved decision%s would expire before this date." % [expiring.size(), "" if expiring.size() == 1 else "s"]
	if not activations.is_empty():
		var activation_text := "%d sponsor activation%s would expire before this date." % [activations.size(), "" if activations.size() == 1 else "s"]
		blocker = activation_text if blocker.is_empty() else "%s %s" % [blocker, activation_text]
	return DecisionComparisonModel.build(team, {
		"eyebrow": "TIME ADVANCEMENT REVIEW",
		"title": "Advance to %s" % CalendarCatalog.format_day(target_day),
		"subtitle": "%d calendar days · %d scheduled events across the racing world" % [
			int(preview.get("days", 0)),
			(preview.get("events", []) as Array).size(),
		],
		"current_title": CalendarCatalog.format_day(team.current_season_day).to_upper(),
		"candidate_title": CalendarCatalog.format_day(target_day).to_upper(),
		"metrics": [
			DecisionComparisonModel.metric("Open decisions", str(CareerExpansionManager.get_pending_decisions(team).size()), str(maxi(0, CareerExpansionManager.get_pending_decisions(team).size() - expiring.size())), "%d expire" % expiring.size(), DecisionComparisonModel.WORSENS if not expiring.is_empty() else DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Sponsor actions", "Current", "%d expire" % activations.size(), "Review" if not activations.is_empty() else "Clear", DecisionComparisonModel.WORSENS if not activations.is_empty() else DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Projects complete", "0", str(completions.size()), "+%d" % completions.size(), DecisionComparisonModel.IMPROVES if not completions.is_empty() else DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Race-ready entries", "%d/%d" % [ready_entries, readiness.size()], "%d/%d" % [ready_entries, readiness.size()], "No change", DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Other-series races", "0", str(int(preview.get("other_races", 0))), "+%d" % int(preview.get("other_races", 0)), DecisionComparisonModel.NEUTRAL),
		],
		"action_enabled": blocked_count == 0 and target_day > team.current_season_day,
		"disabled_reason": blocker if blocked_count > 0 else "Choose a future calendar date." if target_day <= team.current_season_day else "",
		"action_label": "Advance time",
		"recommendation": "Resolve anything that would expire, then advance once every active entry has the resources intended for the next race.",
		"risk": "No player decision or sponsor commitment will expire during this advance." if blocker.is_empty() else blocker,
		"context": {"kind": "advance_time", "target_day": target_day},
	})


static func _effect_metrics(team: Team, effects: Dictionary) -> Array:
	var metrics: Array = []
	for key in effects:
		if str(key) == "money":
			continue
		var current := _current_effect_value(team, str(key))
		var delta := int(effects[key])
		var candidate := current + delta
		metrics.append(DecisionComparisonModel.metric(
			_effect_label(str(key)),
			str(current),
			str(candidate),
			"%+d" % delta,
			_effect_impact(str(key), delta),
		))
	if metrics.is_empty():
		metrics.append(DecisionComparisonModel.metric("Commitment", "Open", "Resolved", "Recorded", DecisionComparisonModel.NEUTRAL))
	return metrics


static func _current_effect_value(team: Team, key: String) -> int:
	var state := CareerExpansionManager.ensure_state(team)
	match key:
		"fans": return team.fans
		"confidence": return int(state.board.confidence)
		"job_security": return int(state.board.job_security)
		"driver_morale":
			var drivers := team.get_contracted_drivers()
			if drivers.is_empty(): return 0
			var total := 0
			for driver in drivers: total += driver.morale
			return roundi(float(total) / float(drivers.size()))
		"staff_morale":
			var total := 0
			var count := 0
			for member in team.staff:
				if member.hired: total += member.morale; count += 1
			return roundi(float(total) / float(count)) if count > 0 else 0
		"sporting_credibility", "professionalism", "commercial_appeal":
			return ReputationManager.get_dimension(team, key)
		"reputation": return team.reputation
		"sponsor": return team.sponsor_objective_progress
		"rivalry":
			var rivalries := state.rivalries as Dictionary
			return int((rivalries[rivalries.keys()[0]] as Dictionary).intensity) if not rivalries.is_empty() else 0
	return 0


static func _effect_label(key: String) -> String:
	return {
		"fans": "Fans",
		"confidence": "Board confidence",
		"job_security": "Job security",
		"driver_morale": "Driver morale",
		"staff_morale": "Staff morale",
		"sporting_credibility": "Sporting credibility",
		"professionalism": "Professionalism",
		"commercial_appeal": "Commercial appeal",
		"reputation": "Reputation",
		"sponsor": "Sponsor progress",
		"rivalry": "Rivalry intensity",
	}.get(key, key.capitalize())


static func _effect_impact(key: String, delta: int) -> int:
	if delta == 0:
		return DecisionComparisonModel.NEUTRAL
	var positive := delta > 0
	if key == "rivalry":
		positive = not positive
	return DecisionComparisonModel.IMPROVES if positive else DecisionComparisonModel.WORSENS


static func _choice_risk(effects: Dictionary, cost: int) -> String:
	var negative: Array[String] = []
	for key in effects:
		var amount := int(effects[key])
		if amount < 0 and str(key) != "money":
			negative.append("%s %d" % [_effect_label(str(key)), amount])
	if not negative.is_empty():
		return "Trade-offs: %s." % ", ".join(negative)
	if cost > 0:
		return "This response commits $%s immediately." % _format_number(cost)
	return "This response has no identified negative team-state effect."


static func _format_number(number: int) -> String:
	var raw := str(number)
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
