extends Control

const PROFILE_COLORS: Dictionary = {
	"GUARANTEED": Color("4da3ff"),
	"PERFORMANCE": Color("ffb547"),
	"GROWTH": Color("65d38e"),
	"DEVELOPMENT": Color("a88bff"),
	"HIGH PRESSURE": Color("ff626f"),
	"REGIONAL": Color("55cfcc"),
	"LEGACY": Color("8f9bad")
}

@onready var status_label: Label = %status_label
@onready var offers_container: VBoxContainer = %offers_container
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer


func _ready() -> void:
	comparison_drawer.action_requested.connect(_on_comparison_action)
	show_sponsors()


func show_sponsors() -> void:
	for child in offers_container.get_children():
		child.queue_free()
	var team := GameManager.team
	if team == null:
		status_label.text = "No team is currently loaded."
		return
	SponsorManager.ensure_state(team)
	_create_team_switcher(team)
	_show_market_header(team)
	for contract in team.get_active_sponsor_contracts():
		_create_active_contract(team, contract)
	if team.get_active_sponsor_contracts().size() < team.get_sponsor_capacity():
		_create_offer_comparison_header()
		var offers := _active_offers(team)
		for index in offers.size():
			_create_offer_card(index, offers[index], team)
	_create_relationship_section(team)


