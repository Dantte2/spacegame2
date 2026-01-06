extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var lifetime: float = 0.5       # fallback in seconds
@export var damage: int = 10            # damage dealt to enemies

func _ready():
	if sprite:
		sprite.play("big")  

		# Calculate animation length if available
		var anim_length = lifetime
		var frames = sprite.sprite_frames
		if frames and frames.has_animation(sprite.animation):
			var frame_count = frames.get_frame_count(sprite.animation)
			var fps = frames.get_animation_speed(sprite.animation)
			if fps > 0:
				anim_length = frame_count / fps

		# Deal damage immediately when explosion spawns
		apply_damage_to_enemies()

		# Wait for animation to finish before freeing
		await get_tree().create_timer(anim_length).timeout

	queue_free()

func apply_damage_to_enemies():
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
