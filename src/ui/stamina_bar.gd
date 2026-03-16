# stamina_bar.gd
extends ProgressBar

@export var low_stamina_color: Color = Color(0.8, 0.2, 0.2)
@export var normal_color: Color = Color(0.2, 0.7, 0.3)
@export var bonk_threshold: float = 20.0

var default_style: StyleBox = null

func _ready():
	default_style = get_theme_stylebox("fill")

func _process(_delta):
	if value < bonk_threshold:
		modulate = low_stamina_color
	else:
		modulate = normal_color
