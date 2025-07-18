#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplaySprite/ScriptDisplaySprite.h"

#include "Game/effects/DisplaySprite.h"
#include "Game/Setup.h"
#include "Objects/game_object_ids.h"
#include "Renderer/Renderer.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

using namespace TEN::Scripting::Types;
using TEN::Renderer::g_Renderer;

/// Represents a display sprite.
//
// @tenclass View.DisplaySprite
// @pragma nostrip

namespace TEN::Scripting::DisplaySprite
{
	void ScriptDisplaySprite::Register(sol::state& state, sol::table& parent)
	{
		// NOTE: Single constructor with a sol::optional argument for the color doesn't work, hence the two constructors. -- Sezz 2023.10.19
		using ctors = sol::constructors<
			ScriptDisplaySprite(GAME_OBJECT_ID, int, const Vec2&, float, const Vec2&, const ScriptColor&),
			ScriptDisplaySprite(GAME_OBJECT_ID, int, const Vec2&, float, const Vec2&),
			ScriptDisplaySprite(const Vec2&, float, const Vec2&, const ScriptColor&),
			ScriptDisplaySprite(const Vec2&, float, const Vec2&)>;

		// Register type.
		parent.new_usertype<ScriptDisplaySprite>(
			ScriptReserved_DisplaySprite,
			ctors(),
			sol::call_constructor, ctors(),

		ScriptReserved_DisplayStringGetObjectID, &ScriptDisplaySprite::GetObjectID,
		ScriptReserved_DisplayStringGetSpriteID, &ScriptDisplaySprite::GetSpriteID,
		ScriptReserved_DisplayStringGetPosition, &ScriptDisplaySprite::GetPosition,
		ScriptReserved_DisplayStringGetRotation, &ScriptDisplaySprite::GetRotation,
		ScriptReserved_DisplayStringGetScale, &ScriptDisplaySprite::GetScale,
		ScriptReserved_DisplayStringGetColor, &ScriptDisplaySprite::GetColor,
		ScriptReserved_DisplayStringGetAnchors, & ScriptDisplaySprite::GetAnchors,
		ScriptReserved_DisplayStringSetObjectID, &ScriptDisplaySprite::SetObjectID,
		ScriptReserved_DisplayStringSetSpriteID, &ScriptDisplaySprite::SetSpriteID,
		ScriptReserved_DisplayStringSetPosition, &ScriptDisplaySprite::SetPosition,
		ScriptReserved_DisplayStringSetRotation, &ScriptDisplaySprite::SetRotation,
		ScriptReserved_DisplayStringSetScale, &ScriptDisplaySprite::SetScale,
		ScriptReserved_DisplayStringSetColor, &ScriptDisplaySprite::SetColor,
		ScriptReserved_DisplaySpriteDraw, &ScriptDisplaySprite::Draw);
	}

	/// Create a DisplaySprite object.
	// @function DisplaySprite
	// @tparam Objects.ObjID.SpriteConstants objectID ID of the sprite sequence object.
	// @tparam int index Index of the sprite in the sequence.
	// @tparam Vec2 pos Display position in percent.
	// @tparam float rot Rotation in degrees.
	// @tparam Vec2 scale Horizontal and vertical scale in percent. Scaling is interpreted by the DisplaySpriteEnum.ScaleMode passed to the Draw() function call.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Color.
	// @treturn DisplaySprite A new DisplaySprite object.
	ScriptDisplaySprite::ScriptDisplaySprite(GAME_OBJECT_ID objectID, int spriteID, const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color)
	{
		_objectID = objectID;
		_spriteID = std::clamp(spriteID, 0, INT_MAX);
		_position = pos;
		_rotation = rot;
		_scale = scale;
		_color = color;
	}

	ScriptDisplaySprite::ScriptDisplaySprite(GAME_OBJECT_ID objectID, int spriteID, const Vec2& pos, float rot, const Vec2& scale)
	{
		*this = ScriptDisplaySprite(objectID, spriteID, pos, rot, scale, ScriptColor(255, 255, 255, 255));
	}

	/// Create a DisplaySprite object with a video image.
	// Video should be played using @{View.PlayVideo} function in a background mode. If no video is played, sprite will not show.
	// @function DisplaySprite
	// @tparam Vec2 pos Display position in percent.
	// @tparam float rot Rotation in degrees.
	// @tparam Vec2 scale Horizontal and vertical scale in percent. Scaling is interpreted by the DisplaySpriteEnum.ScaleMode passed to the Draw() function call.
	// @tparam[opt] Color color Color. __Default: Color(255, 255, 255, 255)__
	// @treturn DisplaySprite A new DisplaySprite object with attached video image.
	ScriptDisplaySprite::ScriptDisplaySprite(const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color)
	{
		_objectID = GAME_OBJECT_ID::ID_DEFAULT_SPRITES;
		_spriteID = VIDEO_SPRITE_ID;
		_position = pos;
		_rotation = rot;
		_scale = scale;
		_color = color;
	}

