#include "framework.h"
#include "Renderer/Renderer11.h"
#include "Game/animation.h"
#include "Game/camera.h"
#include "Game/effects/effects.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/spotcam.h"
#include "Specific/level.h"
#include "Specific/setup.h"
#include "RenderView\RenderView.h"
#include "Game/items.h"
#include "ScriptInterfaceLevel.h"

namespace TEN::Renderer
{
	using namespace TEN::Renderer;
	using TEN::Memory::LinearArrayBuffer;
	using std::vector;

	bool Renderer11::ClipPortal(short parentRoomNumber, RendererPortal* door, Vector4 parentViewPort, Vector4* outClipPort, RenderView& renderView)
	{
		ROOM_INFO* parentRoom = &g_Level.Rooms[parentRoomNumber];

		int  zClip = 0;

		Vector4 tempClipPort = Vector4(INFINITY, INFINITY, -INFINITY, -INFINITY);

		// Do the heavy math only if door was not visited already
		if (!door->Visited)
		{
			int tooFar = 0;

			//float gameFarView = g_GameFlow->GetGameFarView() * float(SECTOR(1));
			//float levelFarView = g_GameFlow->GetLevel(CurrentLevel)->GetFarView() * float(SECTOR(1));

			//float farView = std::min(gameFarView, levelFarView);
			float farView = 100 * 1024.0f;

			Vector3 cameraPos = Vector3(Camera.pos.x, Camera.pos.y, Camera.pos.z);

			for (int i = 0; i < 4; i++)
			{
				// Project the corner in clipping space
				door->ScreenCoordinates[i] = Vector4::Transform(Vector4(
					door->AbsoluteCoordinates[i].x,
					door->AbsoluteCoordinates[i].y,
					door->AbsoluteCoordinates[i].z,
					1.0f), renderView.camera.ViewProjection);

				if (door->ScreenCoordinates[i].w > 0.0f)
				{
					// Scale correctly the result dividing by the homogenous coordinate
					door->ScreenCoordinates[i].x *= (1.0f / door->ScreenCoordinates[i].w);
					door->ScreenCoordinates[i].y *= (1.0f / door->ScreenCoordinates[i].w);
				}

				if ((cameraPos - door->AbsoluteCoordinates[i]).Length() >= farView)
					tooFar++;
			}

			// If all points are too far, just discard this portal and all connected rooms to it
			if (tooFar == 4)
			{
				door->NotVisible = true;
				return false;
			}

			// Mark the portal as visited, the heavy math was cached and will not be done anymore
			door->Visited = true;
		}

		for (int i = 0; i < 4; i++)
		{
			if (door->ScreenCoordinates[i].w > 0.0f)
			{
				// Expand the current clip area
				tempClipPort.x = std::min(tempClipPort.x, door->ScreenCoordinates[i].x);
				tempClipPort.y = std::min(tempClipPort.y, door->ScreenCoordinates[i].y);
				tempClipPort.z = std::max(tempClipPort.z, door->ScreenCoordinates[i].x);
				tempClipPort.w = std::max(tempClipPort.w, door->ScreenCoordinates[i].y);
			}
			else
				zClip++;
		}

		// If all corners of the portal are behind the camera, the portal must not be traversed
		if (zClip == 4)
		{
			door->NotVisible = true;
			return false;
		}

		// If some of the corners were behind the camera, do a proper clipping
		if (zClip > 0)
		{
			for (int i = 0; i < 4; i++)
			{
				Vector4 a = door->ScreenCoordinates[i];
				Vector4 b = door->ScreenCoordinates[(i + 1) % 4];

				if ((a.w > 0.0f) ^ (b.w > 0.0f))
				{
					if (a.x < 0.0f && b.x < 0.0f)
						tempClipPort.x = -1.0f;
					else
						if (a.x > 0.0f && b.x > 0.0f)
							tempClipPort.z = 1.0f;
						else
						{
							tempClipPort.x = -1.0f;
							tempClipPort.z = 1.0f;
						}

					if (a.y < 0.0f && b.y < 0.0f)
						tempClipPort.y = -1.0f;
					else
						if (a.y > 0.0f && b.y > 0.0f)
							tempClipPort.w = 1.0f;
						else
						{
							tempClipPort.y = -1.0f;
							tempClipPort.w = 1.0f;
						}
				}
			}
		}

		// Expand a bit the clipping area for avoiding precision issues
		tempClipPort.x = std::max(tempClipPort.x - CLIPPING_AREA_DELTA, -1.0f);
		tempClipPort.y = std::max(tempClipPort.y - CLIPPING_AREA_DELTA, -1.0f);
		tempClipPort.z = std::min(tempClipPort.z + CLIPPING_AREA_DELTA, 1.0f);
		tempClipPort.w = std::min(tempClipPort.w + CLIPPING_AREA_DELTA, 1.0f);

		// If found clipping area and parent clipping area are not intersecting, then 
		// the portal must not be traversed
		if (tempClipPort.x > parentViewPort.z 
			|| tempClipPort.y > parentViewPort.w 
			|| tempClipPort.z < parentViewPort.x 
			|| tempClipPort.w < parentViewPort.y)
			return false;

		// Output the final clipped area, intersecting both the current and the parent clipping area
		outClipPort->x = std::max(tempClipPort.x, parentViewPort.x);
		outClipPort->y = std::max(tempClipPort.y, parentViewPort.y);
		outClipPort->z = std::min(tempClipPort.z, parentViewPort.z);
		outClipPort->w = std::min(tempClipPort.w, parentViewPort.w);

		return true;
	}

