extends RefCounted
class_name BlackjackHand
## Represents a hand of cards in blackjack
## Handles value calculation, win condition detection, and chaos card mechanics

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a card is added to the hand
signal card_added(card: BlackjackCard)

## Emitted when the hand value changes
signal value_changed(new_value: int, is_soft: bool)

## Emitted when hand status changes (e.g., busted, blackjack, stood)
signal status_changed(new_status: BlackjackConstants.HandStatus)

## Emitted when a chaos card triggers a dice roll
signal chaos_triggered(card: BlackjackCard, dice_value: int)


# ============================================================================
# PROPERTIES
# ============================================================================

var cards: Array[BlackjackCard] = []
var status: BlackjackConstants.HandStatus = BlackjackConstants.HandStatus.ACTIVE
var rules: BlackjackRulesConfig

## The bet amount for this hand
var bet: int = 0

## Whether this hand has taken insurance (separate from main bet)
var has_insurance: bool = false
var insurance_bet: int = 0

## Track if this hand resulted from a split
var is_split_hand: bool = false
var split_count: int = 0  # How many times this hand has been split from


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_rules: BlackjackRulesConfig, initial_bet: int = 0):
	rules = p_rules
	bet = initial_bet


# ============================================================================
# CARD MANAGEMENT
# ============================================================================

## Add a card to the hand
func add_card(card: BlackjackCard) -> void:
	cards.append(card)
	card_added.emit(card)
	
	# Check for automatic status changes
	_check_auto_status()
	
	# Emit value change
	var value = get_value()
	var is_soft = is_soft_hand()
	value_changed.emit(value, is_soft)


## Remove a card from the hand (for splitting)
func remove_card(card: BlackjackCard) -> bool:
	var index = cards.find(card)
	if index >= 0:
		cards.remove_at(index)
		return true
	return false


## Clear all cards from the hand
func clear() -> void:
	cards.clear()
	status = BlackjackConstants.HandStatus.ACTIVE
	has_insurance = false
	insurance_bet = 0


# ============================================================================
# VALUE CALCULATION
# ============================================================================

## Get the best valid value for this hand
## Returns the highest value <= 21, or the lowest value if busted
func get_value() -> int:
	var total = 0
	var ace_count = 0
	
	# Sum all card values
	for card in cards:
		var card_value = card.get_value()
		total += card_value
		
		if card.is_ace():
			ace_count += 1
	
	# Adjust for aces (convert from 11 to 1 as needed)
	while total > 21 and ace_count > 0:
		total -= 10  # Convert an ace from 11 to 1
		ace_count -= 1
	
	return total


## Check if this is a "soft" hand (has an ace counting as 11)
func is_soft_hand() -> bool:
	if cards.is_empty():
		return false
	
	var total = 0
	var has_ace = false
	
	for card in cards:
		total += card.get_value()
		if card.is_ace():
			has_ace = true
	
	# A hand is soft if it has an ace AND that ace is counting as 11
	# (i.e., the total would be <= 21)
	if has_ace and total <= 21:
		# Check if converting ace to 1 would give us a different valid value
		var hard_total = total - 10
		return hard_total != total and total <= 21
	
	return false


## Get the number of cards in the hand
func card_count() -> int:
	return cards.size()


# ============================================================================
# HAND STATUS CHECKS
# ============================================================================

## Check if the hand is busted (over 21)
func is_busted() -> bool:
	return get_value() > 21


## Check if this is a natural blackjack (21 with first two cards)
func is_blackjack() -> bool:
	if cards.size() != 2:
		return false
	
	if get_value() != 21:
		return false
	
	# Must have an ace and a 10-value card
	var has_ace = false
	var has_ten = false
	
	for card in cards:
		if card.is_ace():
			has_ace = true
		if card.is_ten_value():
			has_ten = true
	
	return has_ace and has_ten


## Check if this hand qualifies for 5-card win
func is_five_card() -> bool:
	if not rules.enable_five_card_win:
		return false
	
	return cards.size() == 5 and not is_busted()


## Check if this hand qualifies for triple chaos win
func is_triple_chaos() -> bool:
	if not rules.enable_triple_chaos_win or not rules.enable_chaos_cards:
		return false
	
	var chaos_count = 0
	for card in cards:
		if card.is_chaos():
			chaos_count += 1
	
	return chaos_count == 3 and not is_busted()


