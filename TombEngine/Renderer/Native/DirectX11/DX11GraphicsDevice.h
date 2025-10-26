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

	public:
		IVertexBuffer* CreateVertexBuffer(int numVertices, int vertexSize, void* data) override;
		bool UpdateVertexBuffer(int startVertex, int count, int vertexSize, void* data) override;
		void BindVertexBuffer(IVertexBuffer* vertexBuffer) override;

		IIndexBuffer* CreateIndexBuffer(int numIndices, int* data) override;
		IIndexBuffer* CreateIndexBuffer(int numIndices, int startIndex, int* data) override;
		void BindIndexBuffer(IIndexBuffer* indexBuffer) override;

		// Render targets
		IRenderTarget2D* CreateRenderTarget2D(int width, int height, ColorFormat colorFormat, bool isTypeless, ColorFormat depthFormat) override;
		IRenderTarget2D* CreateRenderTarget2DFromAnother(IRenderTarget2D* src, ColorFormat colorFormat) override;
		IRenderTargetCube* CreateRenderTargetCube(int size, ColorFormat colorFormat, ColorFormat depthFormat) override;

		// Textures
		ITexture2D* CreateTexture2D(int width, int height, byte* data) override;
		ITexture2D* CreateTexture2D(int width, int height, ColorFormat format, int pitch, const void* data) override;
		ITexture2D* CreateTexture2D(const std::wstring& fileName) override;
		ITexture2D* CreateTexture2D(int length, byte* data) override;
		ITexture2DArray* CreateTexture2DArray(int size, int count, ColorFormat colorFormat, ColorFormat depthFormat) override;

		// Pipeline state
		void SetBlendMode(BlendMode blendMode) override;
		void SetDepthState(DepthState depthState) override;
		void SetCullMode(CullMode cullMode) override;
		void SetScissor(RendererRectangle rectangle) override;

		// Bindings
		void BindTexture(TextureRegister registerType, ITextureBase* texture, SamplerStateRegister samplerType) override;
		void BindRenderTargetAsTexture(TextureRegister registerType, IRenderTarget2D* target, SamplerStateRegister samplerType) override;
		void BindConstantBufferVS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;
		void BindConstantBufferPS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;

		// Draw
		void DrawIndexedTriangles(int count, int baseIndex, int baseVertex) override;
		void DrawIndexedInstancedTriangles(int count, int instances, int baseIndex, int baseVertex) override;
		void DrawInstancedTriangles(int count, int instances, int baseVertex) override;
		void DrawTriangles(int count, int baseVertex) override;

		// Clear
		void ClearRenderTarget2D(IRenderTarget2D* renderTarget, DirectX::XMFLOAT4 clearColor) override;
		void ClearRenderTarget2DOfArray(ITexture2DArray* textureArray, int index, DirectX::XMFLOAT4 clearColor) override;
		void ClearRenderTarget2DOfCube(IRenderTargetCube* textureCube, int index, DirectX::XMFLOAT4 clearColor) override;

		void ClearDepthStencil(IRenderTarget2D* renderTarget, float depth, unsigned char stencil) override;
		void ClearDepthStencilOfArray(ITexture2DArray* textureArray, int index, float depth, unsigned char stencil) override;
		void ClearDepthStencilOfCube(IRenderTargetCube* textureCube, int index, float depth, unsigned char stencil) override;

		// Misc
		void SetViewport(RendererViewport viewport) override;
		void SetInputLayout(InputLayout inputLayout) override;
		void SetPrimitiveType(PrimitiveType primitiveType) override;

		void Initialize(const std::string& gameDir, int w, int h, bool windowed, HWND handle) override;

		~DX11GraphicsDevice() override = default;
	};
}
