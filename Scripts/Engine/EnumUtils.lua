--- Utility functions for working with enumerators.
--
-- 
-- To use the functions within the scripts, the module must be called:
--	local EnumUtils = require("Engine.EnumUtils")
-- @module EnumUtils

local EnumUtils = {}

--- Check if a value exists in an enumerator table
-- @tparam table enum The enumerator table (e.g., TEN.Collision.MaterialType)
-- @tparam value The value to search for
-- @treturn bool true if the value exists in the enumerator, false otherwise
-- @usage
-- local isValid = EnumUtils.HasValue(TEN.Collision.MaterialType, 5)
-- if isValid then
--     print("Valid material type!")
-- end
function EnumUtils.HasValue(enum, value)
    if type(enum) ~= "table" then
        return false
    end
    for _, enumValue in pairs(enum) do
        if enumValue == value then
            return true
        end
    end
    return false
end

--- Check if a key exists in an enumerator table
-- @tparam table enum The enumerator table (e.g., TEN.Collision.MaterialType)
-- @tparam string key The key name to search for
-- @treturn bool true if the key exists in the enumerator, false otherwise
-- @usage
-- local hasKey = EnumUtils.HasKey(TEN.Collision.MaterialType, "MUD")
-- if hasKey then
--     print("MUD is a valid material type key!")
-- end
function EnumUtils.HasKey(enum, key)
    if type(enum) ~= "table" or type(key) ~= "string" then
        return false
    end
    for enumKey, _ in pairs(enum) do
        if enumKey == key then
            return true
        end
    end
    return false
end

--- Get all keys from an enumerator table
-- @tparam table enum The enumerator table
-- @treturn table Array of key names
-- @usage
-- local keys = EnumUtils.GetKeys(TEN.Collision.MaterialType)
-- for _, key in ipairs(keys) do
--     print(key)
-- end
function EnumUtils.GetKeys(enum)
    if type(enum) ~= "table" then
        return {}
    end
    local keys = {}
    for key, _ in pairs(enum) do
        table.insert(keys, key)
    end
    return keys
end

--- Get all values from an enumerator table
-- @tparam table enum The enumerator table
-- @treturn table Array of values
-- @usage
-- local values = EnumUtils.GetValues(TEN.Collision.MaterialType)
-- for _, value in ipairs(values) do
--     print(value)
-- end
function EnumUtils.GetValues(enum)
    if type(enum) ~= "table" then
        return {}
    end
    local values = {}
    for _, value in pairs(enum) do
        table.insert(values, value)
    end
    return values
end

--- Get the key name for a given value in an enumerator
-- @tparam table enum The enumerator table
-- @param value The value to find
-- @treturn string|nil The key name if found, nil otherwise
-- @usage
-- local keyName = EnumUtils.GetKeyForValue(TEN.Collision.MaterialType, 0)
-- print(keyName)  -- "MUD"
function EnumUtils.GetKeyForValue(enum, value)
    if type(enum) ~= "table" then
        return nil
    end
    for key, enumValue in pairs(enum) do
        if enumValue == value then
            return key
        end
    end
    return nil
end

return EnumUtils