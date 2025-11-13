#include "framework.h"
#include "Scripting/Internal/TEN/Types/Time/Time.h"

#include "Math/Math.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Specific/clock.h"

namespace TEN::Scripting
{
	constexpr auto TIME_UNIT   = 60;
	constexpr auto CENTISECOND = 100;

	/// Represents a time value in game frames, with support for formatting to hours, minutes, seconds, and centiseconds (1/100th of a second).
	// @tenprimitive Time
	// @pragma nostrip

	void Time::Register(sol::table& parent)
	{
		using ctors = sol::constructors<
			Time(), Time(int),
			Time(const std::string&), Time(const sol::table&)>;

		parent.new_usertype<Time>(
			"Time", ctors(),
			sol::call_constructor, ctors(),

			// Meta functions
			sol::meta_function::to_string, &Time::ToString,
			sol::meta_function::equal_to, &Time::operator ==,
			sol::meta_function::less_than, &Time::operator <,
			sol::meta_function::less_than_or_equal_to, &Time::operator <=,

			sol::meta_function::addition, sol::overload(
				[](const Time& time0, const Time& time1) { return (time0 + time1); },
				[](const Time& time, int gameFrames) { return (time + gameFrames); }),
			sol::meta_function::subtraction, sol::overload(
				[](const Time& time0, const Time& time1) { return (time0 - time1); },
				[](const Time& time, int gameFrames) { return (time - gameFrames); }),

			// Methods
			"GetTimeUnits", &Time::GetTimeUnits,
			"GetFrameCount", &Time::GetFrameCount,
			"GetFormattedString", & Time::GetFormattedString,

			// Readable and writable fields
			"h", sol::property(&Time::GetHours,		   &Time::SetHours),
			"m", sol::property(&Time::GetMinutes,	   &Time::SetMinutes),
			"s", sol::property(&Time::GetSeconds,	   &Time::SetSeconds),
			"c", sol::property(&Time::GetCentiseconds, &Time::SetCentiseconds));
	}

	/// (int) Hours component.
	// @mem h
	int Time::GetHours() const
	{
		auto [h, m, s, c] = GetHmsc();
		return h;
	}

	/// (int) Minutes component.
	// @mem m
	int Time::GetMinutes() const
	{
		auto [h, m, s, c] = GetHmsc();
		return m;
	}

	/// (int) Seconds component.
	// @mem s
	int Time::GetSeconds() const
	{
		auto [h, m, s, c] = GetHmsc();
		return s;
	}

	/// (int) Centiseconds component.
	// @mem c
	int Time::GetCentiseconds() const
	{
		auto [h, m, s, c] = GetHmsc();
		return c;
	}

	void Time::SetHours(int value)
	{
		auto [h, m, s, f] = GetHmsc();
		SetFromHMSC(value, m, s, f);
	}

	void Time::SetMinutes(int value)
	{
		auto [h, m, s, f] = GetHmsc();
		SetFromHMSC(h, value, s, f);
	}

	void Time::SetSeconds(int value)
	{
		auto [h, m, s, c] = GetHmsc();
		SetFromHMSC(h, m, value, c);
	}

	void Time::SetCentiseconds(int value)
	{
		auto [h, m, s, c] = GetHmsc();
		SetFromHMSC(h, m, s, value);
	}

	/// Create a Time object.
	// @function Time
	// @treturn Time A new Time object initialized to zero time.
	// @usage
	// -- Create Time object with zero time
	// local time = Time() -- 0 frames


	/// Create a Time object from a total game frame count (1 second = 30 frames).
	// @function Time
	// @tparam int gameFrames Total game frame count.
	// @treturn Time A new Time object initialized with the given frame count.
	// @usage
	// -- Example1: Create Time object for 3 seconds (90 frames)
	// local time = Time(90) -- 3 seconds
	//
	// -- Example2: Create Time object with 120 seconds (3600 frames)
	// local seconds = 120
	// local time = Time(seconds * 30)
	Time::Time(int gameFrames)
	{
		_frameCount = std::clamp(gameFrames, 0, INT_MAX);
	}

