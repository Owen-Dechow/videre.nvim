local module_found, yaml = pcall(require, "yaml_parser")

if not module_found then
    return
end

local M = {
    encode = nil,
    decode = function(yaml_text)
        local success, result = pcall(yaml.parse, yaml_text)
        if not success then
            error("Failed to parse YAML: " .. result)
        end

        return result
    end,
    highlight = function()
        vim.cmd([[syn match Keyword "\~"]])
    end,
    symbols = {
        null = "~",
    }
}

return M
