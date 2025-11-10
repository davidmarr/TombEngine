#include "framework.h"
#include "Renderer/Native/DirectX11/DX11GraphicsDevice.h"
#include "Specific/winmain.h"
#include "Specific/configuration.h"
#include "Specific/trutils.h"
#include <wincodec.h>
#include <ScreenGrab.h>
#include <algorithm>
#include <ctime>
#include <filesystem>

extern GameConfiguration g_Configuration;

using namespace TEN::Renderer::Graphics;

namespace TEN::Renderer::Native::DirectX11
{
	IVertexBuffer* DX11GraphicsDevice::CreateVertexBuffer(int numVertices, int vertexSize, void* data)
	{
		return new DX11VertexBuffer(_device.Get(), numVertices, vertexSize, data);
	}

	void DX11GraphicsDevice::UpdateVertexBuffer(IVertexBuffer* vertexBuffer, int startVertex, int count, void* data)
	{
		auto vb = static_cast<DX11VertexBuffer*>(vertexBuffer);
		vb->Update(_context.Get(), data, startVertex, count);
	}

	void DX11GraphicsDevice::BindVertexBuffer(IVertexBuffer* vertexBuffer)
	{
		auto vb = static_cast<DX11VertexBuffer*>(vertexBuffer);

		unsigned int stride = vb->Stride;
		unsigned int offset = 0;

		_context->IASetVertexBuffers(0, 1, vb->Buffer.GetAddressOf(), &stride, &offset);
	}

	IIndexBuffer* DX11GraphicsDevice::CreateIndexBuffer(int numIndices, int* indices)
	{
		return new DX11IndexBuffer(_device.Get(), numIndices, indices);
	}

	void DX11GraphicsDevice::UpdateIndexBuffer(IIndexBuffer* indexBuffer, int numIndices, int startIndex, int* data)
	{
		auto ib = static_cast<DX11IndexBuffer*>(indexBuffer);
		ib->Update(_context.Get(), data, startIndex, numIndices);
	}

	void DX11GraphicsDevice::BindIndexBuffer(IIndexBuffer* indexBuffer)
	{
		auto ib = static_cast<DX11IndexBuffer*>(indexBuffer);
		_context->IASetIndexBuffer(ib->Buffer.Get(), DXGI_FORMAT_R32_UINT, 0);
	}

	IRenderSurface2D* DX11GraphicsDevice::CreateRenderSurface2D(int width, int height, SurfaceFormat colorFormat, bool isTypeless, DepthFormat depthFormat)
	{
		IRenderTarget2D* renderTarget = new DX11RenderTarget2D(_device.Get(), width, height, GetDXGIFormat(colorFormat), isTypeless);
		
		IDepthTarget* depthTarget = nullptr;
		if (depthFormat != DepthFormat::None)
			depthTarget = new DX11DepthTarget(_device.Get(), width, height, GetDXGIFormat(depthFormat));
	
		return new IRenderSurface2D(renderTarget, depthTarget);
	}

	IRenderSurface2D* DX11GraphicsDevice::CreateRenderSurface2D(int width, int height, int arraySize, SurfaceFormat colorFormat, DepthFormat depthFormat)
	{
		IRenderTarget2D* renderTarget = new DX11RenderTarget2D(_device.Get(), width, height, arraySize, GetDXGIFormat(colorFormat));

		IDepthTarget* depthTarget = nullptr;
		if (depthFormat != DepthFormat::None)
			depthTarget = new DX11DepthTarget(_device.Get(), width, height, arraySize, GetDXGIFormat(depthFormat));

		return new IRenderSurface2D(renderTarget, depthTarget);
	}

	IRenderSurface2D* DX11GraphicsDevice::CreateRenderSurface2D(IRenderSurface2D* parentRenderTarget, SurfaceFormat colorFormat)
	{
		return new IRenderSurface2D(
			new DX11RenderTarget2D(_device.Get(), static_cast<DX11RenderTarget2D*>(parentRenderTarget->GetRenderTarget()), GetDXGIFormat(colorFormat)),
			parentRenderTarget->GetDepthTarget()
		);
	}

