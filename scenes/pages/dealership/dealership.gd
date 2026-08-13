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
@onready var comparison_drawer: DecisionComparisonDrawer = %DecisionComparisonDrawer

var random_number_generator := RandomNumberGenerator.new()


func _ready() -> void:
	random_number_generator.randomize()

	back_button.pressed.connect(_on_back_button_pressed)
	series_selector.item_selected.connect(_on_series_selected)
	comparison_drawer.action_requested.connect(_on_comparison_action)
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
	offer_instance.comparison_requested.connect(_show_car_comparison)
	offers_container.add_child(offer_instance)


func _show_car_comparison(candidate: Car) -> void:
	var team := GameManager.team
	var current := _best_owned_car(candidate.series_id)
	var current_name := current.name if current != null else "No owned car"
	var current_attributes := current.get_race_attributes() if current != null else {}
	var candidate_attributes := candidate.get_race_attributes()
	var candidate_pp := candidate.get_total_performance_points(team)
	var current_pp := current.get_total_performance_points(team) if current != null else 0
	var purchase_cost := team.get_discounted_cost(candidate.purchase_price)
	var eligible := GameManager.selected_bay >= 0 and team.entered_series_ids.has(candidate.series_id)
	var disabled_reason := ""
	if GameManager.selected_bay < 0:
		disabled_reason = "Sell a car or expand garage capacity before purchasing."
	elif not team.entered_series_ids.has(candidate.series_id):
		disabled_reason = "Enter this series before purchasing its homologated car."
	elif team.money < purchase_cost:
		disabled_reason = "You need %s more cash." % DecisionComparisonModel.money(purchase_cost - team.money)
	var pp_delta := candidate_pp - current_pp
	var condition_delta := candidate.condition - (current.condition if current != null else 0)
	var model := DecisionComparisonModel.build(team, {
		"eyebrow": "CAR ACQUISITION",
		"title": candidate.name,
		"subtitle": "Compare the candidate with your strongest owned car in the same series. Performance Points include installed parts and team modifiers.",
		"current_title": current_name.to_upper(),
		"candidate_title": "CANDIDATE",
		"metrics": [
			DecisionComparisonModel.metric("Specialization", current.get_specialization_data().get("name", "—") if current != null else "—", candidate.get_specialization_data().get("name", "All-Rounder"), "FLEET ROLE", DecisionComparisonModel.NEUTRAL, "Track specialization contributes directly to race pace at matching venues."),
			DecisionComparisonModel.metric("Chassis trait", current.get_chassis_trait_data().get("name", "—") if current != null else "—", candidate.get_chassis_trait_data().get("name", "Stable Platform"), "PERSISTENT", DecisionComparisonModel.NEUTRAL, candidate.get_chassis_trait_data().get("description", "A lasting chassis characteristic.")),
			DecisionComparisonModel.metric("Performance", str(current_pp), str(candidate_pp), "%+d PP" % pp_delta, _impact(pp_delta), "Displayed whole-car Performance Points."),
			DecisionComparisonModel.metric("Condition", "%d%%" % (current.condition if current != null else 0), "%d%%" % candidate.condition, "%+d%%" % condition_delta, _impact(condition_delta), "Condition affects usable pace and repair exposure."),
			_attribute_metric("Power", current_attributes, candidate_attributes, "power"),
			_attribute_metric("Grip", current_attributes, candidate_attributes, "grip"),
			_attribute_metric("Reliability", current_attributes, candidate_attributes, "reliability"),
			DecisionComparisonModel.metric("Mileage", str(current.mileage) if current != null else "—", str(candidate.mileage), "USED" if candidate.mileage > 0 else "NEW", DecisionComparisonModel.WARNING if candidate.mileage > 0 else DecisionComparisonModel.IMPROVES),
		],
		"upfront_cost": purchase_cost,
		"action_label": "Purchase for %s" % DecisionComparisonModel.money(purchase_cost),
		"action_enabled": eligible and team.money >= purchase_cost,
		"disabled_reason": disabled_reason,
		"recommendation": _car_recommendation(current, candidate, pp_delta),
		"context": {"kind": "car", "candidate": candidate},
	})
	comparison_drawer.display(model)


func _attribute_metric(label: String, current: Dictionary, candidate: Dictionary, key: String) -> Dictionary:
	var current_value := roundi(float(current.get(key, 0.0)))
	var candidate_value := roundi(float(candidate.get(key, 0.0)))
	var delta := candidate_value - current_value
	return DecisionComparisonModel.metric(label, str(current_value) if not current.is_empty() else "—", str(candidate_value), "%+d" % delta, _impact(delta))


func _best_owned_car(series_id: String) -> Car:
	var best: Car = null
	var best_pp := -1
	for value in GameManager.team.cars:
		var car := value as Car
		if car == null or car.series_id != series_id:
			continue
		var points := car.get_total_performance_points(GameManager.team)
		if points > best_pp:
			best = car
			best_pp = points
	return best


func _car_recommendation(current: Car, candidate: Car, pp_delta: int) -> String:
	if current == null:
		return "This car establishes an eligible baseline for the series. Preserve enough reserve to enter and service the first race."
	if pp_delta > 0 and candidate.condition >= 80:
		return "Clear performance upgrade with manageable condition risk. Check the reserve before committing."
	if pp_delta > 0:
		return "The pace improves, but used-car wear may consume part of the purchase advantage through repairs."
	if current.specialization_id != candidate.specialization_id:
		return "This adds a different track specialization to the fleet. Its strategic value may exceed the raw Performance Point comparison."
	return "This does not improve whole-car Performance Points. Buy only for capacity, condition, or a deliberate rebuild."


func _impact(delta: int) -> int:
	if delta > 0:
		return DecisionComparisonModel.IMPROVES
	if delta < 0:
		return DecisionComparisonModel.WORSENS
	return DecisionComparisonModel.NEUTRAL


func _on_comparison_action(context: Dictionary) -> void:
	if str(context.get("kind", "")) != "car":
		return
	var candidate := context.get("candidate") as Car
	if candidate == null or GameManager.selected_bay < 0:
		GameManager.report_decision_outcome({
			"status": "error",
			"title": "Purchase not completed",
			"message": "No open garage bay is available for this car.",
			"action_label": "Return to garage",
			"action_path": "res://scenes/pages/garage/garage.tscn",
		})
		return
	var cash_before := GameManager.team.money
	var target_bay := GameManager.selected_bay
	if not GameManager.team.buy_car(candidate, GameManager.selected_bay):
		instructions_label.text = "The purchase could not be completed. Check cash, eligibility, and garage capacity."
		GameManager.report_decision_outcome({
			"status": "error",
			"title": "Purchase not completed",
			"message": instructions_label.text,
			"action_label": "Review marketplace",
			"action_path": "res://scenes/pages/dealership/dealership.tscn",
		})
		return
	GameManager.selected_car = GameManager.team.get_car(GameManager.selected_bay)
	GameManager.refresh_team_money()
	GameManager.save_game()
	GameManager.report_decision_outcome({
		"title": "%s added to Bay %d" % [candidate.name, target_bay + 1],
		"message": "Purchase complete. Additional cars require inspection, baseline setup, and a shakedown before racing.",
		"detail": "Open the Fleet Workshop to schedule the new-car programme; the first career car keeps its opening-race exception.",
		"cash_delta": GameManager.team.money - cash_before,
		"action_label": "View new car",
		"action_path": "res://scenes/pages/garage/car_inspection.tscn",
	})
	GameManager.load_page("res://scenes/pages/garage/car_inspection.tscn")


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
