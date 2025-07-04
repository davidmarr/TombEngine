#include "framework.h"
#include "Renderer/Renderer.h"

#include "Game/animation.h"
#include "Game/effects/Hair.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/Lara/lara_fire.h"
#include "Game/Lara/lara_tests.h"
#include "Game/control/control.h"
#include "Game/spotcam.h"
#include "Game/camera.h"
#include "Game/collision/Sphere.h"
#include "Game/Setup.h"
#include "Math/Math.h"
#include "Scripting/Include/Flow/ScriptInterfaceFlowHandler.h"
#include "Scripting/Include/ScriptInterfaceLevel.h"
#include "Specific/level.h"

using namespace TEN::Effects::Hair;
using namespace TEN::Math;
using namespace TEN::Renderer;

extern ScriptInterfaceFlowHandler *g_GameFlow;

bool ShouldAnimateUpperBody(const LaraWeaponType& weapon)
{
	const auto& nativeItem = *LaraItem;
	auto& player = Lara;

	switch (weapon)
	{
	case LaraWeaponType::RocketLauncher:
	case LaraWeaponType::HarpoonGun:
	case LaraWeaponType::GrenadeLauncher:
	case LaraWeaponType::Crossbow:
	case LaraWeaponType::Shotgun:
		if (nativeItem.Animation.ActiveState == LS_IDLE ||
			nativeItem.Animation.ActiveState == LS_TURN_LEFT_FAST ||
			nativeItem.Animation.ActiveState == LS_TURN_RIGHT_FAST ||
			nativeItem.Animation.ActiveState == LS_TURN_LEFT_SLOW ||
			nativeItem.Animation.ActiveState == LS_TURN_RIGHT_SLOW)
		{
			return true;
		}

		return false;

	case LaraWeaponType::HK:
	{
		// Animate upper body if Lara is shooting from shoulder OR if Lara is standing still/turning
		int baseAnim = Objects[GetWeaponObjectID(weapon)].animIndex;
		if (player.RightArm.AnimNumber - baseAnim == 0 ||
			player.RightArm.AnimNumber - baseAnim == 2 ||
			player.RightArm.AnimNumber - baseAnim == 4)
		{
			return true;
		}
		else
		{
			if (nativeItem.Animation.ActiveState == LS_IDLE ||
				nativeItem.Animation.ActiveState == LS_TURN_LEFT_FAST ||
				nativeItem.Animation.ActiveState == LS_TURN_RIGHT_FAST ||
				nativeItem.Animation.ActiveState == LS_TURN_LEFT_SLOW ||
				nativeItem.Animation.ActiveState == LS_TURN_RIGHT_SLOW)
			{
				return true;
			}

			return false;
		}
	}
	break;

	default:
		return false;
		break;
	}
}

