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
@export_range(0.001, 0.02, 0.001) var orbit_sensitivity: float = 0.005
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -35.0
@export_range(0.0, 80.0, 1.0) var max_pitch_degrees: float = 35.0

var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0

func _ready() -> void:
    distance = clampf(distance, min_distance, max_distance)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_action_pressed("camera_orbit"):
        orbit_yaw = wrapf(
            orbit_yaw - event.relative.x * orbit_sensitivity,
            -PI,
            PI
        )
        orbit_pitch = clampf(
            orbit_pitch - event.relative.y * orbit_sensitivity,
            deg_to_rad(min_pitch_degrees),
            deg_to_rad(max_pitch_degrees)
        )
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if target == null:
        return

    if zoom_enabled:
        if Input.is_action_just_pressed("camera_zoom_in"):
            distance = maxf(min_distance, distance - zoom_step)
        if Input.is_action_just_pressed("camera_zoom_out"):
            distance = minf(max_distance, distance + zoom_step)

    var camera_offset := Vector3(0.0, height, distance)
    camera_offset = camera_offset.rotated(Vector3.RIGHT, orbit_pitch)
    camera_offset = camera_offset.rotated(Vector3.UP, orbit_yaw)
    var desired_position := target.global_position + camera_offset
    var follow_weight := 1.0 - exp(-smooth_speed * delta)
    global_position = global_position.lerp(desired_position, follow_weight)
    look_at(global_position - camera_offset + look_ahead, Vector3.UP)
