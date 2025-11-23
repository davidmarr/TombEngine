#include "framework.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"

/// Represents an RGBA or RGB color.
// Components are specified as values clamped to the range [0, 255].
//
// @tenprimitive Color
// @pragma nostrip

namespace TEN::Scripting::Types
{
	namespace
	{
		// ITU-R BT.709 luminance coefficients.
		constexpr float LUMA_R = 0.2126f;
		constexpr float LUMA_G = 0.7152f;
		constexpr float LUMA_B = 0.0722f;
		constexpr float COLOR_NORMALIZE = 0.5f; // Normalize from [0.0, 2.0] to [0.0, 1.0].
		constexpr float HUE_SECTOR = 60.0f;
		constexpr float HUE_CIRCLE = 360.0f;
	}

	void ScriptColor::Register(sol::table& parent)
	{
		using ctors = sol::constructors<ScriptColor(byte, byte, byte), ScriptColor(byte, byte, byte, byte)>;

		// Register type.
		parent.new_usertype<ScriptColor>(
			"Color",
			ctors(),
			sol::call_constructor, ctors(),
			sol::meta_function::to_string, &ScriptColor::ToString,
			sol::meta_function::equal_to, &ScriptColor::operator ==,

			/// (int) Red component.
			// @mem r
			"r", sol::property(&ScriptColor::GetR, &ScriptColor::SetR),

			/// (int) Green component.
			// @mem g
			"g", sol::property(&ScriptColor::GetG, &ScriptColor::SetG),

			/// (int) Blue component.
			// @mem b
			"b", sol::property(&ScriptColor::GetB, &ScriptColor::SetB),

			/// (int) Alpha component (0 = invisible, 255 = opaque).
			// @mem a
			"a", sol::property(&ScriptColor::GetA, &ScriptColor::SetA),

			// Register methods.
			"Lerp", &ScriptColor::Lerp,
			"GetBrightness", & ScriptColor::GetBrightness,
			"GetSaturation", & ScriptColor::GetSaturation,
			"GetHue", & ScriptColor::GetHue,
			"ToGrayscale", & ScriptColor::ToGrayscale,
			"Invert", & ScriptColor::Invert,
			"Modulate", &ScriptColor::Modulate,
			"Saturate", &ScriptColor::Saturate
		);
	}

	/// Create a Color object.
	// @function Color
	// @int R Red component.
	// @int G Green component.
	// @int B Blue component.
	// @int[opt=255] A Alpha (transparency) component.
	// @treturn Color A new Color object.
	ScriptColor::ScriptColor(byte r, byte g, byte b) :
		_color(r, g, b)
	{
	}

	ScriptColor::ScriptColor(byte r, byte g, byte b, byte a) :
		ScriptColor(r, g, b)
	{
		SetA(a);
	}

	ScriptColor::ScriptColor(const Vector3& color) :
		_color(color)
	{
	}

	ScriptColor::ScriptColor(const Vector4& color) :
		_color(color)
	{
	}

	ScriptColor::ScriptColor(D3DCOLOR color) :
		_color(color)
	{
	}

	byte ScriptColor::GetR() const
	{
		return _color.GetR();
	}

	byte ScriptColor::GetG() const
	{
		return _color.GetG();
	}

	byte ScriptColor::GetB() const
	{
		return _color.GetB();
	}

	byte ScriptColor::GetA() const
	{
		return _color.GetA();
	}

	void ScriptColor::SetR(byte value)
	{
		_color.SetR(value);
	}

	void ScriptColor::SetG(byte value)
	{
		_color.SetG(value);
	}

	void ScriptColor::SetB(byte value)
	{
		_color.SetB(value);
	}

	void ScriptColor::SetA(byte value)
	{
		_color.SetA(value);
	}

	/// @tparam Color color This color.
	// @treturn string A string representing R, G, B, and A values.
	// @function __tostring
	std::string ScriptColor::ToString() const
	{
		return "{" + std::to_string(GetR()) + ", " + std::to_string(GetG()) + ", " + std::to_string(GetB()) + ", " + std::to_string(GetA()) + "}";
	}

	ScriptColor ScriptColor::PremultiplyAlpha()
	{
		_color = Vector3(_color) * ((float)_color.GetA() / (float)UCHAR_MAX);
		return *this;
	}

	ScriptColor::operator Color() const
	{
		return _color;
	}

	ScriptColor::operator Vector3() const
	{
		return _color;
	}

	ScriptColor::operator Vector4() const
	{
		return _color;
	}

	// NOTE: D3DCOLOR is 32 bits and is laid out as ARGB.
	ScriptColor::operator D3DCOLOR() const
	{
		return _color;
	}

	ScriptColor::operator RGBAColor8Byte() const
	{
		return _color;
	}

