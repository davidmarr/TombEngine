#include "framework.h"
#include "Renderer/Renderer.h"
#include "Game/spotcam.h"

namespace TEN::Renderer
{
	void Renderer::DrawPostprocess(IRenderSurface2D* renderTarget, RenderView& view, SceneRenderMode renderMode)
	{
		_doingFullscreenPass = true;

		SetBlendMode(BlendMode::Opaque);
		SetCullMode(CullMode::CounterClockwise);
		SetDepthState(DepthState::Write);
		_graphicsDevice->SetViewport(view.Viewport);
		ResetScissor();

		float screenFadeFactor = renderMode == SceneRenderMode::Full ? ScreenFadeCurrent : 1.0f;
		float cinematicBarsHeight = renderMode == SceneRenderMode::Full ? Smoothstep(CinematicBarsHeight) * SPOTCAM_CINEMATIC_BARS_HEIGHT : 0.0f;

		_stPostProcessBuffer.ScreenFadeFactor = screenFadeFactor;
		_stPostProcessBuffer.CinematicBarsHeight = cinematicBarsHeight;
		_stPostProcessBuffer.ViewportSize = Vector2i(_screenWidth, _screenHeight);
		_stPostProcessBuffer.EffectStrength = _postProcessStrength;
		_stPostProcessBuffer.Tint = _postProcessTint;
		UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

		_graphicsDevice->SetPrimitiveType(PrimitiveType::TriangleList);
		_graphicsDevice->SetInputLayout(_fullScreenVertexInputLayout);

		unsigned int stride = sizeof(PostProcessVertex);
		unsigned int offset = 0;

		_graphicsDevice->BindVertexBuffer(_fullscreenTriangleVertexBuffer);

		_shaders.Bind(Shader::PostProcess);

		// *** START OF POST-PROCESSING CHAIN ***
		
		// Copy render target to post process render target. --------------------------------------------------------------------
		_graphicsDevice->ClearRenderTarget2D(_postProcessRenderTarget[0]->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(_postProcessRenderTarget[0]->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, _renderTarget->GetRenderTarget(), SamplerStateRegister::PointWrap);
		DrawTriangles(3, 0);

		// Ping-pong between two post-process render targets.
		int currentRenderTarget = 0;
		int destRenderTarget = 1;

		// Lens flares ----------------------------------------------------------------------------------------------------------
		_shaders.Bind(Shader::PostProcess);
		
		if (!view.LensFlaresToDraw.empty())
		{
			_graphicsDevice->ClearRenderTarget2D(_postProcessRenderTarget[destRenderTarget]->GetRenderTarget(), Colors::Transparent);
			_graphicsDevice->BindRenderTarget(_postProcessRenderTarget[destRenderTarget]->GetRenderTarget(), nullptr);

			_shaders.Bind(Shader::PostProcessLensFlare);

			for (int i = 0; i < view.LensFlaresToDraw.size(); i++)
			{
				_stPostProcessBuffer.LensFlares[i].Position = view.LensFlaresToDraw[i].Position;
				_stPostProcessBuffer.LensFlares[i].Color = view.LensFlaresToDraw[i].Color.ToVector3();
			}
			_stPostProcessBuffer.NumLensFlares = (int)view.LensFlaresToDraw.size();
			UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

			BindRenderTargetAsTexture(TextureRegister::ColorMap, _postProcessRenderTarget[currentRenderTarget]->GetRenderTarget(), SamplerStateRegister::PointWrap);
			DrawTriangles(3, 0);

			destRenderTarget = (destRenderTarget) == 1 ? 0 : 1;
			currentRenderTarget = (currentRenderTarget == 1) ? 0 : 1;
		}

		// Color scheme ----------------------------------------------------------------------------------------------------------
		if (_postProcessMode != PostProcessMode::None && _postProcessStrength > EPSILON)
		{
			_graphicsDevice->ClearRenderTarget2D(_postProcessRenderTarget[destRenderTarget]->GetRenderTarget(), Colors::Transparent);
			_graphicsDevice->BindRenderTarget(_postProcessRenderTarget[destRenderTarget]->GetRenderTarget(), nullptr);

			switch (_postProcessMode)
			{
			case PostProcessMode::Monochrome:
				_shaders.Bind(Shader::PostProcessMonochrome);
				break;

			case PostProcessMode::Negative:
				_shaders.Bind(Shader::PostProcessNegative);
				break;

			case PostProcessMode::Exclusion:
				_shaders.Bind(Shader::PostProcessExclusion);
				break;

			default:
				return;
			}

			BindRenderTargetAsTexture(TextureRegister::ColorMap, _postProcessRenderTarget[currentRenderTarget]->GetRenderTarget(), SamplerStateRegister::PointWrap);
			DrawTriangles(3, 0);

			destRenderTarget = (destRenderTarget == 1) ? 0 : 1;
			currentRenderTarget = (currentRenderTarget == 1) ? 0 : 1;
		}

		// Final pass ----------------------------------------------------------------------------------------------------------
		_shaders.Bind(Shader::PostProcessFinalPass);

		_graphicsDevice->ClearRenderTarget2D(renderTarget->GetRenderTarget(), Colors::Black);
		_graphicsDevice->BindRenderTarget(renderTarget->GetRenderTarget(), nullptr);

		BindTexture(TextureRegister::ColorMap, _postProcessRenderTarget[currentRenderTarget]->GetRenderTarget(), SamplerStateRegister::PointWrap);

		DrawTriangles(3, 0);

		_doingFullscreenPass = false;
	}

	PostProcessMode Renderer::GetPostProcessMode()
	{
		return _postProcessMode;
	}

	float Renderer::GetPostProcessStrength()
	{
		return _postProcessStrength;
	}

	Vector3 Renderer::GetPostProcessTint()
	{
		return _postProcessTint;
	}

	void Renderer::SetPostProcessMode(PostProcessMode mode)
	{
		_postProcessMode = mode;
	}

	void Renderer::SetPostProcessStrength(float strength)
	{
		_postProcessStrength = strength;
	}

	void Renderer::SetPostProcessTint(Vector3 tint)
	{
		_postProcessTint = tint;
	}

	void Renderer::CopyRenderTarget(IRenderSurface2D* source, IRenderSurface2D* dest, RenderView& view)
	{
		SetBlendMode(BlendMode::Opaque, true);
		SetCullMode(CullMode::CounterClockwise, true);
		SetDepthState(DepthState::Write, true);
		_graphicsDevice->SetViewport(view.Viewport);
		ResetScissor();

		// Common vertex shader to all fullscreen effects
		_shaders.Bind(Shader::PostProcess);

		// We draw a fullscreen triangle
		_graphicsDevice->SetPrimitiveType(PrimitiveType::TriangleList);
		_graphicsDevice->SetInputLayout(_fullScreenVertexInputLayout);

		unsigned int stride = sizeof(PostProcessVertex);
		unsigned int offset = 0;

		_graphicsDevice->BindVertexBuffer(_fullscreenTriangleVertexBuffer);

		float clearColor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
		_graphicsDevice->ClearRenderTarget2D(dest->GetRenderTarget(), Colors::Black);
		_graphicsDevice->BindRenderTarget(dest->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, source->GetRenderTarget(), SamplerStateRegister::PointWrap);
		DrawTriangles(3, 0);
	}

	void Renderer::CopyRenderTargetAndDownscale(IRenderSurface2D* source, IRenderSurface2D* dest, float factor, RenderView& view)
	{
		RendererViewport viewport = { 0, 0, (int)(_screenWidth / factor), (int)(_screenHeight / factor), 0.0f, 1.0f };
		_graphicsDevice->SetViewport(viewport);

		RendererRectangle scissor = { 0, 0, viewport.Width , viewport.Height };
		_graphicsDevice->SetScissor(scissor);

		SetBlendMode(BlendMode::Opaque, true);
		SetCullMode(CullMode::CounterClockwise, true);
		SetDepthState(DepthState::Write, true);

		// Common vertex shader to all fullscreen effects
		_shaders.Bind(Shader::PostProcess);

		// We draw a fullscreen triangle
		_graphicsDevice->SetPrimitiveType(PrimitiveType::TriangleList);
		_graphicsDevice->SetInputLayout(_fullScreenVertexInputLayout);
		_graphicsDevice->BindVertexBuffer(_fullscreenTriangleVertexBuffer);

		_graphicsDevice->ClearRenderTarget2D(dest->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(dest->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, source->GetRenderTarget(), SamplerStateRegister::PointWrap);
		DrawTriangles(3, 0);

		ResetScissor();
		_graphicsDevice->SetViewport(view.Viewport);
	}

	void Renderer::ApplyGlow(IRenderSurface2D* renderTarget, RenderView& view)
	{
		SetBlendMode(BlendMode::Opaque, true);
		SetCullMode(CullMode::CounterClockwise, true);
		SetDepthState(DepthState::Write, true);

		RendererViewport viewport = { 0, 0, (int)(_screenWidth / GLOW_DOWNSCALE_FACTOR), (int)(_screenHeight / GLOW_DOWNSCALE_FACTOR), 0.0f, 1.0f };
		_graphicsDevice->SetViewport(viewport);

		RendererRectangle scissor = { 0, 0, viewport.Width , viewport.Height };
		_graphicsDevice->SetScissor(scissor);


		_shaders.Bind(Shader::PostProcess);

		_stPostProcessBuffer.ViewportSize = Vector2i(_screenWidth, _screenHeight);

		_graphicsDevice->SetPrimitiveType(PrimitiveType::TriangleList);
		_graphicsDevice->SetInputLayout(_fullScreenVertexInputLayout);

		unsigned int stride = sizeof(PostProcessVertex);
		unsigned int offset = 0;

		_graphicsDevice->BindVertexBuffer(_fullscreenTriangleVertexBuffer);

		// Downscale 
		_shaders.Bind(Shader::Downscale);

		_stPostProcessBuffer.DownscaleFactor = GLOW_DOWNSCALE_FACTOR;
		UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

		_graphicsDevice->ClearRenderTarget2D(_glowRenderTarget[0]->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(_glowRenderTarget[0]->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, _emissiveAndRoughnessRenderTarget->GetRenderTarget(), SamplerStateRegister::LinearClamp);
		DrawTriangles(3, 0);

		// Blur
		_shaders.Bind(Shader::Blur);

		_stPostProcessBuffer.TexelSize = Vector2(1.0f / (_screenWidth / GLOW_DOWNSCALE_FACTOR), 1.0f / (_screenHeight / GLOW_DOWNSCALE_FACTOR));
		_stPostProcessBuffer.BlurSigma = GLOW_BLUR_SIGMA;
		_stPostProcessBuffer.BlurRadius = GLOW_BLUR_RADIUS;

		// Horizontal blur
		_graphicsDevice->ClearRenderTarget2D(_glowRenderTarget[1]->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(_glowRenderTarget[1]->GetRenderTarget(), nullptr);

		_stPostProcessBuffer.BlurDirection = Vector2(1.0f, 0.0f);
		UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, _glowRenderTarget[0]->GetRenderTarget(), SamplerStateRegister::LinearClamp);
		DrawTriangles(3, 0);

		// Vertical blur
		_stPostProcessBuffer.BlurDirection = Vector2(0.0f, 1.0f);
		UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

		_graphicsDevice->ClearRenderTarget2D(_glowRenderTarget[0]->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(_glowRenderTarget[0]->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(TextureRegister::ColorMap, _glowRenderTarget[1]->GetRenderTarget(), SamplerStateRegister::LinearClamp);
		DrawTriangles(3, 0);

		// Reset viewport
		_graphicsDevice->SetViewport(view.Viewport);
		ResetScissor();

		// Copy render target to temp render target
		CopyRenderTarget(renderTarget, _postProcessRenderTarget[0], view);

		// Combine glow
		_shaders.Bind(Shader::GlowCombine);

		_stPostProcessBuffer.GlowSoftAdd = 1;
		_stPostProcessBuffer.GlowIntensity = 1.0f;
		UpdateConstantBuffer(&_stPostProcessBuffer, _cbPostProcessBuffer);

		_graphicsDevice->ClearRenderTarget2D(renderTarget->GetRenderTarget(), Colors::Transparent);
		_graphicsDevice->BindRenderTarget(renderTarget->GetRenderTarget(), nullptr);

		BindRenderTargetAsTexture(static_cast<TextureRegister>(0), _postProcessRenderTarget[0]->GetRenderTarget(), SamplerStateRegister::LinearClamp);
		BindRenderTargetAsTexture(static_cast<TextureRegister>(3), _glowRenderTarget[0]->GetRenderTarget(), SamplerStateRegister::LinearClamp);
		DrawTriangles(3, 0);
	}
}