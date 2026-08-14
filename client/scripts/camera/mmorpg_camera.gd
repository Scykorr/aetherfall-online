class_name MmorpgCamera
extends Camera3D

@export var target: Node3D
@export var distance: float = 10.0
@export var height: float = 9.0
@export var look_ahead: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var smooth_speed: float = 8.0
@export var zoom_enabled: bool = true
@export var min_distance: float = 7.0
@export var max_distance: float = 14.0
@export var zoom_step: float = 1.0

func _ready() -> void:
    distance = clampf(distance, min_distance, max_distance)

func _process(delta: float) -> void:
    if target == null:
        return

    if zoom_enabled:
        if Input.is_action_just_pressed("camera_zoom_in"):
            distance = maxf(min_distance, distance - zoom_step)
        if Input.is_action_just_pressed("camera_zoom_out"):
            distance = minf(max_distance, distance + zoom_step)

    var camera_offset := Vector3(0.0, height, distance)
    var desired_position := target.global_position + camera_offset
    var follow_weight := 1.0 - exp(-smooth_speed * delta)
    global_position = global_position.lerp(desired_position, follow_weight)
    look_at(global_position - camera_offset + look_ahead, Vector3.UP)