func _create_team_switcher(team: Team) -> void:
	var row := HBoxContainer.new()
	var label := _label("MANAGING RACE TEAM", &"EyebrowLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	for race_team in team.race_teams:
		var button := Button.new()
		button.text = race_team.team_name
		button.toggle_mode = true
		button.button_pressed = race_team.team_id == team.active_race_team_id
		button.pressed.connect(_select_race_team.bind(race_team.team_id))
		row.add_child(button)
	offers_container.add_child(row)


func _select_race_team(team_id: String) -> void:
	if GameManager.team.set_active_race_team(team_id):
		GameManager.save_game()
		show_sponsors()


func _show_market_header(team: Team) -> void:
	var series := SeriesCatalog.get_series(team.current_series_id)
	var prestige := float(series.get("sponsor_prestige_multiplier", 1.0))
	var races_left := maxi(0, int(series.get("season_length", 12)) - team.get_completed_races().size())
	var contracts := team.get_active_sponsor_contracts()
	var active_team := team.get_active_race_team()
	if contracts.is_empty():
		status_label.text = (
			"PARTNERSHIP MARKET  /  %s  /  SEASON %d\n"
			+ "%s  -  %.1fx media prestige  -  %d race weekends remaining\n"
			+ "%d of %d sponsor slots filled. Reputation levels 7 and 12 add another slot."
		) % [active_team.team_name if active_team != null else "Race Team", team.season_number, str(series.get("name", "Current Series")), prestige, races_left, contracts.size(), team.get_sponsor_capacity()]
	else:
		status_label.text = (
			"COMMERCIAL PORTFOLIO  /  %s\n"
			+ "%d of %d sponsor slots  -  $%s guaranteed each race"
		) % [active_team.team_name if active_team != null else "Race Team", contracts.size(), team.get_sponsor_capacity(), _format_number(active_team.get_sponsor_income_per_race() if active_team != null else 0)]


func _create_active_contract(team: Team, contract: Dictionary) -> void:
	var panel := _new_card(str(contract.profile))
	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_child(_label(
		"%s   |   %s" % [str(contract.sponsor_name).to_upper(), str(contract.profile)],
		&"SectionTitle"
	))
	var progress := int(contract.objective_progress)
	var target := int(contract.objective_target)
	content.add_child(_label(
		"$%s each race   |   Objective bonus $%s   |   Failure exposure $%s"
		% [
			_format_number(int(contract.payment_per_race)),
			_format_number(int(contract.objective_bonus)),
			_format_number(int(contract.failure_penalty))
		]
	))
	content.add_child(_label(
		"%s\n%s\nProgress %d/%d%s"
		% [
			SponsorManager.objective_description(contract),
			SponsorManager.benefit_description(contract),
			progress,
			target,
			" - SECURED" if bool(contract.objective_completed) else ""
		]
	))
	var progress_bar := ProgressBar.new()
	progress_bar.max_value = maxf(1.0, float(target))
	progress_bar.value = float(progress)
	progress_bar.show_percentage = true
	content.add_child(progress_bar)
	content.add_child(_label(
		"Relationship: %s   |   Terms are locked for this contract"
		% _relationship_label(int(team.sponsor_relationships.get(str(contract.sponsor_id), 0)))
	))
	offers_container.add_child(panel)


func _create_offer_comparison_header() -> void:
	var guide := PanelContainer.new()
	var label := _label(
		"READING THE MARKET\n"
		+ "Guaranteed value is paid regardless of results. Expected value accounts for your estimated "
		+ "objective chance and failure penalty. Maximum value assumes the objective is completed."
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_child(label)
	offers_container.add_child(guide)


func _create_offer_card(index: int, offer: Dictionary, team: Team) -> void:
	var panel := _new_card(str(offer.profile))
	var content := VBoxContainer.new()
	var top_row := HBoxContainer.new()
	var identity := VBoxContainer.new()
	var action_column := VBoxContainer.new()
	var sign_button := Button.new()
	panel.add_child(content)
	content.add_child(top_row)
	top_row.add_child(identity)
	top_row.add_child(action_column)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_column.custom_minimum_size.x = 180.0

	identity.add_child(_label(
		"%s   |   %s" % [str(offer.sponsor_name).to_upper(), str(offer.profile)],
		&"SectionTitle"
	))
	var renewal_text := "Renewal offer" if bool(offer.renewal) else "New relationship"
	identity.add_child(_label(
		"%s   |   Relationship: %s"
		% [renewal_text, _relationship_label(int(offer.relationship))]
	))
	sign_button.text = "COMPARE OFFER"
	var already_signed := false
	for contract in team.get_active_sponsor_contracts():
		if str(contract.get("sponsor_id", "")) == str(offer.get("sponsor_id", "")):
			already_signed = true
	if already_signed:
		sign_button.text = "REVIEW CONTRACT"
	sign_button.tooltip_text = (
		"Recommended prestige level %d. Lower standing changes the offer value, but does not block negotiation."
		% int(offer.required_reputation)
	)
	sign_button.pressed.connect(_show_sponsor_comparison.bind(index, offer))
	action_column.add_child(sign_button)

	var metrics := GridContainer.new()
	metrics.columns = 3
	content.add_child(metrics)
	_add_metric(metrics, "GUARANTEED", "$%s" % _format_number(int(offer.guaranteed_value)))
	_add_metric(metrics, "EXPECTED", "$%s" % _format_number(int(offer.expected_value)))
	_add_metric(metrics, "MAXIMUM", "$%s" % _format_number(int(offer.maximum_value)))
	_add_metric(metrics, "PER EVENT", "$%s" % _format_number(int(offer.payment_per_race)))
	_add_metric(metrics, "OBJECTIVE CHANCE", "%d%%" % roundi(float(offer.objective_probability) * 100.0))
	_add_metric(metrics, "FAILURE PENALTY", "-$%s" % _format_number(int(offer.failure_penalty)))

	var objective_label := _label(
		"CAMPAIGN BRIEF\n%s\n%s\n%s\nCoverage: %d remaining race weekends"
		% [
			str(offer.interest_reason),
			SponsorManager.objective_description(offer),
			SponsorManager.benefit_description(offer),
			int(offer.contract_length)
		]
	)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(objective_label)
	offers_container.add_child(panel)


func _show_sponsor_comparison(index: int, offer: Dictionary) -> void:
	var team: Team = GameManager.team
	var benchmark: Dictionary = {}
	var offers := _active_offers(team)
	for other_index in offers.size():
		if other_index == index:
			continue
		var other := offers[other_index] as Dictionary
		if benchmark.is_empty() or int(other.get("expected_value", 0)) > int(benchmark.get("expected_value", 0)):
			benchmark = other
	var has_benchmark := not benchmark.is_empty()
	var current_title := str(benchmark.get("sponsor_name", "No alternate")).to_upper()
	var candidate_probability := roundi(float(offer.get("objective_probability", 0.0)) * 100.0)
	var benchmark_probability := roundi(float(benchmark.get("objective_probability", 0.0)) * 100.0)
	var metrics: Array = [
		_offer_money_metric("Guaranteed", int(benchmark.get("guaranteed_value", 0)), int(offer.get("guaranteed_value", 0)), has_benchmark),
		_offer_money_metric("Expected", int(benchmark.get("expected_value", 0)), int(offer.get("expected_value", 0)), has_benchmark),
		_offer_money_metric("Maximum", int(benchmark.get("maximum_value", 0)), int(offer.get("maximum_value", 0)), has_benchmark),
		_offer_money_metric("Per event", int(benchmark.get("payment_per_race", 0)), int(offer.get("payment_per_race", 0)), has_benchmark),
		_offer_percent_metric("Objective chance", benchmark_probability, candidate_probability, has_benchmark),
		_offer_money_metric("Failure exposure", int(benchmark.get("failure_penalty", 0)), int(offer.get("failure_penalty", 0)), has_benchmark, true),
	]
	var already_signed := false
	for contract in team.get_active_sponsor_contracts():
		if str(contract.get("sponsor_id", "")) == str(offer.get("sponsor_id", "")):
			already_signed = true
	var at_capacity := team.get_active_sponsor_contracts().size() >= team.get_sponsor_capacity()
	var is_best := not has_benchmark or int(offer.get("expected_value", 0)) >= int(benchmark.get("expected_value", 0))
	var recommendation := (
		"Best expected-value offer currently available. Confirm that its objective risk fits the race plan."
		if is_best else
		"Lower expected value than %s; choose it only if the objective or relationship better matches the team plan." % str(benchmark.get("sponsor_name", "the leading offer"))
	)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "SPONSOR DECISION",
		"title": str(offer.get("sponsor_name", "Sponsor offer")),
		"subtitle": "%s profile · %d-race coverage. Compared with the strongest alternate expected value." % [str(offer.get("profile", "PARTNERSHIP")), int(offer.get("contract_length", 0))],
		"current_title": current_title,
		"candidate_title": "THIS OFFER",
		"metrics": metrics,
		"upfront_cost": -int(offer.get("signing_bonus", 0)),
		"recurring_per_race": -int(offer.get("payment_per_race", 0)),
		"recurring_events": int(offer.get("contract_length", 0)),
		"action_enabled": not already_signed and not at_capacity,
		"disabled_reason": "This sponsor is already contracted." if already_signed else "All sponsor slots are filled." if at_capacity else "",
		"action_label": "Sign partnership",
		"recommendation": recommendation,
		"risk": "Failure exposure is $%s if the campaign objective is missed." % _format_number(int(offer.get("failure_penalty", 0))),
		"context": {"kind": "sponsor", "offer_index": index},
	})
	comparison_drawer.display(model)


