class_name PlayerController
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
@export var rotation_speed: float = 12.0
@export var movement_controller: MouseMovementController

var gravity: float = float(
    ProjectSettings.get_setting("physics/3d/default_gravity")
)

func _physics_process(delta: float) -> void:
    var direction := Vector3.ZERO
    if movement_controller != null:
        direction = movement_controller.get_movement_direction()
    if direction.length_squared() > 1.0:
        direction = direction.normalized()

    var horizontal_velocity := Vector2(velocity.x, velocity.z)
    var target_velocity := Vector2(direction.x, direction.z) * move_speed
    var rate := acceleration if direction.length_squared() > 0.0 else deceleration
    horizontal_velocity = horizontal_velocity.move_toward(
        target_velocity,
        rate * delta
    )
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.y

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    if direction.length_squared() > 0.001:
        var target_yaw := atan2(direction.x, direction.z)
        rotation.y = rotate_toward(
            rotation.y,
            target_yaw,
            rotation_speed * delta
        )

    move_and_slide()
