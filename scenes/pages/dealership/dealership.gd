extends Control

const DEALERSHIP_OFFER_SCENE: PackedScene = preload(
	"res://scenes/pages/dealership/dealership_offer.tscn"
)

@export var dealership_inventory: Array[Car] = []

@export_category("Used Car Settings")

@export_range(0, 12, 1)
var used_offer_count: int = 4

@export_range(1, 100, 1)
var minimum_used_condition: int = 55

@export_range(1, 100, 1)
var maximum_used_condition: int = 92

@export_range(0, 500000, 1000)
var minimum_used_mileage: int = 15000

@export_range(0, 500000, 1000)
var maximum_used_mileage: int = 140000

@onready var offers_container: GridContainer = %offers_container
@onready var back_button: Button = %back_button
@onready var title_label: Label = %title_label
@onready var instructions_label: Label = %instructions_label
@onready var series_selector: OptionButton = %series_selector

var random_number_generator := RandomNumberGenerator.new()


func _ready() -> void:
	random_number_generator.randomize()

	back_button.pressed.connect(_on_back_button_pressed)
	series_selector.item_selected.connect(_on_series_selected)
	populate_series_selector()

	if GameManager.selected_bay < 0:
		GameManager.selected_bay = find_empty_garage_bay()

	if GameManager.selected_bay < 0:
		instructions_label.text = "Your garage is full. Sell a car before purchasing another."
	else:
		instructions_label.text = "Purchases will be delivered to garage bay %d. New and used cars include a complete set of standard parts." % (GameManager.selected_bay + 1)

	create_dealership_offers()


func populate_series_selector() -> void:
	series_selector.clear()
	for series in SeriesCatalog.SERIES:
		if GameManager.team.entered_series_ids.has(series.id):
			series_selector.add_item(str(series.name))
			series_selector.set_item_metadata(series_selector.item_count - 1, series.id)
			if series.id == GameManager.team.current_series_id:
				series_selector.select(series_selector.item_count - 1)
	_on_series_selected(series_selector.selected)


func _on_series_selected(index: int) -> void:
	if index < 0:
		return
	var series_id := str(series_selector.get_item_metadata(index))
	var series := SeriesCatalog.get_series(series_id)
	dealership_inventory = SeriesCatalog.create_car_templates(series_id)
	title_label.text = "%s Dealership" % series.name
	if is_node_ready():
		create_dealership_offers()


func find_empty_garage_bay() -> int:
	for bay_index in range(GameManager.team.cars.size()):
		if GameManager.team.get_car(bay_index) == null:
			return bay_index
	return -1


func create_dealership_offers() -> void:
	clear_existing_offers()

	if dealership_inventory.is_empty():
		push_warning("The dealership inventory is empty.")
		return

	create_new_car_offers()
	create_used_car_offers()


func create_new_car_offers() -> void:
	for car_template in dealership_inventory:
		if car_template == null:
			push_warning(
				"The dealership inventory contains an empty entry."
			)
			continue

		var new_car: Car = create_new_car(car_template)

		if new_car != null:
			create_offer(new_car)


func create_used_car_offers() -> void:
	for offer_index in range(used_offer_count):
		var template_index: int = random_number_generator.randi_range(
			0,
			dealership_inventory.size() - 1
		)

		var car_template: Car = dealership_inventory[template_index]

		if car_template == null:
			continue

		var used_car: Car = create_used_car(car_template)

		if used_car != null:
			create_offer(used_car)


func create_new_car(car_template: Car) -> Car:
	var new_car := car_template.duplicate(true) as Car

	if new_car == null:
		push_error(
			"Could not duplicate the new car template."
		)
		return null

	new_car.condition = 100
	new_car.mileage = 0

	return new_car


func create_used_car(car_template: Car) -> Car:
	var used_car := car_template.duplicate(true) as Car

	if used_car == null:
		push_error(
			"Could not duplicate the used car template."
		)
		return null

	used_car.name = "%s (Used)" % car_template.name

	used_car.condition = random_number_generator.randi_range(
		minimum_used_condition,
		maximum_used_condition
	)

	used_car.mileage = random_number_generator.randi_range(
		minimum_used_mileage,
		maximum_used_mileage
	)

	# Wear the authoritative installed parts rather than the ignored legacy rating.
	# Small per-part variation keeps used offers distinct while remaining reproducible
	# from this dealership's RNG stream.
	for part in used_car.installed_parts:
		if part != null:
			part.condition = clampi(
				used_car.condition + random_number_generator.randi_range(-8, 5),
				1,
				100
			)

	used_car.purchase_price = calculate_used_price(
		car_template,
		used_car.condition,
		used_car.mileage
	)

	used_car.value = roundi(
		used_car.purchase_price * 0.75
	)

	return used_car


func calculate_used_price(
	car_template: Car,
	condition: int,
	mileage: int
) -> int:
	var condition_ratio: float = float(condition) / 100.0

	var condition_multiplier: float = lerpf(
		0.45,
		0.90,
		condition_ratio
	)

	var mileage_multiplier: float = clampf(
		1.0 - (float(mileage) / 250000.0),
		0.50,
		0.95
	)

	var calculated_price: int = roundi(
		float(car_template.purchase_price)
		* condition_multiplier
		* mileage_multiplier
	)

	var minimum_price: int = roundi(
		float(car_template.purchase_price) * 0.20
	)

	var maximum_price: int = roundi(
		float(car_template.purchase_price) * 0.85
	)

	return clampi(
		calculated_price,
		minimum_price,
		maximum_price
	)


func create_offer(car_template: Car) -> void:
	if car_template == null:
		return

	var offer_instance := DEALERSHIP_OFFER_SCENE.instantiate()

	if offer_instance == null:
		push_error(
			"The dealership offer scene could not be instantiated."
		)
		return

	offer_instance.set("car_template", car_template)
	offers_container.add_child(offer_instance)


func clear_existing_offers() -> void:
	for child in offers_container.get_children():
		offers_container.remove_child(child)
		child.queue_free()


func _on_back_button_pressed() -> void:
	GameManager.selected_car = null
	GameManager.selected_bay = -1

	GameManager.load_page(
		"res://scenes/pages/garage/garage.tscn"
	)
