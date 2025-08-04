local consts = require("videre.consts")

local M = {
    langs = {
        json = require("videre.langs.json"),
        yaml = require("videre.langs.yaml"),
        xml = require("videre.langs.xml"),
    }
}

---Get the LangSpec for the given filetype
---@param filetype string
---@return LangSpec|nil
function M.get(filetype)
    local lang = M.langs[filetype]
    -- vim.print(M.langs)

    if type(lang) ~= "table" then
        vim.notify(filetype .. " is not a valid filetype for " .. consts.plugin_name);
        return nil
    end

    return lang
end

return M