void Renderer::UpdateLaraAnimations(bool force)
{
	auto& rItem = _items[LaraItem->Index];
	rItem.ItemNumber = LaraItem->Index;

	if (!force && rItem.DoneAnimations)
		return;

	if (_moveableObjects.empty())
		return;

	auto& playerObject = *_moveableObjects[ID_LARA];

	// Clear extra rotations.
	for (auto& bone : playerObject.LinearizedBones)
		bone->ExtraRotation = Quaternion::Identity;

	// Set player world matrix.
	_playerWorldMatrix = LaraItem->Pose.ToMatrix();
	rItem.World = _playerWorldMatrix;

	// Update extra head and torso rotations.
	playerObject.LinearizedBones[LM_TORSO]->ExtraRotation = Lara.ExtraTorsoRot.ToQuaternion();
	playerObject.LinearizedBones[LM_HEAD]->ExtraRotation = Lara.ExtraHeadRot.ToQuaternion();

	// First calculate matrices for legs, hips, head, and torso.
	int mask = MESH_BITS(LM_HIPS) | MESH_BITS(LM_LTHIGH) | MESH_BITS(LM_LSHIN) | MESH_BITS(LM_LFOOT) | MESH_BITS(LM_RTHIGH) | MESH_BITS(LM_RSHIN) | MESH_BITS(LM_RFOOT) | MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);
	
	auto frameData = GetFrameInterpData(*LaraItem);
	UpdateAnimation(&rItem, playerObject, frameData, mask);

	auto gunType = Lara.Control.Weapon.GunType;
	auto handStatus = Lara.Control.HandStatus;

	// HACK: Treat binoculars as two-handed weapon.
	if (Lara.Control.Look.IsUsingBinoculars)
	{
		gunType = LaraWeaponType::Shotgun;
		handStatus = HandStatus::WeaponReady;
	}

	// Then the arms, based on current weapon status.
	if (gunType != LaraWeaponType::Flare && (handStatus == HandStatus::Free || handStatus == HandStatus::Busy) ||
		gunType == LaraWeaponType::Flare && !Lara.Flare.ControlLeft)
	{
		// Both arms
		mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND) | MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
		auto frameData = GetFrameInterpData(*LaraItem);
		UpdateAnimation(&rItem, playerObject, frameData, mask);
	}
	else
	{
		// While handling weapon, extra rotation may be applied to arms.
		if (gunType == LaraWeaponType::Revolver)
		{
			playerObject.LinearizedBones[LM_LINARM]->ExtraRotation =
			playerObject.LinearizedBones[LM_RINARM]->ExtraRotation *= Lara.RightArm.Orientation.ToQuaternion();
		}
		else
		{
			playerObject.LinearizedBones[LM_LINARM]->ExtraRotation *= Lara.LeftArm.Orientation.ToQuaternion();
			playerObject.LinearizedBones[LM_RINARM]->ExtraRotation *= Lara.RightArm.Orientation.ToQuaternion();
		}

		ArmInfo* leftArm = &Lara.LeftArm;
		ArmInfo* rightArm = &Lara.RightArm;

		// HACK: Treat revolver as pistols in crouched state.
		if (IsCrouching(LaraItem) && gunType == LaraWeaponType::Revolver)
			gunType = LaraWeaponType::Pistol;

		// HACK: Back guns are handled differently.
		switch (gunType)
		{
		case LaraWeaponType::Shotgun:
		case LaraWeaponType::HK:
		case LaraWeaponType::Crossbow:
		case LaraWeaponType::GrenadeLauncher:
		case LaraWeaponType::RocketLauncher:
		case LaraWeaponType::HarpoonGun:
		{
			// Left arm
			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);

			if (ShouldAnimateUpperBody(gunType))
				mask |= MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);

			auto shotgunFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber],
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber],
				0.0f
			};

			UpdateAnimation(&rItem, playerObject, shotgunFrameData, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			if (ShouldAnimateUpperBody(Lara.Control.Weapon.GunType))
				mask |= MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);

			shotgunFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber],
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber],
				0.0f
			};

			UpdateAnimation(&rItem, playerObject, shotgunFrameData, mask);
		}

		break;

		case LaraWeaponType::Revolver:
		{
			// Left arm
			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);
			auto revolverFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - GetAnimData(Lara.LeftArm.AnimNumber).frameBase],
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - GetAnimData(Lara.LeftArm.AnimNumber).frameBase],
				0.0f
			};

			UpdateAnimation(&rItem, playerObject, revolverFrameData, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			revolverFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - GetAnimData(Lara.RightArm.AnimNumber).frameBase],
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - GetAnimData(Lara.RightArm.AnimNumber).frameBase],
				0.0f
			};

			UpdateAnimation(&rItem, playerObject, revolverFrameData, mask);
		}

		break;

		case LaraWeaponType::Pistol:
		case LaraWeaponType::Uzi:
		default:
		{
			// Left arm
			int upperArmMask = MESH_BITS(LM_LINARM);
			mask = MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);
			auto pistolFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - GetAnimData(Lara.LeftArm.AnimNumber).frameBase],
				&g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - GetAnimData(Lara.LeftArm.AnimNumber).frameBase],
				0.0f
			};

			UpdateAnimation(&rItem, playerObject, pistolFrameData, upperArmMask, true);
			UpdateAnimation(&rItem, playerObject, pistolFrameData, mask);

			// Right arm
			upperArmMask = MESH_BITS(LM_RINARM);
			mask = MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			pistolFrameData = AnimFrameInterpData
			{
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - GetAnimData(Lara.RightArm.AnimNumber).frameBase],
				&g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - GetAnimData(Lara.RightArm.AnimNumber).frameBase],
				0.0f
			};
			
			UpdateAnimation(&rItem, playerObject, pistolFrameData, upperArmMask, true);
			UpdateAnimation(&rItem, playerObject, pistolFrameData, mask);
		}

		break;

		case LaraWeaponType::Flare:
		case LaraWeaponType::Torch:
			// Left arm
			ItemInfo tempItem;
			tempItem.Animation.AnimNumber = Lara.LeftArm.AnimNumber;
			tempItem.Animation.FrameNumber = Lara.LeftArm.FrameNumber;

			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);

			// HACK: Mask head and torso when taking out a flare.
			if (!Lara.Control.IsLow &&
				tempItem.Animation.AnimNumber > (Objects[ID_FLARE_ANIM].animIndex + 1) &&
				tempItem.Animation.AnimNumber < (Objects[ID_FLARE_ANIM].animIndex + 4))
			{
				mask |= MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);
			}

			auto frameData = GetFrameInterpData(tempItem);
			UpdateAnimation(&rItem, playerObject, frameData, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			frameData = GetFrameInterpData(*LaraItem);
			UpdateAnimation(&rItem, playerObject, frameData, mask);
			break;
		}
	}

	// Copy matrices in player object.
	for (int m = 0; m < NUM_LARA_MESHES; m++)
		playerObject.AnimationTransforms[m] = rItem.AnimTransforms[m];

	// Copy meshswap indices.
	rItem.SkinIndex = LaraItem->Model.SkinIndex;
	rItem.MeshIndex = LaraItem->Model.MeshIndex;
	rItem.DoneAnimations = true;
}

