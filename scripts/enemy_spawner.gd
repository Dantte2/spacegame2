extends Node2D

# ==========================
# --- Toggles / Settings ---
# ==========================
@export var spawner_enabled := true

# ==========================
# --- Enemy Slots (6 enemies) ---
# ==========================
@export var enemy_1: PackedScene
@export var enemy_2: PackedScene
@export var enemy_3: PackedScene
@export var enemy_4: PackedScene
@export var enemy_5: PackedScene
@export var enemy_6: PackedScene

# ==========================
# --- Max On Screen Per Enemy ---
# ==========================
@export var enemy_1_max_on_screen := 4
@export var enemy_2_max_on_screen := 2
@export var enemy_3_max_on_screen := 2
@export var enemy_4_max_on_screen := 2
@export var enemy_5_max_on_screen := 2
@export var enemy_6_max_on_screen := 2

# ==========================
# --- Wave Counts / Intervals ---
# ==========================
@export var enemy_1_total := 10
@export var enemy_1_interval := 0.01

@export var enemy_2_total := 2
@export var enemy_2_interval := 0.3

@export var enemy_3_total := 1
@export var enemy_3_interval := 0.5

@export var enemy_4_total := 5
@export var enemy_4_interval := 0.2

# ==========================
# --- Portal Settings ---
# ==========================
@export var portal_animation := "spawn"
@export var spawn_delay := 0.2
@export var portal_despawn := 0.4
@export var fly_out_distance := 80.0
@export var fly_out_direction := Vector2(-1, 0)
@export var fly_out_duration := 0.3

# ==========================
# --- Spawn Points ---
# ==========================
@export var top_spawn_points: Array[Vector2] = []
@export var right_corners: Array[Vector2] = []

# ==========================
# --- Nodes ---
# ==========================
@onready var template_portal: AnimatedSprite2D = $Portal

# ==========================
# --- Internal Arrays / Counters ---
# ==========================
var enemies: Array[PackedScene]
var active_enemies := {}   # Tracks how many of each enemy type are currently on screen
var max_on_screen := {}    # Max-on-screen caps

# ==========================
# --- Ready ---
# ==========================
func _ready() -> void:
	template_portal.visible = false

	enemies = [enemy_1, enemy_2, enemy_3, enemy_4, enemy_5, enemy_6]

	max_on_screen = {
		enemy_1: enemy_1_max_on_screen,
		enemy_2: enemy_2_max_on_screen,
		enemy_3: enemy_3_max_on_screen,
		enemy_4: enemy_4_max_on_screen,
		enemy_5: enemy_5_max_on_screen,
		enemy_6: enemy_6_max_on_screen
	}

	for e in enemies:
		active_enemies[e] = 0

	# Start stage timeline
	run_stage()

# ==========================
# --- Stage Timeline ---
# ==========================
func run_stage() -> void:
	await wait(2.0)

	# Spawn enemy queues
	spawn_enemy_queued(enemy_1, enemy_1_total, top_spawn_points, enemy_1_interval)
	await wait(3.0)

	spawn_enemy_queued(enemy_2, enemy_2_total, right_corners, enemy_2_interval)
	await wait(1.0)

	spawn_enemy_queued(enemy_3, enemy_3_total, top_spawn_points, enemy_3_interval)
	await wait(1.0)

	spawn_enemy_queued(enemy_4, enemy_4_total, top_spawn_points, enemy_4_interval)

# ==========================
# --- Generic Queued Spawner ---
# ==========================
func spawn_enemy_queued(enemy_scene: PackedScene, total_count: int, spawn_points: Array[Vector2], interval: float) -> void:
	# Start the spawn loop asynchronously
	call_deferred("_spawn_enemy_loop", enemy_scene, total_count, spawn_points, interval)

func _spawn_enemy_loop(enemy_scene: PackedScene, total_count: int, spawn_points: Array[Vector2], interval: float) -> void:
	var spawned_count := 0
	while spawned_count < total_count:
		if active_enemies[enemy_scene] < max_on_screen[enemy_scene]:
			var pos = spawn_points[randi() % spawn_points.size()]
			await spawn_enemy_with_portal_at_position(enemy_scene, pos)
			active_enemies[enemy_scene] += 1
			spawned_count += 1
		# Very short wait so loop can check continuously
		await wait(interval)

# ==========================
# --- Spawn Enemy With Portal ---
# ==========================
func spawn_enemy_with_portal_at_position(enemy_scene: PackedScene, pos: Vector2) -> void:
	if not spawner_enabled:
		return

	var container := Node2D.new()
	add_child(container)
	container.global_position = pos

	var portal := template_portal.duplicate() as AnimatedSprite2D
	container.add_child(portal)
	portal.visible = true
	portal.modulate.a = 0.0
	portal.animation = portal_animation
	portal.play()

	# Portal fade-in
	await portal.create_tween() \
		.tween_property(portal, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN) \
		.finished

	await wait(spawn_delay)

	var enemy := enemy_scene.instantiate() as Node2D
	enemy.global_position = pos
	get_tree().current_scene.add_child(enemy)

	# Connect death signal
	if enemy.has_signal("enemy_died"):
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died").bind(enemy_scene))

	# Optional fly-out
	if fly_out_distance > 0:
		var target: Vector2 = enemy.global_position + fly_out_direction.normalized() * fly_out_distance
		await enemy.create_tween() \
			.tween_property(enemy, "global_position", target, fly_out_duration) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT) \
			.finished

	# Portal fade-out
	await portal.create_tween() \
		.tween_property(portal, "modulate:a", 0.0, portal_despawn) \
		.finished

	container.queue_free()

# ==========================
# --- Enemy Death Handler ---
# ==========================
func _on_enemy_died(enemy_scene: PackedScene) -> void:
	if active_enemies.has(enemy_scene):
		active_enemies[enemy_scene] = max(active_enemies[enemy_scene] - 1, 0)

# ==========================
# --- Utility Wait ---
# ==========================
func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
