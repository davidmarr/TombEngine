#pragma once

#include "Renderer/Graphics/ITexture2D.h"

namespace TEN::Renderer::Graphics
{
	class IRenderTarget2D : public ITexture2D
	{
	public:
		virtual int GetArraySize() = 0;
	};
}
