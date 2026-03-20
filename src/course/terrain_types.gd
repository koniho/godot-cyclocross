# terrain_types.gd
# Real-world cyclocross values, scaled at 32px = 1m
# Speeds derived from race data; deceleration from rolling resistance (Crr * g * 32)
# amplified ~3x for game feel while preserving relative ratios

enum Type {
	GRASS,
	PAVEMENT,
	MUD,
	SAND,
	SNOW,
	ICE
}

# max_speed_mult: relative to pavement top speed (420 px/s)
# deceleration: px/s² when not pedaling (rolling resistance, game-scaled)
# grip: steering responsiveness multiplier
const PROPERTIES = {
	Type.GRASS: {
		"name": "Grass",
		"max_speed_mult": 0.76,   # ~320 px/s (36 km/h)
		"deceleration": 15.0,     # coasts to stop in ~21s from full speed
		"grip": 0.9,
		"color": Color(0.3, 0.5, 0.2)
	},
	Type.PAVEMENT: {
		"name": "Pavement",
		"max_speed_mult": 1.0,    # 420 px/s (47 km/h)
		"deceleration": 6.0,      # coasts very efficiently
		"grip": 1.0,
		"color": Color(0.4, 0.4, 0.4)
	},
	Type.MUD: {
		"name": "Mud",
		"max_speed_mult": 0.31,   # ~130 px/s (14 km/h)
		"deceleration": 100.0,    # stops in ~1.3s from mud top speed
		"grip": 0.5,
		"color": Color(0.4, 0.25, 0.1)
	},
	Type.SAND: {
		"name": "Sand",
		"max_speed_mult": 0.26,   # ~110 px/s (12 km/h)
		"deceleration": 120.0,    # very draggy
		"grip": 0.4,
		"color": Color(0.8, 0.7, 0.4)
	},
	Type.SNOW: {
		"name": "Snow",
		"max_speed_mult": 0.65,   # ~270 px/s (30 km/h)
		"deceleration": 50.0,
		"grip": 0.6,
		"color": Color(0.9, 0.95, 1.0)
	},
	Type.ICE: {
		"name": "Ice",
		"max_speed_mult": 0.71,   # ~300 px/s (34 km/h), fast but uncontrollable
		"deceleration": 8.0,      # almost no rolling resistance
		"grip": 0.2,
		"color": Color(0.7, 0.85, 0.95)
	}
}

static func get_properties(type: Type) -> Dictionary:
	return PROPERTIES.get(type, PROPERTIES[Type.GRASS])