void Renderer::DrawLara(RenderView& view, RendererPass rendererPass)
{
	// TODO: Avoid Lara global.
	// Don't draw player if using optics (but still draw reflections).
	if (Lara.Control.Look.OpticRange != 0 && _currentMirror == nullptr)
		return;

	auto* item = &_items[LaraItem->Index];
	auto* nativeItem = &g_Level.Items[item->ItemNumber];

	if (nativeItem->Flags & IFLAG_INVISIBLE)
		return;

	unsigned int stride = sizeof(Vertex);
	unsigned int offset = 0;

	_context->IASetVertexBuffers(0, 1, _moveablesVertexBuffer.Buffer.GetAddressOf(), &stride, &offset);
	_context->IASetIndexBuffer(_moveablesIndexBuffer.Buffer.Get(), DXGI_FORMAT_R32_UINT, 0);

	auto& laraObj = *_moveableObjects[ID_LARA];
	auto skinMode = GetSkinningMode(laraObj, item->SkinIndex);

	RendererRoom* room = &_rooms[LaraItem->RoomNumber];

	_stItem.World = item->InterpolatedWorld;
	ReflectMatrixOptionally(_stItem.World);

	_stItem.Color = item->Color;
	_stItem.AmbientLight = item->AmbientLight;
	_stItem.Skinned = (int)skinMode;

	for (int k = 0; k < item->MeshIndex.size(); k++)
		_stItem.BoneLightModes[k] = (int)GetMesh(item->MeshIndex[k])->LightMode;

	bool acceptsShadows = laraObj.ShadowType == ShadowMode::None;
	BindMoveableLights(item->LightsToDraw, item->RoomNumber, item->PrevRoomNumber, item->LightFade, acceptsShadows);

	if (skinMode == SkinningMode::Full)
	{
		for (int m = 0; m < laraObj.AnimationTransforms.size(); m++)
			_stItem.BonesMatrices[m] =  laraObj.BindPoseTransforms[m] * item->InterpolatedAnimTransforms[m];
		_cbItem.UpdateData(_stItem, _context.Get());

		DrawMesh(item, GetMesh(item->SkinIndex), RendererObjectType::Moveable, 0, true, view, rendererPass);
	}

	memcpy(_stItem.BonesMatrices, item->InterpolatedAnimTransforms, laraObj.AnimationTransforms.size() * sizeof(Matrix));
	_cbItem.UpdateData(_stItem, _context.Get());

	for (int k = 0; k < item->MeshIndex.size(); k++)
	{
		if (!nativeItem->MeshBits.Test(k))
			continue;

		if (skinMode == SkinningMode::Full && g_Level.Meshes[nativeItem->Model.MeshIndex[k]].hidden)
			continue;

		DrawMesh(item, GetMesh(item->MeshIndex[k]), RendererObjectType::Moveable, k, false, view, rendererPass);
	}

	if (skinMode == SkinningMode::Classic)
		DrawLaraJoints(item, room, view, rendererPass);

	DrawLaraHolsters(item, room, view, rendererPass);
	DrawLaraHair(item, room, view, rendererPass);
}

