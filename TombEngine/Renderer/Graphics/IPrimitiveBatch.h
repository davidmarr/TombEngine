#pragma once

namespace TEN::Renderer::Graphics
{
    template <typename TVertex>
    class IPrimitiveBatch
    {
    public:
        virtual ~IPrimitiveBatch() = default;

        virtual void Begin() = 0;
        virtual void End() = 0;
        virtual void DrawLine(TVertex const& v1, TVertex const& v2) = 0;
        virtual void DrawTriangle(TVertex const& v1, TVertex const& v2, TVertex const& v3) = 0;
        virtual void DrawQuad(TVertex const& v1, TVertex const& v2, TVertex const& v3, TVertex const& v4) = 0;
    };
}