extends CharacterBody2D

# --- Missile Properties ---
@export var lifetime: float = 5.0
@export var drop_time: float = 0.2
@export var drop_speed: float = 850.0
@export var initial_speed: float = 200.0
@export var max_speed: float = 2000.0
@export var acceleration: float = 5000.0
@export var homing_turn_speed: float = 3.0
@export var direction_multiplier: int = 1
@export var explosion_scene: PackedScene
@export var trail_delay: float = 0.0001

# --- Damage ---
@export var damage: int = 50  # <-- Adjustable damage value

# --- Wobble (optional) ---
@export var wobble_strength: float = 0.15
@export var wobble_speed: float = 12.0

enum MissileState { DROPPING, FORWARD }
var state: MissileState = MissileState.DROPPING
var state_timer: float = 0.0

# --- References ---
@onready var exhaust: AnimatedSprite2D = $Exhaust
@onready var trail: GPUParticles2D = $GPUParticles2D
var trail_timer: Timer

# --- Homing target ---
var target: Node2D = null
func set_target(enemy: Node2D) -> void:
    target = enemy

# Forward movement
var speed_forward: float = 0.0

func _ready():
    if exhaust:
        exhaust.visible = false
    if trail:
        trail.emitting = false

    # Trail delay
    trail_timer = Timer.new()
    trail_timer.wait_time = trail_delay
    trail_timer.one_shot = true
    trail_timer.connect("timeout", Callable(self, "_on_trail_timer_timeout"))
    add_child(trail_timer)

    destroy_after_lifetime()

func _on_trail_timer_timeout():
    if trail:
        trail.global_position = global_position
        trail.emitting = true

func destroy_after_lifetime() -> void:
    await get_tree().create_timer(lifetime).timeout
    explode()

func _physics_process(delta):
    state_timer += delta

    match state:

        # -------------------------------------------------
        # DROPPING PHASE
        # -------------------------------------------------
        MissileState.DROPPING:
            position.y += drop_speed * delta * direction_multiplier

            if state_timer >= drop_time:
                state = MissileState.FORWARD
                state_timer = 0.0

                if exhaust:
                    exhaust.visible = true
                    exhaust.play("exhaust")

                trail_timer.start()

        # -------------------------------------------------
        # FORWARD PHASE (ACCELERATION + ARCADE HOMING)
        # -------------------------------------------------
        MissileState.FORWARD:

            # --- Forward acceleration ---
            speed_forward += acceleration * delta
            speed_forward = clamp(speed_forward, 0.0, max_speed)

            # Movement base direction
            var velocity_dir = Vector2(speed_forward, 0).rotated(rotation)

            # --- Arcade homing ---
            if target and target.is_inside_tree():
                var to_target = (target.global_position - global_position).normalized()
                var desired_angle = to_target.angle()
                var max_turn = homing_turn_speed * delta
                rotation += clamp(desired_angle - rotation, -max_turn, max_turn)

            # --- Wobble effect ---
            if wobble_strength > 0.0:
                rotation += sin(Time.get_ticks_msec() * 0.001 * wobble_speed) * wobble_strength * delta

            # Move missile
            var collision = move_and_collide(velocity_dir * delta)
            if collision:
                var hit = collision.get_collider()
                if hit and hit.is_in_group("enemy"):
                    explode()
                    if hit.has_method("take_damage"):
                        hit.take_damage(damage)  # <-- Use variable now

    # Exhaust shader update
    if exhaust and exhaust.visible:
        var shader_material = exhaust.material
        if shader_material:
            shader_material.set("shader_parameter/glow_strength", 2.0)
            shader_material.set("shader_parameter/pulse_amount", 0.3)
            shader_material.set("shader_parameter/time", Time.get_ticks_msec() / 1000.0)

func explode():
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        explosion.global_position = global_position
        get_tree().current_scene.add_child(explosion)
    queue_free()
