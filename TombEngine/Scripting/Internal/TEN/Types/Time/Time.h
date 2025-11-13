#pragma once
#include "Scripting/Internal/ScriptUtil.h"

namespace TEN::Scripting
{
	class Time
	{
	public:
		static void Register(sol::table& parent);

	private:
		// Fields

		int _frameCount = 0;

	public:
		// Constructors

		Time() = default;
		Time(int gameFrames);
		Time(const std::string& formattedTime);
		Time(const sol::table& hmsTable);

		// Getters

		int		   GetFrameCount() const;
		sol::table GetTimeUnits(sol::this_state state) const;

		int GetHours() const;
		int GetMinutes() const;
		int GetSeconds() const;
		int GetCentiseconds() const;

		// Setters

		void SetHours(int value);
		void SetMinutes(int value);
		void SetSeconds(int value);
		void SetCentiseconds(int value);

		// Utilities

		std::string ToString() const;
		std::string GetFormattedString(sol::object formatObj, TypeOrNil<bool> useCentiseconds) const;

		// Operators

		bool  operator <(const Time& time) const;
		bool  operator <=(const Time& time) const;
		bool  operator ==(const Time& time) const;
		Time  operator +(int frameCount) const;
		Time  operator -(int frameCount) const;
		Time  operator +(const Time& time) const;
		Time  operator -(const Time& time) const;
		Time& operator +=(const Time& time);
		Time& operator -=(const Time& time);
		Time& Time::operator ++();
		Time& Time::operator ++(int);
		operator int() const { return _frameCount; }

	private:
		struct Hmsc
		{
			int Hours = 0;
			int Minutes = 0;
			int Seconds = 0;
			int Centiseconds = 0;
		};

		// Helpers

		Hmsc		GetHmsc() const;
		static Hmsc ParseFormattedString(const std::string& formattedTime);

		void SetFromHMSC(int hours, int minutes = 0, int seconds = 0, int cents = 0);
		void SetFromFormattedString(const std::string& formattedTime);
		void SetFromTable(const sol::table& hmscTable);

		// Cache for last formatted result
		mutable int _lastFrameCount = -1;
		mutable std::string _cachedResult;
		mutable bool _lastIncludeHours = true;
		mutable bool _lastIncludeMinutes = true;
		mutable bool _lastIncludeSeconds = true;
		mutable bool _lastIncludeDeciseconds = true;
		mutable bool _lastUseCentiseconds = true;
	};
}
