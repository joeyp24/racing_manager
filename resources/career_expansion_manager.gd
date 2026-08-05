extends RefCounted
class_name CareerExpansionManager

const STATE_VERSION: int = 3
const MAX_INBOX_ITEMS: int = 80
const MAX_NOTIFICATIONS: int = 120
const MAX_NEWS_ITEMS: int = 100

const RND_NODES: Dictionary = {
	"engine_efficiency": {"name":"Efficient combustion", "branch":"Engine", "cost":6500, "days":28, "effect":"fuel", "value":3},
	"engine_power": {"name":"High-output mapping", "branch":"Engine", "cost":9000, "days":35, "effect":"power", "value":3, "requires":"engine_efficiency"},
	"aero_balance": {"name":"Balanced aero platform", "branch":"Aerodynamics", "cost":6000, "days":28, "effect":"aero", "value":3},
	"aero_load": {"name":"High-load bodywork", "branch":"Aerodynamics", "cost":9500, "days":42, "effect":"grip", "value":4, "requires":"aero_balance"},
	"chassis_weight": {"name":"Lightweight structure", "branch":"Chassis", "cost":7500, "days":35, "effect":"performance", "value":3},
	"suspension_geometry": {"name":"Adaptive geometry", "branch":"Suspension", "cost":7000, "days":28, "effect":"tyres", "value":3},
	"reliability_lab": {"name":"Reliability validation", "branch":"Reliability", "cost":5500, "days":21, "effect":"reliability", "value":5},
	"quality_control": {"name":"Precision quality control", "branch":"Reliability", "cost":8500, "days":35, "effect":"quality", "value":6, "requires":"reliability_lab"}
}

const FACILITIES: Dictionary = {
	"design_office": {"name":"Design Office", "base_cost":12000, "upkeep":260, "bonus":"R&D speed"},
	"driver_academy": {"name":"Driver Academy", "base_cost":10000, "upkeep":220, "bonus":"Prospect growth"},
	"simulator": {"name":"Simulator Centre", "base_cost":14000, "upkeep":300, "bonus":"Setup accuracy"},
	"quality_lab": {"name":"Quality Lab", "base_cost":13000, "upkeep":280, "bonus":"Manufacturing quality"},
	"medical_centre": {"name":"Medical Centre", "base_cost":9000, "upkeep":190, "bonus":"Injury recovery"},
	"marketing_suite": {"name":"Marketing Suite", "base_cost":8000, "upkeep":180, "bonus":"Fan and sponsor growth"}
}

const REGIONS: Array[String] = ["North America", "South America", "Europe", "Asia-Pacific", "Africa"]
const FIRST_NAMES: Array[String] = ["Alex", "Maya", "Jordan", "Emi", "Riley", "Luca", "Noor", "Sam", "Toni", "Kai"]
const LAST_NAMES: Array[String] = ["Mercer", "Okafor", "Sato", "Varela", "Novak", "Bennett", "Kim", "Dubois", "Costa", "Singh"]
const CAREER_SERIES_IDS: Array[String] = [
	"local_short_track",
	"regional_short_track",
	"national_short_track",
	"continental_east_west",
	"continental_national",
	"national_truck",
	"national_grand",
	"premier_cup"
]
const SEASON_END_DAY: int = 334


static func defaults() -> Dictionary:
	var facilities := {}
	for facility_id in FACILITIES:
		facilities[facility_id] = {"level":0, "condition":100}
	var region_state := {}
	for region in REGIONS:
		region_state[region] = {"level":0, "assignment":"None", "discoveries":0}
	return {
		"version":STATE_VERSION,
		"inbox":[],
		"news_feed":[],
		"notifications":[],
		"notification_preferences":{"Contracts":true, "Repairs":true, "Projects":true, "Sponsors":true, "Race":true, "Board":true},
		"board":{
			"confidence":72,
			"job_security":78,
			"owner_patience":70,
			"funding":0,
			"targets":[],
			"last_review":"No review yet",
			"history":[]
		},
		"rivalries":{},
		"featured_rival_id":"",
		"processed_transfers":[],
		"press_history":[],
		"story_arcs":[],
		"story_event_history":[],
		"awards":[],
		"hall_of_fame":[],
		"academy":{"budget":0, "slots":2, "prospects":[], "enrolled":[], "junior_results":[]},
		"scouting_network":{"regions":region_state, "accuracy":45, "assigned_region":"North America"},
		"relationships":{},
		"injuries":[],
		"staff_dynamics":{},
		"contract_terms":{},
		"rd":{"points":0, "completed":[], "projects":[], "effects":{}},
		"car_design":{"philosophy":"Balanced", "speed":34, "handling":33, "endurance":33},
		"manufacturing":{"quality":65, "spares":2, "defects":0, "prototypes":0},
		"regulations":{"current":{"name":"Stable regulations", "performance_reset":0, "focus":"Balanced"}, "next":{}, "history":[]},
		"manufacturer":{"partner":"Independent", "support":0, "exclusivity":false, "expectation":"Finish races", "offers":[]},
		"preseason":{"completed":false, "runs":[], "reliability_known":false},
		"stewarding":{"cases":[], "appeals":[], "penalty_points":0},
		"facilities":facilities,
		"construction":[],
		"logistics":{"transporter_level":1, "spare_cars":1, "damaged_inventory":0, "travel_plan":"Standard"},
		"resource_allocations":{},
		"sponsor_activations":[],
		"merchandise":{
			"popularity":0,
			"stock":0,
			"price":25,
			"regional_fans":{},
			"last_revenue":0,
			"last_weekly_units":0,
			"last_weekly_revenue":0,
			"lifetime_revenue":0,
			"last_sales_day":0
		},
		"finance_forecast":{},
		"calendar_variations":{},
		"records":{"tracks":{}, "series":{}, "all_time":{}},
		"ai_development":{"last_day":CalendarCatalog.SEASON_START_DAY, "reports":[], "intel":{}},
		"special_events":[],
		"world_entrants":[],
		"alliances":[],
		"international":{"markets":{}, "programs":[], "disciplines":["Stock cars"]},
		"tutorial":{"enabled":true, "step":0, "completed_steps":[], "guides":[
			{"id":"hire_driver", "title":"Build a driver lineup", "text":"Scout or hire an available driver and agree a sustainable contract."},
			{"id":"prepare_car", "title":"Prepare a race car", "text":"Buy a car, install parts, inspect condition and assign it to a race team."},
			{"id":"enter_race", "title":"Enter the first race", "text":"Check eligibility and budget before paying weekend operations costs."},
			{"id":"practice", "title":"Learn setup through practice", "text":"Use all three timed runs and compare uncertain feedback against lap time."},
			{"id":"finance", "title":"Protect cash flow", "text":"Use the financial forecast before committing to salaries, R&D or facilities."}
		]},
		"accessibility":{"ui_scale":1.0, "colorblind":"None", "reduced_motion":false, "simulation_speed":1.0},
		"branding":{"livery_pattern":"Classic stripe", "number_style":"Block", "uniform_style":"Team colours", "transporter_style":"Clean", "sponsor_placement":"Balanced"},
		"race_weekend":{"forecast":{}, "qualifying_format":"Standard", "team_order":"Race freely"},
		"stats":{"race_finishes":[], "development":[], "cash":[], "fans":[]},
		"season_processed":0
	}


static func ensure_state(team) -> Dictionary:
	if team.career_state == null:
		team.career_state = {}
	_merge_defaults(team.career_state, defaults())
	team.career_state["version"] = STATE_VERSION
	_migrate_inbox_metadata(team)
	_ensure_board_targets(team)
	_ensure_academy_prospects(team)
	_ensure_staff_dynamics(team)
	_ensure_relationships(team)
	_ensure_world_entrants(team)
	_ensure_transfer_rivalries(team)
	_ensure_special_events(team)
	_update_tutorial_progress(team)
	update_finance_forecast(team)
	return team.career_state


static func _migrate_inbox_metadata(team) -> void:
	for value in (team.career_state.inbox as Array):
		var item := value as Dictionary
		var requires_action := not bool(item.get("resolved", false)) and not (item.get("choices", []) as Array).is_empty()
		if not item.has("deadline"):
			item["deadline"] = mini(SEASON_END_DAY, int(item.get("day", team.current_season_day)) + (7 if requires_action else 0))
		if not item.has("priority"):
			item["priority"] = "Normal" if requires_action else "Low"
		if not item.has("why_changed"):
			item["why_changed"] = "This message was carried forward from an earlier career save."
		if not item.has("story_id"):
			item["story_id"] = ""


static func _merge_defaults(target: Dictionary, template: Dictionary) -> void:
	for key in template:
		var fallback: Variant = template[key]
		if not target.has(key) or target[key] == null:
			target[key] = fallback.duplicate(true) if fallback is Dictionary or fallback is Array else fallback
		elif fallback is Dictionary and target[key] is Dictionary:
			_merge_defaults(target[key], fallback)


static func add_notification(team, category: String, title: String, body: String, urgent: bool = false) -> void:
	var state: Dictionary = team.career_state
	var preference_key: String = str({
		"Contracts":"Contracts", "Driver market":"Contracts", "Medical":"Contracts",
		"Workshop":"Repairs", "Logistics":"Repairs",
		"Engineering":"Projects", "Headquarters":"Projects", "Testing":"Projects",
		"Sponsor":"Sponsors", "Media":"Sponsors"
	}.get(category, category))
	if not urgent and (state.notification_preferences as Dictionary).has(preference_key) and not bool((state.notification_preferences as Dictionary)[preference_key]):
		return
	var notifications := state.notifications as Array
	notifications.push_front({
		"id":"notice_%d_%d" % [Time.get_unix_time_from_system(), notifications.size()],
		"category":category,
		"title":title,
		"body":body,
		"urgent":urgent,
		"read":false,
		"season":team.current_season_year,
		"day":team.current_season_day
	})
	if notifications.size() > MAX_NOTIFICATIONS:
		notifications.resize(MAX_NOTIFICATIONS)


static func add_news_item(team, category: String, headline: String, body: String, importance: int = 1) -> void:
	ensure_state(team)
	_append_news(team, category, headline, body, importance)


static func _append_news(team, category: String, headline: String, body: String, importance: int = 1) -> void:
	var news := team.career_state.news_feed as Array
	news.push_front({
		"id":"news_%d_%d" % [Time.get_unix_time_from_system(), news.size()],
		"category":category,
		"headline":headline,
		"body":body,
		"importance":clampi(importance, 1, 3),
		"season":team.current_season_year,
		"day":team.current_season_day
	})
	if news.size() > MAX_NEWS_ITEMS:
		news.resize(MAX_NEWS_ITEMS)


static func set_notification_preference(team, category: String, enabled: bool) -> void:
	var preferences := ensure_state(team).notification_preferences as Dictionary
	if preferences.has(category):
		preferences[category] = enabled
		team.emit_changed()


static func _update_tutorial_progress(team) -> void:
	var tutorial := team.career_state.get("tutorial", {}) as Dictionary
	if not bool(tutorial.get("enabled", true)):
		return
	var completed := tutorial.get("completed_steps", []) as Array
	if not team.get_contracted_drivers().is_empty() and not completed.has("hire_driver"):
		completed.append("hire_driver")
	var has_car := false
	for car_value in team.cars:
		if car_value != null:
			has_car = true
			break
	if has_car and not completed.has("prepare_car"):
		completed.append("prepare_car")
	if not team.get_completed_races().is_empty():
		if not completed.has("enter_race"): completed.append("enter_race")
		if not completed.has("practice"): completed.append("practice")
	if not team.finance_history.is_empty() and not completed.has("finance"):
		completed.append("finance")
	tutorial["step"] = completed.size()


static func add_inbox_item(team, category: String, subject: String, body: String, choices: Array = [], metadata: Dictionary = {}) -> void:
	var state := ensure_state(team)
	var inbox := state.inbox as Array
	var requires_action := not choices.is_empty()
	var default_priority := "High" if requires_action and category in ["Board", "Medical", "Stewarding", "Regulations"] else ("Normal" if requires_action else "Low")
	inbox.push_front({
		"id":"mail_%d_%d" % [Time.get_unix_time_from_system(), inbox.size()],
		"category":category,
		"subject":subject,
		"body":body,
		"choices":choices.duplicate(true),
		"resolved":not requires_action,
		"read":false,
		"season":team.current_season_year,
		"day":team.current_season_day,
		"deadline":mini(SEASON_END_DAY, int(metadata.get("deadline", team.current_season_day + (7 if requires_action else 0)))),
		"priority":str(metadata.get("priority", default_priority)),
		"why_changed":str(metadata.get("why_changed", "New information arrived from %s." % category)),
		"story_id":str(metadata.get("story_id", ""))
	})
	if inbox.size() > MAX_INBOX_ITEMS:
		inbox.resize(MAX_INBOX_ITEMS)
	add_notification(team, category, subject, body, not choices.is_empty())


