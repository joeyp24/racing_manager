extends Resource
class_name StaffMember

@export var staff_id: String = ""
@export var staff_name: String = "Staff Member"
@export_enum("Crew Chief", "Engineer") var role: String = "Engineer"
@export_range(1, 100) var rating: int = 50
@export var signing_fee: int = 0
@export var salary: int = 0
@export var specialty: String = "General"
@export var hired: bool = false


func get_rating_grade() -> String:
	if rating >= 90:
		return "Elite"
	if rating >= 75:
		return "Expert"
	if rating >= 60:
		return "Skilled"
	return "Developing"


func get_summary() -> String:
	return "%s · %s (%d) · %s" % [role, get_rating_grade(), rating, specialty]
