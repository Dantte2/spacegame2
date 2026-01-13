extends CharacterBody2D

# --- Missile Properties ---
@export var lifetime: float = 5.0
@export var initial_speed: float = 1200.0
@export var max_speed: float = 2000.0
@export var acceleration: float = 1000.0
@export var homing_turn_speed: float = 0.5  # radians/sec
@export var damage: int = 5000
@export var explosion_scene: PackedScene

# --- Wobble ---
@export var wobble_strength: float = 0.5
@export var wobble_speed: float = 5.0

# --- References ---
@onready var exhaust: AnimatedSprite2D = $Exhaust

# --- Homing target ---
var target: Node2D = null
func set_target(player: Node2D) -> void:
    target = player

func _ready():
    if exhaust:
        exhaust.visible = true
        exhaust.play("exhaust")

    velocity = Vector2(-initial_speed, 0)  # move left immediately
    destroy_after_lifetime()
    find_target()

func find_target():
    if target == null:
        var players = get_tree().get_nodes_in_group("player")
        if players.size() > 0:
            target = players[0]

func destroy_after_lifetime() -> void:
    await get_tree().create_timer(lifetime).timeout
    explode()

func _physics_process(delta):
    # --- Homing adjustment ---
    if target and target.is_inside_tree():
        var to_target = (target.global_position - global_position).normalized()
        var desired_angle = to_target.angle()
        var angle_diff = wrapf(desired_angle - velocity.angle(), -PI, PI)
        var max_turn = homing_turn_speed * delta
        angle_diff = clamp(angle_diff, -max_turn, max_turn)
        velocity = velocity.rotated(angle_diff)

    # --- Accelerate along current direction ---
    velocity = velocity.normalized() * min(velocity.length() + acceleration * delta, max_speed)

    # --- Wobble ---
    if wobble_strength > 0:
        velocity = velocity.rotated(sin(Time.get_ticks_msec() * 0.001 * wobble_speed) * wobble_strength * delta)

    # --- Move ---
    var collision = move_and_collide(velocity * delta)
    if collision:
        var hit = collision.get_collider()
        _handle_hit(hit)

    # --- Rotate sprite to match velocity ---
    rotation = velocity.angle()

func _handle_hit(target):
    # find player script in parent chain
    var player = target
    while player and not player.has_method("take_damage"):
        player = player.get_parent()
    if not player:
        return

    # Apply damage to shield first, then health
    if player.shield > 0 and player.has_method("apply_shield_damage"):
        player.apply_shield_damage(damage, global_position)
    else:
        player.take_damage(damage)

    explode()


func explode():
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        explosion.global_position = global_position
        get_tree().current_scene.add_child(explosion)
    queue_free()
