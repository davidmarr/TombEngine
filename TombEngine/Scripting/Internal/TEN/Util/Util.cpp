#include "framework.h"
#include "Scripting/Internal/TEN/Util/Util.h"

#include "Game/collision/collide_room.h"
#include "Game/collision/Los.h"
#include "Game/control/los.h"
#include "Game/Lara/lara.h"
#include "Game/room.h"
#include "Renderer/Renderer.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptAssert.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h"
#include "Scripting/Internal/TEN/Objects/Static/StaticObject.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Scripting/Internal/TEN/Util/LevelLog.h"
#include "Specific/configuration.h"
#include "Specific/level.h"

using namespace TEN::Collision::Los;
using TEN::Renderer::g_Renderer;

namespace TEN::Scripting::Util
{
	// Performance limits for deep table comparison
	const int MAX_TABLE_SIZE = 50;    // Max elements per table
	const int MAX_DEPTH = 3;        // Max nesting levels
	const int MAX_TOTAL_ELEMENTS = 500;      // Max total elements checked across all tables

	// Forward declaration for mutual recursion
	static bool CompareTablesDeep(const sol::table& tbl1, const sol::table& tbl2, int depth, int totalElementsChecked);

	/// Utility functions for math, conversions, tables, and interpolation.<style>table.function_list td.name {min-width: 290px;}</style>
	// @tentable Util
	// @pragma nostrip

	/// Determine if there is a clear line of sight between two positions. Limited to room geometry. Objects are ignored.
	// @function HasLineOfSight
	// @tparam float roomID Room ID of the first position's room.
	// @tparam Vec3 posA First position.
	// @tparam Vec3 posB Second position.
	// @treturn bool true if there is a line of sight, false if not.
	// @usage
	// local flamePlinthPos = flamePlinth:GetPosition() + Vec3(0, flamePlinthHeight, 0);
	// print(TEN.Util.HasLineOfSight(enemyHead:GetRoomNumber(), enemyHead:GetPosition(), flamePlinthPos))
	static bool HasLineOfSight(int roomID, const Vec3& posA, const Vec3& posB)
	{
		auto vector0 = posA.ToGameVector();
		auto vector1 = posB.ToGameVector();

		StaticMesh* mesh = nullptr;
		auto vector = Vector3i::Zero;
		return (LOS(&vector0, &vector1) && ObjectOnLOS2(&vector0, &vector1, &vector, &mesh) == NO_LOS_ITEM);
	}

	/// Calculate the horizontal distance between two positions.
	// @function CalculateHorizontalDistance
	// @tparam Vec3 posA First position.
	// @tparam Vec3 posB Second position.
	// @treturn float Horizontal distance between the two positions.
	// @usage
	// local dist = TEN.Util.CalculateHorizontalDistance(Lara:GetPosition(), enemyHead:GetPosition())
	static float CalculateHorizontalDistance(const Vec3& posA, const Vec3& posB)
	{
		auto pos0 = Vector2(posA.x, posA.z);
		auto pos1 = Vector2(posB.x, posB.z);
		return round(Vector2::Distance(pos0, pos1));
	}

	/// Get the projected display space position of a 3D world position. Returns nil if the world position is behind the camera view.
	// @function GetDisplayPosition
	// @tparam Vec3 worldPos 3D world position.
	// @treturn Vec2 Projected display space position in percent.
	// @usage 
	// Example: Display a string at the player's position.
	// local string = DisplayString('Example', 0, 0, Color(255, 255, 255), false)
	// local displayPos = GetDisplayPosition(Lara:GetPosition())
	// string:SetPosition(TEN.Util.PercentToScreen(displayPos))
	static sol::optional<Vec2> GetDisplayPosition(const Vec3& worldPos)
	{
		auto displayPos = g_Renderer.Get2DPosition(worldPos.ToVector3());
		if (!displayPos.has_value())
			return sol::nullopt;

		return Vec2(
			(displayPos->x / DISPLAY_SPACE_RES.x) * 100,
			(displayPos->y / DISPLAY_SPACE_RES.y) * 100);
	}

