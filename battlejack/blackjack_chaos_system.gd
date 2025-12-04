extends RefCounted
class_name BlackjackChaosSystem
## Manages chaos card mechanics: dice rolling, chaos meter, and battle rounds
## Chaos meter persists across rounds until a battle round completes
## Chaos card values reset each round

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when chaos dice are rolled
signal chaos_dice_rolled(is_player: bool, dice_value: int, card: BlackjackCard)

## Emitted when chaos points are added to the meter
signal chaos_meter_updated(current_value: int, threshold: int, percentage: float)

## Emitted when the meter reaches threshold and battle round is triggered
signal battle_round_triggered(meter_value: int)

## Emitted when a battle round completes and meter resets
signal battle_round_completed(meter_was: int)

## Emitted when meter resets
signal chaos_meter_reset()


# ============================================================================
# PROPERTIES
# ============================================================================

var rules: BlackjackRulesConfig
var chaos_meter: int = 0
var is_battle_round: bool = false

## RNG for dice rolls - can be seeded for deterministic multiplayer
var rng: RandomNumberGenerator


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_rules: BlackjackRulesConfig, seed_value: int = -1):
	rules = p_rules
	
	# Setup RNG
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# ============================================================================
# DICE ROLLING
# ============================================================================

## Roll the player's chaos dice
func roll_player_dice() -> int:
	if not rules.enable_chaos_cards:
		return 0
	
	var dice_index = rng.randi_range(0, rules.player_chaos_dice.size() - 1)
	var dice_value = rules.player_chaos_dice[dice_index]
	
	return dice_value


## Roll the house's chaos dice
func roll_house_dice() -> int:
	if not rules.enable_chaos_cards:
		return 0
	
	var dice_index = rng.randi_range(0, rules.house_chaos_dice.size() - 1)
	var dice_value = rules.house_chaos_dice[dice_index]
	
	return dice_value


## Roll appropriate dice for a chaos card in a hand
## is_player: true for player hand, false for dealer/house hand
func roll_dice_for_hand(is_player: bool, card: BlackjackCard) -> int:
	if not card.is_chaos():
		push_warning("Attempted to roll dice for non-chaos card")
		return 0
	
	var dice_value = 0
	if is_player:
		dice_value = roll_player_dice()
	else:
		dice_value = roll_house_dice()
	
	# Set the card's chaos value
	card.set_chaos_value(dice_value)
	
	# Emit signal
	chaos_dice_rolled.emit(is_player, dice_value, card)
	
	return dice_value


# ============================================================================
# CHAOS METER MANAGEMENT
# ============================================================================

## Add points to the chaos meter
## This happens when a chaos card enters play with its rolled value
func add_chaos_points(points: int) -> void:
	if not rules.enable_chaos_cards:
		return
	
	chaos_meter += points * rules.chaos_meter_points_per_value
	
	# Emit meter update
	var percentage = get_meter_percentage()
	chaos_meter_updated.emit(chaos_meter, rules.battle_meter_threshold, percentage)
	
	# Check if we've hit the threshold
	if chaos_meter >= rules.battle_meter_threshold and not is_battle_round:
		_trigger_battle_round()


## Get the current chaos meter value
func get_meter_value() -> int:
	return chaos_meter


## Get the meter as a percentage of the threshold (0.0 to 1.0+)
func get_meter_percentage() -> float:
	if rules.battle_meter_threshold == 0:
		return 0.0
	return float(chaos_meter) / float(rules.battle_meter_threshold)


## Check if the meter has reached the threshold
func is_meter_full() -> bool:
	return chaos_meter >= rules.battle_meter_threshold


## Reset the chaos meter (happens after battle round completes)
func reset_meter() -> void:
	var old_value = chaos_meter
	chaos_meter = 0
	is_battle_round = false
	
	chaos_meter_reset.emit()
	chaos_meter_updated.emit(chaos_meter, rules.battle_meter_threshold, 0.0)


# ============================================================================
# BATTLE ROUND MANAGEMENT
# ============================================================================

## Trigger a battle round
func _trigger_battle_round() -> void:
	is_battle_round = true
	battle_round_triggered.emit(chaos_meter)


## Check if currently in a battle round
func is_in_battle_round() -> bool:
	return is_battle_round


