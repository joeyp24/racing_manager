extends Control

const VIEWS: Array[String] = ["Decision Center", "Board & Story", "People", "Car & R&D", "Operations", "World", "Stats & Settings"]
const INBOX_CATEGORIES: Array[String] = ["All categories", "Board", "Championship", "Driver", "Engineering", "Headquarters", "Manufacturer", "Medical", "Media", "Paddock", "Regulations", "Rivalry", "Scouting", "Sponsor", "Stewarding", "Testing"]
const INBOX_STATUSES: Array[String] = ["Needs action", "Unread", "Resolved", "All messages"]

@onready var content: VBoxContainer = %content
@onready var summary: Label = %Summary
@onready var mark_read_button: Button = %mark_read_button
@onready var category_filter: OptionButton = %category_filter
@onready var status_filter: OptionButton = %status_filter
@onready var decision_workspace: HSplitContainer = %DecisionWorkspace
@onready var legacy_scroll: ScrollContainer = %LegacyScroll
@onready var decision_queue: VBoxContainer = %decision_queue
@onready var decision_detail: VBoxContainer = %decision_detail
@onready var queue_summary: Label = %queue_summary
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer
@onready var decision_button: Button = %decision_button
@onready var board_button: Button = %board_button
@onready var people_button: Button = %people_button
@onready var car_button: Button = %car_button
@onready var operations_button: Button = %operations_button
@onready var world_button: Button = %world_button
@onready var settings_button: Button = %settings_button

var view_buttons: Array[Button] = []
var selected_view: int = 0
var selected_decision_id: String = ""
var pending_receipt: Dictionary = {}


func _ready() -> void:
	view_buttons = [decision_button, board_button, people_button, car_button, operations_button, world_button, settings_button]
	for index in view_buttons.size():
		view_buttons[index].pressed.connect(_select_view.bind(index))
	for category in INBOX_CATEGORIES:
		category_filter.add_item(category)
	for status in INBOX_STATUSES:
		status_filter.add_item(status)
	category_filter.item_selected.connect(_on_inbox_filter_selected)
	status_filter.item_selected.connect(_on_inbox_filter_selected)
	mark_read_button.pressed.connect(_mark_all_read)
	comparison_drawer.action_requested.connect(_on_comparison_action)
	_render()


func _select_view(index: int) -> void:
	selected_view = clampi(index, 0, view_buttons.size() - 1)
	_render()


func _on_inbox_filter_selected(_index: int) -> void:
	_render()


func _render() -> void:
	for child in content.get_children():
		child.queue_free()
	if GameManager.team == null:
		decision_workspace.visible = false
		legacy_scroll.visible = true
		_add_section("NO CAREER LOADED", "Start or load a career to use Career HQ.")
		return
	var state := CareerExpansionManager.ensure_state(GameManager.team)
	var unread := CareerExpansionManager.get_unread_count(GameManager.team)
	summary.text = "Season %d · Day %d · %d unread · Board confidence %d%%" % [GameManager.team.current_season_year, GameManager.team.current_season_day, unread, int(state.board.confidence)]
	mark_read_button.text = "Mark All Read (%d)" % unread
	for index in view_buttons.size():
		view_buttons[index].button_pressed = index == selected_view
	decision_workspace.visible = selected_view == 0
	legacy_scroll.visible = selected_view != 0
	mark_read_button.visible = selected_view == 0
	match selected_view:
		0: _render_decision_center(state)
		1: _render_board(state)
		2: _render_people(state)
		3: _render_car(state)
		4: _render_operations(state)
		5: _render_world(state)
		_: _render_stats_settings(state)


func _render_decision_center(state: Dictionary) -> void:
	_clear(decision_queue)
	_clear(decision_detail)
	var filtered_items: Array[Dictionary] = []
	for value in state.inbox:
		var candidate := value as Dictionary
		if _matches_inbox_filters(candidate):
			filtered_items.append(candidate)
	filtered_items.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_rank := _priority_rank(str(first.get("priority", "Low")))
		var second_rank := _priority_rank(str(second.get("priority", "Low")))
		if first_rank != second_rank:
			return first_rank > second_rank
		return int(first.get("deadline", 9999)) < int(second.get("deadline", 9999))
	)
	var pending := CareerExpansionManager.get_pending_decisions(GameManager.team)
	var due_soon := 0
	for item in pending:
		if int(item.get("deadline", 9999)) <= GameManager.team.current_season_day + 7:
			due_soon += 1
	queue_summary.text = "%d action%s open · %d due within seven days · %d shown" % [
		pending.size(), "" if pending.size() == 1 else "s", due_soon, filtered_items.size(),
	]
	if filtered_items.is_empty():
		var empty := Label.new()
		empty.text = "No messages match these filters."
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		decision_queue.add_child(empty)
		selected_decision_id = ""
	else:
		var selected_is_visible := filtered_items.any(func(item: Dictionary) -> bool: return str(item.get("id", "")) == selected_decision_id)
		if not selected_is_visible:
			selected_decision_id = str(filtered_items[0].get("id", ""))
		for item in filtered_items:
			decision_queue.add_child(_decision_queue_button(item))
	_render_decision_detail(state)


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _decision_queue_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Decision_%s" % str(item.get("id", "item"))
	button.toggle_mode = true
	button.button_pressed = str(item.get("id", "")) == selected_decision_id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var status := "RESOLVED" if bool(item.get("resolved", false)) else ("UNREAD" if not bool(item.get("read", false)) else str(item.get("priority", "Normal")).to_upper())
	button.text = "%s · %s\n%s\n%s" % [
		str(item.get("category", "Career")).to_upper(), status,
		str(item.get("subject", "Career update")), _deadline_text(item).trim_prefix(" · "),
	]
	button.tooltip_text = str(item.get("body", ""))
	button.pressed.connect(_select_decision.bind(str(item.get("id", ""))))
	return button


func _select_decision(item_id: String) -> void:
	selected_decision_id = item_id
	CareerExpansionManager.mark_inbox_item_read(GameManager.team, item_id)
	GameManager.save_game()
	_render()


