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
	for index in count:
		var seed := SeriesCatalog.get_index(series_id) * 41 + index
		var rating := clampi(int(performance[0]) + (index * 7 + seed) % (int(performance[1]) - int(performance[0]) + 1), 1, 100)
		roster.append({"driver_id":"%s_ai_%02d" % [series_id,index+1], "driver_name":"%s %s" % [FIRST_NAMES[seed%FIRST_NAMES.size()],LAST_NAMES[(seed*3+index)%LAST_NAMES.size()]], "team_name":"%s Racing" % LAST_NAMES[(seed*5+2)%LAST_NAMES.size()], "skill":rating, "consistency":clampi(rating-4+(index%9),1,100), "aggression":clampi(rating-6+(index*3%13),1,100), "car_performance":rating})
	return roster
