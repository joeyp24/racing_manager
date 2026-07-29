extends Resource
class_name Driver

const RATING_FIELDS: Array[String] = [
	"race_pace", "qualifying_pace", "tyre_management", "racecraft",
	"wet_weather", "starts_restarts", "consistency", "car_feedback",
	"fitness", "composure"
]

@export var driver_id: String = ""
@export var driver_name: String = "Unnamed Driver"

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