func _render_decision_detail(state: Dictionary) -> void:
	var item := CareerExpansionManager.get_inbox_item(GameManager.team, selected_decision_id)
	if item.is_empty():
		_render_decision_overview(state)
		return
	var title_row := HBoxContainer.new()
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eyebrow := Label.new()
	eyebrow.text = "%s · %s" % [str(item.get("category", "Career")).to_upper(), _decision_scope(item).to_upper()]
	eyebrow.theme_type_variation = &"EyebrowLabel"
	identity.add_child(eyebrow)
	var title := Label.new()
	title.text = str(item.get("subject", "Career decision"))
	title.theme_type_variation = &"PageTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(title)
	title_row.add_child(identity)
	var status := Label.new()
	status.text = "RESOLVED" if bool(item.get("resolved", false)) else str(item.get("priority", "Normal")).to_upper()
	status.theme_type_variation = &"SuccessLabel" if bool(item.get("resolved", false)) else &"DangerLabel" if str(item.get("priority", "")) == "High" else &"WarningLabel"
	title_row.add_child(status)
	decision_detail.add_child(title_row)

	var timing := Label.new()
	timing.text = "RECEIVED · Season %d, day %d    DEADLINE · %s%s" % [
		int(item.get("season", 0)), int(item.get("day", 0)),
		CalendarCatalog.format_day(int(item.get("deadline", GameManager.team.current_season_day))),
		_deadline_text(item),
	]
	timing.theme_type_variation = &"MutedLabel"
	timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_detail.add_child(timing)

	var body := Label.new()
	body.text = str(item.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_detail.add_child(body)

	var why_panel := PanelContainer.new()
	why_panel.theme_type_variation = &"CardPanel"
	var why := Label.new()
	why.text = "WHY THIS REQUIRES ATTENTION\n%s" % str(item.get("why_changed", "New career information arrived."))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why_panel.add_child(why)
	decision_detail.add_child(why_panel)

	if bool(item.get("resolved", false)):
		var outcome := Label.new()
		outcome.text = "RECORDED OUTCOME · %s" % str(item.get("selected", "Filed"))
		outcome.theme_type_variation = &"SuccessLabel"
		decision_detail.add_child(outcome)
	else:
		var choices_title := Label.new()
		choices_title.text = "AVAILABLE RESPONSES"
		choices_title.theme_type_variation = &"SectionTitle"
		decision_detail.add_child(choices_title)
		var choices := item.get("choices", []) as Array
		for index in choices.size():
			decision_detail.add_child(_decision_choice_card(item, index, choices[index] as Dictionary))

	var action_path := str(item.get("action_path", ""))
	if action_path.is_empty():
		action_path = _category_action_path(str(item.get("category", "")))
	if not action_path.is_empty():
		var open_button := Button.new()
		open_button.text = "Open affected area"
		open_button.pressed.connect(GameManager.load_page.bind(action_path))
		decision_detail.add_child(open_button)
	_add_time_advance_card()


func _decision_choice_card(item: Dictionary, index: int, choice: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = str(choice.get("label", "Respond"))
	title.theme_type_variation = &"BodyStrong"
	copy.add_child(title)
	var consequence := Label.new()
	consequence.text = _choice_consequence(choice)
	consequence.theme_type_variation = &"MutedLabel"
	consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(consequence)
	var review := Button.new()
	review.text = "Review choice"
	review.theme_type_variation = &"PrimaryButton"
	review.pressed.connect(_review_inbox_choice.bind(str(item.get("id", "")), index))
	row.add_child(review)
	return panel


func _render_decision_overview(state: Dictionary) -> void:
	var title := Label.new()
	title.text = "Decision Center"
	title.theme_type_variation = &"PageTitle"
	decision_detail.add_child(title)
	var briefing := Label.new()
	briefing.text = _weekly_briefing(state)
	briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_detail.add_child(briefing)
	_add_time_advance_card()


func _add_time_advance_card() -> void:
	var next_race := RaceManager.get_next_race(GameManager.team)
	var target_day := int(next_race.schedule_day) if next_race != null else CareerExpansionManager.SEASON_END_DAY
	var preview := RaceManager.get_advance_preview(target_day)
	var impacts := CareerExpansionManager.get_time_advance_impacts(GameManager.team, target_day)
	var panel := PanelContainer.new()
	panel.name = "TimeAdvanceCard"
	panel.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = "NEXT CHECKPOINT · %s" % CalendarCatalog.format_day(target_day)
	title.theme_type_variation = &"SectionTitle"
	copy.add_child(title)
	var detail := Label.new()
	detail.text = "%d days · %d events · %d projects complete · %d decisions and sponsor actions expire" % [
		int(preview.get("days", 0)), (preview.get("events", []) as Array).size(),
		(impacts.completions as Array).size(),
		(impacts.expiring_decisions as Array).size() + (impacts.expiring_activations as Array).size(),
	]
	detail.theme_type_variation = &"MutedLabel"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(detail)
	var review := Button.new()
	review.name = "ReviewTimeAdvance"
	review.text = "Review time advance"
	review.theme_type_variation = &"PrimaryButton"
	review.pressed.connect(_review_time_advance.bind(target_day))
	row.add_child(review)
	decision_detail.add_child(panel)


func _choice_consequence(choice: Dictionary) -> String:
	var parts: Array[String] = []
	var cost := int(choice.get("cost", 0))
	if cost > 0:
		parts.append("Cash -$%s" % _format_number(cost))
	for key in (choice.get("effects", {}) as Dictionary):
		var amount := int((choice.effects as Dictionary)[key])
		parts.append("%s %+d" % [str(key).replace("_", " ").capitalize(), amount])
	return " · ".join(parts) if not parts.is_empty() else "No immediate numerical effect; the response is recorded in career history."


func _decision_scope(item: Dictionary) -> String:
	var race_team_id := str(item.get("race_team_id", ""))
	if not race_team_id.is_empty():
		var race_team := GameManager.team.get_race_team_by_id(race_team_id)
		if race_team != null:
			return race_team.team_name
	return "Organization-wide"


func _category_action_path(category: String) -> String:
	return {
		"Driver": "res://scenes/pages/drivers/drivers.tscn",
		"Medical": "res://scenes/pages/drivers/drivers.tscn",
		"Engineering": "res://scenes/pages/engineering/engineering.tscn",
		"Headquarters": "res://scenes/pages/departments/departments.tscn",
		"Sponsor": "res://scenes/pages/sponsors/sponsors.tscn",
		"Championship": "res://scenes/pages/championship/championship.tscn",
		"Scouting": "res://scenes/pages/scouting/scouting.tscn",
		"Board": "res://scenes/pages/reputation/reputation.tscn",
	}.get(category, "")


func _render_inbox(state: Dictionary) -> void:
	_add_section("WEEKLY BRIEFING", _weekly_briefing(state))
	var news_lines := PackedStringArray()
	var shown_news := 0
	for story_value in state.news_feed:
		if shown_news >= 6:
			break
		var story := story_value as Dictionary
		if category_filter.selected > 0 and str(story.get("category", "")) != INBOX_CATEGORIES[category_filter.selected]:
			continue
		var marker := "TOP STORY" if int(story.get("importance", 1)) >= 3 else str(story.get("category", "Paddock")).to_upper()
		news_lines.append("%s · %s\n%s" % [marker, story.get("headline", "Update"), story.get("body", "")])
		shown_news += 1
	_add_section("WEEKLY PADDOCK FEED", "\n\n".join(news_lines) if not news_lines.is_empty() else "Results, transfers, upgrades, rumors, sponsor reactions and championship turning points will appear here.")
	var filtered_items: Array[Dictionary] = []
	for value in state.inbox:
		var candidate := value as Dictionary
		if _matches_inbox_filters(candidate):
			filtered_items.append(candidate)
	filtered_items.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_rank := _priority_rank(str(first.get("priority", "Low")))
		var second_rank := _priority_rank(str(second.get("priority", "Low")))
		if first_rank != second_rank:
			return first_rank > second_rank
		return int(first.get("deadline", 9999)) < int(second.get("deadline", 9999))
	)
	var shown := 0
	for value in filtered_items:
		if shown >= 14:
			break
		var item := value as Dictionary
		var actions: Array[Dictionary] = []
		var choices := item.get("choices", []) as Array
		if not bool(item.get("resolved", false)):
			for index in choices.size():
				var choice := choices[index] as Dictionary
				var cost_text := " · $%s" % int(choice.get("cost", 0)) if int(choice.get("cost", 0)) > 0 else ""
				actions.append({"label":str(choice.get("label", "Respond")) + cost_text, "call":_resolve_mail.bind(str(item.id), index)})
		var status := "RESOLVED · %s" % item.get("selected", "Filed") if bool(item.get("resolved", false)) else ("ACTION REQUIRED" if not choices.is_empty() else "NEWS")
		var deadline_text := _deadline_text(item)
		var context := "PRIORITY %s · %s · Season %d, day %d" % [str(item.get("priority", "Low")).to_upper(), status, int(item.get("season", 0)), int(item.get("day", 0))]
		_add_section("%s  /  %s" % [str(item.get("category", "Team")).to_upper(), item.get("subject", "Update")], "%s\n\n%s%s\nWHY THIS CHANGED · %s" % [item.get("body", ""), context, deadline_text, item.get("why_changed", "New information arrived.")], actions)
		shown += 1
	if shown == 0:
		_add_section("INBOX CLEAR", "No messages yet. Race weekends, projects and season changes will generate team news.")
	var notices := state.notifications as Array
	var lines := PackedStringArray()
	for index in mini(8, notices.size()):
		var notice := notices[index] as Dictionary
		lines.append("%s  %s — %s" % ["●" if not bool(notice.get("read", false)) else "○", notice.get("title", "Update"), notice.get("body", "")])
	_add_section("NOTIFICATION CENTER", "\n".join(lines) if not lines.is_empty() else "No notifications.", [{"label":"Clear read notices", "call":_clear_read_notices}])


func _weekly_briefing(state: Dictionary) -> String:
	var action_count := 0
	var due_soon := 0
	var unread := 0
	var priorities: Array[Dictionary] = []
	for value in state.inbox:
		var item := value as Dictionary
		if not bool(item.get("read", false)):
			unread += 1
		if bool(item.get("resolved", false)) or (item.get("choices", []) as Array).is_empty():
			continue
		action_count += 1
		if int(item.get("deadline", 9999)) <= GameManager.team.current_season_day + 7:
			due_soon += 1
		priorities.append(item)
	priorities.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_rank := _priority_rank(str(first.get("priority", "Low")))
		var second_rank := _priority_rank(str(second.get("priority", "Low")))
		if first_rank != second_rank:
			return first_rank > second_rank
		return int(first.get("deadline", 9999)) < int(second.get("deadline", 9999))
	)
	var priority_lines := PackedStringArray()
	for index in mini(3, priorities.size()):
		var item := priorities[index]
		priority_lines.append("• %s · %s" % [item.get("subject", "Decision"), _deadline_text(item).strip_edges().trim_prefix("· ")])
	var finance := CareerExpansionManager.update_finance_forecast(GameManager.team)
	var reputation_state := ReputationManager.ensure_state(GameManager.team)
	var latest_change := "No reputation movement recorded yet."
	if not (reputation_state.history as Array).is_empty():
		latest_change = str((reputation_state.history[0] as Dictionary).get("reason", latest_change))
	var next_event := RaceManager.get_next_race(GameManager.team)
	var next_event_text := "%s · day %d" % [next_event.race_name, next_event.schedule_day] if next_event != null else "No event currently scheduled"
	return (
		"THIS WEEK · %d decisions · %d due within seven days · %d unread\n"
		+ "NEXT EVENT · %s\n"
		+ "BOARD · %d%% confidence · %d%% job security\n"
		+ "CASH OUTLOOK · $%s projected at season end\n\n"
		+ "TOP PRIORITIES\n%s\n\n"
		+ "WHY THE OUTLOOK CHANGED · %s"
	) % [action_count, due_soon, unread, next_event_text, int(state.board.confidence), int(state.board.job_security), String.num_int64(int(finance.get("season_end_cash", GameManager.team.money))), "\n".join(priority_lines) if not priority_lines.is_empty() else "No decisions currently require attention.", latest_change]


func _matches_inbox_filters(item: Dictionary) -> bool:
	if category_filter.selected > 0 and str(item.get("category", "")) != INBOX_CATEGORIES[category_filter.selected]:
		return false
	match status_filter.selected:
		0:
			return not bool(item.get("resolved", false)) and not (item.get("choices", []) as Array).is_empty()
		1:
			return not bool(item.get("read", false))
		2:
			return bool(item.get("resolved", false))
	return true


