extends RefCounted

const PROTOCOL_VERSION: int = 1
const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")

func run(suite) -> void:
    _test_create_session(suite)
    _test_peer_mapping(suite)
    _test_complete_handshake(suite)
    _test_one_player_entity(suite)
    _test_disconnect_session_cleanup(suite)
    _test_disconnect_entity_cleanup(suite)
    _test_duplicate_has_no_second_entity(suite)
    _test_duplicate_keeps_count(suite)
    _test_timeout_session_cleanup(suite)
    _test_timeout_entity_cleanup(suite)

func _create_context(peer_id: int = 2) -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    sessions.create_pending_session(peer_id, 10, 20)
    return {
        "entities": entities,
        "sessions": sessions,
        "service": HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, PROTOCOL_VERSION),
    }

func _accept(context: Dictionary, peer_id: int = 2) -> Dictionary:
    var service = context["service"]
    return service.process_handshake(peer_id, {"protocol_version": PROTOCOL_VERSION}, 11)

func _test_create_session(suite) -> void:
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    suite.check("SR-001 create session", sessions.create_pending_session(2, 10, 20))
    sessions.free()

func _test_peer_mapping(suite) -> void:
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    sessions.create_pending_session(7, 10, 20)
    suite.check("SR-002 peer maps to session", sessions.get_session(7).get("peer_id") == 7)
    sessions.free()

func _test_complete_handshake(suite) -> void:
    var context := _create_context()
    var result := _accept(context)
    var sessions = context["sessions"]
    suite.check(
        "SR-003 handshake completes session",
        result["accepted"] and sessions.get_session(2).get("handshake_complete", false)
    )
    _free_context(context)

func _test_one_player_entity(suite) -> void:
    var context := _create_context()
    _accept(context)
    var entities = context["entities"]
    suite.check("SR-004 handshake creates one player entity", entities.get_entity_count() == 1)
    _free_context(context)

func _test_disconnect_session_cleanup(suite) -> void:
    var context := _create_context()
    _accept(context)
    var service = context["service"]
    var sessions = context["sessions"]
    service.cleanup_peer(2)
    suite.check("SR-005 disconnect removes session", sessions.get_session(2).is_empty())
    _free_context(context)

func _test_disconnect_entity_cleanup(suite) -> void:
    var context := _create_context()
    _accept(context)
    var service = context["service"]
    var entities = context["entities"]
    service.cleanup_peer(2)
    service.cleanup_peer(2)
    suite.check("SR-006 disconnect removes entity idempotently", entities.get_entity_count() == 0)
    _free_context(context)

func _test_duplicate_has_no_second_entity(suite) -> void:
    var context := _create_context()
    _accept(context)
    var duplicate := _accept(context)
    var entities = context["entities"]
    suite.check(
        "SR-007 duplicate creates no second entity",
        not duplicate["accepted"] and entities.get_entity_count() == 1
    )
    _free_context(context)

func _test_duplicate_keeps_count(suite) -> void:
    var context := _create_context()
    _accept(context)
    var entities = context["entities"]
    var count_before: int = entities.get_entity_count()
    _accept(context)
    suite.check("SR-008 duplicate keeps entity count", entities.get_entity_count() == count_before)
    _free_context(context)

func _test_timeout_session_cleanup(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var sessions = context["sessions"]
    var expired: Array[int] = service.cleanup_expired_sessions(20)
    suite.check(
        "SR-009 timeout removes pending session",
        expired == [2] and sessions.get_session(2).is_empty()
    )
    _free_context(context)

func _test_timeout_entity_cleanup(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var entities = context["entities"]
    service.cleanup_expired_sessions(20)
    suite.check("SR-010 timeout leaves no entity", entities.get_entity_count() == 0)
    _free_context(context)

func _free_context(context: Dictionary) -> void:
    var entities: Node = context["entities"]
    var sessions: Node = context["sessions"]
    entities.free()
    sessions.free()
