local module_found, toml = pcall(require, "toml2lua")

if not module_found then
    return
end

local M = {
    encode = nil,
    decode = function(toml_text)
        toml_text = toml_text:gsub("^[ \t]+", ""):gsub("\n[ \t]+", "\n")
        local success, result = pcall(toml.parse, toml_text)

        if not success then
            error("Failed to parse TOML: " .. result)
        end

        vim.print({ text=toml_text, success = success, result = result, tbl = "toml" })
        return result
    end,
    highlight = function()
        vim.cmd([[syn match Keyword "\~"]])
    end,
    symbols = {}
}

return M