func _offer_money_metric(label_text: String, current_value: int, candidate_value: int, has_current: bool, lower_is_better: bool = false) -> Dictionary:
	var delta := candidate_value - current_value
	var impact_delta := -delta if lower_is_better else delta
	return DecisionComparisonModel.metric(
		label_text,
		"$%s" % _format_number(current_value) if has_current else "--",
		"$%s" % _format_number(candidate_value),
		"%s$%s" % ["+" if delta > 0 else "-" if delta < 0 else "", _format_number(absi(delta))] if has_current else "New",
		_comparison_impact(impact_delta) if has_current else DecisionComparisonModel.IMPROVES
	)


func _offer_percent_metric(label_text: String, current_value: int, candidate_value: int, has_current: bool) -> Dictionary:
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(label_text, "%d%%" % current_value if has_current else "--", "%d%%" % candidate_value, "%+d%%" % delta if has_current else "New", _comparison_impact(delta) if has_current else DecisionComparisonModel.IMPROVES)


func _comparison_impact(delta: int) -> int:
	if delta > 0:
		return DecisionComparisonModel.IMPROVES
	if delta < 0:
		return DecisionComparisonModel.WORSENS
	return DecisionComparisonModel.NEUTRAL


func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) == "sponsor":
		_sign_offer(int(context.get("offer_index", -1)))


