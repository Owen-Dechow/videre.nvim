local utils = require "videre.utils"

local M = {}

local module_found, toml = pcall(require, "toml2lua")

if not module_found then
    return nil
end

M[1] = { "toml" }

local DATETIME_FIELDS = {
    year   = "number",
    month  = "number",
    day    = "number",
    hour   = "number",
    min    = "number",
    sec    = "number",
    msec   = "number",
    offset = "number",
}

-- Fields that MUST be present for a valid datetime
local DATETIME_REQUIRED = { "year", "month", "day" }

---@param t table
---@return boolean
local function is_datetime(t)
    -- Every key in t must be a known datetime field with the correct type
    for k, v in pairs(t) do
        local expected = DATETIME_FIELDS[k]
        if not expected then
            return false -- unknown key → not a datetime
        end
        if type(v) ~= expected then
            return false -- wrong type for a known field
        end
    end

    -- All required fields must be present
    for _, field in ipairs(DATETIME_REQUIRED) do
        if t[field] == nil then
            return false
        end
    end

    -- Range checks
    if t.month < 1 or t.month > 12 then return false end
    if t.day < 1 or t.day > 31 then return false end
    if t.hour ~= nil and (t.hour < 0 or t.hour > 23) then return false end
    if t.min ~= nil and (t.min < 0 or t.min > 59) then return false end
    if t.sec ~= nil and (t.sec < 0 or t.sec > 60) then return false end -- 60 for leap seconds
    if t.msec ~= nil and (t.msec < 0 or t.msec > 999) then return false end
    if t.offset ~= nil and (t.offset < -1440 or t.offset > 1440) then return false end

    return true
end

--- Encodes a datetime table as a TOML datetime string.
--- Produces offset datetime, local datetime, or local date depending on
--- which fields are present.
---@param t table
---@return string
local function encode_datetime(t)
    local date = string.format("%04d-%02d-%02d", t.year, t.month, t.day)

    -- No time fields → local date only  (e.g. 1979-05-27)
    if not t.hour and not t.min and not t.sec then
        return date
    end

    local hour = t.hour or 0
    local min  = t.min or 0
    local sec  = t.sec or 0
    -- fractional seconds
    local sec_str
    if t.msec then
        sec_str = string.format("%02d.%03d", sec, t.msec)
    else
        sec_str = string.format("%02d", sec)
    end

    local time = string.format("%02d:%02d:%s", hour, min, sec_str)

    -- offset present → offset datetime (e.g. 1979-05-27T07:32:00Z)
    if t.offset then
        if t.offset == 0 then
            return date .. "T" .. time .. "Z"
        else
            local sign = t.offset > 0 and "+" or "-"
            local abs  = math.abs(t.offset)
            local oh   = math.floor(abs / 60)
            local om   = abs % 60
            return date .. "T" .. time .. string.format("%s%02d:%02d", sign, oh, om)
        end
    end

    -- no offset → local datetime (e.g. 1979-05-27T07:32:00)
    return date .. "T" .. time
end

--- Quotes a TOML key only when it contains characters outside [A-Za-z0-9_-]
---@param k string
---@return string
local function toml_key(k)
    if k:match("^[A-Za-z0-9_%-]+$") then
        return k
    end
    return '"' .. utils.EscapeString(k) .. '"'
end