	void Renderer11::CollectRooms(RenderView &renderView, bool onlyRooms)
	{
		short baseRoomIndex = renderView.camera.RoomNumber;

		// Reset rooms fields
		for (int i = 0; i < g_Level.Rooms.size(); i++)
		{
			RendererRoom* room = &m_rooms[i];

			room->ItemsToDraw.clear();
			room->EffectsToDraw.clear();
			room->TransparentFacesToDraw.clear();
			room->StaticsToDraw.clear();
			room->ViewPort = Vector4(-1.0f, -1.0f, 1.0f, 1.0f);
			room->ViewPorts.clear();
			room->InDrawList = false;

			for (int j = 0; j < room->Portals.size(); j++)
			{
				room->Portals[j].NotVisible = false;
				room->Portals[j].Visited = false;
			}
		}

		// Get all visible rooms, collecting all possible clipping rectangles
		GetVisibleRooms(NO_ROOM, Camera.pos.roomNumber, Vector4(-1.0f, -1.0f, 1.0f, 1.0f), 0, onlyRooms, renderView);

		// For each room, find the largest clipping area containing all clipping rectangles found 
		// in the previous step. We'll do overdraw in some cases but it won't cause glitches.
		for (int i = 0; i < g_Level.Rooms.size(); i++)
		{
			RendererRoom* room = &m_rooms[i];
			room->ViewPort = Vector4(INFINITY, INFINITY, -INFINITY, -INFINITY);
			for (int j = 0; j < room->ViewPorts.size(); j++)
			{
				Vector4 viewPort = room->ViewPorts[j];

				room->ViewPort.x = std::min(viewPort.x, room->ViewPort.x);
				room->ViewPort.y = std::min(viewPort.y, room->ViewPort.y);
				room->ViewPort.z = std::max(viewPort.z, room->ViewPort.z);
				room->ViewPort.w = std::max(viewPort.w, room->ViewPort.w);
			}
		}
	}
	
	Vector4 Renderer11::GetPortalScissorRect(Vector4 v)
	{
		// NOTE: clip space ranges from -1 to 1 and also Y coordinate from bottom to top.
		// This formula below does the trick of scaling it to 0 ... 1 with Y from top to bottom.
		return Vector4(
			(v.x * 0.5f + 0.5f) * m_screenWidth,
			(1.0f - (v.w * 0.5f + 0.5f)) * m_screenHeight,
			(v.z * 0.5f + 0.5f) * m_screenWidth,
			(1.0f - (v.y * 0.5f + 0.5f)) * m_screenHeight
		);
	}