## Get the number of chaos cards in this hand
func get_chaos_card_count() -> int:
	var count = 0
	for card in cards:
		if card.is_chaos():
			count += 1
	return count


# ============================================================================
# AUTOMATIC STATUS DETECTION
# ============================================================================

## Check for automatic status changes (blackjack, bust, 5-card, triple chaos)
func _check_auto_status() -> void:
	if status != BlackjackConstants.HandStatus.ACTIVE:
		return  # Don't change status if already set
	
	# Check for bust
	if is_busted():
		_set_status(BlackjackConstants.HandStatus.BUSTED)
		return
	
	# Check for blackjack (only on initial 2 cards)
	if cards.size() == 2 and is_blackjack():
		_set_status(BlackjackConstants.HandStatus.BLACKJACK)
		return
	
	# Check for 5-card auto-stand
	if is_five_card():
		_set_status(BlackjackConstants.HandStatus.FIVE_CARD)
		return
	
	# Check for triple chaos auto-stand
	if is_triple_chaos():
		_set_status(BlackjackConstants.HandStatus.TRIPLE_CHAOS)
		return


## Set the hand status and emit signal
func _set_status(new_status: BlackjackConstants.HandStatus) -> void:
	if status != new_status:
		status = new_status
		status_changed.emit(new_status)


# ============================================================================
# PLAYER ACTIONS
# ============================================================================

## Player chooses to stand
func stand() -> void:
	if status == BlackjackConstants.HandStatus.ACTIVE:
		_set_status(BlackjackConstants.HandStatus.STOOD)


## Player chooses to surrender
func surrender() -> void:
	if status == BlackjackConstants.HandStatus.ACTIVE and rules.enable_surrender:
		_set_status(BlackjackConstants.HandStatus.SURRENDERED)


## Check if the hand can hit (take another card)
func can_hit() -> bool:
	return status == BlackjackConstants.HandStatus.ACTIVE and not is_busted()


## Check if the hand can stand
func can_stand() -> bool:
	return status == BlackjackConstants.HandStatus.ACTIVE


## Check if the hand can double down
func can_double_down() -> bool:
	if not rules.allow_double_down:
		return false
	
	if status != BlackjackConstants.HandStatus.ACTIVE:
		return false
	
	# Can only double on first decision (2 cards)
	if cards.size() != 2:
		return false
	
	# Check if splitting rules allow doubling after split
	if is_split_hand and not rules.double_after_split:
		return false
	
	return true


## Check if the hand can be split
func can_split() -> bool:
	if not rules.allow_split:
		return false
	
	if status != BlackjackConstants.HandStatus.ACTIVE:
		return false
	
	# Must have exactly 2 cards
	if cards.size() != 2:
		return false
	
	# Check max splits
	if split_count >= rules.max_splits:
		return false
	
	# Cards must be able to split with each other
	return cards[0].can_split_with(cards[1])


## Check if insurance can be offered (dealer shows ace, first decision)
func can_offer_insurance() -> bool:
	if not rules.enable_insurance:
		return false
	
	# Insurance is only offered before any action on initial hand
	return cards.size() == 2 and status == BlackjackConstants.HandStatus.ACTIVE


## Take insurance bet
func take_insurance() -> void:
	if can_offer_insurance():
		has_insurance = true
		insurance_bet = bet / 2  # Insurance is half the original bet


# ============================================================================
# WIN CONDITION EVALUATION
# ============================================================================

## Evaluate all win conditions for this hand
## Returns array of condition names (using BlackjackConstants.WIN_*)
func get_win_conditions() -> Array[String]:
	var conditions: Array[String] = []
	
	# Check if busted or surrendered (no win conditions)
	if is_busted() or status == BlackjackConstants.HandStatus.SURRENDERED:
		return conditions
	
	# Check blackjack
	if is_blackjack():
		conditions.append(BlackjackConstants.WIN_BLACKJACK)
	
	# Check 5-card
	if is_five_card():
		conditions.append(BlackjackConstants.WIN_FIVE_CARD)
	
	# Check triple chaos
	if is_triple_chaos():
		conditions.append(BlackjackConstants.WIN_TRIPLE_CHAOS)
	
	return conditions