	/// Translate a pair display position coordinates to pixel coordinates.
	//To be used with @{Strings.DisplayString:SetPosition} and @{Strings.DisplayString}.
	//@function PercentToScreen
	//@tparam float x X component of the display position.
	//@tparam float y Y component of the display position.
	//@treturn int x X coordinate in pixels.
	//@treturn int y Y coordinate in pixels.
	//@usage	
	//local halfwayX, halfwayY = PercentToScreen(50, 50)
	//local ScreenPos = Vec2(halfwayX, halfwayY)
	//local spawnLocationNullmesh = GetMoveableByName("position_behind_left_pillar")
	//local flags = { DisplayStringOption.SHADOW, DisplayStringOption.CENTER }
	//local str1 = DisplayString("You spawned an enemy!", ScreenPos, Color(255, 100, 100), false, flags)
	//
	//LevelFuncs.triggerOne = function(obj) 
	//	ShowString(str1, 4)
	//end
	static std::tuple<int, int> PercentToScreen(float x, float y)
	{
		float fWidth = g_Configuration.ScreenWidth;
		float fHeight = g_Configuration.ScreenHeight;
		int resX = (int)std::round(fWidth / 100.0f * x);
		int resY = (int)std::round(fHeight / 100.0f * y);

		return std::make_tuple(resX, resY);
	}

	/// Translate a Vec2 of display position coordinates to Vec2 pixel coordinates.
	//To be used with @{Strings.DisplayString:SetPosition} and @{Strings.DisplayString}.
	//@function PercentToScreen
	//@tparam Vec2 percentPos Display position to translate to pixel coordinates.
	//@treturn Vec2 Pixel coordinates.
	//@usage
	//local percentPos = Vec2(25, 75)
	//local screenPos = Util.PercentToScreen(percentPos)
	//local str1 = DisplayString("Position at 25% X and 75% Y", screenPos)
	//ShowString(str1, 4)
	static Vec2 PercentToScreen(const Vec2& percentPos)
	{
		auto [screenX, screenY] = PercentToScreen(percentPos.x, percentPos.y);
		return Vec2(screenX, screenY);
	}

	/// Translate a pair of pixel coordinates to display position coordinates.
	//To be used with @{Strings.DisplayString:GetPosition}.
	//@function ScreenToPercent
	//@tparam int x X pixel coordinate to translate to display position.
	//@tparam int y Y pixel coordinate to translate to display position.
	//@treturn float x X component of display position.
	//@treturn float y Y component of display position.
	//@usage
	//local screenX, screenY = PercentToScreen(25, 75)
	//local percentX, percentY = ScreenToPercent(screenX, screenY)
	static std::tuple<float, float> ScreenToPercent(int x, int y)
	{
		float fWidth = g_Configuration.ScreenWidth;
		float fHeight = g_Configuration.ScreenHeight;
		float resX = x / fWidth * 100.0f;
		float resY = y / fHeight * 100.0f;
		return std::make_tuple(resX, resY);
	}

	/// Translate a Vec2 of pixel coordinates to Vec2 display position coordinates.
	//To be used with @{Strings.DisplayString:GetPosition}.
	//@function ScreenToPercent
	//@tparam Vec2 screenPos Pixel coordinates to translate to display position.
	//@treturn Vec2 Display position.
	//@usage
	//local screenPos = Vec2(400, 300)
	//local percentPos = Util.ScreenToPercent(screenPos)
	//print('Percent X: ' .. percentPos.x .. ' Percent Y: ' .. percentPos.y)
	static Vec2 ScreenToPercent(const Vec2& screenPos)
	{
		auto [percentX, percentY] = ScreenToPercent((int)screenPos.x, (int)screenPos.y);
		return Vec2(percentX, percentY);
	}

	/// Pick a moveable by the given display position.
	// @function PickMoveableByDisplayPosition
	// @tparam Vec2 position Display space position in percent.
	// @treturn Objects.Moveable Picked moveable (nil if no moveable was found under the cursor).
	// @usage
	// -- Example: Pick a moveable at the center of the screen.
	// local screenCenter = Vec2(50, 50)
	// local pickedMoveable = TEN.Util.PickMoveableByDisplayPosition(screenCenter)
	// if pickedMoveable then
	//     print("Picked moveable: " .. pickedMoveable:GetName())
	// else
	//     print("No moveable found at the center of the screen.")
	// end
	static sol::optional <std::unique_ptr<Moveable>> PickMoveable(const Vec2& screenPos)
	{
		auto realScreenPos = PercentToScreen(screenPos.x, screenPos.y);
		auto ray = GetRayFrom2DPosition(Vector2(int(std::get<0>(realScreenPos)), int(std::get<1>(realScreenPos))));

		auto vector = Vector3i::Zero;
		int itemNumber = ObjectOnLOS2(&ray.first, &ray.second, &vector, nullptr);

		if (itemNumber == NO_LOS_ITEM || itemNumber < 0)
			return sol::nullopt;

		return std::make_unique<Moveable>(itemNumber);
	}

