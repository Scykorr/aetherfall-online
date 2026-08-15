extends Node

signal state_changed(new_state: ConnectionState)

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

var _config := NetworkConfig.new()
var _peer: ENetMultiplayerPeer
var _shutdown_after_seconds: float = 0.0
var _duplicate_handshake: bool = false
var _skip_handshake: bool = false
var _malformed_handshake: bool = false

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

@rpc("authority", "call_remote", "reliable")
func handshake_rejected(reason: String) -> void:
    if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
        return
    _fail("handshake rejected: %s" % reason)

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

func _quit_test_client() -> void:
    disconnect_from_zone()
    get_tree().quit()
