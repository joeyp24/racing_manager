class_name DecisionComparisonModel
extends RefCounted

const IMPROVES := 1
const NEUTRAL := 0
const WORSENS := -1
const WARNING := 2


static func metric(label: String, current: String, candidate: String, delta: String = "", impact: int = NEUTRAL, detail: String = "") -> Dictionary:
	return {
		"label": label,
		"current": current,
		"candidate": candidate,
		"delta": delta,
		"impact": impact,
		"detail": detail,
	}


static func build(team: Team, specification: Dictionary) -> Dictionary:
	var model := specification.duplicate(true)
	var upfront_cost := int(model.get("upfront_cost", 0))
	var recurring_per_race := int(model.get("recurring_per_race", 0))
	var forecast := FinanceManager.build_forecast(team)
	var remaining_races := int(forecast.get("remaining_races", 0))
	var recurring_events := clampi(int(model.get("recurring_events", remaining_races)), 0, remaining_races)
	var current_cash := team.money if team != null else 0
	var cash_after := current_cash - upfront_cost
	var season_end_before := int(forecast.get("season_end_cash", current_cash))
	var season_end_after := season_end_before - upfront_cost - recurring_per_race * recurring_events
	var reserve := int(forecast.get("minimum_reserve", 0))
	var enabled := bool(model.get("action_enabled", true)) and team != null and cash_after >= 0
	var supplied_risk := str(model.get("risk", ""))
	var risk := supplied_risk
	var risk_level := str(model.get("risk_level", ""))
	if not enabled:
		risk_level = "blocked"
		var disabled_reason := str(model.get("disabled_reason", ""))
		if disabled_reason.is_empty() and team != null and cash_after < 0:
			disabled_reason = "You need %s more cash to complete this decision." % money(-cash_after)
		if disabled_reason.is_empty():
			disabled_reason = "This decision cannot be completed with the current eligibility or available cash."
		model["disabled_reason"] = disabled_reason
		risk = disabled_reason
	elif cash_after < reserve:
		risk_level = "warning"
		risk = "Cash would fall below the recommended operating reserve by %s." % money(reserve - cash_after)
		if not supplied_risk.is_empty():
			risk += " " + supplied_risk
	elif season_end_after < 0:
		risk_level = "warning"
		risk = "The current forecast would finish the season below zero cash."
		if not supplied_risk.is_empty():
			risk += " " + supplied_risk
	else:
		risk_level = "safe"
		if risk.is_empty():
			risk = "This decision remains inside the current cash and season forecast."

	model["action_enabled"] = enabled
	model["risk"] = risk
	model["risk_level"] = risk_level
	model["finance"] = {
		"upfront": _cash_flow(-upfront_cost),
		"recurring": "%s / race · %d races" % [_cash_flow(-recurring_per_race), recurring_events] if recurring_per_race != 0 else "No change",
		"cash_after": money(cash_after),
		"season_end_after": money(season_end_after),
		"reserve": money(reserve),
	}
	return model


static func money(amount: int) -> String:
	return "%s$%s" % ["-" if amount < 0 else "", _format_number(absi(amount))]


static func _cash_flow(amount: int) -> String:
	if amount == 0:
		return "$0"
	return "%s$%s" % ["+" if amount > 0 else "-", _format_number(absi(amount))]


static func _format_number(number: int) -> String:
	var raw := str(number)
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