	/// Pick a static mesh by the given display position.
	// @function PickStaticByDisplayPosition
	// @tparam Vec2 position Display space position in percent.
	// @treturn Objects.Static Picked static mesh (nil if no static mesh was found under the cursor).
	// @usage
	// -- Example: Pick a static mesh at the center of the screen.
	// local screenCenter = Vec2(50, 50)
	// local pickedStatic = TEN.Util.PickStaticByDisplayPosition(screenCenter)
	// if pickedStatic then
	//     print("Picked static mesh.")
	// else
	//     print("No static mesh found at the center of the screen.")
	// end
	static sol::optional <std::unique_ptr<Static>> PickStatic(const Vec2& screenPos)
	{
		auto realScreenPos = PercentToScreen(screenPos.x, screenPos.y);
		auto ray = GetRayFrom2DPosition(Vector2((int)std::get<0>(realScreenPos), (int)std::get<1>(realScreenPos)));

		StaticMesh* mesh = nullptr;
		auto vector = Vector3i::Zero;
		int itemNumber = ObjectOnLOS2(&ray.first, &ray.second, &vector, &mesh, GAME_OBJECT_ID::ID_LARA);

		if (itemNumber == NO_LOS_ITEM || itemNumber >= 0)
			return sol::nullopt;

		return std::make_unique<Static>(*mesh);
	}

	/// Write messages within the Log file
	//@advancedDesc
	//For native Lua handling of errors, see the official Lua website:
	//
	//<a href="https://www.lua.org/pil/8.3.html">Error management</a>
	//
	//<a href="https://www.lua.org/manual/5.4/manual.html#pdf-debug.traceback">debug.traceback</a>
	//@function PrintLog
	//@tparam string Message to be displayed within the log.
	//@tparam Util.LogLevel logLevel Log level to be displayed.
	//@tparam[opt=false] bool allowSpam If true, allows continuous spamming of the message.
	// 
	//@usage
	//PrintLog('test info log', LogLevel.INFO)
	//PrintLog('test warning log', LogLevel.WARNING)
	//PrintLog('test error log', LogLevel.ERROR)
	//-- spammed message
	//PrintLog('test spam log', LogLevel.INFO, true)
	// 
	static void PrintLog(const std::string& message, const LogLevel& level, TypeOrNil<bool> allowSpam)
	{
		TENLog(message, level, LogConfig::All, ValueOr<bool>(allowSpam, false));
	}

	static float CalculateDistance(const Vec3& posA, const Vec3& posB)
	{
		return posA.Distance(posB);
	}

	// Helper function to compare two sol::objects for equality
	static bool CompareObjectValues(const sol::object& val1, const sol::object& val2, int depth = 0, int totalElementsChecked = 0)
	{
		// Check if types match
		if (val1.get_type() != val2.get_type())
			return false;

		// Compare values based on type
		switch (val1.get_type())
		{
		case sol::type::nil:
			return true; // Both nil

		case sol::type::boolean:
			return val1.as<bool>() == val2.as<bool>();

		case sol::type::number:
			return val1.as<double>() == val2.as<double>();

		case sol::type::string:
			return val1.as<std::string>() == val2.as<std::string>();

		case sol::type::table:
			// Recursive comparison for nested tables
			return CompareTablesDeep(val1.as<sol::table>(), val2.as<sol::table>(), depth + 1, totalElementsChecked);

		case sol::type::userdata:
		case sol::type::lightuserdata:
		{
			// Try pointer comparison first
			if (val1.pointer() == val2.pointer())
				return true;

			// Try value comparison for known types
			if (val1.is<ScriptColor>() && val2.is<ScriptColor>())
			{
				auto color1 = val1.as<ScriptColor>();
				auto color2 = val2.as<ScriptColor>();
				return color1.GetR() == color2.GetR() &&
					   color1.GetG() == color2.GetG() &&
					   color1.GetB() == color2.GetB() &&
					   color1.GetA() == color2.GetA();
			}
			else if (val1.is<Vec3>() && val2.is<Vec3>())
			{
				return Vec3::IsEqualTo(val1.as<Vec3>(), val2.as<Vec3>());
			}
			else if (val1.is<Vec2>() && val2.is<Vec2>())
			{
				return Vec2::IsEqualTo(val1.as<Vec2>(), val2.as<Vec2>());
			}
			else if (val1.is<Rotation>() && val2.is<Rotation>())
			{
				auto rot1 = val1.as<Rotation>();
				auto rot2 = val2.as<Rotation>();
				return rot1.x == rot2.x && rot1.y == rot2.y && rot1.z == rot2.z;
			}
			else
			{
				// Unknown userdata type, compare by reference
				return val1.pointer() == val2.pointer();
			}
		}

		case sol::type::function:
			// For functions, compare references only
			return val1.pointer() == val2.pointer();

		default:
			// Unknown type, compare by reference
			return val1.pointer() == val2.pointer();
		}
	}

