class_name TrainingWispPresentation
extends Node3D

@onready var visual_root: Node3D = $VisualRoot
@onready var animation_controller: PrototypeAnimationController = (
    $AnimationController
)

func apply_replicated_state(state: Dictionary) -> void:
    animation_controller.apply_replicated_state(state)