## Determine primary win condition (highest priority)
func get_primary_win_condition() -> String:
	var conditions = get_win_conditions()
	
	if conditions.is_empty():
		return BlackjackConstants.WIN_STANDARD
	
	# Priority order: blackjack > triple_chaos > five_card
	if BlackjackConstants.WIN_BLACKJACK in conditions:
		return BlackjackConstants.WIN_BLACKJACK
	
	if BlackjackConstants.WIN_TRIPLE_CHAOS in conditions:
		return BlackjackConstants.WIN_TRIPLE_CHAOS
	
	if BlackjackConstants.WIN_FIVE_CARD in conditions:
		return BlackjackConstants.WIN_FIVE_CARD
	
	return BlackjackConstants.WIN_STANDARD


## Get secondary win conditions (all except primary)
func get_secondary_win_conditions() -> Array[String]:
	var all_conditions = get_win_conditions()
	var primary = get_primary_win_condition()
	
	var secondary: Array[String] = []
	for condition in all_conditions:
		if condition != primary:
			secondary.append(condition)
	
	return secondary


# ============================================================================
# CHAOS CARD MECHANICS
# ============================================================================

## Trigger chaos dice roll for a specific card (called by game logic)
func roll_chaos_dice(card: BlackjackCard, dice_roll: int) -> void:
	if not card.is_chaos():
		push_warning("Attempted to roll chaos dice on non-chaos card")
		return
	
	card.set_chaos_value(dice_roll)
	chaos_triggered.emit(card, dice_roll)
	
	# Recalculate and emit value change
	var value = get_value()
	var is_soft = is_soft_hand()
	value_changed.emit(value, is_soft)
	
	# Check if this changed our status
	_check_auto_status()


## Get total chaos value from all chaos cards in hand
func get_total_chaos_value() -> int:
	var total = 0
	for card in cards:
		if card.is_chaos():
			total += card.chaos_value
	return total


# ============================================================================
# COMPARISON (for resolving against dealer)
# ============================================================================

## Compare this hand to another (typically dealer's hand)
## Returns: 1 if this hand wins, -1 if other wins, 0 for push
func compare_to(other: BlackjackHand) -> int:
	# Busted hand always loses
	if is_busted():
		return -1
	
	# If other hand busted, this hand wins
	if other.is_busted():
		return 1
	
	# Compare values
	var this_value = get_value()
	var other_value = other.get_value()
	
	if this_value > other_value:
		return 1
	elif this_value < other_value:
		return -1
	else:
		return 0  # Push


# ============================================================================
# DISPLAY / DEBUG
# ============================================================================

## Get a string representation of the hand
func hand_to_string() -> String:
	var card_strings: Array[String] = []
	for card in cards:
		card_strings.append(card.to_short_string())
	
	var status_str = ""
	match status:
		BlackjackConstants.HandStatus.BLACKJACK:
			status_str = " [BLACKJACK]"
		BlackjackConstants.HandStatus.BUSTED:
			status_str = " [BUSTED]"
		BlackjackConstants.HandStatus.STOOD:
			status_str = " [STOOD]"
		BlackjackConstants.HandStatus.FIVE_CARD:
			status_str = " [5-CARD]"
		BlackjackConstants.HandStatus.TRIPLE_CHAOS:
			status_str = " [TRIPLE CHAOS]"
		BlackjackConstants.HandStatus.SURRENDERED:
			status_str = " [SURRENDERED]"
	
	return "Hand: %s = %d%s%s" % [
		", ".join(card_strings),
		get_value(),
		" (soft)" if is_soft_hand() else "",
		status_str
	]


func _hand_to_string() -> String:
	return hand_to_string()


# ============================================================================
# SERIALIZATION (for networking)
# ============================================================================

## Convert hand to dictionary for network transmission
func to_dict() -> Dictionary:
	var cards_data = []
	for card in cards:
		cards_data.append(card.to_dict())
	
	return {
		"cards": cards_data,
		"status": status,
		"bet": bet,
		"has_insurance": has_insurance,
		"insurance_bet": insurance_bet,
		"is_split_hand": is_split_hand,
		"split_count": split_count
	}


## Restore hand from dictionary
func from_dict(data: Dictionary) -> void:
	cards.clear()
	for card_data in data["cards"]:
		cards.append(BlackjackCard.from_dict(card_data))
	
	status = data["status"]
	bet = data["bet"]
	has_insurance = data["has_insurance"]
	insurance_bet = data["insurance_bet"]
	is_split_hand = data["is_split_hand"]
	split_count = data["split_count"]
