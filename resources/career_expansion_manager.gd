extends RefCounted
class_name CareerExpansionManager

const STATE_VERSION: int = 1
const MAX_INBOX_ITEMS: int = 80
const MAX_NOTIFICATIONS: int = 120

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
		"notifications":[],
		"notification_preferences":{"Contracts":true, "Repairs":true, "Projects":true, "Sponsors":true, "Race":true, "Board":true},
		"board":{
			"confidence":72,
			"job_security":78,
			"owner_patience":70,
			"funding":0,
			"targets":[],
			"last_review":"No review yet"
		},
		"rivalries":{},
		"processed_transfers":[],
		"press_history":[],
		"story_arcs":[],
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
		"merchandise":{"popularity":0, "stock":0, "price":25, "regional_fans":{}, "last_revenue":0},
		"finance_forecast":{},
		"calendar_variations":{},
		"records":{"tracks":{}, "series":{}, "all_time":{}},
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


static func ensure_state(team: Team) -> Dictionary:
	if team.career_state == null:
		team.career_state = {}
	_merge_defaults(team.career_state, defaults())
	team.career_state["version"] = STATE_VERSION
	_ensure_board_targets(team)
	_ensure_academy_prospects(team)
	_ensure_staff_dynamics(team)
	_ensure_relationships(team)
	_ensure_world_entrants(team)
	_ensure_transfer_rivalries(team)
	_update_tutorial_progress(team)
	update_finance_forecast(team)
	return team.career_state


static func _merge_defaults(target: Dictionary, template: Dictionary) -> void:
	for key in template:
		var fallback: Variant = template[key]
		if not target.has(key) or target[key] == null:
			target[key] = fallback.duplicate(true) if fallback is Dictionary or fallback is Array else fallback
		elif fallback is Dictionary and target[key] is Dictionary:
			_merge_defaults(target[key], fallback)


static func add_notification(team: Team, category: String, title: String, body: String, urgent: bool = false) -> void:
	var state := ensure_state(team)
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


static func set_notification_preference(team: Team, category: String, enabled: bool) -> void:
	var preferences := ensure_state(team).notification_preferences as Dictionary
	if preferences.has(category):
		preferences[category] = enabled
		team.emit_changed()


static func _update_tutorial_progress(team: Team) -> void:
	var tutorial := team.career_state.get("tutorial", {}) as Dictionary
	if not bool(tutorial.get("enabled", true)):
		return
	var completed := tutorial.get("completed_steps", []) as Array
	if not team.get_contracted_drivers().is_empty() and not completed.has("hire_driver"):
		completed.append("hire_driver")
	var has_car := false
	for car_value in team.cars:
		if car_value is Car:
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


static func add_inbox_item(team: Team, category: String, subject: String, body: String, choices: Array = []) -> void:
	var state := ensure_state(team)
	var inbox := state.inbox as Array
	inbox.push_front({
		"id":"mail_%d_%d" % [Time.get_unix_time_from_system(), inbox.size()],
		"category":category,
		"subject":subject,
		"body":body,
		"choices":choices.duplicate(true),
		"resolved":choices.is_empty(),
		"read":false,
		"season":team.current_season_year,
		"day":team.current_season_day
	})
	if inbox.size() > MAX_INBOX_ITEMS:
		inbox.resize(MAX_INBOX_ITEMS)
	add_notification(team, category, subject, body, not choices.is_empty())


static func resolve_inbox(team: Team, item_id: String, choice_index: int) -> bool:
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


static func _apply_effects(team: Team, effects: Dictionary) -> void:
	var state := ensure_state(team)
	var board := state.board as Dictionary
	for key in effects:
		var amount := int(effects[key])
		match str(key):
			"money":
				team.money += amount
				team.record_finance("Decision", amount, "Team principal decision")
			"reputation": team.add_reputation_xp(amount)
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


