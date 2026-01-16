extends Node2D

# --------------------
# Laser Settings
# --------------------
@export var damage_to_shield: int = 2000
@export var damage_to_health: int = 200
@export var width: float = 20           # full thickness of the laser
@export var tick_rate: float = 0.1      # damage every 0.1s
@export var shrink_time: float = 0.2    # time to shrink when disappearing

# Nodes
@onready var line2d: Line2D = $Line2D
@onready var area: Area2D = $Area2D
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D
@onready var spark: AnimatedSprite2D = $Spark  # <-- Spark node

# Internal timing
var warning_time: float = 0.5
var duration: float = 2.0
var players_inside: Array = []

# --------------------
# Ready — setup beam
# --------------------
func _ready():
    _setup_beam()
    
    # Connect collision signals
    area.body_entered.connect(_on_body_entered)
    area.body_exited.connect(_on_body_exited)
    area.area_entered.connect(_on_area_entered)
    area.area_exited.connect(_on_area_exited)

# --------------------
# Beam setup
# --------------------
func _setup_beam():
    var screen_height = get_viewport_rect().size.y
    var beam_length = screen_height + 50

    # Line2D points
    line2d.points = [Vector2.ZERO, Vector2(0, beam_length)]
    line2d.width = width
    line2d.default_color = Color(1, 0, 0, 0.2)  # semi-transparent warning
    line2d.visible = true

    # CollisionShape2D setup
    if collision.shape is RectangleShape2D:
        collision.shape.extents = Vector2(width / 2, beam_length / 2)
        area.position = Vector2(0, beam_length / 2)
        area.monitoring = false  # disable collision during warning

    # Hide spark initially
    if spark:
        spark.visible = false

# --------------------
# Start telegraph → active → shrink → destroy
# --------------------
func start_telegraph(_warning_time: float = 0.5, _duration: float = 2.0) -> void:
    warning_time = _warning_time
    duration = _duration
    _telegraph_task()

# --------------------
# Internal coroutine
# --------------------
func _telegraph_task() -> void:
    # --------------------
    # Warning phase
    # --------------------
    line2d.default_color = Color(0.5, 0.0, 0.5, 0.2)
    area.monitoring = false
    if spark:
        spark.visible = false
    await get_tree().create_timer(warning_time).timeout

    # --------------------
    # Active phase
    # --------------------
    line2d.default_color = Color(2.0, 0.0, 2.5)
    area.monitoring = true

    # Show spark during active phase
    if spark:
        spark.visible = true
        spark.modulate = Color(1.0, 0.655, 0.602, 1.0)
        spark.play("default")

    # Start thin and grow to full width
    var target_width = width
    line2d.width = 2  # start very thin
    var ramp_time = 0.2  # seconds to grow to full thickness

    # Tween for growth
    var grow_tween = create_tween()
    grow_tween.tween_property(line2d, "width", target_width, ramp_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # Tick damage while active
    while duration > 0:
        _deal_tick_damage()
        await get_tree().create_timer(tick_rate).timeout
        duration -= tick_rate

    # --------------------
    # Shrink phase before disappearing
    # --------------------
    area.monitoring = false  # stop damaging
    if spark:
        spark.stop()
        spark.visible = false

    var shrink_tween = create_tween()
    shrink_tween.tween_property(line2d, "width", 2, shrink_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    await shrink_tween.finished

    # --------------------
    # Cleanup
    # --------------------
    queue_free()

# --------------------
# Damage tick
# --------------------
func _deal_tick_damage():
    for obj in players_inside:
        if not is_instance_valid(obj):
            continue
        if "shield" in obj and obj.shield > 0:
            if obj.has_method("apply_shield_damage"):
                obj.apply_shield_damage(damage_to_shield * tick_rate, global_position)
        else:
            if obj.has_method("take_damage"):
                obj.take_damage(damage_to_health * tick_rate)

# --------------------
# Collision handling
# --------------------
func _on_body_entered(body):
    if body not in players_inside:
        players_inside.append(body)

func _on_body_exited(body):
    if body in players_inside:
        players_inside.erase(body)

func _on_area_entered(a):
    if a not in players_inside:
        players_inside.append(a)

func _on_area_exited(a):
    if a in players_inside:
        players_inside.erase(a)
