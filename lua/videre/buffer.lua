local config = require("videre.config").config
local tbl = require "videre.table"
local highlighting = require "videre.highlighting"
local statusline = require "videre.statusline"
local utils = require "videre.utils"
local actions = require "videre.actions"

local M = {}

---@param buf integer
---@param fn fun()
local function run_edit(buf, fn)
    vim.bo[buf].modifiable = true
    fn()
    vim.bo[buf].modifiable = false
end

---@param buf integer
---@param videre_table VidereTable
---@param cell VidereCell
---@param cell_n integer
---@param layer VidereLayer
---@param layer_n integer
---@param val_n integer|nil|"expand"
local function register_cell_functions(buf, videre_table, cell, cell_n, layer, layer_n, val_n)
    if #cell.hidden_values > 0 then
        actions.MakeExpandMapping(buf, videre_table, cell)
    elseif #cell.values > config.max_cell_lines then
        actions.MakeCollapseMapping(buf, videre_table, cell)
    end

    if cell.linking_cell then
        actions.MakeJumpBackMapping(buf, videre_table, cell)
    elseif videre_table.parent_table then
        actions.MakeReturnToParentTableMapping(buf, videre_table)
    end

    if cell_n > 1 then
        actions.MakeJumpUpMapping(buf, videre_table, layer_n, cell_n - 1)
    end

    if layer_n > 1 then
        actions.MakeSetRootMapping(buf, videre_table, layer_n, cell_n)
    end

    if cell_n < #layer.cells and not layer.cells[cell_n + 1].is_hidden then
        actions.MakeJumpDownMapping(buf, videre_table, layer_n, cell_n + 1)
    end

    if videre_table.lang_spec.Encode then
        actions.MakeChangeTypeMapping(buf, videre_table, layer_n, cell_n)
    end

    if type(val_n) == "number" then
        local val = cell.values[val_n][2]
        local val_type = utils.ValueType(val)

        if val_type == "array" or val_type == "object" then
            ---@diagnostic disable-next-line: param-type-mismatch
            actions.MakeJumpMapping(buf, videre_table, val)
        end

        if videre_table.lang_spec.ParseVal then
            actions.MakeChangeValueMapping(buf, videre_table, layer_n, cell_n, val_n)
            actions.MakeDeleteValueMapping(buf, videre_table, layer_n, cell_n, val_n)
            actions.MakeAddValueMapping(buf, videre_table, layer_n, cell_n, val_n)

            if cell.type == "object" then
                actions.MakeChangeKeyMapping(buf, videre_table, layer_n, cell_n, val_n)
            end
        end
    elseif val_n == nil then
        if videre_table.lang_spec.Encode then
            actions.MakeAddValueMapping(buf, videre_table, layer_n, cell_n, 0)
        end
    end
end

---@param buf integer
---@param videre_table VidereTable
local function on_mouse_move(buf, videre_table)
    local layer_n, cell_n, val_n = utils.GetHoveredCell(videre_table)

    highlighting.Clear(buf)

    if layer_n and cell_n then
        local layer = videre_table.layers[layer_n]
        local cell = layer.cells[cell_n]

        register_cell_functions(buf, videre_table, cell, cell_n, layer, layer_n, val_n)
        highlighting.HighlightFocusedCell(buf, cell, layer.left_render_col)
    end

    actions.MakeCloseWindowMapping(buf, videre_table)
    actions.MakeOpenHelpMenuMapping(buf)

    run_edit(buf, function()
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { statusline.GetStatuslineString(videre_table) })
    end)

    highlighting.HighlightBuffer(buf, videre_table)
end

---@param buf integer
---@param videre_table VidereTable
---@param cmd string|string[]
---@param fn fun(): nil
local function auto_cmd_for_buf(buf, videre_table, cmd, fn)
    vim.api.nvim_create_autocmd(cmd, {
        buffer = buf,
        group = videre_table.grp,
        callback = fn,
    })
end

---@param buf integer
---@param videre_table VidereTable
function M.Redraw(buf, videre_table)
    local out_lines = tbl.RenderTableToString(videre_table)

    highlighting.Clear(buf)

    run_edit(buf, function()
        vim.api.nvim_buf_set_lines(buf, 1, -1, false, out_lines)
    end)

    highlighting.HighlightBuffer(buf, videre_table)
end

---@param buf integer
---@param videre_table VidereTable
---@param clear_table VidereTable|nil
function M.JoinTableToBuffer(buf, videre_table, clear_table)
    if clear_table then
        vim.api.nvim_clear_autocmds({ group = clear_table.grp })
    end

    M.Redraw(buf, videre_table)

    auto_cmd_for_buf(buf, videre_table, "CursorMoved", function()
        actions.ClearAllMappings(buf, videre_table)
        pcall(on_mouse_move, buf, videre_table)
    end)

    vim.api.nvim_buf_create_user_command(buf, "VidereCommit", function()
        local new_lines = videre_table.lang_spec.Encode(videre_table.data)
        vim.api.nvim_buf_set_lines(videre_table.from_buffer, 0, -1, false, new_lines)
        videre_table.is_saved = true
        on_mouse_move(buf, videre_table)
    end, {})

    on_mouse_move(buf, videre_table)
end

---@param buf integer
---@param clear_table VidereTable
---@param data DataObj
---@param root DataObjectRef
---@param focus DataObjectRef
---@param focus_val integer
---@param expanded_cells DataObjectRef[]
function M.JoinDataToBuffer(buf, clear_table, data, root, focus, focus_val, expanded_cells)
    local videre_table = tbl.DataToVidereTable(data, clear_table.from_buffer, false, clear_table.lang_spec)
    tbl.ExpandCellPack(videre_table, expanded_cells)

    local root_ref = tbl.DataRefToTableRef(videre_table, root, 1)
    local sub_table = tbl.MakeSubTable(videre_table, root_ref[1], root_ref[2])
    M.JoinTableToBuffer(buf, sub_table, clear_table)

    local focus_ref = tbl.DataRefToTableRef(sub_table, focus, focus_val)


    vim.defer_fn(function()
        tbl.JumpToCellAndValue(sub_table, focus_ref[1], focus_ref[2], focus_ref[3])
    end, 0)
end

---@param data DataObj
---@param from_buffer integer
---@param lang_spec LangSpec
---@return integer
function M.CreateVidereBuffer(data, from_buffer, lang_spec)
    local videre_table = tbl.DataToVidereTable(data, from_buffer, true, lang_spec)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "videre"

    M.JoinTableToBuffer(buf, videre_table, nil)

    vim.defer_fn(function()
        tbl.JumpToCellAndValue(videre_table, 1, 1, 1)
    end, 0)

    return buf
end

return M