	IRenderTargetCube* DX11GraphicsDevice::CreateRenderTargetCube(int size, SurfaceFormat colorFormat)
	{
		return nullptr; // new DX11RenderTargetCube(_device.Get(), size, GetDXGIFormat(colorFormat), GetDXGIFormat(depthFormat));
	}

	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int width, int height, byte* data)
	{
		return new DX11Texture2D(_device.Get(), width, height, data);
	}

	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int width, int height, SurfaceFormat format, int pitch, const void* data)
	{
		return new DX11Texture2D(_device.Get(), width, height, GetDXGIFormat(format), pitch, data);
	}

	ITexture2D* DX11GraphicsDevice::CreateTexture2D(const std::string fileName)
	{
		return new DX11Texture2D(_device.Get(), TEN::Utils::ToWString(fileName));
	}

	ITexture2D* DX11GraphicsDevice::CreateTexture2D(int dataSize, byte* data)
	{
		return new DX11Texture2D(_device.Get(), data, dataSize);
	}

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

	void DX11GraphicsDevice::BindTexture(TextureRegister registerType, ITextureBase* texture, SamplerStateRegister samplerType)
	{
		auto nativeTexture = static_cast<DX11TextureBase*>(texture);
		auto dxTexture = nativeTexture->GetShaderResourceView();

		_context->PSSetShaderResources((unsigned int)registerType, 1, &dxTexture);

		ID3D11SamplerState* samplerState = nullptr;
		switch (samplerType)
		{
		case SamplerStateRegister::AnisotropicClamp:
			samplerState = _renderStates->AnisotropicClamp();
			break;

		case SamplerStateRegister::AnisotropicWrap:
			samplerState = _renderStates->AnisotropicWrap();
			break;

		case SamplerStateRegister::LinearClamp:
			samplerState = _renderStates->LinearClamp();
			break;

		case SamplerStateRegister::LinearWrap:
			samplerState = _renderStates->LinearWrap();
			break;

		case SamplerStateRegister::PointWrap:
			samplerState = _pointWrapSamplerState.Get();
			break;

		case SamplerStateRegister::ShadowMap:
			samplerState = _shadowSampler.Get();
			break;

		default:
			return;
		}

		_context->PSSetSamplers((unsigned int)registerType, 1, &samplerState);
	}

	void DX11GraphicsDevice::BindConstantBufferVS(ConstantBufferRegister constantBufferType, IConstantBuffer* constantBuffer)
	{
		auto nativeBuffer = static_cast<DX11ConstantBuffer*>(constantBuffer);
		_context->VSSetConstantBuffers(static_cast<unsigned int>(constantBufferType), 1, nativeBuffer->Get());
	}

	void DX11GraphicsDevice::BindConstantBufferPS(ConstantBufferRegister constantBufferType, IConstantBuffer* constantBuffer)
	{
		auto nativeBuffer = static_cast<DX11ConstantBuffer*>(constantBuffer);
		_context->PSSetConstantBuffers(static_cast<unsigned int>(constantBufferType), 1, nativeBuffer->Get());
	}

	IConstantBuffer* DX11GraphicsDevice::CreateConstantBuffer(int size, std::wstring name)
	{
		return new DX11ConstantBuffer(_device.Get(), size, name);
	}

	void DX11GraphicsDevice::UpdateConstantBuffer(IConstantBuffer* constantBuffer, void* data)
	{
		auto nativeBuffer = static_cast<DX11ConstantBuffer*>(constantBuffer);
		nativeBuffer->UpdateData(data, _context.Get());
	}

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

	void DX11GraphicsDevice::ClearRenderTarget2D(IRenderTarget2D* renderTarget, XMVECTORF32 clearColor)
	{
		auto nativeRenderTarget = static_cast<DX11RenderTarget2D*>(renderTarget);
		_context->ClearRenderTargetView(nativeRenderTarget->GetRenderTargetView(), clearColor);
	}

	void DX11GraphicsDevice::ClearRenderTarget2D(IRenderTarget2D* renderTarget, int arrayIndex, XMVECTORF32 clearColor)
	{
		auto nativeRenderTarget = static_cast<DX11RenderTarget2D*>(renderTarget);
		_context->ClearRenderTargetView(nativeRenderTarget->GetRenderTargetView(arrayIndex), clearColor);
	}

	void DX11GraphicsDevice::ClearDepthStencil(IDepthTarget* renderTarget, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil)
	{
		auto nativeRenderTarget = static_cast<DX11DepthTarget*>(renderTarget);
		_context->ClearDepthStencilView(nativeRenderTarget->GetDepthStencilView(), GetClearFlags(clearFlags), depth, stencil);
	}

	void DX11GraphicsDevice::ClearDepthStencil(IDepthTarget* renderTarget, int arrayIndex, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil)
	{
		auto nativeRenderTarget = static_cast<DX11DepthTarget*>(renderTarget);
		_context->ClearDepthStencilView(nativeRenderTarget->GetDepthStencilView(arrayIndex), GetClearFlags(clearFlags), depth, stencil);
	}

	void DX11GraphicsDevice::BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget)
	{
		auto dxRt = static_cast<DX11RenderTarget2D*>(renderTarget);
		auto rtv = dxRt->GetRenderTargetView();

		ID3D11DepthStencilView* dsv = nullptr;
		if (depthTarget != nullptr)
		{
			auto dxDsvRt = static_cast<DX11DepthTarget*>(depthTarget);
			dsv = dxDsvRt->GetDepthStencilView();
		}
				
		_context->OMSetRenderTargets(1, &rtv, dsv);
	}

	void DX11GraphicsDevice::BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget, int arrayIndex)
	{
		auto dxRt = static_cast<DX11RenderTarget2D*>(renderTarget);
		auto rtv = dxRt->GetRenderTargetView(arrayIndex);

		ID3D11DepthStencilView* dsv = nullptr;
		if (depthTarget != nullptr)
		{
			auto dxDsvRt = static_cast<DX11DepthTarget*>(depthTarget);
			dsv = dxDsvRt->GetDepthStencilView(arrayIndex);
		}

		_context->OMSetRenderTargets(1, &rtv, dsv);
	}

	void DX11GraphicsDevice::BindRenderTargets(std::vector<IRenderTarget2D*> renderTargets, IDepthTarget* depthTarget)
	{
		std::vector<ID3D11RenderTargetView*> rtvList;
		for (int i = 0; i < renderTargets.size(); i++)
		{
			auto rt = renderTargets[i];
			auto dxRt = static_cast<DX11RenderTarget2D*>(rt);
			auto rtv = dxRt->GetRenderTargetView(i);
			rtvList.push_back(rtv);
		}

		ID3D11DepthStencilView* dsv = nullptr;
		if (depthTarget != nullptr)
		{
			auto dxRt = static_cast<DX11DepthTarget*>(depthTarget);
			dsv = dxRt->GetDepthStencilView();
		}

		_context->OMSetRenderTargets(rtvList.size(), rtvList.data(), dsv);
	}

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

	void DX11GraphicsDevice::SetInputLayout(IInputLayout* inputLayout)
	{
		auto dxInputLayout = static_cast<DX11InputLayout*>(inputLayout);
		_context->IASetInputLayout(dxInputLayout->InputLayout.Get());
	}

	IInputLayout* DX11GraphicsDevice::CreateInputLayout(std::vector<RendererInputLayoutField> fields, IShader* shader)
	{
		auto dxShader = static_cast<DX11Shader*>(shader);
		return new DX11InputLayout(_device.Get(), fields, dxShader);
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

	void DX11GraphicsDevice::Initialize(const std::string gameDir, int w, int h, bool windowed, HWND handle)
	{
		_renderStates = std::make_unique<CommonStates>(_device.Get());

		D3D11_BLEND_DESC blendStateDesc{};
		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = false;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_REV_SUBTRACT;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _subtractiveBlendState.GetAddressOf()));

		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = false;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_COLOR;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _screenBlendState.GetAddressOf()));

		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = false;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_MAX;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_DEST_ALPHA;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _lightenBlendState.GetAddressOf()));

		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = false;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_INV_DEST_COLOR;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_COLOR;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_ZERO;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _excludeBlendState.GetAddressOf()));

		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = true;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_ONE;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		blendStateDesc.RenderTarget[1].BlendEnable = true;
		blendStateDesc.RenderTarget[1].SrcBlend = D3D11_BLEND_ZERO;
		blendStateDesc.RenderTarget[1].DestBlend = D3D11_BLEND_INV_SRC_COLOR;
		blendStateDesc.RenderTarget[1].BlendOp = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[1].SrcBlendAlpha = D3D11_BLEND_ZERO;
		blendStateDesc.RenderTarget[1].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
		blendStateDesc.RenderTarget[1].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[1].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_RED;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _transparencyBlendState.GetAddressOf()));

		blendStateDesc.AlphaToCoverageEnable = false;
		blendStateDesc.IndependentBlendEnable = false;
		blendStateDesc.RenderTarget[0].BlendEnable = true;
		blendStateDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_INV_SRC_ALPHA;
		blendStateDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
		blendStateDesc.RenderTarget[0].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
		Utils::throwIfFailed(_device->CreateBlendState(&blendStateDesc, _finalTransparencyBlendState.GetAddressOf()));

		D3D11_SAMPLER_DESC shadowSamplerDesc = {};
		shadowSamplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
		shadowSamplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
		shadowSamplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
		shadowSamplerDesc.ComparisonFunc = D3D11_COMPARISON_LESS_EQUAL;
		shadowSamplerDesc.Filter = D3D11_FILTER_COMPARISON_MIN_MAG_LINEAR_MIP_POINT;
		Utils::throwIfFailed(_device->CreateSamplerState(&shadowSamplerDesc, _shadowSampler.GetAddressOf()));
		_shadowSampler->SetPrivateData(WKPDID_D3DDebugObjectName, sizeof("ShadowSampler") - 1, "ShadowSampler");

		D3D11_RASTERIZER_DESC rasterizerStateDesc = {};

		rasterizerStateDesc.CullMode = D3D11_CULL_BACK;
		rasterizerStateDesc.FillMode = D3D11_FILL_SOLID;
		rasterizerStateDesc.DepthClipEnable = true;
		rasterizerStateDesc.MultisampleEnable = true;
		rasterizerStateDesc.AntialiasedLineEnable = true;
		rasterizerStateDesc.ScissorEnable = true;
		Utils::throwIfFailed(_device->CreateRasterizerState(&rasterizerStateDesc, _cullCounterClockwiseRasterizerState.GetAddressOf()));

		rasterizerStateDesc.CullMode = D3D11_CULL_FRONT;
		rasterizerStateDesc.FillMode = D3D11_FILL_SOLID;
		rasterizerStateDesc.DepthClipEnable = true;
		rasterizerStateDesc.MultisampleEnable = true;
		rasterizerStateDesc.AntialiasedLineEnable = true;
		rasterizerStateDesc.ScissorEnable = true;
		Utils::throwIfFailed(_device->CreateRasterizerState(&rasterizerStateDesc, _cullClockwiseRasterizerState.GetAddressOf()));

		rasterizerStateDesc.CullMode = D3D11_CULL_NONE;
		rasterizerStateDesc.FillMode = D3D11_FILL_SOLID;
		rasterizerStateDesc.DepthClipEnable = true;
		rasterizerStateDesc.MultisampleEnable = true;
		rasterizerStateDesc.AntialiasedLineEnable = true;
		rasterizerStateDesc.ScissorEnable = true;
		Utils::throwIfFailed(_device->CreateRasterizerState(&rasterizerStateDesc, _cullNoneRasterizerState.GetAddressOf()));

		D3D11_SAMPLER_DESC samplerStateDesc = {};
		samplerStateDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
		samplerStateDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
		samplerStateDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
		samplerStateDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
		samplerStateDesc.MinLOD = 0;
		samplerStateDesc.MaxLOD = 0;
		samplerStateDesc.MipLODBias = 0;
		samplerStateDesc.ComparisonFunc = D3D11_COMPARISON_NEVER;
		samplerStateDesc.MaxAnisotropy = 1;
		Utils::throwIfFailed(_device->CreateSamplerState(&samplerStateDesc, _pointWrapSamplerState.GetAddressOf()));

		// TODO: it was in initializescreen maybe move them
		_spriteBatch = std::make_unique<SpriteBatch>(_context.Get());
		_primitiveBatch = std::make_unique<PrimitiveBatch<Vertex>>(_context.Get());

		_viewportToolkit = Viewport(0, 0, w, h, 0.0f, 1.0f);
	}

	IRenderSurface2D* DX11GraphicsDevice::InitializeSwapChain(int width, int height, HWND handle)
	{
		DXGI_SWAP_CHAIN_DESC sd;
		sd.BufferDesc.Width = width;
		sd.BufferDesc.Height = height;
		if (!g_Configuration.EnableHighFramerate)
		{
			_refreshRate = 30;

			sd.BufferDesc.RefreshRate.Numerator = 0;
			sd.BufferDesc.RefreshRate.Denominator = 0;
		}
		else
		{
			_refreshRate = GetCurrentScreenRefreshRate();
			if (_refreshRate == 0)
			{
				_refreshRate = 60;
			}

			sd.BufferDesc.RefreshRate.Numerator = _refreshRate;
			sd.BufferDesc.RefreshRate.Denominator = 1;
		}
		sd.BufferDesc.RefreshRate.Numerator = 60;
		sd.BufferDesc.RefreshRate.Denominator = 1;
		sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		sd.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
		sd.BufferDesc.Scaling = DXGI_MODE_SCALING_STRETCHED;
		sd.Windowed = true;
		sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
		sd.Flags = 0;
		sd.OutputWindow = handle;
		sd.SampleDesc.Count = 1;
		sd.SampleDesc.Quality = 0;
		sd.BufferCount = 1;
		sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
		ComPtr<IDXGIDevice> dxgiDevice;
		Utils::throwIfFailed(_device.As(&dxgiDevice));

		ComPtr<IDXGIAdapter> dxgiAdapter;
		Utils::throwIfFailed(dxgiDevice->GetParent(__uuidof(IDXGIAdapter), &dxgiAdapter));

		ComPtr<IDXGIFactory> dxgiFactory;
		Utils::throwIfFailed(dxgiAdapter->GetParent(__uuidof(IDXGIFactory), &dxgiFactory));

		Utils::throwIfFailed(dxgiFactory->CreateSwapChain(_device.Get(), &sd, &_swapChain));

		dxgiFactory->MakeWindowAssociation(handle, DXGI_MWA_NO_ALT_ENTER);

		// Initialize render targets
		ID3D11Texture2D* backBufferTexture = NULL;
		Utils::throwIfFailed(_swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), reinterpret_cast <void**>(&backBufferTexture)));

		return new IRenderSurface2D(
			new DX11RenderTarget2D(_device.Get(), backBufferTexture),
			new DX11DepthTarget(_device.Get(), width, height, DXGI_FORMAT_D32_FLOAT));
	}

	void DX11GraphicsDevice::CreateDevice()
	{
		TENLog("Creating DX11 renderer device...", LogLevel::Info);

		D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0 };
		D3D_FEATURE_LEVEL featureLevel;
		HRESULT res;

		if constexpr (DEBUG_BUILD)
		{
			res = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, D3D11_CREATE_DEVICE_DEBUG,
				levels, 1, D3D11_SDK_VERSION, &_device, &featureLevel, &_context);
		}
		else
		{
			res = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, NULL,
				levels, 1, D3D11_SDK_VERSION, &_device, &featureLevel, &_context);
		}

		Utils::throwIfFailed(res);
	}

	std::string DX11GraphicsDevice::GetDefaultAdapterName()
	{
		IDXGIFactory* dxgiFactory = NULL;
		Utils::throwIfFailed(CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&dxgiFactory));

		IDXGIAdapter* dxgiAdapter = NULL;

		dxgiFactory->EnumAdapters(0, &dxgiAdapter);

		DXGI_ADAPTER_DESC adapterDesc = {};

		dxgiAdapter->GetDesc(&adapterDesc);
		dxgiFactory->Release();

		return TEN::Utils::ToString(adapterDesc.Description);
	}

	void DX11GraphicsDevice::ChangeScreenResolution(int width, int height, bool windowed)
	{
		ID3D11RenderTargetView* nullViews[] = { nullptr };
		_context->OMSetRenderTargets(0, nullViews, NULL);
		_context->Flush();
		_context->ClearState();

		IDXGIOutput* output;
		Utils::throwIfFailed(_swapChain->GetContainingOutput(&output));

		DXGI_SWAP_CHAIN_DESC scd;
		Utils::throwIfFailed(_swapChain->GetDesc(&scd));

		unsigned int numModes = 1024;
		DXGI_MODE_DESC modes[1024];
		Utils::throwIfFailed(output->GetDisplayModeList(scd.BufferDesc.Format, 0, &numModes, modes));

		DXGI_MODE_DESC* mode = &modes[0];
		for (unsigned int i = 0; i < numModes; i++)
		{
			mode = &modes[i];
			if (mode->Width == width && mode->Height == height)
				break;
		}

		Utils::throwIfFailed(_swapChain->ResizeTarget(mode));

		_screenWidth = width;
		_screenHeight = height;
		_isWindowed = windowed;
	}

	IShader* DX11GraphicsDevice::CreateShader(ShaderCompileRequest& req)
	{
		auto shader = new DX11Shader();

		// come nel tuo ShaderManager attuale
		auto baseFileName = TEN::Utils::ToWString(req.SourceDirectory + req.FileName);
		auto prefix = ((req.CompileIndex < 10) ? L"0" : L"") + std::to_wstring(req.CompileIndex) + L"_";

		// VS
		auto makeCsoName = [&](const std::string& shaderType) {
			return TEN::Utils::ToWString(req.BinaryDirectory) + prefix + TEN::Utils::ToWString(req.FileName) + L"." +
				std::wstring(shaderType.begin(), shaderType.end()) + L".cso";
			};

		auto macros = ToD3DMacros(req.Macros);

		auto compileOne = [&](const std::string& shaderType,
			const std::string& entry,
			const char* model,
			ComPtr<ID3D10Blob>& outBlob)
			{
				auto csoFileName = makeCsoName(shaderType);
				auto srcFileName = baseFileName;

				auto srcFileNameWithExt = srcFileName + L".hlsl";
				if (!std::filesystem::exists(srcFileNameWithExt))
				{
					srcFileNameWithExt = srcFileName + L".fx";
				}

				bool loadedFromDisk = false;
				if (!req.ForceRecompile && std::filesystem::exists(csoFileName))
				{
					auto csoTime = std::filesystem::last_write_time(csoFileName);
					auto srcTime = std::filesystem::last_write_time(srcFileNameWithExt);
					if (srcTime < csoTime)
					{
						std::ifstream ifs(csoFileName, std::ios::binary);
						if (ifs)
						{
							ifs.seekg(0, std::ios::end);
							auto size = ifs.tellg();
							ifs.seekg(0, std::ios::beg);
							std::vector<char> buf(size);
							ifs.read(buf.data(), size);
							D3DCreateBlob((SIZE_T)size, &outBlob);
							memcpy(outBlob->GetBufferPointer(), buf.data(), size);
							loadedFromDisk = true;
						}
					}
				}

				if (!loadedFromDisk)
				{
					UINT flags = D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_PACK_MATRIX_ROW_MAJOR;
#ifdef _DEBUG
					flags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#else
					flags |= D3DCOMPILE_OPTIMIZATION_LEVEL3 | D3DCOMPILE_IEEE_STRICTNESS;
#endif

					ComPtr<ID3D10Blob> errors;
					auto target = shaderType + entry;
					auto hr = D3DCompileFromFile(
						srcFileNameWithExt.c_str(),
						macros.data(),
						D3D_COMPILE_STANDARD_FILE_INCLUDE,
						target.c_str(),
						model,
						flags,
						0,
						&outBlob,
						&errors
					);
					if (FAILED(hr))
					{
						if (errors)
						{
							TENLog((const char*)errors->GetBufferPointer(), LogLevel::Error);
						}
						throwIfFailed(hr);
					}

					std::ofstream ofs(csoFileName, std::ios::binary);
					if (ofs)
					{
						ofs.write((const char*)outBlob->GetBufferPointer(), outBlob->GetBufferSize());
					}
				}
			};

		if (req.Type == ShaderType::Pixel || req.Type == ShaderType::PixelAndVertex)
		{
			compileOne("PS", req.EntryPoint, "ps_5_0", shader->Blob);
			ComPtr<ID3D11PixelShader> ps;
			throwIfFailed(_device->CreatePixelShader(shader->Blob->GetBufferPointer(),
				shader->Blob->GetBufferSize(),
				nullptr,
				&ps));
			shader->PixelShader = ps;
		}

		if (req.Type == ShaderType::Vertex || req.Type == ShaderType::PixelAndVertex)
		{
			ComPtr<ID3D10Blob> vsBlob;
			compileOne("VS", req.EntryPoint, "vs_5_0", vsBlob);
			ComPtr<ID3D11VertexShader> vs;
			throwIfFailed(_device->CreateVertexShader(vsBlob->GetBufferPointer(),
				vsBlob->GetBufferSize(),
				nullptr,
				&vs));
			shader->VertexShader = vs;
			shader->Blob = vsBlob;
		}

		if (req.Type == ShaderType::Compute)
		{
			ComPtr<ID3D10Blob> csBlob;
			compileOne("CS", req.EntryPoint, "cs_5_0", csBlob);
			ComPtr<ID3D11ComputeShader> cs;
			throwIfFailed(_device->CreateComputeShader(csBlob->GetBufferPointer(),
				csBlob->GetBufferSize(),
				nullptr,
				&cs));
		}

		if (req.Type == ShaderType::Geometry)
		{
			ComPtr<ID3D10Blob> gsBlob;
			compileOne("GS", req.EntryPoint, "gs_5_0", gsBlob);
			ComPtr<ID3D11GeometryShader> gs;
			throwIfFailed(_device->CreateGeometryShader(gsBlob->GetBufferPointer(),
				gsBlob->GetBufferSize(),
				nullptr,
				&gs));
			shader->GeometryShader = gs;
			shader->Blob = gsBlob;
		}

		return shader;
	}


	void DX11GraphicsDevice::BindVertexShader(IShader* shader, bool forceNull)
	{
		auto* dx = static_cast<DX11Shader*>(shader);

		if (!dx)
		{
			if (forceNull)
			{
				_context->VSSetShader(nullptr, nullptr, 0);
			}
			return;
		}

		if (dx->VertexShader || forceNull)
			_context->VSSetShader(dx->VertexShader.Get(), nullptr, 0);
	}

	void DX11GraphicsDevice::BindGeometryShader(IShader* shader, bool forceNull)
	{
		auto* dx = static_cast<DX11Shader*>(shader);

		if (!dx)
		{
			if (forceNull)
			{
				_context->GSSetShader(nullptr, nullptr, 0);
			}
			return;
		}

		if (dx->GeometryShader || forceNull)
			_context->GSSetShader(dx->GeometryShader.Get(), nullptr, 0);
	}

	void DX11GraphicsDevice::BindPixelShader(IShader* shader, bool forceNull)
	{
		auto* dx = static_cast<DX11Shader*>(shader);

		if (!dx)
		{
			if (forceNull)
			{
				_context->PSSetShader(nullptr, nullptr, 0);
			}
			return;
		}

		if (dx->PixelShader || forceNull)
			_context->PSSetShader(dx->PixelShader.Get(), nullptr, 0);
	}

	void DX11GraphicsDevice::Present()
	{
		_swapChain->Present(1, 0);
	}

	void DX11GraphicsDevice::ClearState()
	{
		_context->ClearState();
	}

	ISpriteFont* DX11GraphicsDevice::InitializeSpriteFont(std::wstring fontPath)
	{
		return new DX11SpriteFont(_device.Get(), fontPath);
	}

	ISpriteBatch* DX11GraphicsDevice::InitializeSpriteBatch()
	{
		return new DX11SpriteBatch(_device.Get(), _context.Get());
	}

	IPrimitiveBatch* DX11GraphicsDevice::InitializePrimitiveBatch()
	{
		return new DX11PrimitiveBatch(_context.Get());
	}

	void DX11GraphicsDevice::SaveScreenshot(IRenderTarget2D* renderTarget, std::wstring path)
	{
		auto dxRenderTarget = static_cast<DX11RenderTarget2D*>(renderTarget);
		SaveWICTextureToFile(_context.Get(), dxRenderTarget->GetTexture(), GUID_ContainerFormatPng, path.c_str(), 
			&GUID_WICPixelFormat24bppBGR, nullptr, true);
	}

	Vector4 DX11GraphicsDevice::Unproject(Vector3 position, Matrix projection, Matrix view, Matrix world)
	{
		return _viewportToolkit.Unproject(position, projection, view, world);
	}

	void DX11GraphicsDevice::Flush()
	{
		_context->Flush();
	}

	void DX11GraphicsDevice::UnbindAllRenderTargets()
	{
		ID3D11RenderTargetView* nullViews[] = { nullptr };
		_context->OMSetRenderTargets(0, nullViews, NULL);
	}
}