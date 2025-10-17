#pragma once

#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

namespace TEN::Scripting::Types
{
	class DisplayAnchors
	{
	public:
		static void Register(sol::table& parent);

		// Fields

		Vec2 TopLeft = Vec2(0.0f, 0.0f);
		Vec2 CenterTop = Vec2(0.0f, 0.0f);
		Vec2 TopRight = Vec2(0.0f, 0.0f);
		Vec2 CenterLeft = Vec2(0.0f, 0.0f);
		Vec2 Center = Vec2(0.0f, 0.0f);
		Vec2 CenterRight = Vec2(0.0f, 0.0f);
		Vec2 BottomLeft = Vec2(0.0f, 0.0f);
		Vec2 CenterBottom = Vec2(0.0f, 0.0f);
		Vec2 BottomRight = Vec2(0.0f, 0.0f);

		// Constructors

		DisplayAnchors() = default;
		DisplayAnchors(const Vec2& topLeft, const Vec2& centerTop, const Vec2& topRight,
		               const Vec2& centerLeft, const Vec2& center, const Vec2& centerRight,
		               const Vec2& bottomLeft, const Vec2& centerBottom, const Vec2& bottomRight);

		// Meta functions

		std::string ToString() const;
	};
}
