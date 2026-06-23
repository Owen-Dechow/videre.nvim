local config = require("videre.config").config
local utils = require "videre.utils"

local M = {}

---@param tbl VidereTable
---@return string
function M.GetStatuslineString(tbl)
    local pad = string.rep(" ", vim.fn.winsaveview().leftcol)

    local result = (tbl.is_saved and "" or "+") .. "Videre [" .. config.keymaps.help .. " "

    result = result .. table.concat(tbl.available_maps, " ") .. "] "

    local layer_n, cell_n, _ = utils.GetHoveredCell(tbl)
    if cell_n then
        local cell = tbl.layers[layer_n].cells[cell_n]
        result = result .. "(root"
        if #cell.data_ref > 0 then
            result = result .. " ➧ " .. table.concat(cell.data_ref, " ➧ ")
        end

        result = result .. ") "
    end

    local change_indicator = {}

    if #tbl.states > 1 then
        result = result .. tbl.state_idx .. "/" .. #tbl.states .. " "

        for i in ipairs(tbl.states) do
            change_indicator[#change_indicator + 1] = i == tbl.state_idx and "⧯" or "●"
        end
    end

    local change_width = vim.api.nvim_win_get_width(0) - utils.StringWidth(result) - 1

    local prepend = false
    while #change_indicator * 2 > change_width and #change_indicator > 0 do
        table.remove(change_indicator, 1)
        prepend = true
    end

    if prepend then
        result = result .. "—"
    end

    return pad .. result .. table.concat(change_indicator, "—")
end

return M
