local module_found, xml = pcall(require, "xml2lua")

if not module_found then
    return nil
end


local M = {
    name = "XML",
    encode = nil,
    decode = function(xml_text)
        local handler = require("xmlhandler.tree"):new()
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
