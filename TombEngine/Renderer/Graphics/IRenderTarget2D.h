#pragma once

#include "Renderer/Graphics/ITextureBase.h"

namespace TEN::Renderer::Graphics
{
	class IRenderTarget2D : public ITexture2D
	{
	public:
		virtual int GetArraySize() = 0;
	};
}
