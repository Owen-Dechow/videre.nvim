local M = {}

---Jumps the cursor to a graph location.
---@param layer integer
---@param row integer
---@param render_info table
---@param backward boolean
M.JumpToLink = function(layer, row, render_info, backward)
    if backward then
        local col = render_info.row_unit_breaks[row][layer]
        vim.api.nvim_win_set_cursor(0, { row + 1, col.start })
    else
        local col = render_info.row_unit_breaks[row + 1][layer]
        vim.api.nvim_win_set_cursor(0, { row + 2, col.start })
    end

    vim.cmd("call search('\\S')")
end

---Moves the cursor to the first unit
M.CursorToRoot = function()
    vim.api.nvim_win_set_cursor(0, { 3, 3 })
end

return M
