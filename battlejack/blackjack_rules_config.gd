extends Resource
class_name BlackjackRulesConfig
## Configuration resource for Blackjack game rules
## All customizable aspects of the game in one place

# ============================================================================
# FEATURE TOGGLES
# ============================================================================

@export_group("Feature Toggles")

## Enable chaos card mechanics (dice rolls, battle rounds, etc.)
@export var enable_chaos_cards: bool = true

## Enable 5-card win condition (5 cards without busting)
@export var enable_five_card_win: bool = true

## Enable triple chaos win condition (3 chaos cards without busting)
@export var enable_triple_chaos_win: bool = true

## Enable insurance side bet when dealer shows Ace
@export var enable_insurance: bool = true

## Enable surrender option (forfeit hand for half bet back)
@export var enable_surrender: bool = false


# ============================================================================
# DECK CONFIGURATION
# ============================================================================

@export_group("Deck Configuration")

## Number of standard 52-card decks to use (before adding chaos cards)
@export_range(1, 8) var num_decks: int = 2

## Number of chaos cards to add to the total deck (ignored if chaos disabled)
@export_range(0, 20) var num_chaos_cards: int = 4

## When deck has this many cards or fewer remaining, reshuffle
@export_range(10, 100) var reshuffle_threshold: int = 20


# ============================================================================
# CHAOS CARD MECHANICS
# ============================================================================

@export_group("Chaos Mechanics")

## Values on the player's chaos dice (6 sides)
@export var player_chaos_dice: Array[int] = [0, 0, 1, 1, 2, 2]

## Values on the house's chaos dice (6 sides)
@export var house_chaos_dice: Array[int] = [0, 0, 2, 2, 4, 4]

## Points added to battle meter per chaos card value point
@export_range(1, 100) var chaos_meter_points_per_value: int = 1

## Battle meter threshold - when reached, next round is a battle round
@export_range(10, 500) var battle_meter_threshold: int = 50

## Multiplier for winnings during battle rounds
@export_range(1.0, 10.0) var battle_round_multiplier: float = 3.0


# ============================================================================
# BETTING CONFIGURATION
# ============================================================================

@export_group("Betting")

## Minimum bet allowed at this table
@export_range(1, 10000) var min_bet: int = 10

## Maximum bet allowed at this table
@export_range(1, 100000) var max_bet: int = 1000

## Default bet amount when joining table
@export_range(1, 10000) var default_bet: int = 10

## Insurance bet is half the original bet and pays 2:1 if dealer has blackjack
@export var insurance_payout: float = 2.0


# ============================================================================
# STANDARD BLACKJACK RULES
# ============================================================================

@export_group("Standard Rules")

## Dealer must hit on soft 17 (Ace + 6)
@export var dealer_hits_soft_17: bool = true

## Allow players to double down
@export var allow_double_down: bool = true

## Allow players to split pairs
@export var allow_split: bool = true

## Maximum number of times a player can split
@export_range(0, 3) var max_splits: int = 1

## Can double down after splitting
@export var double_after_split: bool = true

## Dealer peeks for blackjack (when showing Ace or 10-value card)
@export var dealer_peeks: bool = true


# ============================================================================
# WIN CONDITION PAYOUTS
# ============================================================================

@export_group("Payouts")

## Array of payout rules for different win conditions
## Create BlackjackPayoutRule resources and add them here
@export var payout_rules: Array[BlackjackPayoutRule] = []


# ============================================================================
# AI DIFFICULTY SCALING
# ============================================================================

@export_group("AI Behavior")

## AI difficulty tiers based on table stakes
enum AIDifficulty {
	BASIC,      # Simple hit/stand based on total
	MODERATE,   # Considers dealer upcard
	ADVANCED,   # Considers win conditions, basic chaos strategy
	EXPERT      # Full optimization including chaos meter timing
}

## Threshold for each difficulty tier (based on max_bet)
@export var ai_difficulty_thresholds: Dictionary = {
	0: AIDifficulty.BASIC,
	100: AIDifficulty.MODERATE,
	500: AIDifficulty.ADVANCED,
	1000: AIDifficulty.EXPERT
}

## How aggressive is the house with chaos cards (0.0 = never, 1.0 = always when possible)
@export_range(0.0, 1.0) var house_chaos_aggression: float = 0.5


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Setup default payout rules if array is empty
	if payout_rules.is_empty():
		_setup_default_payouts()