	// Helper function for deep table comparison with performance limits
	static bool CompareTablesDeep(const sol::table& tbl1, const sol::table& tbl2, int depth = 0, int totalElementsChecked = 0)
	{
		// Check depth limit
		if (depth > MAX_DEPTH)
		{
			TENLog("Table comparison exceeded max depth (" + std::to_string(MAX_DEPTH) + "). Falling back to reference comparison.", LogLevel::Warning, LogConfig::All, false);
			return tbl1.pointer() == tbl2.pointer();
		}

		// Count elements in both tables
		size_t size1 = 0;
		size_t size2 = 0;

		for (const auto& _ : tbl1)
		{
			if (++size1 > MAX_TABLE_SIZE)
			{
				TENLog("Table comparison exceeded max size (" + std::to_string(MAX_TABLE_SIZE) + " elements per table). Falling back to reference comparison.", LogLevel::Warning, LogConfig::All, false);
				return tbl1.pointer() == tbl2.pointer();
			}
		}

		for (const auto& _ : tbl2)
		{
			if (++size2 > MAX_TABLE_SIZE)
			{
				TENLog("Table comparison exceeded max size (" + std::to_string(MAX_TABLE_SIZE) + " elements per table). Falling back to reference comparison.", LogLevel::Warning, LogConfig::All, false);
				return tbl1.pointer() == tbl2.pointer();
			}
		}

		// Check if sizes match
		if (size1 != size2)
			return false;

		// Check total elements limit
		totalElementsChecked += static_cast<int>(size1);
		if (totalElementsChecked > MAX_TOTAL_ELEMENTS)
		{
			TENLog("Table comparison exceeded max total elements (" + std::to_string(MAX_TOTAL_ELEMENTS) + "). Falling back to reference comparison.", LogLevel::Warning, LogConfig::All, false);
			return tbl1.pointer() == tbl2.pointer();
		}

		// Compare each key-value pair
		for (const auto& pair : tbl1)
		{
			sol::object key = pair.first;
			sol::object val1 = pair.second;
			sol::object val2 = tbl2[key];

			// Check if key exists in tbl2
			if (!val2.valid())
				return false;

			// Use the helper function to compare values
			if (!CompareObjectValues(val1, val2, depth, totalElementsChecked))
				return false;
		}
		return true;
	}

	/// Compare two tables for deep equality.
	// Recursively compares table contents including nested tables.
	// Has performance limits to prevent excessive computation.
	// @function CompareTables
	// @tparam table tbl1 First table to compare.
	// @tparam table tbl2 Second table to compare.
	// @treturn bool True if tables have identical structure and values, false otherwise.
	// @usage
	// -- Simple table comparison:
	// local tbl1 = {1, 2, 3}
	// local tbl2 = {1, 2, 3}
	// print(TEN.Util.CompareTablesDeep(tbl1, tbl2)) -- true
	//
	// -- Nested table comparison:
	// local tbl1 = {pos = {x = 10, y = 20}, color = {r = 255, g = 0, b = 0}}
	// local tbl2 = {pos = {x = 10, y = 20}, color = {r = 255, g = 0, b = 0}}
	// print(TEN.Util.CompareTables(tbl1, tbl2)) -- true
	//
	// -- With TEN types:
	// local tbl1 = {{1, 2}, TEN.Vec3(1, 2, 3), TEN.Color(255, 0, 0)}
	// local tbl2 = {{1, 2}, TEN.Vec3(1, 2, 3), TEN.Color(255, 0, 0)}
	// print(TEN.Util.CompareTables(tbl1, tbl2)) -- true
	//
	// -- Performance limits:
	// -- Max 50 elements per table
	// -- Max 3 levels of nesting
	// -- Max 500 total elements checked
	// -- If limits are exceeded, falls back to reference comparison with a warning
	static bool CompareTablesDeepExported(const sol::table& tbl1, const sol::table& tbl2)
	{
		return CompareTablesDeep(tbl1, tbl2);
	}

