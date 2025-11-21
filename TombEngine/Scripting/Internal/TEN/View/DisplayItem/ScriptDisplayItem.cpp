#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayItem/ScriptDisplayItem.h"

#include "Game/Hud/DrawItems/DrawItems.h"

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
	void ScriptDisplayItem::Register(sol::state& state, sol::table& parent)
	{
		using ctors = sol::constructors<
			ScriptDisplayItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits)>;

		// Register type.
		parent.new_usertype<ScriptDisplayItem>(
			ScriptReserved_DrawItemAdd,
			ctors(),
			sol::call_constructor, ctors(),
			ScriptReserved_DrawItemRemove, &ScriptDisplayItem::RemoveItem,
			ScriptReserved_DrawItemSetObjectID, & ScriptDisplayItem::SetItemObjectID,
			ScriptReserved_DrawItemSetPosition, & ScriptDisplayItem::SetItemPosition,
			ScriptReserved_DrawItemSetRotation, & ScriptDisplayItem::SetItemRotation,
			ScriptReserved_DrawItemSetScale, &ScriptDisplayItem::SetItemScale,
			ScriptReserved_DrawItemSetVisibility, &ScriptDisplayItem::SetItemVisibility,
			ScriptReserved_DrawItemSetColor, &ScriptDisplayItem::SetItemColor,
			ScriptReserved_DrawItemSetMeshBits, &ScriptDisplayItem::SetItemMeshBits,
			ScriptReserved_DrawItemSetMeshRotation, &ScriptDisplayItem::SetItemMeshRotation,
			ScriptReserved_DrawItemGetObjectID, & ScriptDisplayItem::GetItemObjectID,
			ScriptReserved_DrawItemGetPosition, &ScriptDisplayItem::GetItemPosition,
			ScriptReserved_DrawItemGetRotation, &ScriptDisplayItem::GetItemRotation,
			ScriptReserved_DrawItemGetScale, &ScriptDisplayItem::GetItemScale,
			ScriptReserved_DrawItemGetColor, &ScriptDisplayItem::GetItemColor,
			ScriptReserved_DrawItemGetVisibility, &ScriptDisplayItem::GetItemVisibility,
			ScriptReserved_DrawItemGetMeshRotation, &ScriptDisplayItem::GetItemMeshRotation);
	}


	

	void ScriptDisplayItem::AddItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits)
	{
		auto rot = rotation.ToEulerAngles();
		_itemName = itemName;
		g_DrawItems.AddItem(itemName, objectID, position, rot, scale, meshBits);
	}

	void ScriptDisplayItem::RemoveItem()
	{
		g_DrawItems.RemoveItem(_itemName);
		_itemName.clear();
	}

	void ScriptDisplayItem::SetItemObjectID(GAME_OBJECT_ID objectID)
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemObjectID(objectID);
	}

	void ScriptDisplayItem::SetItemPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemPosition(newPos, convertedBool);
	}

	void ScriptDisplayItem::SetItemRotation(const Rotation& newRot, TypeOrNil<bool> disableInterpolation)
	{
		auto rotation = newRot.ToEulerAngles();
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemRotation(rotation, convertedBool);
	}

	void ScriptDisplayItem::SetItemScale(float newScale, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemScale(newScale, convertedBool);
	}

	void ScriptDisplayItem::SetItemColor(const ScriptColor& color, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		Color convertedColor = color;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemColor(convertedColor, convertedBool);
	}

	void ScriptDisplayItem::SetItemVisibility(bool visibility)
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemVisibility(visibility);
	}

	void ScriptDisplayItem::SetItemMeshBits(int meshbits)
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemMeshBits(meshbits);
	}

	void ScriptDisplayItem::SetItemMeshRotation(int meshIndex, Rotation angles, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		item->SetItemMeshRotation(meshIndex, angles.ToEulerAngles(), convertedBool);
	}


	GAME_OBJECT_ID ScriptDisplayItem::GetItemObjectID()
	{
		return GAME_OBJECT_ID();
	}

	Vec3 ScriptDisplayItem::GetItemPosition()
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto position = item->GetItemPosition();
		return Vec3(position);
	}

	Rotation ScriptDisplayItem::GetItemRotation()
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto rotation = item->GetItemRotation();
		return Rotation(rotation);
	}

	float ScriptDisplayItem::GetItemScale()
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto scale = item->GetItemScale();
		return scale;
	}

	ScriptColor ScriptDisplayItem::GetItemColor()
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto itemColor = item->GetItemColor();
		return itemColor;
	}

	bool ScriptDisplayItem::GetItemVisibility()
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto itemVisibility = item->GetItemVisibility();
		return itemVisibility;
	}

	Rotation ScriptDisplayItem::GetItemMeshRotation(int mesh)
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		auto rotation = item->GetItemMeshRotation(mesh);
		return Rotation(rotation);
	}

	static DisplayItem GetDisplayItemByName(std::string itemName)
	{
		return g_DrawItems.GetItemByName(itemName);
	}

	static bool IfItemExists(std::string itemName)
	{
		return g_DrawItems.IfItemExists(itemName);
	}

	static bool IfObjectIDExists(GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.IfObjectIDExists(objectID);
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
		tableDrawItems.set_function(ScriptReserved_DrawItemClearAll, &ClearItems);
		tableDrawItems.set_function(ScriptReserved_DrawItemIfItemExists, &IfItemExists);
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
