--- Basic timer that performs countdown. When it expires, you can set a specific *LevelFuncs* function to be activated.<br>Timers are updated automatically at every frame before OnLoop event.<br>To use Timer inside scripts you need to call the module:
--	local Timer = require("Engine.Stopwatch")
-- @luautil Stopwatch

local Type = require("Engine.Type")
local Utility = require("Engine.Util")



local Stopwatch = {}
Stopwatch.__index = Stopwatch
LevelFuncs.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = { stopwatches = {} }

--- Create (but do not start) a new stopwatch.
-- @tparam StopwatchData stopwatchData A table containing the parameters for the stopwatch.
-- @treturn table|nil The created stopwatch object, or nil on failure.
-- @usage local myStopwatch = Stopwatch.Create({ name = "MyStopwatch" })
Stopwatch.Create = function(stopwatchData)
    if not Type.IsTable(stopwatchData) then
        TEN.Util.PrintLog("Stopwatch.Create: stopwatchData must be a table.", LogLevel.ERROR)
        return nil
    end
    if not Type.IsString(stopwatchData.name) then
        TEN.Util.PrintLog("Stopwatch.Create: stopwatchData.name must be a string.", LogLevel.ERROR)
        return nil
    end
    local self = { name = stopwatchData.name }
    return setmetatable(self, Stopwatch)
end
-- Table setup for creating Stopwatch.
-- @table StopwatchData
-- @tfield string name The name of the stopwatch.
