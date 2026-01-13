extends CharacterBody2D

# --------------------
# Health
# --------------------
@export var max_health: int = 550
var health: int

# --------------------
# Movement (Y follow)
# --------------------
@export var vertical_speed: float = 200.0
@export var y_tolerance: float = 5.0

# --------------------
# Shooting
# --------------------
@export var missile_scene: PackedScene
@export var fire_rate_missile: float = 0.5  # missile cooldown

@export var bullet_scene: PackedScene
@export var fire_rate_bullet: float = 1.5  # cone cooldown
@export var cone_shots: int = 8
@export var cone_angle: float = 15.0
@export var bullet_speed: float = 600.0

@onready var bullet_spawn: Node2D = $BulletSpawn

# Missile raycasts
@onready var raycasts: Array = [
    $raycast1,
    $raycast2,
    $raycast3
]

var fire_timer_missile: float = 0.0
var fire_timer_bullet: float = 0.0

# --------------------
# Death
# --------------------
@export var death_animation_scene: PackedScene
signal enemy_died
var alive: bool = true

# --------------------
# Ready
# --------------------
func _ready():
    health = max_health
    for r in raycasts:
        r.enabled = true
    if has_node("Exhaust"):
        $Exhaust.play()

# --------------------
# Process
# --------------------
func _process(delta):
    if not alive:
        return

    follow_player_y(delta)
    handle_firing(delta)

# --------------------
# Player Tracking
# --------------------
func get_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        return players[0]
    return null

func follow_player_y(_delta):
    var player = get_player()
    if player == null:
        velocity.y = 0
        move_and_slide()
        return

    var y_diff = player.global_position.y - global_position.y
    if abs(y_diff) > y_tolerance:
        velocity.y = sign(y_diff) * vertical_speed
    else:
        velocity.y = 0

    move_and_slide()

# --------------------
# Firing Logic
# --------------------
func handle_firing(delta):
    var player = get_player()
    if player == null:
        return

    # --- Missile firing ---
    fire_timer_missile -= delta
    if missile_scene and fire_timer_missile <= 0.0:
        for r in raycasts:
            if r.is_colliding():
                var collider = r.get_collider()
                if collider and collider.is_in_group("player"):
                    fire_missile(collider, r)
                    fire_timer_missile = fire_rate_missile
                    break  # fire only one missile per cooldown

    # --- Cone bullets ---
    fire_timer_bullet -= delta
    if bullet_scene and fire_timer_bullet <= 0.0:
        fire_cone(player)
        fire_timer_bullet = fire_rate_bullet

# --------------------
# Missile
# --------------------
func fire_missile(target: Node2D, spawn_node: Node2D):
    if missile_scene == null or target == null or spawn_node == null:
        return

    var missile = missile_scene.instantiate()
    missile.global_position = spawn_node.global_position
    missile.global_rotation = spawn_node.global_rotation

    if missile.has_method("set_target"):
        missile.set_target(target)

    get_tree().current_scene.add_child(missile)

# --------------------
# Cone bullets
# --------------------
func fire_cone(target: Node2D):
    if bullet_scene == null or target == null:
        return

    var to_target = (target.global_position - bullet_spawn.global_position).normalized()
    var base_angle = to_target.angle()
    var half_angle_rad = deg_to_rad(cone_angle / 2)

    for i in range(cone_shots):
        var t = 0.0
        if cone_shots > 1:
            t = i / float(cone_shots - 1)
        var angle_offset = lerp(-half_angle_rad, half_angle_rad, t)

        var bullet = bullet_scene.instantiate()
        bullet.global_position = bullet_spawn.global_position
        bullet.global_rotation = base_angle + angle_offset

        # Assign velocity safely
        if bullet.has_method("set_velocity"):
            bullet.set_velocity(Vector2(-bullet_speed, 0).rotated(base_angle + angle_offset))
        elif "velocity" in bullet:
            bullet.velocity = Vector2(-bullet_speed, 0).rotated(base_angle + angle_offset)

        get_tree().current_scene.add_child(bullet)

# --------------------
# Damage & Death
# --------------------
func take_damage(amount: int):
    if not alive:
        return

    health -= amount
    if health <= 0:
        die()

func die():
    if not alive:
        return

    alive = false
    emit_signal("enemy_died")

    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)

    queue_free()