## Complete a battle round and reset the meter
func complete_battle_round() -> void:
	if not is_battle_round:
		push_warning("Attempted to complete battle round when not in one")
		return
	
	var old_meter = chaos_meter
	battle_round_completed.emit(old_meter)
	reset_meter()


## Check if the next round should be a battle round
## Call this at the start of each round
func check_for_battle_round() -> bool:
	# If meter is full but we're not in battle round yet, trigger it
	if is_meter_full() and not is_battle_round:
		_trigger_battle_round()
		return true
	
	return is_battle_round


# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

## Process chaos cards when they enter a hand
## This rolls the dice and adds points to the meter
func process_chaos_card_entry(card: BlackjackCard, is_player_hand: bool, hand: BlackjackHand) -> void:
	if not card.is_chaos():
		return
	
	# Roll the dice for this card
	var dice_value = roll_dice_for_hand(is_player_hand, card)
	
	# Update the hand with the new chaos value
	hand.roll_chaos_dice(card, dice_value)
	
	# Add points to the meter
	add_chaos_points(dice_value)


## Reset chaos card values for a new round
## Called at the start of each round to reset all chaos cards to 0
func reset_chaos_cards_in_deck(deck: BlackjackDeck) -> void:
	# Reset all chaos cards in the deck
	for card in deck.cards:
		if card.is_chaos():
			card.set_chaos_value(0)
	
	# Also reset cards in discard pile
	for card in deck.discard_pile:
		if card.is_chaos():
			card.set_chaos_value(0)


## Reset chaos card values in a hand
func reset_chaos_cards_in_hand(hand: BlackjackHand) -> void:
	for card in hand.cards:
		if card.is_chaos():
			card.set_chaos_value(0)


# ============================================================================
# SEED MANAGEMENT (for multiplayer)
# ============================================================================

## Get the current RNG seed
func get_seed() -> int:
	return rng.seed


## Set a new seed (for synchronized multiplayer)
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


# ============================================================================
# DEBUG / UTILITIES
# ============================================================================

## Get a string representation of the chaos system state
func get_status_string() -> String:
	var battle_status = "[BATTLE ROUND]" if is_battle_round else ""
	return "Chaos Meter: %d / %d (%.1f%%) %s" % [
		chaos_meter,
		rules.battle_meter_threshold,
		get_meter_percentage() * 100.0,
		battle_status
	]


## Get detailed info about dice probabilities
func get_dice_info() -> Dictionary:
	var player_avg = 0.0
	for value in rules.player_chaos_dice:
		player_avg += value
	player_avg /= rules.player_chaos_dice.size()
	
	var house_avg = 0.0
	for value in rules.house_chaos_dice:
		house_avg += value
	house_avg /= rules.house_chaos_dice.size()
	
	return {
		"player_dice": rules.player_chaos_dice.duplicate(),
		"player_avg": player_avg,
		"house_dice": rules.house_chaos_dice.duplicate(),
		"house_avg": house_avg
	}


## Simulate rolling both dice types multiple times (for testing)
func simulate_rolls(num_rolls: int = 100) -> Dictionary:
	var player_results = {}
	var house_results = {}
	
	for i in num_rolls:
		var player_roll = roll_player_dice()
		player_results[player_roll] = player_results.get(player_roll, 0) + 1
		
		var house_roll = roll_house_dice()
		house_results[house_roll] = house_results.get(house_roll, 0) + 1
	
	return {
		"player": player_results,
		"house": house_results,
		"num_rolls": num_rolls
	}


# ============================================================================
# SERIALIZATION (for networking)
# ============================================================================

## Convert chaos system state to dictionary for network transmission
func to_dict() -> Dictionary:
	return {
		"chaos_meter": chaos_meter,
		"is_battle_round": is_battle_round,
		"seed": rng.seed
	}


## Restore chaos system state from dictionary
func from_dict(data: Dictionary) -> void:
	chaos_meter = data["chaos_meter"]
	is_battle_round = data["is_battle_round"]
	rng.seed = data["seed"]
	
	# Emit update signal
	var percentage = get_meter_percentage()
	chaos_meter_updated.emit(chaos_meter, rules.battle_meter_threshold, percentage)
