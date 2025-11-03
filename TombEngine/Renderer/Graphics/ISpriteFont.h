#pragma once

#include "Renderer/Graphics/ISpriteBatch.h"
#include <SimpleMath.h>
#include <string>

using namespace DirectX::SimpleMath;

namespace TEN::Renderer::Graphics
{
    class ISpriteFont
    {
    public:
        virtual ~ISpriteFont() = default;

        virtual float GetLineSpacing() = 0;
        virtual Vector2 MeasureString(std::string str) = 0;
        virtual Vector2 MeasureString(char* str) = 0;
        virtual void FindGlyph(char c) = 0;
        virtual void DrawString(ISpriteBatch* spriteBatch, std::string text, Vector2 position, Vector4 color, float rotation, Vector2 origin, float scale = 1) = 0;
        virtual void DrawString(ISpriteBatch* spriteBatch, char* text, Vector2 position, Vector4 color, float rotation, Vector2 origin, float scale = 1) = 0;
    };
}