	/// Check if a table contains a specific value. Works with associative and array tables. Supports basic types and TEN primitive (Color, Vec2, Vec3, Rotation).
	// @function TableHasValue
	// @tparam table tbl The table to check.
	// @tparam any val The value to search for.
	// @treturn bool True if the value is found, false otherwise.
	// @usage
	// -- Example with associative table:
	// local tbl = { apple = 1, banana = 2, cherry = 3 }
	// local hasBanana = Util.TableHasValue(tbl, 2) -- Result: true
	// local hasGrape = Util.TableHasValue(tbl, 4) -- Result: false
	//
	// -- Example with array table:
	// local tbl = { "apple", "banana", "cherry" }
	// local hasBanana = Util.TableHasValue(tbl, "banana") -- Result: true
	// local hasGrape = Util.TableHasValue(tbl, "grape") -- Result: false
	//
	// -- Example with Color:
	// local tbl = { TEN.Color(255, 0, 0), TEN.Color(0, 255, 0), TEN.Color(0, 0, 255) }
	// local hasGreen = TEN.Util.TableHasValue(tbl, TEN.Color(0, 255, 0)) -- Result: true
	//
	// -- Example with Vec3:
	// local tbl = { TEN.Vec3(1, 2, 3), TEN.Vec3(4, 5, 6), TEN.Vec3(7, 8, 9) }
	// local hasVec = TEN.Util.TableHasValue(tbl, TEN.Vec3(4, 5, 6)) -- Result: true
	//
	// -- Example with Rotation:
	// local tbl = { TEN.Rotation(0, 90, 0), TEN.Rotation(45, 45, 45), TEN.Rotation(90, 0, 90) }
	// local hasRot = TEN.Util.TableHasValue(tbl, TEN.Rotation(45, 45, 45)) -- Result: true
	//
	// -- Example with nested tables:
	// local tbl = { {1, 2}, {3, 4}, {5, 6} }
	// local hasSubTable = Util.TableHasValue(tbl, {3, 4}) -- Result: true
	static bool TableHasValue(const sol::table& tbl, const sol::object& val)
	{
		for (const auto& pair : tbl)
		{
			if (CompareObjectValues(pair.second, val))
				return true;
		}
		return false;
	}

	/// Check if a table contains a specific key. Works with any type of key (string, number, boolean, userdata, table, etc.).
	// @function TableHasKey
	// @tparam table tbl The table to check.
	// @tparam any key The key to search for.
	// @treturn bool True if the key is found, false otherwise.
	// @usage
	// -- Example with string keys:
	// local tbl = { apple = 1, banana = 2, cherry = 3 }
	// local hasBanana = Util.TableHasKey(tbl, "banana") -- Result: true
	// local hasGrape = Util.TableHasKey(tbl, "grape") -- Result: false
	//
	// -- Example with numeric keys (array):
	// local tbl = { "apple", "banana", "cherry" }
	// local hasIndex1 = TEN.Util.TableHasKey(tbl, 1) -- Result: true
	// local hasIndex10 = TEN.Util.TableHasKey(tbl, 10) -- Result: false
	//
	// -- Example with boolean keys:
	// local tbl = { [true] = "yes", [false] = "no" }
	// local hasTrue = TEN.Util.TableHasKey(tbl, true) -- Result: true
	//
	// -- Example with Vec3 as key:
	// local pos1 = TEN.Vec3(1, 2, 3)
	// local pos2 = TEN.Vec3(4, 5, 6)
	// local tbl = { [pos1] = "location1", [pos2] = "location2" }
	// local hasPos1 = TEN.Util.TableHasKey(tbl, TEN.Vec3(1, 2, 3)) -- Result: true
	//
	// -- Example with Color as key:
	// local red = TEN.Color(255, 0, 0)
	// local tbl = { [red] = "red color" }
	// local hasRed = TEN.Util.TableHasKey(tbl, TEN.Color(255, 0, 0)) -- Result: true
	//
	// -- Example with table as key:
	// local key1 = {x = 10, y = 20}
	// local tbl = { [key1] = "data" }
	// local hasKey = TEN.Util.TableHasKey(tbl, {x = 10, y = 20}) -- Result: true
	//
	// -- Example with mixed keys:
	// local tbl = { 
	//     name = "test", 
	//     [5] = "fifth", 
	//     [true] = "yes",
	//     [TEN.Vec3(1, 2, 3)] = "position"
	// }
	// local hasName = TEN.Util.TableHasKey(tbl, "name") -- Result: true
	// local has5 = TEN.Util.TableHasKey(tbl, 5) -- Result: true
	// local hasVec = TEN.Util.TableHasKey(tbl, TEN.Vec3(1, 2, 3)) -- Result: true
	static bool TableHasKey(const sol::table& tbl, const sol::object& key)
	{
		for (const auto& pair : tbl)
		{
			if (CompareObjectValues(pair.first, key))
				return true;
		}
		return false;
	}

