#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayItem/DisplayItem.h"

#include "Game/Hud/DrawItems.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"

using namespace TEN::Hud;

namespace TEN::Scripting::DisplayItem
{
	static void AddItem(GAME_OBJECT_ID objectID, const Vec3& origin, float scale, float opacity = 1.0f, int meshBits = 0u)
	{
		g_DrawItems.AddItem(objectID, origin, scale, opacity, meshBits);
	}
	static void RemoveItem(GAME_OBJECT_ID objectID)
	{
		g_DrawItems.RemoveItem(objectID);
	}

	static void SetItemPosition(GAME_OBJECT_ID objectID, const Vec3& newPos)
	{
		g_DrawItems.SetItemPosition(objectID, newPos);
	}

	static void SetItemRotation(GAME_OBJECT_ID objectID, const Rotation& newRot)
	{
		auto rotation = newRot.ToEulerAngles();
		g_DrawItems.SetItemRotation(objectID, rotation);
	}

	static void SetItemScale(GAME_OBJECT_ID objectID, float newScale)
	{
		g_DrawItems.SetItemScale(objectID, newScale);
	}

	static void SetItemTransparency(GAME_OBJECT_ID objectID, float alpha)
	{
		g_DrawItems.SetItemAlpha(objectID, alpha);
	}

	static void SetItemMeshBits(GAME_OBJECT_ID objectID, int meshbits)
	{
		g_DrawItems.SetItemMeshBits(objectID, meshbits);
	}

	static Vec3 GetItemPosition(GAME_OBJECT_ID objectID)
	{
		auto position = g_DrawItems.GetItemPosition(objectID);
		return Vec3(position);
	}

	static Rotation GetItemRotation(GAME_OBJECT_ID objectID)
	{
		auto rotation = g_DrawItems.GetItemRotation(objectID);
		return Rotation(rotation);
	}

	static float GetItemScale(GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.GetItemScale(objectID);
	}

	static void SetMeshRotation(GAME_OBJECT_ID objectID, int mesh, Rotation angles)
	{
		g_DrawItems.SetItemMeshRotation(objectID, mesh, angles.ToEulerAngles());
	}

	static Vec3 GetMeshRotation(GAME_OBJECT_ID objectID, int mesh)
	{
		auto rotation = g_DrawItems.GetItemMeshRotation(objectID, mesh);
		return Rotation(rotation);
	}

	static void ClearItems()
	{
		g_DrawItems.Clear();
	}

	//Camera functions
	static void SetCameraPosition(const Vec3& newPos)
	{
		g_DrawItems.SetCameraPosition(newPos);
	}

	static void SetTargetPosition(const Vec3& newPos)
	{
		g_DrawItems.SetCameraTargetPosition(newPos);
	}

	static Vec3 GetCameraPosition()
	{
		return g_DrawItems.GetCameraPosition();
	}

	static Vec3 GetTargetPosition()
	{
		return g_DrawItems.GetCameraTargetPosition();
	}

	//Inventory overrides
	static bool GetInventoryOverride()
	{
		return g_DrawItems.GetInventoryOverride();
	}

	static void SetInventoryOverride(bool value)
	{
		g_DrawItems.SetInventoryOverride(value);
	}

	static int GetInventoryOpenStatus()
	{
		return g_DrawItems.GetInventoryOpenStatus();
	}

	static void SetInventoryOpenStatus(int value)
	{
		g_DrawItems.SetInventoryOpenStatus(value);
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
		tableDrawItems.set_function(ScriptReserved_DrawItemSetAlpha, &SetItemTransparency);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetMeshBits, &SetItemMeshBits);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetPosition, &GetItemPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetRotation, &GetItemRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetScale, &GetItemScale);
		tableDrawItems.set_function(ScriptReserved_DrawItemClearAll, &ClearItems);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetMeshRotation, &GetMeshRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetMeshRotation, &SetMeshRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetCamera, &SetCameraPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetCamera, &GetCameraPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetTarget, &SetTargetPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetInvOverride, &GetInventoryOverride);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetInvOverride, &SetInventoryOverride);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetOpenInv, &GetInventoryOpenStatus);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetOpenInv, &SetInventoryOpenStatus);

	}
}
