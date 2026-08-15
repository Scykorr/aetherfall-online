class_name TargetableEntity
extends Area3D

var _entity_id: int = 0

func set_target_entity_id(entity_id: int) -> void:
    _entity_id = entity_id

func get_target_entity_id() -> int:
    return _entity_id
