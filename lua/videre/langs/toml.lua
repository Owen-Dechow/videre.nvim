local module_found, toml = pcall(require, "toml2lua")

if not module_found then
    return
end

local M = {
    name="TOML",
    encode = nil,
    decode = function(toml_text)
        toml_text = toml_text:gsub("^[ \t]+", ""):gsub("\n[ \t]+", "\n")
        local result, error = toml.parse(toml_text)

        if not result then
            error("Failed to parse TOML: " .. error)
        end

        return result
    end,
    highlight = function()
        vim.cmd([[syn match Keyword "\~"]])
    end,
    symbols = {}
}

return M
