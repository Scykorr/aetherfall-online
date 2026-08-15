extends RefCounted

const PROTOCOL_VERSION: int = 1
const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")
const SESSION_REGISTRY_SCRIPT: Script = preload("res://scripts/session_registry.gd")
const HANDSHAKE_SERVICE_SCRIPT: Script = preload("res://scripts/network/handshake_service.gd")

func run(suite) -> void:
    _test_matching_protocol(suite)
    _test_mismatched_protocol(suite)
    _test_malformed_payload(suite)
    _test_rejection_preserves_entity_count(suite)
    _test_rejection_does_not_ready_session(suite)

func _create_context() -> Dictionary:
    var entities = ENTITY_REGISTRY_SCRIPT.new()
    var sessions = SESSION_REGISTRY_SCRIPT.new()
    sessions.create_pending_session(2, 100, 200)
    return {
        "entities": entities,
        "sessions": sessions,
        "service": HANDSHAKE_SERVICE_SCRIPT.new(entities, sessions, PROTOCOL_VERSION),
    }

func _test_matching_protocol(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var result: Dictionary = service.process_handshake(2, {"protocol_version": 1}, 101)
    suite.check("PR-001 matching protocol accepted", result["accepted"])
    _free_context(context)

func _test_mismatched_protocol(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var result: Dictionary = service.process_handshake(2, {"protocol_version": 999}, 101)
    suite.check(
        "PR-002 mismatched protocol rejected",
        not result["accepted"] and "protocol mismatch" in result["reason"]
    )
    _free_context(context)

func _test_malformed_payload(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var missing: Dictionary = service.process_handshake(2, {"unexpected": true}, 101)
    var wrong_type: Dictionary = service.process_handshake(2, {"protocol_version": "1"}, 101)
    suite.check(
        "PR-003 malformed payload rejected safely",
        not missing["accepted"] and not wrong_type["accepted"]
    )
    _free_context(context)

func _test_rejection_preserves_entity_count(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var entities = context["entities"]
    service.process_handshake(2, {"protocol_version": 999}, 101)
    suite.check("PR-004 rejected handshake creates no entity", entities.get_entity_count() == 0)
    _free_context(context)

func _test_rejection_does_not_ready_session(suite) -> void:
    var context := _create_context()
    var service = context["service"]
    var sessions = context["sessions"]
    service.process_handshake(2, {"protocol_version": 999}, 101)
    suite.check(
        "PR-005 rejected session is not ready",
        not sessions.get_session(2).get("handshake_complete", false)
    )
    _free_context(context)

func _free_context(context: Dictionary) -> void:
    var entities: Node = context["entities"]
    var sessions: Node = context["sessions"]
    entities.free()
    sessions.free()
