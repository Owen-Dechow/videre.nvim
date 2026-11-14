local utils = require "videre.utils"

local M = {}

local toml = require "toml2lua"

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

---@param s string
---@return string
local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@return string[]
local function sorted_keys(obj)
    local keys = {}
    for k in pairs(obj) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--- A table is a datetime if every key is a known datetime field of the right
--- type, and it is either:
---   * a date / datetime: year, month and day all present, or
---   * a local time: hour and min present, no date fields, no offset.
---@param t table
---@return boolean
local function is_datetime(t)
    for k, v in pairs(t) do
        local expected = DATETIME_FIELDS[k]
        if not expected or type(v) ~= expected then
            return false
        end
    end

    local has_date = t.year ~= nil or t.month ~= nil or t.day ~= nil
    if has_date then
        if t.year == nil or t.month == nil or t.day == nil then return false end
        if t.month < 1 or t.month > 12 then return false end
        if t.day < 1 or t.day > 31 then return false end
    else
        -- Local time only
        if t.hour == nil or t.min == nil or t.offset ~= nil then return false end
    end

    if t.hour ~= nil and (t.hour < 0 or t.hour > 23) then return false end
    if t.min ~= nil and (t.min < 0 or t.min > 59) then return false end
    if t.sec ~= nil and (t.sec < 0 or t.sec > 60) then return false end -- 60 for leap seconds
    if t.msec ~= nil and (t.msec < 0 or t.msec > 999) then return false end
    if t.offset ~= nil and (t.offset < -1440 or t.offset > 1440) then return false end

    return true
end

--- Encodes a datetime table as a TOML datetime string.
--- Produces offset datetime, local datetime, local date or local time
--- depending on which fields are present. Any time-related field (including
--- msec and offset) causes a time component to be written.
---@param t table
---@return string
local function encode_datetime(t)
    local date
    if t.year then
        date = string.format("%04d-%02d-%02d", math.floor(t.year), math.floor(t.month), math.floor(t.day))
    end

    local has_time = t.hour ~= nil or t.min ~= nil or t.sec ~= nil
        or t.msec ~= nil or t.offset ~= nil

    -- Local date only (e.g. 1979-05-27)
    if not has_time then
        return date
    end

    local hour = math.floor(t.hour or 0)
    local min  = math.floor(t.min or 0)
    local sec  = math.floor(t.sec or 0)

    local sec_str
    if t.msec then
        sec_str = string.format("%02d.%03d", sec, math.floor(t.msec))
    else
        sec_str = string.format("%02d", sec)
    end

    local time = string.format("%02d:%02d:%s", hour, min, sec_str)

    -- Local time only (e.g. 07:32:00)
    if not date then
        return time
    end

    -- Offset datetime (e.g. 1979-05-27T07:32:00Z)
    if t.offset then
        if t.offset == 0 then
            return date .. "T" .. time .. "Z"
        end

        local sign = t.offset > 0 and "+" or "-"
        local abs  = math.abs(t.offset)
        local oh   = math.floor(abs / 60)
        local om   = math.floor(abs % 60)
        return date .. "T" .. time .. string.format("%s%02d:%02d", sign, oh, om)
    end

    -- Local datetime (e.g. 1979-05-27T07:32:00)
    return date .. "T" .. time
end

--- Encodes a number without losing precision.
--- Where math.type exists (Lua 5.3+) integers and floats are kept distinct.
--- LuaJIT can't tell them apart, so whole numbers are written as integers.
---@param n number
---@return string
local function encode_number(n)
    if n ~= n then return "nan" end
    if n == math.huge then return "inf" end
    if n == -math.huge then return "-inf" end

    local is_int
    if math.type then
        is_int = math.type(n) == "integer"
    else
        is_int = n % 1 == 0 and math.abs(n) < 2 ^ 63
    end

    if is_int then
        if n == 0 then return "0" end
        if math.type then
            return string.format("%d", n)
        end
        return string.format("%.0f", n)
    end

    -- Shortest representation that round-trips
    for prec = 15, 17 do
        local s = string.format("%." .. prec .. "g", n)
        if tonumber(s) == n then
            -- Keep it a float in TOML
            if not s:find("[%.eEn]") then
                s = s .. ".0"
            end
            return s
        end
    end

    return tostring(n)
end

--- Quotes a TOML key only when it contains characters outside [A-Za-z0-9_-]
---@param k string
---@return string
local function toml_key(k)
    k = tostring(k)
    if k:match("^[A-Za-z0-9_%-]+$") then
        return k
    end
    return '"' .. utils.EscapeString(k) .. '"'
end

