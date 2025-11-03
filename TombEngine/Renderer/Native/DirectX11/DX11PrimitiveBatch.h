#pragma once
#include <d3d11.h>
#include <string>
#include <vector>
#include <memory>
#include <wrl/client.h>
#include "Renderer/RendererUtils.h"
#include "Renderer/Graphics/IPrimitiveBatch.h"
#include <PrimitiveBatch.h>

namespace TEN::Renderer::Native::DirectX11
{
	using namespace TEN::Renderer::Utils;
	using namespace TEN::Renderer::Graphics;
	using namespace DirectX;

	using Microsoft::WRL::ComPtr;

	template <typename TVertex>
	class DX11PrimitiveBatch : public IPrimitiveBatch<TVertex>
	{
	private:
		std::unique_ptr<PrimitiveBatch<TVertex>> _primitiveBatch;

	public:
		DX11PrimitiveBatch(ID3D11DeviceContext context)
		{
			_primitiveBatch = std::make_unique<PrimitiveBatch<TVertex>>(context);
		}

		void Begin() override { _primitiveBatch->Begin(); }
		void End() override { _primitiveBatch->End(); }
		void DrawLine(TVertex const& v1, TVertex const& v2) override { _primitiveBatch->DrawLine(v1, v2); }
		void DrawTriangle(TVertex const& v1, TVertex const& v2, TVertex const& v3) override { _primitiveBatch->DrawTriangle(v1, v2, v3); }
		void DrawQuad(TVertex const& v1, TVertex const& v2, TVertex const& v3, TVertex const& v4) override { _primitiveBatch->DrawQuad(v1, v2, v3, v4); }
	}; 
}