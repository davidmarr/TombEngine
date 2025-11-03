#pragma once
#include <vector>
#include "Specific/fast_vector.h"
#include <string>
#include <SimpleMath.h>
#include "Renderer/Graphics/IIndexBuffer.h"
#include "Renderer/Graphics/IVertexBuffer.h"
#include "Renderer/Graphics/IRenderTarget2D.h"
#include "Renderer/Graphics/IRenderTargetCube.h"
#include "Renderer/Graphics/ITexture2D.h"
#include "Renderer/Graphics/ITexture2DArray.h"
#include "Renderer/Graphics/IConstantBuffer.h"
#include "Renderer/Graphics/IInputLayout.h"
#include "Renderer/Graphics/IShader.h"
#include "Renderer/Graphics/IDepthTarget.h"
#include "Renderer/Graphics/IBackBuffer.h"
#include "Renderer/Graphics/IPrimitiveBatch.h"
#include "Renderer/Graphics/ISpriteBatch.h"
#include "Renderer/Graphics/ISpriteFont.h"
#include "Renderer/RendererEnums.h"
#include "Renderer/Structures/RendererRectangle.h"
#include "Renderer/Structures/RendererInputLayout.h"
#include "Renderer/Structures/RendererViewport.h"
#include "Renderer/ShaderManager/ShaderManager.h"

using namespace TEN::Renderer::Structures;
using namespace DirectX;
using namespace DirectX::SimpleMath;

namespace TEN::Renderer::Graphics
{
	class IGraphicsDevice
	{
	public:
		virtual IVertexBuffer* CreateVertexBuffer(int numVertices, int vertexSize, void* data) = 0;
		virtual void UpdateVertexBuffer(IVertexBuffer* vertexBuffer, int startVertex, int count, void* data) = 0;
		virtual void BindVertexBuffer(IVertexBuffer* vertexBuffer) = 0;

		virtual IIndexBuffer* CreateIndexBuffer(int numIndices, int* data) = 0;
		virtual void UpdateIndexBuffer(IIndexBuffer* indexBuffer, int numIndices, int startIndex, int* data) = 0;
		virtual void BindIndexBuffer(IIndexBuffer* indexBuffer) = 0;

		virtual IRenderTarget2D* CreateRenderTarget2D(int width, int height, SurfaceFormat colorFormat, bool isTypeless) = 0;
		virtual IRenderTarget2D* CreateRenderTarget2D(int width, int height, int arraySize, SurfaceFormat colorFormat) = 0;
		virtual IRenderTarget2D* CreateRenderTarget2D(IRenderTarget2D* parentRenderTarget, SurfaceFormat colorFormat) = 0;

		virtual IRenderTargetCube* CreateRenderTargetCube(int size, SurfaceFormat colorFormat) = 0;

		virtual ITexture2D* CreateTexture2D(int width, int height, byte* data) = 0;
		virtual ITexture2D* CreateTexture2D(int width, int height, SurfaceFormat format, int pitch, const void* data) = 0;
		virtual ITexture2D* CreateTexture2D(const std::string fileName) = 0;
		virtual ITexture2D* CreateTexture2D(int dataSize, byte* data) = 0;

		virtual IDepthTarget* CreateDepthTarget(int width, int height, DepthFormat format) = 0;
		virtual IDepthTarget* CreateDepthTarget(int width, int height, int arraySize, DepthFormat format) = 0;

		virtual void SetBlendMode(BlendMode blendMode) = 0;
		virtual void SetDepthState(DepthState depthState) = 0;
		virtual void SetCullMode(CullMode cullMode) = 0;
		virtual void SetScissor(RendererRectangle rectangle) = 0;

		virtual void BindTexture(TextureRegister registerType, ITextureBase* texture, SamplerStateRegister samplerType) = 0;
		
		virtual IConstantBuffer* CreateConstantBuffer(int size, std::string name) = 0;
		virtual void UpdateConstantBuffer(IConstantBuffer* constantBuffer, void* data) = 0;
		virtual void BindConstantBufferVS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) = 0;
		virtual void BindConstantBufferPS(ConstantBufferRegister constantBufferType, IConstantBuffer* buffer) = 0;

		virtual void DrawIndexedTriangles(int count, int baseIndex, int baseVertex) = 0;
		virtual void DrawIndexedInstancedTriangles(int count, int instances, int baseIndex, int baseVertex) = 0;
		virtual void DrawInstancedTriangles(int count, int instances, int baseVertex) = 0;
		virtual void DrawTriangles(int count, int baseVertex) = 0;

		virtual void ClearRenderTarget2D(IRenderTarget2D* renderTarget, XMVECTORF32 clearColor) = 0;
		virtual void ClearRenderTarget2D(IRenderTarget2D* renderTarget, int arrayIndex, XMVECTORF32 clearColor) = 0;
		virtual void ClearRenderTargetCube(IRenderTargetCube* textureCube, int faceIndex, XMVECTORF32 clearColor) = 0;
		
		virtual void ClearDepthStencil(IDepthTarget* depthTarget, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) = 0;
		virtual void ClearDepthStencil(IDepthTarget* depthTarget, int arrayIndex, DepthStencilClearFlags clearFlags, float depth, unsigned char stencil) = 0;

		virtual void BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget) = 0;
		virtual void BindRenderTarget(IRenderTarget2D* renderTarget, IDepthTarget* depthTarget, int arrayIndex) = 0;
		virtual void BindRenderTargets(std::vector<IRenderTarget2D*> renderTargets, IDepthTarget* depthTarget) = 0;

		virtual void SetViewport(RendererViewport viewport) = 0;
		virtual void SetPrimitiveType(PrimitiveType primitiveType) = 0;

		virtual void SetInputLayout(IInputLayout* inputLayout) = 0;
		virtual IInputLayout* CreateInputLayout(std::vector<RendererInputLayoutField> fields) = 0;

		virtual void CreateDevice() = 0;
		virtual void Initialize(const std::string gameDir, int w, int h, bool windowed, HWND handle) = 0;
		virtual IBackBuffer* InitializeSwapChain(int width, int height, HWND handle) = 0;

		virtual std::string GetDefaultAdapterName() = 0;
		virtual void ChangeScreenResolution(int width, int height, bool windowed) = 0;

		virtual IShader* CreateShader(ShaderCompileRequest& request) = 0;
		virtual void BindVertexShader(IShader* shader, bool forceNull) = 0;
		virtual void BindGeometryShader(IShader* shader, bool forceNull) = 0;
		virtual void BindPixelShader(IShader* shader, bool forceNull) = 0;

		virtual void Present() = 0;
		virtual void ClearState() = 0;

		virtual ~IGraphicsDevice() = default;
	};
}
