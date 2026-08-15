class_name ZoneConfig
extends Resource

@export var zone_id: StringName = &"test_zone_001"
@export_range(1, 120, 1) var simulation_tick_rate: int = 30
@export_range(1, 1000, 1) var max_players: int = 50
@export_range(1.0, 60.0, 0.5) var health_log_interval_seconds: float = 5.0
@export var network_bind_address: String = "127.0.0.1"
@export_range(1, 65535, 1) var network_port: int = 7777
@export_range(1.0, 30.0, 0.5) var handshake_timeout_seconds: float = 5.0
@export_range(0.1, 20.0, 0.1) var player_move_speed: float = 5.0
@export_range(1, 30, 1) var snapshot_rate: int = 10
@export var monster_template_path: String = "shared/data/monsters/training_wisp.json"
@export var monster_spawn_position: Vector3 = Vector3(6.0, 0.1, -2.0)
@export var monster_random_seed: int = 1337
var monster_despawn_after_seconds: float = 0.0

var server_instance_id: String = ""

func assign_runtime_instance_id() -> void:
    var unix_time := int(Time.get_unix_time_from_system())
    server_instance_id = "%s-%d-%d" % [
        zone_id,
        unix_time,
        OS.get_process_id(),
    ]