	/// Create a read-only wrapper around a table.
	// Returns a new table that provides read-only access to the original table. Any attempt to modify the read-only table will log an error. Very useful for create custom enums.
	// @function TableReadonly
	// @tparam table tbl The table to make read-only.
	// @treturn table A read-only wrapper table.
	// @usage
	// -- Create a read-only configuration table:
	// local config = { maxHealth = 100, maxAmmo = 50, difficulty = 2 }
	// local readonlyConfig = TEN.Util.TableReadonly(config)
	// 
	// -- Reading values works normally:
	// print(readonlyConfig.maxHealth) -- prints: 100
	// 
	// -- Attempting to modify triggers an error:
	// readonlyConfig.maxHealth = 200 -- Error: cannot modify 'maxHealth': table is read-only
	//
	// -- Iteration works normally:
	// for k, v in pairs(readonlyConfig) do
	//     print(k, v)
	// end
	static sol::table TableReadonly(const sol::table& tbl, sol::this_state s)
	{
		sol::state_view lua(s);
		sol::table wrapper = lua.create_table();
		sol::table mt = lua.create_table();

		// Read access via __index
		mt[sol::meta_function::index] = tbl;

		// Block write access via __newindex
		mt[sol::meta_function::new_index] = [](sol::table, sol::object key, sol::object)
		{
			std::string keyStr = key.is<std::string>() ? key.as<std::string>() : key.is<int>() ? std::to_string(key.as<int>()) : "unknown";
			TENLog("Error, cannot modify '" + keyStr + "': table is read-only", LogLevel::Error, LogConfig::All, false);
		};

		// Enable iteration via __pairs
		mt[sol::meta_function::pairs] = [tbl](sol::this_state s)
		{
			return sol::state_view(s)["pairs"](tbl);
		};

		wrapper[sol::metatable_key] = mt;
		return wrapper;
	}

