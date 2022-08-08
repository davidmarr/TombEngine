#pragma once
#include <vector>
#include <SimpleMath.h>
#include "RendererPortal.h"

struct MESH_INFO;

namespace TEN::Renderer
{
	struct RendererItem;
	struct RendererBucket;
	struct RendererLight;
	struct RendererEffect;
	struct RendererTransparentFace;

	struct RendererRoom
	{
		int Distance;
		short RoomNumber;
		Vector4 AmbientLight;
		bool InDrawList;
		Vector4 ViewPort;
		std::vector<Vector4> ViewPorts;
		std::vector<RendererBucket> Buckets;
		std::vector<RendererLight> Lights;
		std::vector<RendererItem*> ItemsToDraw;
		std::vector<RendererEffect*> EffectsToDraw;
		std::vector<RendererStatic> StaticsToDraw;
		std::vector<RendererTransparentFace> TransparentFacesToDraw;
		std::vector<RendererPortal> Portals;
		std::vector<int> Neighbors;
	};
}
