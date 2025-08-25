#pragma once

#include "Game/Lara/lara_struct.h"


//Private constants required for inventory
namespace TEN::Scripting
{

	static const auto WEAPON_MODES = std::unordered_map<std::string, PlayerWeaponMode>
	{
		{ "HK_RAPID_MODE", PlayerWeaponMode::HKRapid },
		{ "HK_BURST_MODE", PlayerWeaponMode::HKBurst },
		{ "HK_SNIPER_MODE", PlayerWeaponMode::HKSniper }
	};
}
