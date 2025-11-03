#pragma once

#include "Renderer/Graphics/ITextureBase.h"

namespace TEN::Renderer::Graphics
{
	class IRenderTarget2D : public ITextureBase
	{
	public:
		virtual int GetArraySize() = 0;
		//virtual SurfaceFormat GetColorFormat() = 0;
	};
}
