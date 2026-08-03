@tool
class_name ShaderAnimatedSprite3D
extends AnimatedSprite3D
## Syncs material_override uniforms for custom Sprite3D shaders.
## Workaround until https://github.com/godotengine/godot/pull/103274 lands.
## After that PR: change node type back to AnimatedSprite3D and delete this script.

var _material_uniqued := false
var _signals_hooked := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_hook_signals()
		_ensure_unique_material()
		call_deferred("_sync_material")


func _ready() -> void:
	_hook_signals()
	_ensure_unique_material()
	_sync_material()


func _hook_signals() -> void:
	if _signals_hooked:
		return
	if not frame_changed.is_connected(_sync_material):
		frame_changed.connect(_sync_material)
	if not animation_changed.is_connected(_sync_material):
		animation_changed.connect(_sync_material)
	if not sprite_frames_changed.is_connected(_sync_material):
		sprite_frames_changed.connect(_sync_material)
	_signals_hooked = true


func _ensure_unique_material() -> void:
	if material_override == null or _material_uniqued:
		return
	material_override = material_override.duplicate()
	_material_uniqued = true


func _sync_material() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null or sprite_frames == null:
		return
	if animation == &"" or not sprite_frames.has_animation(animation):
		return
	if frame < 0 or frame >= sprite_frames.get_frame_count(animation):
		return

	var frame_tex := sprite_frames.get_frame_texture(animation, frame)
	if frame_tex is AtlasTexture:
		var atlas_tex := frame_tex as AtlasTexture
		var atlas := atlas_tex.atlas
		if atlas == null:
			return
		var atlas_size := atlas.get_size()
		if atlas_size.x <= 0.0 or atlas_size.y <= 0.0:
			return
		var region := atlas_tex.region
		mat.set_shader_parameter("texture_albedo", atlas)
		mat.set_shader_parameter("albedo_texture_size", Vector2i(atlas_size))
		mat.set_shader_parameter("atlas_uv_min", region.position / atlas_size)
		mat.set_shader_parameter("atlas_uv_size", region.size / atlas_size)
	elif frame_tex != null:
		var tex_size := frame_tex.get_size()
		mat.set_shader_parameter("texture_albedo", frame_tex)
		mat.set_shader_parameter("albedo_texture_size", Vector2i(tex_size))
		mat.set_shader_parameter("atlas_uv_min", Vector2.ZERO)
		mat.set_shader_parameter("atlas_uv_size", Vector2.ONE)