	/// Create a Time object from a formatted string.
	// @function Time
	// @tparam string formattedTime Time in the format "HH:MM:SS[.CC]", where [.CC] is centiseconds and is optional.
	// @treturn Time A new Time object parsed from the given string.
	// @usage
	// -- Create Time object from formatted string "00:01:30.50"
	// local time = Time("00:01:30.50") -- 1 minute, 30 seconds, and 50 centiseconds
	Time::Time(const std::string& formattedTime)
	{
		SetFromFormattedString(formattedTime);
	}

	/// Create a Time object from a time unit table (hours, minutes, seconds, centiseconds).
	// @function Time
	// @tparam table timeUnits A time unit table in the format {HH, MM, SS, [CC]}, where [CC] is optional.
	// @treturn Time A new Time object initialized with the given values.
	// @usage
	// -- Create Time object for 0 hours, 2 minutes, 15 seconds, and 75 centiseconds
	// local timeUnits = {0, 2, 15, 75} -- 0 hours, 2 minutes, 15 seconds, and 75 centiseconds
	// local time = Time(timeUnits)
	Time::Time(const sol::table& hmsTable)
	{
		SetFromTable(hmsTable);
	}

	///  Convert this Time object to a formatted string.
	// @function tostring
	// @tparam Time this Time object.
	// @treturn string A string showing time in "HH:MM:SS.CC" format.
	// @usage
	// -- Example of converting Time object to string
	// local time = Time(3661) -- 2 minutes, 2 seconds, and 1 frame
	// print(tostring(time)) -- "00:02:02.03"
	std::string Time::ToString() const
	{
		auto hmsc = GetHmsc();

		auto stream = std::ostringstream();
		stream << std::setw(2) << std::setfill('0') << hmsc.Hours << ":"
			<< std::setw(2) << std::setfill('0') << hmsc.Minutes << ":"
			<< std::setw(2) << std::setfill('0') << hmsc.Seconds << "."
			<< std::setw(2) << std::setfill('0') << hmsc.Centiseconds;
		return stream.str();
	}

	/// List of all methods of the Time object:
	// @type Time

	/// Get the total game frame count.
	// @function Time:GetFrameCount
	// @treturn int Total number of game frames.
	// @usage
	// -- Get total frame count from Time object
	// local time = Time(150) -- 5 seconds
	// print(time:GetFrameCount()) -- 150
	int Time::GetFrameCount() const
	{
		return _frameCount;
	}

	/// Get the time in hours, minutes, seconds, and centiseconds as a table.
	// @function Time:GetTimeUnits
	// @treturn table A table in the format {HH, MM, SS, CC}.
	// @usage
	// -- Get time units from Time object
	// local time = Time(3675) -- 2 minutes, 2 seconds, and 15 frames
	// local units = time:GetTimeUnits() -- {0, 2, 2, 50}
	sol::table Time::GetTimeUnits(sol::this_state state) const
	{
		auto hmsc = GetHmsc();
		auto table = sol::state_view(state).create_table();

		table.add(hmsc.Hours);
		table.add(hmsc.Minutes);
		table.add(hmsc.Seconds);
		table.add(hmsc.Centiseconds);
		return table;
	}

