extends Control

@onready var tier_label: Label = %tier_label
@onready var tier_description: Label = %tier_description
@onready var prestige_progress: ProgressBar = %prestige_progress
@onready var prestige_detail: Label = %prestige_detail
@onready var momentum_label: Label = %momentum_label
@onready var momentum_detail: Label = %momentum_detail
@onready var sporting_bar: ProgressBar = %sporting_bar
@onready var professionalism_bar: ProgressBar = %professionalism_bar
@onready var commercial_bar: ProgressBar = %commercial_bar
@onready var sporting_detail: Label = %sporting_detail
@onready var professionalism_detail: Label = %professionalism_detail
@onready var commercial_detail: Label = %commercial_detail
@onready var season_trend: Control = %season_trend
@onready var merchandise_label: Label = %merchandise_label
@onready var history_label: Label = %history_label
@onready var unlock_label: Label = %unlock_label
@onready var organizations_label: Label = %organizations_label
@onready var relationships_label: Label = %relationships_label
@onready var markets_label: Label = %markets_label
@onready var achievements_label: Label = %achievements_label
@onready var risks_label: Label = %risks_label


func _ready() -> void:
	render_reputation()


func render_reputation() -> void:
	var team := GameManager.team
	if team == null:
		tier_label.text = "No team loaded"
		return
	CareerExpansionManager.ensure_state(team)
	var state := ReputationManager.ensure_state(team)
	var level := team.get_reputation_level()
	var tier := team.get_reputation_tier()
	tier_label.text = "%s  |  PRESTIGE LEVEL %d" % [tier.to_upper(), level]
	tier_description.text = ReputationManager.get_tier_description(level)
	prestige_progress.max_value = maxf(1.0, float(team.get_level_xp_span()))
	prestige_progress.value = float(team.get_current_level_xp())
	prestige_detail.text = "%s / %s XP toward Level %d  |  Career total %s XP" % [
		String.num_int64(team.get_current_level_xp()),
		String.num_int64(team.get_level_xp_span()),
		level + 1,
		String.num_int64(team.reputation)
	]
	var momentum := int(state.momentum)
	momentum_label.text = "%s  %s%d" % [
		ReputationManager.get_momentum_label(team).to_upper(),
		"+" if momentum >= 0 else "",
		momentum
	]
	momentum_detail.text = (
		"Short-term paddock sentiment naturally returns toward stable between major moments.\n"
		+ "Last season: %+d Prestige XP"
	) % int(state.last_season_change)

	_set_dimension(
		sporting_bar,
		sporting_detail,
		int(state.sporting_credibility),
		"Results versus expectations, championships and competitive milestones."
	)
	_set_dimension(
		professionalism_bar,
		professionalism_detail,
		int(state.professionalism),
		"Reliability, conduct, contracts, stewarding and partner delivery."
	)
	_set_dimension(
		commercial_bar,
		commercial_detail,
		int(state.commercial_appeal),
		"Fans, marketable drivers, media choices, sponsors and activations."
	)
	season_trend.call("configure", state.history, state, team.current_season_year)
	_render_merchandise(team)
	_render_history(state)
	unlock_label.text = ReputationManager.get_next_unlock(team)
	organizations_label.text = "\n".join(ReputationManager.get_interested_organizations(team))
	_render_sponsor_relationships(team)
	_render_markets(team)
	_render_achievements(team)
	_render_risks(team, state)


func _set_dimension(
	progress_bar: ProgressBar,
	detail_label: Label,
	value: int,
	description: String
) -> void:
	progress_bar.value = value
	detail_label.text = "%d / 100\n%s" % [value, description]


