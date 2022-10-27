#pragma once
#include "framework.h"
#include "LaraObject.h"
#include "ReservedScriptNames.h"
#include "ScriptAssert.h"
#include "ScriptUtil.h"

/***
Represents lara object inside the game world.

@tenclass Objects.Lara
@pragma nostrip
*/

static auto index_error = index_error_maker(Test, ScriptReserved_Lara);
static auto newindex_error = newindex_error_maker(Test, ScriptReserved_Lara);

Test::Test(LaraInfo& ref) : m_lara{ ref }
{};

void Test::Register(sol::table& parent)
{
	parent.new_usertype<Test>(ScriptReserved_Sink,
		sol::no_constructor, // ability to spawn new ones could be added later
		sol::meta_function::index, index_error,
		sol::meta_function::new_index, newindex_error,

		/// Set Poison to Lara with specific potency of poison
		// @function Lara:SetPoison
		// @tparam int poison potency (0-64)
		ScriptReserved_GetPosition, & Test::SetPoison,

		/// Remove Poison from Lara
		// @function Lara:RemovePoison
		ScriptReserved_SetPosition, & Test::RemovePoison
	);
}

void Test::SetPoison(unsigned short potency = 0)
{
	m_lara.PoisonPotency = potency;
}

void Test::RemovePoison()
{
	m_lara.PoisonPotency = 0;
}