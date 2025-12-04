extends Object
class_name BlackjackConstants
## Central location for all game constants and identifiers
## Prevents typos and ensures consistency across the codebase

# ============================================================================
# WIN CONDITION IDENTIFIERS
# ============================================================================
## These strings are used in PayoutRule.condition_name and hand evaluation

const WIN_BLACKJACK = "blackjack"
const WIN_STANDARD = "standard_win"
const WIN_FIVE_CARD = "five_card"
const WIN_TRIPLE_CHAOS = "triple_chaos"
const WIN_PUSH = "push"

# ============================================================================
# CARD SUITS
# ============================================================================

enum Suit {
	HEARTS,
	DIAMONDS,
	CLUBS,
	SPADES,
	CHAOS  # Special suit for chaos cards
}

# ============================================================================
# CARD RANKS
# ============================================================================

enum Rank {
	ACE = 1,
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	CHAOS = 99  # Special rank for chaos cards
}

# ============================================================================
# PLAYER ACTIONS
# ============================================================================

enum Action {
	HIT,
	STAND,
	DOUBLE_DOWN,
	SPLIT,
	SURRENDER,
	INSURANCE_YES,
	INSURANCE_NO
}

# ============================================================================
# GAME STATES
# ============================================================================

enum GameState {
	WAITING_FOR_BETS,
	DEALING_INITIAL_CARDS,
	CHECKING_FOR_BLACKJACK,
	OFFERING_INSURANCE,
	PLAYER_TURN,
	DEALER_TURN,
	RESOLVING_HANDS,
	ROUND_COMPLETE
}

# ============================================================================
# HAND STATUS
# ============================================================================

enum HandStatus {
	ACTIVE,        # Still playing
	STOOD,         # Player chose to stand
	BUSTED,        # Over 21
	BLACKJACK,     # Natural 21
	FIVE_CARD,     # 5 cards without busting (auto-stand)
	TRIPLE_CHAOS,  # 3 chaos cards without busting (auto-stand)
	SURRENDERED    # Player surrendered
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get display name for a suit
static func get_suit_name(suit: Suit) -> String:
	match suit:
		Suit.HEARTS: return "Hearts"
		Suit.DIAMONDS: return "Diamonds"
		Suit.CLUBS: return "Clubs"
		Suit.SPADES: return "Spades"
		Suit.CHAOS: return "Chaos"
		_: return "Unknown"


## Get display name for a rank
static func get_rank_name(rank: Rank) -> String:
	match rank:
		Rank.ACE: return "Ace"
		Rank.TWO: return "2"
		Rank.THREE: return "3"
		Rank.FOUR: return "4"
		Rank.FIVE: return "5"
		Rank.SIX: return "6"
		Rank.SEVEN: return "7"
		Rank.EIGHT: return "8"
		Rank.NINE: return "9"
		Rank.TEN: return "10"
		Rank.JACK: return "Jack"
		Rank.QUEEN: return "Queen"
		Rank.KING: return "King"
		Rank.CHAOS: return "Chaos"
		_: return "Unknown"


## Get short display name for a rank (for compact UI)
static func get_rank_short_name(rank: Rank) -> String:
	match rank:
		Rank.ACE: return "A"
		Rank.JACK: return "J"
		Rank.QUEEN: return "Q"
		Rank.KING: return "K"
		Rank.CHAOS: return "C"
		_: return str(rank)


## Get symbol for a suit (Unicode characters)
static func get_suit_symbol(suit: Suit) -> String:
	match suit:
		Suit.HEARTS: return "♥"
		Suit.DIAMONDS: return "♦"
		Suit.CLUBS: return "♣"
		Suit.SPADES: return "♠"
		Suit.CHAOS: return "⚡"
		_: return "?"