func _create_relationship_section(team: Team) -> void:
	if team.sponsor_relationships.is_empty():
		return
	var lines := PackedStringArray()
	for sponsor_id in team.sponsor_relationships:
		var relationship := int(team.sponsor_relationships[sponsor_id])
		if relationship != 0:
			lines.append("%s: %s (%+d)" % [
				_sponsor_name_for_id(str(sponsor_id), team),
				_relationship_label(relationship),
				relationship
			])
	if lines.is_empty():
		return
	var panel := PanelContainer.new()
	panel.add_child(_label("PADDOCK RELATIONSHIPS\n" + "\n".join(lines)))
	offers_container.add_child(panel)


func _sign_offer(index: int) -> void:
	var team := GameManager.team
	var cash_before := team.money
	var contract := SponsorManager.sign_offer(team, index)
	if contract.is_empty():
		GameManager.report_decision_outcome({
			"status": "error", "title": "Partnership not signed",
			"message": "The sponsor slot or offer is no longer available.",
			"action_label": "Review sponsors", "action_path": "res://scenes/pages/sponsors/sponsors.tscn",
		})
		return
	var signing_bonus := int(contract.signing_bonus)
	GameManager.add_team_money(signing_bonus)
	team.record_finance("Sponsor", signing_bonus, "%s signing bonus" % str(contract.sponsor_name))
	SponsorManager.adjust_relationship(team, str(contract.sponsor_id), 3)
	GameManager.save_game()
	show_sponsors()
	GameManager.report_decision_outcome({
		"title": "%s partnership signed" % str(contract.sponsor_name),
		"message": "$%s is guaranteed after each covered race." % _format_number(int(contract.payment_per_race)),
		"detail": "%d races · %s" % [int(contract.contract_length), SponsorManager.objective_description(contract)],
		"cash_delta": team.money - cash_before,
		"action_label": "View contract", "action_path": "res://scenes/pages/sponsors/sponsors.tscn",
	})


func _new_card(profile: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var accent: Color = PROFILE_COLORS.get(profile, Color("8f9bad"))
	style.bg_color = Color(0.055, 0.07, 0.10, 0.96)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add_metric(grid: GridContainer, title: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(190.0, 58.0)
	box.add_child(_label(title))
	box.add_child(_label(value, &"SectionTitle"))
	grid.add_child(box)


func _label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	if not variation.is_empty():
		label.theme_type_variation = variation
	return label


func _relationship_label(value: int) -> String:
	if value >= 50:
		return "Trusted partner"
	if value >= 20:
		return "Strong"
	if value > 0:
		return "Positive"
	if value <= -30:
		return "Damaged"
	if value < 0:
		return "Wary"
	return "New"


func _sponsor_name_for_id(sponsor_id: String, team: Team) -> String:
	for race_team in team.race_teams:
		for offer in race_team.sponsor_offers:
			if str(offer.sponsor_id) == sponsor_id:
				return str(offer.sponsor_name)
	var sponsor := SponsorCatalog.find_by_id(sponsor_id)
	return sponsor.sponsor_name if sponsor != null else sponsor_id.capitalize()


func _active_offers(team: Team) -> Array[Dictionary]:
	var race_team := team.get_active_race_team()
	return race_team.sponsor_offers if race_team != null else []


func _format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
