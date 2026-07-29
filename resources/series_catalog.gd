extends RefCounted
class_name SeriesCatalog

const SERIES: Array[Dictionary] = [
	{"id":"local_short_track", "name":"Local Short Track Series", "entry_cost":0, "hq_level":1, "roster_size":20, "car_price":12000, "car_rating":48},
	{"id":"regional_short_track", "name":"Regional Short Track Series", "entry_cost":35000, "hq_level":2, "roster_size":24, "car_price":28000, "car_rating":55},
	{"id":"national_short_track", "name":"National Short Track Series", "entry_cost":80000, "hq_level":3, "roster_size":30, "car_price":60000, "car_rating":62},
	{"id":"continental_east_west", "name":"Continental East/West Series", "entry_cost":150000, "hq_level":4, "roster_size":24, "car_price":110000, "car_rating":68},
	{"id":"continental_national", "name":"Continental National Series", "entry_cost":275000, "hq_level":5, "roster_size":30, "car_price":190000, "car_rating":74},
	{"id":"national_truck", "name":"National Truck Series", "entry_cost":500000, "hq_level":6, "roster_size":36, "car_price":350000, "car_rating":80},
	{"id":"national_grand", "name":"National Grand Series", "entry_cost":900000, "hq_level":7, "roster_size":38, "car_price":650000, "car_rating":87},
	{"id":"premier_cup", "name":"Premier Cup Series", "entry_cost":1750000, "hq_level":8, "roster_size":40, "car_price":1200000, "car_rating":94}
]

const HQ_UPGRADE_COSTS: Array[int] = [25000, 60000, 125000, 250000, 450000, 800000, 1400000]

static func get_series(series_id: String) -> Dictionary:
	for series in SERIES:
		if series.id == series_id:
			return series
	return {}

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
		car.performance = int(series.car_rating) + index - 1
		car.purchase_price = roundi(float(series.car_price) * (0.9 + index * 0.1))
		car.value = roundi(car.purchase_price * 0.75)
		cars.append(car)
	return cars
