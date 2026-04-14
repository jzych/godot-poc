extends RefCounted
class_name RenderDomain

const NEAR := "near"
const MID := "mid"
const FAR := "far"

const LAYER_NEAR := 1
const LAYER_MID := 1 << 1
const LAYER_FAR := 1 << 2

static func all_domains() -> Array[String]:
	return [FAR, MID, NEAR]

static func to_layer_mask(domain: String) -> int:
	match domain:
		NEAR:
			return LAYER_NEAR
		FAR:
			return LAYER_FAR
		_:
			return LAYER_MID