static func resolve_inbox(team, item_id: String, choice_index: int) -> bool:
	var state := ensure_state(team)
	for item_value in state.inbox:
		var item := item_value as Dictionary
		if str(item.get("id", "")) != item_id or bool(item.get("resolved", false)):
			continue
		var choices := item.get("choices", []) as Array
		if choice_index < 0 or choice_index >= choices.size():
			return false
		var choice := choices[choice_index] as Dictionary
		if team.money < int(choice.get("cost", 0)):
			return false
		team.money -= int(choice.get("cost", 0))
		_apply_effects(team, choice.get("effects", {}) as Dictionary)
		item["resolved"] = true
		item["selected"] = str(choice.get("label", "Responded"))
		add_notification(team, "Decision", "Decision recorded", "%s: %s" % [item.get("subject", "Inbox"), item.selected])
		team.emit_changed()
		return true
	return false


static func _apply_effects(team, effects: Dictionary) -> void:
	var state := ensure_state(team)
	var board := state.board as Dictionary
	for key in effects:
		var amount := int(effects[key])
		match str(key):
			"money":
				team.money += amount
				team.record_finance("Decision", amount, "Team principal decision")
			"reputation":
				ReputationManager.apply_event(team, "commercial_appeal", amount, "Media response improved public awareness", maxi(0, amount), "Media")
			"sporting_credibility":
				ReputationManager.apply_event(team, "sporting_credibility", amount, "Team decision changed sporting credibility", 0, "Decision")
			"professionalism":
				ReputationManager.apply_event(team, "professionalism", amount, "Team decision changed professional standing", 0, "Decision")
			"commercial_appeal":
				ReputationManager.apply_event(team, "commercial_appeal", amount, "Team decision changed commercial appeal", 0, "Decision")
			"fans": team.fans = maxi(0, team.fans + amount)
			"confidence": board.confidence = clampi(int(board.confidence) + amount, 0, 100)
			"job_security": board.job_security = clampi(int(board.job_security) + amount, 0, 100)
			"driver_morale":
				for driver in team.get_contracted_drivers():
					driver.morale = clampi(driver.morale + amount, 0, 99)
			"staff_morale":
				for member in team.staff:
					if member.hired: member.morale = clampi(member.morale + amount, 0, 100)
			"sponsor":
				team.sponsor_objective_progress = maxi(0, team.sponsor_objective_progress + amount)
			"rivalry":
				var rivalries := state.rivalries as Dictionary
				if not rivalries.is_empty():
					var first_id := str(rivalries.keys()[0])
					var rival := rivalries[first_id] as Dictionary
					rival.intensity = clampi(int(rival.intensity) + amount, 0, 100)


static func _ensure_board_targets(team) -> void:
	var board := team.career_state.get("board", {}) as Dictionary
	var targets := board.get("targets", []) as Array
	for value in targets:
		var existing := value as Dictionary
		var legacy_id := str(existing.get("id", "expectation"))
		existing["kind"] = str(existing.get("kind", legacy_id.get_slice("_", 0)))
		existing["created_year"] = int(existing.get("created_year", team.current_season_year))
		existing["deadline_year"] = int(existing.get("deadline_year", team.current_season_year))
		existing["horizon"] = maxi(1, int(existing.deadline_year) - int(existing.created_year) + 1)
		existing["status"] = str(existing.get("status", "Complete" if bool(existing.get("complete", false)) else "Active"))
	var expected_finish := 8
	if team.last_season_position > 0:
		expected_finish = maxi(1, team.last_season_position)
	var has_current_annual := targets.any(func(value: Variant) -> bool:
		var target := value as Dictionary
		return int(target.get("created_year", 0)) == team.current_season_year and str(target.get("kind", "")) == "championship"
	)
	if not has_current_annual and int(board.get("annual_reviewed_year", 0)) != team.current_season_year:
		targets.append({"id":"championship_%d" % team.current_season_year, "kind":"championship", "label":"Finish P%d or better" % expected_finish, "target":expected_finish, "progress":0, "complete":false, "status":"Active", "created_year":team.current_season_year, "deadline_year":team.current_season_year, "horizon":1})
		targets.append({"id":"finance_%d" % team.current_season_year, "kind":"finance", "label":"Finish the season with a $10,000 reserve", "target":10000, "progress":team.money, "complete":team.money >= 10000, "status":"Active", "created_year":team.current_season_year, "deadline_year":team.current_season_year, "horizon":1})
	var has_development := targets.any(func(value: Variant) -> bool: return str((value as Dictionary).get("kind", "")) == "driver_development" and str((value as Dictionary).get("status", "Active")) == "Active")
	if not has_development:
		var driver: Driver = team.get_active_driver()
		var baseline := driver.get_overall_rating() if driver != null else 0
		targets.append({"id":"driver_development_%d" % team.current_season_year, "kind":"driver_development", "label":"Develop a team driver by 3 OVR", "target":3, "progress":0, "baseline":baseline, "driver_id":driver.driver_id if driver != null else "", "complete":false, "status":"Active", "created_year":team.current_season_year, "deadline_year":team.current_season_year + 1, "horizon":2})
	var current_index := SeriesCatalog.get_index(team.current_series_id)
	var has_promotion := targets.any(func(value: Variant) -> bool: return str((value as Dictionary).get("kind", "")) == "promotion" and str((value as Dictionary).get("status", "Active")) == "Active")
	if current_index >= 0 and current_index < SeriesCatalog.SERIES.size() - 1 and not has_promotion:
		var next_series := SeriesCatalog.SERIES[current_index + 1] as Dictionary
		targets.append({"id":"promotion_%d" % team.current_season_year, "kind":"promotion", "label":"Reach %s" % next_series.name, "target_series":str(next_series.id), "target":current_index + 1, "progress":current_index, "complete":false, "status":"Active", "created_year":team.current_season_year, "deadline_year":team.current_season_year + 2, "horizon":3})
	board["targets"] = targets


static func process_day(team, elapsed_days: int) -> Array[String]:
	var state := ensure_state(team)
	var summaries: Array[String] = []
	ReputationManager.advance_days(team, elapsed_days)
	_process_rd(team, elapsed_days, summaries)
	_process_construction(team, elapsed_days, summaries)
	_process_injuries(team, elapsed_days, summaries)
	_process_academy(team, elapsed_days, summaries)
	_process_scouting_network(team, elapsed_days, summaries)
	_process_staff(team, elapsed_days, summaries)
	_process_ai_development(team, summaries)
	_process_special_events(team, summaries)
	_apply_upkeep(team, elapsed_days, summaries)
	_process_weekly_merchandise(team, elapsed_days, summaries)
	_expire_inbox_decisions(team)
	_generate_paddock_event(team, elapsed_days)
	update_finance_forecast(team)
	return summaries


static func start_new_season(team) -> void:
	var state := ensure_state(team)
	var merchandise := state.merchandise as Dictionary
	merchandise.last_sales_day = team.current_season_day
	merchandise.last_weekly_units = 0
	merchandise.last_weekly_revenue = 0
	(state.ai_development as Dictionary).last_day = team.current_season_day
	state.special_events = []
	_ensure_special_events(team)
	update_finance_forecast(team)


static func calculate_weekly_merchandise_demand(team) -> int:
	var merchandise := team.career_state.get("merchandise", {}) as Dictionary
	var prestige_level: int = team.get_reputation_level()
	var commercial_appeal := ReputationManager.get_dimension(team, "commercial_appeal")
	var momentum := int(ReputationManager.ensure_state(team).momentum)
	var marketing_level: int = team.get_department_level("marketing")
	return maxi(
		3,
		5
		+ prestige_level * 2
		+ roundi(float(commercial_appeal) / 5.0)
		+ mini(45, roundi(float(team.fans) / 200.0))
		+ marketing_level * 3
		+ mini(15, roundi(float(merchandise.popularity) / 50.0))
		+ maxi(-4, roundi(float(momentum) / 10.0))
	)


static func _process_weekly_merchandise(team, elapsed_days: int, summaries: Array[String]) -> void:
	var merchandise := ensure_state(team).merchandise as Dictionary
	if int(merchandise.last_sales_day) <= 0:
		merchandise.last_sales_day = maxi(
			CalendarCatalog.SEASON_START_DAY,
			team.current_season_day - elapsed_days
		)
	var weeks_elapsed := floori(
		float(team.current_season_day - int(merchandise.last_sales_day)) / 7.0
	)
	if weeks_elapsed <= 0:
		return
	var total_units := 0
	var total_revenue := 0
	var total_demand := 0
	for week in weeks_elapsed:
		var demand := calculate_weekly_merchandise_demand(team)
		var units := mini(int(merchandise.stock), demand)
		var revenue := units * int(merchandise.price)
		merchandise.stock = maxi(0, int(merchandise.stock) - units)
		merchandise.popularity = maxi(0, int(merchandise.popularity) + roundi(float(units) * 0.25))
		total_units += units
		total_revenue += revenue
		total_demand += demand
	merchandise.last_sales_day = int(merchandise.last_sales_day) + weeks_elapsed * 7
	merchandise.last_weekly_units = total_units
	merchandise.last_weekly_revenue = total_revenue
	merchandise.last_revenue = total_revenue
	merchandise.lifetime_revenue = int(merchandise.lifetime_revenue) + total_revenue
	if total_revenue > 0:
		var game_manager: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
		if game_manager != null and game_manager.get("team") == team:
			game_manager.call("add_team_money", total_revenue)
		else:
			team.money += total_revenue
		team.record_finance(
			"Merchandise",
			total_revenue,
			"%d week%s of reputation-driven merchandise sales"
			% [weeks_elapsed, "" if weeks_elapsed == 1 else "s"]
		)
	summaries.append(
		"Merchandise: sold %d of %d requested units for $%s"
		% [total_units, total_demand, String.num_int64(total_revenue)]
	)


static func _process_rd(team, elapsed_days: int, summaries: Array[String]) -> void:
	var rd := team.career_state.rd as Dictionary
	var projects := rd.projects as Array
	var finished: Array = []
	for project_value in projects:
		var project := project_value as Dictionary
		project["days_remaining"] = maxi(0, int(project.days_remaining) - elapsed_days)
		if int(project.days_remaining) <= 0:
			finished.append(project)
	for project in finished:
		projects.erase(project)
		var node_id := str(project.node_id)
		if not (rd.completed as Array).has(node_id):
			(rd.completed as Array).append(node_id)
		var node := RND_NODES.get(node_id, {}) as Dictionary
		var effects := rd.effects as Dictionary
		var effect := str(node.get("effect", "performance"))
		effects[effect] = int(effects.get(effect, 0)) + int(node.get("value", 1))
		summaries.append("R&D completed: %s" % node.get("name", node_id))
		add_inbox_item(team, "Engineering", "R&D programme completed", "%s is ready for the race cars." % node.get("name", node_id))


static func start_rd_project(team, node_id: String) -> bool:
	var state := ensure_state(team)
	if not RND_NODES.has(node_id):
		return false
	var rd := state.rd as Dictionary
	if (rd.completed as Array).has(node_id):
		return false
	for value in rd.projects:
		if str((value as Dictionary).get("node_id", "")) == node_id:
			return false
	var node := RND_NODES[node_id] as Dictionary
	var required := str(node.get("requires", ""))
	if not required.is_empty() and not (rd.completed as Array).has(required):
		return false
	var cost: int = int(team.get_discounted_cost(int(node.cost)))
	if team.money < cost:
		return false
	team.money -= cost
	team.record_finance("R&D", -cost, str(node.name))
	var speed_bonus := get_facility_level(team, "design_office") * 0.08
	(rd.projects as Array).append({"node_id":node_id, "days_remaining":maxi(7, roundi(float(node.days) * (1.0 - speed_bonus)))})
	add_notification(team, "Engineering", "R&D started", str(node.name))
	team.emit_changed()
	return true


static func set_car_design(team, philosophy: String, speed: int, handling: int, endurance: int) -> bool:
	if speed + handling + endurance != 100 or mini(speed, mini(handling, endurance)) < 10:
		return false
	var design := ensure_state(team).car_design as Dictionary
	design["philosophy"] = philosophy
	design["speed"] = speed
	design["handling"] = handling
	design["endurance"] = endurance
	team.emit_changed()
	return true


static func get_car_design_modifiers(team) -> Dictionary:
	var design := ensure_state(team).car_design as Dictionary
	return {
		"power":(float(design.speed) - 33.0) * 0.06,
		"grip":(float(design.handling) - 33.0) * 0.06,
		"reliability":(float(design.endurance) - 33.0) * 0.10,
		"tyre_wear":-(float(design.endurance) - 33.0) * 0.035
	}


static func apply_manufacturing_quality(team, part: CarPart) -> String:
	var manufacturing := ensure_state(team).manufacturing as Dictionary
	var quality := clampi(int(manufacturing.quality) + get_facility_level(team, "quality_lab") * 5, 35, 95)
	var roll := randi_range(1, 100)
	part.manufacturing_quality = quality
	part.serial_number = "RM-%d-%04d" % [team.current_season_year, randi_range(1, 9999)]
	part.is_prototype = bool(roll > 92)
	part.has_production_defect = bool(roll > quality)
	if part.is_prototype:
		part.base_performance_points += 2
		manufacturing.prototypes = int(manufacturing.prototypes) + 1
	if part.has_production_defect:
		part.reliability_modifier -= 6
		part.condition = mini(part.condition, 92)
		manufacturing.defects = int(manufacturing.defects) + 1
		return "Quality control found a latent defect after production."
	manufacturing.spares = maxi(0, int(manufacturing.spares) - 1)
	return "Prototype performance gain" if part.is_prototype else "Passed quality control"


