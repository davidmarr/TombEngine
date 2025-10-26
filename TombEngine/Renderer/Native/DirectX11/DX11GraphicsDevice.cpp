#include "framework.h"
#include "Renderer/Native/DirectX11/DX11GraphicsDevice.h"

using namespace TEN::Renderer::Graphics;

namespace TEN::Renderer::Native::DirectX11
{
	IVertexBuffer* DX11GraphicsDevice::CreateVertexBuffer(int, int, void*) { return nullptr; }
	bool DX11GraphicsDevice::UpdateVertexBuffer(int, int, int, void*) { return false; }
	
	void DX11GraphicsDevice::BindVertexBuffer(IVertexBuffer* vertexBuffer) 
	{
		auto vb = static_cast<DX11VertexBuffer*>(vertexBuffer);

		unsigned int stride = vb->Stride;
		unsigned int offset = 0;

		_context->IASetVertexBuffers(0, 1, vb->Buffer.GetAddressOf(), &stride, &offset);
	}

	IIndexBuffer* DX11GraphicsDevice::CreateIndexBuffer(int, int*) { return nullptr; }
	IIndexBuffer* DX11GraphicsDevice::CreateIndexBuffer(int, int, int*) { return nullptr; }
	
	void DX11GraphicsDevice::BindIndexBuffer(IIndexBuffer* indexBuffer) 
	{
		auto ib = static_cast<DX11IndexBuffer*>(indexBuffer);
		_context->IASetIndexBuffer(ib->Buffer.Get(), DXGI_FORMAT_R32_UINT, 0);
	}

