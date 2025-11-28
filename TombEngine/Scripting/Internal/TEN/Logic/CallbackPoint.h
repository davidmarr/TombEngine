#pragma once

#include "Scripting/Internal/TEN/Flow/FlowHandler.h"

namespace TEN::Scripting
{
	/// Points in the game flow where level scripts can hook into.
	// @enum Logic.CallbackPoint
	// @pragma nostrip
	static const auto CALLBACK_POINTS = std::unordered_map<std::string, CallbackPoint>
	{
		/// Will be called immediately before LevelFuncs.OnStart.
		// @mem PreStart
		{ ScriptReserved_PreStart, CallbackPoint::PreStart },

		/// Will be called immediately after LevelFuncs.OnStart.
		// @mem PostStart
		{ ScriptReserved_PostStart, CallbackPoint::PostStart },

		/// Will be called immediately before LevelFuncs.OnLoad.
		// @mem PreLoad
		{ ScriptReserved_PreLoad, CallbackPoint::PreLoad },

		/// Will be called immediately after LevelFuncs.OnLoad.
		// @mem PostLoad
		{ ScriptReserved_PostLoad, CallbackPoint::PostLoad },

		/// Will be called in the beginning of game loop (LevelFuncs.OnLoop).
		// @mem PreLoop
		{ ScriptReserved_PreLoop, CallbackPoint::PreLoop },

		/// Will be called at the end of game loop (LevelFuncs.OnLoop).
		// @mem PostLoop
		{ ScriptReserved_PostLoop, CallbackPoint::PostLoop },

		/// Will be called immediately before LevelFuncs.OnSave.
		// @mem PreSave
		{ ScriptReserved_PreSave, CallbackPoint::PreSave },

		/// Will be called immediately after LevelFuncs.OnSave.
		// @mem PostSave
		{ ScriptReserved_PostSave, CallbackPoint::PostSave },

		/// Will be called immediately before LevelFuncs.OnEnd.
		// @mem PreEnd
		{ ScriptReserved_PreEnd, CallbackPoint::PreEnd },

		/// Will be called immediately after LevelFuncs.OnEnd.
		// @mem PostEnd
		{ ScriptReserved_PostEnd, CallbackPoint::PostEnd },

		/// Will be called immediately before LevelFuncs.OnUseItem.
		// @mem PreUseItem
		{ ScriptReserved_PreUseItem, CallbackPoint::PreUseItem },

		/// Will be called immediately after LevelFuncs.OnUseItem.
		// @mem PostUseItem
		{ ScriptReserved_PostUseItem, CallbackPoint::PostUseItem },

		/// Will be called immediately before LevelFuncs.OnFreeze. This accepts functions that take an objectNumber argument, such as OnUseItem
		// @mem PreFreeze
		{ ScriptReserved_PreFreeze, CallbackPoint::PreFreeze },

		/// Will be called immediately after LevelFuncs.OnFreeze. This accepts functions that take an objectNumber argument, such as OnUseItem
		// @mem PostFreeze
		{ ScriptReserved_PostFreeze, CallbackPoint::PostFreeze },

		// COMPATIBILITY
		{ "POSTSTART", CallbackPoint::PostStart },
		{ "PRELOAD", CallbackPoint::PreLoad },
		{ "POSTLOAD", CallbackPoint::PostLoad },
		{ "PRELOOP", CallbackPoint::PreLoop },
		{ "PRECONTROLPHASE", CallbackPoint::PreLoop },
		{ "POSTLOOP", CallbackPoint::PostLoop },
		{ "POSTCONTROLPHASE", CallbackPoint::PostLoop },
		{ "PRESAVE", CallbackPoint::PreSave },
		{ "POSTSAVE", CallbackPoint::PostSave },
		{ "PREEND", CallbackPoint::PreEnd },
		{ "POSTEND", CallbackPoint::PostEnd },
		{ "PREUSEITEM", CallbackPoint::PreUseItem },
		{ "POSTUSEITEM", CallbackPoint::PostUseItem },
		{ "PREFREEZE", CallbackPoint::PreFreeze },
		{ "POSTFREEZE", CallbackPoint::PostFreeze }
	};
}