	void Renderer11::GetVisibleRooms(short from, short to, Vector4 viewPort, int count, bool onlyRooms, RenderView& renderView)
	{
		// Avoid too much recursion depth
		if (count > 12) 
		{
			return;
		}

		RendererRoom* room = &m_rooms[to];
		ROOM_INFO* nativeRoom = &g_Level.Rooms[to];

		if (!room->InDrawList)
		{
			// Store the distance of the room from the camera
			Vector3 roomCentre = Vector3(nativeRoom->x + nativeRoom->xSize * WALL_SIZE / 2.0f,
				(nativeRoom->minfloor + nativeRoom->maxceiling) / 2.0f,
				nativeRoom->z + nativeRoom->zSize * WALL_SIZE / 2.0f);
			Vector3 laraPosition = Vector3(Camera.pos.x, Camera.pos.y, Camera.pos.z);
			room->Distance = (roomCentre - laraPosition).Length();

			renderView.roomsToDraw.push_back(room);
		}

		// Collect the current clipping area used to reach that room
		room->ViewPorts.push_back(viewPort);

		// Collect items
		if (!onlyRooms && !room->InDrawList)
		{
			CollectLightsForRoom(to, renderView);
			CollectItems(to, renderView);
			CollectStatics(to, renderView);
			CollectEffects(to);
		}

		room->InDrawList = true;

		// Traverse all portals for recursively collecting the visible rooms
		for (int i = 0; i < room->Portals.size(); i++)
		{
			RendererPortal* portal = &room->Portals[i];
			
			// If portal was already marked as not visible by a previous step, simply discard it
			if (portal->NotVisible)
				continue;

			if (!portal->Visited)
			{
				portal->ViewDirection = Vector3(Camera.pos.x, Camera.pos.y, Camera.pos.z) - portal->AbsoluteCoordinates[0];
				portal->ViewDirection.Normalize();
			}

			// Check if portal is visible
			if (portal->Normal.Dot(portal->ViewDirection) <= 0.0f)
			{
				portal->NotVisible = true;
				continue;
			}

			// Try to clip the portal and eventually find recursively the connected rooms
			Vector4 outClipPort;
			if (from != portal->Room && ClipPortal(to, portal, viewPort, &outClipPort, renderView))
			{
				GetVisibleRooms(to, portal->Room, outClipPort, count + 1, onlyRooms, renderView);
			}
		}
	}

	void Renderer11::CollectItems(short roomNumber, RenderView& renderView)
	{
		if (m_rooms.size() < roomNumber)
			return;

		RendererRoom& room = m_rooms[roomNumber];
		ROOM_INFO* r = &g_Level.Rooms[room.RoomNumber];

		short itemNum = NO_ITEM;
		for (itemNum = r->itemNumber; itemNum != NO_ITEM; itemNum = g_Level.Items[itemNum].NextItem)
		{
			ItemInfo* item = &g_Level.Items[itemNum];

			if (item->ObjectNumber == ID_LARA && itemNum == g_Level.Items[itemNum].NextItem)
				break;

			if (item->Status == ITEM_INVISIBLE)
				continue;

			if (item->ObjectNumber == ID_LARA && (BinocularRange || SpotcamOverlay || SpotcamDontDrawLara || CurrentLevel == 0))
				continue;

			if (!m_moveableObjects[item->ObjectNumber].has_value())
				continue;

			auto& obj = m_moveableObjects[item->ObjectNumber].value();

			if (obj.DoNotDraw)
				continue;

			// Clip object by frustum only if it doesn't cast shadows. Otherwise we may see
			// disappearing shadows if object gets out of frustum.

			if (obj.ShadowType == ShadowMode::None)
			{
				auto bounds = TO_DX_BBOX(item->Pose, GetBoundsAccurate(item));
				Vector3 min = bounds.Center - bounds.Extents;
				Vector3 max = bounds.Center + bounds.Extents;

				if (!renderView.camera.frustum.AABBInFrustum(min, max))
					continue;
			}

			auto newItem = &m_items[itemNum];

			newItem->ItemNumber = itemNum;
			newItem->ObjectNumber = item->ObjectNumber;
			newItem->Color = item->Color;
			newItem->Position = item->Pose.Position.ToVector3();
			newItem->Translation = Matrix::CreateTranslation(item->Pose.Position.x, item->Pose.Position.y, item->Pose.Position.z);
			newItem->Rotation = Matrix::CreateFromYawPitchRoll(TO_RAD(item->Pose.Orientation.y),
															   TO_RAD(item->Pose.Orientation.x),
															   TO_RAD(item->Pose.Orientation.z));
			newItem->Scale = Matrix::CreateScale(1.0f);
			newItem->World = newItem->Rotation * newItem->Translation;

			CalculateLightFades(newItem);
			CollectLightsForItem(newItem);

			room.ItemsToDraw.push_back(newItem);
		}
	}