void Renderer::DrawLaraHair(RendererItem* itemToDraw, RendererRoom* room, RenderView& view, RendererPass rendererPass)
{
	bool forceValue = g_GameFlow->CurrentFreezeMode == FreezeMode::Player;

	for (int i = 0; i < HairEffect.Units.size(); i++)
	{
		auto& unit = HairEffect.Units[i];
		if (!unit.IsEnabled)
			continue;

		const auto& object = Objects[unit.ObjectID];
		if (!object.loaded)
			continue;

		bool skinned = object.skinIndex != NO_VALUE && g_GameFlow->GetSettings()->Graphics.Skinning;
		bool flipped = skinned || (GetJointOffset(unit.ObjectID, 1).z < 0);
		auto objectType = i ? RendererObjectType::HairSecondary : RendererObjectType::HairPrimary;

		const auto& rendererObject = *_moveableObjects[unit.ObjectID];

		_stItem.World = Matrix::Identity;
		_stItem.BonesMatrices[0] = itemToDraw->InterpolatedAnimTransforms[HairUnit::GetRootMeshID(i)] * itemToDraw->InterpolatedWorld;
		_stItem.Skinned = (int)skinned;

		ReflectMatrixOptionally(_stItem.BonesMatrices[0]);

		for (int j = 0; j < unit.Segments.size(); j++)
		{
			auto& segment = unit.Segments[j];
			auto worldMatrix = 
				Matrix::CreateFromQuaternion(
					Quaternion::Lerp(segment.PrevOrientation, segment.Orientation, GetInterpolationFactor(forceValue))) *
				Matrix::CreateTranslation(
					Vector3::Lerp(segment.PrevPosition, segment.Position, GetInterpolationFactor(forceValue)));

			if (flipped)
				worldMatrix = Matrix::CreateRotationY(PI) * worldMatrix;

			ReflectMatrixOptionally(worldMatrix);
			_stItem.BonesMatrices[j + 1] = segment.GlobalTransform = worldMatrix;

			_stItem.BoneLightModes[j] = (int)LightMode::Dynamic;
		}

		_cbItem.UpdateData(_stItem, _context.Get());

		if (skinned)
		{
			DrawMesh(itemToDraw, GetMesh(object.skinIndex), objectType, 0, true, view, rendererPass);
		}
		else
		{
			for (int j = 0; j < rendererObject.ObjectMeshes.size(); j++)
			{
				auto& rendererMesh = *rendererObject.ObjectMeshes[j];
				DrawMesh(itemToDraw, &rendererMesh, objectType, j, false, view, rendererPass);
			}
		}
	}
}

void Renderer::DrawLaraJoints(RendererItem* itemToDraw, RendererRoom* room, RenderView& view, RendererPass rendererPass)
{
	if (!_moveableObjects[ID_LARA_SKIN_JOINTS].has_value())
		return;

	RendererObject& laraSkinJoints = *_moveableObjects[ID_LARA_SKIN_JOINTS];

	for (int k = 1; k < laraSkinJoints.ObjectMeshes.size(); k++)
	{
		RendererMesh* mesh = laraSkinJoints.ObjectMeshes[k];
		DrawMesh(itemToDraw, mesh, RendererObjectType::Moveable, k, false, view, rendererPass);
	}
}

void Renderer::DrawLaraHolsters(RendererItem* itemToDraw, RendererRoom* room, RenderView& view, RendererPass rendererPass)
{
	auto leftHolsterID  = Lara.Control.Weapon.HolsterInfo.LeftHolster;
	auto rightHolsterID = Lara.Control.Weapon.HolsterInfo.RightHolster;
	auto backHolsterID  = Lara.Control.Weapon.HolsterInfo.BackHolster;

	if (_moveableObjects[static_cast<int>(leftHolsterID)])
	{
		RendererObject& holsterSkin = *_moveableObjects[static_cast<int>(leftHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_LTHIGH];
		DrawMesh(itemToDraw, mesh, RendererObjectType::Moveable, LM_LTHIGH, false, view, rendererPass);
	}

	if (_moveableObjects[static_cast<int>(rightHolsterID)])
	{
		RendererObject& holsterSkin = *_moveableObjects[static_cast<int>(rightHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_RTHIGH];
		DrawMesh(itemToDraw, mesh, RendererObjectType::Moveable, LM_RTHIGH, false, view, rendererPass);
	}

	if (backHolsterID != HolsterSlot::Empty && _moveableObjects[static_cast<int>(backHolsterID)])
	{
		RendererObject& holsterSkin = *_moveableObjects[static_cast<int>(backHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_TORSO];
		DrawMesh(itemToDraw, mesh, RendererObjectType::Moveable, LM_TORSO, false, view, rendererPass);
	}
}
