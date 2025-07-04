#include "framework.h"
#include "ObjectsHandler.h"

#include "Game/collision/collide_item.h"
#include "Game/collision/collide_room.h"
#include "Game/Lara/lara.h"
#include "Scripting/Include/ScriptInterfaceGame.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/TEN/Objects/Camera/CameraObject.h"
#include "Scripting/Internal/TEN/Objects/Lara/AmmoTypes.h"
#include "Scripting/Internal/TEN/Objects/Lara/HandStatuses.h"
#include "Scripting/Internal/TEN/Objects/Lara/LaraObject.h"
#include "Scripting/Internal/TEN/Objects/Lara/WeaponTypes.h"
#include "Scripting/Internal/TEN/Objects/Moveable/MoveableStatuses.h"
#include "Scripting/Internal/TEN/Objects/ObjectIDs.h"
#include "Scripting/Internal/TEN/Objects/Room/RoomFlags.h"
#include "Scripting/Internal/TEN/Objects/Room/RoomObject.h"
#include "Scripting/Internal/TEN/Objects/Room/RoomReverbTypes.h"
#include "Scripting/Internal/TEN/Objects/Sink/SinkObject.h"
#include "Scripting/Internal/TEN/Objects/SoundSource/SoundSourceObject.h"
#include "Scripting/Internal/TEN/Objects/Volume/VolumeObject.h"

using namespace TEN::Scripting::Objects;

/// Objects include moveables, statics, cameras, and others.
// Every object accessible by script API must have unique name, disregarding its type.
// @tentable Objects 
// @pragma nostrip

ObjectsHandler::ObjectsHandler(sol::state* lua, sol::table& parent) :
	_handler(lua),
	_table_objects(sol::table(_handler.GetState()->lua_state(), sol::create))
{
	parent.set(ScriptReserved_Objects, _table_objects);

	/***
	Get a Moveable by its name.
	@function GetMoveableByName
	@tparam string name The unique name of the moveable as set in, or generated by, Tomb Editor.
	@treturn Objects.Moveable A non-owning Moveable referencing the item.
	*/
	_table_objects.set_function(ScriptReserved_GetMoveableByName, &ObjectsHandler::GetByName<Moveable, ScriptReserved_Moveable>, this);

	/***
	Get moveables by their slot.
	@function GetMoveablesBySlot
	@tparam Objects.ObjID slot The unique slot of the moveable, e.g. `Objects.ObjID.ANIMATING1`.
	@treturn table Table of moveables referencing the given slot.
	*/
	_table_objects.set_function(ScriptReserved_GetMoveablesBySlot, &ObjectsHandler::GetMoveablesBySlot<Moveable>, this);

	/***
	Get a Static by its name.
	@function GetStaticByName
	@tparam string name The unique name of the static mesh as set in, or generated by, Tomb Editor.
	@treturn Objects.Static A non-owning Static referencing the static mesh.
	*/
	_table_objects.set_function(ScriptReserved_GetStaticByName, &ObjectsHandler::GetByName<Static, ScriptReserved_Static>, this);

	/***
	Get statics by their slot.
	@function GetStaticsBySlot
	@tparam int slot The unique numerical slot of the static mesh.
	@treturn table Table of static meshes referencing the given slot.
	*/
	_table_objects.set_function(ScriptReserved_GetStaticsBySlot, &ObjectsHandler::GetStaticsBySlot<Static>, this);

	/***
	Get a Camera by its name.
	@function GetCameraByName
	@tparam string name The unique name of the camera as set in, or generated by, Tomb Editor.
	@treturn Objects.Camera A non-owning Camera referencing the camera.
	*/
	_table_objects.set_function(ScriptReserved_GetCameraByName, &ObjectsHandler::GetByName<CameraObject, ScriptReserved_Camera>, this);

	/***
	Get a Sink by its name.
	@function GetSinkByName
	@tparam string name The unique name of the sink as set in, or generated by, Tomb Editor.
	@treturn Objects.Sink A non-owning Sink referencing the sink.
	*/
	_table_objects.set_function(ScriptReserved_GetSinkByName, &ObjectsHandler::GetByName<Sink, ScriptReserved_Sink>, this);

	/***
	Get a SoundSource by its name.
	@function GetSoundSourceByName
	@tparam string name The unique name of the sound source as set in, or generated by, Tomb Editor.
	@treturn Objects.SoundSource A non-owning SoundSource referencing the sound source.
	*/
	_table_objects.set_function(ScriptReserved_GetSoundSourceByName, &ObjectsHandler::GetByName<SoundSource, ScriptReserved_SoundSource>, this);

	/***
	Get an AIObject by its name.
	@function GetAIObjectByName
	@tparam string name The unique name of the AIObject as set in, or generated by, Tomb Editor.
	@treturn Objects.AIObject A non-owning AIObject referencing the AI object.
	*/
	_table_objects.set_function(ScriptReserved_GetAIObjectByName, &ObjectsHandler::GetByName<AIObject, ScriptReserved_AIObject>, this);

	/***
	Get a Volume by its name.
	@function GetVolumeByName
	@tparam string name The unique name of the volume as set in, or generated by, Tomb Editor.
	@treturn Objects.Volume A non-owning Volume referencing the volume.
	*/
	_table_objects.set_function(ScriptReserved_GetVolumeByName, &ObjectsHandler::GetByName<Volume, ScriptReserved_Volume>, this);

	/***
	Get a Room by its name.
	@function GetRoomByName
	@tparam string name The unique name of the room as set in Tomb Editor.
	@treturn Objects.Room A non-owning Room referencing the room.
	*/
	_table_objects.set_function(ScriptReserved_GetRoomByName, &ObjectsHandler::GetByName<Room, ScriptReserved_Room>, this);

	/***
	Get rooms by tag.
	@function GetRoomsByTag
	@tparam string tag Tag to select rooms by.
	@treturn table Table of rooms containing the given tag.
	*/
	_table_objects.set_function(ScriptReserved_GetRoomsByTag, &ObjectsHandler::GetRoomsByTag<Room>, this);

	/***
	Check if a given script name is in use by any object type.
	@function IsNameInUse
	@tparam string name The name to check.
	@treturn bool True if name is in use and an object with a given name is present, false if not.
	*/
	_table_objects.set_function(ScriptReserved_IsNameInUse, &ObjectsHandler::IsNameInUse, this);

	LaraObject::Register(_table_objects);

	Moveable::Register(*lua, _table_objects);
	Moveable::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	Static::Register(_table_objects);
	Static::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	CameraObject::Register(_table_objects);
	CameraObject::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	Sink::Register(_table_objects);
	Sink::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	AIObject::Register(_table_objects);
	AIObject::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }	);

	SoundSource::Register(_table_objects);
	SoundSource::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	Room::Register(_table_objects);
	Room::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	Volume::Register(_table_objects);
	Volume::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); });

	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_ObjID, GAME_OBJECT_IDS);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_RoomFlagID, ROOM_FLAG_IDS);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_RoomReverb, ROOM_REVERB_TYPES);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_WeaponType, WEAPON_TYPES);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_AmmoType, AMMO_TYPES);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_HandStatus, HAND_STATUSES);
	_handler.MakeReadOnlyTable(_table_objects, ScriptReserved_MoveableStatus, MOVEABLE_STATUSES);
}