static func _process_construction(team, elapsed_days: int, summaries: Array[String]) -> void:
	var construction := team.career_state.construction as Array
	var completed: Array = []
	for value in construction:
		var project := value as Dictionary
		project["days_remaining"] = maxi(0, int(project.days_remaining) - elapsed_days)
		if int(project.days_remaining) <= 0:
			completed.append(project)
	for project in completed:
		construction.erase(project)
		var facility_id := str(project.facility_id)
		var facility := (team.career_state.facilities as Dictionary).get(facility_id, {}) as Dictionary
		facility["level"] = mini(3, int(facility.get("level", 0)) + 1)
		summaries.append("%s upgraded to level %d" % [FACILITIES[facility_id].name, facility.level])
		add_inbox_item(team, "Headquarters", "Construction complete", summaries[-1])


static func start_facility_upgrade(team, facility_id: String) -> bool:
	var state := ensure_state(team)
	if not FACILITIES.has(facility_id):
		return false
	for value in state.construction:
		if str((value as Dictionary).get("facility_id", "")) == facility_id:
			return false
	var level := get_facility_level(team, facility_id)
	if level >= 3:
		return false
	var cost := int(FACILITIES[facility_id].base_cost) * (level + 1)
	if team.money < cost:
		return false
	team.money -= cost
	team.record_finance("Headquarters", -cost, "Upgrade %s" % FACILITIES[facility_id].name)
	(state.construction as Array).append({"facility_id":facility_id, "days_remaining":21 + level * 14})
	add_notification(team, "Headquarters", "Construction started", str(FACILITIES[facility_id].name))
	team.emit_changed()
	return true


static func get_facility_level(team, facility_id: String) -> int:
	if team == null or not team.career_state.has("facilities"):
		return 0
	var facilities := team.career_state.facilities as Dictionary
	return int((facilities.get(facility_id, {}) as Dictionary).get("level", 0))


static func _apply_upkeep(team, elapsed_days: int, summaries: Array[String]) -> void:
	if elapsed_days <= 0:
		return
	var upkeep := 0
	for facility_id in FACILITIES:
		var level := get_facility_level(team, facility_id)
		upkeep += int(FACILITIES[facility_id].upkeep) * level
	var weekly_cost := roundi(float(upkeep) * float(elapsed_days) / 7.0)
	if weekly_cost > 0:
		team.money -= weekly_cost
		team.record_finance("Headquarters", -weekly_cost, "Facility upkeep")
		summaries.append("Facility upkeep: $%s" % weekly_cost)


static func _ensure_academy_prospects(team) -> void:
	var academy := team.career_state.get("academy", {}) as Dictionary
	var prospects := academy.get("prospects", []) as Array
	while prospects.size() < 6:
		prospects.append(_generate_prospect(team, prospects.size()))


static func _generate_prospect(team, offset: int) -> Dictionary:
	var seed_value := hash("%s:%d:%d" % [team.team_name, team.current_season_year, offset])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var overall := rng.randi_range(38, 64)
	var potential := rng.randi_range(maxi(66, overall + 10), 94)
	var region := REGIONS[rng.randi_range(0, REGIONS.size() - 1)]
	return {
		"id":"academy_%d_%d" % [team.current_season_year, abs(seed_value) % 100000],
		"name":"%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]],
		"age":rng.randi_range(16, 20),
		"region":region,
		"overall":overall,
		"potential":potential,
		"hidden_potential":potential,
		"morale":70,
		"junior_points":0,
		"seasons":0,
		"status":"Scouted",
		"cost":rng.randi_range(1800, 5200)
	}


static func recruit_academy_prospect(team, prospect_id: String) -> bool:
	var academy := ensure_state(team).academy as Dictionary
	var enrolled := academy.enrolled as Array
	if enrolled.size() >= int(academy.slots):
		return false
	for prospect_value in academy.prospects:
		var prospect := prospect_value as Dictionary
		if str(prospect.id) != prospect_id:
			continue
		var cost := int(prospect.cost)
		if team.money < cost:
			return false
		team.money -= cost
		team.record_finance("Academy", -cost, "Recruit %s" % prospect.name)
		prospect["status"] = "Academy"
		enrolled.append(prospect)
		(academy.prospects as Array).erase(prospect)
		add_inbox_item(team, "Academy", "Prospect signed", "%s has joined the driver academy." % prospect.name)
		team.emit_changed()
		return true
	return false


static func _process_academy(team, elapsed_days: int, summaries: Array[String]) -> void:
	if elapsed_days <= 0:
		return
	var academy := team.career_state.academy as Dictionary
	var growth_bonus := get_facility_level(team, "driver_academy")
	for prospect_value in academy.enrolled:
		var prospect := prospect_value as Dictionary
		var chance := 0.08 * float(elapsed_days) / 7.0 + growth_bonus * 0.02
		if int(prospect.overall) < int(prospect.hidden_potential) and randf() < chance:
			prospect["overall"] = int(prospect.overall) + 1
			prospect["junior_points"] = int(prospect.junior_points) + randi_range(3, 12)
			summaries.append("%s improved in the junior programme" % prospect.name)


static func _process_scouting_network(team, elapsed_days: int, summaries: Array[String]) -> void:
	if elapsed_days < 7:
		return
	var network := team.career_state.scouting_network as Dictionary
	var region := str(network.assigned_region)
	var region_data := (network.regions as Dictionary).get(region, {}) as Dictionary
	if str(region_data.get("assignment", "None")) == "None":
		return
	var discovery_chance := 0.12 + int(region_data.get("level", 0)) * 0.08
	if randf() >= discovery_chance * float(elapsed_days) / 7.0:
		return
	var academy := team.career_state.academy as Dictionary
	var prospect := _generate_prospect(team, (academy.prospects as Array).size() + int(region_data.get("discoveries", 0)) + 20)
	prospect["region"] = region
	(academy.prospects as Array).push_front(prospect)
	region_data["discoveries"] = int(region_data.get("discoveries", 0)) + 1
	summaries.append("The %s network discovered %s" % [region, prospect.name])
	add_inbox_item(team, "Scouting", "Regional discovery", "%s found %s, a young %s prospect with an uncertain ceiling." % [region, prospect.name, prospect.region])


static func _expire_inbox_decisions(team) -> void:
	var state := ensure_state(team)
	for value in state.inbox:
		var item := value as Dictionary
		if bool(item.get("resolved", false)) or (item.get("choices", []) as Array).is_empty():
			continue
		var deadline := int(item.get("deadline", 0))
		if deadline <= 0 or team.current_season_day <= deadline:
			continue
		item["resolved"] = true
		item["selected"] = "Deadline passed"
		item["read"] = false
		add_notification(team, "Decision", "Decision deadline passed", "%s was closed without a response." % item.get("subject", "Inbox decision"), true)


static func _generate_paddock_event(team, elapsed_days: int) -> void:
	if elapsed_days < 7 or randf() > 0.34 * float(elapsed_days) / 7.0:
		return
	var state := ensure_state(team)
	var candidates := _authored_paddock_events(team)
	if candidates.is_empty():
		return
	var recent := state.story_event_history as Array
	var available: Array[Dictionary] = []
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		if not recent.has(str(candidate.id)):
			available.append(candidate)
	if available.is_empty():
		available = candidates
	var event := available[randi_range(0, available.size() - 1)] as Dictionary
	add_inbox_item(team, str(event.category), str(event.subject), str(event.body), event.choices as Array, {
		"deadline":mini(SEASON_END_DAY, team.current_season_day + int(event.get("deadline_days", 7))),
		"priority":str(event.get("priority", "Normal")),
		"why_changed":str(event.get("why_changed", "A new paddock development requires attention.")),
		"story_id":str(event.id)
	})
	add_news_item(team, str(event.category), str(event.subject), str(event.get("news", event.body)), 2 if str(event.get("priority", "Normal")) == "High" else 1)
	recent.push_front(str(event.id))
	if recent.size() > 4:
		recent.resize(4)


static func _authored_paddock_events(team) -> Array[Dictionary]:
	var state := ensure_state(team)
	var events: Array[Dictionary] = []
	var contracted: Array[Driver] = team.get_contracted_drivers()
	if not contracted.is_empty():
		var driver := contracted[0]
		events.append({
			"id":"driver_resource_dispute", "category":"Driver", "priority":"High", "deadline_days":5,
			"subject":"%s questions the development plan" % driver.driver_name,
			"body":"After two difficult debriefs, %s believes the current development direction is costing race pace and wants a clear commitment before the next event." % driver.driver_name,
			"why_changed":"Driver morale and the team's recent development direction brought the disagreement to a head.",
			"news":"A disagreement over technical priorities has become the paddock's latest talking point.",
			"choices":[
				{"label":"Back the driver's direction", "cost":1200, "effects":{"driver_morale":7, "staff_morale":-2, "confidence":1}},
				{"label":"Back the engineering group", "effects":{"driver_morale":-5, "staff_morale":4, "professionalism":1}},
				{"label":"Commission a joint test", "cost":2400, "effects":{"driver_morale":3, "staff_morale":3, "sporting_credibility":1}}
			]
		})
	if not team.active_sponsor_contract.is_empty():
		var sponsor_name := str(team.active_sponsor_contract.get("sponsor_name", "The title partner"))
		events.append({
			"id":"sponsor_brand_conflict", "category":"Sponsor", "priority":"High", "deadline_days":6,
			"subject":"%s challenges the team's public message" % sponsor_name,
			"body":"The sponsor says a recent press appearance conflicts with its campaign and wants a corrective activation before the next race.",
			"why_changed":"A public team statement clashed with the active sponsor's campaign priorities.",
			"news":"Commercial tension has surfaced between the team and its primary partner.",
			"choices":[
				{"label":"Fund a corrective campaign", "cost":1800, "effects":{"sponsor":5, "commercial_appeal":3, "fans":40}},
				{"label":"Offer a private apology", "effects":{"sponsor":2, "professionalism":2}},
				{"label":"Defend the team's independence", "effects":{"sponsor":-5, "fans":70, "commercial_appeal":1}}
			]
		})
	var regulations := state.regulations as Dictionary
	var next_rules := regulations.get("next", {}) as Dictionary
	if not next_rules.is_empty():
		events.append({
			"id":"regulation_controversy", "category":"Regulations", "priority":"High", "deadline_days":9,
			"subject":"Teams split over %s" % next_rules.get("name", "the next technical rules"),
			"body":"A paddock working group is divided over the proposed %s focus. Your public position will influence manufacturers, independent teams and the board." % next_rules.get("focus", "cost-control"),
			"why_changed":"The governing body opened formal consultation on the published technical reset.",
			"news":"The next technical package has triggered a public dispute between leading organizations.",
			"choices":[
				{"label":"Support the reset", "effects":{"professionalism":2, "commercial_appeal":1, "confidence":1}},
				{"label":"Fight for technical freedom", "effects":{"sporting_credibility":2, "professionalism":-1, "rivalry":4}},
				{"label":"Call for a cost compromise", "effects":{"professionalism":3, "staff_morale":1}}
			]
		})
	var has_car := false
	for car_value in team.cars:
		if car_value != null:
			has_car = true
			break
	if has_car:
		events.append({
			"id":"technical_failure_warning", "category":"Engineering", "priority":"High", "deadline_days":4,
			"subject":"Inspection finds a developing reliability risk",
			"body":"Workshop inspection found heat damage near a critical assembly. The car can race, but the technical group recommends action before the next start.",
			"why_changed":"Accumulated mileage and recent component stress pushed the assembly beyond its inspection threshold.",
			"news":"The team faces an unexpected reliability decision before its next appearance.",
			"choices":[
				{"label":"Replace the assembly", "cost":3200, "effects":{"staff_morale":2, "professionalism":2}},
				{"label":"Run an extended inspection", "cost":1100, "effects":{"staff_morale":1, "confidence":-1}},
				{"label":"Accept the risk", "effects":{"staff_morale":-4, "confidence":-2}}
			]
		})
	var rivalries := state.rivalries as Dictionary
	if not rivalries.is_empty():
		var rival := rivalries[rivalries.keys()[0]] as Dictionary
		events.append({
			"id":"rival_accusation", "category":"Rivalry", "priority":"Normal", "deadline_days":7,
			"subject":"%s questions your team's tactics" % rival.get("name", "A rival driver"),
			"body":"The rival camp claims your team crossed the line in recent wheel-to-wheel racing and is pushing the story through the media.",
			"why_changed":"A persistent rivalry reached %d intensity after recent on-track encounters." % int(rival.get("intensity", 0)),
			"news":"A competitive rivalry has spilled from the circuit into the press room.",
			"choices":[
				{"label":"De-escalate publicly", "effects":{"professionalism":3, "rivalry":-7}},
				{"label":"Answer forcefully", "effects":{"fans":60, "commercial_appeal":2, "rivalry":8}},
				{"label":"Invite a private meeting", "effects":{"professionalism":2, "rivalry":-3, "driver_morale":1}}
			]
		})
	var completed: int = team.get_completed_races().size()
	if completed >= 3:
		var standings: Array[Dictionary] = team.get_sorted_championship_standings()
		var player_position := 0
		for index in standings.size():
			if bool((standings[index] as Dictionary).get("is_player", false)):
				player_position = index + 1
				break
		events.append({
			"id":"championship_pressure", "category":"Championship", "priority":"High" if player_position <= 3 else "Normal", "deadline_days":7,
			"subject":"Championship pressure reshapes the season",
			"body":"With %d races complete and the team P%d, ownership wants the next month framed around a clear competitive priority." % [completed, maxi(1, player_position)],
			"why_changed":"The championship passed its first major checkpoint and the standings now carry strategic weight.",
			"news":"The title picture is beginning to influence development and race-weekend decisions.",
			"choices":[
				{"label":"Prioritize points consistency", "effects":{"confidence":2, "professionalism":2, "driver_morale":1}},
				{"label":"Commit to race wins", "effects":{"sporting_credibility":2, "rivalry":4, "staff_morale":-1}},
				{"label":"Protect the long-term plan", "effects":{"confidence":-1, "staff_morale":3}}
			]
		})
	if events.is_empty():
		events.append({
			"id":"community_identity", "category":"Paddock", "priority":"Normal", "deadline_days":10,
			"subject":"Local supporters ask what the team stands for",
			"body":"A growing group of supporters wants the team to choose between a community programme and a performance-first public identity.",
			"why_changed":"Recent fan growth created an opportunity to define the team's public identity.",
			"choices":[
				{"label":"Launch a community programme", "cost":900, "effects":{"fans":90, "commercial_appeal":2}},
				{"label":"Focus every resource on racing", "effects":{"sporting_credibility":1, "fans":-15}}
			]
		})
	return events


