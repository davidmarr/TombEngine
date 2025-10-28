#pragma once

namespace TEN::Renderer::Graphics
{
	class ITextureBase
	{
	public:
		int Width;
		int Height;
		PixelFormat ColorFormat;
		PixelFormat DepthFormat;
	};
}
