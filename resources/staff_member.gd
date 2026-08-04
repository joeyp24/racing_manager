extends Resource
class_name StaffMember

const ROLES: Array[String] = ["Crew Chief", "Engineer", "Mechanic", "Spotter", "Pit Crew"]

@export var staff_id: String = ""
@export var staff_name: String = "Staff Member"
@export_enum("Crew Chief", "Engineer", "Mechanic", "Spotter", "Pit Crew") var role: String = "Engineer"
@export_range(1, 100) var rating: int = 50
@export_range(1, 100) var primary_rating: int = 50
@export_range(1, 100) var secondary_rating: int = 50
@export_range(1, 100) var potential: int = 70
@export var signing_fee: int = 0
@export var salary: int = 0
@export var specialty: String = "General"
@export var hired: bool = false
@export var contract_races_remaining: int = 0
@export_range(0, 100) var morale: int = 70
@export var experience: int = 0
@export var seasons_with_team: int = 0
@export var development_points: int = 0
@export var rival_interest: String = "Low"
@export var last_development: String = "No change"
@export_range(0, 100) var loyalty: int = 70
@export_range(0, 100) var burnout: int = 0
@export var relationship_notes: Dictionary = {}
@export var succession_candidate_id: String = ""
@export var assigned_race_team_id: String = ""


func get_rating_grade() -> String:
	if rating >= 90:
		return "Elite"
	if rating >= 75:
		return "Expert"
	if rating >= 60:
		return "Skilled"
	return "Developing"


func get_attribute_names() -> Array[String]:
	match role:
		"Crew Chief":
			return ["Strategy", "Setup"]
		"Engineer":
			return ["Performance", "Reliability"]
		"Mechanic":
			return ["Repair speed", "Pit accuracy"]
		"Spotter":
			return ["Risk reduction", "Restarts"]
		"Pit Crew":
			return ["Speed", "Consistency"]
	return ["Primary", "Secondary"]


func get_attributes_summary() -> String:
	var names := get_attribute_names()
	return "%s %d  ·  %s %d" % [names[0], primary_rating, names[1], secondary_rating]


func get_summary() -> String:
	return "%s · %s %d · %s" % [role, get_rating_grade(), rating, specialty]


func get_default_contract_length() -> int:
	if rating >= 90:
		return 12
	if rating >= 75:
		return 10
	if rating >= 60:
		return 7
	return 5


func get_termination_fee() -> int:
	return salary * 2


func get_morale_label() -> String:
	if morale >= 80:
		return "Excellent"
	if morale >= 60:
		return "Good"
	if morale >= 40:
		return "Unsettled"
	return "Unhappy"


func recalculate_rating() -> void:
	rating = roundi((float(primary_rating) + float(secondary_rating)) / 2.0)
	potential = maxi(potential, rating)


func apply_season_development() -> void:
	var old_rating := rating
	seasons_with_team += 1
	experience += 12
	development_points += 2 if morale >= 70 else 1
	while development_points > 0 and rating < potential:
		if primary_rating <= secondary_rating:
			primary_rating = mini(100, primary_rating + 1)
		else:
			secondary_rating = mini(100, secondary_rating + 1)
		development_points -= 1
		recalculate_rating()
	last_development = "+%d overall" % (rating - old_rating) if rating > old_rating else "At potential"
	emit_changed()
