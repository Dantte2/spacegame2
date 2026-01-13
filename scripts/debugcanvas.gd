extends CanvasLayer

@export var wave_enemies: Array[PackedScene] = []
@export var spawn_positions: Array[Vector2] = []
@export var vertical_spacing: float = 80.0
@export var start_position: Vector2 = Vector2(400, 300)
@export var player_node: NodePath  # You can remove this too if not used anymore

func _on_spawn_wave_button_pressed() -> void:
    if wave_enemies.size() == 0:
        print("No enemies assigned for this wave!")
        return

    var positions: Array[Vector2] = []

    if spawn_positions.size() == 0:
        for i in range(wave_enemies.size()):
            positions.append(start_position + Vector2(0, i * vertical_spacing))
    else:
        positions = spawn_positions.duplicate()

    for i in range(wave_enemies.size()):
        var enemy_scene = wave_enemies[i]
        if enemy_scene:
            var enemy = enemy_scene.instantiate()
            enemy.global_position = positions[i % positions.size()]
            get_tree().current_scene.add_child(enemy)

    print("Spawned wave of ", wave_enemies.size(), " enemies!")