	ScriptDisplaySprite::ScriptDisplaySprite(const Vec2& pos, float rot, const Vec2& scale)
	{
		*this = ScriptDisplaySprite(pos, rot, scale, ScriptColor(255, 255, 255, 255));
	}

	/// Get the object ID of the sprite sequence object used by the display sprite.
	// @function DisplaySprite:GetObjectID
	// @treturn Objects.ObjID.SpriteConstants Sprite sequence object ID.
	GAME_OBJECT_ID ScriptDisplaySprite::GetObjectID() const
	{
		return _objectID;
	}

	/// Get the sprite ID in the sprite sequence object used by the display sprite.
	// @function DisplaySprite:GetSpriteID
	// @treturn int Sprite ID in the sprite sequence object. Value __-1__ means that it is a background video, played using @{View.PlayVideo}.
	int ScriptDisplaySprite::GetSpriteID() const
	{
		return _spriteID;
	}

	/// Get the display position of the display sprite in percent.
	// @function DisplaySprite:GetPosition
	// @treturn Vec2 Display position in percent.
	Vec2 ScriptDisplaySprite::GetPosition() const
	{
		return _position;
	}

	/// Get the rotation of the display sprite in degrees.
	// @function DisplaySprite:GetRotation
	// @treturn float Rotation in degrees.
	float ScriptDisplaySprite::GetRotation() const
	{
		return _rotation;
	}

	/// Get the horizontal and vertical scale of the display sprite in percent.
	// @function DisplaySprite:GetScale
	// @treturn Vec2 Horizontal and vertical scale in percent.
	Vec2 ScriptDisplaySprite::GetScale() const
	{
		return _scale;
	}

	/// Get the color of the display sprite.
	// @function DisplaySprite:GetColor
	// @treturn Color Color.
	ScriptColor ScriptDisplaySprite::GetColor() const
	{
		return _color;
	}

