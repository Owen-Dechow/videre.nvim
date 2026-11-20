local utils = require("videre.utils")

local M = {}

local xml = require("xml2lua")

local ok, tree = pcall(require, "xmlhandler.tree")
if not ok then
    tree = require "xml2lua.xmlhandler.tree"
end

M[1] = { "xml" }

-- Move each `_attr` entry into its parent as "<prefix>name" (existing child keys win).
---@param node any parsed XML node (tables are recursed into, anything else is ignored)
---@param prefix string
local function inline_attrs(node, prefix)
    if type(node) ~= "table" then
        return
    end
    local attrs = node._attr
    node._attr = nil
    for _, child in pairs(node) do
        inline_attrs(child, prefix)
    end
    if type(attrs) == "table" then
        for k, v in pairs(attrs) do
            local key = prefix .. k
            if node[key] == nil then
                node[key] = v
            end
        end
    end
end

---@type LangSpec
M[2] = {
    ft = "xml",
    Decode = function(xml_text)
        local handler = tree:new()
        local parser = xml.parser(handler)
        parser:parse(xml_text)
        local cfg = require("videre.config").config
        if cfg.xml_inline_attributes then
            inline_attrs(handler.root, cfg.xml_attribute_prefix)
        end
        return handler.root
    end,
    Encode = nil,
    name = "XML",
    ValueAsString = function(val, t, is_key)
        if is_key then
            return tostring(val)
        end

        if t == "array" then
            return "</>"
        elseif t == "object" then
            return "< <>"
        elseif t == "null" then
            return "*"
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
}

return M
