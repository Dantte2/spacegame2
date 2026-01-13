extends CharacterBody2D

# ==========================
# --- Signals ---
# ==========================
signal enemy_died

# ==========================
# --- State ---
# ==========================
enum State { ATTACK, REPOSITION }
var state := State.ATTACK

# ==========================
# --- Health ---
# ==========================
@export var max_health := 250
var health := 0
@export var death_animation_scene: PackedScene

# ==========================
# --- Player ---
# ==========================
var player: CharacterBody2D

# ==========================
# --- Rotation ---
# ==========================
@export var rotation_speed := 6.0

# ==========================
# --- Shooting ---
# ==========================
@export var normal_bullet_scene: PackedScene
@export var homing_bullet_scene: PackedScene

# Normal bullets
@export var fire_rate := 0.6
@export var burst_count := 5
@export var burst_delay := 0.1
@export var bullet_spread := 6.0
@export var normal_bullet_speed := 1300.0

# Homing bullets
@export var homing_bullet_count := 2
@export var homing_bullet_speed := 1200.0
@export var homing_barrel_angles := [20, -20]
@export var homing_cooldown := 2.5

# ==========================
# --- Reposition ---
# ==========================
@export var reposition_speed := 1200.0
@export var min_distance := 900.0
@export var max_distance := 1200.0
@export var reposition_delay := 0.8

var target_pos := Vector2.ZERO

# ==========================
# --- Timers ---
# ==========================
var fire_timer := 0.0
var burst_timer := 0.0
var burst_remaining := 0
var homing_timer := 0.0
var reposition_timer := 0.0

# ==========================
# --- Ready ---
# ==========================
func _ready():
    health = max_health
    fire_timer = 1.0 / fire_rate
    homing_timer = homing_cooldown
    reposition_timer = reposition_delay

    var players = get_tree().get_nodes_in_group("player_body")
    if players.size() > 0:
        player = players[0]

# ==========================
# --- Physics ---
# ==========================
func _physics_process(delta):
    if not player:
        return

    rotate_toward_player(delta)

    match state:
        State.ATTACK:
            handle_attack(delta)
        State.REPOSITION:
            handle_reposition(delta)

    move_and_slide()

# ==========================
# --- Rotation ---
# ==========================
func rotate_toward_player(delta):
    var dir = (player.global_position - global_position).normalized()
    rotation = lerp_angle(rotation, dir.angle(), rotation_speed * delta)

# ==========================
# --- Attack State ---
# ==========================
func handle_attack(delta):
    velocity = Vector2.ZERO

    fire_timer -= delta
    if fire_timer <= 0.0:
        burst_remaining = burst_count
        burst_timer = 0.0
        fire_timer = 1.0 / fire_rate

    if burst_remaining > 0:
        burst_timer -= delta
        if burst_timer <= 0.0:
            shoot_normal_bullet()
            burst_remaining -= 1
            burst_timer = burst_delay

    homing_timer -= delta
    if homing_timer <= 0.0:
        shoot_homing_bullets()
        homing_timer = homing_cooldown

    if burst_remaining == 0:
        reposition_timer -= delta
        if reposition_timer <= 0.0:
            start_reposition()

# ==========================
# --- Reposition State ---
# ==========================
func handle_reposition(_delta):
    var to_target = target_pos - global_position
    var dist = to_target.length()

    if dist < 15:
        state = State.ATTACK
        reposition_timer = reposition_delay
        velocity = Vector2.ZERO
        return

    var speed_factor = clamp(dist / 300.0, 0.25, 1.0)
    velocity = to_target.normalized() * reposition_speed * speed_factor

# ==========================
# --- Reposition Target ---
# ==========================
func start_reposition():
    state = State.REPOSITION
    choose_reposition_target()

func choose_reposition_target():
    var vp_rect = get_viewport().get_visible_rect()
    var padding := 60

    # Predict player slightly
    var predicted_player_pos = player.global_position
    if player is CharacterBody2D:
        predicted_player_pos += player.velocity * 0.4

    # --- X: always in front of player ---
    var forward_dir = sign(player.scale.x)
    if forward_dir == 0:
        forward_dir = 1

    var x_dist = randf_range(min_distance, max_distance)
    var target_x = predicted_player_pos.x + forward_dir * x_dist

    # --- Y: free vertical movement ---
    var y_offset = randf_range(-250.0, 250.0)
    var target_y = predicted_player_pos.y + y_offset

    # Clamp to screen
    target_x = clamp(
        target_x,
        vp_rect.position.x + padding,
        vp_rect.position.x + vp_rect.size.x - padding
    )

    target_y = clamp(
        target_y,
        vp_rect.position.y + padding,
        vp_rect.position.y + vp_rect.size.y - padding
    )

    target_pos = Vector2(target_x, target_y)


# ==========================
# --- Normal Bullet ---
# ==========================
func shoot_normal_bullet():
    if not normal_bullet_scene or not has_node("BulletSpawn1"):
        return

    var spawn = $BulletSpawn1
    var spread = deg_to_rad(bullet_spread)
    var angle_offset = randf_range(-spread / 2, spread / 2)

    var bullet = normal_bullet_scene.instantiate()
    bullet.global_position = spawn.global_position
    bullet.velocity = Vector2.RIGHT.rotated(rotation + angle_offset) * normal_bullet_speed
    bullet.rotation = bullet.velocity.angle()

    get_tree().current_scene.add_child(bullet)

# ==========================
# --- Homing Bullets ---
# ==========================
func shoot_homing_bullets():
    var spawns = [$BulletSpawn2, $BulletSpawn3]

    for i in range(homing_bullet_count):
        if i >= spawns.size():
            continue

        var spawn = spawns[i]
        if not spawn or not homing_bullet_scene:
            continue

        var hb = homing_bullet_scene.instantiate()
        hb.global_position = spawn.global_position
        hb.initial_direction = Vector2.RIGHT.rotated(
            rotation + deg_to_rad(homing_barrel_angles[i])
        )
        hb.speed = homing_bullet_speed

        get_tree().current_scene.add_child(hb)

# ==========================
# --- Damage ---
# ==========================
func take_damage(amount: int):
    health -= amount
    if health <= 0:
        die()

func die():
    emit_signal("enemy_died")

    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)

    queue_free()
