#pragma once

#include "Specific/RGBAColor8Byte.h"

typedef DWORD D3DCOLOR;

namespace sol { class state; }
namespace sol { template <typename T> struct as_table_t; }

namespace TEN::Scripting::Types
{
	class ScriptColor
	{
	private:
		// Fields

		RGBAColor8Byte _color;

	public:
		static void Register(sol::table& parent);

		// Constructors

		ScriptColor();
		ScriptColor(byte r, byte g, byte b);
		ScriptColor(byte r, byte g, byte b, byte a);
		ScriptColor(const Vector3& color);
		ScriptColor(const Vector4& color);
		ScriptColor(D3DCOLOR);

		// Getters

		byte GetR() const;
		byte GetG() const;
		byte GetB() const;
		byte GetA() const;

		// Setters

		void SetR(byte value);
		void SetG(byte value);
		void SetB(byte value);
		void SetA(byte value);

		// Methods

		ScriptColor PremultiplyAlpha();
		float GetBrightness() const;
		float GetSaturation() const;
		float GetHue() const;
		ScriptColor ToGrayscale() const;
		ScriptColor Invert() const;
		ScriptColor Screen(const ScriptColor& other) const;

		// Utilities

		ScriptColor Lerp(const ScriptColor& color, float alpha) const;

		// Converters

		std::string ToString() const;

		// Operators

		operator Color() const;
		operator Vector3() const;
		operator Vector4() const;
		operator D3DCOLOR() const;
		operator RGBAColor8Byte() const;
		bool operator ==(const ScriptColor& other) const;
	};
}
