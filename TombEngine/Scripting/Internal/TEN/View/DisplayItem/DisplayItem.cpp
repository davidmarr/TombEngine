#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayItem/DisplayItem.h"

#include "Game/Hud/DrawItems.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"


using namespace TEN::Hud;
using namespace TEN::Scripting::Types;

namespace TEN::Scripting::DisplayItem
{
	static void AddItem(GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits)
	{
		auto rot = rotation.ToEulerAngles();
		g_DrawItems.AddItem(objectID, position, rot, scale, meshBits);
	}
	static void RemoveItem(GAME_OBJECT_ID objectID)
	{
		g_DrawItems.RemoveItem(objectID);
	}

	static void SetItemPosition(GAME_OBJECT_ID objectID, const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetItemPosition(objectID, newPos, convertedBool);
	}

	static void SetItemRotation(GAME_OBJECT_ID objectID, const Rotation& newRot, TypeOrNil<bool> disableInterpolation)
	{
		auto rotation = newRot.ToEulerAngles();
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetItemRotation(objectID, rotation, convertedBool);
	}

	static void SetItemScale(GAME_OBJECT_ID objectID, float newScale, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetItemScale(objectID, newScale, convertedBool);
	}

	static void SetItemColor(GAME_OBJECT_ID objectID, const ScriptColor& color, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		Color convertedColor = color;
		g_DrawItems.SetItemColor(objectID, convertedColor, convertedBool);
	}

	static void SetItemVisibility(GAME_OBJECT_ID objectID, bool visibility)
	{
		g_DrawItems.SetItemVisibility(objectID, visibility);
	}

	static void SetItemMeshBits(GAME_OBJECT_ID objectID, int meshbits)
	{
		g_DrawItems.SetItemMeshBits(objectID, meshbits);
	}

	static void SetMeshRotation(GAME_OBJECT_ID objectID, int mesh, Rotation angles, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetItemMeshRotation(objectID, mesh, angles.ToEulerAngles(), convertedBool);
	}

	static bool IfItemExists(GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.IfItemExists(objectID);
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

	static ScriptColor GetItemColor(GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.GetItemColor(objectID);
	}

	static bool GetItemVisibility(GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.GetItemVisibility(objectID);
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
	static void SetCameraPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetCameraPosition(newPos, convertedBool);
	}

	static void SetTargetPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetCameraTargetPosition(newPos, convertedBool);
	}

	static Vec3 GetCameraPosition()
	{
		return g_DrawItems.GetCameraPosition();
	}

	static Vec3 GetTargetPosition()
	{
		return g_DrawItems.GetCameraTargetPosition();
	}

	static void SetAmbientLight(const ScriptColor& color)
	{
		g_DrawItems.SetAmbientLight(color);
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
		tableDrawItems.set_function(ScriptReserved_DrawItemSetVisibility, &SetItemVisibility);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetColor, &SetItemColor);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetMeshBits, &SetItemMeshBits);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetPosition, &GetItemPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetRotation, &GetItemRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetScale, &GetItemScale);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetColor, &GetItemColor);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetVisibility, &GetItemVisibility);
		tableDrawItems.set_function(ScriptReserved_DrawItemClearAll, &ClearItems);
		tableDrawItems.set_function(ScriptReserved_DrawItemIfItemExists, &IfItemExists);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetMeshRotation, &GetMeshRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetMeshRotation, &SetMeshRotation);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetCamera, &SetCameraPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetCamera, &GetCameraPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetTarget, &SetTargetPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetTarget, &GetTargetPosition);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetAmbientLight, &SetAmbientLight);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetInvOverride, &GetInventoryOverride);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetInvOverride, &SetInventoryOverride);
		tableDrawItems.set_function(ScriptReserved_DrawItemGetOpenInv, &GetInventoryOpenStatus);
		tableDrawItems.set_function(ScriptReserved_DrawItemSetOpenInv, &SetInventoryOpenStatus);

	}
}