	IRenderTarget2D* DX11GraphicsDevice::CreateRenderTarget2D(int, int, ColorFormat, bool, ColorFormat) { return nullptr; }
	IRenderTarget2D* DX11GraphicsDevice::CreateRenderTarget2DFromAnother(IRenderTarget2D*, ColorFormat) { return nullptr; }
	IRenderTargetCube* DX11GraphicsDevice::CreateRenderTargetCube(int, ColorFormat, ColorFormat) { return nullptr; }

	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int, int, byte*) { return nullptr; }
	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int, int, ColorFormat, int, const void*) { return nullptr; }
	ITexture2D* DX11GraphicsDevice::CreateTexture2D(const std::wstring&) { return nullptr; }
	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int, byte*) { return nullptr; }
	ITexture2DArray* DX11GraphicsDevice::CreateTexture2DArray(int, int, ColorFormat, ColorFormat) { return nullptr; }

	void DX11GraphicsDevice::SetBlendMode(BlendMode blendMode)
	{
		switch (blendMode)
		{
		case BlendMode::AlphaBlend:
			_context->OMSetBlendState(_renderStates->NonPremultiplied(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::AlphaTest:
			_context->OMSetBlendState(_renderStates->Opaque(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Opaque:
			_context->OMSetBlendState(_renderStates->Opaque(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Subtractive:
			_context->OMSetBlendState(_subtractiveBlendState.Get(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Additive:
			_context->OMSetBlendState(_renderStates->Additive(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Screen:
			_context->OMSetBlendState(_screenBlendState.Get(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Lighten:
			_context->OMSetBlendState(_lightenBlendState.Get(), nullptr, 0xFFFFFFFF);
			break;

		case BlendMode::Exclude:
			_context->OMSetBlendState(_excludeBlendState.Get(), nullptr, 0xFFFFFFFF);
			break;
		}
	}

	void DX11GraphicsDevice::SetDepthState(DepthState depthState) 
	{
		switch (depthState)
		{
		case DepthState::Read:
			_context->OMSetDepthStencilState(_renderStates->DepthRead(), 0xFFFFFFFF);
			break;

		case DepthState::Write:
			_context->OMSetDepthStencilState(_renderStates->DepthDefault(), 0xFFFFFFFF);
			break;

		case DepthState::None:
			_context->OMSetDepthStencilState(_renderStates->DepthNone(), 0xFFFFFFFF);
			break;

		}
	}

	void DX11GraphicsDevice::SetCullMode(CullMode cullMode) 
	{
		switch (cullMode)
		{
		case CullMode::None:
			_context->RSSetState(_cullNoneRasterizerState.Get());
			break;

		case CullMode::CounterClockwise:
			_context->RSSetState(_cullCounterClockwiseRasterizerState.Get());
			break;

		case CullMode::Clockwise:
			_context->RSSetState(_cullClockwiseRasterizerState.Get());
			break;

		case CullMode::Wireframe:
			_context->RSSetState(_renderStates->Wireframe());
			break;

		}
	}

	void DX11GraphicsDevice::SetScissor(RendererRectangle rectangle)
	{
		D3D11_RECT rects;
		rects.left = rectangle.Left;
		rects.top = rectangle.Top;
		rects.right = rectangle.Right;
		rects.bottom = rectangle.Bottom;

		_context->RSSetScissorRects(1, &rects);
	}

	void DX11GraphicsDevice::BindTexture(TextureRegister, ITextureBase*, SamplerStateRegister) {}
	void DX11GraphicsDevice::BindRenderTargetAsTexture(TextureRegister, IRenderTarget2D*, SamplerStateRegister) {}
	void DX11GraphicsDevice::BindConstantBufferVS(ConstantBufferRegister, IConstantBuffer*) {}
	void DX11GraphicsDevice::BindConstantBufferPS(ConstantBufferRegister, IConstantBuffer*) {}

	void DX11GraphicsDevice::DrawIndexedTriangles(int count, int baseIndex, int baseVertex)
	{
		_context->DrawIndexed(count, baseIndex, baseVertex);
	}

	void DX11GraphicsDevice::DrawIndexedInstancedTriangles(int count, int instances, int baseIndex, int baseVertex)
	{
		_context->DrawIndexedInstanced(count, instances, baseIndex, baseVertex, 0);
	}

	void DX11GraphicsDevice::DrawInstancedTriangles(int count, int instances, int baseVertex)
	{
		_context->DrawInstanced(count, instances, baseVertex, 0);
	}

	void DX11GraphicsDevice::DrawTriangles(int count, int baseVertex)
	{
		_context->Draw(count, baseVertex);
	}

	void DX11GraphicsDevice::ClearRenderTarget2D(IRenderTarget2D*, DirectX::XMFLOAT4) {}
	void DX11GraphicsDevice::ClearRenderTarget2DOfArray(ITexture2DArray*, int, DirectX::XMFLOAT4) {}
	void DX11GraphicsDevice::ClearRenderTarget2DOfCube(IRenderTargetCube*, int, DirectX::XMFLOAT4) {}

	void DX11GraphicsDevice::ClearDepthStencil(IRenderTarget2D*, float, unsigned char) {}
	void DX11GraphicsDevice::ClearDepthStencilOfArray(ITexture2DArray*, int, float, unsigned char) {}
	void DX11GraphicsDevice::ClearDepthStencilOfCube(IRenderTargetCube*, int, float, unsigned char) {}

	void DX11GraphicsDevice::SetViewport(RendererViewport viewport)
	{
		D3D11_VIEWPORT dxViewport;
		dxViewport.TopLeftX = viewport.X;
		dxViewport.TopLeftY = viewport.Y;
		dxViewport.Width = viewport.Width;
		dxViewport.Height = viewport.Height;
		dxViewport.MinDepth = viewport.MinDepth;
		dxViewport.MaxDepth = viewport.MaxDepth;

		_context->RSSetViewports(1, &dxViewport);

		D3D11_RECT rects[1];
		rects[0].left = dxViewport.TopLeftX;
		rects[0].right = dxViewport.Width;
		rects[0].top = dxViewport.TopLeftY;
		rects[0].bottom = dxViewport.Height;

		_context->RSSetScissorRects(1, rects);
	}

	void DX11GraphicsDevice::SetInputLayout(InputLayout inputLayout)
	{
		switch (inputLayout)
		{
		case InputLayout::Vertex:
			_context->IASetInputLayout(_inputLayout.Get());
			break;

		case InputLayout::PostProcessVertex:
			_context->IASetInputLayout(_fullscreenTriangleInputLayout.Get());
			break;

		}
	}

	void DX11GraphicsDevice::SetPrimitiveType(PrimitiveType primitiveType)
	{
		switch (primitiveType)
		{
		case PrimitiveType::TriangleList:
			_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST); 
			break;

		case PrimitiveType::TriangleStrip:
			_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
			break;

		case PrimitiveType::LineList:
			_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_LINELIST);
			break;
		}
	}

	void DX11GraphicsDevice::Initialize(const std::string&, int, int, bool, HWND) {}
}