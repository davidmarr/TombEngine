#pragma once

#include "Game/Lara/lara_struct.h"


/// Constants for Weapon modes.
// @enum Objects.WeaponMode
// @pragma nostrip

/// Table of Objects.WeaponMode constants.
// To be used with @{Objects.LaraObject.SetWeaponMode} function. Currently only works for HK Weapon.
//
// - `RAPID_MODE` Sets the Rapid mode.
// - `BURST_MODE` Sets the Burst mode.
// - `SNIPER_MODE` Sets the Sniper mode.
//
// @table Objects.WeaponMode
namespace TEN::Scripting
{

	static const auto WEAPON_MODES = std::unordered_map<std::string, PlayerWeaponMode>
	{
		{ "RAPID_MODE", PlayerWeaponMode::HKRapid },
		{ "BURST_MODE", PlayerWeaponMode::HKBurst },
		{ "SNIPER_MODE", PlayerWeaponMode::HKSniper }
	};
}
