local utils = require "videre.utils"

local M = {}

local yaml = require "yaml_parser"

---@param val VidereValue
---@param t VidereValueTypeName
---@param is_key boolean
---@return string
local function val_as_string(val, t, is_key)
    if is_key then
        return tostring(val)
    end

    if t == "array" then
        return "-"
    elseif t == "object" then
        return ":"
    elseif t == "null" then
        return "~"
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
end

---@param val any
---@return string
local function encode_val(val)
    local t = type(val)

    if t == "string" then
        return '"' .. utils.EscapeString(val) .. '"'
    elseif val == vim.NIL then
        return "~"
    else
        return tostring(val)
    end
end

---@param obj DataObj
---@param pad string|nil
---@return string[]
local function encode(obj, pad)
    pad = pad and pad or ""
    local lines = {}
    local data_type = utils.DataType(obj)

    if data_type == "array" then
        for _, v in ipairs(obj) do
            if type(v) ~= "table" then
                lines[#lines + 1] = pad .. "- " .. encode_val(v)
            elseif next(v) == nil then
                lines[#lines + 1] = pad .. (utils.DataType(v) == "array" and "- []" or "- {}")
            else
                lines[#lines + 1] = pad .. "-"
                for _, line in ipairs(encode(v, pad .. "  ")) do
                    lines[#lines + 1] = line
                end
                lines[#lines + 1] = ""
            end
        end
    else
        for k, v in pairs(obj) do
            if type(v) ~= "table" then
                lines[#lines + 1] = pad .. k .. ": " .. encode_val(v)
            elseif next(v) == nil then
                lines[#lines + 1] = pad .. k .. (utils.DataType(v) == "array" and ": []" or ": {}")
            else
                lines[#lines + 1] = pad .. k .. ":"
                for _, line in ipairs(encode(v, pad .. "  ")) do
                    lines[#lines + 1] = line
                end
                lines[#lines + 1] = ""
            end
        end
    end

    return lines
end

local function parse_key(text)
    local ok, res = pcall(yaml.parse, text .. ": ~")

    if not ok then
        error("Malformed key.")
    end

    local key
    for k, _ in pairs(res) do
        if key ~= nil then
            error("Malformed key.")
        end

        key = k
    end

    return key
end

local function parse_val(text)
    local ok, res = pcall(yaml.parse, "- " .. text)

    if not ok then
        error("Malformed key.")
    end

    local key, val
    for k, v in pairs(res) do
        if key ~= nil then
            error("Malformed key.")
        end

        key, val = k, v
    end

    return val
end

local function parse_key_val(text)
    local ok, res = pcall(yaml.parse, text)

    if not ok then
        error("Malformed key value pair.")
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

M[1] = { "yaml" }

---@type LangSpec
M[2] = {
    Decode = yaml.parse,
    Encode = encode,
    name = "YAML",
    ft = "yaml",
    ValueAsString = val_as_string,
    ParseKey = parse_key,
    ParseVal = parse_val,
    ParseKeyVal = parse_key_val,
    val_exe = { "# Enter new value:", '"ValueExample", ~/null, [], {}, true/false' },
    key_exe = { "# Enter new key:", 'keyExample/"alsoKey"' },
    key_val_exe = { "# Enter key val pair:", 'KeyVal: [1, 2]' },
}

return M