--- True if `v` is a non-empty array whose elements are ALL (non-datetime) objects.
---@param v table
---@return boolean
local function is_aot(v)
    if utils.DataType(v) ~= "array" or #v == 0 then
        return false
    end

    for _, item in ipairs(v) do
        if type(item) ~= "table"
            or is_datetime(item)
            or utils.DataType(item) ~= "object"
        then
            return false
        end
    end

    return true
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
            local parts = {}
            for _, v in ipairs(val) do
                parts[#parts + 1] = encode_val(v)
            end
            return "[" .. table.concat(parts, ", ") .. "]"
        else
            -- Inline table
            local parts = {}
            for _, k in ipairs(sorted_keys(val)) do
                parts[#parts + 1] = toml_key(k) .. " = " .. encode_val(val[k])
            end
            if #parts == 0 then
                return "{}"
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
    elseif t == "string" then
        return '"' .. utils.EscapeString(val) .. '"'
    elseif val == vim.NIL or val == nil then
        error("TOML cannot represent null values.")
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return encode_number(val)
    else
        return tostring(val)
    end
end

--- Recursively writes a TOML section into `lines`.
--- Scalar keys and arrays-of-scalars are written first (inline),
--- then sub-tables as [section] headers, then arrays-of-tables as [[header]].
--- Keys are sorted so output is deterministic.
---@param lines   string[]
---@param obj     table
---@param prefix  string   dotted key path so far, "" at top level
local function encode_section(lines, obj, prefix)
    local scalars   = {} -- keys whose values write inline
    local subtables = {} -- keys whose values are objects → [section]
    local aots      = {} -- keys whose values are arrays-of-tables → [[section]]

    for _, k in ipairs(sorted_keys(obj)) do
        local v = obj[k]
        local full_key = prefix ~= "" and (prefix .. "." .. toml_key(k)) or toml_key(k)

        if type(v) == "table" and not is_datetime(v) then
            if utils.DataType(v) == "object" then
                subtables[#subtables + 1] = { key = k, full_key = full_key, val = v }
            elseif is_aot(v) then
                aots[#aots + 1] = { key = k, full_key = full_key, val = v }
            else
                scalars[#scalars + 1] = { key = k, val = v }
            end
        else
            scalars[#scalars + 1] = { key = k, val = v }
        end
    end

    -- 1. Inline scalars / arrays / datetimes
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
    if type(obj) ~= "table" then
        error("TOML root must be a table.")
    end

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

--- Finds the end of a single (bare or quoted) key at the start of `s`.
--- Returns the index of the key's last character, or nil if `s` doesn't
--- start with a well formed key. Does not consume dotted parts.
---@param s string
---@return integer?
local function scan_key(s)
    local q = s:sub(1, 1)

    if q == '"' then
        local i = 2
        while i <= #s do
            local c = s:sub(i, i)
            if c == "\\" then
                i = i + 2
            elseif c == '"' then
                return i
            else
                i = i + 1
            end
        end
        return nil
    elseif q == "'" then
        return s:find("'", 2, true)
    end

    local _, e = s:find("^[A-Za-z0-9_%-]+")
    return e
end

local function parse_key(text)
    local trimmed = trim(text)

    -- The whole input must be exactly one key (no dotted keys, no trailing junk)
    if scan_key(trimmed) ~= #trimmed then
        error("Malformed TOML key. Dotted keys are not allowed.")
    end

    local ok, res = pcall(toml.parse, trimmed .. ' = ""')

    if not ok or not res then
        error("Malformed TOML key.")
    end

    local key = next(res)
    if key == nil or next(res, key) ~= nil or res[key] ~= "" then
        error("Malformed TOML key.")
    end

    if type(key) ~= "string" then
        error("Key must be string.")
    end

    if key:find(".", 1, true) then
        error("Keys containing '.' are not allowed.")
    end

    return key
end

local function parse_val(text)
    local ok, res = pcall(toml.parse, "x = " .. text)

    if not ok or not res then
        error("Malformed TOML value.")
    end


    -- Anything beyond the single `x` entry means the user typed extra content
    local key = next(res)
    if key ~= "x" or next(res, key) ~= nil then
        error("Malformed TOML value.")
    end

    return res.x
end

local function parse_key_val(text)
    local trimmed = trim(text)

    -- Must start with exactly one key followed by `=`.
    -- This rejects [headers], dotted keys (a.b = 1) and other junk.
    local e = scan_key(trimmed)
    if not e or not trimmed:sub(e + 1):match("^%s*=") then
        error("Malformed TOML key value pair. Dotted keys are not allowed.")
    end

    local ok, res = pcall(toml.parse, trimmed)

    if not ok or not res then
        error("Malformed TOML key value pair.")
    end

    local key, val = next(res)

    if key == nil then
        error("No key passed.")
    end

    if next(res, key) ~= nil then
        error("Too many key value pairs found.")
    end

    if type(key) ~= "string" then
        error("Key must be string.")
    end

    if key:find(".", 1, true) then
        error("Keys containing '.' are not allowed.")
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
