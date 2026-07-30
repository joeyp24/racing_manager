extends Control

@onready var summary_label: Label = %summary_label
@onready var status_label: Label = %status_label
@onready var contracts_container: VBoxContainer = %contracts_container
@onready var market_container: VBoxContainer = %market_container
@onready var rumors_label: Label = %rumors_label
@onready var transactions_label: Label = %transactions_label
@onready var recap_label: Label = %recap_label
@onready var readiness_label: Label = %readiness_label
@onready var complete_button: Button = %complete_button
@onready var back_button: Button = %back_button


func _ready() -> void:
	back_button.pressed.connect(_return_to_championship)
	complete_button.pressed.connect(_complete_offseason)
	if GameManager.team == null:
		status_label.text = "No career is loaded."
		complete_button.disabled = true
		return
	if str(GameManager.team.offseason_data.get("status", "")) != "Prepared":
		RaceManager.prepare_offseason(GameManager.team.current_series_id)
	_refresh()


func _refresh(message: String = "") -> void:
	var team := GameManager.team
	if team == null:
		return
	var data := team.offseason_data
	if str(data.get("status", "")) != "Prepared":
		status_label.text = "The offseason is not available until the championship is complete."
		complete_button.disabled = true
		return
	var source := SeriesCatalog.get_series(str(data.source_series_id))
	var target := SeriesCatalog.get_series(str(data.target_series_id))
	var direction := "Returning to %s" % str(target.name)
	if str(data.source_series_id) != str(data.target_series_id):
		direction = "Promoting from %s to %s" % [str(source.name), str(target.name)]
	summary_label.text = "SEASON %d COMPLETE  •  Finished %s  •  Prize $%s\n%s  •  %d roster spot%s filled" % [
		int(data.season_number),
		_ordinal(int(data.championship_position)),
		_format_money(int(data.championship_prize)),
		direction,
		team.contracted_driver_ids.size(),
		"" if team.contracted_driver_ids.size() == 1 else "s"
	]
	status_label.text = message
	_clear(contracts_container)
	_clear(market_container)
	_build_contracts(data.get("player_contracts", []))
	_build_market(team.get_offseason_free_agents())
	rumors_label.text = _lines(data.get("rumors", []), "No active rumors.")
	var transaction_lines: Array[String] = []
	for transaction_value in data.get("transactions", []):
		transaction_lines.append("• " + str((transaction_value as Dictionary).get("text", "")))
	transactions_label.text = "\n".join(transaction_lines) if not transaction_lines.is_empty() else "No confirmed moves."
	var recap_lines: Array[String] = []
	for development in data.get("development", []):
		recap_lines.append("• " + str(development))
	for ai_summary in data.get("ai_development", []):
		recap_lines.append("• " + str(ai_summary))
	for retirement in data.get("retirements", []):
		recap_lines.append("• " + str(retirement))
	for rookie in data.get("rookies", []):
		recap_lines.append("• " + str(rookie))
	recap_label.text = "\n".join(recap_lines) if not recap_lines.is_empty() else "No major paddock changes were recorded."
	var readiness := OffseasonManager.can_complete(team)
	complete_button.disabled = not bool(readiness.get("ready", false))
	readiness_label.text = str(readiness.get("reason", ""))
	complete_button.tooltip_text = readiness_label.text


func _build_contracts(contracts: Array) -> void:
	if contracts.is_empty():
		_add_empty_row(contracts_container, "No player contracts require review. Use the transfer market to build your lineup.")
		return
	for contract_value in contracts:
		var contract := contract_value as Dictionary
		var panel := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITokens.SPACE_MD)
		var details := Label.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.text = "%s  •  %d OVR  •  Fit %d%%  •  %s\nDemand: $%s/race + $%s signing  •  Rival: %s at $%s/race\n%s" % [
			str(contract.driver_name),
			int(contract.overall),
			int(contract.team_fit),
			str(contract.career_goal),
			_format_money(int(contract.demand_salary)),
			_format_money(int(contract.demand_signing)),
			str(contract.rival_team_name),
			_format_money(int(contract.rival_salary)),
			str(contract.decision)
		]
		row.add_child(details)
		if str(contract.status) == "Pending":
			row.add_child(_action_button("Renew", _renew.bind(str(contract.driver_id), false)))
			row.add_child(_action_button("Match Rival", _renew.bind(str(contract.driver_id), true)))
			row.add_child(_action_button("Let Walk", _release.bind(str(contract.driver_id))))
		else:
			var badge := Label.new()
			badge.text = str(contract.status)
			badge.theme_type_variation = &"StatusLabel"
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(badge)
		panel.get_child(0).add_child(row)
		contracts_container.add_child(panel)


