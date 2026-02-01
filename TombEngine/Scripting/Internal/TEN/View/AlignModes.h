#pragma once

#include "Game/Effects/DisplaySprite.h"

using namespace TEN::Effects::DisplaySprite;

namespace TEN::Scripting::View
{
	/// Constants for sprite align modes.
	// To be used with @{View.DisplaySprite} class.
	// @enum View.AlignMode
	// @pragma nostrip

	static const std::unordered_map<std::string, DisplaySpriteAlignMode> ALIGN_MODES
	{
		/// Center alignment.
		// @mem CENTER
		{ "CENTER", DisplaySpriteAlignMode::Center },

		/// Center top alignment.
		// @mem CENTER_TOP
		{ "TOP_CENTER", DisplaySpriteAlignMode::CenterTop },

		/// Center bottom alignment.
		// @mem CENTER_BOTTOM
		{ "BOTTOM_CENTER", DisplaySpriteAlignMode::CenterBottom },

		/// Center left alignment.
		// @mem CENTER_LEFT
		{ "CENTER_LEFT", DisplaySpriteAlignMode::CenterLeft },

		/// Center right alignment.
		// @mem CENTER_RIGHT
		{ "CENTER_RIGHT", DisplaySpriteAlignMode::CenterRight },

		/// Top left alignment.
		// @mem TOP_LEFT
		{ "TOP_LEFT", DisplaySpriteAlignMode::TopLeft },

		/// Top right alignment.
		// @mem TOP_RIGHT
		{ "TOP_RIGHT", DisplaySpriteAlignMode::TopRight },

		/// Bottom left alignment.
		// @mem BOTTOM_LEFT
		{ "BOTTOM_LEFT", DisplaySpriteAlignMode::BottomLeft },

		/// Bottom right alignment.
		// @mem BOTTOM_RIGHT
		{ "BOTTOM_RIGHT", DisplaySpriteAlignMode::BottomRight },

		// COMPATIBILITY
		{ "CENTER_BOTTOM", DisplaySpriteAlignMode::CenterBottom },
		{ "CENTER_TOP", DisplaySpriteAlignMode::CenterTop },
	};
}
