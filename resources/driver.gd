extends Resource
class_name Driver

const RATING_FIELDS: Array[String] = [
	"race_pace", "qualifying_pace", "tyre_management", "racecraft",
	"wet_weather", "starts_restarts", "consistency", "car_feedback",
	"fitness", "composure"
]
const PERSONALITY_FIELDS: Array[String] = ["ambition", "loyalty", "professionalism", "adaptability", "marketability", "coachability", "teamwork", "pressure_tolerance"]

@export var driver_id: String = ""
@export var driver_name: String = "Unnamed Driver"
@export var series_id: String = "local_short_track"

# Legacy values remain serialized for save compatibility and race balancing.
@export_range(0, 99) var skill: int = 50
@export_range(0, 99) var consistency: int = 50
@export_range(0, 99) var aggression: int = 50

@export_category("Driver Profile")
@export_range(16, 70) var age: int = 25
@export var nationality: String = "American"
@export var hometown: String = "Unknown"
@export var date_of_birth: String = ""
@export var height_cm: int = 178
@export var weight_kg: int = 73
@export var racing_background: String = "Club racing"
@export_multiline var biography: String = "A determined racer building a reputation in the paddock."
@export var preferred_number: int = 0

@export_category("Performance Ratings")
@export_range(0, 99) var race_pace: int = 50
@export_range(0, 99) var qualifying_pace: int = 50
@export_range(0, 99) var tyre_management: int = 50
@export_range(0, 99) var racecraft: int = 50
@export_range(0, 99) var wet_weather: int = 50
@export_range(0, 99) var starts_restarts: int = 50
@export_range(0, 99) var car_feedback: int = 50
@export_range(0, 99) var fitness: int = 50
@export_range(0, 99) var composure: int = 50

@export_category("Personality & Wellbeing")
@export_range(0, 99) var ambition: int = 50
@export_range(0, 99) var loyalty: int = 50
@export_range(0, 99) var professionalism: int = 50
@export_range(0, 99) var adaptability: int = 50
@export_range(0, 99) var marketability: int = 50
@export_range(0, 99) var coachability: int = 50
@export_range(0, 99) var confidence: int = 60
@export_range(0, 99) var morale: int = 70
@export_range(0, 99) var form: int = 50
@export_range(-10, 10) var form_trend: int = 0
@export var last_confidence_change: int = 0
@export_range(0, 99) var teamwork: int = 50
@export_range(0, 99) var pressure_tolerance: int = 50
@export_range(0, 100) var fatigue: int = 0
@export var availability_status: String = "Available"
@export var unavailable_weeks: int = 0
@export var development_focus: String = "Balanced"
@export var relationship_scores: Dictionary = {}

@export_category("Attribute Potential Caps")
@export_range(0, 99) var race_pace_potential: int = 80
@export_range(0, 99) var qualifying_pace_potential: int = 80
@export_range(0, 99) var tyre_management_potential: int = 80
@export_range(0, 99) var racecraft_potential: int = 80
@export_range(0, 99) var wet_weather_potential: int = 80
@export_range(0, 99) var starts_restarts_potential: int = 80
@export_range(0, 99) var consistency_potential: int = 80
@export_range(0, 99) var car_feedback_potential: int = 80
@export_range(0, 99) var fitness_potential: int = 80
@export_range(0, 99) var composure_potential: int = 80

@export_category("Career")
@export_range(0, 99) var potential: int = 80 # Legacy summary; use get_potential_overall().
@export var seasons_with_team: int = 0
@export var development_points: int = 0
@export var season_starts: int = 0
@export var last_season_development: String = "No change"
@export var salary: int = 1500
@export var signing_fee: int = 2500
@export var archetype: String = "Balanced club racer"
@export var assigned_bay: int = -1
@export var team_name: String = ""
@export var is_player_driver: bool = false
@export var career_starts: int = 0
@export var career_wins: int = 0
@export var career_podiums: int = 0
@export var career_points: int = 0
@export var career_poles: int = 0
@export var career_fastest_laps: int = 0
@export var championships: int = 0
@export var best_championship_finish: int = 0
@export var race_history: Array[Dictionary] = []

@export_category("Contract")
@export var contract_races_remaining: int = 0
@export var contract_length: int = 12
@export var performance_bonus: int = 0
@export var championship_bonus: int = 0
@export var release_clause: int = 0
@export_enum("None", "Team", "Driver") var contract_option: String = "None"
@export_enum("Lead", "Second", "Equal", "Prospect") var expected_role: String = "Equal"
@export_range(0, 3) var minimum_facility_level: int = 0
@export_range(0, 99) var desired_competitiveness: int = 40
@export var is_pay_driver: bool = false
@export var sponsorship_contribution_per_race: int = 0
@export var sponsorship_signing_bonus: int = 0


func get_overall_rating() -> int:
	var total := 0
	for attribute in RATING_FIELDS:
		total += int(get(attribute))
	return clampi(roundi(float(total) / RATING_FIELDS.size()), 0, 99)


func get_potential_overall() -> int:
	var total := 0
	for attribute in RATING_FIELDS:
		total += int(get(attribute + "_potential"))
	return clampi(roundi(float(total) / RATING_FIELDS.size()), 0, 99)


func get_rating_rows() -> Array[Dictionary]:
	var labels := ["Race pace", "Qualifying pace", "Tyre management", "Racecraft", "Wet weather", "Starts & restarts", "Consistency", "Car feedback", "Fitness", "Composure"]
	var rows: Array[Dictionary] = []
	for index in RATING_FIELDS.size():
		var field := RATING_FIELDS[index]
		rows.append({"key": field, "label": labels[index], "rating": int(get(field)), "potential": int(get(field + "_potential"))})
	return rows


