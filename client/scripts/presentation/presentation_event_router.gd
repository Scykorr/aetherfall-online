class_name PresentationEventRouter
extends Node

@export var presentation_registry: RemotePlayerManager

func _ready() -> void:
    Network.combat_event_received.connect(_on_combat_event_received)

func _on_combat_event_received(event: Dictionary) -> void:
    var attacker_id: int = event.get("attacker_entity_id", 0)
    var target_id: int = event.get("target_entity_id", 0)
    var attacker := presentation_registry.get_animation_controller(attacker_id)
    var target := presentation_registry.get_animation_controller(target_id)
    if attacker != null:
        if target != null:
            attacker.face_world_position(target.visual_root.global_position)
        attacker.trigger_attack()
    if target != null:
        target.trigger_hit()
