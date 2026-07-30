extends Control

const TABS: Array[String] = ["Inbox", "Board & Story", "People", "Car & R&D", "Operations", "World", "Stats & Settings"]

@onready var tab_selector: OptionButton = %tab_selector
@onready var content: VBoxContainer = %content
@onready var summary: Label = %Summary
@onready var mark_read_button: Button = %mark_read_button


func _ready() -> void:
	for tab in TABS:
		tab_selector.add_item(tab)
	tab_selector.item_selected.connect(_on_tab_selected)
	mark_read_button.pressed.connect(_mark_all_read)
	_render()


func _on_tab_selected(_index: int) -> void:
	_render()


func _render() -> void:
	for child in content.get_children():
		child.queue_free()
	if GameManager.team == null:
		_add_section("NO CAREER LOADED", "Start or load a career to use Career HQ.")
		return
	var state := CareerExpansionManager.ensure_state(GameManager.team)
	var unread := CareerExpansionManager.get_unread_count(GameManager.team)
	summary.text = "Season %d · Day %d · %d unread · Board confidence %d%%" % [GameManager.team.current_season_year, GameManager.team.current_season_day, unread, int(state.board.confidence)]
	mark_read_button.text = "Mark All Read (%d)" % unread
	match tab_selector.selected:
		0: _render_inbox(state)
		1: _render_board(state)
		2: _render_people(state)
		3: _render_car(state)
		4: _render_operations(state)
		5: _render_world(state)
		_: _render_stats_settings(state)


func _render_inbox(state: Dictionary) -> void:
	_add_section("TEAM PRINCIPAL INBOX", "News, urgent decisions, driver conversations, sponsor requests, paddock events and press conferences appear here.")
	var shown := 0
	for value in state.inbox:
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
		_add_section("%s  /  %s" % [str(item.get("category", "Team")).to_upper(), item.get("subject", "Update")], "%s\n%s · Season %d, day %d" % [item.get("body", ""), status, int(item.get("season", 0)), int(item.get("day", 0))], actions)
		shown += 1
	if shown == 0:
		_add_section("INBOX CLEAR", "No messages yet. Race weekends, projects and season changes will generate team news.")
	var notices := state.notifications as Array
	var lines := PackedStringArray()
	for index in mini(8, notices.size()):
		var notice := notices[index] as Dictionary
		lines.append("%s  %s — %s" % ["●" if not bool(notice.get("read", false)) else "○", notice.get("title", "Update"), notice.get("body", "")])
	_add_section("NOTIFICATION CENTER", "\n".join(lines) if not lines.is_empty() else "No notifications.", [{"label":"Clear read notices", "call":_clear_read_notices}])


func _render_board(state: Dictionary) -> void:
	var board := state.board as Dictionary
	var target_lines := PackedStringArray()
	for value in board.targets:
		var target := value as Dictionary
		target_lines.append("%s  %s · %s" % ["✓" if bool(target.complete) else "○", target.label, "Complete" if bool(target.complete) else "In progress"])
	_add_section("BOARD EXPECTATIONS", "Confidence %d%% · Job security %d%% · Owner patience %d%%\n%s\n%s" % [int(board.confidence), int(board.job_security), int(board.owner_patience), "\n".join(target_lines), board.last_review], [{"label":"Request ownership funding", "call":_request_funding}])
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
		contract_actions.append({"label":"Lead package: %s" % driver.driver_name, "call":_set_contract_package.bind(driver.driver_id, "Lead")})
		contract_actions.append({"label":"Equal package: %s" % driver.driver_name, "call":_set_contract_package.bind(driver.driver_id, "Equal")})
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
			rnd_actions.append({"label":"Research %s · $%s" % [node.name, int(node.cost)], "call":_start_rd.bind(str(node_id))})
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
		offer_actions.append({"label":"Sign %s · support %d" % [offer.partner, int(offer.support)], "call":_sign_manufacturer.bind(str(offer.partner), int(offer.support), bool(offer.exclusivity))})
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
			facility_actions.append({"label":"Upgrade %s" % definition.name, "call":_upgrade_facility.bind(str(facility_id))})
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
			sponsor_actions.append({"label":"Accept activation %d" % (index + 1), "call":_complete_activation.bind(index)})
			sponsor_actions.append({"label":"Decline activation %d" % (index + 1), "call":_decline_activation.bind(index)})
	_add_section("SPONSOR ACTIVATION", "\n".join(sponsor_lines) if not sponsor_lines.is_empty() else "Strong race results generate appearances, hospitality and sponsor-specific activation opportunities.", sponsor_actions)
	var merch := state.merchandise as Dictionary
	_add_section("MERCHANDISE & FAN GROWTH", "%d fans · Popularity %d · Stock %d · $%d last revenue\nRegional fanbases grow through results and international programmes." % [GameManager.team.fans, int(merch.popularity), int(merch.stock), int(merch.last_revenue)], [{"label":"Order 50 units · $500", "call":_order_merch.bind(50)}, {"label":"Order 200 units · $2,000", "call":_order_merch.bind(200)}])
	var forecast := CareerExpansionManager.update_finance_forecast(GameManager.team)
	_add_section("FINANCIAL FORECASTING", "Cash $%d · Weekly income $%d · Weekly costs $%d · Net %s$%d\nSeason-end forecast $%d · Safe upgrade budget $%d%s" % [int(forecast.cash), int(forecast.weekly_income), int(forecast.weekly_costs), "+" if int(forecast.weekly_net) >= 0 else "", int(forecast.weekly_net), int(forecast.season_end_cash), int(forecast.upgrade_budget), "\n⚠ Payroll exceeds sustainable income." if bool(forecast.payroll_warning) else ""])


func _render_world(state: Dictionary) -> void:
	var variation := (state.calendar_variations as Dictionary).get(str(GameManager.team.current_season_year), {}) as Dictionary
	_add_section("EVOLVING CALENDAR", "Added: %s · Removed: %s · Invitation: %s · Date shift: %+d days" % [variation.get("added", "Calendar stable"), variation.get("removed", "None"), variation.get("invitation", "None"), int(variation.get("date_shift", 0))])
	var record_lines := PackedStringArray()
	for track in state.records.tracks:
		var data := state.records.tracks[track] as Dictionary
		record_lines.append("%s · %d starts · %d wins · %d poles · best P%d" % [track, int(data.starts), int(data.wins), int(data.poles), int(data.best_finish)])
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


func _finish_action(success: bool, error_message: String = "That action is unavailable or unaffordable.") -> void:
	if not success:
		CareerExpansionManager.add_notification(GameManager.team, "Career HQ", "Action unavailable", error_message)
	GameManager.save_game()
	GameManager.refresh_team_money()
	_render()


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
