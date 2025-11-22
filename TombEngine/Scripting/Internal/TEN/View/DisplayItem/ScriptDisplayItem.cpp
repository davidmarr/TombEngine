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
			ScriptDisplayItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits),
			ScriptDisplayItem(std::string)>;

		// Register type.
		parent.new_usertype<ScriptDisplayItem>(
			ScriptReserved_DrawItem,
			ctors(),
			sol::call_constructor, ctors(),
			ScriptReserved_DrawItemRemove, &ScriptDisplayItem::Remove,
			ScriptReserved_DrawItemExists, &ScriptDisplayItem::Exists,
			ScriptReserved_SetObjectID, & ScriptDisplayItem::SetItemObjectID,
			ScriptReserved_SetPosition, & ScriptDisplayItem::SetItemPosition,
			ScriptReserved_SetRotation, & ScriptDisplayItem::SetItemRotation,
			ScriptReserved_SetScale, &ScriptDisplayItem::SetItemScale,
			ScriptReserved_SetColor, &ScriptDisplayItem::SetItemColor,
			ScriptReserved_DrawItemSetMeshBits, &ScriptDisplayItem::SetItemMeshBits,
			ScriptReserved_DrawItemSetMeshRotation, &ScriptDisplayItem::SetItemMeshRotation,
			ScriptReserved_SetVisible, &ScriptDisplayItem::SetItemVisibility,
			ScriptReserved_GetObjectID, & ScriptDisplayItem::GetItemObjectID,
			ScriptReserved_GetPosition, &ScriptDisplayItem::GetItemPosition,
			ScriptReserved_GetRotation, &ScriptDisplayItem::GetItemRotation,
			ScriptReserved_GetScale, &ScriptDisplayItem::GetItemScale,
			ScriptReserved_GetColor, &ScriptDisplayItem::GetItemColor,
			ScriptReserved_DrawItemGetMeshRotation, &ScriptDisplayItem::GetItemMeshRotation,
			ScriptReserved_GetVisible, &ScriptDisplayItem::GetItemVisibility,
			ScriptReserved_DrawItemGetItem, &ScriptDisplayItem::GetItemByName,
			ScriptReserved_DrawItemRemoveItem, &ScriptDisplayItem::RemoveItem,
			ScriptReserved_DrawItemClearAll, &ScriptDisplayItem::ClearItems,
			ScriptReserved_DrawItemIfItemExists, &ScriptDisplayItem::IfItemExists,
			ScriptReserved_DrawItemIfObjectIDExists, &ScriptDisplayItem::IfObjectIDExists,
			ScriptReserved_DrawItemSetAmbientLight, &ScriptDisplayItem::SetAmbientLight,
			ScriptReserved_DrawItemSetCamera, &ScriptDisplayItem::SetCameraPosition,
			ScriptReserved_DrawItemSetTarget, &ScriptDisplayItem::SetCameraTargetPosition,
			ScriptReserved_DrawItemGetAmbientLight, &ScriptDisplayItem::GetAmbientLight,
			ScriptReserved_DrawItemGetCamera, &ScriptDisplayItem::GetCameraPosition,
			ScriptReserved_DrawItemGetTarget, &ScriptDisplayItem::GetCameraTargetPosition
			);
	}

	ScriptDisplayItem::ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits)
	{
		auto rot = rotation.ToEulerAngles();
		_itemName = itemName;
		g_DrawItems.AddItem(itemName, objectID, position, rot, scale, meshBits);
	}

	ScriptDisplayItem::ScriptDisplayItem(const std::string& itemName)
	{
		if (!g_DrawItems.IfItemExists(itemName))
		{
			// Mark as invalid
			_itemName.clear();
			return;
		}

		_itemName = itemName;
	}

	void ScriptDisplayItem::Remove()
	{
		if (_itemName.empty())
			return;

		g_DrawItems.RemoveItem(_itemName);
		_itemName.clear();
	}

	bool ScriptDisplayItem::Exists() const
	{
		return g_DrawItems.IfItemExists(_itemName);
	}

	void ScriptDisplayItem::SetItemObjectID(GAME_OBJECT_ID objectID)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);

		if (item)
		item->SetItemObjectID(objectID);
	}

	void ScriptDisplayItem::SetItemPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemPosition(newPos, convertedBool);
	}

	void ScriptDisplayItem::SetItemRotation(const Rotation& newRot, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		auto rotation = newRot.ToEulerAngles();
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemRotation(rotation, convertedBool);
	}

	void ScriptDisplayItem::SetItemScale(float newScale, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemScale(newScale, convertedBool);
	}

	void ScriptDisplayItem::SetItemColor(const ScriptColor& color, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		Color convertedColor = color;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemColor(convertedColor, convertedBool);
	}

	void ScriptDisplayItem::SetItemVisibility(bool visibility)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemVisibility(visibility);
	}

	void ScriptDisplayItem::SetItemMeshBits(int meshbits)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemMeshBits(meshbits);
	}

	void ScriptDisplayItem::SetItemMeshRotation(int meshIndex, Rotation angles, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemMeshRotation(meshIndex, angles.ToEulerAngles(), convertedBool);
	}

	GAME_OBJECT_ID ScriptDisplayItem::GetItemObjectID() const
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		return item->GetItemObjectID();

		return ID_NO_OBJECT;
	}

	Vec3 ScriptDisplayItem::GetItemPosition() const
	{
		if (_itemName.empty())
			return Vec3(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Vec3(0, 0, 0);

		return Vec3(item->GetItemPosition());
	}

	Rotation ScriptDisplayItem::GetItemRotation() const
	{
		if (_itemName.empty())
			return Rotation(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Rotation(0, 0, 0);

		return Rotation(item->GetItemRotation());
	}

	float ScriptDisplayItem::GetItemScale() const
	{
		if (_itemName.empty())
			return 0.0f;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return 0.0f;

		return item->GetItemScale();
	}

	ScriptColor ScriptDisplayItem::GetItemColor() const
	{
		if (_itemName.empty())
			return ScriptColor(0, 0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return ScriptColor(0, 0, 0, 0);

		return item->GetItemColor();
	}

	Rotation ScriptDisplayItem::GetItemMeshRotation(int mesh) const
	{
		if (_itemName.empty())
			return Rotation(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Rotation(0, 0, 0);

		auto rotation = item->GetItemMeshRotation(mesh);
		return Rotation(rotation);
	}

	bool ScriptDisplayItem::GetItemVisibility() const
	{
		if (_itemName.empty())
			return false;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return false;

		return item->GetItemVisibility();
	}

	ScriptDisplayItem ScriptDisplayItem::GetItemByName(const std::string& itemName)
	{
		return ScriptDisplayItem(itemName);
	}

	void ScriptDisplayItem::RemoveItem(const std::string& itemName)
	{
		if (!g_DrawItems.IfItemExists(itemName))
			return;

		g_DrawItems.RemoveItem(itemName);

	}

	void ScriptDisplayItem::ClearItems()
	{
		g_DrawItems.Clear();
	}

	bool ScriptDisplayItem::IfItemExists(const std::string& itemName)
	{
		return g_DrawItems.IfItemExists(itemName);
	}

	bool ScriptDisplayItem::IfObjectIDExists(const GAME_OBJECT_ID objectID)
	{
		return g_DrawItems.IfObjectIDExists(objectID);
	}

	//Camera functions

	void ScriptDisplayItem::SetAmbientLight(const ScriptColor& color)
	{
		g_DrawItems.SetAmbientLight(color);
	}

	void ScriptDisplayItem::SetCameraPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetCameraPosition(newPos, convertedBool);
	}

	void ScriptDisplayItem::SetCameraTargetPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		bool convertedBool = ValueOr<bool>(disableInterpolation, false);
		g_DrawItems.SetCameraTargetPosition(newPos, convertedBool);
	}

	ScriptColor ScriptDisplayItem::GetAmbientLight()
	{
		return g_DrawItems.GetAmbientLight();
	}

	Vec3 ScriptDisplayItem::GetCameraPosition()
	{
		return g_DrawItems.GetCameraPosition();
	}

	Vec3 ScriptDisplayItem::GetCameraTargetPosition()
	{
		return g_DrawItems.GetCameraTargetPosition();
	}
}
