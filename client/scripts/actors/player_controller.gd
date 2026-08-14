class_name PlayerController
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
@export var rotation_speed: float = 12.0

func _physics_process(delta: float) -> void:
    var input_2d := Input.get_vector(
        "move_left",
        "move_right",
        "move_forward",
        "move_back"
    )
    var direction := Vector3(input_2d.x, 0.0, input_2d.y)
    if direction.length_squared() > 1.0:
        direction = direction.normalized()

    var target_velocity := direction * move_speed
    var rate := acceleration if direction.length_squared() > 0.0 else deceleration
    velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = 0.0

    if direction.length_squared() > 0.001:
        var target_yaw := atan2(direction.x, direction.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

    move_and_slide()
