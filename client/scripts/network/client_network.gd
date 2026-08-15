extends Node

const SNAPSHOT_STORE_SCRIPT: Script = preload("res://scripts/network/snapshot_store.gd")

signal state_changed(new_state: ConnectionState)
signal snapshot_received(snapshot: Dictionary)

enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    HANDSHAKING,
    READY,
    FAILED,
}

var state: ConnectionState = ConnectionState.DISCONNECTED
var assigned_entity_id: int = 0
var zone_id: String = ""
var server_tick: int = 0
var movement_mode: String = "STOP"
var last_input_sequence: int = 0
var last_ack_sequence: int = 0

var _config := NetworkConfig.new()
var _peer: ENetMultiplayerPeer
var _shutdown_after_seconds: float = 0.0
var _duplicate_handshake: bool = false
var _skip_handshake: bool = false
var _malformed_handshake: bool = false
var _snapshot_store = SNAPSHOT_STORE_SCRIPT.new()
var _last_follow_sent_usec: int = 0
var _last_follow_direction: Vector3 = Vector3.ZERO
var _movement_test_mode: String = ""

func _ready() -> void:
    _read_development_arguments()
    get_tree().create_timer(0.1).timeout.connect(connect_to_zone)
    if _shutdown_after_seconds > 0.0:
        get_tree().create_timer(_shutdown_after_seconds).timeout.connect(_quit_test_client)

func connect_to_zone() -> void:
    if state != ConnectionState.DISCONNECTED and state != ConnectionState.FAILED:
        return
    assigned_entity_id = 0
    zone_id = ""
    server_tick = 0
    _peer = ENetMultiplayerPeer.new()
    var error := _peer.create_client(_config.host, _config.port)
    if error != OK:
        _fail("cannot create ENet client: %s" % error_string(error))
        return
    multiplayer.multiplayer_peer = _peer
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _set_state(ConnectionState.CONNECTING)
    print("[Aetherfall Client] Connecting to %s:%d" % [_config.host, _config.port])

func disconnect_from_zone() -> void:
    _disconnect_transport()
    _set_state(ConnectionState.DISCONNECTED)

func get_state_name() -> String:
    return ConnectionState.keys()[state]

func send_move_to_point(destination: Vector3) -> void:
    if state != ConnectionState.READY:
        return
    last_input_sequence += 1
    movement_mode = "MOVE_TO_POINT"
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
        "destination": destination,
    })

func send_follow_direction(direction: Vector3, force: bool = false) -> void:
    if state != ConnectionState.READY or direction.is_zero_approx():
        return
    var normalized := Vector3(direction.x, 0.0, direction.z).normalized()
    var interval_usec := int(1_000_000.0 / float(_config.movement_send_rate))
    var now := Time.get_ticks_usec()
    var changed := normalized.dot(_last_follow_direction) < 0.995
    if not force and not changed and now - _last_follow_sent_usec < interval_usec:
        return
    last_input_sequence += 1
    movement_mode = "FOLLOW_CURSOR"
    _last_follow_sent_usec = now
    _last_follow_direction = normalized
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
        "direction": normalized,
    })

func send_stop() -> void:
    if state != ConnectionState.READY:
        return
    last_input_sequence += 1
    movement_mode = "STOP"
    movement_intent.rpc_id(1, {
        "command": movement_mode,
        "sequence": last_input_sequence,
    })

@rpc("any_peer", "call_remote", "reliable")
func request_handshake(_payload: Variant) -> void:
    pass

@rpc("authority", "call_remote", "reliable")
func handshake_accepted(payload: Dictionary) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    if state != ConnectionState.HANDSHAKING:
        _fail("unexpected handshake acceptance")
        return
    if not _is_valid_acceptance(payload):
        _fail("malformed handshake acceptance")
        return
    assigned_entity_id = payload["entity_id"]
    zone_id = payload["zone_id"]
    server_tick = payload["server_tick"]
    _set_state(ConnectionState.READY)
    print("[Aetherfall Client] Handshake accepted")
    print("[Aetherfall Client] Entity ID: %d" % assigned_entity_id)
    print("[Aetherfall Client] Zone: %s" % zone_id)
    print("[Aetherfall Client] Network state: READY")
    if _duplicate_handshake:
        request_handshake.rpc_id(1, {"protocol_version": _config.protocol_version})
    if not _movement_test_mode.is_empty():
        get_tree().create_timer(0.5).timeout.connect(_start_movement_test)

