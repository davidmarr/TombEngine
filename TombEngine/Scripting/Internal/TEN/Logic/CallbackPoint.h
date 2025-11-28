#pragma once

#include "Scripting/Internal/TEN/Flow/FlowHandler.h"

namespace TEN::Scripting
{
	/// Points in the game flow where level scripts can hook into.
	// @enum Logic.CallbackPoint
	// @pragma nostrip
	static const auto CALLBACK_POINTS = std::unordered_map<std::string, CallbackPoint>
	{
		/// Before level start.
		// @mem PreStart
		{ "PreStart", CallbackPoint::PreStart },
		/// After level start.
		// @mem PostStart
		{ "PostStart",  CallbackPoint::PostStart },
		/// Before level load.
		// @mem PreLoad
		{ "PreLoad",  CallbackPoint::PreLoad },
		/// After level load.
		// @mem PostLoad
		{ "PostLoad",  CallbackPoint::PostLoad },
		/// Before main loop iteration.
		// @mem PreLoop
		{ "PreLoop",  CallbackPoint::PreLoop },
		/// After main loop iteration.
		// @mem PostLoop
		{ "PostLoop",  CallbackPoint::PostLoop },
		/// Before level save.
		// @mem PreSave
		{ "PreSave",  CallbackPoint::PreSave },
		/// After level save.
		// @mem PostSave
		{ "PostSave",  CallbackPoint::PostSave },
		/// Before level end.
		// @mem PreEnd
		{ "PreEnd",  CallbackPoint::PreEnd },
		/// After level end.
		// @mem PostEnd
		{ "PostEnd",  CallbackPoint::PostEnd },
		/// Before an item is used.
		// @mem PreUseItem
		{ "PreUseItem",  CallbackPoint::PreUseItem },
		/// After an item is used.
		// @mem PostUseItem
		{ "PostUseItem",  CallbackPoint::PostUseItem },
		/// Before the game is frozen.
		// @mem PreFreeze
		{ "PreFreeze", CallbackPoint::PreFreeze },
		/// After the game is frozen.
		// @mem PostFreeze
		{ "PostFreeze", CallbackPoint::PostFreeze }
	};
}