extends CharacterBody2D

# ====================
# EXPORTS
# ====================
@export var missile_scene: PackedScene
@export var laser_scene: PackedScene

@export var fire_rate: float = 5.0

@export var missile_count: int = 6
@export var missile_delay: float = 0.2

@export var laser_waves: int = 2
@export var lasers_per_wave: int = 3
@export var laser_warning_time: float = 0.5
@export var laser_duration: float = 2.0
@export var laser_wave_delay: float = 0.3

@export var laser_x_min: float = 100
@export var laser_x_max: float = 1200

# ====================
# NODES
# ====================
@onready var missile_spawns: Array[Node2D] = [
    $missile/missilespawn1,
    $missile/missilespawn2,
    $missile/missilespawn3
]

@onready var muzzle_flash: AnimatedSprite2D = $missile/missilemuzzle
@onready var exhaust: AnimatedSprite2D = $exhaust

# ====================
# INTERNAL
# ====================
var fire_timer := 0.0
var attacking := false

# ====================
# READY
# ====================
func _ready() -> void:
    randomize()
    fire_timer = fire_rate

    if muzzle_flash:
        muzzle_flash.visible = false

    if exhaust:
        exhaust.visible = true
        exhaust.play("default")

# ====================
# PROCESS
# ====================
func _process(delta: float) -> void:
    if attacking:
        return

    fire_timer -= delta
    if fire_timer <= 0.0:
        var player := get_player()
        if player:
            start_attack(player)
        fire_timer = fire_rate

# ====================
# PLAYER
# ====================
func get_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    return players[0] if players.size() > 0 else null

# ====================
# ATTACK SEQUENCE
# ====================
func start_attack(target: Node2D) -> void:
    if attacking:
        return

    attacking = true
    await fire_missiles(target)
    await fire_lasers()
    attacking = false

# ====================
# MISSILES
# ====================
func fire_missiles(target: Node2D) -> void:
    for i in range(missile_count):
        var spawn := missile_spawns[i % missile_spawns.size()]

        # --- Spawn missile ---
        var missile = missile_scene.instantiate()
        missile.global_position = spawn.global_position
        missile.global_rotation = -PI / 2

        if missile.has_method("set_target"):
            missile.set_target(target)

        get_tree().current_scene.add_child(missile)

        # --- Spawn a muzzle flash for this missile ---
        if muzzle_flash:
            var flash_instance = muzzle_flash.duplicate()  # duplicate the AnimatedSprite2D
            flash_instance.global_position = spawn.global_position
            flash_instance.visible = true
            get_tree().current_scene.add_child(flash_instance)
            flash_instance.play()

            # Correct Godot 4 connection to remove after animation
            flash_instance.animation_finished.connect(Callable(flash_instance, "queue_free"))

        await get_tree().create_timer(missile_delay).timeout

# ====================
# LASERS
# ====================
func fire_lasers() -> void:
    for wave in range(laser_waves):
        # Get the first player in the group
        var players := get_tree().get_nodes_in_group("player")
        var player_x := 0.0
        if players.size() > 0:
            player_x = players[0].global_position.x

        # Pick one laser to track the player
        var tracking_index := randi() % lasers_per_wave

        for i in range(lasers_per_wave):
            var laser = laser_scene.instantiate()

            # If this is the tracking laser, use player's X
            if i == tracking_index:
                laser.position.x = player_x
            else:
                laser.position.x = randf_range(laser_x_min, laser_x_max)

            laser.position.y = 0
            get_tree().current_scene.add_child(laser)

            if laser.has_method("start_telegraph"):
                laser.start_telegraph(laser_warning_time, laser_duration)

        # Wait for this wave to finish
        await get_tree().create_timer(laser_warning_time + laser_duration).timeout

        # Small pause between waves
        if wave < laser_waves - 1:
            await get_tree().create_timer(laser_wave_delay).timeout
