---@class LangSpec
---@field Decode fun(text: string): DataObj)
---@field Encode (fun(obj: DataObj): string[])|nil
---@field name string
---@field ft string
---@field ValueAsString fun(val: VidereValue, type: VidereValueTypeName, is_key: boolean): string
---@field ParseVal (fun(text: string): DataObj)|nil
---@field ParseKey (fun(text: string): DataObj)|nil
---@field ParseKeyVal (fun(text: string): [string, DataObj])|nil

---@type table<string, LangSpec>
local M = {}

---@param lib string
local function add_lang(lib)
    ---@type [string[], LangSpec]|nil
    local result = require(lib)

    if result ~= nil then
        for _, lang in pairs(result[1]) do
            M[lang] = result[2]
        end
    end
end

add_lang "videre.langs.json"
add_lang "videre.langs.yaml"
add_lang "videre.langs.toml"
add_lang "videre.langs.xml"

return M
