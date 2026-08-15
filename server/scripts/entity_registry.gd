class_name EntityRegistry
extends Node

var _next_entity_id: int = 1
var _entities: Dictionary = {}

func register_entity(
    entity_type: StringName,
    created_tick: int,
    metadata: Dictionary = {}
) -> int:
    var entity_id := _next_entity_id
    _next_entity_id += 1

    var stored_metadata := metadata.duplicate(true)
    stored_metadata["entity_id"] = entity_id
    stored_metadata["entity_type"] = entity_type
    stored_metadata["created_tick"] = created_tick
    _entities[entity_id] = stored_metadata
    return entity_id

func get_entity(entity_id: int) -> Dictionary:
    if not _entities.has(entity_id):
        return {}
    var stored_metadata: Dictionary = _entities[entity_id]
    return stored_metadata.duplicate(true)

func remove_entity(entity_id: int) -> bool:
    return _entities.erase(entity_id)

func get_entity_count() -> int:
    return _entities.size()

func clear() -> void:
    _entities.clear()
    _next_entity_id = 1
