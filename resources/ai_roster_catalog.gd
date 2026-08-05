extends RefCounted
class_name AIRosterCatalog

const FIRST_NAMES := ["Alex","Bailey","Cameron","Dakota","Emery","Finley","Harper","Jordan","Kai","Logan","Morgan","Parker","Quinn","Reese","Riley","Rowan","Sawyer","Skyler","Taylor","Avery"]
const LAST_NAMES := ["Brooks","Carter","Reed","Morgan","Turner","Bennett","Walker","Hayes","Foster","Price","Cole","Ward","Bell","Gray","Ross","Perry","Wood","Cook","Bailey","Cooper"]

static func get_roster(series_id: String) -> Array[Dictionary]:
	var series := SeriesCatalog.get_series(series_id)
	var roster: Array[Dictionary] = []
	if series.is_empty(): return roster
	var performance: Array = series.car_performance_range
	var count := int(series.maximum_field_size)
	var teams := TeamCatalog.get_teams(series_id)
	var driver_index := 0
	for team in teams:
		for team_car_index in int(team.driver_count):
			var index := driver_index
			var seed := SeriesCatalog.get_index(series_id) * 41 + index
			var rating := clampi(int(performance[0]) + (index * 7 + seed) % (int(performance[1]) - int(performance[0]) + 1), 1, 100)
			var equipment_effect := roundi((int(team.equipment_rating) - int(series.car_rating)) * 0.65)
			roster.append({"driver_id":"%s_ai_%02d" % [series_id,index+1], "driver_name":"%s %s" % [FIRST_NAMES[seed%FIRST_NAMES.size()],LAST_NAMES[(seed*3+index)%LAST_NAMES.size()]], "team_id":str(team.team_id), "team_name":str(team.team_name), "team_car_number":team_car_index+1, "team_primary_color":str(team.primary_color), "team_secondary_color":str(team.secondary_color), "skill":rating, "consistency":clampi(rating-4+(index%9),1,100), "aggression":clampi(rating-6+(index*3%13),1,100), "car_performance":clampi(rating+equipment_effect,1,100)})
			driver_index += 1
	assert(driver_index == count, "Team organizations must provide the configured field size.")
	return roster
