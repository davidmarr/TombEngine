#pragma once
#include "Scripting/Internal/TEN/Flow/FlowHandler.h"

namespace TEN::Scripting
{
	/// Reasons why a level ended.
	// @enum Logic.EndReason
	static const auto LEVEL_END_REASONS = std::unordered_map<std::string, LevelEndReason>
	{
		/// Will be used when the level is completed successfully.
		// @mem LevelComplete
		{ ScriptReserved_EndReasonLevelComplete, LevelEndReason::LevelComplete },

		/// Will be used when the level ends due to loading a saved game.
		// @mem LoadGame
		{ ScriptReserved_EndReasonLoadGame, LevelEndReason::LoadGame },

		/// Will be used when the level ends due to exiting to the title screen.
		// @mem ExitToTitle
		{ ScriptReserved_EndReasonExitToTitle, LevelEndReason::ExitToTitle },

		/// Will be used when the level ends due to the player's death.
		// @mem Death
		{ ScriptReserved_EndReasonDeath, LevelEndReason::Death },

		/// Will be used when the level ends for any other reason.
		// @mem Other
		{ ScriptReserved_EndReasonOther, LevelEndReason::Other },

		// COMPATIBILITY
		{ "LEVELCOMPLETE", LevelEndReason::LevelComplete },
		{ "LOADGAME", LevelEndReason::LoadGame },
		{ "EXITTOTITLE", LevelEndReason::ExitToTitle }
	};
}