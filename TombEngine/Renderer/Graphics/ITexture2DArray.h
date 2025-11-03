#pragma once

#include "Renderer/Graphics/ITextureBase.h"

namespace TEN::Renderer::Graphics
{
	class ITexture2DArray : public ITextureBase
	{
	public:
		int Count;
	};
}
