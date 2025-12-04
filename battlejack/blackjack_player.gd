extends RefCounted
class_name BlackjackPlayer
## Represents a player at the blackjack table (human or AI)
## Manages hands, chips, betting, and player state

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when player's chip count changes
signal chips_changed(new_amount: int, delta: int)

## Emitted when player places a bet
signal bet_placed(amount: int)

## Emitted when player wins chips
signal chips_won(amount: int)

## Emitted when player loses chips
signal chips_lost(amount: int)

## Emitted when a new hand is added (from splitting)
signal hand_added(hand: BlackjackHand)

## Emitted when player is out of chips
signal busted_out()


# ============================================================================
# PLAYER TYPES
# ============================================================================

enum PlayerType {
	HUMAN,        # Local human player
	AI,           # Computer-controlled player
	NETWORK,      # Remote human player
	DEALER        # The house/dealer (special player type)
}


# ============================================================================
# PROPERTIES
# ============================================================================

var player_id: String  # Unique identifier
var player_name: String
var player_type: PlayerType

var chips: int = 0
var hands: Array[BlackjackHand] = []  # Usually 1, but can be multiple from splitting

var rules: BlackjackRulesConfig

## Current bet for the round (before splitting)
var current_bet: int = 0

## Track if player is active in the current round
var is_active: bool = true

## Track if player is sitting out (can be used for "leave table" functionality)
var is_sitting_out: bool = false


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_id: String, p_name: String, p_type: PlayerType, p_rules: BlackjackRulesConfig, starting_chips: int = 1000):
	player_id = p_id
	player_name = p_name
	player_type = p_type
	rules = p_rules
	chips = starting_chips


## Create a human player
static func create_human(id: String, name: String, rules: BlackjackRulesConfig, starting_chips: int = 1000) -> BlackjackPlayer:
	return BlackjackPlayer.new(id, name, PlayerType.HUMAN, rules, starting_chips)


## Create an AI player
static func create_ai(id: String, name: String, rules: BlackjackRulesConfig, starting_chips: int = 1000) -> BlackjackPlayer:
	return BlackjackPlayer.new(id, name, PlayerType.AI, rules, starting_chips)


## Create a network player
static func create_network(id: String, name: String, rules: BlackjackRulesConfig, starting_chips: int = 1000) -> BlackjackPlayer:
	return BlackjackPlayer.new(id, name, PlayerType.NETWORK, rules, starting_chips)


## Create the dealer
static func create_dealer(rules: BlackjackRulesConfig) -> BlackjackPlayer:
	var dealer = BlackjackPlayer.new("dealer", "Dealer", PlayerType.DEALER, rules, 0)
	dealer.chips = -1  # Dealer has unlimited chips
	return dealer


# ============================================================================
# CHIP MANAGEMENT
# ============================================================================