func _priority_rank(priority: String) -> int:
	return int({"High":3, "Normal":2, "Low":1}.get(priority, 1))


func _deadline_text(item: Dictionary) -> String:
	if bool(item.get("resolved", false)) or (item.get("choices", []) as Array).is_empty():
		return ""
	var days_left := int(item.get("deadline", GameManager.team.current_season_day)) - GameManager.team.current_season_day
	return " · DUE DAY %d (%s)" % [int(item.get("deadline", 0)), "today" if days_left == 0 else ("%d days" % days_left if days_left > 0 else "expired")]


func _render_board(state: Dictionary) -> void:
	var board := state.board as Dictionary
	var target_lines := PackedStringArray()
	for value in board.targets:
		var target := value as Dictionary
		var deadline := int(target.get("deadline_year", GameManager.team.current_season_year))
		var progress_text := "%s / %s" % [target.get("progress", 0), target.get("target", "-")]
		if str(target.get("kind", "")) == "championship":
			progress_text = "P%s / target P%s" % [target.get("progress", "-"), target.get("target", "-")]
			target_lines.append("%s  %s · %s · due %d · %s" % ["✓" if bool(target.complete) else "○", target.label, progress_text, deadline, target.get("status", "Active")])
	_add_section("BOARD EXPECTATIONS", "Confidence %d%% · Job security %d%% · Owner patience %d%%\n%s\n%s" % [int(board.confidence), int(board.job_security), int(board.owner_patience), "\n".join(target_lines), board.last_review], [{"label":"Review ownership funding", "call":_review_board_funding}])
	var review_lines := PackedStringArray()
	for index in mini(8, (board.get("history", []) as Array).size()):
		var review := board.history[index] as Dictionary
		review_lines.append("%d · %s · %s" % [int(review.get("reviewed_year", 0)), review.get("label", "Expectation"), review.get("status", "Reviewed")])
	_add_section("OWNER REVIEW HISTORY", "\n".join(review_lines) if not review_lines.is_empty() else "Completed and failed expectations will remain here across seasons.")
	var rivalry_lines := PackedStringArray()
	for rival_id in state.rivalries:
		var rival := state.rivalries[rival_id] as Dictionary
		rivalry_lines.append("%s / %s · intensity %d · %d defeats · %d incidents" % [rival.name, rival.team, int(rival.intensity), int(rival.defeats), int(rival.incidents)])
	_add_section("DYNAMIC RIVALRIES", "\n".join(rivalry_lines) if not rivalry_lines.is_empty() else "Close finishes, incidents and transfer disputes will create persistent rivals.")
	var arc_lines := PackedStringArray()
	for index in mini(8, (state.story_arcs as Array).size()):
		var arc := state.story_arcs[index] as Dictionary
		arc_lines.append("%s · %s at %s" % [arc.type, arc.driver, arc.race])
	_add_section("CAREER STORY ARCS", "\n".join(arc_lines) if not arc_lines.is_empty() else "Comebacks, dominant runs, veterans, wonderkids and surprise contenders will be tracked here.")
	var award_lines := PackedStringArray()
	for index in mini(10, (state.awards as Array).size()):
		var award := state.awards[index] as Dictionary
		award_lines.append("%d · %s — %s" % [int(award.season), award.award, award.recipient])
	for value in state.hall_of_fame:
		var legend := value as Dictionary
		award_lines.append("HALL OF FAME · %s · %d wins · %d titles · retired #%d" % [legend.name, int(legend.wins), int(legend.championships), int(legend.retired_number)])
	_add_section("AWARDS & HALL OF FAME", "\n".join(award_lines) if not award_lines.is_empty() else "Season awards and legendary careers will appear after the first completed season.")


func _render_people(state: Dictionary) -> void:
	var form_lines := PackedStringArray()
	for driver in GameManager.team.get_contracted_drivers():
		var trend := "+%d" % driver.form_trend if driver.form_trend > 0 else str(driver.form_trend)
		var uncertainty := " · CONTRACT UNCERTAIN" if driver.contract_races_remaining <= 3 else ""
		form_lines.append("%s · Form %d (%s) · Confidence %d (%+d) · Morale %d · Effective consistency %d%s" % [driver.driver_name, driver.form, trend, driver.confidence, driver.last_confidence_change, driver.morale, driver.get_effective_consistency(), uncertainty])
	_add_section("DRIVER FORM & CONFIDENCE", "\n".join(form_lines) if not form_lines.is_empty() else "Sign a driver to track form, confidence, morale and contract pressure. Recent results, incidents and team orders all affect race performance.")
	var academy := state.academy as Dictionary
	var academy_lines := PackedStringArray(["Academy seats %d / %d" % [(academy.enrolled as Array).size(), int(academy.slots)]])
	var academy_actions: Array[Dictionary] = []
	for value in academy.enrolled:
		var prospect := value as Dictionary
		academy_lines.append("%s · age %d · OVR %d / POT %d · junior pts %d" % [prospect.name, int(prospect.age), int(prospect.overall), int(prospect.hidden_potential), int(prospect.junior_points)])
		academy_actions.append({"label":"Promote %s" % str(prospect.name).get_slice(" ", 0), "call":_promote_prospect.bind(str(prospect.id))})
	for index in mini(4, (academy.prospects as Array).size()):
		var prospect := academy.prospects[index] as Dictionary
		var estimate := CareerExpansionManager.get_uncertain_prospect_rating(GameManager.team, prospect)
		academy_lines.append("SCOUTED · %s · %s · OVR %d–%d · POT %d–%d" % [prospect.name, prospect.region, int(estimate.overall_low), int(estimate.overall_high), int(estimate.potential_low), int(estimate.potential_high)])
		academy_actions.append({"label":"Recruit %s · $%s" % [str(prospect.name).get_slice(" ", 0), int(prospect.cost)], "call":_recruit_prospect.bind(str(prospect.id))})
	_add_section("DRIVER ACADEMY & JUNIOR CHAMPIONSHIPS", "\n".join(academy_lines), academy_actions)
	var network := state.scouting_network as Dictionary
	var region_lines := PackedStringArray(["Report accuracy %d%% · Current search: %s" % [int(network.accuracy), network.assigned_region]])
	var region_actions: Array[Dictionary] = []
	for region in CareerExpansionManager.REGIONS:
		var data := network.regions[region] as Dictionary
		region_lines.append("%s · network L%d · %d discoveries · %s" % [region, int(data.level), int(data.discoveries), data.assignment])
		region_actions.append({"label":"Scout %s" % region, "call":_assign_region.bind(region)})
		if int(data.level) < 3:
			region_actions.append({"label":"Upgrade %s" % region, "call":_upgrade_region.bind(region)})
	_add_section("EXPANDED SCOUTING NETWORK", "\n".join(region_lines), region_actions)
	var relationship_lines := PackedStringArray()
	var relationship_actions: Array[Dictionary] = []
	for key in state.relationships:
		var relationship := state.relationships[key] as Dictionary
		relationship_lines.append("%s · chemistry %d · %s · %d team orders" % [str(key).replace("|", " / "), int(relationship.score), relationship.type, int(relationship.orders)])
	var contracted_drivers := GameManager.team.get_contracted_drivers()
	if contracted_drivers.size() >= 2:
		relationship_actions.append({"label":"Set driver mentorship", "call":_set_mentorship.bind(contracted_drivers[0].driver_id, contracted_drivers[1].driver_id)})
	_add_section("DRIVER RELATIONSHIPS", "\n".join(relationship_lines) if not relationship_lines.is_empty() else "Assign two drivers to build chemistry, mentorship and role dynamics.", relationship_actions)
	var injury_lines := PackedStringArray()
	for value in state.injuries:
		var injury := value as Dictionary
		injury_lines.append("%s · %s · %d recovery days" % [injury.driver_name, injury.severity, int(injury.days_remaining)])
	_add_section("INJURIES, RECOVERY & RESERVES", "\n".join(injury_lines) if not injury_lines.is_empty() else "Medical status clear. Fatigue and race incidents create injury risk; reserve drivers can cover unavailable seats.")
	var staff_lines := PackedStringArray()
	for member in GameManager.team.staff:
		if not member.hired:
			continue
		var data := (state.staff_dynamics as Dictionary).get(member.staff_id, {}) as Dictionary
		staff_lines.append("%s · %s · loyalty %d · burnout %d · poaching %s" % [member.staff_name, member.role, int(data.get("loyalty", member.loyalty)), int(data.get("burnout", member.burnout)), member.rival_interest])
	_add_section("STAFF RELATIONSHIPS & SUCCESSION", "\n".join(staff_lines) if not staff_lines.is_empty() else "Hire staff to manage loyalty, conflicts, burnout, poaching and succession planning.")
	var contract_lines := PackedStringArray()
	var contract_actions: Array[Dictionary] = []
	for driver in GameManager.team.get_contracted_drivers():
		contract_lines.append("%s · %s role · $%s salary · $%s performance · $%s release · %s option" % [driver.driver_name, driver.expected_role, driver.salary, driver.performance_bonus, driver.release_clause, driver.contract_option])
		contract_actions.append({"label":"Review lead package: %s" % driver.driver_name, "call":_review_contract_package.bind(driver.driver_id, "Lead")})
		contract_actions.append({"label":"Review equal package: %s" % driver.driver_name, "call":_review_contract_package.bind(driver.driver_id, "Equal")})
	_add_section("ADVANCED CONTRACTS", "\n".join(contract_lines) if not contract_lines.is_empty() else "No signed drivers. Contract offers support bonuses, options, clauses, promised roles, facility promises and performance targets.", contract_actions)


