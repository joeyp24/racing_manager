extends RefCounted
class_name SeriesCatalog

const IDENTITIES: Dictionary = {
	"local_short_track":{"short_name":"LOCAL 100", "color":"e85d45", "tagline":"Friday lights. Volunteer crews. Nothing comes easy."},
	"regional_short_track":{"short_name":"REGIONAL TOUR", "color":"f09a38", "tagline":"The first road trips and the first real reputations."},
	"national_short_track":{"short_name":"NATIONAL SHORT", "color":"e6bd39", "tagline":"Bullrings, bruises and the country's best late-model teams."},
	"continental_east_west":{"short_name":"EAST / WEST", "color":"34b7a0", "tagline":"Two coasts, one field and no familiar way home."},
	"continental_national":{"short_name":"CONTINENTAL", "color":"3e91e8", "tagline":"A national proving ground for serious organizations."},
	"national_truck":{"short_name":"TRUCK TOUR", "color":"6e7ff2", "tagline":"Heavy machines, close packs and unforgiving restarts."},
	"national_grand":{"short_name":"GRAND SERIES", "color":"a55ce8", "tagline":"Factory attention and careers made in public."},
	"premier_cup":{"short_name":"PREMIER CUP", "color":"e6539c", "tagline":"The biggest teams, the longest season and the final measure."}
}

const SERIES: Array[Dictionary] = [
	{"id":"local_short_track", "required_level":1, "name":"Local Short Track Series", "entry_cost":0, "hq_level":1, "roster_size":20, "season_length":12, "maximum_field_size":20, "points_system":"short_track", "championship_payouts":[50000,35000,25000,18000,14000,10000,7500,5000], "championship_prize":50000, "weekend_cost_multiplier":1.0, "sponsor_prestige_multiplier":1.0, "car_price":12000, "car_rating":48, "minimum_car_rating":44, "car_performance_range":[44,52], "track_type_distribution":{"Short Track":0.75,"Speedway":0.25}, "estimated_race_cost":1200},
	{"id":"regional_short_track", "required_level":2, "name":"Regional Short Track Series", "entry_cost":35000, "hq_level":2, "roster_size":24, "season_length":14, "maximum_field_size":24, "points_system":"short_track", "championship_payouts":[125000,80000,50000,30000,20000], "championship_prize":125000, "weekend_cost_multiplier":1.25, "sponsor_prestige_multiplier":1.2, "car_price":28000, "car_rating":55, "minimum_car_rating":52, "car_performance_range":[52,59], "track_type_distribution":{"Short Track":0.70,"Speedway":0.30}, "estimated_race_cost":2500},
	{"id":"national_short_track", "required_level":4, "name":"National Short Track Series", "entry_cost":80000, "hq_level":3, "roster_size":30, "season_length":16, "maximum_field_size":30, "points_system":"national", "championship_payouts":[250000,150000,90000,50000,30000], "championship_prize":250000, "weekend_cost_multiplier":1.6, "sponsor_prestige_multiplier":1.5, "car_price":60000, "car_rating":62, "minimum_car_rating":59, "car_performance_range":[59,66], "track_type_distribution":{"Short Track":0.60,"Speedway":0.30,"Road Course":0.10}, "estimated_race_cost":5000},
	{"id":"continental_east_west", "required_level":6, "name":"Continental East/West Series", "entry_cost":150000, "hq_level":4, "roster_size":24, "season_length":16, "maximum_field_size":24, "points_system":"national", "championship_payouts":[400000,240000,140000,80000,50000], "championship_prize":400000, "weekend_cost_multiplier":2.0, "sponsor_prestige_multiplier":1.9, "car_price":110000, "car_rating":68, "minimum_car_rating":65, "car_performance_range":[65,72], "track_type_distribution":{"Short Track":0.35,"Speedway":0.45,"Road Course":0.20}, "estimated_race_cost":9000},
	{"id":"continental_national", "required_level":8, "name":"Continental National Series", "entry_cost":275000, "hq_level":5, "roster_size":30, "season_length":20, "maximum_field_size":30, "points_system":"national", "championship_payouts":[700000,400000,240000,140000,80000], "championship_prize":700000, "weekend_cost_multiplier":2.6, "sponsor_prestige_multiplier":2.4, "car_price":190000, "car_rating":74, "minimum_car_rating":71, "car_performance_range":[71,78], "track_type_distribution":{"Short Track":0.25,"Speedway":0.50,"Road Course":0.25}, "estimated_race_cost":15000},
	{"id":"national_truck", "required_level":11, "name":"National Truck Series", "entry_cost":500000, "hq_level":6, "roster_size":36, "season_length":23, "maximum_field_size":36, "points_system":"national", "championship_payouts":[1200000,700000,400000,220000,120000], "championship_prize":1200000, "weekend_cost_multiplier":3.5, "sponsor_prestige_multiplier":3.2, "car_price":350000, "car_rating":80, "minimum_car_rating":77, "car_performance_range":[77,84], "track_type_distribution":{"Short Track":0.20,"Speedway":0.55,"Road Course":0.25}, "estimated_race_cost":26000},
	{"id":"national_grand", "required_level":14, "name":"National Grand Series", "entry_cost":900000, "hq_level":7, "roster_size":38, "season_length":28, "maximum_field_size":38, "points_system":"national", "championship_payouts":[2200000,1300000,750000,400000,225000], "championship_prize":2200000, "weekend_cost_multiplier":4.7, "sponsor_prestige_multiplier":4.2, "car_price":650000, "car_rating":87, "minimum_car_rating":84, "car_performance_range":[84,91], "track_type_distribution":{"Short Track":0.15,"Speedway":0.55,"Road Course":0.30}, "estimated_race_cost":45000},
	{"id":"premier_cup", "required_level":18, "name":"Premier Cup Series", "entry_cost":1750000, "hq_level":8, "roster_size":40, "season_length":36, "maximum_field_size":40, "points_system":"cup", "championship_payouts":[5000000,3000000,1750000,1000000,600000], "championship_prize":5000000, "weekend_cost_multiplier":6.0, "sponsor_prestige_multiplier":5.5, "car_price":1200000, "car_rating":94, "minimum_car_rating":91, "car_performance_range":[91,100], "track_type_distribution":{"Short Track":0.15,"Speedway":0.55,"Road Course":0.25,"Street Course":0.05}, "estimated_race_cost":75000}
]