	/// Get a time string formatted with a custom format. If the format is incorrect, the default value will be used.
	// @function Time:GetFormattedString
	// @tparam[opt={true&#44; true&#44; true&#44; true}] table format Boolean table {includeHours, includeMinutes, includeSeconds, includeDeciseconds}.<br>
	// @tparam[opt=true] bool useCentiseconds Whether to use centiseconds (1/100th of a second) or deciseconds (1/10th of a second) for the fractional part.
	// @treturn string A formatted time string (e.g., "12:34:56.73" or custom format based on the provided table).
	// @usage
	// -- Get full formatted time string
	// local time = Time(3750) -- 2 minutes, 5 seconds
	// print(time:GetFormattedString()) -- "00:02:05.00"
	//
	// -- Get formatted time string without hours and deciseconds
	// local format = {false, true, true, false}
	// print(time:GetFormattedString(format)) -- "02:05"
	//
	// -- Get formatted time string with only total seconds
	// local format = {false, false, true, false}
	// print(time:GetFormattedString(format)) -- "125"
	//
	// -- Get formatted time string using deciseconds
	// local format = {true, true, true, true}
	// print(time:GetFormattedString(format, false)) -- "00:02:05.0"
	std::string Time::GetFormattedString(sol::object formatObj, TypeOrNil<bool> useCentiseconds) const
	{
		bool includeHours = true;
		bool includeMinutes = true;
		bool includeSeconds = true;
		bool includeDeciseconds = true;

		if (formatObj.is<sol::table>())
		{
			sol::table format = formatObj.as<sol::table>();
			
			if (format.size() == 4)
			{
				auto h = format.get<sol::optional<bool>>(1);
				auto m = format.get<sol::optional<bool>>(2);
				auto s = format.get<sol::optional<bool>>(3);
				auto d = format.get<sol::optional<bool>>(4);

				if (h.has_value() && m.has_value() && s.has_value() && d.has_value())
				{
					includeHours = h.value();
					includeMinutes = m.value();
					includeSeconds = s.value();
					includeDeciseconds = d.value();
				}
			}
		}

		bool convertedUseCentiseconds = ValueOr<bool>(useCentiseconds, true);

		// Check if we can use the cached result
		if (_lastFrameCount == _frameCount &&
			_lastIncludeHours == includeHours &&
			_lastIncludeMinutes == includeMinutes &&
			_lastIncludeSeconds == includeSeconds &&
			_lastIncludeDeciseconds == includeDeciseconds &&
			_lastUseCentiseconds == convertedUseCentiseconds)
		{
			return _cachedResult;
		}

		// Update cache
		_lastFrameCount = _frameCount;
		_lastIncludeHours = includeHours;
		_lastIncludeMinutes = includeMinutes;
		_lastIncludeSeconds = includeSeconds;
		_lastIncludeDeciseconds = includeDeciseconds;
		_lastUseCentiseconds = convertedUseCentiseconds;

		auto hmsc = GetHmsc();

		int hours = hmsc.Hours;
		int minutes = hmsc.Minutes;
		int seconds = hmsc.Seconds;
		int deciseconds = convertedUseCentiseconds ? hmsc.Centiseconds : (hmsc.Centiseconds / 10);

		if (!includeHours && includeMinutes)
		{
			minutes = hours * TIME_UNIT + minutes;
		}

		if (!includeMinutes && includeSeconds)
		{
			seconds = hours * SQUARE(TIME_UNIT) + minutes * TIME_UNIT + seconds;
		}

		// Calculate the number of digits needed for each component
		auto countDigits = [](int value) -> int {
			if (value == 0) return 1;
			int digits = 0;
			while (value > 0) 
			{
				value /= 10;
				digits++;
			}
			return digits;
		};

		char buffer[32]{}; // Buffer size to handle larger numbers
		char* ptr = buffer;

		if (includeHours)
		{
			int digits = countDigits(hours);
			if (digits == 1)
			{
				*ptr++ = '0';
				*ptr++ = '0' + hours;
			}
			else
			{
				for (int i = digits - 1; i >= 0; --i) 
				{
					int divisor = 1;
					for (int j = 0; j < i; ++j) divisor *= 10;
					*ptr++ = '0' + (hours / divisor) % 10;
				}
			}
		}

		if (includeMinutes)
		{
			if (ptr != buffer) *ptr++ = ':';
			int digits = countDigits(minutes);
			if (digits == 1)
			{
				*ptr++ = '0';
				*ptr++ = '0' + minutes;
			}
			else
			{
				for (int i = digits - 1; i >= 0; --i)
				{
					int divisor = 1;
					for (int j = 0; j < i; ++j) divisor *= 10;
					*ptr++ = '0' + (minutes / divisor) % 10;
				}
			}
		}

		if (includeSeconds)
		{
			if (ptr != buffer) *ptr++ = ':';
			int digits = countDigits(seconds);
			if (digits == 1)
			{
				*ptr++ = '0';
				*ptr++ = '0' + seconds;
			}
			else
			{
				for (int i = digits - 1; i >= 0; --i)
				{
					int divisor = 1;
					for (int j = 0; j < i; ++j) divisor *= 10;
					*ptr++ = '0' + (seconds / divisor) % 10;
				}
			}
		}

		if (includeDeciseconds)
		{
			if (ptr != buffer) *ptr++ = '.';
			
			if (convertedUseCentiseconds)
			{
				// Two digits for centiseconds (00-99)
				*ptr++ = '0' + (deciseconds / 10);
				*ptr++ = '0' + (deciseconds % 10);
			}
			else
			{
				// Single digit for deciseconds (0-9)
				*ptr++ = '0' + deciseconds;
			}
		}

		*ptr = '\0';

		_cachedResult = std::string(buffer, ptr - buffer);
		return _cachedResult;
	}