func _setup_default_payouts():
	# Create default BlackjackPayoutRule resources using constants
	var blackjack_rule = BlackjackPayoutRule.new()
	blackjack_rule.condition_name = BlackjackConstants.WIN_BLACKJACK
	blackjack_rule.principle_payout = 1.5
	blackjack_rule.bonus_payout = 3.0
	blackjack_rule.description = "Natural 21 with first two cards"
	
	var standard_win_rule = BlackjackPayoutRule.new()
	standard_win_rule.condition_name = BlackjackConstants.WIN_STANDARD
	standard_win_rule.principle_payout = 1.0
	standard_win_rule.bonus_payout = 0.0
	standard_win_rule.description = "Beat dealer without special conditions"
	
	var five_card_rule = BlackjackPayoutRule.new()
	five_card_rule.condition_name = BlackjackConstants.WIN_FIVE_CARD
	five_card_rule.principle_payout = 1.5
	five_card_rule.bonus_payout = 2.0
	five_card_rule.description = "5 cards without busting"
	
	var triple_chaos_rule = BlackjackPayoutRule.new()
	triple_chaos_rule.condition_name = BlackjackConstants.WIN_TRIPLE_CHAOS
	triple_chaos_rule.principle_payout = 2.0
	triple_chaos_rule.bonus_payout = 5.0
	triple_chaos_rule.description = "3 chaos cards without busting"
	
	var push_rule = BlackjackPayoutRule.new()
	push_rule.condition_name = BlackjackConstants.WIN_PUSH
	push_rule.principle_payout = 0.0
	push_rule.bonus_payout = 0.0
	push_rule.description = "Tie with dealer"
	
	payout_rules = [
		blackjack_rule,
		standard_win_rule,
		five_card_rule,
		triple_chaos_rule,
		push_rule
	]


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get the AI difficulty for this table's stakes
func get_ai_difficulty() -> AIDifficulty:
	var thresholds = ai_difficulty_thresholds.keys()
	thresholds.sort()
	
	var difficulty = AIDifficulty.BASIC
	for threshold in thresholds:
		if max_bet >= threshold:
			difficulty = ai_difficulty_thresholds[threshold]
	
	return difficulty


## Get a BlackjackPayoutRule by condition name
func get_payout_rule(condition_name: String) -> BlackjackPayoutRule:
	for rule in payout_rules:
		if rule.condition_name == condition_name:
			return rule
	return null


## Validate that min_bet <= default_bet <= max_bet
func validate_betting_config() -> bool:
	return min_bet <= default_bet and default_bet <= max_bet


## Calculate total payout for a winning hand
func calculate_payout(bet: int, primary_condition: String, secondary_conditions: Array[String], is_battle_round: bool = false) -> int:
	var total_payout = bet  # Start with bet return
	
	# Add primary win condition payout
	var primary_rule = get_payout_rule(primary_condition)
	if primary_rule:
		total_payout += int(bet * primary_rule.principle_payout)
	
	# Add secondary condition bonuses
	for condition in secondary_conditions:
		var secondary_rule = get_payout_rule(condition)
		if secondary_rule:
			total_payout += int(min_bet * secondary_rule.bonus_payout)
	
	# Apply battle round multiplier (but only to winnings, not original bet)
	if is_battle_round and enable_chaos_cards:
		var winnings = total_payout - bet
		winnings = int(winnings * battle_round_multiplier)
		total_payout = bet + winnings
	
	return total_payout


## Calculate insurance payout (separate from main hand)
func calculate_insurance_payout(insurance_bet: int, dealer_has_blackjack: bool) -> int:
	if not enable_insurance:
		return 0
	
	if dealer_has_blackjack:
		return int(insurance_bet * (1.0 + insurance_payout))  # Return bet + payout
	else:
		return 0  # Lose insurance bet


## Get a summary string of this configuration (for debugging/display)
func get_config_summary() -> String:
	var features: Array[String] = []
	if enable_chaos_cards: features.append("chaos")
	if enable_five_card_win: features.append("5-card")
	if enable_triple_chaos_win: features.append("triple-chaos")
	if enable_insurance: features.append("insurance")
	if enable_surrender: features.append("surrender")
	
	return "RulesConfig: %d decks, min/max bet: %d/%d, features: [%s]" % [
		num_decks, min_bet, max_bet, ", ".join(features)
	]


## Validate the entire configuration
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if not validate_betting_config():
		errors.append("Invalid betting config: min_bet must be <= default_bet <= max_bet")
	
	if enable_chaos_cards:
		if player_chaos_dice.size() != 6:
			errors.append("Player chaos dice must have exactly 6 values")
		
		if house_chaos_dice.size() != 6:
			errors.append("House chaos dice must have exactly 6 values")
		
		if num_chaos_cards > num_decks * 52:
			errors.append("Cannot have more chaos cards than total deck cards")
	
	if reshuffle_threshold > num_decks * 52 + (num_chaos_cards if enable_chaos_cards else 0):
		errors.append("Reshuffle threshold is higher than total deck size")
	
	# Validate payout rules
	var condition_names: Array[String] = []
	for rule in payout_rules:
		if rule.condition_name.is_empty():
			errors.append("BlackjackPayoutRule has empty condition_name")
		elif condition_names.has(rule.condition_name):
			errors.append("Duplicate BlackjackPayoutRule condition_name: " + rule.condition_name)
		else:
			condition_names.append(rule.condition_name)
		
		# Check if the rule uses a valid constant
		if not rule.validate():
			errors.append(rule.get_validation_warning())
	
	# Check for required payout rules
	if not get_payout_rule(BlackjackConstants.WIN_BLACKJACK):
		errors.append("Missing required payout rule: blackjack")
	if not get_payout_rule(BlackjackConstants.WIN_STANDARD):
		errors.append("Missing required payout rule: standard_win")
	if not get_payout_rule(BlackjackConstants.WIN_PUSH):
		errors.append("Missing required payout rule: push")
	
	return errors