	void Renderer11::CollectStatics(short roomNumber, RenderView& renderView)
	{
		if (m_rooms.size() < roomNumber)
			return;

		RendererRoom& room = m_rooms[roomNumber];
		ROOM_INFO* r = &g_Level.Rooms[room.RoomNumber];

		if (r->mesh.size() == 0)
			return;

		int numStatics = r->mesh.size();
		for (int i = 0; i < numStatics; i++)
		{
			auto mesh = &r->mesh[i];
			
			if (!(mesh->flags & StaticMeshFlags::SM_VISIBLE))
				continue;

			if (!m_staticObjects[mesh->staticNumber].has_value())
				continue;
			
			auto& obj = *m_staticObjects[mesh->staticNumber];

			if (obj.ObjectMeshes.size() == 0)
				continue;

			auto stat = &StaticObjects[mesh->staticNumber];
			auto bounds = TO_DX_BBOX(mesh->pos, &stat->visibilityBox);
			Vector3 min = bounds.Center - bounds.Extents;
			Vector3 max = bounds.Center + bounds.Extents;

			if (!renderView.camera.frustum.AABBInFrustum(min, max))
				continue;

			std::vector<RendererLight*> lights;
			if (obj.ObjectMeshes.front()->LightMode != LIGHT_MODES::LIGHT_MODE_STATIC)
				CollectLights(mesh->pos.Position.ToVector3(), ITEM_LIGHT_COLLECTION_RADIUS, room.RoomNumber, NO_ROOM, false, lights);

			Matrix world = (Matrix::CreateFromYawPitchRoll(TO_RAD(mesh->pos.Orientation.y), TO_RAD(mesh->pos.Orientation.x), TO_RAD(mesh->pos.Orientation.z)) *
							Matrix::CreateTranslation(mesh->pos.Position.x, mesh->pos.Position.y, mesh->pos.Position.z));

			auto staticInfo = RendererStatic
			{
				mesh->staticNumber,
				room.RoomNumber,
				mesh->pos.Position.ToVector3(),
				world,
				mesh->color,
				room.AmbientLight,
				lights
			};

			room.StaticsToDraw.push_back(staticInfo);
		}
	}

