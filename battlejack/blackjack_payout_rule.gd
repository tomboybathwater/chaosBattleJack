extends Resource
class_name BlackjackPayoutRule
## Defines payout structure for a win condition
## Can have both a principle payout (when primary win) and bonus payout (when secondary)

## Name/identifier for this payout rule
## Should use one of: "blackjack", "standard_win", "five_card", "triple_chaos", "push"
## See BlackjackConstants.WIN_* for the canonical list
@export var condition_name: String = ""

## Multiplier applied to bet when this is the PRIMARY win condition
## Examples: 1.0 = 1:1 (even money), 1.5 = 3:2, 2.0 = 2:1
@export var principle_payout: float = 1.0

## Flat bonus amount (in multiples of min_bet) when this is a SECONDARY win condition
## Example: 3.0 means +3x the table's minimum bet
@export var bonus_payout: float = 0.0

## Human-readable description of this payout
@export_multiline var description: String = ""


func _to_string() -> String:
	return "%s: %.1f:1 principle, +%.0fx min_bet bonus" % [
		condition_name, principle_payout, bonus_payout
	]


## Validate that this payout rule uses a recognized condition name
func validate() -> bool:
	var valid_conditions = [
		BlackjackConstants.WIN_BLACKJACK,
		BlackjackConstants.WIN_STANDARD,
		BlackjackConstants.WIN_FIVE_CARD,
		BlackjackConstants.WIN_TRIPLE_CHAOS,
		BlackjackConstants.WIN_PUSH
	]
	return condition_name in valid_conditions


## Get a warning message if this rule is invalid
func get_validation_warning() -> String:
	if validate():
		return ""
	return "Warning: '%s' is not a recognized win condition. Use BlackjackConstants.WIN_* values." % condition_name
