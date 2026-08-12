class_name DecisionOutcomeModel
extends RefCounted


static func build(team: Team, specification: Dictionary) -> Dictionary:
	var model := specification.duplicate(true)
	var status := str(model.get("status", "success"))
	if status not in ["success", "error", "info"]:
		status = "info"
	var cash_delta := int(model.get("cash_delta", 0))
	var balance := team.money if team != null else int(model.get("balance", 0))
	model["status"] = status
	model["eyebrow"] = str(model.get("eyebrow", _default_eyebrow(status)))
	model["title"] = str(model.get("title", _default_title(status)))
	model["message"] = str(model.get("message", "The team state has been updated."))
	model["detail"] = str(model.get("detail", ""))
	model["cash_delta"] = cash_delta
	model["cash_effect"] = signed_money(cash_delta)
	model["balance"] = balance
	model["balance_text"] = money(balance)
	model["show_finance"] = bool(model.get("show_finance", status == "success"))
	model["action_label"] = str(model.get("action_label", ""))
	model["action_path"] = str(model.get("action_path", ""))
	model["duration"] = float(model.get("duration", 10.0 if status == "error" else 8.0))
	return model


static func money(amount: int) -> String:
	return "%s$%s" % ["-" if amount < 0 else "", _format_number(absi(amount))]


static func signed_money(amount: int) -> String:
	if amount == 0:
		return "$0"
	return "%s$%s" % ["+" if amount > 0 else "-", _format_number(absi(amount))]


static func _default_eyebrow(status: String) -> String:
	return {"success": "DECISION COMPLETE", "error": "ACTION NOT COMPLETED", "info": "TEAM UPDATE"}.get(status, "TEAM UPDATE")


static func _default_title(status: String) -> String:
	return {"success": "Update complete", "error": "Something changed", "info": "Team updated"}.get(status, "Team updated")


static func _format_number(number: int) -> String:
	var raw := str(number)
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
