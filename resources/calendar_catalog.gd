extends RefCounted
class_name CalendarCatalog

const VENUES := [
	["Pine Ridge","Southeast"],["Copper Valley","Southwest"],["Great Lakes","Midwest"],["Atlantic Shores","Northeast"],
	["Rocky Mountain","Mountain"],["Gulf Coast","Southeast"],["Prairie State","Midwest"],["Capital City","Northeast"],
	["Lone Star","Southwest"],["Pacific Crest","West"],["Bluegrass","Southeast"],["North Woods","Midwest"],
	["Desert Sun","Southwest"],["River Bend","Midwest"],["Coastal Plains","Southeast"],["Empire State","Northeast"],
	["Cascade","West"],["Heartland","Midwest"],["Bayfront","West"],["Appalachian","Southeast"],
	["New England","Northeast"],["High Plains","Mountain"],["Golden State","West"],["Motor City","Midwest"],
	["Ozark","Southwest"],["Carolina","Southeast"],["Lake Erie","Northeast"],["Front Range","Mountain"],
	["Puget Sound","West"],["Allegheny","Northeast"],["Sonoran","Southwest"],["Tidewater","Southeast"],
	["Twin Cities","Midwest"],["Mojave","West"],["Smoky Mountain","Southeast"],["Metro Finale","Northeast"]
]
const LOCAL_IDS := ["spring_100","riverside_200","coastal_150","desert_175","mountain_classic","lakeside_225","capital_200","prairie_250","harbor_180","forest_240","national_stock_car","championship_300"]

static func get_events(series_id: String) -> Array[Dictionary]:
	var series := SeriesCatalog.get_series(series_id); var events: Array[Dictionary] = []
	if series.is_empty(): return events
	var length := int(series.season_length); var types := _track_types(series.track_type_distribution, length)
	var offset := SeriesCatalog.get_index(series_id) * 5
	for index in length:
		var venue: Array = VENUES[(index + offset) % VENUES.size()]
		events.append({"race_id":LOCAL_IDS[index] if series_id == "local_short_track" else "%s_round_%02d" % [series_id,index+1], "race_name":"%s %s" % [venue[0], "200" if types[index] == "Short Track" else "300"], "track_name":"%s Raceway" % venue[0], "race_date":"Week %02d • %s" % [index+1, ["March","April","May","June","July","August","September","October"][mini(7,index*8/length)]], "travel_region":venue[1], "track_type":types[index], "season_round":index+1})
	return events

static func _track_types(distribution: Dictionary, length: int) -> Array[String]:
	var result: Array[String] = []
	for type in distribution:
		for unused in roundi(float(distribution[type]) * length): result.append(str(type))
	while result.size() < length: result.append(str(distribution.keys()[0]))
	while result.size() > length: result.pop_back()
	# Spread types rather than grouping the calendar by track category.
	var spread: Array[String] = []
	while not result.is_empty(): spread.append(result.pop_at((spread.size()*7) % result.size()))
	return spread
