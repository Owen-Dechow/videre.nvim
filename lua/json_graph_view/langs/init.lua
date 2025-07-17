local consts = require("json_graph_view.consts")

local M = {
    langs = {
        json = require("json_graph_view.langs.json"),
        yaml = require("json_graph_view.langs.yaml")
    }
}

---Get the LangSpec for the given filetype
---@param filetype string
---@return LangSpec|nil
function M.get(filetype)
    local lang = M.langs[filetype]

    if type(lang) ~= "table" then
        vim.notify(filetype .. " is not a valid filetype for " .. consts.plugin_name);
        return nil
    end

    return lang
end

return M