	/// Split a string into parts using a delimiter.
	// Returns a Lua table containing the extracted parts.
	// @function SplitString
	// @tparam string str The string to split.
	// @tparam[opt=space " "] string delimiter The delimiter to use for splitting.
	// @treturn table Array table containing the split parts.
	// @usage
	// -- Split by comma:
	// local parts = TEN.Util.SplitString("apple,banana,cherry", ",")
	// -- Result: {"apple", "banana", "cherry"}
	//
	// -- Split by whitespace (default):
	// local parts = TEN.Util.SplitString("hello world  test")
	// -- Result: {"hello", "world", "test"}
	//
	// -- Split with custom delimiter:
	// local parts = TEN.Util.SplitString("one::two::three", "::")
	// -- Result: {"one", "two", "three"}
	//
	// -- Empty string returns empty table:
	// local parts = TEN.Util.SplitString("")
	// -- Result: {}
	//
	// -- No delimiter found returns original string:
	// local parts = TEN.Util.SplitString("nodelimiter", ",")
	// -- Result: {"nodelimiter"}
	static sol::table SplitString(const std::string& str, TypeOrNil<std::string> delimiter, sol::this_state s)
	{
		sol::state_view lua(s);
		sol::table result = lua.create_table();

		if (str.empty())
			return result;

		const std::string delim = ValueOr<std::string>(delimiter, "");
    
		if (delim.empty())
		{
			// Split by whitespace
			size_t pos = 0;
			const size_t len = str.length();
			int index = 1;

			while (pos < len)
			{
				// Skip leading whitespace
				while (pos < len && std::isspace(static_cast<unsigned char>(str[pos])))
					++pos;

				if (pos >= len)
					break;

				// Find end of word
				const size_t start = pos;
				while (pos < len && !std::isspace(static_cast<unsigned char>(str[pos])))
					++pos;

				result[index++] = str.substr(start, pos - start);
			}
		}
		else
		{
			// Split by delimiter
			size_t start = 0;
			size_t pos = 0;
			const size_t delimLen = delim.length();
			int index = 1;

			while ((pos = str.find(delim, start)) != std::string::npos)
			{
				result[index++] = str.substr(start, pos - start);
				start = pos + delimLen;
			}

			// Add last part
			result[index] = str.substr(start);
		}

		return result;
	}

	/// Linear interpolation between two values.
	// @function Lerp
	// @tparam number|Color|Rotation|Vec2|Vec3 a Start value.
	// @tparam number|Color|Rotation|Vec2|Vec3 b End value.
	// @tparam float alpha Interpolation factor (0.0 to 1.0).
	// @treturn number|Color|Rotation|Vec2|Vec3 Interpolated value.
	// @usage
	// local interpolated = TEN.Util.Lerp(0.0, 100.0, 0.5) -- Returns 50.0
	// local color = TEN.Util.Lerp(Color(255, 0, 0), Color(0, 255, 0), 0.5)
	// local pos = TEN.Util.Lerp(Vec3(0, 0, 0), Vec3(10, 10, 10), 0.25)
	static float LerpFloat(float a, float b, float alpha)
	{
		return a + (b - a) * alpha;
	}

	static ScriptColor LerpColor(const ScriptColor& a, const ScriptColor& b, float alpha)
	{
		Color result = Color::Lerp(a, b, alpha); 
		return ScriptColor(result);
	}

	static Rotation LerpRotation(const Rotation& a, const Rotation& b, float alpha)
	{
		return a.Lerp(b, alpha);
	}

	static Vec2 LerpVec2(const Vec2& a, const Vec2& b, float alpha)
	{
		return a.Lerp(b, alpha);
	}

static Vec3 LerpVec3(const Vec3& a, const Vec3& b, float alpha)
	{
		return a.Lerp(b, alpha);
	}

	/// Smooth Hermite interpolation between two values.
	// Provides a smoother interpolation than linear lerp using the formula: t<SUP style="font-size: x-small;">2</SUP> * (3 - 2t).
	// @function Smoothstep
	// @tparam number|Color|Rotation|Vec2|Vec3 a Start value.
	// @tparam number|Color|Rotation|Vec2|Vec3 b End value.
	// @tparam float alpha Interpolation factor (0.0 to 1.0).
	// @treturn number|Color|Rotation|Vec2|Vec3 Smoothly interpolated value.
	// @usage
	// -- Smooth float interpolation:
	// local smooth = TEN.Util.Smoothstep(0.0, 100.0, 0.5) -- Returns 50.0 (with smooth curve)
	//
	// -- Smooth color transition:
	// local color = TEN.Util.Smoothstep(Color(255, 0, 0), Color(0, 255, 0), 0.5)
	//
	// -- Smooth position movement:
	// local pos = TEN.Util.Smoothstep(Vec3(0, 0, 0), Vec3(10, 10, 10), 0.75)
	//
	// -- Smooth rotation:
	// local rot = TEN.Util.Smoothstep(Rotation(0, 0, 0), Rotation(0, 90, 0), 0.5)
	//
	// -- Compare with linear lerp:
	// local linear = TEN.Util.Lerp(0.0, 100.0, 0.5) -- Linear interpolation 50.0
	// local smooth = TEN.Util.Smoothstep(0.0, 100.0, 0.5) -- Smooth interpolation 
	static float SmoothstepFloat(float a, float b, float alpha)
	{
		// Clamp alpha to [0, 1]
		alpha = std::clamp(alpha, 0.0f, 1.0f);
		// Smooth Hermite interpolation: t² * (3 - 2t)
		float t = alpha * alpha * (3.0f - 2.0f * alpha);
		return a + (b - a) * t;
	}

