#pragma once

#include "Renderer/Graphics/IGraphicsDevice.h"
#include <wrl/client.h>
#include <CommonStates.h>
#include <SpriteFont.h>
#include <PrimitiveBatch.h>
#include <d3d9types.h>
#include <SimpleMath.h>
#include "Renderer/Native/DirectX11/DX11IndexBuffer.h"
#include "Renderer/Native/DirectX11/DX11VertexBuffer.h"
#include "Renderer/Native/DirectX11/DX11RenderTarget2D.h"
#include "Renderer/Native/DirectX11/DX11RenderTargetCube.h"
#include "Renderer/Native/DirectX11/DX11Texture2D.h"
#include "Renderer/Native/DirectX11/DX11Texture2DArray.h"
#include "Renderer/Native/DirectX11/DX11ConstantBuffer.h"

using namespace TEN::Renderer::Graphics;
using namespace TEN::Renderer::Graphics;
using namespace TEN::Renderer::Structures;
using namespace DirectX::SimpleMath;
using namespace Microsoft::WRL;

namespace TEN::Renderer::Native::DirectX11
{
	class DX11GraphicsDevice final : public IGraphicsDevice
	{
	private:
		ComPtr<ID3D11Device> _device = nullptr;
		ComPtr<ID3D11DeviceContext> _context = nullptr;
		ComPtr<IDXGISwapChain> _swapChain = nullptr;

		std::unique_ptr<CommonStates> _renderStates = nullptr;

		ComPtr <ID3D11SamplerState> _pointWrapSamplerState = nullptr;
		ComPtr<ID3D11SamplerState> _shadowSampler;

		ComPtr<ID3D11BlendState> _subtractiveBlendState = nullptr;
		ComPtr<ID3D11BlendState> _screenBlendState = nullptr;
		ComPtr<ID3D11BlendState> _lightenBlendState = nullptr;
		ComPtr<ID3D11BlendState> _excludeBlendState = nullptr;
		ComPtr<ID3D11BlendState> _transparencyBlendState = nullptr;
		ComPtr<ID3D11BlendState> _finalTransparencyBlendState = nullptr;

		ComPtr<ID3D11RasterizerState> _cullCounterClockwiseRasterizerState = nullptr;
		ComPtr<ID3D11RasterizerState> _cullClockwiseRasterizerState = nullptr;
		ComPtr<ID3D11RasterizerState> _cullNoneRasterizerState = nullptr;
		
		ComPtr<ID3D11InputLayout> _inputLayout = nullptr;
		ComPtr<ID3D11InputLayout> _fullscreenTriangleInputLayout = nullptr;
		
		D3D11_VIEWPORT _viewport;
		D3D11_VIEWPORT _shadowMapViewport;
		Viewport _viewportToolkit;

		inline DXGI_FORMAT GetDXGIFormat(PixelFormat format)
		{
			switch (format)
			{
			case PixelFormat::RGBA8_Unorm:
				return DXGI_FORMAT_R8G8B8A8_UNORM;
			case PixelFormat::RGBA8_Unorm_Srgb:
				return DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
			case PixelFormat::R32_Float:
				return DXGI_FORMAT_R32_FLOAT;
			case PixelFormat::R8G8_Unorm:
				return DXGI_FORMAT_R8G8_UNORM;
			case PixelFormat::D24_S8:
				return DXGI_FORMAT_D24_UNORM_S8_UINT;
			case PixelFormat::Unknown:
			default:
				return DXGI_FORMAT_UNKNOWN;
			}
		}

		inline unsigned int GetClearFlags(DepthStencilClearFlags flags)
		{
			switch (flags)
			{
			case DepthStencilClearFlags::Depth:
				return D3D11_CLEAR_DEPTH;
			case DepthStencilClearFlags::Stencil:
				return D3D11_CLEAR_STENCIL;
			case DepthStencilClearFlags::DepthAndStencil:
			default:
				return (D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL);
			}
		}

	public:
		IVertexBuffer* CreateVertexBuffer(int numVertices, int vertexSize, void* data) override;
		bool UpdateVertexBuffer(IVertexBuffer* vertexBuffer, int startVertex, int count, void* data) override;
		void BindVertexBuffer(IVertexBuffer* vertexBuffer) override;

		IIndexBuffer* CreateIndexBuffer(int numIndices, int* data) override;
		IIndexBuffer* CreateIndexBuffer(int numIndices, int startIndex, int* data) override;
		void BindIndexBuffer(IIndexBuffer* indexBuffer) override;

		IRenderTarget2D* CreateRenderTarget2D(int width, int height, PixelFormat colorFormat, bool isTypeless, PixelFormat depthFormat) override;
		IRenderTarget2D* CreateRenderTarget2DFromAnother(IRenderTarget2D* src, PixelFormat colorFormat) override;
		IRenderTargetCube* CreateRenderTargetCube(int size, PixelFormat colorFormat, PixelFormat depthFormat) override;

		ITexture2D* CreateTexture2D(int width, int height, byte* data) override;
		ITexture2D* CreateTexture2D(int width, int height, PixelFormat format, int pitch, const void* data) override;
		ITexture2D* CreateTexture2D(const std::wstring& fileName) override;
		ITexture2D* CreateTexture2D(int length, byte* data) override;
		ITexture2DArray* CreateTexture2DArray(int size, int count, PixelFormat colorFormat, PixelFormat depthFormat) override;

		void SetBlendMode(BlendMode blendMode) override;
		void SetDepthState(DepthState depthState) override;
		void SetCullMode(CullMode cullMode) override;
		void SetScissor(RendererRectangle rectangle) override;

		void BindTexture(TextureRegister registerType, ITextureBase* texture, SamplerStateRegister samplerType) override;

		IConstantBuffer* CreateConstantBuffer(int size, char* name) override;
		void UpdateConstantBuffer(IConstantBuffer* constantBuffer, void* data) override;
		void BindConstantBufferVS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;
		void BindConstantBufferPS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;

		void DrawIndexedTriangles(int count, int baseIndex, int baseVertex) override;
		void DrawIndexedInstancedTriangles(int count, int instances, int baseIndex, int baseVertex) override;
		void DrawInstancedTriangles(int count, int instances, int baseVertex) override;
		void DrawTriangles(int count, int baseVertex) override;

		void ClearRenderTarget2D(IRenderTarget2D* renderTarget, XMVECTORF32 clearColor) override;
		void ClearRenderTarget2DOfArray(ITexture2DArray* textureArray, int index, XMVECTORF32 clearColor) override;
		void ClearRenderTarget2DOfCube(IRenderTargetCube* textureCube, int index, XMVECTORF32 clearColor) override;

		void ClearDepthStencil(IRenderTarget2D* renderTarget, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) override;
		void ClearDepthStencilOfArray(ITexture2DArray* textureArray, int index, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) override;
		void ClearDepthStencilOfCube(IRenderTargetCube* textureCube, int index, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) override;

		void SetViewport(RendererViewport viewport) override;
		void SetInputLayout(InputLayout inputLayout) override;
		void SetPrimitiveType(PrimitiveType primitiveType) override;

		void Initialize(const std::string& gameDir, int w, int h, bool windowed, HWND handle) override;

		~DX11GraphicsDevice() override = default;
	};
}
