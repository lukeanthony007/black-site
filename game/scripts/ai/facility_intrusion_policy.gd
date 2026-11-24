class_name FacilityIntrusionPolicy
extends RefCounted
## Pure institutional response policy. It owns no scene state and performs no effects.

enum Response {
	CLEAR = 0,
	OBSERVE = 1,
	CHALLENGE = 2,
	CONTAIN = 3,
	ENGAGE = 4,
}


## Expected context keys:
## room_authorized, access_denied, custody_violation, visible_weapon,
## suspicious_movement, noise_loudness, compromised_disguise, hostile_act.
## Missing keys take their least severe value so callers can adopt the seam gradually.
static func evaluate(context: Dictionary) -> Response:
	if bool(context.get("hostile_act", false)):
		return Response.ENGAGE
	if (
		bool(context.get("access_denied", false))
		or bool(context.get("custody_violation", false))
		or bool(context.get("compromised_disguise", false))
	):
		return Response.CONTAIN
	if (
		not bool(context.get("room_authorized", true))
		or bool(context.get("visible_weapon", false))
		or float(context.get("noise_loudness", 0.0)) >= 0.7
	):
		return Response.CHALLENGE
	if (
		bool(context.get("suspicious_movement", false))
		or float(context.get("noise_loudness", 0.0)) > 0.0
	):
		return Response.OBSERVE
	return Response.CLEAR
