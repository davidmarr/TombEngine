#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayItem/DisplayItem.h"

#include "Game/Hud/Hud.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"

using namespace TEN::Hud;

namespace TEN::Scripting::DisplayItem
{
	static void AddItem(GAME_OBJECT_ID objectID, const Vector3& origin, float scale)
	{
		g_Hud.DrawItems.AddItem(objectID, origin, scale);
	}
	static void RemoveItem(GAME_OBJECT_ID objectID)
	{
		g_Hud.DrawItems.RemoveItem(objectID);
	}

	static void SetItemPosition(GAME_OBJECT_ID objectID, const Vector3& newPos)
	{
		g_Hud.DrawItems.SetItemPosition(objectID, newPos);
	}

	static void SetItemRotation(GAME_OBJECT_ID objectID, const Rotation& newRot)
	{
		auto rotation = newRot.ToEulerAngles();
		g_Hud.DrawItems.SetItemRotation(objectID, rotation);
	}

	static void SetItemScale(GAME_OBJECT_ID objectID, float newScale)
	{
		g_Hud.DrawItems.SetItemScale(objectID, newScale);
	}

	static Vec3 GetItemPosition(GAME_OBJECT_ID objectID)
	{
		auto position = g_Hud.DrawItems.GetItemPosition(objectID);
		return Vec3(position);
	}

	static Rotation GetItemRotation(GAME_OBJECT_ID objectID)
	{
		auto rotation = g_Hud.DrawItems.GetItemRotation(objectID);
		return Rotation(rotation);
	}

	static float GetItemScale(GAME_OBJECT_ID objectID)
	{
		return g_Hud.DrawItems.GetItemScale(objectID);
	}

	void Register(sol::state* state, sol::table& parent)
	{
		auto tableDrawItems = sol::table(state->lua_state(), sol::create);
		parent.set(ScriptReserved_DrawItem, tableDrawItems);

		tableDrawItems.set_function(ScriptReserved_DrawItemAdd, &AddItem);
		tableDrawItems.set_function(ScriptReserved_DrawItemRemove, &RemoveItem);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetPosition, &SetItemPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetRotation, &SetItemRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetScale, &SetItemScale);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetPosition, &GetItemPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetRotation, &GetItemRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetScale, &GetItemScale);

	}
}