@rpc("authority", "call_remote", "reliable")
func handshake_rejected(reason: String) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    _fail("handshake rejected: %s" % reason)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func movement_intent(_payload: Variant) -> void:
    pass

@rpc("authority", "call_remote", "unreliable_ordered")
func movement_snapshot(snapshot: Dictionary) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    if state != ConnectionState.READY or not _snapshot_store.apply_snapshot(snapshot):
        return
    server_tick = _snapshot_store.latest_server_tick
    var local_state: Dictionary = _snapshot_store.get_state(assigned_entity_id)
    if not local_state.is_empty():
        movement_mode = local_state["movement_mode"]
        last_ack_sequence = local_state["last_processed_input_sequence"]
    snapshot_received.emit(snapshot)
    if not _movement_test_mode.is_empty() and server_tick % 15 == 0:
        var remote_positions: Array[String] = []
        for player: Dictionary in snapshot["players"]:
            if player["entity_id"] != assigned_entity_id:
                remote_positions.append("%d:%s" % [player["entity_id"], player["position"]])
        print(
            "[Aetherfall Client] Movement test snapshot: tick=%d local=%s remotes=%s ack=%d" % [
                server_tick,
                local_state.get("position", Vector3.ZERO),
                ",".join(remote_positions),
                last_ack_sequence,
            ]
        )

func _on_connected_to_server() -> void:
    _set_state(ConnectionState.CONNECTED)
    print("[Aetherfall Client] Transport connected")
    if _skip_handshake:
        return
    _set_state(ConnectionState.HANDSHAKING)
    print("[Aetherfall Client] Sending handshake protocol=%d" % _config.protocol_version)
    if _malformed_handshake:
        request_handshake.rpc_id(1, {"unexpected_field": true})
    else:
        request_handshake.rpc_id(1, {"protocol_version": _config.protocol_version})

func _on_connection_failed() -> void:
    _fail("transport connection failed")

func _on_server_disconnected() -> void:
    if state != ConnectionState.FAILED:
        print("[Aetherfall Client] Server disconnected")
        _set_state(ConnectionState.DISCONNECTED)
    _disconnect_transport()

func _is_valid_acceptance(payload: Dictionary) -> bool:
    return (
        payload.get("entity_id", 0) is int
        and payload.get("entity_id", 0) > 0
        and payload.get("zone_id", "") is String
        and payload.get("server_tick", -1) is int
        and payload.get("protocol_version", 0) == NetworkConfig.PROTOCOL_VERSION
    )

func _fail(reason: String) -> void:
    print("[Aetherfall Client] Failed: %s" % reason)
    _set_state(ConnectionState.FAILED)

func _set_state(new_state: ConnectionState) -> void:
    if state == new_state:
        return
    state = new_state
    state_changed.emit(state)

func _disconnect_transport() -> void:
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = null
    _peer = null

func _read_development_arguments() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--network-host="):
            _config.host = argument.trim_prefix("--network-host=")
        elif argument.begins_with("--network-port="):
            _config.port = argument.trim_prefix("--network-port=").to_int()
        elif argument.begins_with("--protocol-version="):
            _config.protocol_version = argument.trim_prefix("--protocol-version=").to_int()
        elif argument.begins_with("--shutdown-after="):
            _shutdown_after_seconds = argument.trim_prefix("--shutdown-after=").to_float()
        elif argument == "--duplicate-handshake":
            _duplicate_handshake = true
        elif argument == "--skip-handshake":
            _skip_handshake = true
        elif argument == "--malformed-handshake":
            _malformed_handshake = true
        elif argument.begins_with("--movement-test="):
            _movement_test_mode = argument.trim_prefix("--movement-test=")

func _quit_test_client() -> void:
    disconnect_from_zone()
    get_tree().quit()

func _start_movement_test() -> void:
    if _movement_test_mode == "move_to_point":
        send_move_to_point(Vector3(4.0, 0.1, 0.0))
    elif _movement_test_mode == "follow_cursor":
        send_follow_direction(Vector3.FORWARD, true)
        get_tree().create_timer(3.0).timeout.connect(send_stop)
