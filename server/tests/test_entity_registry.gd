extends RefCounted

const ENTITY_REGISTRY_SCRIPT: Script = preload("res://scripts/entity_registry.gd")

func run(suite) -> void:
    _test_create(suite)
    _test_get(suite)
    _test_remove(suite)
    _test_unique_ids(suite)
    _test_invalid_operations(suite)
    _test_idempotent_cleanup(suite)

func _test_create(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    var entity_id: int = registry.register_entity(&"player", 10)
    suite.check("ER-001 create entity", entity_id > 0 and registry.get_entity_count() == 1)
    registry.free()

func _test_get(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    var entity_id: int = registry.register_entity(&"player", 11)
    var entity: Dictionary = registry.get_entity(entity_id)
    suite.check(
        "ER-002 get entity",
        entity.get("entity_id", 0) == entity_id and entity.get("entity_type") == &"player"
    )
    registry.free()

func _test_remove(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    var entity_id: int = registry.register_entity(&"player", 12)
    var removed: bool = registry.remove_entity(entity_id)
    suite.check("ER-003 remove entity", removed and registry.get_entity_count() == 0)
    registry.free()

func _test_unique_ids(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    var first_id: int = registry.register_entity(&"player", 13)
    var second_id: int = registry.register_entity(&"player", 13)
    suite.check("ER-004 unique IDs", first_id != second_id)
    registry.free()

func _test_invalid_operations(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    suite.check(
        "ER-005 invalid get/remove",
        registry.get_entity(999).is_empty() and not registry.remove_entity(999)
    )
    registry.free()

func _test_idempotent_cleanup(suite) -> void:
    var registry = ENTITY_REGISTRY_SCRIPT.new()
    var entity_id: int = registry.register_entity(&"player", 14)
    registry.remove_entity(entity_id)
    var removed_again: bool = registry.remove_entity(entity_id)
    suite.check(
        "ER-006 cleanup idempotency",
        not removed_again and registry.get_entity_count() == 0
    )
    registry.free()