func _render_car(state: Dictionary) -> void:
	var rd := state.rd as Dictionary
	var project_lines := PackedStringArray(["Research effects: %s" % str(rd.effects)])
	for value in rd.projects:
		var project := value as Dictionary
		project_lines.append("%s · %d days remaining" % [CareerExpansionManager.RND_NODES[project.node_id].name, int(project.days_remaining)])
	var rnd_actions: Array[Dictionary] = []
	for node_id in CareerExpansionManager.RND_NODES:
		var node := CareerExpansionManager.RND_NODES[node_id] as Dictionary
		if (rd.completed as Array).has(node_id):
			project_lines.append("✓ %s / %s" % [node.branch, node.name])
		else:
			rnd_actions.append({"label":"Review %s · $%s" % [node.name, int(node.cost)], "call":_review_rd_project.bind(str(node_id))})
	_add_section("RESEARCH & DEVELOPMENT TREE", "\n".join(project_lines), rnd_actions)
	var design := state.car_design as Dictionary
	var design_modifiers := CareerExpansionManager.get_car_design_modifiers(GameManager.team)
	_add_section("CUSTOM CAR DESIGN", "%s philosophy · Speed %d / Handling %d / Endurance %d\nPower %+.1f · Grip %+.1f · Reliability %+.1f · Tyre wear %+.2f" % [design.philosophy, int(design.speed), int(design.handling), int(design.endurance), float(design_modifiers.power), float(design_modifiers.grip), float(design_modifiers.reliability), float(design_modifiers.tyre_wear)], [{"label":"Straight-line philosophy", "call":_set_design.bind("Straight-line", 52, 22, 26)}, {"label":"Handling philosophy", "call":_set_design.bind("Handling", 22, 52, 26)}, {"label":"Endurance philosophy", "call":_set_design.bind("Endurance", 22, 26, 52)}, {"label":"Balanced", "call":_set_design.bind("Balanced", 34, 33, 33)}])
	var manufacturing := state.manufacturing as Dictionary
	_add_section("MANUFACTURING & SPARES", "Quality %d · Spares %d · Prototypes %d · Defects %d\nNew workshop parts receive serials, variable quality, prototype gains and possible production defects." % [int(manufacturing.quality), int(manufacturing.spares), int(manufacturing.prototypes), int(manufacturing.defects)], [{"label":"Produce spare · $1,200", "call":_produce_spare}])
	var regulations := state.regulations as Dictionary
	_add_section("TECHNICAL REGULATIONS", "Current: %s · Focus: %s\nNext: %s · Reset %d PP" % [regulations.current.name, regulations.current.focus, regulations.next.get("name", "Not announced"), int(regulations.next.get("performance_reset", 0))])
	var manufacturer := state.manufacturer as Dictionary
	var offer_actions: Array[Dictionary] = []
	for offer_value in manufacturer.offers:
		var offer := offer_value as Dictionary
		offer_actions.append({"label":"Review %s · support %d" % [offer.partner, int(offer.support)], "call":_review_manufacturer.bind(str(offer.partner), int(offer.support), bool(offer.exclusivity))})
	_add_section("MANUFACTURER PARTNERSHIP", "%s · Support %d · %s · Expectation: %s" % [manufacturer.partner, int(manufacturer.support), "Exclusive" if bool(manufacturer.exclusivity) else "Independent supply", manufacturer.expectation], offer_actions)
	var testing := state.preseason as Dictionary
	var test_lines := PackedStringArray()
	for value in testing.runs:
		var run := value as Dictionary
		test_lines.append("%s · Pace %d · Reliability %d · %s" % [run.focus, int(run.pace), int(run.reliability), run.issue])
	_add_section("PRESEASON TESTING", "\n".join(test_lines) if not test_lines.is_empty() else "No test data. Testing compares upgrades, evaluates drivers and uncovers reliability problems.", [{"label":"Performance test · $3,200", "call":_run_test.bind("Performance")}, {"label":"Reliability test · $3,200", "call":_run_test.bind("Reliability")}, {"label":"Driver comparison · $3,200", "call":_run_test.bind("Driver comparison")}])


func _render_operations(state: Dictionary) -> void:
	var facility_lines := PackedStringArray()
	var facility_actions: Array[Dictionary] = []
	for facility_id in CareerExpansionManager.FACILITIES:
		var definition := CareerExpansionManager.FACILITIES[facility_id] as Dictionary
		var level := CareerExpansionManager.get_facility_level(GameManager.team, facility_id)
		facility_lines.append("%s · L%d · %s · $%d/week" % [definition.name, level, definition.bonus, int(definition.upkeep) * level])
		if level < 3:
			facility_actions.append({"label":"Review %s upgrade" % definition.name, "call":_review_facility.bind(str(facility_id))})
	_add_section("EXPANDED HEADQUARTERS", "\n".join(facility_lines), facility_actions)
	var logistics := state.logistics as Dictionary
	_add_section("LOGISTICS & EQUIPMENT", "Transporter L%d · Spare cars %d · Damaged inventory %d · Travel plan %s" % [int(logistics.transporter_level), int(logistics.spare_cars), int(logistics.damaged_inventory), logistics.travel_plan], [{"label":"Upgrade transporter", "call":_upgrade_transporter}, {"label":"Buy spare car · $8,000", "call":_buy_spare_car}, {"label":"Economy travel", "call":_set_travel_plan.bind("Economy")}, {"label":"Performance travel", "call":_set_travel_plan.bind("Performance")}])
	var team_lines := PackedStringArray()
	for race_team in GameManager.team.race_teams:
		team_lines.append("%s · %s role · %s · setup data %s" % [race_team.team_name, race_team.driver_role, race_team.team_orders, "shared" if race_team.shared_setup else "private"])
	_add_section("MULTI-CAR TEAM POLITICS", "\n".join(team_lines) if not team_lines.is_empty() else "Build a second race team to manage roles, resource allocation, crew assignments and shared data.", [{"label":"Equal resources", "call":_set_resource_policy.bind("Equal")}, {"label":"Prioritize lead car", "call":_set_resource_policy.bind("Lead car")}, {"label":"Protect contender", "call":_set_resource_policy.bind("Championship contender")}])
	var sponsor_lines := PackedStringArray()
	for index in (state.sponsor_activations as Array).size():
		var activation := state.sponsor_activations[index] as Dictionary
		var activation_status := "Complete" if bool(activation.completed) else (
			"Declined" if bool(activation.get("declined", false))
			else (
				"Expired"
				if GameManager.team.current_season_day > int(activation.get("deadline", CalendarCatalog.SEASON_END_DAY))
				else "Available through day %d" % int(activation.get("deadline", 0))
			)
		)
		sponsor_lines.append("%s · $%d · Fans +%d · Driver morale -%d · %s" % [
			activation.event,
			int(activation.value),
			int(activation.get("fans", 25)),
			int(activation.get("morale_cost", 1)),
			activation_status
		])
	var sponsor_actions: Array[Dictionary] = []
	for index in (state.sponsor_activations as Array).size():
		var activation := state.sponsor_activations[index] as Dictionary
		if (
			not bool(activation.completed)
			and not bool(activation.get("declined", false))
			and GameManager.team.current_season_day <= int(activation.get("deadline", CalendarCatalog.SEASON_END_DAY))
		):
			sponsor_actions.append({"label":"Review activation %d" % (index + 1), "call":_review_sponsor_activation.bind(index, true)})
			sponsor_actions.append({"label":"Review decline %d" % (index + 1), "call":_review_sponsor_activation.bind(index, false)})
	_add_section("SPONSOR ACTIVATION", "\n".join(sponsor_lines) if not sponsor_lines.is_empty() else "Strong race results generate appearances, hospitality and sponsor-specific activation opportunities.", sponsor_actions)
	var merch := state.merchandise as Dictionary
	var weekly_demand := CareerExpansionManager.calculate_weekly_merchandise_demand(GameManager.team)
	_add_section(
		"MERCHANDISE & FAN GROWTH",
		(
			"%d fans · Popularity %d · Stock %d\n"
			+ "Projected weekly demand %d units · Last week %d units / $%d\n"
			+ "Higher prestige, commercial appeal and momentum create more weekly sales."
		) % [
			GameManager.team.fans,
			int(merch.popularity),
			int(merch.stock),
			weekly_demand,
			int(merch.get("last_weekly_units", 0)),
			int(merch.get("last_weekly_revenue", 0))
		],
		[
			{"label":"Review 50-unit order · $500", "call":_review_merchandise.bind(50)},
			{"label":"Review 200-unit order · $2,000", "call":_review_merchandise.bind(200)}
		]
	)
	var forecast := CareerExpansionManager.update_finance_forecast(GameManager.team)
	_add_section("FINANCIAL FORECASTING", "Cash $%d · %d races remaining\nPer race: income $%d · costs $%d · net %s$%d\nSeason: income $%d · costs $%d · projected cash $%d\nReserve $%d · safe upgrade budget $%d%s%s" % [int(forecast.cash), int(forecast.remaining_races), int(forecast.race_income), int(forecast.race_cost), "+" if int(forecast.race_net) >= 0 else "", int(forecast.race_net), int(forecast.projected_income), int(forecast.projected_costs), int(forecast.season_end_cash), int(forecast.minimum_reserve), int(forecast.upgrade_budget), "\n⚠ Payroll exceeds sustainable race income." if bool(forecast.payroll_warning) else "", "\nNo sponsor is signed; sponsor income is excluded." if GameManager.team.active_sponsor_contract.is_empty() else ""])


