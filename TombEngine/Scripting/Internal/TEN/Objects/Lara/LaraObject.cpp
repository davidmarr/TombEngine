#pragma once
#include "framework.h"
#include "Game/Lara/lara_helpers.h"
#include "LaraObject.h"
#include "Objects/Moveable/MoveableObject.h"
#include "Objects/ObjectsHandler.h"
#include "ReservedScriptNames.h"
#include "Specific/level.h"
#include "ScriptAssert.h"
#include "ScriptUtil.h"

/***
Represents lara object inside the game world.

@tenclass Objects.Lara
@pragma nostrip
*/

static auto index_error = index_error_maker(LaraObject, ScriptReserved_Lara);
static auto newindex_error = newindex_error_maker(LaraObject, ScriptReserved_Lara);

LaraObject::LaraObject(short num, bool alreadyInitialised) : m_item{ &g_Level.Items[num] }, m_num{ num }, m_initialised{ alreadyInitialised }
{
	
};

LaraObject::LaraObject(LaraObject&& other) noexcept :
	m_item{ std::exchange(other.m_item, nullptr) },
	m_num{ std::exchange(other.m_num, NO_ITEM) },
	m_initialised{ std::exchange(other.m_initialised, false) }
{

}


LaraObject::~LaraObject()
{

}

void LaraObject::Register(sol::table& parent)
{
	parent.new_usertype<LaraObject>(ScriptReserved_Lara,
		sol::no_constructor, // ability to spawn new ones could be added later
		sol::meta_function::index, index_error,
		sol::meta_function::new_index, newindex_error,

		/// Set Poison to Lara with specific potency of poison
		// @function Lara:SetPoison
		// @tparam int poison potency (0-64)
		ScriptReserved_SetPoison, &LaraObject::SetPoison,

		/// Remove Poison from Lara
		// @function Lara:RemovePoison
		ScriptReserved_RemovePoison, &LaraObject::RemovePoison
	);
}

void LaraObject::SetPoison(unsigned short potency = 0)
{
	auto* lara = GetLaraInfo(m_item);
	lara->PoisonPotency = potency;
}

void LaraObject::RemovePoison()
{
	auto* lara = GetLaraInfo(m_item);
	lara->PoisonPotency = 0;
}