static func _process_ai_development(team, summaries: Array[String]) -> void:
	var development := team.career_state.ai_development as Dictionary
	var last_day := int(development.get("last_day", CalendarCatalog.SEASON_START_DAY))
	var cycles := floori(float(team.current_season_day - last_day) / 14.0)
	if cycles <= 0:
		return
	var teams: Array[Dictionary] = team.get_ai_team_states_for_series(team.current_series_id)
	if teams.is_empty():
		development.last_day = team.current_season_day
		return
	var reports := development.reports as Array
	var intel := development.intel as Dictionary
	var series := SeriesCatalog.get_series(team.current_series_id)
	var base_investment := maxi(500, int(series.get("estimated_race_cost", 1200)) / 2)
	var upgrades := 0
	for cycle in cycles:
		for offset in mini(2, teams.size()):
			var index := posmod(team.current_season_year + last_day + cycle * 3 + offset * 5, teams.size())
			var rival := teams[index] as Dictionary
			var budget := int(rival.get("budget", 0))
			if budget < base_investment:
				continue
			var investment := mini(base_investment, maxi(0, roundi(float(budget) * 0.08)))
			var old_rating := int(rival.get("equipment_rating", 50))
			var gain := 1 + (1 if int(rival.get("engineering_rating", 50)) >= 72 and posmod(hash(str(rival.team_id) + str(team.current_season_day)), 3) == 0 else 0)
			rival.budget = budget - investment
			rival.equipment_rating = clampi(old_rating + gain, 1, 100)
			rival.engineering_rating = clampi(int(rival.get("engineering_rating", 50)) + (1 if gain > 1 else 0), 1, 100)
			rival.trend = float(rival.get("trend", 0.0)) + float(gain) * 0.35
			var revealed := bool(intel.get(str(rival.team_id), false))
			var report := {
				"team_id":str(rival.team_id),
				"team_name":str(rival.team_name),
				"day":team.current_season_day,
				"season":team.current_season_year,
				"investment":investment,
				"gain":gain,
				"equipment_rating":int(rival.equipment_rating),
				"revealed":revealed
			}
			reports.push_front(report)
			upgrades += 1
			add_news_item(team, "Development", "%s brings an upgrade" % rival.team_name, "%s has introduced a %s package before the next round." % [rival.team_name, "major" if gain > 1 else "targeted"], 2 if gain > 1 else 1)
	development.last_day = last_day + cycles * 14
	if reports.size() > 80:
		reports.resize(80)
	if upgrades > 0:
		summaries.append("Rival development: %d upgrade package%s introduced" % [upgrades, "" if upgrades == 1 else "s"])


static func scout_ai_team_development(team, team_id: String) -> bool:
	team.ensure_scouting_hours()
	if team.scouting_hours_remaining < 6 or team.get_ai_team_state(team_id).is_empty():
		return false
	team.scouting_hours_remaining -= 6
	var state := ensure_state(team)
	var development := state.ai_development as Dictionary
	(development.intel as Dictionary)[team_id] = true
	for value in development.reports:
		var report := value as Dictionary
		if str(report.get("team_id", "")) == team_id:
			report.revealed = true
	var rival: Dictionary = team.get_ai_team_state(team_id)
	add_inbox_item(team, "Scouting", "Development report: %s" % rival.get("team_name", "Rival team"), "Scouts rate the current equipment at %d, engineering at %d, with a %+.1f development trend." % [int(rival.get("equipment_rating", 50)), int(rival.get("engineering_rating", 50)), float(rival.get("trend", 0.0))])
	team.emit_changed()
	return true


static func _ensure_special_events(team) -> void:
	var events := team.career_state.get("special_events", []) as Array
	for value in events:
		if int((value as Dictionary).get("season", 0)) == team.current_season_year:
			return
	var templates := [
		{"id":"all_star", "name":"International All-Star 100", "type":"Invitational", "day":102, "entry_cost":500, "prize":6500, "required_level":2, "description":"A reputation-gated sprint against leading drivers."},
		{"id":"endurance", "name":"Heartland 300 Endurance", "type":"Endurance", "day":172, "entry_cost":900, "prize":10000, "required_level":1, "description":"A long-distance non-championship test of pace and reliability."},
		{"id":"manufacturer", "name":"Manufacturer Development Challenge", "type":"Manufacturer", "day":242, "entry_cost":0, "prize":8000, "required_level":1, "description":"A technical challenge available to manufacturer-backed teams."},
		{"id":"exhibition", "name":"Season Finale Exhibition", "type":"Exhibition", "day":306, "entry_cost":300, "prize":4500, "required_level":1, "description":"A fan-focused exhibition with appearance and performance money."}
	]
	var occupied_special_days: Array[int] = []
	for template_value in templates:
		var event := (template_value as Dictionary).duplicate(true)
		event.day = _find_special_event_day(team.current_series_id, int(event.day), occupied_special_days)
		occupied_special_days.append(int(event.day))
		event.id = "%s_%d" % [event.id, team.current_season_year]
		event.season = team.current_season_year
		event.status = "Scheduled"
		event.finish = 0
		event.payout = 0
		events.append(event)
	team.career_state.special_events = events


static func _find_special_event_day(series_id: String, preferred_day: int, occupied_special_days: Array[int]) -> int:
	var race_days: Array[int] = []
	for race_event in CalendarCatalog.get_events(series_id):
		race_days.append(int(race_event.get("schedule_day", 0)))
	for offset in [0, -4, 4, -7, 7, -10, 10, -14, 14]:
		var candidate := clampi(preferred_day + int(offset), CalendarCatalog.SEASON_START_DAY + 7, CalendarCatalog.SEASON_END_DAY - 7)
		if occupied_special_days.has(candidate):
			continue
		var conflicts := race_days.any(func(race_day: int) -> bool: return absi(race_day - candidate) <= 2)
		if not conflicts:
			return candidate
	return clampi(preferred_day, CalendarCatalog.SEASON_START_DAY + 7, CalendarCatalog.SEASON_END_DAY - 7)


static func get_special_events(team) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var state := ensure_state(team)
	for value in state.special_events:
		var event := value as Dictionary
		if int(event.get("season", 0)) == team.current_season_year:
			result.append(event)
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first.day) < int(second.day))
	return result


static func can_enter_special_event(team, event: Dictionary) -> bool:
	if event.is_empty() or str(event.get("status", "")) != "Scheduled" or team.current_season_day > int(event.get("day", 0)):
		return false
	if team.get_reputation_level() < int(event.get("required_level", 1)) or team.money < int(event.get("entry_cost", 0)):
		return false
	if str(event.get("type", "")) == "Manufacturer":
		return str((ensure_state(team).manufacturer as Dictionary).get("partner", "Independent")) != "Independent"
	return team.get_active_driver() != null and team.cars.any(func(car): return car != null)


static func enter_special_event(team, event_id: String) -> bool:
	for event in get_special_events(team):
		if str(event.get("id", "")) != event_id or not can_enter_special_event(team, event):
			continue
		var cost := int(event.get("entry_cost", 0))
		team.money -= cost
		if cost > 0:
			team.record_finance("Special Event", -cost, "%s entry" % event.name)
		event.status = "Entered"
		add_news_item(team, "Special Event", "%s confirms entry" % team.team_name, "The team will contest the %s alongside its championship programme." % event.name, 2)
		add_notification(team, "Race", "Special-event entry confirmed", "%s takes place on %s." % [event.name, CalendarCatalog.format_day(int(event.day))])
		team.emit_changed()
		return true
	return false


static func _process_special_events(team, summaries: Array[String]) -> void:
	for event in get_special_events(team):
		if int(event.day) > team.current_season_day or str(event.status) in ["Completed", "Missed"]:
			continue
		if str(event.status) != "Entered":
			event.status = "Missed"
			continue
		var driver: Driver = team.get_active_driver()
		var car: Car = null
		for car_value in team.cars:
			if car_value is Car:
				car = car_value as Car
				break
		if driver == null or car == null:
			event.status = "Missed"
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(event.id) + team.team_name)
		var strength := float(driver.get_overall_rating()) + float(car.get_total_performance_points(team)) + driver.get_race_state_modifier()
		var finish := clampi(roundi(15.0 - (strength - 100.0) * 0.12 + rng.randf_range(-3.0, 3.0)), 1, 24)
		var payout_ratio := 1.0 if finish == 1 else (0.72 if finish <= 3 else (0.45 if finish <= 8 else 0.20))
		var payout := roundi(float(event.prize) * payout_ratio)
		event.status = "Completed"
		event.finish = finish
		event.payout = payout
		team.money += payout
		team.record_finance("Special Event", payout, "%s P%d payout" % [event.name, finish])
		driver.record_race({"race_id":event.id, "race_name":event.name, "start":12, "finish":finish, "positions_gained":12-finish, "status":"Finished", "incident":false, "special_event":true})
		driver.apply_race_dynamics({"finish":finish, "status":"Finished", "incident":false}, 12)
		if finish <= 5:
			ReputationManager.apply_event(team, "sporting_credibility", 2, "Strong special-event result", 35, "Special Event")
		add_news_item(team, "Special Event", "%s finishes P%d in %s" % [team.team_name, finish, event.name], "The non-championship appearance earned $%s and increased the team's profile." % String.num_int64(payout), 3 if finish <= 3 else 2)
		add_inbox_item(team, "Race", "Special-event result", "%s finished P%d and earned $%s without affecting championship points." % [driver.driver_name, finish, String.num_int64(payout)])
		summaries.append("%s: P%d, $%s earned" % [event.name, finish, String.num_int64(payout)])


static func promote_academy_driver(team, prospect_id: String) -> Driver:
	var academy := ensure_state(team).academy as Dictionary
	for value in academy.enrolled:
		var prospect := value as Dictionary
		if str(prospect.id) != prospect_id:
			continue
		var driver := Driver.new()
		driver.driver_id = "rookie_%s" % prospect.id
		driver.driver_name = str(prospect.name)
		driver.age = int(prospect.age)
		driver.nationality = str(prospect.region)
		driver.racing_background = "Team driver academy"
		driver.initialize_detailed_ratings(int(prospect.overall), int(prospect.overall), 50, int(prospect.hidden_potential))
		driver.expected_role = "Prospect"
		driver.salary = 1000 + int(prospect.overall) * 18
		driver.signing_fee = 0
		driver.team_name = team.team_name
		driver.series_id = team.current_series_id
		team.drivers.append(driver)
		(academy.enrolled as Array).erase(prospect)
		add_inbox_item(team, "Academy", "Academy promotion", "%s is now available for a senior race seat." % driver.driver_name)
		return driver
	return null


static func assign_scouting_region(team, region: String) -> bool:
	var network := ensure_state(team).scouting_network as Dictionary
	if not (network.regions as Dictionary).has(region):
		return false
	network["assigned_region"] = region
	((network.regions as Dictionary)[region] as Dictionary)["assignment"] = "Talent search"
	add_notification(team, "Scouting", "Regional search assigned", region)
	team.emit_changed()
	return true