func _render_merchandise(team: Team) -> void:
	var merchandise := team.career_state.merchandise as Dictionary
	var weekly_demand := CareerExpansionManager.calculate_weekly_merchandise_demand(team)
	var price := int(merchandise.price)
	var stock := int(merchandise.stock)
	var sales_capacity := mini(stock, weekly_demand)
	merchandise_label.text = (
		"Projected weekly demand: %d units  |  Current stock: %d\n"
		+ "Potential weekly revenue: $%s  |  Stock-limited revenue: $%s\n"
		+ "Last weekly sales: %d units / $%s  |  Lifetime revenue: $%s\n"
		+ "Prestige level, commercial appeal, fans, momentum and Marketing directly increase demand."
	) % [
		weekly_demand,
		stock,
		String.num_int64(weekly_demand * price),
		String.num_int64(sales_capacity * price),
		int(merchandise.last_weekly_units),
		String.num_int64(int(merchandise.last_weekly_revenue)),
		String.num_int64(int(merchandise.lifetime_revenue))
	]


func _render_history(state: Dictionary) -> void:
	var lines := PackedStringArray()
	var history := state.history as Array
	for index in mini(10, history.size()):
		lines.append(ReputationManager.format_history_entry(history[index] as Dictionary))
	history_label.text = (
		"\n\n".join(lines)
		if not lines.is_empty()
		else "No reputation events yet. Race performance, media and commercial decisions will appear here."
	)


func _render_sponsor_relationships(team: Team) -> void:
	SponsorManager.ensure_state(team)
	var rows: Array[Dictionary] = []
	for sponsor_id in team.sponsor_relationships:
		rows.append({
			"name": str(sponsor_id).replace("_", " ").capitalize(),
			"score": int(team.sponsor_relationships[sponsor_id])
		})
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return absi(int(a.score)) > absi(int(b.score))
	)
	var lines := PackedStringArray()
	for index in mini(4, rows.size()):
		var row := rows[index]
		var score := int(row.score)
		lines.append("%s  |  %s%d" % [
			str(row.name),
			"+" if score >= 0 else "",
			score
		])
	relationships_label.text = (
		"\n".join(lines)
		if not lines.is_empty()
		else "No sponsor relationship history yet."
	)


func _render_markets(team: Team) -> void:
	var markets := (team.career_state.international as Dictionary).markets as Dictionary
	var rows: Array[Dictionary] = []
	for region in markets:
		var data := markets[region] as Dictionary
		rows.append({
			"region": str(region),
			"score": int(data.get("reputation", 0)),
			"fans": int(data.get("fans", 0))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	var lines := PackedStringArray()
	for index in mini(3, rows.size()):
		var row := rows[index]
		lines.append("%s  |  Standing %d  |  %s fans" % [
			str(row.region),
			int(row.score),
			String.num_int64(int(row.fans))
		])
	markets_label.text = "\n".join(lines) if not lines.is_empty() else "No international market presence yet."


func _render_achievements(team: Team) -> void:
	var lines := PackedStringArray()
	var awards := team.career_state.awards as Array
	for index in mini(4, awards.size()):
		var award := awards[index] as Dictionary
		lines.append("Season %d  |  %s" % [int(award.season), str(award.award)])
	if team.last_season_position > 0:
		lines.append("Latest championship finish  |  P%d" % team.last_season_position)
	achievements_label.text = "\n".join(lines) if not lines.is_empty() else "No major achievements recorded yet."


func _render_risks(team: Team, state: Dictionary) -> void:
	var risks := PackedStringArray()
	if int(state.momentum) <= -10:
		risks.append("Negative momentum is cooling paddock interest.")
	if int(state.professionalism) < 40:
		risks.append("Low professionalism is weakening renewals and driver confidence.")
	if int(state.commercial_appeal) < 40:
		risks.append("Commercial appeal is suppressing sponsor terms and merchandise demand.")
	if int(state.sporting_credibility) < 40:
		risks.append("Sporting credibility is below the standard expected at this level.")
	var merchandise := team.career_state.merchandise as Dictionary
	if int(merchandise.stock) < CareerExpansionManager.calculate_weekly_merchandise_demand(team):
		risks.append("Merchandise stock is below projected weekly demand.")
	risks_label.text = "\n".join(risks) if not risks.is_empty() else "No active reputation risks."