func initialize_detailed_ratings(base_skill: int, base_consistency: int, base_aggression: int, ceiling: int) -> void:
	var values := [base_skill, base_skill - 2, base_consistency + 2, base_skill + (base_aggression - 50) / 4, base_skill - 4, base_consistency + (base_aggression - 50) / 5, base_consistency, base_consistency + 1, base_consistency - 2, base_consistency + 1]
	for index in RATING_FIELDS.size():
		var field := RATING_FIELDS[index]
		set(field, clampi(int(values[index]), 0, 99))
		set(field + "_potential", clampi(maxi(int(get(field)), ceiling + (index % 3) - 1), 0, 99))
	potential = get_potential_overall()
	sync_legacy_ratings()


func sync_legacy_ratings() -> void:
	# Older simulation systems consume these summaries while detailed attributes
	# remain the single source of truth for profile and development.
	skill = roundi(float(race_pace + qualifying_pace + racecraft + wet_weather) / 4.0)
	consistency = roundi(float(tyre_management + car_feedback + fitness + composure) / 4.0)
	aggression = roundi(float(racecraft + starts_restarts) / 2.0)
	potential = get_potential_overall()


func get_development_rate() -> String:
	if age >= 34:
		return "Declining"
	var growth_room := get_potential_overall() - get_overall_rating()
	if age <= 23 and growth_room >= 15:
		return "Rapid"
	if age <= 29 and growth_room >= 6:
		return "Steady"
	return "Limited"


func get_attribute_dictionary() -> Dictionary:
	var result := {}
	for field in RATING_FIELDS:
		result[field] = int(get(field))
	return result


func update_archetype() -> void:
	var best := "race_pace"
	for field in RATING_FIELDS:
		if int(get(field)) > int(get(best)):
			best = field
	var names := {"qualifying_pace":"Qualifying specialist", "tyre_management":"Tyre whisperer", "wet_weather":"Wet-weather specialist", "racecraft":"Aggressive overtaker", "car_feedback":"Technical development driver", "consistency":"Consistent points scorer", "starts_restarts":"Short-track specialist", "fitness":"Late-race closer", "composure":"Pressure specialist", "race_pace":"Complete racer"}
	archetype = str(names.get(best, "Balanced racer"))
	if get_overall_rating() >= 90:
		archetype = "Complete champion"


func is_available() -> bool:
	return availability_status == "Available" and unavailable_weeks <= 0 and fatigue < 95


func record_race(result: Dictionary) -> void:
	race_history.push_front(result.duplicate(true))
	if race_history.size() > 60:
		race_history.resize(60)


func get_form_summary(limit: int = 5) -> Dictionary:
	var count := mini(limit, race_history.size())
	if count == 0:
		return {"races":0, "average_start":0.0, "average_finish":0.0, "positions_gained":0.0, "finish_rate":0.0, "incident_rate":0.0, "form":form, "confidence":confidence, "morale":morale, "trend":form_trend}
	var starts := 0.0
	var finishes := 0.0
	var gained := 0.0
	var completed := 0
	var incidents := 0
	for index in count:
		var item := race_history[index]
		starts += float(item.get("start", 0)); finishes += float(item.get("finish", 0)); gained += float(item.get("positions_gained", 0))
		if str(item.get("status", "Finished")) != "Retired": completed += 1
		if bool(item.get("incident", false)): incidents += 1
	return {"races":count, "average_start":starts/count, "average_finish":finishes/count, "positions_gained":gained/count, "finish_rate":float(completed)/count, "incident_rate":float(incidents)/count, "form":form, "confidence":confidence, "morale":morale, "trend":form_trend}


func get_race_state_modifier() -> float:
	return (
		float(form - 50) * 0.06
		+ float(confidence - 50) * 0.04
		+ float(morale - 50) * 0.025
		- float(fatigue) * 0.018
	)


func get_effective_consistency() -> int:
	return clampi(consistency + roundi(float(form - 50) * 0.10) + roundi(float(confidence - 50) * 0.12), 1, 99)


func apply_race_dynamics(result: Dictionary, expected_finish: int, team_order: String = "Race freely") -> Dictionary:
	var finish := int(result.get("finish", expected_finish))
	var status := str(result.get("status", "Finished"))
	var incident := bool(result.get("incident", false)) or status == "Retired"
	var performance_delta := clampi(expected_finish - finish, -8, 8)
	var target_form := clampi(50 + performance_delta * 5 - (18 if incident else 0), 5, 95)
	var old_form := form
	form = clampi(roundi(lerpf(float(form), float(target_form), 0.38)), 0, 99)
	form_trend = clampi(form - old_form, -10, 10)
	var confidence_delta := clampi(performance_delta, -4, 4)
	if finish == 1:
		confidence_delta += 3
	if incident:
		confidence_delta -= 5
	if team_order != "Race freely":
		confidence_delta -= 1
	if contract_races_remaining <= 3:
		confidence_delta -= 2
	last_confidence_change = clampi(confidence_delta, -8, 8)
	confidence = clampi(confidence + last_confidence_change, 0, 99)
	var morale_delta := clampi(performance_delta, -3, 3)
	if team_order in ["Hold position", "Let teammate pass"]:
		morale_delta -= 3
	if contract_races_remaining <= 3:
		morale_delta -= 1
	morale = clampi(morale + morale_delta, 0, 99)
	return {
		"form_change": form_trend,
		"confidence_change": last_confidence_change,
		"morale_change": morale_delta,
		"incident": incident,
		"contract_uncertain": contract_races_remaining <= 3
	}
