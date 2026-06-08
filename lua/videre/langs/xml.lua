local utils = require "videre.utils"

local M = {}

local module_found, xml = pcall(require, "xml2lua")

if not module_found then
    return nil
end

local tree_found, tree = pcall(require, "xmlhandler.tree")
if not tree_found then
    tree_found, tree = pcall(require, "xml2lua.xmlhandler.tree")
end

if not tree_found then
    return nil
end


local M = {
    name = "XML",
    encode = nil,
    decode = function(xml_text)
        local handler = tree:new()
        local parser = xml.parser(handler)

M[1] = { "xml" }

---@type LangSpec
M[2] = {
    Decode = function(xml_text)
        local handler = tree:new()
        local parser = xml.parser(handler)
        parser:parse(xml_text)
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
