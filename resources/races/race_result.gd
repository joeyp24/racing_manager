class_name RaceResult
extends RefCounted

var race: Race = null
var player_car: Car = null

var finishing_position: int = 0
var field_size: int = 0

var championship_points_earned: int = 0
var total_championship_points: int = 0

var prize_money: int = 0
var entry_fee: int = 0
var net_earnings: int = 0

var mileage_added: int = 0
var condition_lost: int = 0

var standings: Array[Dictionary] = []
