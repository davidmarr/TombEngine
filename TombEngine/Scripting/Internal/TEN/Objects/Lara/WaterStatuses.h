#pragma once

#include "Game/Lara/lara_struct.h"

/// Constants for player hand statuses.
// @enum Objects.HandStatus
// @pragma nostrip

/// Table of Objects.HandStatus constants.
// To be used with @{Objects.LaraObject.GetAmmoType} function.
//
// - `FREE`
// - `BUSY`
// - `WEAPON_DRAW`
// - `WEAPON_READY`
// - `SPECIAL`
//
// @table Objects.HandStatus

namespace TEN::Scripting
{
	static const auto WATER_STATUSES = std::unordered_map<std::string, WaterStatus>
	{
		{ "DRY", WaterStatus::Dry },
		{ "WADE", WaterStatus::Wade },
		{ "TREADWATER", WaterStatus::TreadWater },
		{ "UNDERWATER", WaterStatus::Underwater },
		{ "FLYCHEAT", WaterStatus::FlyCheat }
	};
}