static func _ensure_board_targets(team: Team) -> void:
	var board := team.career_state.get("board", {}) as Dictionary
	var targets := board.get("targets", []) as Array
	if not targets.is_empty():
		return
	var expected_finish := 8
	if team.last_season_position > 0:
		expected_finish = maxi(1, team.last_season_position)
	targets.append({"id":"championship", "label":"Finish P%d or better" % expected_finish, "target":expected_finish, "progress":0, "complete":false})
	targets.append({"id":"finance", "label":"Keep at least $10,000 available", "target":10000, "progress":team.money, "complete":team.money >= 10000})
	targets.append({"id":"development", "label":"Complete one R&D programme", "target":1, "progress":0, "complete":false})
	board["targets"] = targets


static func process_day(team: Team, elapsed_days: int) -> Array[String]:
	var state := ensure_state(team)
	var summaries: Array[String] = []
	_process_rd(team, elapsed_days, summaries)
	_process_construction(team, elapsed_days, summaries)
	_process_injuries(team, elapsed_days, summaries)
	_process_academy(team, elapsed_days, summaries)
	_process_scouting_network(team, elapsed_days, summaries)
	_process_staff(team, elapsed_days, summaries)
	_apply_upkeep(team, elapsed_days, summaries)
	_generate_paddock_event(team, elapsed_days)
	update_finance_forecast(team)
	return summaries


