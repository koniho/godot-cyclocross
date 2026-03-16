# ramp_trigger.gd
# Triggers a layer transition for riders passing through
# Attach to Area2D

class_name RampTrigger
extends Area2D

@export var target_layer: int = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.is_in_group("riders"):
		body.current_layer = target_layer
