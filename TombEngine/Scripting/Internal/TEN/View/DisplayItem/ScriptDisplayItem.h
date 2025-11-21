#include "framework.h"

#include "Game/Hud/DrawItems/DrawItems.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"

namespace TEN::Scripting::DisplayItem
{

	void Register(sol::state* lua, sol::table& parent);

	class ScriptDisplayItem
	{
	public:
		static void Register(sol::state& state, sol::table& parent);

	private:
		// Members
		std::string _itemName;

	public:
		// Constructors
		void AddItem(std::string itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale, int meshBits);

		// Remove Item
		void RemoveItem();

		// Getters
		void SetItemObjectID(GAME_OBJECT_ID objectID);
		void SetItemPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation);
		void SetItemRotation(const Rotation& newRot, TypeOrNil<bool> disableInterpolation);
		void SetItemScale(float newScale, TypeOrNil<bool> disableInterpolation);
		void SetItemColor(const ScriptColor& newColor, TypeOrNil<bool> disableInterpolation);
		void SetItemMeshBits(int meshbits);
		void SetItemMeshRotation(int meshIndex, Rotation angles, TypeOrNil<bool> disableInterpolation);
		void SetItemVisibility(bool visible);

		// Setters
		GAME_OBJECT_ID GetItemObjectID();
		Vec3 GetItemPosition();
		Rotation GetItemRotation();
		float GetItemScale();
		ScriptColor GetItemColor();
		bool GetItemVisibility();
		Rotation GetItemMeshRotation(int meshIndex);

	};

}
