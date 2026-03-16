# race_controller.gd
# Bootstraps the race: wires up the player to the HUD and starts countdown
extends Node

func _ready():
	# Wire player to HUD
	var hud = get_tree().get_first_node_in_group("hud")
	var player = get_tree().get_first_node_in_group("player")
	if hud and player:
		hud.set_player(player)

	# Start countdown after a short intro delay
	await get_tree().create_timer(0.5).timeout
	GameManager.begin_countdown()