	static ScriptColor SmoothstepColor(const ScriptColor& a, const ScriptColor& b, float alpha)
	{
		// Clamp alpha to [0, 1]
		alpha = std::clamp(alpha, 0.0f, 1.0f);
		// Apply smoothstep function
		float t = alpha * alpha * (3.0f - 2.0f * alpha);
	
		Color result = Color::Lerp(a, b, t);
		return ScriptColor(result);
	}

	static Rotation SmoothstepRotation(const Rotation& a, const Rotation& b, float alpha)
	{
		// Clamp alpha to [0, 1]
		alpha = std::clamp(alpha, 0.0f, 1.0f);
		// Apply smoothstep function
		float t = alpha * alpha * (3.0f - 2.0f * alpha);
	
		return a.Lerp(b, t);
	}

static Vec2 SmoothstepVec2(const Vec2& a, const Vec2& b, float alpha)
	{
		// Clamp alpha to [0, 1]
		alpha = std::clamp(alpha, 0.0f, 1.0f);
		// Apply smoothstep function
		float t = alpha * alpha * (3.0f - 2.0f * alpha);
	
		return a.Lerp(b, t);
	}

	static Vec3 SmoothstepVec3(const Vec3& a, const Vec3& b, float alpha)
	{
		// Clamp alpha to [0, 1]
		alpha = std::clamp(alpha, 0.0f, 1.0f);
		// Apply smoothstep function
		float t = alpha * alpha * (3.0f - 2.0f * alpha);
	
		return a.Lerp(b, t);
	}

	void Register(sol::state* state, sol::table& parent)
	{
		auto tableUtil = sol::table(state->lua_state(), sol::create);
		parent.set(ScriptReserved_Util, tableUtil);

		tableUtil.set_function(ScriptReserved_HasLineOfSight, &HasLineOfSight);
		tableUtil.set_function(ScriptReserved_CalculateHorizontalDistance, &CalculateHorizontalDistance);
		tableUtil.set_function(ScriptReserved_GetDisplayPosition, &GetDisplayPosition);
		tableUtil.set_function(ScriptReserved_PickMoveable, &PickMoveable);
		tableUtil.set_function(ScriptReserved_PickStatic, &PickStatic);
		tableUtil.set_function(ScriptReserved_PercentToScreen,
			sol::overload(
				static_cast<std::tuple<int, int>(*)(float, float)>(&PercentToScreen),
				static_cast<Vec2(*)(const Vec2&)>(&PercentToScreen)
			)
		);
		tableUtil.set_function(ScriptReserved_ScreenToPercent,
			sol::overload(
				static_cast<std::tuple<float, float>(*)(int, int)>(&ScreenToPercent),
				static_cast<Vec2(*)(const Vec2&)>(&ScreenToPercent)
			)
		);
		tableUtil.set_function(ScriptReserved_PrintLog, &PrintLog);
		tableUtil.set_function(ScriptReserved_CompareTables, &CompareTablesDeepExported);
		tableUtil.set_function(ScriptReserved_TableHasValue, &TableHasValue);
		tableUtil.set_function(ScriptReserved_TableHasKey, &TableHasKey);
		tableUtil.set_function(ScriptReserved_TableReadonly, &TableReadonly);
		tableUtil.set_function(ScriptReserved_SplitString, &SplitString);
		tableUtil.set_function(ScriptReserved_Lerp,
			sol::overload(
				&LerpFloat,
				&LerpColor,
				&LerpRotation,
				&LerpVec2,
				&LerpVec3
			)
		);
		tableUtil.set_function(ScriptReserved_Smoothstep,
			sol::overload(
				&SmoothstepFloat,
				&SmoothstepColor,
				&SmoothstepRotation,
				&SmoothstepVec2,
				&SmoothstepVec3
			)
		);

		// COMPATIBILITY
		tableUtil.set_function("CalculateDistance", &CalculateDistance);

		auto handler = LuaHandler(state);
		handler.MakeReadOnlyTable(tableUtil, ScriptReserved_LogLevel, LOG_LEVEL_IDS);
	}
}
