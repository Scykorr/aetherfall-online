class_name MmorpgCamera
extends Camera3D

@export var target: Node3D
@export var distance: float = 10.0
@export var height: float = 9.0
@export var smooth_speed: float = 8.0
@export var min_distance: float = 7.0
@export var max_distance: float = 14.0
@export var zoom_step: float = 1.0

func _process(delta: float) -> void:
    if target == null:
        return

    if Input.is_action_just_pressed("camera_zoom_in"):
        distance = max(min_distance, distance - zoom_step)
    if Input.is_action_just_pressed("camera_zoom_out"):
        distance = min(max_distance, distance + zoom_step)

    var desired := target.global_position + Vector3(0.0, height, distance)
    global_position = global_position.lerp(desired, 1.0 - exp(-smooth_speed * delta))
    look_at(target.global_position + Vector3.UP * 1.0, Vector3.UP)