func _render_world(state: Dictionary) -> void:
	var variation := (state.calendar_variations as Dictionary).get(str(GameManager.team.current_season_year), {}) as Dictionary
	_add_section("EVOLVING CALENDAR", "Added: %s · Removed: %s · Invitation: %s · Date shift: %+d days" % [variation.get("added", "Calendar stable"), variation.get("removed", "None"), variation.get("invitation", "None"), int(variation.get("date_shift", 0))])
	var record_lines := PackedStringArray()
	for track in state.records.tracks:
		var data := state.records.tracks[track] as Dictionary
		var average := float(data.get("average_finish_total", 0)) / maxf(1.0, float(data.get("starts", 1)))
		var lap_text := " · lap %.3fs by %s" % [float(data.get("best_lap", 0.0)), data.get("lap_record_driver", "Unknown")] if float(data.get("best_lap", 0.0)) > 0.0 else ""
		var qualifying := data.get("qualifying_record", {}) as Dictionary
		var qualifying_text := " · qualifying %.2f by %s" % [float(qualifying.score), qualifying.get("driver", "Unknown")] if not qualifying.is_empty() else ""
		var winner_names := PackedStringArray()
		for winner_index in mini(3, (data.get("previous_winners", []) as Array).size()):
			var winner := (data.previous_winners as Array)[winner_index] as Dictionary
			winner_names.append("%d %s" % [int(winner.season), winner.driver])
		var history_text := " · recent winners: %s" % ", ".join(winner_names) if not winner_names.is_empty() else ""
		record_lines.append("%s · %d starts · %d wins · best P%d · avg P%.1f · last winner %s%s%s%s" % [track, int(data.starts), int(data.wins), int(data.best_finish), average, data.get("last_winner", "Unknown"), lap_text, qualifying_text, history_text])
	for track_type in state.records.get("track_types", {}):
		var type_data := state.records.track_types[track_type] as Dictionary
		var type_average := float(type_data.get("finish_total", 0)) / maxf(1.0, float(type_data.get("starts", 1)))
		record_lines.append("%s FORM · %d starts · %d wins · average P%.1f" % [str(track_type).to_upper(), int(type_data.starts), int(type_data.wins), type_average])
	for series_id in state.records.series:
		var data := state.records.series[series_id] as Dictionary
		record_lines.append("%s · %d wins · %d podiums · %d points" % [series_id, int(data.wins), int(data.podiums), int(data.points)])
	_add_section("TRACK & SERIES RECORDS", "\n".join(record_lines) if not record_lines.is_empty() else "Race starts, wins, poles, lap records, streaks and championships will accumulate here.")
	var entrant_lines := PackedStringArray()
	for value in state.world_entrants:
		var entrant := value as Dictionary
		entrant_lines.append("%s · %s · budget $%d · performance %d · %s" % [entrant.name, entrant.series_id, int(entrant.budget), int(entrant.performance), entrant.status])
	_add_section("INDEPENDENT TEAMS & NEW ENTRANTS", "\n".join(entrant_lines))
	var alliance_lines := PackedStringArray()
	for value in state.alliances:
		var alliance := value as Dictionary
		alliance_lines.append("%s · %s · %s" % [", ".join(alliance.teams), alliance.manufacturer, alliance.focus])
	_add_section("AI MANUFACTURER ALLIANCES", "\n".join(alliance_lines) if not alliance_lines.is_empty() else "AI alliances, shared technology and divergent design philosophies evolve each offseason.")
	var development := state.ai_development as Dictionary
	var development_lines := PackedStringArray()
	var development_actions: Array[Dictionary] = []
	var listed_teams := {}
	for index in mini(12, (development.reports as Array).size()):
		var report := development.reports[index] as Dictionary
		var revealed := bool(report.get("revealed", false))
		development_lines.append("Day %d · %s · %s" % [int(report.day), report.team_name, ("equipment %d · +%d PP · $%d invested" % [int(report.equipment_rating), int(report.gain), int(report.investment)]) if revealed else "new package spotted · details unknown"])
		var team_id := str(report.team_id)
		if not revealed and not listed_teams.has(team_id):
			listed_teams[team_id] = true
			development_actions.append({"label":"Scout %s · 6h" % report.team_name, "call":_scout_ai_team.bind(team_id)})
	_add_section("AI DEVELOPMENT RACE", "\n".join(development_lines) if not development_lines.is_empty() else "Rival teams introduce upgrade packages every two weeks. Scout them to reveal investment, performance gain and current equipment level.", development_actions)
	var event_lines := PackedStringArray()
	var event_actions: Array[Dictionary] = []
	for event in CareerExpansionManager.get_special_events(GameManager.team):
		event_lines.append("%s · %s · %s · entry $%d · purse $%d · %s" % [CalendarCatalog.format_day(int(event.day)), event.name, event.status, int(event.entry_cost), int(event.prize), event.description])
		if str(event.status) == "Scheduled" and GameManager.team.current_season_day <= int(event.day):
			event_actions.append({"label":"Review %s entry" % event.name, "call":_review_special_event.bind(str(event.id))})
	_add_section("SPECIAL EVENTS", "\n".join(event_lines), event_actions)
	var international := state.international as Dictionary
	var international_lines := PackedStringArray(["Disciplines: %s" % ", ".join(international.disciplines)])
	for region in international.markets:
		var market := international.markets[region] as Dictionary
		international_lines.append("%s · %d fans · reputation %d · travel $%d" % [region, int(market.fans), int(market.reputation), int(market.travel_cost)])
	var international_actions: Array[Dictionary] = []
	for region in CareerExpansionManager.REGIONS:
		international_actions.append({"label":"Launch %s programme" % region, "call":_launch_international.bind(region)})
	_add_section("INTERNATIONAL EXPANSION", "\n".join(international_lines), international_actions)


func _render_stats_settings(state: Dictionary) -> void:
	var stats := state.stats as Dictionary
	var finish_lines := PackedStringArray()
	for index in mini(12, (stats.race_finishes as Array).size()):
		var row := stats.race_finishes[(stats.race_finishes as Array).size() - 1 - index] as Dictionary
		finish_lines.append("%s · P%d from P%d" % [row.race, int(row.finish), int(row.start)])
	var drivers := PackedStringArray()
	for driver in GameManager.team.get_contracted_drivers():
		var form := driver.get_form_summary()
		drivers.append("%s · avg start %.1f · avg finish %.1f · finish rate %d%% · incidents %d%%" % [driver.driver_name, float(form.average_start), float(form.average_finish), roundi(float(form.finish_rate) * 100.0), roundi(float(form.incident_rate) * 100.0)])
	_add_section("ADVANCED STATISTICS DASHBOARD", "%s\n\nDRIVER FORM\n%s\n\nCash trend: %s\nFan trend: %s" % ["\n".join(finish_lines) if not finish_lines.is_empty() else "No race data yet.", "\n".join(drivers) if not drivers.is_empty() else "No contracted driver data.", str(stats.cash), str(stats.fans)])
	var branding := state.branding as Dictionary
	_add_section("LIVERY & TEAM BRANDING", "%s pattern · %s numbers · %s uniforms · %s transporter · %s sponsor placement" % [branding.livery_pattern, branding.number_style, branding.uniform_style, branding.transporter_style, branding.sponsor_placement], [{"label":"Cycle livery pattern", "call":_cycle_branding.bind("livery_pattern", ["Classic stripe", "Split colour", "Speed blocks", "Heritage"])}, {"label":"Cycle number style", "call":_cycle_branding.bind("number_style", ["Block", "Slanted", "Round", "Retro"])}, {"label":"Cycle uniforms", "call":_cycle_branding.bind("uniform_style", ["Team colours", "Dark pit crew", "Heritage", "High visibility"])}, {"label":"Cycle transporter", "call":_cycle_branding.bind("transporter_style", ["Clean", "Full wrap", "Heritage", "Sponsor showcase"])}])
	var tutorial := state.tutorial as Dictionary
	var guide_lines := PackedStringArray(["%s · %d guided steps complete" % ["Enabled" if bool(tutorial.enabled) else "Disabled", (tutorial.completed_steps as Array).size()]])
	for guide_value in tutorial.guides:
		var guide := guide_value as Dictionary
		guide_lines.append("%s  %s — %s" % ["✓" if (tutorial.completed_steps as Array).has(guide.id) else "○", guide.title, guide.text])
	_add_section("INTERACTIVE TUTORIALS", "\n".join(guide_lines), [{"label":"Toggle tutorials", "call":_toggle_tutorial}, {"label":"Restart guided tour", "call":_restart_tutorial}])
	var preference_lines := PackedStringArray()
	var preference_actions: Array[Dictionary] = []
	for category in state.notification_preferences:
		var enabled := bool(state.notification_preferences[category])
		preference_lines.append("%s · %s" % [category, "On" if enabled else "Off"])
		preference_actions.append({"label":"Toggle %s" % category, "call":_toggle_notification.bind(str(category))})
	_add_section("NOTIFICATION PREFERENCES", "\n".join(preference_lines), preference_actions)
	var accessibility := state.accessibility as Dictionary
	_add_section("ACCESSIBILITY & SIMULATION", "Interface scale %.0f%% · Colour mode %s · Reduced motion %s · Simulation %.1fx" % [float(accessibility.ui_scale) * 100.0, accessibility.colorblind, "On" if bool(accessibility.reduced_motion) else "Off", float(accessibility.simulation_speed)], [{"label":"UI scale −", "call":_change_ui_scale.bind(-0.1)}, {"label":"UI scale +", "call":_change_ui_scale.bind(0.1)}, {"label":"Cycle colour mode", "call":_cycle_colour_mode}, {"label":"Toggle reduced motion", "call":_toggle_reduced_motion}, {"label":"Simulation speed", "call":_cycle_simulation_speed}])
	_add_section("RACE REPLAY & TIMELINE", "The latest official result stores lap-by-lap positions, weather, flags, pit stops, failures and decisive moments. Open the Race Results screen after a race to review it.")


