## ProfilePicture.gd
## Static helper — chuyển đổi base64 PNG thành Texture2D để hiển thị trong UI
## Dùng cho: HUD player card, AvatarCustomizer preview, InteractionDialog

class_name ProfilePicture
extends RefCounted

# Tạo Texture2D từ base64 PNG string (trả về null nếu lỗi)
static func base64_to_texture(base64_str: String) -> Texture2D:
	if base64_str.is_empty():
		return null
	var raw: PackedByteArray = Marshalls.base64_to_raw(base64_str)
	if raw.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(raw) != OK:
		return null
	return ImageTexture.create_from_image(img)

# Tạo TextureRect đã style sẵn (avatar hình tròn, crop center)
# size: kích thước vuông (px)
static func make_portrait_rect(size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.size = Vector2(size, size)
	return rect

# Tạo portrait TextureRect từ PlayerData.avatar_portrait_base64
# Trả về null nếu chưa có portrait
static func make_from_player_data(size: float) -> TextureRect:
	var tex := base64_to_texture(PlayerData.avatar_portrait_base64)
	if tex == null:
		return null
	var rect := make_portrait_rect(size)
	rect.texture = tex
	return rect
