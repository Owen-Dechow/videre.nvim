local utils = require "videre.utils"

local M = {}

M[1] = { "json" }

---@type LangSpec
M[2] = {
    Decode = vim.json.decode,
    Encode = function(json)
        return vim.split(vim.json.encode(json, { indent = "    " }), "\n")
    end,
    name = "JSON",
    ft = "json",
    ValueAsString = function(val, t, _)
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
        local ok, res = pcall(vim.json.decode, text)

        if not ok then
            error("Malformed string key.")
        end

        if type(text) ~= "string" then
            error("Key value must be string.")
        end

        return res
    end,
    ParseVal = function(text)
        local ok, res = pcall(vim.json.decode, text)

        if not ok then
            error("Malformed value.")
        end

        return res
    end,
    ParseKeyVal = function(text)
        local ok, res = pcall(vim.json.decode, "{" .. text .. "}")

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

        return { key, val }
    end
}

return M