func _add_section(title: String, body: String, actions: Array[Dictionary] = []) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	var heading := Label.new()
	heading.theme_type_variation = &"SectionTitle"
	heading.text = title
	stack.add_child(heading)
	var description := Label.new()
	description.text = body
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.theme_type_variation = &"MutedLabel"
	stack.add_child(description)
	if not actions.is_empty():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 5)
		stack.add_child(row)
		for action in actions:
			var button := Button.new()
			button.text = str(action.get("label", "Action"))
			button.pressed.connect(action.call as Callable)
			row.add_child(button)
	content.add_child(panel)


func _review_inbox_choice(item_id: String, choice_index: int) -> void:
	var item := CareerExpansionManager.get_inbox_item(GameManager.team, item_id)
	var model := CareerDecisionModel.build_inbox_choice(GameManager.team, item, choice_index)
	if not model.is_empty():
		comparison_drawer.display(model)


func _review_time_advance(target_day: int) -> void:
	var preview := RaceManager.get_advance_preview(target_day)
	var impacts := CareerExpansionManager.get_time_advance_impacts(GameManager.team, target_day)
	comparison_drawer.display(CareerDecisionModel.build_time_advance(GameManager.team, target_day, preview, impacts))


func _review_board_funding() -> void:
	var board := CareerExpansionManager.ensure_state(GameManager.team).board as Dictionary
	var funding := 5000 + int(board.confidence) * 100
	var eligible := int(board.confidence) >= 55 and not bool(board.get("funding_used", false))
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "OWNERSHIP DECISION",
		"title": "Request expansion funding",
		"subtitle": "One board grant is available per season when confidence is at least 55%.",
		"current_title": "CURRENT PLAN",
		"candidate_title": "WITH GRANT",
		"metrics": [
			DecisionComparisonModel.metric("Board confidence", "%d%%" % int(board.confidence), "%d%%" % int(board.confidence), "Required 55%", DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Funding used", "Yes" if bool(board.get("funding_used", false)) else "No", "Yes", "Season grant", DecisionComparisonModel.WARNING),
		],
		"upfront_cost": -funding,
		"action_enabled": eligible,
		"disabled_reason": "Board confidence must reach 55%." if int(board.confidence) < 55 else "The season's ownership grant has already been used." if bool(board.get("funding_used", false)) else "",
		"action_label": "Request funding",
		"recommendation": "Use the grant for a defined expansion need; ownership will not approve another this season.",
		"risk": "Accepting uses the organization's only expansion grant for this season.",
		"context": {"kind": "board_funding"},
	}))


func _review_contract_package(driver_id: String, role: String) -> void:
	var driver := GameManager.team.get_driver_by_id(driver_id)
	if driver == null:
		return
	var bonus := maxi(500, driver.salary / 2)
	var candidate_option := "Team" if role == "Lead" else "Driver"
	var candidate_competitiveness := 65 if role == "Lead" else 48
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "DRIVER CONTRACT DECISION",
		"title": "%s · %s package" % [driver.driver_name, role],
		"subtitle": "Set promised role, bonuses, option control and competitiveness expectations.",
		"current_title": str(driver.expected_role).to_upper(),
		"candidate_title": role.to_upper(),
		"metrics": [
			DecisionComparisonModel.metric("Performance bonus", "$%s" % _format_number(driver.performance_bonus), "$%s" % _format_number(bonus), "%s$%s" % ["+" if bonus >= driver.performance_bonus else "-", _format_number(absi(bonus - driver.performance_bonus))], DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Championship bonus", "$%s" % _format_number(driver.championship_bonus), "$%s" % _format_number(bonus * 4), "%s$%s" % ["+" if bonus * 4 >= driver.championship_bonus else "-", _format_number(absi(bonus * 4 - driver.championship_bonus))], DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Contract option", driver.contract_option, candidate_option, "Control", DecisionComparisonModel.IMPROVES if candidate_option == "Team" else DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Expected pace", str(driver.desired_competitiveness), str(candidate_competitiveness), "%+d" % (candidate_competitiveness - driver.desired_competitiveness), DecisionComparisonModel.WARNING),
		],
		"action_label": "Set contract package",
		"recommendation": "Promise the lead role only when the team can consistently prioritize this driver's results and facilities.",
		"risk": "Unmet role and competitiveness promises can weaken morale and retention.",
		"context": {"kind": "contract_package", "driver_id": driver_id, "role": role},
	}))


func _review_rd_project(node_id: String) -> void:
	var definition := CareerExpansionManager.RND_NODES.get(node_id, {}) as Dictionary
	if definition.is_empty():
		return
	var state := CareerExpansionManager.ensure_state(GameManager.team)
	var rd := state.rd as Dictionary
	var requirement := str(definition.get("requires", ""))
	var eligible := not (rd.completed as Array).has(node_id)
	for project in rd.projects:
		if str((project as Dictionary).get("node_id", "")) == node_id:
			eligible = false
	if not requirement.is_empty() and not (rd.completed as Array).has(requirement):
		eligible = false
	var cost := GameManager.team.get_discounted_cost(int(definition.cost))
	var duration := maxi(7, roundi(float(definition.days) * (1.0 - CareerExpansionManager.get_facility_level(GameManager.team, "design_office") * 0.08)))
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "R&D DECISION",
		"title": str(definition.name),
		"subtitle": "%s branch · %d-day programme" % [str(definition.branch), duration],
		"current_title": "NOT STARTED",
		"candidate_title": "ACTIVE PROJECT",
		"metrics": [
			DecisionComparisonModel.metric("Research effect", "None", "%s +%d" % [str(definition.effect).capitalize(), int(definition.value)], "Permanent", DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Completion", "—", CalendarCatalog.format_day(mini(CareerExpansionManager.SEASON_END_DAY, GameManager.team.current_season_day + duration)), "%d days" % duration, DecisionComparisonModel.NEUTRAL),
		],
		"upfront_cost": cost,
		"action_enabled": eligible,
		"disabled_reason": "Complete the prerequisite research first." if not requirement.is_empty() and not (rd.completed as Array).has(requirement) else "This research is already complete or active." if not eligible else "",
		"action_label": "Start R&D project",
		"recommendation": "Start projects early enough for their benefit to affect several race weekends.",
		"risk": "Cash is committed immediately; the performance effect arrives only after the project completes.",
		"context": {"kind": "rd_project", "node_id": node_id},
	}))


func _review_facility(facility_id: String) -> void:
	var definition := CareerExpansionManager.FACILITIES.get(facility_id, {}) as Dictionary
	if definition.is_empty():
		return
	var level := CareerExpansionManager.get_facility_level(GameManager.team, facility_id)
	var cost := int(definition.base_cost) * (level + 1)
	var active := false
	for value in CareerExpansionManager.ensure_state(GameManager.team).construction:
		if str((value as Dictionary).get("facility_id", "")) == facility_id:
			active = true
	var duration := 21 + level * 14
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "FACILITY DECISION",
		"title": "Upgrade %s" % str(definition.name),
		"subtitle": "%d-day construction project · %s" % [duration, str(definition.bonus)],
		"current_title": "LEVEL %d" % level,
		"candidate_title": "LEVEL %d" % mini(3, level + 1),
		"metrics": [
			DecisionComparisonModel.metric("Facility level", str(level), str(mini(3, level + 1)), "+1", DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Weekly upkeep", "$%s" % _format_number(int(definition.upkeep) * level), "$%s" % _format_number(int(definition.upkeep) * (level + 1)), "+$%s" % _format_number(int(definition.upkeep)), DecisionComparisonModel.WARNING),
			DecisionComparisonModel.metric("Completion", "—", CalendarCatalog.format_day(mini(CareerExpansionManager.SEASON_END_DAY, GameManager.team.current_season_day + duration)), "%d days" % duration, DecisionComparisonModel.NEUTRAL),
		],
		"upfront_cost": cost,
		"action_enabled": level < 3 and not active,
		"disabled_reason": "This facility is already at maximum level." if level >= 3 else "An upgrade is already under construction." if active else "",
		"action_label": "Start facility upgrade",
		"recommendation": "Confirm the permanent upkeep remains sustainable after the construction payment.",
		"risk": "The higher facility level adds $%s to weekly upkeep." % _format_number(int(definition.upkeep)),
		"context": {"kind": "facility_upgrade", "facility_id": facility_id},
	}))


