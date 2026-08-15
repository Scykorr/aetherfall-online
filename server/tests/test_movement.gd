extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")
const MOVEMENT_SYSTEM_SCRIPT: Script = preload("res://scripts/movement/movement_system.gd")

func run(suite) -> void:
    _valid_intent(suite)
    _non_ready_rejected(suite)
    _position_not_authoritative(suite)
    _configured_speed(suite)
    _deterministic_ticks(suite)
    _stop(suite)
    _old_sequence(suite)
    _new_sequence(suite)
    _malformed_direction(suite)
    _nan_rejected(suite)
    _inf_rejected(suite)
    _extreme_destination(suite)
    _disconnect_cleanup(suite)
    _spoofed_ownership(suite)
    _session_ownership(suite)
    _unknown_peer(suite)

func _context(two_players: bool = false) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    var handshake = HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, 1)
    sessions.create_pending_session(2, 0, 100)
    handshake.process_handshake(2, {"protocol_version": 1}, 1)
    if two_players:
        sessions.create_pending_session(3, 0, 100)
        handshake.process_handshake(3, {"protocol_version": 1}, 1)
    var movement = MOVEMENT_SYSTEM_SCRIPT.new(sessions, entities, 5.0)
    movement.register_ready_player(2, Vector3.ZERO)
    if two_players:
        movement.register_ready_player(3, Vector3(2.0, 0.0, 0.0))
    return {"entities": entities, "sessions": sessions, "movement": movement}

func _free(context: Dictionary) -> void:
    (context["entities"] as Node).free()
    (context["sessions"] as Node).free()

func _valid_intent(suite) -> void:
    var c := _context()
    suite.check("MOV-001 valid intent accepted", c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT}, 1))
    _free(c)

func _non_ready_rejected(suite) -> void:
    var c := _context()
    suite.check("MOV-002 non-READY rejected", not c.movement.process_intent(99, {"command": "STOP", "sequence": 1}, 1))
    _free(c)

func _position_not_authoritative(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT, "position": Vector3(999.0, 0.0, 0.0)}, 1)
    c.movement.simulate_tick(1.0 / 30.0)
    suite.check("MOV-003 client position ignored", c.movement.get_state(1).position.x < 1.0)
    _free(c)

func _configured_speed(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT}, 1)
    c.movement.simulate_tick(0.1)
    suite.check("MOV-004 server applies move speed", is_equal_approx(c.movement.get_state(1).position.x, 0.5))
    _free(c)

func _deterministic_ticks(suite) -> void:
    var a := _context()
    var b := _context()
    for c in [a, b]:
        c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.FORWARD}, 1)
        for tick in 30:
            c.movement.simulate_tick(1.0 / 30.0)
    suite.check("MOV-005 fixed ticks deterministic", a.movement.get_state(1).position.is_equal_approx(b.movement.get_state(1).position))
    _free(a); _free(b)

func _stop(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT}, 1)
    c.movement.simulate_tick(0.1)
    var stopped_at: Vector3 = c.movement.get_state(1).position
    c.movement.process_intent(2, {"command": "STOP", "sequence": 2}, 2)
    c.movement.simulate_tick(0.1)
    suite.check("MOV-006 STOP stops movement", c.movement.get_state(1).position == stopped_at and c.movement.get_state(1).velocity == Vector3.ZERO)
    _free(c)

func _old_sequence(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "STOP", "sequence": 2}, 1)
    suite.check("MOV-007 old sequence ignored", not c.movement.process_intent(2, {"command": "STOP", "sequence": 1}, 2))
    _free(c)

func _new_sequence(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "STOP", "sequence": 1}, 1)
    suite.check("MOV-008 new sequence accepted", c.movement.process_intent(2, {"command": "STOP", "sequence": 2}, 2))
    _free(c)

func _malformed_direction(suite) -> void:
    var c := _context()
    suite.check("MOV-009 malformed direction rejected", not c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": "right"}, 1))
    _free(c)

func _nan_rejected(suite) -> void:
    var c := _context()
    suite.check("MOV-010 NaN rejected", not c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3(NAN, 0.0, 0.0)}, 1))
    _free(c)

func _inf_rejected(suite) -> void:
    var c := _context()
    suite.check("MOV-011 INF rejected", not c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3(INF, 0.0, 0.0)}, 1))
    _free(c)

func _extreme_destination(suite) -> void:
    var c := _context()
    c.movement.process_intent(2, {"command": "MOVE_TO_POINT", "sequence": 1, "destination": Vector3(1.0e20, 0.0, 0.0)}, 1)
    c.movement.simulate_tick(1.0 / 30.0)
    suite.check("MOV-012 extreme destination cannot teleport", c.movement.get_state(1).position.length() <= 5.0 / 30.0 + 0.001)
    _free(c)

func _disconnect_cleanup(suite) -> void:
    var c := _context()
    suite.check("MOV-013 disconnect removes movement state", c.movement.remove_player(1) and c.movement.get_state(1).is_empty())
    _free(c)

func _spoofed_ownership(suite) -> void:
    var c := _context(true)
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT, "entity_id": 2}, 1)
    c.movement.simulate_tick(0.1)
    suite.check("OWN-001 A cannot move B", c.movement.get_state(2).position == Vector3(2.0, 0.0, 0.0))
    _free(c)

func _session_ownership(suite) -> void:
    var c := _context(true)
    c.movement.process_intent(2, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT}, 1)
    c.movement.simulate_tick(0.1)
    suite.check("OWN-002 controlled entity comes from session", c.movement.get_state(1).position.x > 0.0 and c.movement.get_state(2).position.x == 2.0)
    _free(c)

func _unknown_peer(suite) -> void:
    var c := _context()
    suite.check("OWN-003 unknown peer cannot move", not c.movement.process_intent(404, {"command": "FOLLOW_CURSOR", "sequence": 1, "direction": Vector3.RIGHT}, 1))
    _free(c)
