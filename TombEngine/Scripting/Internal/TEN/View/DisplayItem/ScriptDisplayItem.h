#include "framework.h"
#include "Game/Hud/DrawItems/DrawItems.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"

using namespace TEN::Scripting::Types;

namespace TEN::Scripting::DisplayItem
{
	constexpr auto ALL_JOINT_BITS = UINT_MAX;

	class ScriptDisplayItem
	{
	public:
		static void Register(sol::state& state, sol::table& parent);

	private:
		// Members
		std::string _itemName;

	public:
		// Constructors
		ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation,	float scale, int meshBits);
		ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position, const Rotation& rotation, float scale);
		ScriptDisplayItem(const std::string& itemName, GAME_OBJECT_ID objectID, const Vec3& position);
		ScriptDisplayItem(const std::string& itemName);
		
		// Methods
		void Remove();
		bool Exists() const;

		// Setters
		void SetItemObjectID(GAME_OBJECT_ID objectID);
		void SetItemPosition(const Vec3& newPos, TypeOrNil<bool> disableInterpolation);
		void SetItemRotation(const Rotation& newRot, TypeOrNil<bool> disableInterpolation);
		void SetItemScale(float newScale, TypeOrNil<bool> disableInterpolation);
		void SetItemColor(const ScriptColor& newColor, TypeOrNil<bool> disableInterpolation);
		void SetItemMeshBits(int meshbits);
		void SetItemMeshVisibility(int meshIndex, bool visible);
		void SetItemMeshRotation(int meshIndex, Rotation angles, TypeOrNil<bool> disableInterpolation);
		void SetItemVisibility(bool visible);

		// Getters
		GAME_OBJECT_ID GetItemObjectID() const;
		Vec3 GetItemPosition() const;
		Rotation GetItemRotation() const;
		float GetItemScale() const;
		ScriptColor GetItemColor() const;
		bool GetItemMeshVisibility(int meshIndex) const;
		Rotation GetItemMeshRotation(int meshIndex) const;
		bool GetItemVisibility() const;

		//functions
		static ScriptDisplayItem GetItemByName(const std::string& itemName);
		static void RemoveItem(const std::string& itemName);
		static void ClearItems();
		static bool IfItemExists(const std::string& itemName);
		static bool IfObjectIDExists(const GAME_OBJECT_ID objectID);

		//camera static functions
		//Setters
		static void SetAmbientLight(const ScriptColor& lightColor);
		static void SetCameraPosition(const Vec3& pos, TypeOrNil<bool> disableInterpolation);
		static void SetCameraTargetPosition(const Vec3& target, TypeOrNil<bool> disableInterpolation);

		//Getters
		static ScriptColor GetAmbientLight();
		static Vec3 GetCameraPosition();
		static Vec3 GetCameraTargetPosition();

	};

}