static func upgrade_scouting_region(team, region: String) -> bool:
	var network := ensure_state(team).scouting_network as Dictionary
	var regions := network.regions as Dictionary
	if not regions.has(region):
		return false
	var data := regions[region] as Dictionary
	var level := int(data.level)
	var cost := 3000 * (level + 1)
	if level >= 3 or team.money < cost:
		return false
	team.money -= cost
	data["level"] = level + 1
	network["accuracy"] = mini(95, int(network.accuracy) + 6)
	team.record_finance("Scouting", -cost, "Expand %s network" % region)
	team.emit_changed()
	return true


static func get_uncertain_prospect_rating(team, prospect: Dictionary) -> Dictionary:
	var accuracy := int((ensure_state(team).scouting_network as Dictionary).accuracy)
	var uncertainty := maxi(1, roundi(float(100 - accuracy) * 0.16))
	return {
		"overall_low":maxi(1, int(prospect.overall) - uncertainty),
		"overall_high":mini(99, int(prospect.overall) + uncertainty),
		"potential_low":maxi(1, int(prospect.hidden_potential) - uncertainty * 2),
		"potential_high":mini(99, int(prospect.hidden_potential) + uncertainty * 2)
	}


static func _ensure_relationships(team) -> void:
	var relationships := team.career_state.get("relationships", {}) as Dictionary
	var contracted: Array[Driver] = team.get_contracted_drivers()
	for first_index in contracted.size():
		for second_index in range(first_index + 1, contracted.size()):
			var first: Driver = contracted[first_index]
			var second: Driver = contracted[second_index]
			var key := _pair_key(first.driver_id, second.driver_id)
			if not relationships.has(key):
				relationships[key] = {"score":55, "type":"Professional", "mentor":"", "incidents":0, "orders":0}


static func _ensure_transfer_rivalries(team) -> void:
	var processed := team.career_state.get("processed_transfers", []) as Array
	var rivalries := team.career_state.get("rivalries", {}) as Dictionary
	for transaction_value in team.transfer_history:
		var transaction := transaction_value as Dictionary
		var signature := "%s:%s:%s" % [transaction.get("season", 0), transaction.get("driver_id", ""), transaction.get("text", "")]
		if processed.has(signature):
			continue
		processed.append(signature)
		var team_id := str(transaction.get("team_id", "transfer_market"))
		var data := rivalries.get(team_id, {"name":"Transfer rival", "team":team.get_ai_team_name(team_id), "intensity":8, "incidents":0, "defeats":0, "disputes":0, "history":[]}) as Dictionary
		data.disputes = int(data.disputes) + 1
		data.intensity = clampi(int(data.intensity) + 6, 0, 100)
		(data.history as Array).push_front({"season":transaction.get("season", 0), "event":transaction.get("text", "Transfer dispute")})
		rivalries[team_id] = data
		_append_news(team, "Transfer", "Driver market movement", str(transaction.get("text", "A transfer rumor is circulating in the paddock.")), 2)
	if processed.size() > 100:
		processed.resize(100)


static func _pair_key(first: String, second: String) -> String:
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]


static func set_mentorship(team, mentor_id: String, prospect_id: String) -> bool:
	var relationships := ensure_state(team).relationships as Dictionary
	var key := _pair_key(mentor_id, prospect_id)
	if not relationships.has(key):
		relationships[key] = {"score":55, "type":"Mentorship", "mentor":mentor_id, "incidents":0, "orders":0}
	else:
		(relationships[key] as Dictionary)["mentor"] = mentor_id
		(relationships[key] as Dictionary)["type"] = "Mentorship"
	add_notification(team, "Drivers", "Mentorship established", "Senior-driver feedback will accelerate development.")
	team.emit_changed()
	return true


static func _process_injuries(team, elapsed_days: int, summaries: Array[String]) -> void:
	var injuries := team.career_state.injuries as Array
	var recovered: Array = []
	var recovery_bonus := get_facility_level(team, "medical_centre")
	for value in injuries:
		var injury := value as Dictionary
		injury["days_remaining"] = maxi(0, int(injury.days_remaining) - elapsed_days - recovery_bonus)
		var driver: Driver = team.get_driver_by_id(str(injury.driver_id))
		if driver != null:
			driver.unavailable_weeks = ceili(float(injury.days_remaining) / 7.0)
		if int(injury.days_remaining) <= 0:
			recovered.append(injury)
			if driver != null:
				driver.availability_status = "Available"
				driver.unavailable_weeks = 0
				summaries.append("%s has completed injury rehabilitation" % driver.driver_name)
	for injury in recovered:
		injuries.erase(injury)


static func create_injury(team, driver: Driver, severity: String = "Minor") -> void:
	if driver == null:
		return
	var days: int = int({"Minor":7, "Moderate":21, "Serious":42}.get(severity, 7))
	driver.availability_status = "Injured"
	driver.unavailable_weeks = ceili(float(days) / 7.0)
	(ensure_state(team).injuries as Array).append({"driver_id":driver.driver_id, "driver_name":driver.driver_name, "severity":severity, "days_remaining":days})
	add_inbox_item(team, "Medical", "%s injury" % severity, "%s will miss approximately %d week(s). A reserve driver may be required." % [driver.driver_name, driver.unavailable_weeks])


static func _ensure_staff_dynamics(team) -> void:
	var dynamics := team.career_state.get("staff_dynamics", {}) as Dictionary
	for member in team.staff:
		if member.staff_id.is_empty():
			continue
		if not dynamics.has(member.staff_id):
			dynamics[member.staff_id] = {"loyalty":clampi(member.morale, 25, 90), "burnout":0, "conflict":"None", "successor":""}


static func _process_staff(team, elapsed_days: int, summaries: Array[String]) -> void:
	_ensure_staff_dynamics(team)
	var dynamics := team.career_state.staff_dynamics as Dictionary
	for member in team.staff:
		if not member.hired or not dynamics.has(member.staff_id):
			continue
		var data := dynamics[member.staff_id] as Dictionary
		var workload := 2 if not team.engineering_projects.is_empty() else 1
		data["burnout"] = clampi(int(data.burnout) + roundi(float(elapsed_days) / 7.0 * workload) - (1 if member.morale > 80 else 0), 0, 100)
		data["loyalty"] = clampi(int(data.loyalty) + (1 if member.morale >= 70 else -1), 0, 100)
		member.burnout = int(data.burnout)
		member.loyalty = int(data.loyalty)
		if int(data.burnout) >= 75:
			member.morale = maxi(0, member.morale - 2)
			if randf() < 0.08:
				add_inbox_item(team, "Staff", "Burnout concern: %s" % member.staff_name, "Reduce workload or risk losing a key staff member.", [
					{"label":"Give paid leave", "cost":member.salary, "effects":{"staff_morale":8, "confidence":1}},
					{"label":"Keep working", "cost":0, "effects":{"staff_morale":-5}}
				])
		if int(data.burnout) >= 55 and randf() < 0.04 * float(elapsed_days) / 7.0:
			data["conflict"] = "Workload dispute"
			member.relationship_notes["department"] = "Workload dispute"
		if int(data.loyalty) < 35:
			member.rival_interest = "High"


static func set_advanced_contract(team, driver: Driver, terms: Dictionary) -> bool:
	if driver == null:
		return false
	driver.performance_bonus = maxi(0, int(terms.get("performance_bonus", driver.performance_bonus)))
	driver.championship_bonus = maxi(0, int(terms.get("championship_bonus", driver.championship_bonus)))
	driver.release_clause = maxi(0, int(terms.get("release_clause", driver.release_clause)))
	driver.contract_option = str(terms.get("option", driver.contract_option))
	driver.expected_role = str(terms.get("role", driver.expected_role))
	driver.minimum_facility_level = clampi(int(terms.get("minimum_facility_level", driver.minimum_facility_level)), 0, 3)
	driver.desired_competitiveness = clampi(int(terms.get("desired_competitiveness", driver.desired_competitiveness)), 0, 99)
	var all_terms := ensure_state(team).contract_terms as Dictionary
	all_terms[driver.driver_id] = terms.duplicate(true)
	team.emit_changed()
	return true


static func begin_manufacturer_partnership(team, partner: String, support: int, exclusive: bool) -> bool:
	var cost := maxi(0, 8000 - support * 50)
	if team.money < cost:
		return false
	team.money -= cost
	var data := ensure_state(team).manufacturer as Dictionary
	data["partner"] = partner
	data["support"] = clampi(support, 0, 100)
	data["exclusivity"] = exclusive
	data["expectation"] = "Top-half championship finish" if support >= 60 else "Finish races"
	team.record_finance("Manufacturer", -cost, "%s partnership" % partner)
	add_inbox_item(team, "Manufacturer", "Partnership confirmed", "%s will provide technical support this season." % partner)
	team.emit_changed()
	return true


static func run_preseason_test(team, focus: String) -> Dictionary:
	var state := ensure_state(team)
	var cost := 3200
	if team.money < cost:
		return {}
	team.money -= cost
	team.record_finance("Testing", -cost, "%s preseason programme" % focus)
	var reliability := 55 + get_facility_level(team, "simulator") * 6 + int((state.rd.effects as Dictionary).get("reliability", 0))
	var result := {"focus":focus, "pace":randi_range(45, 80), "reliability":clampi(reliability + randi_range(-8, 8), 1, 99), "issue":"None"}
	if int(result.reliability) < 60:
		result.issue = "Cooling weakness"
	(state.preseason.runs as Array).append(result)
	state.preseason["completed"] = true
	state.preseason["reliability_known"] = true
	add_inbox_item(team, "Testing", "Preseason test complete", "%s: pace %d, reliability confidence %d%%, issue: %s." % [focus, result.pace, result.reliability, result.issue])
	team.emit_changed()
	return result


static func process_race(team, result, simulation = null) -> void:
	var state := ensure_state(team)
	var board := state.board as Dictionary
	var finish_target := 8
	for target_value in board.targets:
		var expectation := target_value as Dictionary
		if str(expectation.get("kind", expectation.get("id", ""))) == "championship" and str(expectation.get("status", "Active")) == "Active":
			finish_target = int(expectation.get("target", finish_target))
			break
	var delta := 4 if result.finishing_position <= finish_target else -3
	if result.finishing_position == 1:
		delta += 4
	board["confidence"] = clampi(int(board.confidence) + delta, 0, 100)
	board["job_security"] = clampi(int(board.job_security) + signi(delta), 0, 100)
	_update_board_progress(team, result)
	_update_records(team, result)
	_update_stats(team, result)
	_update_rivalries(team, result)
	_update_driver_dynamics(team, result)
	_write_race_story(team, result)
	_publish_race_news(team, result)
	_generate_press_conference(team, result)
	_generate_story_arc(team, result)
	_process_sponsor_and_merchandise(team, result)
	_process_injury_risk(team, result)
	_process_stewarding(team, result, simulation)
	_process_team_politics(team, result)
	_process_logistics_damage(team, result)
	update_finance_forecast(team)
	if result.finishing_position <= 3:
		add_notification(team, "Race", "Podium secured", "%s finished P%d." % [result.player_driver.driver_name, result.finishing_position])
	team.emit_changed()


static func _update_board_progress(team, result) -> void:
	var targets := (team.career_state.board as Dictionary).targets as Array
	for target_value in targets:
		var target := target_value as Dictionary
		if str(target.get("status", "Active")) != "Active":
			continue
		match str(target.get("kind", target.get("id", ""))):
			"championship":
				var standings: Array[Dictionary] = team.get_sorted_championship_standings()
				var position: int = result.finishing_position
				for index in standings.size():
					if bool((standings[index] as Dictionary).get("is_player", false)):
						position = index + 1
						break
				target["progress"] = position
				target["complete"] = position <= int(target.target)
			"finance":
				target["progress"] = team.money
				target["complete"] = team.money >= int(target.target)
			"development":
				target["progress"] = (team.career_state.rd.completed as Array).size()
				target["complete"] = int(target.progress) >= int(target.target)
			"driver_development":
				var driver: Driver = team.get_driver_by_id(str(target.get("driver_id", "")))
				if driver == null:
					driver = team.get_active_driver()
				var gain := maxi(0, driver.get_overall_rating() - int(target.get("baseline", driver.get_overall_rating()))) if driver != null else 0
				target["progress"] = gain
				target["complete"] = gain >= int(target.target)
			"promotion":
				var current_index := SeriesCatalog.get_index(team.current_series_id)
				target["progress"] = current_index
				target["complete"] = current_index >= int(target.target)