const HQ_UPGRADE_COSTS: Array[int] = [25000, 60000, 125000, 250000, 450000, 800000, 1400000]

static func get_series(series_id: String) -> Dictionary:
	for series in SERIES:
		if series.id == series_id:
			return series
	return {}


static func get_identity(series_id: String) -> Dictionary:
	return (IDENTITIES.get(series_id, {"short_name":"RACING SERIES", "color":"8b5cf6", "tagline":"Every lap adds to the story."}) as Dictionary).duplicate(true)

static func get_index(series_id: String) -> int:
	for index in SERIES.size():
		if SERIES[index].id == series_id:
			return index
	return -1

static func get_hq_upgrade_cost(current_level: int) -> int:
	if current_level < 1 or current_level > HQ_UPGRADE_COSTS.size():
		return 0
	return HQ_UPGRADE_COSTS[current_level - 1]

static func create_car_templates(series_id: String) -> Array[Car]:
	var series := get_series(series_id)
	var cars: Array[Car] = []
	if series.is_empty():
		return cars
	var styles := [["Apex", "Charger"], ["Falcon", "Velocity"], ["Titan", "Racer"]]
	for index in styles.size():
		var car := Car.new()
		car.series_id = series_id
		car.manufacturer = styles[index][0]
		car.model = styles[index][1]
		car.name = "%s %s" % [car.manufacturer, car.model]
		var target_base_pp := int(series.car_rating) + index - 1
		car.installed_parts = PartCatalog.create_factory_parts(series_id, target_base_pp)
		car.purchase_price = roundi(float(series.car_price) * (0.9 + index * 0.1))
		car.value = roundi(car.purchase_price * 0.75)
		cars.append(car)
	return cars
