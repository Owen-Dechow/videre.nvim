local config = require("videre.config").config
local utils = require "videre.utils"

local M = {}

---@param tbl VidereTable
---@return string
function M.GetStatuslineString(tbl)
    local pad = string.rep(" ", vim.fn.winsaveview().leftcol)


    local result = (tbl.is_saved and "" or "+") .. "Videre [" .. config.keymaps.help .. " "

    result = result .. table.concat(tbl.available_maps, " ") .. "]"

    local layer_n, cell_n, _ = utils.GetHoveredCell(tbl)
    if cell_n then
        local cell = tbl.layers[layer_n].cells[cell_n]
        result = result .. " (root"
        if #cell.data_ref > 0 then
            result = result .. " ➧ " .. table.concat(cell.data_ref, " ➧ ")
        end

        result = result .. ")"
    end

    return pad .. result
end

return M