static func _update_records(team, result) -> void:
	var records := team.career_state.records as Dictionary
	var track_id: String = str(result.race.track_name)
	var tracks := records.tracks as Dictionary
	var track := tracks.get(track_id, {"starts":0, "wins":0, "poles":0, "best_finish":999, "best_lap":0.0, "average_finish_total":0, "previous_winners":[], "player_results":[], "qualifying_record":{}}) as Dictionary
	_merge_defaults(track, {"average_finish_total":0, "previous_winners":[], "player_results":[], "qualifying_record":{}, "last_winner":""})
	track.starts = int(track.starts) + 1
	track.wins = int(track.wins) + (1 if result.finishing_position == 1 else 0)
	track.poles = int(track.poles) + (1 if result.starting_position == 1 else 0)
	track.best_finish = mini(int(track.best_finish), result.finishing_position)
	track.average_finish_total = int(track.average_finish_total) + result.finishing_position
	(track.player_results as Array).push_front({"season":team.current_season_year, "finish":result.finishing_position, "start":result.starting_position, "driver":result.player_driver.driver_name})
	if (track.player_results as Array).size() > 12:
		(track.player_results as Array).resize(12)
	if result.qualifying_score > float((track.qualifying_record as Dictionary).get("score", -INF)):
		track.qualifying_record = {"score":result.qualifying_score, "driver":result.player_driver.driver_name, "season":team.current_season_year}
	if not result.standings.is_empty():
		var winner := result.standings[0] as Dictionary
		track.last_winner = str(winner.get("driver_name", "Unknown"))
		(track.previous_winners as Array).push_front({"season":team.current_season_year, "driver":track.last_winner, "team":winner.get("team_name", "")})
		if (track.previous_winners as Array).size() > 10:
			(track.previous_winners as Array).resize(10)
		var best_lap := 0.0
		var lap_driver := ""
		for row_value in result.standings:
			var row := row_value as Dictionary
			var lap := float(row.get("best_lap_time", 0.0))
			if lap > 0.0 and (best_lap <= 0.0 or lap < best_lap):
				best_lap = lap
				lap_driver = str(row.get("driver_name", "Unknown"))
		if best_lap > 0.0 and (float(track.best_lap) <= 0.0 or best_lap < float(track.best_lap)):
			track.best_lap = best_lap
			track.lap_record_driver = lap_driver
			track.lap_record_season = team.current_season_year
	tracks[track_id] = track
	var type_records := records.get("track_types", {}) as Dictionary
	var type_id := str(result.race.track_type)
	var type_data := type_records.get(type_id, {"starts":0, "wins":0, "finish_total":0, "best_finish":999}) as Dictionary
	type_data.starts = int(type_data.starts) + 1
	type_data.wins = int(type_data.wins) + (1 if result.finishing_position == 1 else 0)
	type_data.finish_total = int(type_data.finish_total) + result.finishing_position
	type_data.best_finish = mini(int(type_data.best_finish), result.finishing_position)
	type_records[type_id] = type_data
	records["track_types"] = type_records
	var series_records := records.series as Dictionary
	var series := series_records.get(result.race.series_id, {"starts":0, "wins":0, "podiums":0, "points":0, "championships":0}) as Dictionary
	series.starts = int(series.starts) + 1
	series.wins = int(series.wins) + (1 if result.finishing_position == 1 else 0)
	series.podiums = int(series.podiums) + (1 if result.finishing_position <= 3 else 0)
	series.points = int(series.points) + result.championship_points_earned
	series_records[result.race.series_id] = series


static func _update_stats(team, result) -> void:
	var stats := team.career_state.stats as Dictionary
	(stats.race_finishes as Array).append({"race":result.race.race_name, "finish":result.finishing_position, "start":result.starting_position, "season":team.current_season_year})
	(stats.cash as Array).append(team.money)
	(stats.fans as Array).append(team.fans)
	for key in ["race_finishes", "cash", "fans"]:
		var rows := stats[key] as Array
		if rows.size() > 50:
			rows.pop_front()


static func _update_rivalries(team, result) -> void:
	if result.standings.is_empty() or result.finishing_position <= 0:
		return
	var featured_id := str(team.career_state.get("featured_rival_id", ""))
	var nearest_index := clampi(result.finishing_position, 0, result.standings.size() - 1)
	var rival := result.standings[nearest_index] as Dictionary
	if bool(rival.get("is_player", false)) and nearest_index > 0:
		rival = result.standings[nearest_index - 1] as Dictionary
	if not featured_id.is_empty():
		for index in result.standings.size():
			var candidate := result.standings[index] as Dictionary
			if str(candidate.get("driver_id", "")) == featured_id and absi((index + 1) - result.finishing_position) <= 5:
				rival = candidate
				break
	var rival_id := str(rival.get("driver_id", rival.get("driver_name", "")))
	if rival_id.is_empty():
		return
	var rivalries := team.career_state.rivalries as Dictionary
	var data := rivalries.get(rival_id, {"name":rival.get("driver_name", "Rival"), "team":rival.get("team_name", ""), "intensity":10, "incidents":0, "defeats":0, "disputes":0, "encounters":0, "player_wins":0, "rival_wins":0, "streak":0, "history":[]}) as Dictionary
	_merge_defaults(data, {"encounters":0, "player_wins":0, "rival_wins":0, "streak":0, "history":[]})
	var player_incident := false
	for row_value in result.standings:
		var row := row_value as Dictionary
		if bool(row.get("is_player", false)):
			player_incident = float(row.get("incident_time_loss", 0.0)) > 0.0 or str(row.get("status", "Finished")) != "Finished"
			break
	data.intensity = clampi(int(data.intensity) + (10 if player_incident else (4 if result.positions_gained != 0 else 2)), 0, 100)
	data.encounters = int(data.encounters) + 1
	if player_incident:
		data.incidents = int(data.incidents) + 1
	var rival_position: int = result.standings.find(rival) + 1
	if rival_position > 0 and result.finishing_position < rival_position:
		data.defeats = int(data.defeats) + 1
		data.player_wins = int(data.player_wins) + 1
		data.streak = maxi(1, int(data.streak) + 1)
		data.last_result = "Won by %d place%s" % [rival_position - result.finishing_position, "" if rival_position - result.finishing_position == 1 else "s"]
	else:
		data.rival_wins = int(data.rival_wins) + 1
		data.streak = mini(-1, int(data.streak) - 1)
		data.last_result = "Lost by %d place%s" % [maxi(1, result.finishing_position - rival_position), "" if result.finishing_position - rival_position == 1 else "s"]
	(data.history as Array).push_front({"season":team.current_season_year, "race":result.race.race_name, "player_finish":result.finishing_position, "incident":player_incident})
	if (data.history as Array).size() > 16:
		(data.history as Array).resize(16)
	rivalries[rival_id] = data
	var current := rivalries.get(featured_id, {}) as Dictionary
	var current_score := int(current.get("intensity", 0)) + int(current.get("encounters", 0)) * 4
	var candidate_score := int(data.intensity) + int(data.encounters) * 4
	if featured_id.is_empty() or featured_id == rival_id or candidate_score >= current_score + 12:
		team.career_state["featured_rival_id"] = rival_id
		featured_id = rival_id
	result.rival_summary = "%s of %s is now the recurring rival · %s · series score %d–%d · intensity %d/100." % [str(data.name), str(data.team), str(data.last_result), int(data.player_wins), int(data.rival_wins), int(data.intensity)]
	if player_incident:
		add_news_item(team, "Rivalry", "%s rivalry tightens" % data.name, "A difficult race at %s raised the rivalry to %d intensity and put both drivers back in the spotlight." % [result.race.track_name, int(data.intensity)], 3)
		add_inbox_item(team, "Media", "Rivalry response requested", "The press wants a response after another tense weekend alongside %s." % data.name, [
			{"label":"Cool the situation", "effects":{"professionalism":3, "rivalry":-8}},
			{"label":"Keep the pressure on", "effects":{"commercial_appeal":3, "rivalry":8, "fans":45}}
		])


static func get_rivalry_modifiers(team) -> Dictionary:
	var maximum := 0
	for value in (ensure_state(team).rivalries as Dictionary).values():
		maximum = maxi(maximum, int((value as Dictionary).get("intensity", 0)))
	return {
		"maximum_intensity":maximum,
		"incident_scale":1.0 + minf(0.18, float(maximum) * 0.0018),
		"media_attention":maximum >= 55
	}


static func _update_driver_dynamics(team, result) -> void:
	var driver: Driver = result.player_driver
	if driver == null:
		return
	var incident := false
	var status := "Finished"
	for value in result.standings:
		var row := value as Dictionary
		if bool(row.get("is_player", false)):
			incident = float(row.get("incident_time_loss", 0.0)) > 0.0
			status = str(row.get("status", "Finished"))
			break
	var change := driver.apply_race_dynamics({"finish":result.finishing_position, "status":status, "incident":incident}, result.expected_finishing_position, result.team_order_summary)
	PersonalityCatalog.assign_identity(driver)
	var reaction_kind := "failure"
	if result.team_order_summary != "Race freely":
		reaction_kind = "team_order"
	elif result.finishing_position == 1:
		reaction_kind = "win"
	elif result.finishing_position <= result.expected_finishing_position:
		reaction_kind = "success"
	result.driver_personality = driver.get_personality_name()
	result.driver_reaction = PersonalityCatalog.reaction(driver, reaction_kind, {"season":team.current_season_year, "event":result.race.race_id, "race":result.race.race_name, "team":team.team_name})
	if result.finishing_position == 1 and driver.career_wins == 1:
		driver.remember_moment("First career win", "Won %s for %s." % [result.race.race_name, team.team_name], team.current_season_year, result.race.race_name)
	elif result.finishing_position == 1 and driver.age >= 34:
		driver.remember_moment("Veteran victory", "Won again at age %d." % driver.age, team.current_season_year, result.race.race_name)
	elif result.positions_gained >= 7:
		driver.remember_moment("Charge through the field", "Gained %d positions at %s." % [result.positions_gained, result.race.race_name], team.current_season_year, result.race.race_name)
	if abs(int(change.confidence_change)) >= 4 or bool(change.contract_uncertain):
		add_notification(team, "Driver", "%s's confidence changed" % driver.driver_name, "Form %d (%+d), confidence %d (%+d), morale %d." % [driver.form, int(change.form_change), driver.confidence, int(change.confidence_change), driver.morale])


static func _write_race_story(team, result) -> void:
	var player_row: Dictionary = {}
	for value in result.standings:
		var row := value as Dictionary
		if bool(row.get("is_player", false)):
			player_row = row
			break
	var status := str(player_row.get("status", "Finished"))
	var incident_loss := float(player_row.get("incident_time_loss", 0.0))
	if status != "Finished":
		result.authored_incident = "THE RADIO WENT QUIET · Warning signs became a retirement before the team could rescue the afternoon."
	elif incident_loss > 0.0:
		result.authored_incident = "THE LONG WAY BACK · A mistake in traffic cost %.1f seconds, leaving %s to rebuild the race one position at a time." % [incident_loss, result.player_driver.driver_name]
	elif result.pit_stop_factor <= -1.0:
		result.authored_incident = "A STOP TOO LONG · The pit lane turned a competitive run into a recovery drive."
	elif result.positions_gained >= 6:
		result.authored_incident = "THE CHARGE · From P%d on the grid, %s kept finding a way through and gained %d positions." % [result.starting_position, result.player_driver.driver_name, result.positions_gained]
	elif result.finishing_position == 1:
		result.authored_incident = "THE BREAKTHROUGH · Every decision held under pressure, and the final restart became a victory lap."
	else:
		result.authored_incident = "THE SMALL MARGINS · No single moment decided the race; setup, traffic and tyre life accumulated into P%d." % result.finishing_position
	var arcs := team.career_state.story_arcs as Array
	for arc_value in arcs:
		var arc := arc_value as Dictionary
		if str(arc.get("driver", "")) == result.player_driver.driver_name:
			result.storyline_summary = "%s · chapter %d · %s remains one of the season's running stories." % [str(arc.get("type", "Season story")), int(arc.get("momentum", 1)), result.player_driver.driver_name]
			break


static func _publish_race_news(team, result) -> void:
	var headline := "%s takes P%d at %s" % [result.player_driver.driver_name, result.finishing_position, result.race.track_name]
	var importance := 1
	if result.finishing_position == 1:
		headline = "%s wins at %s" % [result.player_driver.driver_name, result.race.track_name]
		importance = 3
	elif result.finishing_position <= 3:
		headline = "%s reaches the podium at %s" % [result.player_driver.driver_name, result.race.track_name]
		importance = 2
	var completed: int = team.get_completed_races().size()
	var season_length := int(SeriesCatalog.get_series(team.current_series_id).get("season_length", 12))
	var turning_point: bool = completed >= season_length / 2 and result.finishing_position <= 3
	add_news_item(team, "Championship" if turning_point else "Race", headline, "%s started P%d, finished P%d and earned %d championship points.%s" % [team.team_name, result.starting_position, result.finishing_position, result.championship_points_earned, " The result could prove pivotal in the title race." if turning_point else ""], maxi(importance, 3 if turning_point else 1))
	if result.sponsor_objective_completed:
		add_news_item(team, "Sponsor", "%s celebrates objective success" % result.sponsor_name, "The partner praised the team's result and released a $%s performance bonus." % String.num_int64(result.sponsor_objective_bonus), 2)
	elif not result.sponsor_name.is_empty() and result.finishing_position <= 3:
		add_news_item(team, "Sponsor", "%s welcomes the podium" % result.sponsor_name, "The result strengthened the commercial partnership and created a new activation opportunity.", 1)


