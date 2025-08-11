local M = {}

---Determines if the unit specified by the key_set
---is expanded or not.
---@param key_set any[]
---@param dict table | nil
---@return boolean | nil
M.IsExpanded = function(key_set, dict)
    if dict == nil then
        dict = require("videre").expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            return nil
        end

        dict = dict[key]

        if idx == #key_set then
            return dict[0]
        end
    end

    return false
end

---Register the unit specified by the key_set as expanded true
---or expanded false.
---@param key_set any[]
---@param val boolean
---@param dict table | nil
M.SetExpanded = function(key_set, val, dict)
    if dict == nil then
        dict = require("videre").expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            dict[key] = {}
        end

        dict = dict[key]

        if idx == #key_set then
            dict[0] = val
        end
    end
end


return M