func _review_manufacturer(partner: String, support: int, exclusive: bool) -> void:
	var current := CareerExpansionManager.ensure_state(GameManager.team).manufacturer as Dictionary
	var cost := maxi(0, 8000 - support * 50)
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "MANUFACTURER DECISION",
		"title": "%s partnership" % partner,
		"subtitle": "Technical support agreement with %s supply terms." % ("exclusive" if exclusive else "independent"),
		"current_title": str(current.partner).to_upper(),
		"candidate_title": partner.to_upper(),
		"metrics": [
			DecisionComparisonModel.metric("Technical support", str(int(current.support)), str(support), "%+d" % (support - int(current.support)), DecisionComparisonModel.IMPROVES if support >= int(current.support) else DecisionComparisonModel.WORSENS),
			DecisionComparisonModel.metric("Supply freedom", "Restricted" if bool(current.exclusivity) else "Open", "Restricted" if exclusive else "Open", "Exclusivity" if exclusive else "Flexible", DecisionComparisonModel.WARNING if exclusive else DecisionComparisonModel.IMPROVES),
		],
		"upfront_cost": cost,
		"action_label": "Sign manufacturer",
		"recommendation": "Higher support helps development, while exclusivity reduces future supplier flexibility.",
		"risk": "An exclusive agreement can restrict later manufacturer choices.",
		"context": {"kind": "manufacturer", "partner": partner, "support": support, "exclusive": exclusive},
	}))


func _review_sponsor_activation(index: int, accept: bool) -> void:
	var activations := CareerExpansionManager.ensure_state(GameManager.team).sponsor_activations as Array
	if index < 0 or index >= activations.size():
		return
	var activation := activations[index] as Dictionary
	var value := int(activation.get("value", 0)) if accept else 0
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "SPONSOR ACTIVATION DECISION",
		"title": "%s %s" % ["Accept" if accept else "Decline", str(activation.get("event", "activation"))],
		"subtitle": "Available through %s" % CalendarCatalog.format_day(int(activation.get("deadline", CareerExpansionManager.SEASON_END_DAY))),
		"current_title": "AVAILABLE",
		"candidate_title": "ACCEPTED" if accept else "DECLINED",
		"metrics": [
			DecisionComparisonModel.metric("Fan growth", "0", str(int(activation.get("fans", 0)) if accept else 0), "%+d" % (int(activation.get("fans", 0)) if accept else 0), DecisionComparisonModel.IMPROVES if accept else DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Driver morale", "No change", "-%d" % int(activation.get("morale_cost", 0)) if accept else "No change", "Appearance load" if accept else "Protected", DecisionComparisonModel.WARNING if accept else DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Sponsor relationship", "Current", "+4" if accept else "-3", "Partner effect", DecisionComparisonModel.IMPROVES if accept else DecisionComparisonModel.WORSENS),
		],
		"upfront_cost": -value,
		"action_label": "Accept activation" if accept else "Decline activation",
		"recommendation": "Accept when the commercial return is worth the driver's additional appearance load.",
		"risk": "The driver loses morale from the appearance." if accept else "Declining cools the sponsor relationship.",
		"context": {"kind": "sponsor_activation", "index": index, "accept": accept},
	}))


func _review_merchandise(quantity: int) -> void:
	var merchandise := CareerExpansionManager.ensure_state(GameManager.team).merchandise as Dictionary
	var cost := quantity * 10
	var demand := CareerExpansionManager.calculate_weekly_merchandise_demand(GameManager.team)
	comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
		"eyebrow": "MERCHANDISE DECISION",
		"title": "Order %d units" % quantity,
		"subtitle": "Current weekly demand is approximately %d units." % demand,
		"current_title": "%d IN STOCK" % int(merchandise.stock),
		"candidate_title": "%d IN STOCK" % (int(merchandise.stock) + quantity),
		"metrics": [
			DecisionComparisonModel.metric("Inventory", str(int(merchandise.stock)), str(int(merchandise.stock) + quantity), "+%d" % quantity, DecisionComparisonModel.IMPROVES),
			DecisionComparisonModel.metric("Weeks of demand", "%.1f" % (float(int(merchandise.stock)) / maxf(1.0, float(demand))), "%.1f" % (float(int(merchandise.stock) + quantity) / maxf(1.0, float(demand))), "Coverage", DecisionComparisonModel.NEUTRAL),
			DecisionComparisonModel.metric("Sales ceiling", "$%s" % _format_number(int(merchandise.stock) * int(merchandise.price)), "$%s" % _format_number((int(merchandise.stock) + quantity) * int(merchandise.price)), "+$%s" % _format_number(quantity * int(merchandise.price)), DecisionComparisonModel.IMPROVES),
		],
		"upfront_cost": cost,
		"action_label": "Place merchandise order",
		"recommendation": "Order enough for near-term demand without tying up cash needed for race operations.",
		"risk": "Unsold stock has no immediate cash return.",
		"context": {"kind": "merchandise", "quantity": quantity},
	}))


func _review_special_event(event_id: String) -> void:
	for event in CareerExpansionManager.get_special_events(GameManager.team):
		if str(event.get("id", "")) != event_id:
			continue
		var eligible := CareerExpansionManager.can_enter_special_event(GameManager.team, event)
		comparison_drawer.display(DecisionComparisonModel.build(GameManager.team, {
			"eyebrow": "SPECIAL EVENT DECISION",
			"title": str(event.name),
			"subtitle": "%s · %s" % [str(event.type), CalendarCatalog.format_day(int(event.day))],
			"current_title": "NOT ENTERED",
			"candidate_title": "ENTERED",
			"metrics": [
				DecisionComparisonModel.metric("Maximum purse", "$0", "$%s" % _format_number(int(event.prize)), "+$%s" % _format_number(int(event.prize)), DecisionComparisonModel.IMPROVES),
				DecisionComparisonModel.metric("Championship points", "Unchanged", "Unchanged", "Exhibition", DecisionComparisonModel.NEUTRAL),
				DecisionComparisonModel.metric("Calendar load", "Current", CalendarCatalog.format_day(int(event.day)), "+1 event", DecisionComparisonModel.WARNING),
			],
			"upfront_cost": int(event.entry_cost),
			"action_enabled": eligible,
			"disabled_reason": "Entry requirements, car and driver availability, reputation, manufacturer backing, or funding are not currently satisfied." if not eligible else "",
			"action_label": "Enter special event",
			"recommendation": "Enter when the extra workload fits between championship rounds and the prize opportunity supports the season plan.",
			"risk": "Payout depends on finishing position and is not guaranteed.",
			"context": {"kind": "special_event", "event_id": event_id},
		}))
		return


func _on_comparison_action(context: Dictionary) -> void:
	var kind := str(context.get("kind", ""))
	match kind:
		"career_inbox_choice":
			_prepare_receipt("Decision recorded", "%s is now the organization's recorded response." % str(context.get("choice_label", "The selected response")))
			_resolve_mail(str(context.get("item_id", "")), int(context.get("choice_index", -1)))
		"advance_time":
			_advance_time(int(context.get("target_day", GameManager.team.current_season_day)))
		"board_funding":
			_prepare_receipt("Ownership funding approved", "The board's season grant is now available to the organization.")
			_request_funding()
		"contract_package":
			_prepare_receipt("Driver package updated", "The promised role and contract terms are now recorded.", "Review driver expectations before the next race.", "res://scenes/pages/drivers/drivers.tscn")
			_set_contract_package(str(context.driver_id), str(context.role))
		"rd_project":
			_prepare_receipt("R&D project started", "Engineering work is underway and will complete as calendar days advance.", "", "res://scenes/pages/engineering/engineering.tscn")
			_start_rd(str(context.node_id))
		"facility_upgrade":
			_prepare_receipt("Facility upgrade started", "Construction is underway and permanent upkeep will increase at completion.", "", "res://scenes/pages/departments/departments.tscn")
			_upgrade_facility(str(context.facility_id))
		"manufacturer":
			_prepare_receipt("Manufacturer partnership signed", "%s is now the team's technical partner." % str(context.partner))
			_sign_manufacturer(str(context.partner), int(context.support), bool(context.exclusive))
		"sponsor_activation":
			var accepted := bool(context.accept)
			_prepare_receipt("Sponsor activation accepted" if accepted else "Sponsor activation declined", "Commercial, morale, and partner effects have been applied.", "", "res://scenes/pages/sponsors/sponsors.tscn")
			if accepted:
				_complete_activation(int(context.index))
			else:
				_decline_activation(int(context.index))
		"merchandise":
			_prepare_receipt("Merchandise ordered", "%d units were added to organization inventory." % int(context.quantity))
			_order_merch(int(context.quantity))
		"special_event":
			_prepare_receipt("Special-event entry confirmed", "The event has been added to the organization's race programme.")
			_enter_special_event(str(context.event_id))


func _advance_time(target_day: int) -> void:
	var cash_before := GameManager.team.money
	var result := RaceManager.advance_to_date(target_day)
	var days := int(result.get("days_advanced", 0))
	var summary_parts: Array[String] = []
	for summary in result.get("summaries", []) as Array:
		summary_parts.append(str(summary))
	GameManager.save_game()
	_render()
	GameManager.report_decision_outcome({
		"title": "Advanced %d calendar day%s" % [days, "" if days == 1 else "s"],
		"message": "The organization is now at %s." % CalendarCatalog.format_day(GameManager.team.current_season_day),
		"detail": " · ".join(summary_parts) if not summary_parts.is_empty() else "No project or world-state milestone required a separate update.",
		"cash_delta": GameManager.team.money - cash_before,
		"action_label": "Review priorities",
		"action_path": "res://scenes/pages/career_hub/career_hub.tscn",
	})