---@param val any
---@return string
local function encode_val(val)
    local t = type(val)
    if t == "table" then
        -- Datetime check comes first, before DataType dispatch
        if is_datetime(val) then
            return encode_datetime(val)
        end

        local dt = utils.DataType(val)
        if dt == "array" then
            local is_aot = type(val[1]) == "table"
                and not is_datetime(val[1])
                and utils.DataType(val[1]) == "object"
            if is_aot then
                local parts = {}
                for _, v in ipairs(val) do
                    parts[#parts + 1] = encode_val(v)
                end
                return "[" .. table.concat(parts, ", ") .. "]"
            else
                local parts = {}
                for _, v in ipairs(val) do
                    parts[#parts + 1] = encode_val(v)
                end
                return "[" .. table.concat(parts, ", ") .. "]"
            end
        else
            -- Inline table
            local parts = {}
            for k, v in pairs(val) do
                parts[#parts + 1] = toml_key(k) .. " = " .. encode_val(v)
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
    elseif t == "string" then
        return '"' .. utils.EscapeString(val) .. '"'
    elseif val == vim.NIL or val == nil then
        return '""'
    elseif t == "boolean" then
        return val and "true" or "false"
    else
        return tostring(val)
    end
end

--- Recursively writes a TOML section into `lines`.
--- Scalar keys and arrays-of-scalars are written first (inline),
--- then sub-tables as [section] headers, then arrays-of-tables as [[header]].
---@param lines   string[]
---@param obj     table
---@param prefix  string   dotted key path so far, "" at top level
local function encode_section(lines, obj, prefix)
    local scalars   = {} -- keys whose values write inline
    local subtables = {} -- keys whose values are objects → [section]
    local aots      = {} -- keys whose values are arrays-of-tables → [[section]]

    for k, v in pairs(obj) do
        local full_key = prefix ~= "" and (prefix .. "." .. toml_key(k)) or toml_key(k)
        if type(v) == "table" and not is_datetime(v) then
            local dt = utils.DataType(v)
            if dt == "object" then
                subtables[#subtables + 1] = { key = k, full_key = full_key, val = v }
            elseif dt == "array" then
                local first = v[1]
                if type(first) == "table"
                    and not is_datetime(first)
                    and utils.DataType(first) == "object"
                then
                    aots[#aots + 1] = { key = k, full_key = full_key, val = v }
                else
                    scalars[#scalars + 1] = { key = k, val = v }
                end
            else
                scalars[#scalars + 1] = { key = k, val = v }
            end
        else
            scalars[#scalars + 1] = { key = k, val = v }
        end
    end

    -- 1. Inline scalars / arrays-of-scalars / datetimes
    for _, entry in ipairs(scalars) do
        lines[#lines + 1] = toml_key(entry.key) .. " = " .. encode_val(entry.val)
    end

    -- 2. Sub-tables  →  [full_key]
    for _, entry in ipairs(subtables) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "[" .. entry.full_key .. "]"
        encode_section(lines, entry.val, entry.full_key)
    end

    -- 3. Arrays-of-tables  →  [[full_key]]
    for _, entry in ipairs(aots) do
        for _, item in ipairs(entry.val) do
            lines[#lines + 1] = ""
            lines[#lines + 1] = "[[" .. entry.full_key .. "]]"
            encode_section(lines, item, entry.full_key)
        end
    end
end

---@param obj DataObj
---@return string[]
local function encode(obj)
    local lines = {}
    encode_section(lines, obj, "")

    -- Remove leading/trailing blank lines
    while lines[1] == "" do table.remove(lines, 1) end
    while lines[#lines] == "" do lines[#lines] = nil end

    return lines
end

local function val_as_string(val, t, is_key)
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
end

local function parse_key(text)
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

    if key == nil then
        error("Malformed TOML key.")
    end

    return key
end

local function parse_val(text)
    local ok, res = pcall(toml.parse, "x = " .. text)

    if not ok then
        error("Malformed TOML value.")
    end

    return res.x
end

local function parse_key_val(text)
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

---@type LangSpec
M[2] = {
    Decode = toml.parse,
    Encode = encode,
    name = "TOML",
    ft = "toml",
    ValueAsString = val_as_string,
    ParseKey = parse_key,
    ParseVal = parse_val,
    ParseKeyVal = parse_key_val,
    val_exe = { "# Enter new value:", '"ExampleValues", 34.12, true, 1979-05-27T07:32:00Z' },
    key_exe = { "# Enter new key:", "myKeyExample" },
    key_val_exe = { "# Enter Key value pair:", "myKey = true" },
}

return M
