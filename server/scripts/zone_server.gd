class_name ZoneServer
extends Node

const PROTOCOL_VERSION: int = 1

@export var config: ZoneConfig

@onready var simulation_clock: SimulationClock = $SimulationClock
@onready var entity_registry: EntityRegistry = $EntityRegistry
@onready var session_registry: SessionRegistry = $SessionRegistry

var _health_log_interval_ticks: int = 150
var _shutdown_after_seconds: float = 0.0
var _shutdown_completed: bool = false

func _ready() -> void:
    if config == null:
        push_error("ZoneConfig is required.")
        get_tree().quit(1)
        return

    get_tree().auto_accept_quit = false
    config.assign_runtime_instance_id()
    simulation_clock.configure(config.simulation_tick_rate)
    _health_log_interval_ticks = maxi(
        1,
        int(round(
            config.health_log_interval_seconds
            * float(config.simulation_tick_rate)
        ))
    )
    _read_development_arguments()
    simulation_clock.tick_completed.connect(_on_tick_completed)

    _print_startup_log()
    if _should_run_registry_self_test():
        if not _run_registry_self_test():
            _request_shutdown("entity registry self-test failed", 1)
            return

    if not Network.start_server(
        config,
        simulation_clock,
        entity_registry,
        session_registry
    ):
        _request_shutdown("network startup failed", 1)
        return
    simulation_clock.start()
    print("[Aetherfall Zone] Ready")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
        call_deferred("_request_shutdown", "close request", 0)

func _exit_tree() -> void:
    if _shutdown_completed:
        return
    if is_instance_valid(simulation_clock):
        simulation_clock.stop()
    if is_instance_valid(entity_registry):
        entity_registry.clear()
    Network.stop_server()
    _shutdown_completed = true
    print("[Aetherfall Zone] Stopped (process exit)")

func _on_tick_completed(completed_tick: int) -> void:
    if completed_tick % _health_log_interval_ticks == 0:
        _print_health_log()
    if (
        _shutdown_after_seconds > 0.0
        and simulation_clock.get_uptime() >= _shutdown_after_seconds
    ):
        _request_shutdown("test duration reached", 0)

func _print_startup_log() -> void:
    print("[Aetherfall Zone] Starting...")
    print("Zone: %s" % config.zone_id)
    print("Tick rate: %d Hz" % config.simulation_tick_rate)
    print("Max players: %d" % config.max_players)
    print("Listen port: %d" % config.network_port)
    print("Server instance: %s" % config.server_instance_id)
    print("Protocol version: %d" % PROTOCOL_VERSION)

func _print_health_log() -> void:
    var health_message := (
        "[Aetherfall Zone] Health | Tick: %d | Uptime: %.2f s | "
        + "Entities: %d | Sessions: %d | Tick health: last=%.3f ms avg=%.3f ms "
        + "budget=%.3f ms over_budget=%d"
    )
    print(
        health_message % [
            simulation_clock.tick_number,
            simulation_clock.get_uptime(),
            entity_registry.get_entity_count(),
            session_registry.get_session_count(),
            simulation_clock.last_tick_duration * 1000.0,
            simulation_clock.average_tick_duration * 1000.0,
            simulation_clock.expected_tick_duration * 1000.0,
            simulation_clock.over_budget_tick_count,
        ]
    )

func _read_development_arguments() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--shutdown-after="):
            _shutdown_after_seconds = maxf(
                0.0,
                argument.trim_prefix("--shutdown-after=").to_float()
            )
        elif argument.begins_with("--network-port="):
            config.network_port = clampi(
                argument.trim_prefix("--network-port=").to_int(),
                1,
                65535
            )

func _should_run_registry_self_test() -> bool:
    return "--registry-self-test" in OS.get_cmdline_user_args()

func _run_registry_self_test() -> bool:
    var entity_id := entity_registry.register_entity(
        &"self_test",
        simulation_clock.tick_number,
        {"purpose": "registry_validation"}
    )
    if entity_registry.get_entity_count() != 1:
        push_error("EntityRegistry self-test failed to register entity.")
        return false

    var entity := entity_registry.get_entity(entity_id)
    if entity.get("entity_id", 0) != entity_id:
        push_error("EntityRegistry self-test failed to fetch entity.")
        return false
    if not entity_registry.remove_entity(entity_id):
        push_error("EntityRegistry self-test failed to remove entity.")
        return false
    if entity_registry.get_entity_count() != 0:
        push_error("EntityRegistry self-test did not finish empty.")
        return false

    print("[Aetherfall Zone] EntityRegistry self-test: PASS")
    return true

func _request_shutdown(reason: String, exit_code: int) -> void:
    if _shutdown_completed:
        return
    print("[Aetherfall Zone] Stopping (%s)..." % reason)
    simulation_clock.stop()
    Network.stop_server()
    session_registry.clear()
    entity_registry.clear()
    _shutdown_completed = true
    print("[Aetherfall Zone] Stopped")
    get_tree().quit(exit_code)
