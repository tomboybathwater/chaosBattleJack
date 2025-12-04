extends RefCounted
class_name BlackjackCard 
## Represents a single playing card (standard or chaos)
## Immutable once created - cards don't change their properties

# ============================================================================
# PROPERTIES
# ============================================================================

var suit: BlackjackConstants.Suit
var rank: BlackjackConstants.Rank
var is_face_up: bool = false

## Chaos cards have a dynamic value that changes when rolled
var chaos_value: int = 0


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_suit: BlackjackConstants.Suit, p_rank: BlackjackConstants.Rank):
	suit = p_suit
	rank = p_rank
	
	# Chaos cards are always face up (double-sided)
	if is_chaos():
		is_face_up = true


## Create a standard playing card
static func create_standard(p_suit: BlackjackConstants.Suit, p_rank: BlackjackConstants.Rank) -> BlackjackCard:
	return BlackjackCard.new(p_suit, p_rank)


## Create a chaos card
static func create_chaos() -> BlackjackCard:
	return BlackjackCard.new(BlackjackConstants.Suit.CHAOS, BlackjackConstants.Rank.CHAOS)


# ============================================================================
# CARD TYPE CHECKS
# ============================================================================

## Check if this is a chaos card
func is_chaos() -> bool:
	return suit == BlackjackConstants.Suit.CHAOS and rank == BlackjackConstants.Rank.CHAOS


## Check if this is an Ace (important for soft/hard hand calculations)
func is_ace() -> bool:
	return rank == BlackjackConstants.Rank.ACE


## Check if this is a face card (Jack, Queen, King)
func is_face_card() -> bool:
	return rank in [BlackjackConstants.Rank.JACK, BlackjackConstants.Rank.QUEEN, BlackjackConstants.Rank.KING]


## Check if this is a 10-value card (10, Jack, Queen, King)
func is_ten_value() -> bool:
	return rank == BlackjackConstants.Rank.TEN or is_face_card()


# ============================================================================
# VALUE CALCULATIONS
# ============================================================================

## Get the blackjack value of this card
## For Aces, returns 11 (caller must handle soft/hard logic)
## For chaos cards, returns the current chaos_value
func get_value() -> int:
	if is_chaos():
		return chaos_value
	
	if is_ace():
		return 11  # Caller handles soft vs hard
	
	if is_face_card():
		return 10
	
	# Number cards (2-10) return their rank value
	return rank as int


## Set the chaos value (only works for chaos cards)
func set_chaos_value(value: int) -> void:
	if is_chaos():
		chaos_value = value
	else:
		push_warning("Attempted to set chaos value on non-chaos card")


# ============================================================================
# CARD STATE
# ============================================================================

## Flip the card face up
func flip_up() -> void:
	is_face_up = true


## Flip the card face down (chaos cards can't be flipped down)
func flip_down() -> void:
	if not is_chaos():
		is_face_up = false


## Toggle card face up/down
func flip() -> void:
	if is_face_up:
		flip_down()
	else:
		flip_up()


# ============================================================================
# DISPLAY / DEBUG
# ============================================================================

## Get a short string representation (e.g., "A♠", "K♥", "C⚡")
func to_short_string() -> String:
	if not is_face_up:
		return "[?]"
	
	if is_chaos():
		return "C⚡(%d)" % chaos_value
	
	return "%s%s" % [
		BlackjackConstants.get_rank_short_name(rank),
		BlackjackConstants.get_suit_symbol(suit)
	]


## Get a full string representation (e.g., "Ace of Spades", "Chaos BlackjackCard (value: 2)")
func card_to_string() -> String:
	if not is_face_up:
		return "[Face Down BlackjackCard]"
	
	if is_chaos():
		return "Chaos BlackjackCard (value: %d)" % chaos_value
	
	return "%s of %s" % [
		BlackjackConstants.get_rank_name(rank),
		BlackjackConstants.get_suit_name(suit)
	]


func _card_to_string() -> String:
	return card_to_string()


# ============================================================================
# COMPARISON / EQUALITY
# ============================================================================

## Check if two cards are equal (ignoring face up/down state and chaos value)
func equals(other: BlackjackCard) -> bool:
	if other == null:
		return false
	return suit == other.suit and rank == other.rank


## Check if this card can be split with another (same rank, not chaos)
func can_split_with(other: BlackjackCard) -> bool:
	if is_chaos() or other.is_chaos():
		return false
	
	# Standard split: same rank
	# Alternative rule: any 10-value cards can split (10, J, Q, K)
	# Using standard rule here
	return rank == other.rank


# ============================================================================
# SERIALIZATION (for networking)
# ============================================================================

## Convert card to dictionary for network transmission
func to_dict() -> Dictionary:
	return {
		"suit": suit,
		"rank": rank,
		"is_face_up": is_face_up,
		"chaos_value": chaos_value
	}


## Create a card from a dictionary (for network transmission)
static func from_dict(data: Dictionary) -> BlackjackCard:
	var card = BlackjackCard.new(data["suit"], data["rank"])
	card.is_face_up = data["is_face_up"]
	card.chaos_value = data["chaos_value"]
	return card
