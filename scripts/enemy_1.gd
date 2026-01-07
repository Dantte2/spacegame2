extends CharacterBody2D

signal enemy_died  # <--- important! Spawner listens to this

enum State { IDLE, REPOSITION, ATTACK }
var state: State = State.IDLE

# -----------------------------
# Enemy stats
# -----------------------------
@export var health := 50
@export var death_animation_scene: PackedScene
@export var laser_scene: PackedScene
@export var ghost_scene: PackedScene  

@export var fire_rate := 1.5
@export var reposition_speed := 1200.0
@export var min_distance := 700.0
@export var max_distance := 900.0

@export var burst_count := 7
@export var burst_delay := 0.1
@export var spread_angle := 10.0
@export var aim_cone_bias := true

@onready var bullet_spawn := $BulletSpawn
@onready var sprite := $Sprite2D
@export var rotation_speed := 5.0  
@onready var muzzle_flash := $BulletSpawn/MuzzleFlash

# Ghost / afterimage variables
var ghost_timer := 0.0
@export var ghost_interval := 0.05  

# Internal variables
var player: CharacterBody2D
var target_pos := Vector2.ZERO
var running := true

# -----------------------------
# Lifecycle
# -----------------------------
func _ready():
	var players = get_tree().get_nodes_in_group("player_body")
	if players.size() > 0:
		player = players[0]
	loop()

func _exit_tree():
	running = false

func loop() -> void:
	await get_tree().process_frame
	while running and player:
		# --- Attack phase ---
		state = State.ATTACK
		await shoot_burst()

		# --- Reposition phase ---
		state = State.REPOSITION
		choose_reposition_target()

		while running and state == State.REPOSITION:
			await get_tree().process_frame

		await get_tree().create_timer(fire_rate).timeout

# -----------------------------
# Physics / movement
# -----------------------------
func _physics_process(_delta):
	if not player:
		return

	# Rotate sprite to face player
	var direction = (player.global_position - global_position).normalized()
	sprite.rotation = lerp_angle(sprite.rotation, direction.angle(), rotation_speed * _delta)

	# Ghost spawning
	if state == State.REPOSITION:
		ghost_timer -= _delta
		if ghost_timer <= 0:
			spawn_ghost()
			ghost_timer = ghost_interval

	# Calculate reposition velocity
	var move_velocity = Vector2.ZERO
	match state:
		State.IDLE, State.ATTACK:
			move_velocity = Vector2.ZERO
		State.REPOSITION:
			var dist = global_position.distance_to(target_pos)
			if dist < 10:
				state = State.IDLE
				move_velocity = Vector2.ZERO
			else:
				move_velocity = (target_pos - global_position).normalized() * reposition_speed

	velocity = move_velocity
	move_and_slide()

	clamp_to_screen()

# -----------------------------
# Clamp inside viewport
# -----------------------------
func clamp_to_screen(padding := 50):
	var vp_rect = get_viewport().get_visible_rect()
	global_position.x = clamp(global_position.x, vp_rect.position.x + padding, vp_rect.position.x + vp_rect.size.x - padding)
	global_position.y = clamp(global_position.y, vp_rect.position.y + padding, vp_rect.position.y + vp_rect.size.y - padding)

# -----------------------------
# Reposition target selection
# -----------------------------
func choose_reposition_target():
	if not player:
		return

	var vp_rect = get_viewport().get_visible_rect()
	var padding = 50

	for i in range(10):
		var front_dir = Vector2(1, 0)
		var angle_offset = randf_range(-PI/6, PI/6)
		var dir = front_dir.rotated(angle_offset)
		var dist = randf_range(min_distance, max_distance)
		var p = player.global_position + dir * dist

		# Clamp
		p.x = clamp(p.x, vp_rect.position.x + padding, vp_rect.position.x + vp_rect.size.x - padding)
		p.y = clamp(p.y, vp_rect.position.y + padding, vp_rect.position.y + vp_rect.size.y - padding)

		target_pos = p
		return

# -----------------------------
# Shooting
# -----------------------------
func shoot_burst():
	for i in range(burst_count):
		shoot_one(i)
		await get_tree().create_timer(burst_delay).timeout

func shoot_one(index):
	if not laser_scene or not player:
		return

	if muzzle_flash:
		muzzle_flash.restart()

	var laser = laser_scene.instantiate()
	laser.global_position = bullet_spawn.global_position

	var base_dir = (player.global_position - bullet_spawn.global_position).normalized()
	var angle_offset = 0.0
	if aim_cone_bias and burst_count > 1:
		var mid = (burst_count - 1) / 2.0
		var step = spread_angle / (burst_count - 1)
		angle_offset = deg_to_rad((index - mid) * step)
	else:
		angle_offset = deg_to_rad(randf_range(-spread_angle/2, spread_angle/2))

	var final_dir = base_dir.rotated(angle_offset)
	laser.velocity = final_dir * 1300
	laser.rotation = final_dir.angle()

	get_tree().current_scene.call_deferred("add_child", laser)

# -----------------------------
# Ghost / afterimage
# -----------------------------
func spawn_ghost():
	if not ghost_scene or not sprite:
		return

	var ghost = ghost_scene.instantiate()
	ghost.global_position = global_position
	ghost.rotation = sprite.global_rotation
	ghost.scale = sprite.scale

	if ghost.has_node("Sprite2D"):
		ghost.get_node("Sprite2D").texture = sprite.texture
		ghost.get_node("Sprite2D").frame = sprite.frame if sprite.has_method("frame") else 0

	get_tree().current_scene.add_child(ghost)

# -----------------------------
# Damage / death
# -----------------------------
func take_damage(amount):
	health -= amount
	if health <= 0:
		die()

func die():
	running = false

	# Spawn death animation
	if death_animation_scene:
		var anim = death_animation_scene.instantiate()
		anim.global_position = global_position
		get_tree().get_root().call_deferred("add_child", anim)

	# Emit signal for spawner
	emit_signal("enemy_died")

	queue_free()
