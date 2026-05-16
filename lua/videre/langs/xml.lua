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

        local success, result = pcall(function(text)
            parser:parse(text)
            return handler.root
        end, xml_text)

        if not success then
            error("Failed to parse XML: " .. result)
        end

        return result
    end,
    highlight = function() end,
    symbols = {},
    nodebased = true,
}

return M