static func _generate_press_conference(team, result) -> void:
	var subject := "Post-race press conference"
	var body := "Reporters want your reaction after finishing P%d at %s." % [result.finishing_position, result.race.track_name]
	add_inbox_item(team, "Media", subject, body, [
		{"label":"Praise the whole team", "effects":{"driver_morale":3, "staff_morale":3, "fans":20, "professionalism":2, "commercial_appeal":1, "sponsor":1, "rivalry":-1}},
		{"label":"Demand more performance", "effects":{"confidence":2, "driver_morale":-3, "staff_morale":-2, "sporting_credibility":2, "professionalism":-1, "rivalry":4}},
		{"label":"Entertain the fans", "effects":{"fans":60, "reputation":2, "commercial_appeal":3, "confidence":-1, "sponsor":2, "rivalry":2}}
	])


static func _generate_story_arc(team, result) -> void:
	var arcs := team.career_state.story_arcs as Array
	var kind := ""
	if result.starting_position - result.finishing_position >= 6:
		kind = "Comeback drive"
	elif result.finishing_position == 1 and result.starting_position <= 3:
		kind = "Dominant force"
	elif result.player_driver.age >= 34 and result.finishing_position <= 5:
		kind = "Veteran resurgence"
	elif result.player_driver.age <= 21 and result.finishing_position <= 5:
		kind = "Wonderkid breakthrough"
	if kind.is_empty():
		return
	for arc_value in arcs:
		var existing := arc_value as Dictionary
		if str(existing.get("type", "")) == kind and str(existing.get("driver", "")) == result.player_driver.driver_name and int(existing.get("season", 0)) == team.current_season_year:
			existing.momentum = int(existing.get("momentum", 1)) + 1
			existing.race = result.race.race_name
			result.storyline_summary = "%s · chapter %d · %s added another memorable result at %s." % [kind, int(existing.momentum), result.player_driver.driver_name, result.race.race_name]
			return
	arcs.push_front({"type":kind, "driver":result.player_driver.driver_name, "race":result.race.race_name, "season":team.current_season_year, "momentum":1})
	result.storyline_summary = "%s begins · %s at %s." % [kind, result.player_driver.driver_name, result.race.race_name]
	add_notification(team, "Story", kind, "%s is becoming a paddock talking point." % result.player_driver.driver_name)


static func _process_sponsor_and_merchandise(team, result) -> void:
	var merchandise := team.career_state.merchandise as Dictionary
	var demand: int = maxi(0, 12 - int(result.finishing_position)) * 3 + int(result.fans_earned)
	merchandise.popularity = maxi(0, int(merchandise.popularity) + demand)
	var revenue := mini(int(merchandise.stock), demand) * int(merchandise.price)
	merchandise.stock = maxi(0, int(merchandise.stock) - demand)
	merchandise.last_revenue = revenue
	if revenue > 0:
		team.money += revenue
		team.record_finance("Merchandise", revenue, "Race-week merchandise sales")
	SponsorManager.ensure_state(team)
	if result.finishing_position <= 5 and not team.active_sponsor_contract.is_empty():
		var contract: Dictionary = team.active_sponsor_contract
		var activations := team.career_state.sponsor_activations as Array
		var activation_type := "Hospitality" if result.finishing_position == 1 else (
			"Product campaign" if str(contract.profile) == "GROWTH" else (
				"Community event" if result.finishing_position <= 3 else "Driver appearance"
			)
		)
		var activation_value := maxi(250, roundi(float(int(contract.payment_per_race)) * 0.55) + demand * 10)
		activations.push_front({
			"event": "%s: %s" % [str(contract.sponsor_name), activation_type],
			"type": activation_type,
			"sponsor_id": str(contract.sponsor_id),
			"sponsor_name": str(contract.sponsor_name),
			"value": activation_value,
			"fans": 55 if activation_type == "Community event" else 30,
			"morale_cost": 1 if activation_type == "Hospitality" else 2,
			"requirement": "Active driver and sponsor-forward branding" if activation_type == "Product campaign" else "Team availability",
			"deadline": mini(CalendarCatalog.SEASON_END_DAY, team.current_season_day + 14),
			"completed": false,
			"declined": false,
			"season": team.current_season_year
		})


static func order_merchandise(team, quantity: int) -> bool:
	if quantity <= 0:
		return false
	var cost := quantity * 10
	if team.money < cost:
		return false
	team.money -= cost
	var merchandise := ensure_state(team).merchandise as Dictionary
	merchandise.stock = int(merchandise.stock) + quantity
	team.record_finance("Merchandise", -cost, "Order team merchandise")
	team.emit_changed()
	return true


static func complete_sponsor_activation(team, index: int) -> bool:
	var activations := ensure_state(team).sponsor_activations as Array
	if index < 0 or index >= activations.size():
		return false
	var activation := activations[index] as Dictionary
	if bool(activation.completed) or bool(activation.get("declined", false)):
		return false
	if team.current_season_day > int(activation.get("deadline", CalendarCatalog.SEASON_END_DAY)):
		return false
	activation.completed = true
	var value := int(activation.value)
	var game_manager: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if game_manager != null:
		game_manager.call("add_team_money", value)
	else:
		team.money += value
	team.fans += int(activation.get("fans", 25))
	var driver: Driver = team.get_active_driver()
	if driver != null:
		driver.morale = maxi(0, driver.morale - int(activation.get("morale_cost", 1)))
	SponsorManager.adjust_relationship(team, str(activation.sponsor_id), 4)
	SponsorManager.add_activation_progress(team, str(activation.sponsor_id))
	ReputationManager.apply_changes(
		team, 1, 0, 1, 3,
		"Completed %s for %s" % [str(activation.type), str(activation.sponsor_name)],
		"Sponsor activation"
	)
	team.record_finance("Sponsor activation", value, str(activation.event))
	add_notification(team, "Sponsor", "Activation completed", "+$%s, fan growth and stronger partner relations" % value)
	team.emit_changed()
	return true


static func decline_sponsor_activation(team, index: int) -> bool:
	var activations := ensure_state(team).sponsor_activations as Array
	if index < 0 or index >= activations.size():
		return false
	var activation := activations[index] as Dictionary
	if bool(activation.completed) or bool(activation.get("declined", false)):
		return false
	activation.declined = true
	SponsorManager.adjust_relationship(team, str(activation.sponsor_id), -3)
	ReputationManager.apply_changes(
		team, 0, 0, -1, -2,
		"Declined an activation for %s" % str(activation.sponsor_name),
		"Sponsor activation"
	)
	add_notification(team, "Sponsor", "Activation declined", "Preparation time preserved, but the partner relationship cooled.")
	team.emit_changed()
	return true


static func _process_injury_risk(team, result) -> void:
	if result.player_driver == null:
		return
	var retired := false
	if result.finishing_position > 0 and result.finishing_position <= result.standings.size():
		retired = str((result.standings[result.finishing_position - 1] as Dictionary).get("status", "")) == "Retired"
	var risk := 0.02 + float(result.player_driver.fatigue) * 0.0006 + (0.04 if retired else 0.0)
	if randf() < risk:
		create_injury(team, result.player_driver, "Moderate" if retired else "Minor")


static func _process_stewarding(team, result, simulation) -> void:
	var cases := team.career_state.stewarding.cases as Array
	if simulation == null:
		return
	var player: RaceEntryState = simulation.get_player_entry()
	if player == null:
		return
	if player.incident_time_loss > 0.0 and randf() < 0.18:
		var penalty := 5
		var case := {"race":result.race.race_name, "reason":"Avoidable contact", "penalty":"%d championship points" % penalty, "points":penalty, "appealable":true, "status":"Applied"}
		cases.push_front(case)
		result.championship_points_earned = maxi(0, result.championship_points_earned - penalty)
		result.penalties.append(case)
		ReputationManager.apply_changes(
			team, 0, -1, -6, -1,
			"Received a stewarding penalty for avoidable contact",
			"Stewarding"
		)
		add_inbox_item(team, "Stewarding", "Post-race penalty", "Race control issued a %d-point penalty for avoidable contact. The decision may be appealed." % penalty)


static func _process_team_politics(team, result) -> void:
	var order: String = str(result.team_order_summary)
	for race_team in team.race_teams:
		race_team.team_orders = order
	var relationships := ensure_state(team).relationships as Dictionary
	if order == "Race freely":
		for key in relationships:
			var data := relationships[key] as Dictionary
			data.score = mini(100, int(data.score) + 1)
		return
	for key in relationships:
		var data := relationships[key] as Dictionary
		data.orders = int(data.orders) + 1
		data.score = clampi(int(data.score) + (-3 if order in ["Hold position", "Swap positions"] else 1), 0, 100)
	for driver in team.get_contracted_drivers():
		if driver.expected_role == "Lead" and order == "Help lead car":
			driver.morale = mini(99, driver.morale + 3)
		elif order in ["Hold position", "Swap positions"]:
			driver.morale = maxi(0, driver.morale - 2)


static func _process_logistics_damage(team, result) -> void:
	var logistics := ensure_state(team).logistics as Dictionary
	if result.condition_lost >= 8:
		if int(logistics.spare_cars) > 0:
			logistics.spare_cars = int(logistics.spare_cars) - 1
			add_notification(team, "Logistics", "Spare car allocated", "Heavy weekend damage consumed one spare car.")
		else:
			logistics.damaged_inventory = int(logistics.damaged_inventory) + 1
			add_inbox_item(team, "Logistics", "Equipment shortage", "Heavy damage added to the workshop backlog. Travel readiness and cash flow are at risk.")


static func appeal_latest_penalty(team) -> bool:
	var stewarding := ensure_state(team).stewarding as Dictionary
	for value in stewarding.cases:
		var case := value as Dictionary
		if bool(case.get("appealable", false)) and str(case.status) == "Applied":
			var cost := 1500
			if team.money < cost:
				return false
			team.money -= cost
			var successful := randf() < 0.38
			case.status = "Overturned" if successful else "Upheld"
			(stewarding.appeals as Array).push_front(case.duplicate(true))
			add_inbox_item(team, "Stewarding", "Appeal decision", "The penalty was %s." % case.status.to_lower())
			team.record_finance("Legal", -cost, "Stewarding appeal")
			team.emit_changed()
			return true
	return false


static func process_season_end(team, finishing_position: int) -> void:
	var state := ensure_state(team)
	if int(state.season_processed) == team.current_season_year:
		return
	state.season_processed = team.current_season_year
	var board := state.board as Dictionary
	for target_value in board.targets:
		var target := target_value as Dictionary
		match str(target.get("kind", target.get("id", ""))):
			"championship":
				target.progress = finishing_position
				target.complete = finishing_position <= int(target.target)
			"finance":
				target.progress = team.money
				target.complete = team.money >= int(target.target)
			"driver_development":
				var driver: Driver = team.get_driver_by_id(str(target.get("driver_id", "")))
				if driver == null:
					driver = team.get_active_driver()
				var gain := maxi(0, driver.get_overall_rating() - int(target.get("baseline", driver.get_overall_rating()))) if driver != null else 0
				target.progress = gain
				target.complete = gain >= int(target.target)
			"promotion":
				var series_index := SeriesCatalog.get_index(team.current_series_id)
				target.progress = series_index
				target.complete = series_index >= int(target.target)
	var met := 0
	var reviewed := 0
	var retained: Array = []
	var history := board.get("history", []) as Array
	for target_value in board.targets:
		var target := target_value as Dictionary
		if int(target.get("deadline_year", team.current_season_year)) > team.current_season_year:
			retained.append(target)
			continue
		reviewed += 1
		target.status = "Complete" if bool(target.get("complete", false)) else "Failed"
		if bool(target.complete):
			met += 1
		var archived := target.duplicate(true)
		archived["reviewed_year"] = team.current_season_year
		history.push_front(archived)
	if history.size() > 30:
		history.resize(30)
	board.history = history
	var confidence_delta := (met * 6) - ((reviewed - met) * 5)
	board.confidence = clampi(int(board.confidence) + confidence_delta, 0, 100)
	board.job_security = clampi(int(board.job_security) + confidence_delta, 0, 100)
	board.owner_patience = clampi(int(board.owner_patience) + signi(confidence_delta) * 3, 0, 100)
	board.last_review = "%d of %d due objectives met; board confidence %d%%. %d multi-season objective%s remain active." % [met, reviewed, board.confidence, retained.size(), "" if retained.size() == 1 else "s"]
	board.annual_reviewed_year = team.current_season_year
	board.targets = retained
	_generate_awards(team, finishing_position)
	_develop_academy_season(team)
	_generate_regulation(team)
	_evolve_world(team)
	_generate_manufacturer_offers(team)
	board["funding_used"] = false
	board["funding"] = 0
	add_inbox_item(team, "Board", "Season review", str(board.last_review))
	add_news_item(team, "Board", "Ownership completes its season review", str(board.last_review), 3 if confidence_delta < 0 else 2)
	team.emit_changed()