	void Renderer11::CollectLights(Vector3 position, float radius, int roomNumber, int prevRoomNumber, bool prioritizeShadowLight, std::vector<RendererLight*>& lights)
	{
		if (m_rooms.size() < roomNumber)
			return;

		// Now collect lights from dynamic list and from rooms
		std::vector<RendererLight*> tempLights;
		tempLights.reserve(MAX_LIGHTS_DRAW);
		
		RendererRoom& room = m_rooms[roomNumber];
		ROOM_INFO* nativeRoom = &g_Level.Rooms[room.RoomNumber];

		RendererLight* brightestLight = nullptr;
		float brightest = 0.0f;

		// Dynamic lights have the priority
		for (auto& light : dynamicLights)
		{
			float distance = (position - light.Position).Length();

			// Collect only lights nearer than 20 sectors
			if (distance >= SECTOR(20))
				continue;

			// Check the out radius
			if (distance > light.Out + radius)
				continue;

			float attenuation = 1.0f - distance / light.Out;
			float intensity = std::max(0.0f, attenuation * light.Intensity * Luma(light.Color));

			light.LocalIntensity = intensity;
			light.Distance = distance;

			tempLights.push_back(&light);
		}

		// Check current room and also neighbour rooms
		for (int roomToCheck : room.Neighbors)
		{
			RendererRoom& currentRoom = m_rooms[roomToCheck];
			int numLights = currentRoom.Lights.size();

			for (int j = 0; j < numLights; j++)
			{
				RendererLight* light = &currentRoom.Lights[j];

				// Check only lights different from sun
				if (light->Type == LIGHT_TYPE_SUN)
				{
					// Suns from non-adjacent rooms are not added!
					if (roomToCheck != roomNumber && (prevRoomNumber != roomToCheck || prevRoomNumber == NO_ROOM))
						continue;

					// Sun is added without distance checks
					light->Distance = 0;
					light->LocalIntensity = 0;
				}
				else if (light->Type == LIGHT_TYPE_POINT || light->Type == LIGHT_TYPE_SHADOW)
				{
					Vector3 lightPosition = Vector3(light->Position.x, light->Position.y, light->Position.z);
					float distance = (position - lightPosition).Length();

					// Collect only lights nearer than 20 sectors
					if (distance >= SECTOR(20))
						continue;

					// Check the out radius
					if (distance > light->Out + radius)
						continue;

					float attenuation = 1.0f - distance / light->Out;
					float intensity = std::max(0.0f, attenuation * light->Intensity * Luma(light->Color));

					light->LocalIntensity = intensity;
					light->Distance = distance;

					// If collecting shadows, try to collect shadow casting light
					if (light->CastShadows && prioritizeShadowLight && light->Type == LIGHT_TYPE_POINT)
					{
						if (intensity >= brightest)
						{
							brightest = intensity;
							brightestLight = light;
						}
					}
				}
				else if (light->Type == LIGHT_TYPE_SPOT)
				{
					Vector3 lightPosition = Vector3(light->Position.x, light->Position.y, light->Position.z);
					float distance = (position - lightPosition).Length();

					// Collect only lights nearer than 20 sectors
					if (distance >= SECTOR(20))
						continue;

					// Check the range
					if (distance > light->Out + radius)
						continue;

					float attenuation = 1.0f - distance / light->Out;
					float intensity = std::max(0.0f, attenuation * light->Intensity * Luma(light->Color));

					light->LocalIntensity = intensity;

					// If shadow pointer provided, try to collect shadow casting light
					if (light->CastShadows && prioritizeShadowLight)
					{
						if (intensity >= brightest)
						{
							brightest = intensity;
							brightestLight = light;
						}
					}

					light->Distance = distance;
				}
				else
				{
					// Invalid light type
					continue;
				}

				tempLights.push_back(light);
			}
		}

		// Sort lights by distance, if needed

		if (tempLights.size() > MAX_LIGHTS_PER_ITEM)
		{
			std::sort(
				tempLights.begin(),
				tempLights.end(),
				[](RendererLight* a, RendererLight* b)
				{
					return a->Distance < b->Distance;
				}
			);
		}

		// Now put actual lights to provided vector
		lights.clear();

		// Always add brightest light, if collecting shadow light is specified, even if it's far in range
		if (prioritizeShadowLight && brightestLight)
			lights.push_back(brightestLight);

		// Add max 8 lights per item, including the shadow light for Lara eventually
		for (auto l : tempLights)
		{
			if (prioritizeShadowLight && brightestLight == l)
				continue;

			lights.push_back(l);

			if (lights.size() == MAX_LIGHTS_PER_ITEM)
				break;
		}
	}

	void Renderer11::CollectLightsForCamera()
	{
		std::vector<RendererLight*> lightsToDraw;
		CollectLights(Vector3(Camera.pos.x, Camera.pos.y, Camera.pos.z), CAMERA_LIGHT_COLLECTION_RADIUS, Camera.pos.roomNumber, NO_ROOM, true, lightsToDraw);

		if (lightsToDraw.size() > 0 && lightsToDraw.front()->CastShadows)
			shadowLight = lightsToDraw.front();
		else
			shadowLight = nullptr;
	}	
	
	void Renderer11::CollectLightsForEffect(short roomNumber, RendererEffect* effect)
	{
		CollectLights(effect->Position, ITEM_LIGHT_COLLECTION_RADIUS, roomNumber, NO_ROOM, false, effect->LightsToDraw);
	}

	void Renderer11::CollectLightsForItem(RendererItem* item)
	{
		CollectLights(item->Position, ITEM_LIGHT_COLLECTION_RADIUS, item->RoomNumber, item->PrevRoomNumber, false, item->LightsToDraw);
	}