	/// Get the anchors of the display sprite.
	// Anchors are the vertices of the display sprite, which can be used to position other objects relative to it.
	// @function DisplaySprite:GetAnchors
	// @tparam[opt=DisplaySpriteAlignMode.Center] View.AlignMode alignMode Alignment mode.
	// @tparam[opt=DisplaySpriteScaleMode.Fit] View.ScaleMode scaleMode Scaling mode.
	// @treturn table A table containing the vertices of the display sprite, which can be used to position other objects relative to it.<br>
	// The table will contain the following keys:<br>
	// - `TOP_LEFT`<br>
	// - `CENTER_TOP`<br>
	// - `TOP_RIGHT`<br>
	// - `CENTER_LEFT`<br>
	// - `CENTER`<br>
	// - `CENTER_RIGHT`<br>
	// - `BOTTOM_RIGHT`<br>
	// - `CENTER_BOTTOM`<br>
	// - `BOTTOM_LEFT`<br>
	sol::table ScriptDisplaySprite::GetAnchors(sol::optional<DisplaySpriteAlignMode> alignModeOpt, sol::optional<DisplaySpriteScaleMode> scaleModeOpt, sol::this_state state) const
	{
		auto anchorTable = sol::state_view(state).create_table();
		anchorTable["TOP_LEFT"] = Vec2(0.0f, 0.0f),
		anchorTable["CENTER_TOP"] = Vec2(0.0f, 0.0f),
		anchorTable["TOP_RIGHT"] = Vec2(0.0f, 0.0f),
		anchorTable["CENTER_LEFT"] = Vec2(0.0f, 0.0f),
		anchorTable["CENTER"] = Vec2(0.0f, 0.0f),
		anchorTable["CENTER_RIGHT"] = Vec2(0.0f, 0.0f),
		anchorTable["BOTTOM_RIGHT"] = Vec2(0.0f, 0.0f),
		anchorTable["CENTER_BOTTOM"] = Vec2(0.0f, 0.0f),
		anchorTable["BOTTOM_LEFT"] = Vec2(0.0f, 0.0f);

		// Object is not a sprite sequence; return early.
		if (_spriteID != VIDEO_SPRITE_ID && (_objectID < GAME_OBJECT_ID::ID_HORIZON || _objectID >= GAME_OBJECT_ID::ID_NUMBER_OBJECTS))
		{
			TENLog("Attempted to draw display sprite from non-sprite sequence object " + std::to_string(_objectID), LogLevel::Warning);
			return anchorTable;
		}

		// Sprite missing or sequence not found; return early.
		const auto& object = Objects[_objectID];
		if (!object.loaded || _spriteID >= abs(object.nmeshes))
		{
			TENLog(
				"Attempted to draw missing sprite " + std::to_string(_spriteID) +
				" from sprite sequence object " + std::to_string(_objectID) +
				" as display sprite.",
				LogLevel::Warning);
			return anchorTable;
		}

		constexpr auto DEFAULT_ALIGN_MODE = DisplaySpriteAlignMode::Center;
		constexpr auto DEFAULT_SCALE_MODE = DisplaySpriteScaleMode::Fit;
		constexpr auto SCALE_CONVERSION = 0.01f;
		constexpr auto DISPLAY_ASPECT = DISPLAY_SPACE_RES.x / DISPLAY_SPACE_RES.y;
		constexpr auto VERTEX_COUNT = 4;

		// Screen and sprite data
		auto screenRes = Vector2(g_Configuration.ScreenWidth, g_Configuration.ScreenHeight);
		const float screenAspect = screenRes.x / screenRes.y;
		const float aspectCorrectionBase = screenAspect / DISPLAY_ASPECT;
		const float aspectCorrectionBaseInv = 1.0f / aspectCorrectionBase;

		const auto& sprite = g_Renderer.GetSprites()[object.meshIndex + _spriteID];
		const float spriteAspect = static_cast<float>(sprite.Width) / sprite.Height;

		// Scaled values
		const Vector2 convertedScale = _scale * SCALE_CONVERSION;
		const Vector2 convertedPos = _position * (DISPLAY_SPACE_RES / 100.0f);
		const short convertedRot = ANGLE(_rotation);

		// Calculate halfSize and aspect correction
		Vector2 halfSize = Vector2::Zero;
		Vector2 aspectCorrection = Vector2::One;
		const auto scaleMode = scaleModeOpt.value_or(DEFAULT_SCALE_MODE);

		switch (scaleMode)
		{
		case DisplaySpriteScaleMode::Fit:
		case DisplaySpriteScaleMode::Fill:
		{
			const bool scaleByHeight = (scaleMode == DisplaySpriteScaleMode::Fit) ? (screenAspect >= spriteAspect)
				: (screenAspect < spriteAspect);
			if (scaleByHeight)
			{
				halfSize = Vector2(DISPLAY_SPACE_RES.y * convertedScale.y) / 2.0f;
				halfSize.x *= (spriteAspect >= 1.0f) ? spriteAspect : (1.0f / spriteAspect);
				aspectCorrection.x = aspectCorrectionBaseInv;
			}
			else
			{
				halfSize = Vector2(DISPLAY_SPACE_RES.x * convertedScale.x) / 2.0f;
				halfSize.y *= (spriteAspect >= 1.0f) ? (1.0f / spriteAspect) : spriteAspect;
				aspectCorrection.y = aspectCorrectionBase;
			}
			break;
		}
		case DisplaySpriteScaleMode::Stretch:
		default:
		{
			if (screenAspect >= 1.0f)
			{
				halfSize = Vector2(DISPLAY_SPACE_RES.x * convertedScale.x) / 2.0f;
				halfSize.y *= 1.0f / screenAspect;
				aspectCorrection.y = aspectCorrectionBase;
			}
			else
			{
				halfSize = Vector2(DISPLAY_SPACE_RES.y * convertedScale.y) / 2.0f;
				halfSize.x *= 1.0f / screenAspect;
				aspectCorrection.x = aspectCorrectionBaseInv;
			}
			break;
		}
		}

		// Offset based on alignment
		Vector2 offset = Vector2::Zero;
		const auto alignMode = alignModeOpt.value_or(DEFAULT_ALIGN_MODE);

		switch (alignMode)
		{
		case DisplaySpriteAlignMode::CenterTop:     offset = { 0.0f,  halfSize.y }; break;
		case DisplaySpriteAlignMode::CenterBottom:  offset = { 0.0f, -halfSize.y }; break;
		case DisplaySpriteAlignMode::CenterLeft:    offset = { halfSize.x, 0.0f }; break;
		case DisplaySpriteAlignMode::CenterRight:   offset = { -halfSize.x, 0.0f }; break;
		case DisplaySpriteAlignMode::TopLeft:       offset = { halfSize.x,  halfSize.y }; break;
		case DisplaySpriteAlignMode::TopRight:      offset = { -halfSize.x,  halfSize.y }; break;
		case DisplaySpriteAlignMode::BottomLeft:    offset = { halfSize.x, -halfSize.y }; break;
		case DisplaySpriteAlignMode::BottomRight:   offset = { -halfSize.x, -halfSize.y }; break;
		default: break; // Center
		}

		// Apply rotation to offset
		const Matrix rotMatrix = Matrix::CreateRotationZ(TO_RAD(convertedRot));
		offset = Vector2::Transform(offset, rotMatrix) * aspectCorrection;

		const Vector2 size = halfSize * 2.0f;
		const Vector2 position = convertedPos + offset;

		// Vertices centered around origin
		std::array<Vector2, VERTEX_COUNT> vertices = {
			Vector2(size.x,  size.y) / 2.0f, // top-left
			Vector2(-size.x,  size.y) / 2.0f, // top-right
			Vector2(-size.x, -size.y) / 2.0f, // bottom-right
			Vector2(size.x, -size.y) / 2.0f  // bottom-left
		};

		// Apply rotation + aspect + offset
		const Matrix rot180 = Matrix::CreateRotationZ(TO_RAD(convertedRot + ANGLE(180.0f)));

		for (auto& vertex : vertices)
		{
			vertex = Vector2::Transform(vertex, rot180);
			vertex *= aspectCorrection;
			vertex += position;
		}

		// Scale to screen resolution
		const Vector2 screenScale = screenRes / DISPLAY_SPACE_RES;
		for (auto& vertex : vertices)
		{
			vertex.x *= screenScale.x;
			vertex.y *= screenScale.y;
		}

		// Calculate anchors
		const Vector2 CENTER = (vertices[0] + vertices[2]) / 2.0f;
		const Vector2 CENTER_TOP = (vertices[0] + vertices[1]) / 2.0f;
		const Vector2 CENTER_LEFT = (vertices[0] + vertices[3]) / 2.0f;
		const Vector2 CENTER_RIGHT = (vertices[1] + vertices[2]) / 2.0f;
		const Vector2 CENTER_BOTTOM = (vertices[2] + vertices[3]) / 2.0f;

		// Create anchors array
		anchorTable["TOP_LEFT"] = Vec2(std::round((vertices[0].x / screenRes.x) * 10000.0f) / 100.0f, std::round((vertices[0].y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["CENTER_TOP"] = Vec2(std::round((CENTER_TOP.x / screenRes.x) * 10000.0f) / 100.0f, std::round((CENTER_TOP.y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["TOP_RIGHT"] = Vec2(std::round((vertices[1].x / screenRes.x) * 10000.0f) / 100.0f, std::round((vertices[1].y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["CENTER_LEFT"] = Vec2(std::round((CENTER_LEFT.x / screenRes.x) * 10000.0f) / 100.0f, std::round((CENTER_LEFT.y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["CENTER"] = Vec2(std::round((CENTER.x / screenRes.x) * 10000.0f) / 100.0f, std::round((CENTER.y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["CENTER_RIGHT"] = Vec2(std::round((CENTER_RIGHT.x / screenRes.x) * 10000.0f) / 100.0f, std::round((CENTER_RIGHT.y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["BOTTOM_RIGHT"] = Vec2(std::round((vertices[2].x / screenRes.x) * 10000.0f) / 100.0f, std::round((vertices[2].y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["CENTER_BOTTOM"] = Vec2(std::round((CENTER_BOTTOM.x / screenRes.x) * 10000.0f) / 100.0f, std::round((CENTER_BOTTOM.y / screenRes.y) * 10000.0f) / 100.0f);
		anchorTable["BOTTOM_LEFT"] = Vec2(std::round((vertices[3].x / screenRes.x) * 10000.0f) / 100.0f, std::round((vertices[3].y / screenRes.y) * 10000.0f) / 100.0f);

		return anchorTable;
	}

	/// Set the sprite sequence object ID used by the display sprite.
	// @function DisplaySprite:SetObjectID
	// @tparam Objects.ObjID.SpriteConstants objectID New sprite sequence object ID.
	void ScriptDisplaySprite::SetObjectID(GAME_OBJECT_ID objectID)
	{
		_objectID = objectID;
	}

	/// Set the sprite ID in the sprite sequence object used by the display sprite.
	// @function DisplaySprite:SetSpriteID
	// @tparam int spriteID New sprite ID in the sprite sequence object.
	void ScriptDisplaySprite::SetSpriteID(int spriteID)
	{
		_spriteID = spriteID;
	}

	/// Set the display position of the display sprite in percent.
	// @function DisplaySprite:SetPosition
	// @tparam Vec2 position New display position in percent.
	void ScriptDisplaySprite::SetPosition(const Vec2& pos)
	{
		_position = pos;
	}

	/// Set the rotation of the display sprite in degrees.
	// @function DisplaySprite:SetRotation
	// @tparam float rotation New rotation in degrees.
	void ScriptDisplaySprite::SetRotation(float rot)
	{
		_rotation = rot;
	}

	/// Set the horizontal and vertical scale of the display sprite in percent.
	// @function DisplaySprite:SetScale
	// @tparam float scale New horizontal and vertical scale in percent.
	void ScriptDisplaySprite::SetScale(const Vec2& scale)
	{
		_scale = scale;
	}

	/// Set the color of the display sprite.
	// @function DisplaySprite:SetColor
	// @tparam Color color New color.
	void ScriptDisplaySprite::SetColor(const ScriptColor& color)
	{
		_color = color;
	}

	/// Draw the display sprite in display space for the current frame.
	// @function DisplaySprite:Draw
	// @tparam[opt=0] int priority Draw priority. Can be thought of as a layer, with higher values having precedence.
	// Negative values will draw sprite above strings, while positive values will draw it under.
	// @tparam[opt=View.AlignMode.CENTER] View.AlignMode alignMode Align mode interpreting an offset from the sprite's position.
	// @tparam[opt=View.ScaleMode.FIT] View.ScaleMode scaleMode Scale mode interpreting the display sprite's horizontal and vertical scale.
	// @tparam[opt=Effects.BlendID.ALPHABLEND] Effects.BlendID blendMode Blend mode.
	void ScriptDisplaySprite::Draw(sol::optional<int> priority, sol::optional<DisplaySpriteAlignMode> alignMode,
								   sol::optional<DisplaySpriteScaleMode> scaleMode, sol::optional<BlendMode> blendMode)
	{
		// NOTE: Conversion from more intuitive 100x100 screen space resolution to internal 800x600 is required.
		// In a future refactor, everything will use 100x100 natively. -- Sezz 2023.08.31
		constexpr auto POS_CONVERSION_COEFF	  = Vector2(DISPLAY_SPACE_RES.x / 100, DISPLAY_SPACE_RES.y / 100);
		constexpr auto SCALE_CONVERSION_COEFF = 0.01f;

		constexpr auto DEFAULT_PRIORITY	  = 0;
		constexpr auto DEFAULT_ALIGN_MODE = DisplaySpriteAlignMode::Center;
		constexpr auto DEFAULT_SCALE_MODE = DisplaySpriteScaleMode::Fit;
		constexpr auto DEFAULT_BLEND_MODE = BlendMode::AlphaBlend;

		// Object is not a sprite sequence; return early.
		if (_spriteID != VIDEO_SPRITE_ID && (_objectID < GAME_OBJECT_ID::ID_HORIZON || _objectID >= GAME_OBJECT_ID::ID_NUMBER_OBJECTS))
		{
			TENLog("Attempted to draw display sprite from non-sprite sequence object " + std::to_string(_objectID), LogLevel::Warning);
			return;
		}

		// Sprite missing or sequence not found; return early.
		const auto& object = Objects[_objectID];
		if (!object.loaded || _spriteID >= abs(object.nmeshes))
		{
			TENLog(
				"Attempted to draw missing sprite " + std::to_string(_spriteID) +
				" from sprite sequence object " + std::to_string(_objectID) +
				" as display sprite.",
				LogLevel::Warning);
			return;
		}

		auto convertedPos = Vector2(_position.x, _position.y) * POS_CONVERSION_COEFF;
		short convertedRot = ANGLE(_rotation);
		auto convertedScale = Vector2(_scale.x, _scale.y) * SCALE_CONVERSION_COEFF;
		auto convertedColor = Vector4(_color.GetR(), _color.GetG(), _color.GetB(), _color.GetA()) / UCHAR_MAX;

		AddDisplaySprite(
			_objectID, _spriteID,
			convertedPos, convertedRot, convertedScale, convertedColor,
			priority.value_or(DEFAULT_PRIORITY),
			alignMode.value_or(DEFAULT_ALIGN_MODE),
			scaleMode.value_or(DEFAULT_SCALE_MODE),
			blendMode.value_or(DEFAULT_BLEND_MODE), 
			DisplaySpritePhase::Control);
	}
}
