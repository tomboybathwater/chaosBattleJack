extends RefCounted
class_name BlackjackDeck
## Manages the shoe of cards (multiple decks + chaos cards)
## Handles shuffling, dealing, and automatic reshuffling

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when the deck is shuffled
signal shuffled()

## Emitted when a card is dealt
signal card_dealt(card: BlackjackCard)

## Emitted when the deck needs to be reshuffled (below threshold)
signal reshuffle_needed()

## Emitted when deck is reshuffled automatically
signal reshuffled()


# ============================================================================
# PROPERTIES
# ============================================================================

var rules: BlackjackRulesConfig
var cards: Array[BlackjackCard] = []
var discard_pile: Array[BlackjackCard] = []

## RNG for shuffling - can be seeded for deterministic multiplayer
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
	
	# Build and shuffle the initial deck
	_build_deck()
	shuffle()


# ============================================================================
# DECK BUILDING
# ============================================================================

## Build the complete shoe from scratch
func _build_deck() -> void:
	cards.clear()
	discard_pile.clear()
	
	# Add standard decks
	for deck_num in rules.num_decks:
		_add_standard_deck()
	
	# Add chaos cards if enabled
	if rules.enable_chaos_cards:
		for i in rules.num_chaos_cards:
			cards.append(BlackjackCard.create_chaos())


## Add one standard 52-card deck
func _add_standard_deck() -> void:
	var suits = [
		BlackjackConstants.Suit.HEARTS,
		BlackjackConstants.Suit.DIAMONDS,
		BlackjackConstants.Suit.CLUBS,
		BlackjackConstants.Suit.SPADES
	]
	
	var ranks = [
		BlackjackConstants.Rank.ACE,
		BlackjackConstants.Rank.TWO,
		BlackjackConstants.Rank.THREE,
		BlackjackConstants.Rank.FOUR,
		BlackjackConstants.Rank.FIVE,
		BlackjackConstants.Rank.SIX,
		BlackjackConstants.Rank.SEVEN,
		BlackjackConstants.Rank.EIGHT,
		BlackjackConstants.Rank.NINE,
		BlackjackConstants.Rank.TEN,
		BlackjackConstants.Rank.JACK,
		BlackjackConstants.Rank.QUEEN,
		BlackjackConstants.Rank.KING
	]
	
	for suit in suits:
		for rank in ranks:
			cards.append(BlackjackCard.create_standard(suit, rank))


# ============================================================================
# SHUFFLING
# ============================================================================

## Shuffle the deck using Fisher-Yates algorithm
func shuffle() -> void:
	var n = cards.size()
	for i in range(n - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp
	
	shuffled.emit()


## Rebuild deck from discard pile and shuffle (when below threshold)
func reshuffle() -> void:
	# Return all discarded cards to the deck
	cards.append_array(discard_pile)
	discard_pile.clear()
	
	# Shuffle everything
	shuffle()
	
	reshuffled.emit()


## Check if deck needs reshuffling based on threshold
func needs_reshuffle() -> bool:
	return cards.size() <= rules.reshuffle_threshold


# ============================================================================
# DEALING
# ============================================================================

## Deal one card from the top of the deck
## Returns null if deck is empty (shouldn't happen with auto-reshuffle)
func deal_card(face_up: bool = true) -> BlackjackCard:
	# Auto-reshuffle if needed
	if needs_reshuffle():
		reshuffle_needed.emit()
		reshuffle()
	
	if cards.is_empty():
		push_error("Deck is empty! This shouldn't happen.")
		return null
	
	var card = cards.pop_back()
	
	# Set face state (chaos cards ignore this, they're always face up)
	if face_up:
		card.flip_up()
	else:
		card.flip_down()
	
	card_dealt.emit(card)
	return card


## Deal multiple cards at once
func deal_cards(count: int, face_up: bool = true) -> Array[BlackjackCard]:
	var dealt_cards: Array[BlackjackCard] = []
	for i in count:
		var card = deal_card(face_up)
		if card:
			dealt_cards.append(card)
	return dealt_cards


# ============================================================================
# DISCARD PILE
# ============================================================================

## Add a card to the discard pile
func discard(card: BlackjackCard) -> void:
	discard_pile.append(card)


## Add multiple cards to the discard pile
func discard_multiple(card_array: Array[BlackjackCard]) -> void:
	discard_pile.append_array(card_array)


# ============================================================================
# DECK STATE
# ============================================================================

## Get the number of cards remaining in the deck
func cards_remaining() -> int:
	return cards.size()


## Get the number of cards in the discard pile
func cards_discarded() -> int:
	return discard_pile.size()


## Get the total number of cards (deck + discard)
func total_cards() -> int:
	return cards.size() + discard_pile.size()


## Get the percentage of cards remaining (0.0 to 1.0)
func deck_percentage() -> float:
	var total = total_cards()
	if total == 0:
		return 0.0
	return float(cards.size()) / float(total)


## Check if deck is empty
func is_empty() -> bool:
	return cards.is_empty()


# ============================================================================
# SEED MANAGEMENT (for multiplayer)
# ============================================================================

## Get the current RNG seed
func get_seed() -> int:
	return rng.seed


## Set a new seed and reshuffle (for synchronized multiplayer)
func set_seed_and_reshuffle(seed_value: int) -> void:
	rng.seed = seed_value
	_build_deck()
	shuffle()


# ============================================================================
# DEBUG / UTILITIES
# ============================================================================

## Get a string representation of the deck state
func get_deck_info() -> String:
	return "Deck: %d cards remaining, %d discarded, %.1f%% remaining" % [
		cards_remaining(),
		cards_discarded(),
		deck_percentage() * 100.0
	]


## Peek at the top card without dealing it (for debugging)
func peek_top_card() -> BlackjackCard:
	if cards.is_empty():
		return null
	return cards[cards.size() - 1]


## Get all cards of a specific type (for testing/debugging)
func count_card_type(check_chaos: bool = false) -> int:
	var count = 0
	for card in cards:
		if card.is_chaos() == check_chaos:
			count += 1
	return count


## Count chaos cards remaining in deck
func count_chaos_cards() -> int:
	return count_card_type(true)


## Count standard cards remaining in deck
func count_standard_cards() -> int:
	return count_card_type(false)


# ============================================================================
# SERIALIZATION (for networking)
# ============================================================================

## Convert deck state to dictionary for network transmission
## Note: Only sends state, not all cards (that would be cheating!)
func to_dict() -> Dictionary:
	return {
		"cards_remaining": cards_remaining(),
		"cards_discarded": cards_discarded(),
		"seed": rng.seed,
		"needs_reshuffle": needs_reshuffle()
	}


## For host/dealer only - full deck state
func to_full_dict() -> Dictionary:
	var cards_data = []
	for card in cards:
		cards_data.append(card.to_dict())
	
	var discard_data = []
	for card in discard_pile:
		discard_data.append(card.to_dict())
	
	return {
		"cards": cards_data,
		"discard_pile": discard_data,
		"seed": rng.seed
	}


## Restore deck from full state (host/dealer only)
func from_full_dict(data: Dictionary) -> void:
	rng.seed = data["seed"]
	
	cards.clear()
	for card_data in data["cards"]:
		cards.append(BlackjackCard.from_dict(card_data))
	
	discard_pile.clear()
	for card_data in data["discard_pile"]:
		discard_pile.append(BlackjackCard.from_dict(card_data))