static func _process_rd(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func start_rd_project(team: Team, node_id: String) -> bool:
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
	var cost := team.get_discounted_cost(int(node.cost))
	if team.money < cost:
		return false
	team.money -= cost
	team.record_finance("R&D", -cost, str(node.name))
	var speed_bonus := get_facility_level(team, "design_office") * 0.08
	(rd.projects as Array).append({"node_id":node_id, "days_remaining":maxi(7, roundi(float(node.days) * (1.0 - speed_bonus)))})
	add_notification(team, "Engineering", "R&D started", str(node.name))
	team.emit_changed()
	return true


static func set_car_design(team: Team, philosophy: String, speed: int, handling: int, endurance: int) -> bool:
	if speed + handling + endurance != 100 or mini(speed, mini(handling, endurance)) < 10:
		return false
	var design := ensure_state(team).car_design as Dictionary
	design["philosophy"] = philosophy
	design["speed"] = speed
	design["handling"] = handling
	design["endurance"] = endurance
	team.emit_changed()
	return true


static func get_car_design_modifiers(team: Team) -> Dictionary:
	var design := ensure_state(team).car_design as Dictionary
	return {
		"power":(float(design.speed) - 33.0) * 0.06,
		"grip":(float(design.handling) - 33.0) * 0.06,
		"reliability":(float(design.endurance) - 33.0) * 0.10,
		"tyre_wear":-(float(design.endurance) - 33.0) * 0.035
	}


static func apply_manufacturing_quality(team: Team, part: CarPart) -> String:
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


static func _process_construction(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func start_facility_upgrade(team: Team, facility_id: String) -> bool:
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


static func get_facility_level(team: Team, facility_id: String) -> int:
	if team == null or not team.career_state.has("facilities"):
		return 0
	var facilities := team.career_state.facilities as Dictionary
	return int((facilities.get(facility_id, {}) as Dictionary).get("level", 0))


static func _apply_upkeep(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func _ensure_academy_prospects(team: Team) -> void:
	var academy := team.career_state.get("academy", {}) as Dictionary
	var prospects := academy.get("prospects", []) as Array
	while prospects.size() < 6:
		prospects.append(_generate_prospect(team, prospects.size()))


static func _generate_prospect(team: Team, offset: int) -> Dictionary:
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


static func recruit_academy_prospect(team: Team, prospect_id: String) -> bool:
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


static func _process_academy(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func _process_scouting_network(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func _generate_paddock_event(team: Team, elapsed_days: int) -> void:
	if elapsed_days < 7 or randf() > 0.22 * float(elapsed_days) / 7.0:
		return
	var contracted := team.get_contracted_drivers()
	var event_index := randi_range(0, 2)
	if event_index == 0 and not contracted.is_empty():
		var driver: Driver = contracted[randi_range(0, contracted.size() - 1)]
		add_inbox_item(team, "Driver", "%s requests a conversation" % driver.driver_name, "The driver wants clarity on their role and the team's development direction.", [
			{"label":"Promise equal support", "effects":{"driver_morale":5, "confidence":-1}},
			{"label":"Set firm expectations", "effects":{"driver_morale":-3, "confidence":2}}
		])
	elif event_index == 1:
		add_inbox_item(team, "Sponsor", "Sponsor appearance request", "A partner wants a driver and show car at a regional fan event.", [
			{"label":"Attend the event", "cost":600, "effects":{"fans":80, "sponsor":3, "driver_morale":-1}},
			{"label":"Decline and focus on racing", "effects":{"sponsor":-2, "staff_morale":2}}
		])
	else:
		add_inbox_item(team, "Paddock", "Rival team approaches your staff", "A competitor has been seen speaking with a member of your technical department.", [
			{"label":"Offer loyalty bonuses", "cost":1800, "effects":{"staff_morale":6, "confidence":1}},
			{"label":"Trust the existing contracts", "effects":{"staff_morale":-2}}
		])


static func promote_academy_driver(team: Team, prospect_id: String) -> Driver:
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


static func assign_scouting_region(team: Team, region: String) -> bool:
	var network := ensure_state(team).scouting_network as Dictionary
	if not (network.regions as Dictionary).has(region):
		return false
	network["assigned_region"] = region
	((network.regions as Dictionary)[region] as Dictionary)["assignment"] = "Talent search"
	add_notification(team, "Scouting", "Regional search assigned", region)
	team.emit_changed()
	return true


static func upgrade_scouting_region(team: Team, region: String) -> bool:
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


static func get_uncertain_prospect_rating(team: Team, prospect: Dictionary) -> Dictionary:
	var accuracy := int((ensure_state(team).scouting_network as Dictionary).accuracy)
	var uncertainty := maxi(1, roundi(float(100 - accuracy) * 0.16))
	return {
		"overall_low":maxi(1, int(prospect.overall) - uncertainty),
		"overall_high":mini(99, int(prospect.overall) + uncertainty),
		"potential_low":maxi(1, int(prospect.hidden_potential) - uncertainty * 2),
		"potential_high":mini(99, int(prospect.hidden_potential) + uncertainty * 2)
	}


static func _ensure_relationships(team: Team) -> void:
	var relationships := team.career_state.get("relationships", {}) as Dictionary
	var contracted := team.get_contracted_drivers()
	for first_index in contracted.size():
		for second_index in range(first_index + 1, contracted.size()):
			var first: Driver = contracted[first_index]
			var second: Driver = contracted[second_index]
			var key := _pair_key(first.driver_id, second.driver_id)
			if not relationships.has(key):
				relationships[key] = {"score":55, "type":"Professional", "mentor":"", "incidents":0, "orders":0}


static func _ensure_transfer_rivalries(team: Team) -> void:
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
	if processed.size() > 100:
		processed.resize(100)


static func _pair_key(first: String, second: String) -> String:
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]


static func set_mentorship(team: Team, mentor_id: String, prospect_id: String) -> bool:
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


static func _process_injuries(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
	var injuries := team.career_state.injuries as Array
	var recovered: Array = []
	var recovery_bonus := get_facility_level(team, "medical_centre")
	for value in injuries:
		var injury := value as Dictionary
		injury["days_remaining"] = maxi(0, int(injury.days_remaining) - elapsed_days - recovery_bonus)
		var driver := team.get_driver_by_id(str(injury.driver_id))
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


static func create_injury(team: Team, driver: Driver, severity: String = "Minor") -> void:
	if driver == null:
		return
	var days: int = int({"Minor":7, "Moderate":21, "Serious":42}.get(severity, 7))
	driver.availability_status = "Injured"
	driver.unavailable_weeks = ceili(float(days) / 7.0)
	(ensure_state(team).injuries as Array).append({"driver_id":driver.driver_id, "driver_name":driver.driver_name, "severity":severity, "days_remaining":days})
	add_inbox_item(team, "Medical", "%s injury" % severity, "%s will miss approximately %d week(s). A reserve driver may be required." % [driver.driver_name, driver.unavailable_weeks])


static func _ensure_staff_dynamics(team: Team) -> void:
	var dynamics := team.career_state.get("staff_dynamics", {}) as Dictionary
	for member in team.staff:
		if member.staff_id.is_empty():
			continue
		if not dynamics.has(member.staff_id):
			dynamics[member.staff_id] = {"loyalty":clampi(member.morale, 25, 90), "burnout":0, "conflict":"None", "successor":""}


static func _process_staff(team: Team, elapsed_days: int, summaries: Array[String]) -> void:
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


static func set_advanced_contract(team: Team, driver: Driver, terms: Dictionary) -> bool:
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


static func begin_manufacturer_partnership(team: Team, partner: String, support: int, exclusive: bool) -> bool:
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


static func run_preseason_test(team: Team, focus: String) -> Dictionary:
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


static func process_race(team: Team, result: RaceResult, simulation: RaceSimulation = null) -> void:
	var state := ensure_state(team)
	var board := state.board as Dictionary
	var finish_target := int(((board.targets as Array)[0] as Dictionary).target) if not (board.targets as Array).is_empty() else 8
	var delta := 4 if result.finishing_position <= finish_target else -3
	if result.finishing_position == 1:
		delta += 4
	board["confidence"] = clampi(int(board.confidence) + delta, 0, 100)
	board["job_security"] = clampi(int(board.job_security) + signi(delta), 0, 100)
	_update_board_progress(team, result)
	_update_records(team, result)
	_update_stats(team, result)
	_update_rivalries(team, result)
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


static func _update_board_progress(team: Team, result: RaceResult) -> void:
	var targets := (team.career_state.board as Dictionary).targets as Array
	for target_value in targets:
		var target := target_value as Dictionary
		match str(target.id):
			"championship":
				target["progress"] = result.finishing_position
				target["complete"] = result.finishing_position <= int(target.target)
			"finance":
				target["progress"] = team.money
				target["complete"] = team.money >= int(target.target)
			"development":
				target["progress"] = (team.career_state.rd.completed as Array).size()
				target["complete"] = int(target.progress) >= int(target.target)


static func _update_records(team: Team, result: RaceResult) -> void:
	var records := team.career_state.records as Dictionary
	var track_id := result.race.track_name
	var tracks := records.tracks as Dictionary
	var track := tracks.get(track_id, {"starts":0, "wins":0, "poles":0, "best_finish":999, "best_lap":0.0}) as Dictionary
	track.starts = int(track.starts) + 1
	track.wins = int(track.wins) + (1 if result.finishing_position == 1 else 0)
	track.poles = int(track.poles) + (1 if result.starting_position == 1 else 0)
	track.best_finish = mini(int(track.best_finish), result.finishing_position)
	tracks[track_id] = track
	var series_records := records.series as Dictionary
	var series := series_records.get(result.race.series_id, {"starts":0, "wins":0, "podiums":0, "points":0, "championships":0}) as Dictionary
	series.starts = int(series.starts) + 1
	series.wins = int(series.wins) + (1 if result.finishing_position == 1 else 0)
	series.podiums = int(series.podiums) + (1 if result.finishing_position <= 3 else 0)
	series.points = int(series.points) + result.championship_points_earned
	series_records[result.race.series_id] = series


static func _update_stats(team: Team, result: RaceResult) -> void:
	var stats := team.career_state.stats as Dictionary
	(stats.race_finishes as Array).append({"race":result.race.race_name, "finish":result.finishing_position, "start":result.starting_position, "season":team.current_season_year})
	(stats.cash as Array).append(team.money)
	(stats.fans as Array).append(team.fans)
	for key in ["race_finishes", "cash", "fans"]:
		var rows := stats[key] as Array
		if rows.size() > 50:
			rows.pop_front()


static func _update_rivalries(team: Team, result: RaceResult) -> void:
	if result.standings.is_empty() or result.finishing_position <= 0:
		return
	var nearest_index := clampi(result.finishing_position, 0, result.standings.size() - 1)
	var rival := result.standings[nearest_index] as Dictionary
	if bool(rival.get("is_player", false)) and nearest_index > 0:
		rival = result.standings[nearest_index - 1] as Dictionary
	var rival_id := str(rival.get("driver_id", rival.get("driver_name", "")))
	if rival_id.is_empty():
		return
	var rivalries := team.career_state.rivalries as Dictionary
	var data := rivalries.get(rival_id, {"name":rival.get("driver_name", "Rival"), "team":rival.get("team_name", ""), "intensity":10, "incidents":0, "defeats":0, "disputes":0, "history":[]}) as Dictionary
	data.intensity = clampi(int(data.intensity) + (4 if result.positions_gained != 0 else 2), 0, 100)
	if result.finishing_position < int(rival.get("position", result.finishing_position + 1)):
		data.defeats = int(data.defeats) + 1
	(data.history as Array).push_front({"season":team.current_season_year, "race":result.race.race_name, "player_finish":result.finishing_position})
	rivalries[rival_id] = data


static func _generate_press_conference(team: Team, result: RaceResult) -> void:
	var subject := "Post-race press conference"
	var body := "Reporters want your reaction after finishing P%d at %s." % [result.finishing_position, result.race.track_name]
	add_inbox_item(team, "Media", subject, body, [
		{"label":"Praise the whole team", "effects":{"driver_morale":3, "staff_morale":3, "fans":20, "sponsor":1, "rivalry":-1}},
		{"label":"Demand more performance", "effects":{"confidence":2, "driver_morale":-3, "staff_morale":-2, "rivalry":4}},
		{"label":"Entertain the fans", "effects":{"fans":60, "reputation":2, "confidence":-1, "sponsor":2, "rivalry":2}}
	])


static func _generate_story_arc(team: Team, result: RaceResult) -> void:
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
	arcs.push_front({"type":kind, "driver":result.player_driver.driver_name, "race":result.race.race_name, "season":team.current_season_year, "momentum":1})
	add_notification(team, "Story", kind, "%s is becoming a paddock talking point." % result.player_driver.driver_name)


static func _process_sponsor_and_merchandise(team: Team, result: RaceResult) -> void:
	var merchandise := team.career_state.merchandise as Dictionary
	var demand := maxi(0, 12 - result.finishing_position) * 3 + result.fans_earned
	merchandise.popularity = maxi(0, int(merchandise.popularity) + demand)
	var revenue := mini(int(merchandise.stock), demand) * int(merchandise.price)
	merchandise.stock = maxi(0, int(merchandise.stock) - demand)
	merchandise.last_revenue = revenue
	if revenue > 0:
		team.money += revenue
		team.record_finance("Merchandise", revenue, "Race-week merchandise sales")
	if result.finishing_position <= 5:
		var activations := team.career_state.sponsor_activations as Array
		activations.push_front({"event":"Winner's circle hospitality" if result.finishing_position == 1 else "Fan appearance", "value":250 + demand * 10, "completed":false, "season":team.current_season_year})


static func order_merchandise(team: Team, quantity: int) -> bool:
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


static func complete_sponsor_activation(team: Team, index: int) -> bool:
	var activations := ensure_state(team).sponsor_activations as Array
	if index < 0 or index >= activations.size():
		return false
	var activation := activations[index] as Dictionary
	if bool(activation.completed):
		return false
	activation.completed = true
	var value := int(activation.value)
	team.money += value
	team.fans += 25
	team.record_finance("Sponsor activation", value, str(activation.event))
	add_notification(team, "Sponsor", "Activation completed", "+$%s and 25 fans" % value)
	team.emit_changed()
	return true


static func _process_injury_risk(team: Team, result: RaceResult) -> void:
	if result.player_driver == null:
		return
	var retired := false
	if result.finishing_position > 0 and result.finishing_position <= result.standings.size():
		retired = str((result.standings[result.finishing_position - 1] as Dictionary).get("status", "")) == "Retired"
	var risk := 0.02 + float(result.player_driver.fatigue) * 0.0006 + (0.04 if retired else 0.0)
	if randf() < risk:
		create_injury(team, result.player_driver, "Moderate" if retired else "Minor")


static func _process_stewarding(team: Team, result: RaceResult, simulation: RaceSimulation) -> void:
	var cases := team.career_state.stewarding.cases as Array
	if simulation == null:
		return
	var player := simulation.get_player_entry()
	if player == null:
		return
	if player.incident_time_loss > 0.0 and randf() < 0.18:
		var penalty := 5
		var case := {"race":result.race.race_name, "reason":"Avoidable contact", "penalty":"%d championship points" % penalty, "points":penalty, "appealable":true, "status":"Applied"}
		cases.push_front(case)
		result.championship_points_earned = maxi(0, result.championship_points_earned - penalty)
		result.penalties.append(case)
		add_inbox_item(team, "Stewarding", "Post-race penalty", "Race control issued a %d-point penalty for avoidable contact. The decision may be appealed." % penalty)


static func _process_team_politics(team: Team, result: RaceResult) -> void:
	var order := result.team_order_summary
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


static func _process_logistics_damage(team: Team, result: RaceResult) -> void:
	var logistics := ensure_state(team).logistics as Dictionary
	if result.condition_lost >= 8:
		if int(logistics.spare_cars) > 0:
			logistics.spare_cars = int(logistics.spare_cars) - 1
			add_notification(team, "Logistics", "Spare car allocated", "Heavy weekend damage consumed one spare car.")
		else:
			logistics.damaged_inventory = int(logistics.damaged_inventory) + 1
			add_inbox_item(team, "Logistics", "Equipment shortage", "Heavy damage added to the workshop backlog. Travel readiness and cash flow are at risk.")


static func appeal_latest_penalty(team: Team) -> bool:
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


static func process_season_end(team: Team, finishing_position: int) -> void:
	var state := ensure_state(team)
	if int(state.season_processed) == team.current_season_year:
		return
	state.season_processed = team.current_season_year
	var board := state.board as Dictionary
	var met := 0
	for target_value in board.targets:
		if bool((target_value as Dictionary).get("complete", false)):
			met += 1
	var confidence_delta := (met * 6) - (((board.targets as Array).size() - met) * 5)
	board.confidence = clampi(int(board.confidence) + confidence_delta, 0, 100)
	board.job_security = clampi(int(board.job_security) + confidence_delta, 0, 100)
	board.last_review = "%d of %d objectives met; board confidence %d%%." % [met, (board.targets as Array).size(), board.confidence]
	_generate_awards(team, finishing_position)
	_develop_academy_season(team)
	_generate_regulation(team)
	_evolve_world(team)
	_generate_manufacturer_offers(team)
	board["funding_used"] = false
	board["funding"] = 0
	board.targets = []
	_ensure_board_targets(team)
	add_inbox_item(team, "Board", "Season review", str(board.last_review))
	team.emit_changed()


static func _generate_awards(team: Team, finishing_position: int) -> void:
	var awards := team.career_state.awards as Array
	var driver := team.get_active_driver()
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


static func _develop_academy_season(team: Team) -> void:
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


static func _generate_regulation(team: Team) -> void:
	var regulations := team.career_state.regulations as Dictionary
	if not (regulations.next as Dictionary).is_empty():
		(regulations.history as Array).push_front(regulations.current.duplicate(true))
		regulations.current = regulations.next.duplicate(true)
		var reset := int(regulations.current.get("performance_reset", 0))
		var applied := 0
		for car_value in team.cars:
			var car := car_value as Car
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


static func _ensure_world_entrants(team: Team) -> void:
	var entrants := team.career_state.get("world_entrants", []) as Array
	if not entrants.is_empty():
		return
	for series_value in SeriesCatalog.SERIES:
		var series_id := str((series_value as Dictionary).id)
		entrants.append({"id":"independent_%s" % series_id, "name":"Independent Racing %s" % (entrants.size() + 1), "series_id":series_id, "status":"Active", "budget":randi_range(28000, 90000), "performance":randi_range(40, 68), "seasons":1})


static func _evolve_world(team: Team) -> void:
	var state := team.career_state
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
	var ai_team_ids := team.ai_team_career.keys()
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


static func launch_international_program(team: Team, region: String, discipline: String) -> bool:
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


static func _generate_manufacturer_offers(team: Team) -> void:
	var manufacturer := team.career_state.manufacturer as Dictionary
	var offers := manufacturer.offers as Array
	offers.clear()
	for index in 3:
		offers.append({"partner":["Orion", "Apex", "Vanguard"][index], "support":45 + index * 15, "exclusivity":index == 2, "cost":maxi(1000, 7500 - team.reputation * 12 - index * 900)})


static func update_finance_forecast(team: Team) -> Dictionary:
	var state := team.career_state
	var weekly_salary := 0
	for driver in team.get_contracted_drivers():
		weekly_salary += driver.salary
	for member in team.staff:
		if member.hired:
			weekly_salary += member.salary
	var upkeep := 0
	for facility_id in FACILITIES:
		upkeep += int(FACILITIES[facility_id].upkeep) * get_facility_level(team, facility_id)
	var projected_income := maxi(0, team.get_effective_sponsor_value(4000)) + roundi(float(team.fans) * 0.4)
	var projected_costs := weekly_salary + upkeep + maxi(0, int((state.logistics as Dictionary).damaged_inventory) * 600)
	var weeks_remaining := maxi(0, CalendarCatalog.SEASON_END_DAY - team.current_season_day) / 7
	var forecast := {
		"cash":team.money,
		"weekly_income":projected_income,
		"weekly_costs":projected_costs,
		"weekly_net":projected_income - projected_costs,
		"season_end_cash":team.money + (projected_income - projected_costs) * weeks_remaining,
		"payroll_warning":projected_costs > projected_income * 1.35,
		"upgrade_budget":maxi(0, team.money - projected_costs * 3)
	}
	state.finance_forecast = forecast
	return forecast


static func configure_race_weekend(team: Team, race: Race) -> Dictionary:
	var state := ensure_state(team)
	var seed_value := hash("%s:%s:%d" % [race.race_id, team.current_season_year, team.current_race_week])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weather: String = str(["Dry", "Dry", "Dry", "Mixed", "Wet"][rng.randi_range(0, 4)])
	if race.weather == "Wet":
		weather = "Wet"
	var formats := ["Standard", "Knockout", "Groups", "Heat races", "Provisionals"]
	var format: String = str(formats[(race.season_round + team.current_season_year) % formats.size()])
	var forecast := {"weather":weather, "rain_chance":15 if weather == "Dry" else (55 if weather == "Mixed" else 88), "temperature":rng.randi_range(14, 34), "confidence":rng.randi_range(62, 94)}
	state.race_weekend = {"forecast":forecast, "qualifying_format":format, "team_order":"Race freely"}
	return state.race_weekend


static func get_race_modifiers(team: Team) -> Dictionary:
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


static func set_branding(team: Team, branding: Dictionary) -> void:
	var target := ensure_state(team).branding as Dictionary
	for key in branding:
		target[key] = branding[key]
	team.emit_changed()


static func set_accessibility(team: Team, values: Dictionary) -> void:
	var target := ensure_state(team).accessibility as Dictionary
	for key in values:
		target[key] = values[key]
	target.ui_scale = clampf(float(target.ui_scale), 0.8, 1.5)
	target.simulation_speed = clampf(float(target.simulation_speed), 0.5, 4.0)
	apply_accessibility(team)
	team.emit_changed()


static func apply_accessibility(team: Team) -> void:
	var accessibility := ensure_state(team).accessibility as Dictionary
	var root := Engine.get_main_loop() as SceneTree
	if root == null:
		return
	root.root.content_scale_factor = clampf(float(accessibility.ui_scale), 0.8, 1.5)


static func get_unread_count(team: Team) -> int:
	var total := 0
	var state := ensure_state(team)
	for value in state.inbox:
		if not bool((value as Dictionary).get("read", false)):
			total += 1
	for value in state.notifications:
		if not bool((value as Dictionary).get("read", false)):
			total += 1
	return total


static func mark_all_read(team: Team) -> void:
	var state := ensure_state(team)
	for value in state.inbox:
		(value as Dictionary)["read"] = true
	for value in state.notifications:
		(value as Dictionary)["read"] = true
	team.emit_changed()