static func _generate_awards(team, finishing_position: int) -> void:
	var awards := team.career_state.awards as Array
	var driver: Driver = team.get_active_driver()
	var season_awards: Array[String] = []
	if finishing_position == 1:
		season_awards.append("Team of the Year")
	if driver != null and driver.age <= 22 and finishing_position <= 5:
		season_awards.append("Rookie of the Year")
	if driver != null and driver.race_history.size() >= 2:
		season_awards.append("Fan Favourite" if driver.marketability >= 65 else "Most Improved Driver")
	for award in season_awards:
		awards.push_front({"season":team.current_season_year, "award":award, "recipient":team.team_name if "Team" in award else driver.driver_name})
	if driver != null and (driver.championships >= 3 or driver.career_wins >= 20):
		var hall := team.career_state.hall_of_fame as Array
		var exists := false
		for entry in hall:
			if str((entry as Dictionary).get("driver_id", "")) == driver.driver_id:
				exists = true
		if not exists:
			hall.append({"driver_id":driver.driver_id, "name":driver.driver_name, "wins":driver.career_wins, "championships":driver.championships, "retired_number":driver.preferred_number})


static func _develop_academy_season(team) -> void:
	var academy := team.career_state.academy as Dictionary
	for value in academy.enrolled:
		var prospect := value as Dictionary
		prospect.seasons = int(prospect.seasons) + 1
		prospect.age = int(prospect.age) + 1
		var gain := randi_range(1, 4) + get_facility_level(team, "driver_academy")
		prospect.overall = mini(int(prospect.hidden_potential), int(prospect.overall) + gain)
		var finish := randi_range(1, 20)
		(academy.junior_results as Array).push_front({"season":team.current_season_year, "driver":prospect.name, "position":finish, "points":int(prospect.junior_points)})
	academy.prospects = []
	_ensure_academy_prospects(team)


static func _generate_regulation(team) -> void:
	var regulations := team.career_state.regulations as Dictionary
	if not (regulations.next as Dictionary).is_empty():
		(regulations.history as Array).push_front(regulations.current.duplicate(true))
		regulations.current = regulations.next.duplicate(true)
		var reset := int(regulations.current.get("performance_reset", 0))
		var applied := 0
		for car_value in team.cars:
			var car: Resource = car_value as Resource
			if car == null:
				continue
			for part in car.installed_parts:
				if part != null and reset > 0:
					var loss := mini(part.base_performance_points - 1, ceili(float(reset) / float(CarPart.PART_TYPES.size())))
					part.base_performance_points = maxi(1, part.base_performance_points - loss)
					applied += maxi(0, loss)
		for part in team.parts_inventory:
			if part != null and reset > 0:
				part.base_performance_points = maxi(1, part.base_performance_points - ceili(float(reset) / float(CarPart.PART_TYPES.size())))
		if applied > 0:
			add_inbox_item(team, "Regulations", "Technical reset applied", "The new %s rules removed %d installed performance points and forced a redesign." % [regulations.current.focus, applied])
	var focuses := ["Engine efficiency", "Aerodynamic simplicity", "Cost control", "Reliability", "Tyre conservation"]
	var focus: String = str(focuses[randi_range(0, focuses.size() - 1)])
	regulations.next = {"name":"%d technical regulations" % (team.current_season_year + 1), "performance_reset":randi_range(2, 10), "focus":focus}
	add_inbox_item(team, "Regulations", "Future regulations published", "%s will emphasize %s and may reset up to %d performance points." % [regulations.next.name, focus, regulations.next.performance_reset])


static func _ensure_world_entrants(team) -> void:
	var entrants := team.career_state.get("world_entrants", []) as Array
	if not entrants.is_empty():
		return
	for series_id in CAREER_SERIES_IDS:
		entrants.append({"id":"independent_%s" % series_id, "name":"Independent Racing %s" % (entrants.size() + 1), "series_id":series_id, "status":"Active", "budget":randi_range(28000, 90000), "performance":randi_range(40, 68), "seasons":1})


static func _evolve_world(team) -> void:
	var state: Dictionary = team.career_state
	for entrant_value in state.world_entrants:
		var entrant := entrant_value as Dictionary
		entrant.seasons = int(entrant.seasons) + 1
		entrant.budget = maxi(0, int(entrant.budget) + randi_range(-18000, 24000))
		entrant.performance = clampi(int(entrant.performance) + randi_range(-4, 5), 25, 92)
		if int(entrant.budget) <= 5000:
			var outcome: String = str(["Folded and replaced", "Merged", "Rebranded"][randi_range(0, 2)])
			entrant.status = outcome
			entrant.name = "%s Motorsport" % LAST_NAMES[randi_range(0, LAST_NAMES.size() - 1)]
			entrant.budget = 30000
		elif int(entrant.performance) >= 82:
			entrant.status = "Promotion contender"
	var alliances := state.alliances as Array
	alliances.clear()
	var entrants := state.world_entrants as Array
	if entrants.size() >= 2:
		alliances.append({"teams":[(entrants[0] as Dictionary).name, (entrants[1] as Dictionary).name], "manufacturer":"Orion Performance", "focus":"Shared engine technology", "season":team.current_season_year + 1})
	var ai_team_ids: Array = team.ai_team_career.keys()
	if ai_team_ids.size() >= 2:
		var first_team := team.ai_team_career[ai_team_ids[0]] as Dictionary
		var second_team := team.ai_team_career[ai_team_ids[1]] as Dictionary
		first_team["manufacturer_alliance"] = "Orion Performance"
		second_team["manufacturer_alliance"] = "Orion Performance"
		first_team["engineering_rating"] = mini(100, int(first_team.get("engineering_rating", 50)) + 2)
		second_team["engineering_rating"] = mini(100, int(second_team.get("engineering_rating", 50)) + 2)
		alliances.append({"teams":[first_team.get("team_name", "AI Team 1"), second_team.get("team_name", "AI Team 2")], "manufacturer":"Orion Performance", "focus":"Shared engine technology", "season":team.current_season_year + 1})
	if not team.ai_team_career.is_empty():
		var lowest_id := str(team.ai_team_career.keys()[0])
		for team_id in team.ai_team_career:
			if int((team.ai_team_career[team_id] as Dictionary).get("budget", 0)) < int((team.ai_team_career[lowest_id] as Dictionary).get("budget", 0)):
				lowest_id = str(team_id)
		var lowest := team.ai_team_career[lowest_id] as Dictionary
		if int(lowest.get("budget", 0)) < 12000:
			lowest.team_name = "%s Racing" % LAST_NAMES[randi_range(0, LAST_NAMES.size() - 1)]
			lowest.budget = 30000
			lowest.trend = -2.0
		var leader_id := str(team.ai_team_career.keys()[0])
		for team_id in team.ai_team_career:
			if int((team.ai_team_career[team_id] as Dictionary).get("equipment_rating", 0)) > int((team.ai_team_career[leader_id] as Dictionary).get("equipment_rating", 0)):
				leader_id = str(team_id)
		var leader := team.ai_team_career[leader_id] as Dictionary
		(state.story_arcs as Array).push_front({"type":"Dominant rival" if int(leader.get("trend", 0)) >= 0 else "Surprise contender", "driver":leader.get("team_name", "AI Team"), "race":"Season forecast", "season":team.current_season_year + 1, "momentum":int(leader.get("trend", 0))})
	var variations := state.calendar_variations as Dictionary
	var tracks := ["Harbor Street Circuit", "Mountain Ring", "Desert Speedway", "Coastal Raceway", "Lakeside International"]
	variations[str(team.current_season_year + 1)] = {"added":tracks[randi_range(0, tracks.size() - 1)], "removed":"One rotating venue", "invitation":"International All-Star 100", "date_shift":randi_range(-7, 7)}
	var international := state.international as Dictionary
	var markets := international.markets as Dictionary
	for region in REGIONS:
		var data := markets.get(region, {"fans":0, "reputation":0, "travel_cost":randi_range(2500, 9000)}) as Dictionary
		data.fans = int(data.fans) + randi_range(0, maxi(10, team.fans / 20))
		markets[region] = data


static func launch_international_program(team, region: String, discipline: String) -> bool:
	var international := ensure_state(team).international as Dictionary
	var market := (international.markets as Dictionary).get(region, {"fans":0, "reputation":0, "travel_cost":5000}) as Dictionary
	var cost := int(market.travel_cost)
	if team.money < cost:
		return false
	team.money -= cost
	team.record_finance("International", -cost, "%s expansion" % region)
	(international.programs as Array).push_front({"region":region, "discipline":discipline, "season":team.current_season_year, "status":"Active"})
	if not (international.disciplines as Array).has(discipline):
		(international.disciplines as Array).append(discipline)
	market.fans = int(market.fans) + 150
	market.reputation = int(market.reputation) + 5
	(international.markets as Dictionary)[region] = market
	add_inbox_item(team, "World", "International programme launched", "%s operations are now active in %s." % [discipline, region])
	team.emit_changed()
	return true


static func _generate_manufacturer_offers(team) -> void:
	var manufacturer := team.career_state.manufacturer as Dictionary
	var offers := manufacturer.offers as Array
	offers.clear()
	var leverage: int = (
		team.get_reputation_level() * 220
		+ ReputationManager.get_dimension(team, "sporting_credibility") * 12
		+ ReputationManager.get_dimension(team, "professionalism") * 8
	)
	for index in 3:
		offers.append({
			"partner": ["Orion", "Apex", "Vanguard"][index],
			"support": 45 + index * 15,
			"exclusivity": index == 2,
			"cost": maxi(1000, 7500 - leverage - index * 900)
		})


static func update_finance_forecast(team) -> Dictionary:
	var state: Dictionary = team.career_state
	var forecast := FinanceManager.build_forecast(team)
	state.finance_forecast = forecast
	return forecast


static func configure_race_weekend(team, race: Race) -> Dictionary:
	var state := ensure_state(team)
	var seed_value := hash("%s:%s:%d" % [race.race_id, team.current_season_year, team.current_race_week])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weather: String = str(["Dry", "Dry", "Dry", "Mixed", "Wet"][rng.randi_range(0, 4)])
	if race.is_oval():
		weather = "Dry"
	elif race.weather == "Wet":
		weather = "Wet"
	var formats := ["Standard", "Knockout", "Groups", "Heat races", "Provisionals"]
	var format: String = str(formats[(race.season_round + team.current_season_year) % formats.size()])
	var rain_chance := 0 if race.is_oval() else (15 if weather == "Dry" else (55 if weather == "Mixed" else 88))
	var forecast := {"weather":weather, "rain_chance":rain_chance, "temperature":rng.randi_range(14, 34), "confidence":rng.randi_range(62, 94)}
	state.race_weekend = {"forecast":forecast, "qualifying_format":format, "team_order":"Race freely"}
	return state.race_weekend


static func get_race_modifiers(team) -> Dictionary:
	var state := ensure_state(team)
	var rd_effects := state.rd.effects as Dictionary
	var design := get_car_design_modifiers(team)
	var manufacturer := state.manufacturer as Dictionary
	var logistics := state.logistics as Dictionary
	var resource_policy := str((state.resource_allocations as Dictionary).get("policy", "Equal"))
	var travel_reliability := 3.0 if str(logistics.travel_plan) == "Performance" else (-2.0 if str(logistics.travel_plan) == "Economy" else 0.0)
	var lead_bonus := 1.2 if resource_policy in ["Lead car", "Championship contender"] else 0.0
	return {
		"power":float(rd_effects.get("power", 0)) + float(design.power) + lead_bonus,
		"grip":float(rd_effects.get("grip", 0)) + float(design.grip) + lead_bonus,
		"fuel":float(rd_effects.get("fuel", 0)),
		"tyres":float(rd_effects.get("tyres", 0)),
		"reliability":float(rd_effects.get("reliability", 0)) + float(design.reliability) + float(manufacturer.support) * 0.03 + travel_reliability,
		"tyre_wear":float(design.tyre_wear),
		"setup_accuracy":get_facility_level(team, "simulator") * 2,
		"pit_loss":get_facility_level(team, "quality_lab") * 0.12
	}


static func set_branding(team, branding: Dictionary) -> void:
	var target := ensure_state(team).branding as Dictionary
	for key in branding:
		target[key] = branding[key]
	team.emit_changed()


static func set_accessibility(team, values: Dictionary) -> void:
	var target := ensure_state(team).accessibility as Dictionary
	for key in values:
		target[key] = values[key]
	target.ui_scale = clampf(float(target.ui_scale), 0.8, 1.5)
	target.simulation_speed = clampf(float(target.simulation_speed), 0.5, 4.0)
	apply_accessibility(team)
	team.emit_changed()


static func apply_accessibility(team) -> void:
	var accessibility := ensure_state(team).accessibility as Dictionary
	var root := Engine.get_main_loop() as SceneTree
	if root == null:
		return
	root.root.content_scale_factor = clampf(float(accessibility.ui_scale), 0.8, 1.5)


static func get_unread_count(team) -> int:
	var total := 0
	var state := ensure_state(team)
	for value in state.inbox:
		if not bool((value as Dictionary).get("read", false)):
			total += 1
	for value in state.notifications:
		if not bool((value as Dictionary).get("read", false)):
			total += 1
	return total


static func mark_all_read(team) -> void:
	var state := ensure_state(team)
	for value in state.inbox:
		(value as Dictionary)["read"] = true
	for value in state.notifications:
		(value as Dictionary)["read"] = true
	team.emit_changed()