func _prepare_receipt(title: String, message: String, detail: String = "", action_path: String = "res://scenes/pages/career_hub/career_hub.tscn") -> void:
	pending_receipt = {
		"title": title,
		"message": message,
		"detail": detail,
		"action_path": action_path,
		"cash_before": GameManager.team.money,
	}


func _finish_action(success: bool, error_message: String = "That action is unavailable or unaffordable.") -> void:
	if not success:
		CareerExpansionManager.add_notification(GameManager.team, "Career HQ", "Action unavailable", error_message)
	GameManager.save_game()
	GameManager.refresh_team_money()
	_render()
	var receipt := pending_receipt.duplicate(true)
	pending_receipt.clear()
	GameManager.report_decision_outcome({
		"status": "success" if success else "error",
		"title": str(receipt.get("title", "Career decision complete" if success else "Career decision unavailable")),
		"message": str(receipt.get("message", "The organization state has been updated." if success else error_message)),
		"detail": str(receipt.get("detail", "")),
		"cash_delta": GameManager.team.money - int(receipt.get("cash_before", GameManager.team.money)),
		"action_label": "View update",
		"action_path": str(receipt.get("action_path", "res://scenes/pages/career_hub/career_hub.tscn")),
	})


func _resolve_mail(item_id: String, choice: int) -> void: _finish_action(CareerExpansionManager.resolve_inbox(GameManager.team, item_id, choice))
func _mark_all_read() -> void: CareerExpansionManager.mark_all_read(GameManager.team); GameManager.save_game(); _render()
func _clear_read_notices() -> void:
	var notices := CareerExpansionManager.ensure_state(GameManager.team).notifications as Array
	for index in range(notices.size() - 1, -1, -1):
		if bool((notices[index] as Dictionary).get("read", false)): notices.remove_at(index)
	GameManager.save_game(); _render()
func _request_funding() -> void:
	var board := CareerExpansionManager.ensure_state(GameManager.team).board as Dictionary
	if int(board.confidence) < 55 or bool(board.get("funding_used", false)):
		_finish_action(false, "The board requires at least 55% confidence and only approves one expansion grant per season.")
		return
	var funding := 5000 + int(board.confidence) * 100
	board.funding_used = true; board.funding = funding; GameManager.team.money += funding
	GameManager.team.record_finance("Ownership", funding, "Board-approved expansion grant")
	_finish_action(true)
func _recruit_prospect(id: String) -> void: _finish_action(CareerExpansionManager.recruit_academy_prospect(GameManager.team, id))
func _promote_prospect(id: String) -> void: _finish_action(CareerExpansionManager.promote_academy_driver(GameManager.team, id) != null)
func _assign_region(region: String) -> void: _finish_action(CareerExpansionManager.assign_scouting_region(GameManager.team, region))
func _upgrade_region(region: String) -> void: _finish_action(CareerExpansionManager.upgrade_scouting_region(GameManager.team, region))
func _set_mentorship(mentor_id: String, prospect_id: String) -> void: _finish_action(CareerExpansionManager.set_mentorship(GameManager.team, mentor_id, prospect_id))
func _set_contract_package(driver_id: String, role: String) -> void:
	var driver := GameManager.team.get_driver_by_id(driver_id)
	if driver == null: _finish_action(false); return
	var bonus := maxi(500, driver.salary / 2)
	var terms := {"performance_bonus":bonus, "championship_bonus":bonus * 4, "release_clause":driver.salary * 12, "option":"Team" if role == "Lead" else "Driver", "role":role, "minimum_facility_level":1 if role == "Lead" else 0, "desired_competitiveness":65 if role == "Lead" else 48}
	_finish_action(CareerExpansionManager.set_advanced_contract(GameManager.team, driver, terms))
func _start_rd(id: String) -> void: _finish_action(CareerExpansionManager.start_rd_project(GameManager.team, id))
func _set_design(name: String, speed: int, handling: int, endurance: int) -> void: _finish_action(CareerExpansionManager.set_car_design(GameManager.team, name, speed, handling, endurance))
func _produce_spare() -> void:
	if GameManager.team.money < 1200: _finish_action(false); return
	GameManager.team.money -= 1200; CareerExpansionManager.ensure_state(GameManager.team).manufacturing.spares += 1
	GameManager.team.record_finance("Workshop", -1200, "Produce spare components"); _finish_action(true)
func _sign_manufacturer(partner: String, support: int, exclusive: bool) -> void: _finish_action(CareerExpansionManager.begin_manufacturer_partnership(GameManager.team, partner, support, exclusive))
func _run_test(focus: String) -> void: _finish_action(not CareerExpansionManager.run_preseason_test(GameManager.team, focus).is_empty())
func _upgrade_facility(id: String) -> void: _finish_action(CareerExpansionManager.start_facility_upgrade(GameManager.team, id))
func _upgrade_transporter() -> void:
	var logistics := CareerExpansionManager.ensure_state(GameManager.team).logistics as Dictionary
	var cost := 7500 * int(logistics.transporter_level)
	if GameManager.team.money < cost: _finish_action(false); return
	GameManager.team.money -= cost; logistics.transporter_level = mini(4, int(logistics.transporter_level) + 1)
	GameManager.team.record_finance("Logistics", -cost, "Transporter upgrade"); _finish_action(true)
func _buy_spare_car() -> void:
	if GameManager.team.money < 8000: _finish_action(false); return
	GameManager.team.money -= 8000; CareerExpansionManager.ensure_state(GameManager.team).logistics.spare_cars += 1
	GameManager.team.record_finance("Logistics", -8000, "Spare race car"); _finish_action(true)
func _set_travel_plan(plan: String) -> void: CareerExpansionManager.ensure_state(GameManager.team).logistics.travel_plan = plan; _finish_action(true)
func _set_resource_policy(policy: String) -> void: CareerExpansionManager.ensure_state(GameManager.team).resource_allocations.policy = policy; _finish_action(true)
func _complete_activation(index: int) -> void: _finish_action(CareerExpansionManager.complete_sponsor_activation(GameManager.team, index))
func _decline_activation(index: int) -> void: _finish_action(CareerExpansionManager.decline_sponsor_activation(GameManager.team, index))
func _order_merch(quantity: int) -> void: _finish_action(CareerExpansionManager.order_merchandise(GameManager.team, quantity))
func _launch_international(region: String) -> void: _finish_action(CareerExpansionManager.launch_international_program(GameManager.team, region, "Touring cars"))
func _scout_ai_team(team_id: String) -> void: _finish_action(CareerExpansionManager.scout_ai_team_development(GameManager.team, team_id), "Six weekly scouting hours are required for this report.")
func _enter_special_event(event_id: String) -> void: _finish_action(CareerExpansionManager.enter_special_event(GameManager.team, event_id), "Entry requirements, car/driver availability, reputation or funding are not currently met.")
func _cycle_branding(key: String, values: Array) -> void:
	var branding := CareerExpansionManager.ensure_state(GameManager.team).branding as Dictionary
	var index := values.find(branding.get(key, values[0]))
	branding[key] = values[(index + 1) % values.size()]
	CareerExpansionManager.set_branding(GameManager.team, branding); _finish_action(true)
func _toggle_tutorial() -> void:
	var tutorial := CareerExpansionManager.ensure_state(GameManager.team).tutorial as Dictionary
	tutorial.enabled = not bool(tutorial.enabled); _finish_action(true)
func _restart_tutorial() -> void:
	var tutorial := CareerExpansionManager.ensure_state(GameManager.team).tutorial as Dictionary
	tutorial.step = 0; tutorial.completed_steps = []; tutorial.enabled = true; _finish_action(true)
func _toggle_notification(category: String) -> void:
	var preferences := CareerExpansionManager.ensure_state(GameManager.team).notification_preferences as Dictionary
	CareerExpansionManager.set_notification_preference(GameManager.team, category, not bool(preferences[category])); _finish_action(true)
func _change_ui_scale(delta: float) -> void:
	var accessibility := CareerExpansionManager.ensure_state(GameManager.team).accessibility as Dictionary
	CareerExpansionManager.set_accessibility(GameManager.team, {"ui_scale":float(accessibility.ui_scale) + delta}); _finish_action(true)
func _cycle_colour_mode() -> void:
	var accessibility := CareerExpansionManager.ensure_state(GameManager.team).accessibility as Dictionary
	var values := ["None", "Deuteranopia", "Protanopia", "Tritanopia", "High contrast"]
	CareerExpansionManager.set_accessibility(GameManager.team, {"colorblind":values[(values.find(accessibility.colorblind) + 1) % values.size()]}); _finish_action(true)
func _toggle_reduced_motion() -> void:
	var accessibility := CareerExpansionManager.ensure_state(GameManager.team).accessibility as Dictionary
	CareerExpansionManager.set_accessibility(GameManager.team, {"reduced_motion":not bool(accessibility.reduced_motion)}); _finish_action(true)
func _cycle_simulation_speed() -> void:
	var accessibility := CareerExpansionManager.ensure_state(GameManager.team).accessibility as Dictionary
	var values := [0.5, 1.0, 1.5, 2.0, 4.0]
	var index := values.find(float(accessibility.simulation_speed))
	CareerExpansionManager.set_accessibility(GameManager.team, {"simulation_speed":values[(index + 1) % values.size()]}); _finish_action(true)


func _format_number(number: int) -> String:
	var raw := str(absi(number))
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