func _build_market(drivers: Array[Driver]) -> void:
	if drivers.is_empty():
		_add_empty_row(market_container, "The available driver pool has been signed out.")
		return
	for driver in drivers:
		var panel := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITokens.SPACE_MD)
		var details := Label.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state := GameManager.team.get_ai_driver_state(driver.driver_id)
		details.text = "%s  •  %d OVR / %d POT  •  Age %d  •  Morale %d\n%s  •  $%s/race  •  $%s signing  •  Goal: %s" % [
			driver.driver_name,
			driver.get_overall_rating(),
			driver.get_potential_overall(),
			driver.age,
			driver.morale,
			driver.archetype,
			_format_money(driver.salary),
			_format_money(driver.signing_fee),
			str(state.get("career_goal", "Secure a competitive seat"))
		]
		row.add_child(details)
		var sign_button := _action_button("Sign", _sign.bind(driver.driver_id))
		sign_button.disabled = GameManager.team.contracted_driver_ids.size() >= GameManager.team.get_driver_roster_limit() or GameManager.team.money < GameManager.team.get_discounted_cost(driver.signing_fee)
		row.add_child(sign_button)
		panel.get_child(0).add_child(row)
		market_container.add_child(panel)


func _renew(driver_id: String, match_rival: bool) -> void:
	var result := OffseasonManager.renew_player_driver(GameManager.team, driver_id, match_rival)
	GameManager.save_game()
	_refresh(str(result.get("reason", "")))


func _release(driver_id: String) -> void:
	if OffseasonManager.release_player_driver(GameManager.team, driver_id):
		GameManager.save_game()
		_refresh("The driver accepted the competing offer.")


func _sign(driver_id: String) -> void:
	var result := OffseasonManager.sign_free_agent(GameManager.team, driver_id)
	GameManager.save_game()
	_refresh(str(result.get("reason", "")))


func _complete_offseason() -> void:
	if not RaceManager.complete_offseason():
		_refresh("Resolve the remaining offseason decisions before continuing.")
		return
	var team := GameManager.team
	if not team.owns_car_for_series(team.current_series_id):
		GameManager.load_page("res://scenes/pages/dealership/dealership.tscn")
	elif team.get_contracted_drivers().is_empty():
		GameManager.load_page("res://scenes/pages/driver_market/driver_market.tscn")
	else:
		GameManager.load_page("res://scenes/pages/dashboard/dashboard.tscn")


func _return_to_championship() -> void:
	GameManager.load_page("res://scenes/pages/championship/championship.tscn")


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(94, UITokens.CONTROL_HEIGHT)
	button.pressed.connect(callback)
	return button


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_top", UITokens.CARD_PADDING_VERTICAL)
	margin.add_theme_constant_override("margin_right", UITokens.CARD_PADDING_HORIZONTAL)
	margin.add_theme_constant_override("margin_bottom", UITokens.CARD_PADDING_VERTICAL)
	panel.add_child(margin)
	return panel


func _add_empty_row(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	container.add_child(label)


func _clear(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


func _lines(values: Array, empty_text: String) -> String:
	var lines: Array[String] = []
	for value in values:
		lines.append("• " + str(value))
	return "\n".join(lines) if not lines.is_empty() else empty_text


func _ordinal(value: int) -> String:
	if value <= 0:
		return "unclassified"
	if value % 100 >= 11 and value % 100 <= 13:
		return "%dth" % value
	match value % 10:
		1: return "%dst" % value
		2: return "%dnd" % value
		3: return "%drd" % value
	return "%dth" % value


func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + formatted
