#pragma once
#include "Math/Math.h"

using namespace TEN::Math;

struct ItemInfo;

namespace TEN::Effects::Streamer
{
	enum class StreamerFlags
	{
		FadeLeft		  = 1 << 0,
		FadeRight		  = 1 << 1,
		BlendModeAdditive = 1 << 2
	};

	class Streamer
	{
	private:
		// Constants
		static constexpr auto SEGMENT_COUNT_MAX = 128;

	public:
		struct StreamerSegment
		{
			static constexpr auto VERTEX_COUNT = 2;

			AxisAngle Orientation = AxisAngle::Identity;
			Vector4	  Color		  = Vector4::Zero;

			float Life		 = 0.0f;
			float LifeMax	 = 0.0f;
			float OpacityMax = 0.0f;
			float Velocity	 = 0.0f;
			float ScaleRate	 = 0.0f;
			short Rotation	 = 0;
			int	  Flags		 = 0;

			std::array<Vector3, VERTEX_COUNT> Vertices = {};

			Vector4 PrevColor = Vector4::Zero;
			std::array<Vector3, VERTEX_COUNT> PrevVertices = {};

			void InitializeVertices(const Vector3& pos, float width);
			void Update();

		private:
			void TransformVertices(float vel, float scaleRate);

			void StoreInterpolationData()
			{
				PrevColor = Color;
				PrevVertices[0] = Vertices[0];
				PrevVertices[1] = Vertices[1];
			}
		};

		// Members
		bool IsBroken = false;
		std::vector<StreamerSegment> Segments = {};

		// Utilities
		void AddSegment(const Vector3& pos, const Vector3& dir, short orient, const Vector4& color,
						float width, float life, float vel, float scaleRate, short rot, int flags, unsigned int segmentCount);
		void Update();

	private:
		// Helpers
		StreamerSegment& GetNewSegment();
	};

	class StreamerModule
	{
	private:
		// Constants
		static constexpr auto POOL_COUNT_MAX	 = 8;
		static constexpr auto STREAMER_COUNT_MAX = 8;

	public:
		// Members
		std::unordered_map<int, std::vector<Streamer>> Pools = {}; // Key = tag.

		// Utilities
		void AddStreamer(int tag, const Vector3& pos, const Vector3& dir, short orient, const Vector4& color,
						 float width, float life, float vel, float scaleRate, short rot, int flags);
		void Update();

	private:
		// Helpers
		std::vector<Streamer>& GetPool(int tag);
		Streamer&			   GetStreamer(int tag);
		void				   ClearInactivePools();
		void				   ClearInactiveStreamers(int tag);
	};

	class StreamerEffectController
	{
	private:
		// Constants
		static constexpr auto MODULE_COUNT_MAX = 64;

	public:
		// Members
		std::unordered_map<int, StreamerModule> Modules = {}; // Key = item number.

		// Utilities
		void Spawn(int itemNumber, int tag, const Vector3& pos, const Vector3& dir, short orient, const Vector4& color,
				   float width, float life, float vel, float scaleRate, short rot, int flags = 0);
		void Update();
		void Clear();

	private:
		// Helpers
		StreamerModule& GetModule(int itemNumber);
		void			ClearInactiveModules();
	};

	extern StreamerEffectController StreamerEffect;
}
