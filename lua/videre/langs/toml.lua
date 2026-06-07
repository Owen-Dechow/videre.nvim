local utils = require "videre.utils"

local M = {}

local module_found, toml = pcall(require, "toml2lua")

if not module_found then
    return nil
end

M[1] = { "toml" }

---@param val any
---@return string
local function encode_val(val)
    local t = type(val)

    if t == "table" then
        local dt = utils.DataType(val)
        if dt == "array" then
            -- Nested arrays handled recursively
            local parts = {}
            for _, v in ipairs(val) do
                parts[#parts + 1] = encode_val(v)
            end
            return "[" .. table.concat(parts, ", ") .. "]"
        else
            -- Inline table for objects
            local parts = {}
            for k, v in pairs(val) do
                parts[#parts + 1] = k .. " = " .. encode_val(v)
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
    elseif t == "string" then
        return '"' .. utils.EscapeString(val) .. '"'
    elseif val == vim.NIL or val == nil then
        -- TOML has no explicit null; you can choose to omit or use a placeholder
        return '""'
    elseif t == "boolean" then
        return val and "true" or "false"
    else
        return tostring(val)
    end
end

---@param obj DataObj
---@return string[]
local function encode(obj)
    local lines = {}

    for k, v in pairs(obj) do
        if type(v) == "table" and utils.DataType(v) == "object" then
            -- Table section
            lines[#lines + 1] = "[" .. k .. "]"
            for kk, vv in pairs(v) do
                lines[#lines + 1] = kk .. " = " .. encode_val(vv)
            end
            lines[#lines + 1] = ""
        else
            lines[#lines + 1] = k .. " = " .. encode_val(v)
        end
    end

    return lines
end

---@type LangSpec
M[2] = {
    Decode = toml.parse,
    Encode = encode,
    name = "TOML",
    ft = "toml",
    ValueAsString = function(val, t, is_key)
        if is_key then
            return tostring(val)
        end

        if t == "array" then
            return "[]"
        elseif t == "object" then
            return "{}"
        elseif t == "null" then
            return "null"
        elseif t == "bool" then
            return val and "true" or "false"
        elseif t == "number" then
            return tostring(val)
        elseif t == "string" then
            ---@diagnostic disable-next-line: param-type-mismatch
            return '"' .. utils.EscapeString(val) .. '"'
        else
            return tostring(val)
        end
    end,
    ParseKey = function(text)
        local ok, res = pcall(toml.parse, text .. ' = ""')

        if not ok then
            error("Malformed TOML key.")
        end

        local key
        for k, _ in pairs(res) do
            if key ~= nil then
                error("Malformed TOML key.")
            end
            key = k
        end

        return key
    end,
    ParseVal = function(text)
        local ok, res = pcall(toml.parse, "x = " .. text)

        if not ok then
            error("Malformed TOML value.")
        end

        return res.x
    end,
    ParseKeyVal = function(text)
        local ok, res = pcall(toml.parse, text)

        if not ok then
            error("Malformed TOML key value pair.")
        end

        local key, val
        for k, v in pairs(res) do
            if key ~= nil then
                error("Too many key value pairs found.")
            end

            key, val = k, v
        end

        if key == nil then
            error("No key passed.")
        end

        if type(key) ~= "string" then
            error("Key must be string.")
        end

        return { key, val }
    end
}

return M

