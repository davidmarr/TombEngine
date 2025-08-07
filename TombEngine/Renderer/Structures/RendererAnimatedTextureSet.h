#pragma once
#include <vector>
#include "RendererAnimatedTexture.h"

namespace TEN::Renderer::Structures
{
	using namespace DirectX::SimpleMath;

	enum class UVRotateDirection
	{
		TopToBottom,
		RightToLeft,
		BottomToTop,
		LeftToRight
	};

	enum class AnimatedTextureType
	{
		Frames,
		UVRotate,
		Video
	};

	struct RendererAnimatedTextureSet
	{
		AnimatedTextureType Type = AnimatedTextureType::Frames;
		int NumTextures = 0;
		int Fps = 0;
		float UVRotateSpeed = 0.0f;
		UVRotateDirection UVRotateDirection;
		std::vector<RendererAnimatedTexture> Textures;
	};
}
