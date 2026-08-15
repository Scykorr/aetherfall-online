class_name ZoneConfig
extends Resource

@export var zone_id: StringName = &"test_zone_001"
@export_range(1, 120, 1) var simulation_tick_rate: int = 30
@export_range(1, 1000, 1) var max_players: int = 50
@export_range(1.0, 60.0, 0.5) var health_log_interval_seconds: float = 5.0
@export var network_bind_address: String = "127.0.0.1"
@export_range(1, 65535, 1) var network_port: int = 7777
@export_range(1.0, 30.0, 0.5) var handshake_timeout_seconds: float = 5.0

var server_instance_id: String = ""

func assign_runtime_instance_id() -> void:
    var unix_time := int(Time.get_unix_time_from_system())
    server_instance_id = "%s-%d-%d" % [
        zone_id,
        unix_time,
        OS.get_process_id(),
    ]
