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
@export_range(1.0, 100.0, 0.5) var target_selection_range: float = 30.0
@export_range(1, 1000, 1) var basic_attack_damage: int = 10
@export_range(0.1, 20.0, 0.1) var basic_attack_range: float = 2.5
@export_range(0.1, 10.0, 0.1) var basic_attack_cooldown_seconds: float = 1.0
@export_range(1, 10000, 1) var player_max_hp: int = 100
@export_range(0.1, 60.0, 0.1) var player_respawn_delay_seconds: float = 4.0
@export_range(1, 60, 1) var monster_aggro_interval_ticks: int = 5
@export var item_catalog_path: String = "shared/data/items/prototype_items.json"
@export_range(1, 120, 1) var inventory_slot_count: int = 24
@export var monster_loot_table_path: String = "shared/data/loot_tables/training_wisp.json"
@export var loot_random_seed: int = 4242
@export_range(0.1, 10.0, 0.1) var loot_pickup_range: float = 2.5
@export_range(1.0, 600.0, 1.0) var loot_lifetime_seconds: float = 60.0
@export var monster_template_path: String = "shared/data/monsters/training_wisp.json"
@export var monster_spawn_position: Vector3 = Vector3(6.0, 0.1, -2.0)
@export var monster_random_seed: int = 1337
var monster_despawn_after_seconds: float = 0.0
var loot_test_mode: bool = false
var inventory_full_test_mode: bool = false

const PLAYER_COLLISION_RADIUS: float = 0.45
const WORLD_HALF_EXTENT: float = 15.0

var server_instance_id: String = ""

func get_movement_blockers() -> Array[Dictionary]:
    return [
        {
            "shape": "box",
            "center": Vector2(0.0, -4.0),
            "half_extents": Vector2(1.5, 1.0),
        },
        {"shape": "circle", "center": Vector2(5.0, 4.0), "radius": 1.2},
        {
            "shape": "box",
            "center": Vector2(-3.0, 5.0),
            "half_extents": Vector2(0.75, 3.0),
        },
        {
            "shape": "box",
            "center": Vector2(0.0, 5.0),
            "half_extents": Vector2(0.75, 3.0),
        },
    ]

func assign_runtime_instance_id() -> void:
    var unix_time := int(Time.get_unix_time_from_system())
    server_instance_id = "%s-%d-%d" % [
        zone_id,
        unix_time,
        OS.get_process_id(),
    ]
