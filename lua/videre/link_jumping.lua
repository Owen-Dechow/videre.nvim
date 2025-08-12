local M = {}

---Jumps the cursor to a graph location.
---@param layer integer
---@param row integer
---@param render_info RenderInfo
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

---Jump up or down a unit
---@param layer integer
---@param unit integer
---@param render_info RenderInfo
M.JumpVertical = function(layer, unit, render_info)
    local row = render_info.text_output_table[layer].boxes[unit].top_line
    local col = render_info.row_unit_breaks[row + 1][layer]
    vim.api.nvim_win_set_cursor(0, { row + 2, col.start })
    vim.cmd("call search('\\S')")
end

---Jump up or down a unit
---@param layer integer
---@param unit integer
---@return function
M.GetJumpVerticalPredicate = function(layer, unit)
    return function(opts)
        local target_layer = opts.render_info.text_output_table[layer]
        if target_layer == nil then
            return false
        end

        local boxes = target_layer.boxes
        if boxes == nil then
            return false
        end

        if boxes[unit] == nil then
            return false
        end

        return true
    end
end

return M