	bool ScriptColor::operator ==(const ScriptColor& other) const
	{
		return _color.GetR() == other.GetR() &&
			_color.GetG() == other.GetG() &&
			_color.GetB() == other.GetB() &&
			_color.GetA() == other.GetA();
	}

	inline Vector3 ScriptColor::GetNormalizedRGB() const
	{
		const Color& color = static_cast<const Color&>(_color);
		return Vector3(
			color.x * COLOR_NORMALIZE,
			color.y * COLOR_NORMALIZE,
			color.z * COLOR_NORMALIZE);
	}

	/// Get the perceived brightness of this Color using Rec.709 luminance formula.
	// @function Color:GetBrightness
	// @treturn float The brightness value in the range [0.0, 1.0].
	float ScriptColor::GetBrightness() const
	{
		const Vector3 normalized = GetNormalizedRGB();
		return (LUMA_R * normalized.x) + (LUMA_G * normalized.y) + (LUMA_B * normalized.z);
	}

	/// Get the saturation of this Color using the HSV color model.
	// @function Color:GetSaturation
	// @treturn float The saturation value in the range [0.0, 1.0].
	float ScriptColor::GetSaturation() const
	{
		const Vector3 normalized = GetNormalizedRGB();
		const float maxVal = std::max({ normalized.x, normalized.y, normalized.z });
		const float minVal = std::min({ normalized.x, normalized.y, normalized.z });

		// Saturation is 0 when max is 0 (black color).
		if (maxVal == 0.0f)
			return 0.0f;

		return (maxVal - minVal) / maxVal;
	}

	/// Get the hue of this Color using the HSV color model.
	// @function Color:GetHue
	// @treturn float The hue value in the range [0.0, 360.0) in degrees.
	float ScriptColor::GetHue() const
	{
		const Vector3 normalized = GetNormalizedRGB();
		const float maxVal = std::max({ normalized.x, normalized.y, normalized.z });
		const float minVal = std::min({ normalized.x, normalized.y, normalized.z });
		const float delta = maxVal - minVal;

		// Hue is undefined for achromatic colors.
		if (delta == 0.0f)
			return 0.0f;

		float hue = 0.0f;

		if (maxVal == normalized.x)
		{
			hue = HUE_SECTOR * fmodf((normalized.y - normalized.z) / delta, 6.0f);
		}
		else if (maxVal == normalized.y)
		{
			hue = HUE_SECTOR * (((normalized.z - normalized.x) / delta) + 2.0f);
		}
		else // maxVal == normalized.z
		{
			hue = HUE_SECTOR * (((normalized.x - normalized.y) / delta) + 4.0f);
		}

		// Normalize to [0.0, 360.0).
		if (hue < 0.0f)
			hue += HUE_CIRCLE;

		return hue;
	}

	/// Convert this Color to grayscale using perceived luminance (ITU-R BT.709).
	// @function Color:ToGrayscale
	// @treturn Color A grayscale version of this Color with RGB components set to the luminance value.
	ScriptColor ScriptColor::ToGrayscale() const
	{
		const byte grayscaleValue = static_cast<byte>(std::clamp(GetBrightness() * 255.0f, 0.0f, 255.0f));
		return ScriptColor(grayscaleValue, grayscaleValue, grayscaleValue, GetA());
	}

	/// Invert the RGB components of this Color (255 - component).
	// @function Color:Invert
	// @treturn Color An inverted version of this Color with RGB components inverted (alpha unchanged).
	ScriptColor ScriptColor::Invert() const
	{
		return ScriptColor(
			255 - GetR(),
			255 - GetG(),
			255 - GetB(),
			GetA()
		);
	}

	/// Multiply this Color component-wise with another Color (modulation).
	// @function Color:Modulate
	// @tparam Color other The Color to multiply with.
	// @treturn Color The resulting Color.
	ScriptColor ScriptColor::Modulate(const ScriptColor& other) const
	{
		const Color result = Color::Modulate(static_cast<Color>(_color), static_cast<Color>(other._color));
		return ScriptColor(result);
	}

	/// Saturate this Color (clamp all components to valid range).
	// @function Color:Saturate
	// @treturn Color The saturated Color.
	ScriptColor ScriptColor::Saturate() const
	{
		Color color = static_cast<Color>(_color);
		color.Saturate();
		return ScriptColor(color);
	}

	/// Get the linearly interpolated Color between this Color and the input Color according to the input alpha.
	// @function Color:Lerp
	// @tparam Color color The target Color.
	// @tparam float alpha The interpolation factor in the range [0.0, 1.0]. If alpha is outside this range, it will be clamped.
	// @treturn Color The resulting Color.
	ScriptColor ScriptColor::Lerp(const ScriptColor& color, float alpha) const
	{
		const float clampedAlpha = std::clamp(alpha, 0.0f, 1.0f);
		const Color result = Color::Lerp(_color, color, clampedAlpha);
		return ScriptColor(result);
	}
}