	void Renderer11::CalculateLightFades(RendererItem *item)
	{
		ItemInfo* nativeItem = &g_Level.Items[item->ItemNumber];

		// Interpolate ambient light between rooms
		if (item->PrevRoomNumber == NO_ROOM)
		{
			item->PrevRoomNumber = nativeItem->RoomNumber;
			item->RoomNumber = nativeItem->RoomNumber;
			item->LightFade = 1.0f;
		}
		else if (nativeItem->RoomNumber != item->RoomNumber)
		{
			item->PrevRoomNumber = item->RoomNumber;
			item->RoomNumber = nativeItem->RoomNumber;
			item->LightFade = 0.0f;
		}
		else if (item->LightFade < 1.0f)
		{
			item->LightFade += AMBIENT_LIGHT_INTERPOLATION_STEP;
			item->LightFade = std::clamp(item->LightFade, 0.0f, 1.0f);
		}

		if (item->PrevRoomNumber == NO_ROOM || item->LightFade == 1.0f)
			item->AmbientLight = m_rooms[nativeItem->RoomNumber].AmbientLight;
		else
		{
			auto prev = m_rooms[item->PrevRoomNumber].AmbientLight;
			auto next = m_rooms[item->RoomNumber].AmbientLight;

			item->AmbientLight.x = Lerp(prev.x, next.x, item->LightFade);
			item->AmbientLight.y = Lerp(prev.y, next.y, item->LightFade);
			item->AmbientLight.z = Lerp(prev.z, next.z, item->LightFade);
		}

		// Multiply calculated ambient light by object tint
		item->AmbientLight *= nativeItem->Color;
	}

	void Renderer11::CollectLightsForRoom(short roomNumber, RenderView &renderView)
	{
		if (m_rooms.size() < roomNumber)
			return;
		
		RendererRoom& room = m_rooms[roomNumber];
		ROOM_INFO* r = &g_Level.Rooms[roomNumber];
		
		Vector3 boxMin = Vector3(r->x + WALL_SIZE, r->maxceiling - STEP_SIZE, r->z + WALL_SIZE);
		Vector3 boxMax = Vector3(r->x + (r->xSize - 1) * WALL_SIZE, r->minfloor + STEP_SIZE, r->z + (r->zSize - 1) * WALL_SIZE);

		// Collect dynamic lights for rooms
		for (int i = 0; i < dynamicLights.size(); i++)
		{
			RendererLight* light = &dynamicLights[i];

			Vector3 center = Vector3(light->Position.x, light->Position.y, light->Position.z);

			// Light buffer is full
			if (renderView.lightsToDraw.size() >= NUM_LIGHTS_PER_BUFFER)
				continue;

			// Light already on a list
			if (std::find(renderView.lightsToDraw.begin(), renderView.lightsToDraw.end(), light) != renderView.lightsToDraw.end())
				continue;

			// Light is not within room bounds
			if (!SphereBoxIntersection(boxMin, boxMax, center, light->Out))
				continue;

			renderView.lightsToDraw.push_back(light);
		}
	}

	void Renderer11::CollectEffects(short roomNumber)
	{
		if (m_rooms.size() < roomNumber)
			return;

		RendererRoom& room = m_rooms[roomNumber];
		ROOM_INFO* r = &g_Level.Rooms[room.RoomNumber];

		short fxNum = NO_ITEM;
		for (fxNum = r->fxNumber; fxNum != NO_ITEM; fxNum = EffectList[fxNum].nextFx)
		{
			FX_INFO *fx = &EffectList[fxNum];

			if (fx->objectNumber < 0)
				continue;

			ObjectInfo *obj = &Objects[fx->objectNumber];

			RendererEffect *newEffect = &m_effects[fxNum];

			Matrix translation = Matrix::CreateTranslation(fx->pos.Position.x, fx->pos.Position.y, fx->pos.Position.z);
			Matrix rotation = Matrix::CreateFromYawPitchRoll(TO_RAD(fx->pos.Orientation.y), TO_RAD(fx->pos.Orientation.x), TO_RAD(fx->pos.Orientation.z));

			newEffect->ObjectNumber = fx->objectNumber;
			newEffect->RoomNumber = fx->roomNumber;
			newEffect->Position = fx->pos.Position.ToVector3();
			newEffect->World = rotation * translation;
			newEffect->Mesh = GetMesh(obj->nmeshes ? obj->meshIndex : fx->frameNumber);

			CollectLightsForEffect(fx->roomNumber, newEffect);

			room.EffectsToDraw.push_back(newEffect);
		}
	}

	void Renderer11::ResetAnimations()
	{
		for (int i = 0; i < NUM_ITEMS; i++)
			m_items[i].DoneAnimations = false;
	}
} // namespace TEN::Renderer

