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
#include "Renderer/Native/DirectX11/DX11DepthTarget.h"
#include "Renderer/Native/DirectX11/DX11ConstantBuffer.h"
#include "Renderer/Native/DirectX11/DX11InputLayout.h"
#include "Renderer/Native/DirectX11/DX11Shader.h"

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
		
		std::unique_ptr<SpriteBatch> _spriteBatch;
		std::unique_ptr<PrimitiveBatch<Vertex>> _primitiveBatch;

		Viewport _viewportToolkit;

		int _screenWidth;
		int _screenHeight;
		int _isWindowed;
		int _refreshRate;

		inline DXGI_FORMAT GetDXGIFormat(SurfaceFormat format)
		{
			switch (format)
			{
			case SurfaceFormat::RGBA8_Unorm:
				return DXGI_FORMAT_R8G8B8A8_UNORM;
			case SurfaceFormat::RGBA8_Unorm_Srgb:
				return DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
			case SurfaceFormat::R32_Float:
				return DXGI_FORMAT_R32_FLOAT;
			case SurfaceFormat::R8G8_Unorm:
				return DXGI_FORMAT_R8G8_UNORM;
			case SurfaceFormat::Unknown:
			default:
				return DXGI_FORMAT_UNKNOWN;
			}
		}

		inline DXGI_FORMAT GetDXGIFormat(DepthFormat format)
		{
			switch (format)
			{
			case DepthFormat::Depth24Stencil8:
				return DXGI_FORMAT_D24_UNORM_S8_UINT;
			case DepthFormat::Depth32:
				return DXGI_FORMAT_D32_FLOAT;
			default:
				return DXGI_FORMAT_D32_FLOAT;
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

		std::vector<D3D_SHADER_MACRO> ToD3DMacros(const std::map<std::string, std::string>& m)
		{
			std::vector<D3D_SHADER_MACRO> out;
			out.reserve(m.size() + 1);
			for (auto& kv : m)
			{
				out.push_back(D3D_SHADER_MACRO{ kv.first.c_str(),
												kv.second.empty() ? nullptr : kv.second.c_str() });
			}
			out.push_back(D3D_SHADER_MACRO{ nullptr, nullptr });
			return out;
		}

	public:
		IVertexBuffer* CreateVertexBuffer(int numVertices, int vertexSize, void* data) override;
		void UpdateVertexBuffer(IVertexBuffer* vertexBuffer, int startVertex, int count, void* data) override;
		void BindVertexBuffer(IVertexBuffer* vertexBuffer) override;

		IIndexBuffer* CreateIndexBuffer(int numIndices, int* data) override;
		void UpdateIndexBuffer(IIndexBuffer* indexBuffer, int numIndices, int startIndex, int* data) override;
		void BindIndexBuffer(IIndexBuffer* indexBuffer) override;

		IRenderSurface2D* CreateRenderSurface2D(int width, int height, SurfaceFormat colorFormat, bool isTypeless, DepthFormat depthFormat) override;
		IRenderSurface2D* CreateRenderSurface2D(int width, int height, int arraySize, SurfaceFormat colorFormat, DepthFormat depthFormat) override;
		IRenderSurface2D* CreateRenderSurface2D(IRenderSurface2D* parentRenderTarget, SurfaceFormat colorFormat) override;

		IRenderTargetCube* CreateRenderTargetCube(int size, SurfaceFormat colorFormat) override;

		ITexture2D* CreateTexture2D(int width, int height, byte* data) override;
		ITexture2D* CreateTexture2D(int width, int height, SurfaceFormat format, int pitch, const void* data) override;
		ITexture2D* CreateTexture2D(const std::string fileName) override;
		ITexture2D* CreateTexture2D(int dataSize, byte* data) override;

		void SetBlendMode(BlendMode blendMode) override;
		void SetDepthState(DepthState depthState) override;
		void SetCullMode(CullMode cullMode) override;
		void SetScissor(RendererRectangle rectangle) override;

		void BindTexture(TextureRegister registerType, ITextureBase* texture, SamplerStateRegister samplerType) override;

		IConstantBuffer* CreateConstantBuffer(int size, std::wstring name) override;
		void UpdateConstantBuffer(IConstantBuffer* constantBuffer, void* data) override;
		void BindConstantBufferVS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;
		void BindConstantBufferPS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) override;

		void DrawIndexedTriangles(int count, int baseIndex, int baseVertex) override;
		void DrawIndexedInstancedTriangles(int count, int instances, int baseIndex, int baseVertex) override;
		void DrawInstancedTriangles(int count, int instances, int baseVertex) override;
		void DrawTriangles(int count, int baseVertex) override;

		void ClearRenderTarget2D(IRenderTarget2D* renderTarget, XMVECTORF32 clearColor) override;
		void ClearRenderTarget2D(IRenderTarget2D* renderTarget, int arrayIndex, XMVECTORF32 clearColor) override;
		void ClearRenderTarget2DOfCube(IRenderTargetCube* textureCube, int index, XMVECTORF32 clearColor) override;

		void ClearDepthStencil(IDepthTarget* renderTarget, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) override;
		void ClearDepthStencil(IDepthTarget* renderTarget, int arrayIndex, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) override;

		void BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget) override;
		void BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget, int arrayIndex) override;
		void BindRenderTargets(std::vector<IRenderTarget2D*> renderTargets, IDepthTarget* depthTarget) override;

		void SetViewport(RendererViewport viewport) override;
		void SetPrimitiveType(PrimitiveType primitiveType) override;

		void SetInputLayout(IInputLayout* inputLayout) override;
		IInputLayout* CreateInputLayout(std::vector<RendererInputLayoutField> fields) override;

		void CreateDevice() override;
		void Initialize(const std::string gameDir, int w, int h, bool windowed, HWND handle) override;
		IRenderSurface2D* InitializeSwapChain(int width, int height, HWND handle) override;

		std::string GetDefaultAdapterName() override;
		void ChangeScreenResolution(int width, int height, bool windowed) override;

		IShader* CreateShader(ShaderCompileRequest& request) override;
		void BindVertexShader(IShader* shader, bool forceNull) override;
		void BindGeometryShader(IShader* shader, bool forceNull) override;
		void BindPixelShader(IShader* shader, bool forceNull) override;

		void Present() override;
		void ClearState() override;

		~DX11GraphicsDevice() override = default;
	};
}
