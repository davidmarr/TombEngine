#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayAnchors/DisplayAnchors.h"

namespace TEN::Scripting::Types
{
	/// Represents the anchor points of a display element.
	// @tenprimitive View.DisplayAnchors
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
			"TOP_LEFT", &DisplayAnchors::TOP_LEFT,

			/// (Vec2) Center-top anchor point in percent.
			// @mem TOP_CENTER
			"TOP_CENTER", &DisplayAnchors::TOP_CENTER,
			/// (Vec2) Top-right anchor point in percent.
			// @mem TOP_RIGHT
			"TOP_RIGHT", &DisplayAnchors::TOP_RIGHT,

			/// (Vec2) Center-left anchor point in percent.
			// @mem CENTER_LEFT
			"CENTER_LEFT", &DisplayAnchors::CENTER_LEFT,
			/// (Vec2) Center anchor point in percent.
			// @mem CENTER
			"CENTER", &DisplayAnchors::CENTER,

			/// (Vec2) Center-right anchor point in percent.
			// @mem CENTER_RIGHT
			"CENTER_RIGHT", &DisplayAnchors::CENTER_RIGHT,
			/// (Vec2) Bottom-left anchor point in percent.
			// @mem BOTTOM_LEFT
			"BOTTOM_LEFT", &DisplayAnchors::BOTTOM_LEFT,

			/// (Vec2) Bottom-center anchor point in percent.
			// @mem BOTTOM_CENTER
			"BOTTOM_CENTER", &DisplayAnchors::BOTTOM_CENTER,
			/// (Vec2) Bottom-right anchor point in percent.
			// @mem BOTTOM_RIGHT
			"BOTTOM_RIGHT", &DisplayAnchors::BOTTOM_RIGHT);
	}

	DisplayAnchors::DisplayAnchors(const Vec2& topLeft, const Vec2& topCenter, const Vec2& topRight,
	                               const Vec2& centerLeft, const Vec2& center, const Vec2& centerRight,
	                               const Vec2& bottomLeft, const Vec2& bottomCenter, const Vec2& bottomRight)
	{
		TOP_LEFT = topLeft;
		TOP_CENTER = topCenter;
		TOP_RIGHT = topRight;
		CENTER_LEFT = centerLeft;
		CENTER = center;
		CENTER_RIGHT = centerRight;
		BOTTOM_LEFT = bottomLeft;
		BOTTOM_CENTER = bottomCenter;
		BOTTOM_RIGHT = bottomRight;
	}

	/// Metafunction. Use tostring(anchors).
	// @tparam DisplayAnchors This DisplayAnchors.
	// @treturn string A string showing all anchor points.
	// @function __tostring
	// @usage
	// local anchors = TEN.View.DisplayAnchors()
	// print(tostring(anchors))
	// -- or --
	// print(anchors)
	// -- result:
	// -- DisplayAnchors { TOP_LEFT: Vec2 { x = 0.0, y = 0.0 }, TOP_CENTER: Vec2 { x = 0.0, y = 0.0 }, ... }
	//
	// -- Example with DisplaySprite:
	// local sprite = TEN.View.DisplaySprite(Objects.ObjID.MySpriteSequence, 0, Vec2(50, 50), 0, Vec2(100, 100))
	// local anchors = sprite:GetAnchors()
	// print(anchors)
	// -- result:
	// -- DisplayAnchors { TOP_LEFT: Vec2 { x = 45.0, y = 40.0 }, TOP_CENTER: Vec2 { x = 50.0, y = 40.0 }, ... }
	std::string DisplayAnchors::ToString() const
	{
		return "DisplayAnchors { \n"
			"TOP_LEFT: " + TOP_LEFT.ToString() + ", "
			"TOP_CENTER: " + TOP_CENTER.ToString() + ", "
			"TOP_RIGHT: " + TOP_RIGHT.ToString() + ", \n"
			"CENTER_LEFT: " + CENTER_LEFT.ToString() + ", "
			"CENTER: " + CENTER.ToString() + ", "
			"CENTER_RIGHT: " + CENTER_RIGHT.ToString() + ", \n"
			"BOTTOM_LEFT: " + BOTTOM_LEFT.ToString() + ", "
			"BOTTOM_CENTER: " + BOTTOM_CENTER.ToString() + ", "
			"BOTTOM_RIGHT: " + BOTTOM_RIGHT.ToString() + " \n}";
	}
}
