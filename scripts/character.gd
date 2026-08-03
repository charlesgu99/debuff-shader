extends CharacterBody3D

@export var speed: float = 4.0

@onready var sprite: ShaderAnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	var direction := Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if sprite.animation != "jump":
			sprite.play("jump")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		if sprite.animation != "idle":
			sprite.play("idle")

	move_and_slide()
