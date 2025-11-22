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

/// Represents a Display Item.
//
// @tenclass View.DisplayItem
// @pragma nostrip

namespace TEN::Scripting::DisplayItem
{
	void ScriptDisplayItem::Register(sol::state& state, sol::table& parent)
	{
		using ctors = sol::constructors<
			ScriptDisplayItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits),
			ScriptDisplayItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale),
			ScriptDisplayItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position),
			ScriptDisplayItem(std::string)>;

		// Register type.
		parent.new_usertype<ScriptDisplayItem>(
			ScriptReserved_DrawItem,
			ctors(),
			sol::call_constructor, ctors(),
			ScriptReserved_DrawItemRemove, &ScriptDisplayItem::Remove,
			ScriptReserved_DrawItemExists, &ScriptDisplayItem::Exists,
			ScriptReserved_SetObjectID, &ScriptDisplayItem::SetItemObjectID,
			ScriptReserved_SetPosition, &ScriptDisplayItem::SetItemPosition,
			ScriptReserved_SetRotation, &ScriptDisplayItem::SetItemRotation,
			ScriptReserved_SetScale, &ScriptDisplayItem::SetItemScale,
			ScriptReserved_SetColor, &ScriptDisplayItem::SetItemColor,
			ScriptReserved_DrawItemSetMeshBits, &ScriptDisplayItem::SetItemMeshBits,
			ScriptReserved_SetMeshVisible, &ScriptDisplayItem::SetItemMeshVisibility,
			ScriptReserved_DrawItemSetMeshRotation, &ScriptDisplayItem::SetItemMeshRotation,
			ScriptReserved_SetVisible, &ScriptDisplayItem::SetItemVisibility,
			ScriptReserved_GetObjectID, & ScriptDisplayItem::GetItemObjectID,
			ScriptReserved_GetPosition, &ScriptDisplayItem::GetItemPosition,
			ScriptReserved_GetRotation, &ScriptDisplayItem::GetItemRotation,
			ScriptReserved_GetScale, &ScriptDisplayItem::GetItemScale,
			ScriptReserved_GetColor, &ScriptDisplayItem::GetItemColor,
			ScriptReserved_GetMeshVisible, &ScriptDisplayItem::GetItemMeshVisibility,
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

	/// Create a DisplayItem object.
	// @function DisplayItem
	// @tparam string itemName Lua name of the display item.
	// @tparam Objects.ObjID objectID ID of the object.
	// @tparam Vec3 position Position in 3d screen sapce.
	// @tparam[opt] Rotation rotation Rotation about x, y, and z axes.
	// @tparam[opt] float scale Set the visual scale.
	// @tparam[opt] int meshBits Packed meshbits.
	// @treturn DisplayItem A new DisplayItem object.
	// @usage
	// local item = DisplayItem("pistols", -- name
	//	TEN.Objects.ObjID.PISTOLS_ITEM, -- object id
	//	Vec3(0,200,1024)) -- position

	ScriptDisplayItem::ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits)
	{
		auto rot = rotation.ToEulerAngles();
		_itemName = itemName;
		g_DrawItems.AddItem(itemName, objectID, position, rot, scale, meshBits);
	}

	ScriptDisplayItem::ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale)
	{
		auto rot = rotation.ToEulerAngles();
		_itemName = itemName;
		g_DrawItems.AddItem(itemName, objectID, position, rot, scale, ALL_JOINT_BITS);
	}

	ScriptDisplayItem::ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position)
	{
		auto rot = Rotation(0, 0, 0).ToEulerAngles();

		_itemName = itemName;
		g_DrawItems.AddItem(itemName, objectID, position, rot, 1.0f, ALL_JOINT_BITS);
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

	/// Removes the Display Item.
	// @function DisplayItem:Remove
	void ScriptDisplayItem::Remove()
	{
		if (_itemName.empty())
			return;

		g_DrawItems.RemoveItem(_itemName);
		_itemName.clear();
	}

	/// Test if the Display Item exists.
	// @function DisplayItem:Exists
	// @treturn bool true if the Display Item exists.
	bool ScriptDisplayItem::Exists() const
	{
		return g_DrawItems.IfItemExists(_itemName);
	}

	/// Change the DisplayItem's object ID. 
	// @function DisplayItem:SetObjectID
	// @tparam Objects.ObjID objectID The new ID.
	// @usage
	// shiva = TEN.View.DisplayItem.GetItemByName("shiva_60")
	// shiva:SetObjectID(TEN.Objects.ObjID.BIGMEDI_ITEM)
	void ScriptDisplayItem::SetItemObjectID(GAME_OBJECT_ID objectID)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);

		if (item)
		item->SetItemObjectID(objectID);
	}

	/// Set the DisplayItem's position.
	// @function DisplayItem:SetPosition
	// @tparam Vec3 position The new position of the Display Item.
	// @bool[opt=false] disableInterPolation Disables interpolation to allow for snap movements.
	void ScriptDisplayItem::SetItemPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemPosition(newPos, convertedBool);
	}

	/// Set the DisplayItem's rotation.
	// @function DisplayItem:SetRotation
	// @tparam Rotation rotation The DisplayItem's new rotation.
	// @bool[opt=false] disableInterPolation Disables interpoaltion to allow for snap movements.
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

	/// Set the DisplayItem's visual scale.
	// @function DisplayItem:SetScale
	// @tparam float scale New visual scale.
	// @bool[opt=false] disableInterPolation Disables interpoaltion to allow for snap movements.
	void ScriptDisplayItem::SetItemScale(float newScale, TypeOrNil<bool> disableInterpolation)
	{
		if (_itemName.empty())
			return;

		bool convertedBool = ValueOr<bool>(disableInterpolation, false);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemScale(newScale, convertedBool);
	}

	/// Set the DisplayItem's color.
	// @function DisplayItem:SetColor
	// @tparam Color color The new color of the DisplayItem.
	// @bool[opt=false] disableInterPolation Disables interpoaltion to allow for snap color changes.
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

	/// Set the DisplayItems's visibility.
	// @bool visible true if the item should become visible, false if it should become invisible.
	// @function DisplayItem:SetVisible
	void ScriptDisplayItem::SetItemVisibility(bool visible)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemVisibility(visible);
	}

	void ScriptDisplayItem::SetItemMeshBits(int meshbits)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		item->SetItemMeshBits(meshbits);
	}

	/// Makes specified mesh visible or invisible.
	// Use this to show or hide a specified mesh of a DisplayItem.
	// @function DisplayItem:SetMeshVisible
	// @tparam int meshIndex Index of a mesh.
	// @tparam bool visible true if you want the mesh to be visible, false otherwise.
	void ScriptDisplayItem::SetItemMeshVisibility(int meshIndex, bool visible)
	{
		if (_itemName.empty())
			return;

		auto* item = g_DrawItems.GetItemByName(_itemName);

		if (item)
			item->SetItemMeshVisibility(meshIndex, visible);
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

	/// Retrieve the object ID from a DisplayItem.
	// @function DisplayItem:GetObjectID
	// @treturn Objects.ObjID A number representing the object ID of the DisplayItem.
	GAME_OBJECT_ID ScriptDisplayItem::GetItemObjectID() const
	{
		auto* item = g_DrawItems.GetItemByName(_itemName);
		
		if (item)
		return item->GetItemObjectID();

		return ID_NO_OBJECT;
	}
	/// Get the DisplayItem's position.
	// @function DisplayItem:GetPosition
	// @treturn Vec3 DisplayItem's position.
	Vec3 ScriptDisplayItem::GetItemPosition() const
	{
		if (_itemName.empty())
			return Vec3(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Vec3(0, 0, 0);

		return Vec3(item->GetItemPosition());
	}

	/// Get the DisplayItem's rotation.
	// @function DisplayItem:GetRotation
	// @treturn Rotation DisplayItem's rotation.
	Rotation ScriptDisplayItem::GetItemRotation() const
	{
		if (_itemName.empty())
			return Rotation(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Rotation(0, 0, 0);

		return Rotation(item->GetItemRotation());
	}

	/// Get the DisplayItem's visual scale.
	// @function DisplayItem:GetScale
	// @treturn float DisplayItem's visual scale.
	float ScriptDisplayItem::GetItemScale() const
	{
		if (_itemName.empty())
			return 0.0f;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return 0.0f;

		return item->GetItemScale();
	}

	/// Get the DisplayItem's color.
	// @function DisplayItem:GetColor
	// @treturn Color DisplayItem's color.
	ScriptColor ScriptDisplayItem::GetItemColor() const
	{
		if (_itemName.empty())
			return ScriptColor(0, 0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return ScriptColor(0, 0, 0, 0);

		return item->GetItemColor();
	}

	/// Get visibility state of a specified mesh of a DisplayItem.
	// Returns true if specified mesh is visible on a DisplayItem, and false
	// if it is not visible.
	// @function DisplayItem:GetMeshVisible
	// @tparam int index Index of a mesh.
	// @treturn bool Visibility status.
	bool ScriptDisplayItem::GetItemMeshVisibility(int meshIndex) const
	{
		if (_itemName.empty())
			return false;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return false;

		return item->GetItemMeshVisibility(meshIndex);
	}

	/// Get the DisplayItem's joint rotation.
	// @function DisplayItem:GetJointRotation
	// @tparam int meshIndex Index of a joint to get rotation.
	// @treturn Rotation DisplayItem's joint rotation.
	Rotation ScriptDisplayItem::GetItemMeshRotation(int meshIndex) const
	{
		if (_itemName.empty())
			return Rotation(0, 0, 0);

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return Rotation(0, 0, 0);

		auto rotation = item->GetItemMeshRotation(meshIndex);
		return Rotation(rotation);
	}

	/// Get the DisplayItem's visibility state.
	// @function DisplayItem:GetVisible
	// @treturn bool Item's visibility state.
	bool ScriptDisplayItem::GetItemVisibility() const
	{
		if (_itemName.empty())
			return false;

		auto* item = g_DrawItems.GetItemByName(_itemName);
		if (!item)
			return false;

		return item->GetItemVisibility();
	}

	/***
	Get a DisplayItem by its name.
	@function GetDisplayItemByName
	@tparam string name The unique name of the DisplayItem as set in, or generated by, Tomb Editor.
	@treturn Objects.DisplayItem A non-owning DisplayItem referencing the item.
	*/
	ScriptDisplayItem ScriptDisplayItem::GetItemByName(const std::string& itemName)
	{
		return ScriptDisplayItem(itemName);
	}

	/***
	Get a DisplayItem by its name.
	@function GetDisplayItemByName
	@tparam string name The unique name of the DisplayItem as set in, or generated by, Tomb Editor.
	@treturn Objects.DisplayItem A non-owning DisplayItem referencing the item.
	*/
	void ScriptDisplayItem::RemoveItem(const std::string& itemName)
	{
		if (!g_DrawItems.IfItemExists(itemName))
			return;

		g_DrawItems.RemoveItem(itemName);

	}

	/***
	Get a DisplayItem by its name.
	@function GetDisplayItemByName
	@tparam string name The unique name of the DisplayItem as set in, or generated by, Tomb Editor.
	@treturn Objects.DisplayItem A non-owning DisplayItem referencing the item.
	*/
	void ScriptDisplayItem::ClearItems()
	{
		g_DrawItems.Clear();
	}

	/***
	Check if a given script name is in use by any object type.
	@function IsNameInUse
	@tparam string name The name to check.
	@treturn bool True if name is in use and an object with a given name is present, false if not.
	*/
	bool ScriptDisplayItem::IfItemExists(const std::string& itemName)
	{
		return g_DrawItems.IfItemExists(itemName);
	}

	/***
	Check if a given name is in use by a display item.
	@function IsNameInUse
	@tparam string name The name to check.
	@treturn bool True if name is in use and an object with a given name is present, false if not.
	*/
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
