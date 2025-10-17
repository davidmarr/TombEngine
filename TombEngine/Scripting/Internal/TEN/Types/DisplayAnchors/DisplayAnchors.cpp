#include "framework.h"
#include "Scripting/Internal/TEN/Types/DisplayAnchors/DisplayAnchors.h"

#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

namespace TEN::Scripting::Types
{
	/// Represents the anchor points of a display element.
	// @tenprimitive DisplayAnchors
	// @pragma nostrip
	void DisplayAnchors::Register(sol::table& parent)
	{
		// Register type (no constructor exposed to Lua).
		parent.new_usertype<DisplayAnchors>(
			"DisplayAnchors",
			sol::no_constructor,

			sol::meta_function::to_string, &DisplayAnchors::ToString,

			/// (Vec2) Top-left anchor point in percent.
			// @mem TOP_LEFT
			"TOP_LEFT", &DisplayAnchors::TopLeft,

			/// (Vec2) Center-top anchor point in percent.
			// @mem CENTER_TOP
			"CENTER_TOP", &DisplayAnchors::CenterTop,

			/// (Vec2) Top-right anchor point in percent.
			// @mem TOP_RIGHT
			"TOP_RIGHT", &DisplayAnchors::TopRight,

			/// (Vec2) Center-left anchor point in percent.
			// @mem CENTER_LEFT
			"CENTER_LEFT", &DisplayAnchors::CenterLeft,

			/// (Vec2) Center anchor point in percent.
			// @mem CENTER
			"CENTER", &DisplayAnchors::Center,

			/// (Vec2) Center-right anchor point in percent.
			// @mem CENTER_RIGHT
			"CENTER_RIGHT", &DisplayAnchors::CenterRight,

			/// (Vec2) Bottom-left anchor point in percent.
			// @mem BOTTOM_LEFT
			"BOTTOM_LEFT", &DisplayAnchors::BottomLeft,

			/// (Vec2) Center-bottom anchor point in percent.
			// @mem CENTER_BOTTOM
			"CENTER_BOTTOM", &DisplayAnchors::CenterBottom,

			/// (Vec2) Bottom-right anchor point in percent.
			// @mem BOTTOM_RIGHT
			"BOTTOM_RIGHT", &DisplayAnchors::BottomRight);
	}

	DisplayAnchors::DisplayAnchors(const Vec2& topLeft, const Vec2& centerTop, const Vec2& topRight,
	                               const Vec2& centerLeft, const Vec2& center, const Vec2& centerRight,
	                               const Vec2& bottomLeft, const Vec2& centerBottom, const Vec2& bottomRight)
	{
		TopLeft = topLeft;
		CenterTop = centerTop;
		TopRight = topRight;
		CenterLeft = centerLeft;
		Center = center;
		CenterRight = centerRight;
		BottomLeft = bottomLeft;
		CenterBottom = centerBottom;
		BottomRight = bottomRight;
	}

	/// Metafunction. Use tostring(anchors).
	// @tparam DisplayAnchors This DisplayAnchors.
	// @treturn string A string showing all anchor points.
	// @function __tostring
	std::string DisplayAnchors::ToString() const
	{
		return "DisplayAnchors { "
			"TOP_LEFT: " + TopLeft.ToString() + ", "
			"CENTER_TOP: " + CenterTop.ToString() + ", "
			"TOP_RIGHT: " + TopRight.ToString() + ", "
			"CENTER_LEFT: " + CenterLeft.ToString() + ", "
			"CENTER: " + Center.ToString() + ", "
			"CENTER_RIGHT: " + CenterRight.ToString() + ", "
			"BOTTOM_LEFT: " + BottomLeft.ToString() + ", "
			"CENTER_BOTTOM: " + CenterBottom.ToString() + ", "
			"BOTTOM_RIGHT: " + BottomRight.ToString() + " }";
	}
}
