#pragma once

#include "Game/Lara/lara_struct.h"


/// Constants for HK Weapon modes.
// @enum Objects.WeaponMode
// @pragma nostrip

/// Table of Objects.WeaponMode constants.
// To be used with @{Objects.LaraObject.SetWeaponMode} function.
//
// - `HK_RAPID_MODE` Sets the HK Rapid mode.
// - `HK_BURST_MODE` Sets the HK Burst mode.
// - `HK_SNIPER_MODE` Sets the HK Sniper mode.
//
// @table Objects.WeaponMode
namespace TEN::Scripting
{

	static const auto WEAPON_MODES = std::unordered_map<std::string, PlayerWeaponMode>
	{
		{ "HK_RAPID_MODE", PlayerWeaponMode::HKRapid },
		{ "HK_BURST_MODE", PlayerWeaponMode::HKBurst },
		{ "HK_SNIPER_MODE", PlayerWeaponMode::HKSniper }
	};
}
