extends CharacterBody2D

@export var speed := 750.0
@export var homing_delay := 0.1
@export var turn_speed := 1.0  # radians per second

var target: Node2D = null
var homing_enabled := false
var initial_direction := Vector2.LEFT

func _ready():
    velocity = initial_direction.normalized() * speed
    rotation = velocity.angle()

    if target == null:
        var players = get_tree().get_nodes_in_group("player")
        if players.size() > 0:
            target = players[0]

    _enable_homing_after_delay()
    _destroy_after_lifetime()

func _enable_homing_after_delay() -> void:
    await get_tree().create_timer(homing_delay).timeout
    homing_enabled = true

func _destroy_after_lifetime() -> void:
    await get_tree().create_timer(2.0).timeout
    queue_free()

func _physics_process(delta):
    if homing_enabled and target and target.is_inside_tree():
        var to_target = (target.global_position - global_position).normalized()
        var current_dir = velocity.normalized()

        var angle_diff = current_dir.angle_to(to_target)
        var max_turn = turn_speed * delta
        angle_diff = clamp(angle_diff, -max_turn, max_turn)

        velocity = current_dir.rotated(angle_diff) * speed

    var collision = move_and_collide(velocity * delta)
    if collision:
        _handle_hit(collision.get_collider())

    rotation = velocity.angle()

func _handle_hit(target_node):
    var player = target_node
    while player and not player.has_method("take_damage"):
        player = player.get_parent()
    if not player:
        return

    if player.shield > 0:
        player.apply_shield_damage(1, global_position)
    else:
        player.take_damage(1)

    queue_free()
