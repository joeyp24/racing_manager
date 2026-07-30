class_name ReputationManager
extends RefCounted

const MAX_HISTORY: int = 80
const LEVEL_THRESHOLDS: Array[int] = [
	0, 100, 220, 360, 520, 700, 900, 1120, 1360, 1620, 1900,
	2200, 2520, 2860, 3220, 3600, 4000, 4420, 4860, 5320, 5800,
	6300, 6820, 7360, 7920
]
const DIMENSION_LABELS: Dictionary = {
	"sporting_credibility": "Sporting credibility",
	"professionalism": "Professionalism",
	"commercial_appeal": "Commercial appeal"
}


static func defaults(team: Team = null) -> Dictionary:
	return {
		"momentum": 0,
		"sporting_credibility": 50,
		"professionalism": 50,
		"commercial_appeal": 50,
		"history": [],
		"last_season_change": 0,
		"season_start_xp": team.reputation if team != null else 0
	}


static func ensure_state(team: Team) -> Dictionary:
	if team.reputation_state == null:
		team.reputation_state = {}
	var fallback := defaults(team)
	for key in fallback:
		if not team.reputation_state.has(key) or team.reputation_state[key] == null:
			var value: Variant = fallback[key]
			team.reputation_state[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return team.reputation_state


static func migrate_legacy_xp(team: Team) -> void:
	var old_level := maxi(1, floori(float(team.reputation) / float(Team.XP_PER_LEVEL)) + 1)
	var old_progress := float(team.reputation % Team.XP_PER_LEVEL) / float(Team.XP_PER_LEVEL)
	var start := get_level_start_xp(old_level)
	var span := get_level_span(old_level)
	team.reputation = start + roundi(float(span) * old_progress)
	var state := ensure_state(team)
	state.season_start_xp = team.reputation


static func get_level_for_xp(xp: int) -> int:
	var safe_xp := maxi(0, xp)
	for index in LEVEL_THRESHOLDS.size() - 1:
		if safe_xp < LEVEL_THRESHOLDS[index + 1]:
			return index + 1
	var extra_span := LEVEL_THRESHOLDS[-1] - LEVEL_THRESHOLDS[-2]
	return LEVEL_THRESHOLDS.size() + floori(float(safe_xp - LEVEL_THRESHOLDS[-1]) / float(extra_span))


static func get_level_start_xp(level: int) -> int:
	var safe_level := maxi(1, level)
	if safe_level <= LEVEL_THRESHOLDS.size():
		return LEVEL_THRESHOLDS[safe_level - 1]
	var extra_span := LEVEL_THRESHOLDS[-1] - LEVEL_THRESHOLDS[-2]
	return LEVEL_THRESHOLDS[-1] + (safe_level - LEVEL_THRESHOLDS.size()) * extra_span


static func get_level_span(level: int) -> int:
	return get_level_start_xp(level + 1) - get_level_start_xp(level)


static func get_tier_name(level: int) -> String:
	if level <= 2:
		return "Unknown"
	if level <= 5:
		return "Local Name"
	if level <= 9:
		return "Regional Contender"
	if level <= 13:
		return "National Presence"
	if level <= 17:
		return "Championship Organization"
	if level <= 21:
		return "Elite Team"
	return "Motorsport Icon"


static func get_tier_description(level: int) -> String:
	if level <= 2:
		return "Building an identity and proving the team belongs."
	if level <= 5:
		return "Recognized by local fans, drivers and commercial partners."
	if level <= 9:
		return "A credible regional operation with a growing paddock profile."
	if level <= 13:
		return "A nationally relevant team capable of attracting established talent."
	if level <= 17:
		return "A proven organization expected to compete for major championships."
	if level <= 21:
		return "One of the sport's elite destinations for talent and investment."
	return "A defining name in motorsport history."


static func apply_race_result(team: Team, result: RaceResult) -> Dictionary:
	var expected := result.expected_finishing_position
	if expected <= 0:
		expected = result.starting_position if result.starting_position > 0 else maxi(1, result.field_size / 2)
	var field_size := maxi(1, result.field_size)
	var expectation_delta := expected - result.finishing_position
	var finish_percentile := clampf(
		float(field_size - result.finishing_position + 1) / float(field_size),
		0.0,
		1.0
	)
	var series := SeriesCatalog.get_series(result.race.series_id if result.race != null else team.current_series_id)
	var importance := sqrt(float(series.get("sponsor_prestige_multiplier", 1.0)))
	var required_level := int(series.get("required_level", 1))
	var diminishing := 0.55 if team.get_reputation_level() >= required_level + 5 else 1.0
	var base_xp := 2.0 + maxf(0.0, float(expectation_delta)) * 1.35 + finish_percentile * 4.0
	if result.finishing_position == 1:
		base_xp += 5.0
	elif result.finishing_position <= 3:
		base_xp += 2.5
	var prestige_gain := maxi(1, roundi(base_xp * importance * diminishing))

	var status := _player_status(result)
	var finished := status != "Retired" and result.finishing_position > 0
	var sporting_delta := clampi(
		expectation_delta * 2
		+ (4 if result.finishing_position == 1 else (2 if result.finishing_position <= 3 else 0)),
		-8,
		12
	)
	var professionalism_delta := 1 if finished else -3
	if result.cheating_penalty > 0:
		professionalism_delta -= 8
	if not result.penalties.is_empty():
		professionalism_delta -= 4
	var commercial_delta := clampi(
		roundi(float(result.fans_earned) / 30.0)
		+ (3 if result.finishing_position == 1 else (1 if result.finishing_position <= 5 else 0)),
		0,
		7
	)
	var reason := (
		"Finished P%d against a P%d expectation at %s"
		% [
			result.finishing_position,
			expected,
			result.race.race_name if result.race != null else "the race"
		]
	)
	var changes := apply_changes(
		team,
		prestige_gain,
		sporting_delta,
		professionalism_delta,
		commercial_delta,
		reason,
		"Race"
	)
	result.reputation_earned = prestige_gain
	result.reputation_changes = changes
	return changes


static func apply_changes(
	team: Team,
	prestige_xp: int,
	sporting_delta: int,
	professionalism_delta: int,
	commercial_delta: int,
	reason: String,
	category: String
) -> Dictionary:
	var state := ensure_state(team)
	var safe_prestige := maxi(0, prestige_xp)
	if safe_prestige > 0:
		team.add_reputation_xp(safe_prestige)
	state.sporting_credibility = clampi(int(state.sporting_credibility) + sporting_delta, 0, 100)
	state.professionalism = clampi(int(state.professionalism) + professionalism_delta, 0, 100)
	state.commercial_appeal = clampi(int(state.commercial_appeal) + commercial_delta, 0, 100)
	var momentum_change := sporting_delta + roundi(float(commercial_delta + professionalism_delta) * 0.25)
	state.momentum = clampi(roundi(float(state.momentum) * 0.70) + momentum_change, -100, 100)
	var entry := {
		"season": team.current_season_year,
		"day": team.current_season_day,
		"category": category,
		"reason": reason,
		"prestige_xp": safe_prestige,
		"sporting_credibility": sporting_delta,
		"professionalism": professionalism_delta,
		"commercial_appeal": commercial_delta,
		"momentum": int(state.momentum)
	}
	(state.history as Array).push_front(entry)
	if (state.history as Array).size() > MAX_HISTORY:
		(state.history as Array).resize(MAX_HISTORY)
	team.reputation_state = state
	team.emit_changed()
	return entry


static func apply_event(
	team: Team,
	dimension: String,
	amount: int,
	reason: String,
	prestige_xp: int = 0,
	category: String = "Team"
) -> Dictionary:
	var sporting := amount if dimension == "sporting_credibility" else 0
	var professional := amount if dimension == "professionalism" else 0
	var commercial := amount if dimension == "commercial_appeal" else 0
	return apply_changes(team, prestige_xp, sporting, professional, commercial, reason, category)


static func apply_sponsor_outcome(team: Team, success: bool, sponsor_name: String) -> void:
	if success:
		apply_changes(
			team, 3, 0, 3, 4,
			"Delivered the campaign objective for %s" % sponsor_name,
			"Sponsor"
		)
	else:
		apply_changes(
			team, 0, 0, -5, -4,
			"Failed to deliver the campaign objective for %s" % sponsor_name,
			"Sponsor"
		)


static func apply_season_result(team: Team, finishing_position: int) -> void:
	var series := SeriesCatalog.get_series(team.current_series_id)
	var importance := sqrt(float(series.get("sponsor_prestige_multiplier", 1.0)))
	var prestige_gain := 0
	var sporting_gain := 0
	if finishing_position == 1:
		prestige_gain = roundi(45.0 * importance)
		sporting_gain = 10
	elif finishing_position <= 3:
		prestige_gain = roundi(22.0 * importance)
		sporting_gain = 5
	elif finishing_position <= 5:
		prestige_gain = roundi(10.0 * importance)
		sporting_gain = 2
	if prestige_gain > 0:
		apply_changes(
			team, prestige_gain, sporting_gain, 2, 2,
			"Finished P%d in the %s championship" % [finishing_position, str(series.get("name", "series"))],
			"Season"
		)
	var state := ensure_state(team)
	state.last_season_change = team.reputation - int(state.season_start_xp)
	state.season_start_xp = team.reputation


static func advance_days(team: Team, elapsed_days: int) -> void:
	var weeks := floori(float(maxi(0, elapsed_days)) / 7.0)
	if weeks <= 0:
		return
	var state := ensure_state(team)
	state.momentum = roundi(float(state.momentum) * pow(0.82, weeks))
	team.reputation_state = state


static func get_next_unlock(team: Team) -> String:
	var level := team.get_reputation_level()
	var unlocks := [
		{"level": 3, "text": "Local commercial partners take notice"},
		{"level": 6, "text": "Regional talent treats the team as a credible destination"},
		{"level": 10, "text": "National manufacturers begin monitoring the organization"},
		{"level": 14, "text": "Championship-calibre staff and drivers become easier to negotiate with"},
		{"level": 18, "text": "Elite partners and top-series opportunities become available"},
		{"level": 22, "text": "Legacy invitations and icon-level recognition unlock"}
	]
	for unlock in unlocks:
		if level < int(unlock.level):
			return "Level %d: %s" % [int(unlock.level), str(unlock.text)]
	return "All prestige milestones unlocked"


static func get_interested_organizations(team: Team) -> Array[String]:
	var state := ensure_state(team)
	var organizations: Array[String] = []
	if int(state.commercial_appeal) >= 60:
		organizations.append("National consumer brands")
	else:
		organizations.append("Regional commercial partners")
	if int(state.sporting_credibility) >= 65:
		organizations.append("Performance manufacturers")
	else:
		organizations.append("Development-focused suppliers")
	if int(state.professionalism) >= 65:
		organizations.append("Established veteran drivers")
	elif int(state.professionalism) < 35:
		organizations.append("Risk-tolerant independent backers")
	else:
		organizations.append("Emerging driver prospects")
	if team.get_reputation_level() >= 14:
		organizations.append("Championship-level personnel")
	return organizations


static func get_dimension(team: Team, key: String) -> int:
	return int(ensure_state(team).get(key, 50))


static func get_momentum_label(team: Team) -> String:
	var momentum := int(ensure_state(team).momentum)
	if momentum >= 20:
		return "Surging"
	if momentum >= 5:
		return "Rising"
	if momentum <= -20:
		return "In crisis"
	if momentum <= -5:
		return "Cooling"
	return "Stable"


static func format_history_entry(entry: Dictionary) -> String:
	var changes := PackedStringArray()
	if int(entry.get("prestige_xp", 0)) != 0:
		changes.append("%+d Prestige XP" % int(entry.prestige_xp))
	for key in DIMENSION_LABELS:
		var amount := int(entry.get(key, 0))
		if amount != 0:
			changes.append("%+d %s" % [amount, str(DIMENSION_LABELS[key])])
	return "Day %d | %s\n%s" % [
		int(entry.get("day", 0)),
		str(entry.get("reason", "Team standing changed")),
		"  |  ".join(changes) if not changes.is_empty() else "Momentum updated"
	]


static func _player_status(result: RaceResult) -> String:
	if result.finishing_position > 0 and result.finishing_position <= result.standings.size():
		return str((result.standings[result.finishing_position - 1] as Dictionary).get("status", "Finished"))
	return "Retired"