void ObjectsHandler::TestCollidingObjects()
{
	// Remove items which can't collide.
	for (int itemNumber : _collidingItemsToRemove)
		_collidingItems.erase(itemNumber);
	_collidingItemsToRemove.clear();

	for (int itemNumber0 : _collidingItems)
	{
		auto& item = g_Level.Items[itemNumber0];
		if (!item.Callbacks.OnObjectCollided.empty())
		{
			// Test against other moveables.
			auto collObjects = GetCollidedObjects(item, true, false);
			for (const auto& collidedItemPtr : collObjects.Items)
				g_GameScript->ExecuteFunction(item.Callbacks.OnObjectCollided, itemNumber0, collidedItemPtr->Index);
		}

		if (!item.Callbacks.OnRoomCollided.empty())
		{
			// Test against room geometry.
			if (TestItemRoomCollisionAABB(&item))
				g_GameScript->ExecuteFunction(item.Callbacks.OnRoomCollided, itemNumber0);
		}
	}
}

void ObjectsHandler::AssignPlayer()
{
	_table_objects.set(ScriptReserved_Lara, LaraObject(LaraItem->Index, true));
}

bool ObjectsHandler::NotifyKilled(ItemInfo* key)
{
	auto it = _moveables.find(key);
	if (it != std::end(_moveables))
	{
		for (auto* movPtr : _moveables[key])
			movPtr->Invalidate();
		
		return true;
	}

	return false;
}

bool ObjectsHandler::AddMoveableToMap(ItemInfo* key, Moveable* mov)
{
	std::unordered_set<Moveable*> movVec;
	movVec.insert(mov);
	auto it = _moveables.find(key);
	if (std::end(_moveables) == it)
	{
		return _moveables.insert(std::pair{ key, movVec }).second;
	}
	else
	{
		_moveables[key].insert(mov);
		return true;
	}
}

bool ObjectsHandler::RemoveMoveableFromMap(ItemInfo* key, Moveable* mov)
{
	auto it = _moveables.find(key);
	if (std::end(_moveables) != it)
	{
		auto& set = _moveables[key];

		bool isErased = static_cast<bool>(set.erase(mov));
		if (isErased && set.empty())
			isErased = isErased && static_cast<bool>(_moveables.erase(key));
		
		return isErased;
	}

	return false;
}