	Time& Time::operator ++()
	{
		_frameCount++;
		return *this;
	}

	Time& Time::operator ++(int)
	{
		_frameCount++;
		return *this;
	}

	Time& Time::operator +=(const Time& time)
	{
		_frameCount += time._frameCount;
		return *this;
	}

	Time& Time::operator -=(const Time& time)
	{
		_frameCount = std::clamp(_frameCount - time._frameCount, 0, INT_MAX);
		return *this;
	}

	Time Time::operator +(int frameCount) const
	{
		return Time(_frameCount + frameCount);
	}

	Time Time::operator -(int frameCount) const
	{
		return Time(std::clamp(_frameCount - frameCount, 0, INT_MAX));
	}

	Time Time::operator +(const Time& time) const
	{
		return Time(_frameCount + time._frameCount);
	}

	Time Time::operator -(const Time& time) const
	{
		return Time(std::clamp(_frameCount - time._frameCount, 0, INT_MAX));
	}

	bool Time::operator <(const Time& time) const
	{
		return _frameCount < time._frameCount;
	}

	bool Time::operator <=(const Time& time) const
	{
		return _frameCount <= time._frameCount;
	}

	bool Time::operator ==(const Time& time) const
	{
		return _frameCount == time._frameCount;
	}

	Time::Hmsc Time::GetHmsc() const
	{
		int totalSeconds = _frameCount / FPS;

		return Hmsc
		{
			totalSeconds / SQUARE(TIME_UNIT),
			(totalSeconds % SQUARE(TIME_UNIT)) / TIME_UNIT,
			totalSeconds % TIME_UNIT,
			(_frameCount * 100 / FPS) % CENTISECOND
		};
	}

	Time::Hmsc Time::ParseFormattedString(const std::string& formattedTime)
	{
		std::regex timeFormat(R"((?:(\d+):)?(\d+):(\d+)(?:\.(\d+))?)");
		std::smatch match;

		if (!std::regex_match(formattedTime, match, timeFormat))
		{
			TENLog("Invalid time format. Supported formats: HH:MM:SS.CC, HH:MM:SS, MM:SS, or MM:SS.CC.", LogLevel::Warning);
			return Time::Hmsc();
		}

		int hours   = match[1].matched ? std::stoi(match[1].str()) : 0;
		int minutes = match[2].matched ? std::stoi(match[2].str()) : 0;
		int seconds = match[3].matched ? std::stoi(match[3].str()) : 0;
		int cents   = match[4].matched ? std::stoi(match[4].str()) : 0;

		return { hours, minutes, seconds, cents };
	}

	void Time::SetFromHMSC(int hours, int minutes, int seconds, int cents)
	{
		_frameCount = (hours * SQUARE(TIME_UNIT) + minutes * TIME_UNIT + seconds) * FPS +
			round((float)cents / ((float)CENTISECOND / (float)FPS));
	}

	void Time::SetFromFormattedString(const std::string& formattedTime)
	{
		auto hmsc = ParseFormattedString(formattedTime);
		SetFromHMSC(hmsc.Hours, hmsc.Minutes, hmsc.Seconds, hmsc.Centiseconds);
	}

	void Time::SetFromTable(const sol::table& hmsTable)
	{
		if (!hmsTable.valid() || hmsTable.size() < 1 || hmsTable.size() > 4)
			throw std::invalid_argument("Invalid time unit table. Expected {HH, MM, SS, [CC]}");

		int hours	= hmsTable.get_or(1, 0);
		int minutes = hmsTable.get_or(2, 0);
		int seconds = hmsTable.get_or(3, 0);
		int cents	= hmsTable.get_or(4, 0);

		SetFromHMSC(hours, minutes, seconds, cents);
	}
}
