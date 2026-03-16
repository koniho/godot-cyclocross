# terrain_types.gd
# Static terrain definitions - can be autoload or just referenced as const
# Usage: TerrainTypes.PROPERTIES[TerrainTypes.Type.MUD]

class_name TerrainTypes

enum Type {
	GRASS,
	PAVEMENT,
	MUD,
	SAND,
	SNOW,
	ICE
}

# Terrain physics properties
# friction: how quickly you slow down (lower = more drag)
# max_speed_mult: cap on max speed (1.0 = normal)
# grip: steering effectiveness and drift resistance (lower = slidier)
const PROPERTIES = {
	Type.GRASS: {
		"name": "Grass",
		"friction": 0.85,
		"max_speed_mult": 1.0,
		"grip": 0.9,
		"particle": "grass_spray",
		"sound": "terrain_grass"
	},
	Type.PAVEMENT: {
		"name": "Pavement", 
		"friction": 0.92,
		"max_speed_mult": 1.15,
		"grip": 1.0,
		"particle": null,
		"sound": "terrain_pavement"
	},
	Type.MUD: {
		"name": "Mud",
		"friction": 0.70,
		"max_speed_mult": 0.75,
		"grip": 0.5,
		"particle": "mud_spray",
		"sound": "terrain_mud"
	},
	Type.SAND: {
		"name": "Sand",
		"friction": 0.60,
		"max_speed_mult": 0.60,
		"grip": 0.4,
		"particle": "sand_spray",
		"sound": "terrain_sand"
	},
	Type.SNOW: {
		"name": "Snow",
		"friction": 0.80,
		"max_speed_mult": 0.85,
		"grip": 0.6,
		"particle": "snow_spray",
		"sound": "terrain_snow"
	},
	Type.ICE: {
		"name": "Ice",
		"friction": 0.95,  # Low drag but...
		"max_speed_mult": 0.90,
		"grip": 0.2,  # Very low grip
		"particle": "ice_shards",
		"sound": "terrain_ice"
	}
}

# Helper to get properties with fallback
static func get_properties(type: Type) -> Dictionary:
	return PROPERTIES.get(type, PROPERTIES[Type.GRASS])

# Map tile IDs to terrain types (adjust based on your tileset)
# This maps TileMap tile indices to terrain types
const TILE_MAPPING = {
	0: Type.GRASS,
	1: Type.GRASS,  # Grass variant
	2: Type.GRASS,  # Grass variant
	10: Type.PAVEMENT,
	11: Type.PAVEMENT,
	20: Type.MUD,
	21: Type.MUD,
	22: Type.MUD,
	30: Type.SAND,
	31: Type.SAND,
	40: Type.SNOW,
	41: Type.SNOW,
	50: Type.ICE,
	51: Type.ICE
}

static func get_type_from_tile(tile_id: int) -> Type:
	return TILE_MAPPING.get(tile_id, Type.GRASS)

# Color hints for debug/minimap
const DEBUG_COLORS = {
	Type.GRASS: Color(0.3, 0.6, 0.2),
	Type.PAVEMENT: Color(0.4, 0.4, 0.4),
	Type.MUD: Color(0.4, 0.25, 0.1),
	Type.SAND: Color(0.8, 0.7, 0.4),
	Type.SNOW: Color(0.9, 0.95, 1.0),
	Type.ICE: Color(0.7, 0.85, 0.95)
}

static func get_debug_color(type: Type) -> Color:
	return DEBUG_COLORS.get(type, Color.MAGENTA)