## Add chips to the player's stack
func add_chips(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_chips = chips
	chips += amount
	chips_changed.emit(chips, amount)
	chips_won.emit(amount)


## Remove chips from the player's stack
func remove_chips(amount: int) -> bool:
	if amount <= 0:
		return false
	
	# Dealer has unlimited chips
	if player_type == PlayerType.DEALER:
		chips_lost.emit(amount)
		return true
	
	if chips < amount:
		return false  # Not enough chips
	
	var old_chips = chips
	chips -= amount
	chips_changed.emit(chips, -amount)
	chips_lost.emit(amount)
	
	# Check if player is out of chips
	if chips == 0:
		busted_out.emit()
	
	return true


## Check if player can afford a bet
func can_afford(amount: int) -> bool:
	if player_type == PlayerType.DEALER:
		return true  # Dealer has unlimited chips
	return chips >= amount


## Check if player has enough chips to play
func has_chips() -> bool:
	if player_type == PlayerType.DEALER:
		return true
	return chips > 0


## Get the number of chips
func get_chips() -> int:
	return chips


# ============================================================================
# BETTING
# ============================================================================

## Place a bet for the round (deducts chips)
func place_bet(amount: int) -> bool:
	# Validate bet amount
	if amount < rules.min_bet or amount > rules.max_bet:
		push_warning("Bet amount %d outside valid range [%d, %d]" % [amount, rules.min_bet, rules.max_bet])
		return false
	
	# Check if player can afford it
	if not can_afford(amount):
		push_warning("Player %s cannot afford bet of %d (has %d)" % [player_name, amount, chips])
		return false
	
	# Deduct chips
	if not remove_chips(amount):
		return false
	
	current_bet = amount
	bet_placed.emit(amount)
	
	# Create initial hand with this bet
	var hand = BlackjackHand.new(rules, amount)
	hands.append(hand)
	hand_added.emit(hand)
	
	return true


## Get the total amount bet across all hands (after splits)
func get_total_bet() -> int:
	var total = 0
	for hand in hands:
		total += hand.bet
	return total


# ============================================================================
# HAND MANAGEMENT
# ============================================================================

## Get the current active hand (for player's turn)
func get_active_hand() -> BlackjackHand:
	# Find the first hand that is still active and can be played
	for hand in hands:
		if hand.can_hit() or hand.can_stand():
			return hand
	return null


## Get all hands
func get_hands() -> Array[BlackjackHand]:
	return hands


## Get the number of hands (1 normally, more after splitting)
func get_hand_count() -> int:
	return hands.size()


## Clear all hands (at the end of a round)
func clear_hands() -> void:
	hands.clear()
	current_bet = 0


## Split a hand into two hands
func split_hand(hand: BlackjackHand) -> BlackjackHand:
	if not hand.can_split():
		push_warning("Cannot split this hand")
		return null
	
	# Check if player can afford the split (need to match the bet)
	if not can_afford(hand.bet):
		push_warning("Cannot afford to split (need %d chips)" % hand.bet)
		return null
	
	# Deduct chips for the second hand's bet
	if not remove_chips(hand.bet):
		return null
	
	# Remove one card from the original hand
	var card_to_move = hand.cards[1]
	hand.remove_card(card_to_move)
	
	# Create new hand with the same bet
	var new_hand = BlackjackHand.new(rules, hand.bet)
	new_hand.add_card(card_to_move)
	new_hand.is_split_hand = true
	new_hand.split_count = hand.split_count + 1
	
	# Mark original hand as split
	hand.is_split_hand = true
	hand.split_count += 1
	
	# Add new hand to player's hands
	hands.append(new_hand)
	hand_added.emit(new_hand)
	
	return new_hand


## Double down on a hand (doubles the bet and takes one more card)
func double_down_hand(hand: BlackjackHand) -> bool:
	if not hand.can_double_down():
		push_warning("Cannot double down on this hand")
		return false
	
	# Check if player can afford to double
	if not can_afford(hand.bet):
		push_warning("Cannot afford to double down (need %d chips)" % hand.bet)
		return false
	
	# Deduct chips for the additional bet
	if not remove_chips(hand.bet):
		return false
	
	# Double the hand's bet
	hand.bet *= 2
	
	return true


# ============================================================================
# ROUND STATE
# ============================================================================

## Check if player has any active hands
func has_active_hands() -> bool:
	for hand in hands:
		if hand.can_hit() or hand.can_stand():
			return true
	return false


## Check if all hands are resolved (stood, busted, or auto-stood)
func all_hands_resolved() -> bool:
	if hands.is_empty():
		return true
	
	for hand in hands:
		if hand.status == BlackjackConstants.HandStatus.ACTIVE:
			return false
	
	return true


## Reset for a new round
func reset_for_new_round() -> void:
	clear_hands()
	is_active = true


# ============================================================================
# PAYOUT RESOLUTION
# ============================================================================

## Resolve payout for a single hand against dealer
func resolve_hand_payout(hand: BlackjackHand, dealer_hand: BlackjackHand, is_battle_round: bool = false) -> int:
	# Handle surrender
	if hand.status == BlackjackConstants.HandStatus.SURRENDERED:
		var surrender_return = hand.bet / 2
		add_chips(surrender_return)
		return surrender_return - hand.bet  # Net loss is half the bet
	
	# Handle insurance separately
	var insurance_payout = 0
	if hand.has_insurance:
		insurance_payout = rules.calculate_insurance_payout(hand.insurance_bet, dealer_hand.is_blackjack())
		if insurance_payout > 0:
			add_chips(insurance_payout)
	
	# If player busted, they lose (bet already taken)
	if hand.is_busted():
		return -hand.bet + insurance_payout
	
	# Compare hands
	var comparison = hand.compare_to(dealer_hand)
	
	var net_payout = 0
	
	if comparison > 0:
		# Player wins
		var primary = hand.get_primary_win_condition()
		var secondary = hand.get_secondary_win_conditions()
		var total_payout = rules.calculate_payout(hand.bet, primary, secondary, is_battle_round)
		add_chips(total_payout)
		net_payout = total_payout - hand.bet  # Net winnings
		
	elif comparison < 0:
		# Player loses (bet already taken)
		net_payout = -hand.bet
		
	else:
		# Push - return bet
		add_chips(hand.bet)
		net_payout = 0
	
	return net_payout + insurance_payout


## Resolve all hands for this player
func resolve_all_hands(dealer_hand: BlackjackHand, is_battle_round: bool = false) -> int:
	var total_net = 0
	
	for hand in hands:
		var net = resolve_hand_payout(hand, dealer_hand, is_battle_round)
		total_net += net
	
	return total_net


# ============================================================================
# PLAYER TYPE CHECKS
# ============================================================================

func is_human() -> bool:
	return player_type == PlayerType.HUMAN


func is_ai() -> bool:
	return player_type == PlayerType.AI


func is_network() -> bool:
	return player_type == PlayerType.NETWORK


func is_dealer() -> bool:
	return player_type == PlayerType.DEALER


# ============================================================================
# DISPLAY / DEBUG
# ============================================================================

## Get a string representation of the player
func player_to_string() -> String:
	var type_str = ""
	match player_type:
		PlayerType.HUMAN: type_str = "Human"
		PlayerType.AI: type_str = "AI"
		PlayerType.NETWORK: type_str = "Network"
		PlayerType.DEALER: type_str = "Dealer"
	
	var chip_str = str(chips) if chips >= 0 else "Unlimited"
	
	return "%s (%s) - Chips: %s, Hands: %d" % [
		player_name,
		type_str,
		chip_str,
		hands.size()
	]


func _player_to_string() -> String:
	return player_to_string()


# ============================================================================
# SERIALIZATION (for networking)
# ============================================================================

## Convert player to dictionary for network transmission
func to_dict() -> Dictionary:
	var hands_data = []
	for hand in hands:
		hands_data.append(hand.to_dict())
	
	return {
		"player_id": player_id,
		"player_name": player_name,
		"player_type": player_type,
		"chips": chips,
		"hands": hands_data,
		"current_bet": current_bet,
		"is_active": is_active,
		"is_sitting_out": is_sitting_out
	}


## Restore player from dictionary
func from_dict(data: Dictionary) -> void:
	player_id = data["player_id"]
	player_name = data["player_name"]
	player_type = data["player_type"]
	chips = data["chips"]
	current_bet = data["current_bet"]
	is_active = data["is_active"]
	is_sitting_out = data["is_sitting_out"]
	
	hands.clear()
	for hand_data in data["hands"]:
		var hand = BlackjackHand.new(rules, 0)
		hand.from_dict(hand_data)
		hands.append(hand)
