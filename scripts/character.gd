extends CharacterBody3D

@export var speed: float = 4.0
@export var hit_flash_duration: float = 0.12

@onready var sprite: ShaderAnimatedSprite3D = $AnimatedSprite3D

var _hit_tween: Tween


func _ready() -> void:
	sprite.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	# Temporary debug trigger for hit flash.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		play_hit_flash()
		get_viewport().set_input_as_handled()


func play_hit_flash() -> void:
	var mat := sprite.material_override as ShaderMaterial
	if mat == null:
		return
	if _hit_tween != null:
		_hit_tween.kill()
	mat.set_shader_parameter("hit_flash", 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_method(_set_hit_flash, 1.0, 0.0, hit_flash_duration)


func _set_hit_flash(value: float) -> void:
	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("hit_flash", value)


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
